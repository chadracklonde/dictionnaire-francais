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
    print("::notice::RAPPORT " + text)


def one(sql):
    return con.execute(sql).fetchone()[0]


out(f"taille fichier : {os.path.getsize(db) / 1e6:.1f} Mo")
out(f"entrees : {one('SELECT COUNT(*) FROM entries')}"
    f" | mots distincts : {one('SELECT COUNT(DISTINCT word) FROM entries')}"
    f" | lemmes : {one('SELECT COUNT(*) FROM entries WHERE is_lemma=1')}"
    f" | verbes (lemmes) : {one(VERBES)}")
for t in ("senses", "examples", "relations", "forms"):
    out(f"lignes {t} : {one(f'SELECT COUNT(*) FROM {t}')}")
n = one("SELECT COUNT(*) FROM entries")
for col in ("gender", "ipa", "etymology"):
    c = one(f"SELECT COUNT(*) FROM entries WHERE {col} IS NOT NULL AND {col}<>''")
    out(f"couverture {col} : {c} / {n}")
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
