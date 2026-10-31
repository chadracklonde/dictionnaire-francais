#!/usr/bin/env python3
"""Importe le Wiktionnaire français (JSONL de kaikki.org / wiktextract)
dans une base SQLite prête pour l'application.

Usage :
    python3 import_wiktionnaire.py entrees.jsonl dictionnaire.db
    python3 import_wiktionnaire.py entrees.jsonl dictionnaire.db --limit 5000

Le fichier JSONL contient un objet JSON par ligne (un mot + une catégorie).
Contenu sous licence CC BY-SA 4.0 : voir le champ « meta » de la base.
"""

import argparse
import gzip
import json
import sqlite3
import sys
import unicodedata
from pathlib import Path
from urllib.parse import quote

SCHEMA = Path(__file__).with_name("schema.sql")
WIKI_URL = "https://fr.wiktionary.org/wiki/"
BATCH = 20000

POS_FR = {
    "noun": "nom", "verb": "verbe", "adj": "adjectif", "adv": "adverbe",
    "name": "nom propre", "prep": "préposition", "conj": "conjonction",
    "pron": "pronom", "intj": "interjection", "det": "déterminant",
    "article": "article", "num": "numéral", "prefix": "préfixe",
    "suffix": "suffixe", "phrase": "locution", "prep_phrase": "locution",
    "adv_phrase": "locution", "particle": "particule", "symbol": "symbole",
    "contraction": "contraction", "abbrev": "abréviation",
}
REGISTERS = {
    "familiar": "familier", "colloquial": "familier", "informal": "familier",
    "slang": "argot", "vulgar": "vulgaire", "formal": "soutenu",
    "literary": "littéraire", "dated": "vieilli", "archaic": "archaïque",
    "obsolete": "désuet", "rare": "rare", "pejorative": "péjoratif",
    "familier": "familier", "argot": "argot", "vieilli": "vieilli",
    "soutenu": "soutenu", "littéraire": "littéraire", "péjoratif": "péjoratif",
}
REL_TYPES = {
    "synonyms": "synonyme", "antonyms": "antonyme",
    "derived": "derive", "related": None,
}


def normalize(text: str) -> str:
    """Minuscule, sans accents, ligatures dépliées, apostrophes unifiées."""
    text = text.lower().replace("œ", "oe").replace("æ", "ae")
    text = text.replace("’", "'").replace("ʼ", "'")
    decomposed = unicodedata.normalize("NFD", text)
    return "".join(c for c in decomposed if not unicodedata.combining(c))


def open_text(path: str):
    if path.endswith(".gz"):
        return gzip.open(path, "rt", encoding="utf-8")
    return open(path, "r", encoding="utf-8")


def gender_of(entry: dict):
    tags = set()
    for sense in entry.get("senses", []):
        tags.update(sense.get("tags", []))
    for form in entry.get("forms", []):
        tags.update(form.get("tags", []))
    tags.update(entry.get("tags", []))
    masc = bool(tags & {"masculine", "masculin"})
    fem = bool(tags & {"feminine", "féminin"})
    if masc and fem:
        return "mf"
    if masc:
        return "m"
    if fem:
        return "f"
    return None


def first_ipa(entry: dict):
    for sound in entry.get("sounds", []):
        ipa = sound.get("ipa")
        if ipa:
            return ipa
    return None


def etymology_of(entry: dict):
    """Édition française : `etymology_texts` (liste) ; anglaise : `etymology_text`."""
    text = entry.get("etymology_text")
    if not text:
        text = "\n".join(t for t in entry.get("etymology_texts") or [] if t)
    return text or None


def clean_definition(sense: dict):
    glosses = sense.get("glosses") or sense.get("raw_glosses") or []
    text = " ; ".join(g.strip() for g in glosses if g and g.strip())
    return text or None


def sense_register(sense: dict):
    for tag in sense.get("tags", []):
        if tag.lower() in REGISTERS:
            return REGISTERS[tag.lower()]
    return None


def sense_domain(sense: dict):
    topics = sense.get("topics") or []
    return ", ".join(topics) if topics else None


def form_of_targets(entry: dict):
    """Lemmes visés si toutes les acceptions sont des formes fléchies."""
    senses = entry.get("senses", [])
    if not senses:
        return []
    targets = []
    for sense in senses:
        refs = sense.get("form_of") or sense.get("alt_of") or []
        if not refs:
            return []
        for ref in refs:
            word = ref.get("word") if isinstance(ref, dict) else ref
            if word:
                targets.append(word)
    return targets


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("jsonl", help="fichier .jsonl ou .jsonl.gz")
    parser.add_argument("db", help="base SQLite à créer")
    parser.add_argument("--limit", type=int, default=0,
                        help="ne lire que N lignes (test)")
    args = parser.parse_args()

    db_path = Path(args.db)
    if db_path.exists():
        db_path.unlink()

    con = sqlite3.connect(db_path)
    con.executescript(SCHEMA.read_text(encoding="utf-8"))
    cur = con.cursor()

    pending_forms = []      # (forme, lemme_texte)
    own_forms = []          # (forme, entry_id)
    pending_relations = []  # lignes prêtes
    entry_rows, sense_rows, example_rows = [], [], []
    next_entry = next_sense = next_example = 1
    count = skipped = 0

    def flush():
        nonlocal entry_rows, sense_rows, example_rows, pending_relations
        cur.executemany(
            "INSERT INTO entries(id,word,norm,pos,gender,ipa,etymology,"
            "is_lemma,source,source_url) VALUES (?,?,?,?,?,?,?,?,?,?)",
            entry_rows)
        cur.executemany(
            "INSERT INTO senses(id,entry_id,ord,definition,register,domain)"
            " VALUES (?,?,?,?,?,?)", sense_rows)
        cur.executemany(
            "INSERT INTO examples(id,sense_id,text) VALUES (?,?,?)",
            example_rows)
        cur.executemany(
            "INSERT INTO relations(entry_id,type,word) VALUES (?,?,?)",
            pending_relations)
        entry_rows, sense_rows, example_rows = [], [], []
        pending_relations = []

    with open_text(args.jsonl) as handle:
        for line_no, line in enumerate(handle, 1):
            if args.limit and line_no > args.limit:
                break
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                skipped += 1
                continue

            lang = entry.get("lang_code")
            if lang and lang != "fr":
                skipped += 1
                continue
            word = (entry.get("word") or "").strip()
            if not word:
                skipped += 1
                continue

            targets = form_of_targets(entry)
            is_lemma = 0 if targets else 1
            for target in targets:
                pending_forms.append((word, target))

            entry_id = next_entry
            next_entry += 1
            pos = POS_FR.get(entry.get("pos"), entry.get("pos"))
            entry_rows.append((
                entry_id, word, normalize(word), pos, gender_of(entry),
                first_ipa(entry), etymology_of(entry),
                is_lemma, "wiktionnaire",
                WIKI_URL + quote(word.replace(" ", "_")),
            ))

            order = 0
            for sense in entry.get("senses", []):
                definition = clean_definition(sense)
                if not definition:
                    continue
                order += 1
                sense_id = next_sense
                next_sense += 1
                sense_rows.append((sense_id, entry_id, order, definition,
                                   sense_register(sense), sense_domain(sense)))
                for ex in sense.get("examples", []):
                    text = (ex.get("text") or "").strip() if isinstance(ex, dict) else ""
                    if text:
                        example_rows.append((next_example, sense_id, text))
                        next_example += 1

            for key, rel_type in REL_TYPES.items():
                if not rel_type:
                    continue
                seen = set()
                collected = list(entry.get(key, []))
                for sense in entry.get("senses", []):
                    collected.extend(sense.get(key, []))
                for item in collected:
                    rel_word = item.get("word") if isinstance(item, dict) else item
                    if rel_word and rel_word not in seen:
                        seen.add(rel_word)
                        pending_relations.append((entry_id, rel_type, rel_word))

            for form in entry.get("forms", []):
                form_text = (form.get("form") or "").strip()
                if form_text and form_text != word and form_text != "-":
                    own_forms.append((form_text, entry_id))

            count += 1
            if len(entry_rows) >= BATCH:
                flush()
                print(f"  {count} entrées…", file=sys.stderr)

    flush()

    # Résolution des formes fléchies -> lemme (on préfère les vrais lemmes)
    lemma_ids = {}
    for entry_id, word, is_lemma in cur.execute(
            "SELECT id, word, is_lemma FROM entries ORDER BY is_lemma ASC, id DESC"):
        lemma_ids[word] = entry_id  # le dernier écrit gagne : lemme prioritaire

    form_rows = set()
    for form_text, lemma_word in pending_forms:
        target_id = lemma_ids.get(lemma_word)
        if target_id:
            form_rows.add((form_text, normalize(form_text), target_id))
    for form_text, entry_id in own_forms:
        form_rows.add((form_text, normalize(form_text), entry_id))
    cur.executemany("INSERT OR IGNORE INTO forms(form,norm,entry_id) VALUES (?,?,?)",
                    form_rows)

    # Fréquence provisoire : les lemmes courts passent devant dans l'autocomplétion
    cur.execute("UPDATE entries SET freq = CASE WHEN is_lemma=1 THEN "
                "MAX(0, 100 - length(word)) ELSE 0 END")

    cur.execute("INSERT INTO search_fts(search_fts) VALUES ('rebuild')")

    meta = {
        "version": "1",
        "source": "Wiktionnaire (fr.wiktionary.org)",
        "licence": "CC BY-SA 4.0",
        "licence_url": "https://creativecommons.org/licenses/by-sa/4.0/deed.fr",
        "attribution": "Contenu issu du Wiktionnaire et de ses contributeurs, "
                       "modifié (restructuré) pour cette application.",
        "entrees": str(count),
    }
    cur.executemany("INSERT INTO meta(key,value) VALUES (?,?)", meta.items())

    con.commit()
    con.execute("PRAGMA optimize")
    con.execute("VACUUM")
    con.close()

    size = db_path.stat().st_size / 1_000_000
    print(f"Terminé : {count} entrées, {skipped} lignes ignorées, "
          f"{size:.1f} Mo -> {db_path}")


if __name__ == "__main__":
    main()
