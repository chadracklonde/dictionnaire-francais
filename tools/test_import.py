#!/usr/bin/env python3
"""Vérifie une base générée : python3 test_import.py dictionnaire.db"""
import sqlite3
import sys

con = sqlite3.connect(sys.argv[1])
ok = True


def check(label, condition, detail=""):
    global ok
    ok = ok and condition
    print(("OK   " if condition else "ÉCHEC"), label, detail)


def q(sql, *params):
    return con.execute(sql, params).fetchall()


# 1. Recherche par préfixe, sans accents (« ecol » trouve « école »)
rows = q("SELECT e.word FROM search_fts f JOIN entries e ON e.id=f.rowid "
         "WHERE search_fts MATCH 'norm:ecol*'")
check("préfixe sans accent : ecol* -> école", ("école",) in rows, str(rows))

# 2. Ligature : « oeuvre » trouve « œuvre »
rows = q("SELECT word FROM entries WHERE norm = 'oeuvre'")
check("ligature : oeuvre -> œuvre", rows == [("œuvre",)], str(rows))

# 3. Forme fléchie -> lemme
rows = q("SELECT e.word FROM forms f JOIN entries e ON e.id=f.entry_id "
         "WHERE f.norm = 'mangeons'")
check("forme : mangeons -> manger", rows == [("manger",)], str(rows))
rows = q("SELECT e.word FROM forms f JOIN entries e ON e.id=f.entry_id "
         "WHERE f.norm = 'belles'")
check("forme : belles -> beau", ("beau",) in rows, str(rows))

rows = q("SELECT i.kind, i.form FROM inflections i JOIN entries e ON e.id=i.entry_id "
         "WHERE e.word = 'beau'")
check("accord : belles = féminin pluriel de beau", ("fp", "belles") in rows, str(rows))

# 4. Définitions, exemples, registre, domaine
rows = q("SELECT s.ord, s.register FROM senses s JOIN entries e ON e.id=s.entry_id "
         "WHERE e.word='manger' ORDER BY s.ord")
check("manger : 2 sens, le 2e familier", rows == [(1, None), (2, "familier")], str(rows))
rows = q("SELECT s.domain FROM senses s JOIN entries e ON e.id=s.entry_id "
         "WHERE e.word='droit' AND s.ord=1")
check("droit : domaine « droit »", rows == [("droit",)], str(rows))

# 5. Relations
rows = q("SELECT r.type, r.word FROM relations r JOIN entries e ON e.id=r.entry_id "
         "WHERE e.word='beau' ORDER BY type")
check("beau : antonyme laid + synonyme joli",
      ("antonyme", "laid") in rows and ("synonyme", "joli") in rows, str(rows))

# 6. Genre, prononciation, source
rows = q("SELECT gender, ipa FROM entries WHERE word='école'")
check("école : féminin + API",
      rows and rows[0][0] == "f" and rows[0][1], str(rows))

# 7. Langues étrangères ignorées, métadonnées de licence présentes
check("mot anglais ignoré", q("SELECT 1 FROM entries WHERE word='house'") == [])
meta = dict(q("SELECT key, value FROM meta"))
check("licence CC BY-SA 4.0 dans meta", meta.get("licence") == "CC BY-SA 4.0")

print("\nTout est OK" if ok else "\nDes tests ont échoué")
sys.exit(0 if ok else 1)
