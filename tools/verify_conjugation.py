#!/usr/bin/env python3
"""Compare le moteur de conjugaison aux formes fléchies du Wiktionnaire.

Pour chaque verbe de la base, toutes les formes simples générées (présent,
imparfait, passé simple, futur, conditionnel, subjonctif, impératif,
participes) doivent exister dans la table `forms` de la base, rattachées au
même verbe. Chaque écart est soit une erreur du moteur à corriger, soit un
verbe irrégulier à ajouter à conjugation_models.json, soit une lacune des
données.

    python3 verify_conjugation.py dictionnaire.db
    python3 verify_conjugation.py dictionnaire.db --csv ecarts.csv --max 50
"""
import argparse
import csv
import sqlite3
import sys
from collections import Counter

from conjugation_ref import Conjugator, subj_imparfait


def all_forms(conj, inf):
    """Formes simples (sans pronoms) générées pour un infinitif."""
    s = conj.simple_forms(inf)
    if s is None:
        return None
    forms = set()
    for key in ("pres", "impf", "ps", "fut", "cond", "subj", "imp"):
        forms.update(s[key] or [])
    forms.update(subj_imparfait(s["ps"]) or [])
    forms.add(s["prp"])
    forms.add(s["pp"])
    # accords du participe passé (féminin, pluriel)
    forms.update({s["pp"] + "e", s["pp"] + "s", s["pp"] + "es"})
    # l'infinitif lui-même est le lemme : rien à vérifier
    return {f for f in forms if f}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("db")
    parser.add_argument("--csv", help="écrire les écarts dans ce fichier")
    parser.add_argument("--max", type=int, default=30,
                        help="nombre de verbes en écart à afficher")
    args = parser.parse_args()

    con = sqlite3.connect(args.db)
    verbs = [row[0] for row in con.execute(
        "SELECT DISTINCT word FROM entries WHERE pos = 'verbe' AND is_lemma = 1 AND word NOT LIKE '% %' "
        "AND (word LIKE '%er' OR word LIKE '%ir' OR word LIKE '%re' OR word LIKE '%oir')")]
    known = set(con.execute(
        "SELECT f.form, e.word FROM forms f JOIN entries e ON e.id = f.entry_id "
        "WHERE e.pos = 'verbe'"))
    print(f"{len(verbs)} verbes, {len(known)} formes fléchies connues")

    conj = Conjugator()
    unknown_verbs, perfect, gaps = [], 0, []
    missing_by_suffix = Counter()

    for inf in verbs:
        forms = all_forms(conj, inf)
        if forms is None:
            unknown_verbs.append(inf)
            continue
        missing = sorted(f for f in forms if f != inf and (f, inf) not in known)
        if missing:
            gaps.append((inf, missing))
            missing_by_suffix[inf[-3:]] += 1
        else:
            perfect += 1

    checked = len(verbs) - len(unknown_verbs)
    print(f"\nVerbes vérifiés      : {checked}")
    if checked:
        print(f"Tout concorde        : {perfect} ({100 * perfect / checked:.1f} %)")
    print(f"Avec des écarts      : {len(gaps)}")
    print(f"Non reconnus (moteur): {len(unknown_verbs)}")

    if missing_by_suffix:
        print("\nTerminaisons les plus touchées :",
              ", ".join(f"-{k} ({v})" for k, v in missing_by_suffix.most_common(10)))
    for inf, missing in gaps[:args.max]:
        print(f"  {inf}: {len(missing)} formes absentes, ex. {', '.join(missing[:5])}")
    if unknown_verbs:
        print("\nVerbes non reconnus (ex.) :", ", ".join(unknown_verbs[:20]))

    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as handle:
            writer = csv.writer(handle)
            writer.writerow(["verbe", "formes_absentes"])
            for inf, missing in gaps:
                writer.writerow([inf, " ".join(missing)])
            for inf in unknown_verbs:
                writer.writerow([inf, "(verbe non reconnu)"])
        print(f"\nÉcarts écrits dans {args.csv}")
    sys.exit(0)


if __name__ == "__main__":
    main()
