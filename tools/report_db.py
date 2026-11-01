#!/usr/bin/env python3
"""Rapport sur une base générée : taille par table, couverture des champs,
formes fléchies. Chaque ligne est aussi émise comme annotation GitHub.

    python3 report_db.py dictionnaire.db
"""
import os
import sqlite3
import sys

db = sys.argv[1]
con = sqlite3.connect(db)
lines = []
VERBES = "SELECT COUNT(DISTINCT word) FROM entries WHERE pos='verbe' AND is_lemma=1"


def out(text):
    lines.append(text)
    print(text)


def one(sql):
    return con.execute(sql).fetchone()[0]


out(f"taille fichier : {os.path.getsize(db) / 1e6:.1f} Mo")
out(f"entrees : {one('SELECT COUNT(*) FROM entries')}"
    f" | mots distincts : {one('SELECT COUNT(DISTINCT word) FROM entries')}"
    f" | lemmes : {one('SELECT COUNT(*) FROM entries WHERE is_lemma=1')}"
    f" | verbes (lemmes) : {one(VERBES)}")
for t in ("senses", "examples", "relations", "forms", "inflections"):
    out(f"lignes {t} : {one(f'SELECT COUNT(*) FROM {t}')}")
out("accords par type : " + ", ".join(f"{k}={c}" for k, c in con.execute(
    "SELECT kind, COUNT(*) FROM inflections GROUP BY kind ORDER BY 2 DESC")))
out("exemples d'accords : " + " ; ".join(f"{w} {k}={f}" for w, k, f in con.execute(
    "SELECT e.word, i.kind, i.form FROM inflections i JOIN entries e ON e.id=i.entry_id "
    "WHERE e.word IN ('beau','castélorien','cheval','œil','acteur','heureux') ORDER BY e.word, i.kind")))
n = one("SELECT COUNT(*) FROM entries")
for col in ("gender", "ipa", "etymology"):
    c = one(f"SELECT COUNT(*) FROM entries WHERE {col} IS NOT NULL AND {col}<>''")
    out(f"couverture {col} : {c} / {n}")
Q_SPACE = "SELECT COUNT(*) FROM forms WHERE norm LIKE '% %'"
Q_SPACE_EX = "SELECT norm FROM forms WHERE norm LIKE '% %' LIMIT 8"
Q_APOS = "SELECT COUNT(*) FROM forms WHERE norm LIKE '%''%'"
out(f"formes avec espace : {one(Q_SPACE)} | exemples : {[r[0] for r in con.execute(Q_SPACE_EX)]}")
out(f"formes avec apostrophe : {one(Q_APOS)}")
out(f"formes distinctes (norm) : {one('SELECT COUNT(DISTINCT norm) FROM forms')}")
try:
    rows = con.execute("SELECT name, SUM(pgsize) FROM dbstat GROUP BY name ORDER BY 2 DESC LIMIT 12").fetchall()
    out("taille par objet : " + ", ".join(f"{a}={b / 1e6:.1f}Mo" for a, b in rows))
except sqlite3.Error as e:
    out(f"dbstat indisponible ({e})")
rows = con.execute("SELECT pos, COUNT(*) FROM entries GROUP BY pos ORDER BY 2 DESC LIMIT 10").fetchall()
out("categories : " + ", ".join(f"{a}={b}" for a, b in rows))
for w in ("manger", "lire", "mangeons", "belles", "ecole"):
    r = con.execute("SELECT word,pos,is_lemma FROM entries WHERE norm=? LIMIT 3", (w,)).fetchall()
    f = con.execute("SELECT COUNT(*) FROM forms WHERE norm=?", (w,)).fetchone()[0]
    out(f"test {w} : entrees={r} formes={f}")

print("::notice::RAPPORT-COMPLET " + " | ".join(lines).replace("\n", " "))
