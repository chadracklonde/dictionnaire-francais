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
import re
import sqlite3
import sys
import unicodedata
from pathlib import Path
from urllib.parse import quote

SCHEMA = Path(__file__).with_name("schema.sql")
WIKI_URL = "https://fr.wiktionary.org/wiki/"
BATCH = 20000
MAX_EXAMPLES = 2        # exemples conservés par acception
MAX_EXAMPLES_ENTRY = 3  # ... et par entrée
MAX_EXAMPLE_CHARS = 300
MAX_ETYMOLOGY_CHARS = 700
MAX_RELATIONS = {"synonyme": 15, "antonyme": 15, "derive": 20}

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


# « il/elle/on organise », « j’organise », « que tu lises », « je me lave »…
# -> on retire le pronom pour retrouver la forme simple (« organise »).
PRONOUNS = re.compile(
    r"^(?:que |qu[’'])?(?:j[’']|je |tu |il/elle/on |nous |vous |ils/elles )"
    r"(?:(?:me |te |se |nous |vous )|[mts][’'])?"
)


def usable_form(form_text: str, lemma_word: str, pos):
    """Forme à indexer pour la recherche, ou None.

    Le Wiktionnaire liste aussi des tournures (« j’ai organisé »,
    « en organisant ») : inutiles pour retrouver un mot, on les écarte.
    """
    text = form_text.strip()
    if pos == "verbe":
        text = PRONOUNS.sub("", text, count=1).strip()
        if " " in text:
            return None
    elif " " in text and " " not in lemma_word:
        return None
    if not text or text == "-" or "/" in text or "(" in text:
        return None
    return text


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
    if text and len(text) > MAX_ETYMOLOGY_CHARS:
        text = text[:MAX_ETYMOLOGY_CHARS].rsplit(" ", 1)[0] + "…"
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


_KIND_PATTERNS = [
    (re.compile(r"^masculin et féminin plurie"), "p"),
    (re.compile(r"^féminin plurie"), "fp"),
    (re.compile(r"^masculin plurie"), "mp"),
    (re.compile(r"^féminin singulier"), "fs"),
    (re.compile(r"^masculin singulier"), "ms"),
    (re.compile(r"^féminin\b"), "fs"),
    (re.compile(r"^masculin\b"), "ms"),
    (re.compile(r"^plurie"), "p"),
    (re.compile(r"^singulier\b"), "s"),
]


def inflection_kind(gloss: str):
    """« Féminin pluriel de beau. » -> 'fp' ; None si ce n'est pas un accord."""
    g = re.sub(r"^(\([^)]*\)\s*)+", "", (gloss or "").strip().lower())
    for pattern, kind in _KIND_PATTERNS:
        if pattern.match(g):
            return kind
    return None


def form_kinds(entry: dict, target: str):
    """Accords (ms, fs, mp, fp, s, p) que cette forme représente pour [target]."""
    kinds = set()
    for sense in entry.get("senses", []):
        refs = sense.get("form_of") or sense.get("alt_of") or []
        words = [r.get("word") if isinstance(r, dict) else r for r in refs]
        if target not in words:
            continue
        for gloss in sense.get("glosses") or []:
            kind = inflection_kind(gloss)
            if kind:
                kinds.add(kind)
    return kinds or {None}


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

    cur.execute("CREATE TEMP TABLE tmp_forms(form TEXT, norm TEXT, lemma TEXT, pos TEXT, kind TEXT)")
    own_forms = []          # (forme, entry_id)
    pending_forms = []      # (forme, lemme, catégorie) -> table temporaire
    pending_relations = []
    entry_rows, sense_rows, example_rows = [], [], []
    next_entry = next_sense = next_example = 1
    count = redirects = skipped = 0

    def flush():
        nonlocal entry_rows, sense_rows, example_rows, pending_relations
        nonlocal pending_forms, own_forms
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
        cur.executemany("INSERT INTO tmp_forms VALUES (?,?,?,?,?)", pending_forms)
        cur.executemany(
            "INSERT OR IGNORE INTO forms(norm,entry_id,form) VALUES (?,?,?)",
            own_forms)
        entry_rows, sense_rows, example_rows = [], [], []
        pending_relations, pending_forms, own_forms = [], [], []

    with open_text(args.jsonl) as handle:
        for line_no, line in enumerate(handle, 1):
            if args.limit and line_no > args.limit:
                break
            if line_no % 500000 == 0:
                print(f"  {line_no} lignes lues, {count} entrées, "
                      f"{redirects} renvois…", file=sys.stderr, flush=True)
            # Saut rapide des autres langues, sans décoder le JSON
            if ('"lang_code"' in line and '"lang_code": "fr"' not in line
                    and '"lang_code":"fr"' not in line):
                skipped += 1
                continue
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

            pos = POS_FR.get(entry.get("pos"), entry.get("pos"))

            # Forme fléchie ou variante : simple renvoi vers son lemme
            targets = form_of_targets(entry)
            if targets:
                if " " in word and not any(" " in t for t in targets):
                    redirects += 1
                    continue
                for target in set(targets):
                    for kind in form_kinds(entry, target):
                        pending_forms.append(
                            (word, normalize(word), target, pos, kind))
                redirects += 1
                if len(pending_forms) >= BATCH:
                    flush()
                continue

            entry_id = next_entry
            next_entry += 1
            entry_rows.append((
                entry_id, word, normalize(word), pos, gender_of(entry),
                first_ipa(entry), etymology_of(entry),
                1, "wiktionnaire",
                None,   # l'adresse du Wiktionnaire est recalculée à l'affichage
            ))

            order = 0
            entry_examples = 0
            for sense in entry.get("senses", []):
                definition = clean_definition(sense)
                if not definition:
                    continue
                order += 1
                sense_id = next_sense
                next_sense += 1
                sense_rows.append((sense_id, entry_id, order, definition,
                                   sense_register(sense), sense_domain(sense)))
                kept = 0
                for ex in sense.get("examples", []):
                    if kept >= MAX_EXAMPLES or entry_examples >= MAX_EXAMPLES_ENTRY:
                        break
                    text = (ex.get("text") or "").strip() if isinstance(ex, dict) else ""
                    if text and len(text) <= MAX_EXAMPLE_CHARS:
                        example_rows.append((next_example, sense_id, text))
                        next_example += 1
                        kept += 1
                        entry_examples += 1

            for key, rel_type in REL_TYPES.items():
                if not rel_type:
                    continue
                seen = set()
                collected = list(entry.get(key, []))
                for sense in entry.get("senses", []):
                    collected.extend(sense.get(key, []))
                for item in collected:
                    if len(seen) >= MAX_RELATIONS.get(rel_type, 15):
                        break
                    rel_word = item.get("word") if isinstance(item, dict) else item
                    if rel_word and rel_word not in seen:
                        seen.add(rel_word)
                        pending_relations.append((entry_id, rel_type, rel_word))

            for form in entry.get("forms", []):
                form_text = usable_form(form.get("form") or "", word, pos)
                if form_text and form_text != word:
                    n = normalize(form_text)
                    own_forms.append((n, entry_id, "" if n == form_text else form_text))

            count += 1
            if len(entry_rows) >= BATCH:
                flush()

    flush()
    print(f"  lecture terminée : {count} entrées, {redirects} renvois",
          file=sys.stderr, flush=True)

    # Résolution des renvois -> lemme (même catégorie d'abord, sinon n'importe laquelle)
    cur.execute("""
        INSERT OR IGNORE INTO forms(norm, entry_id, form)
        SELECT norm, id, CASE WHEN form = norm THEN '' ELSE form END FROM (
            SELECT t.form AS form, t.norm AS norm,
                   COALESCE(
                     (SELECT e.id FROM entries e WHERE e.word = t.lemma AND e.pos = t.pos LIMIT 1),
                     (SELECT e.id FROM entries e WHERE e.word = t.lemma LIMIT 1)
                   ) AS id
            FROM tmp_forms t
        ) WHERE id IS NOT NULL
    """)
    cur.execute("""
        INSERT OR IGNORE INTO inflections(entry_id, kind, form)
        SELECT id, kind, form FROM (
            SELECT t.form AS form, t.kind AS kind,
                   COALESCE(
                     (SELECT e.id FROM entries e WHERE e.word = t.lemma AND e.pos = t.pos LIMIT 1),
                     (SELECT e.id FROM entries e WHERE e.word = t.lemma LIMIT 1)
                   ) AS id
            FROM tmp_forms t
            WHERE t.kind IS NOT NULL AND t.pos IN ('nom', 'adjectif')
        ) WHERE id IS NOT NULL
    """)
    cur.execute("DROP TABLE tmp_forms")

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
        "formes": str(cur.execute("SELECT COUNT(*) FROM forms").fetchone()[0]),
    }
    cur.executemany("INSERT INTO meta(key,value) VALUES (?,?)", meta.items())

    con.commit()
    con.execute("PRAGMA optimize")
    con.execute("VACUUM")
    con.close()

    size = db_path.stat().st_size / 1_000_000
    print(f"Terminé : {count} entrées, {redirects} renvois, {skipped} lignes ignorées, "
          f"{size:.1f} Mo -> {db_path}")


if __name__ == "__main__":
    main()
