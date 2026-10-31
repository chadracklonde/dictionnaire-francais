#!/usr/bin/env python3
"""Prépare les assets de l'application Flutter.

- découpe dictionnaire.db en morceaux de 20 Mo (assets/db/part_000, ...)
  avec un manifest.json (version, nombre de morceaux)
- copie conjugation_models.json dans assets/

    python3 build_assets.py dictionnaire.db
    python3 build_assets.py dictionnaire.db --chunk-mb 10
"""
import argparse
import json
import shutil
import sqlite3
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "app" / "assets"
MODELS = ROOT / "engine" / "data" / "conjugation_models.json"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("db", help="base générée par import_wiktionnaire.py")
    parser.add_argument("--chunk-mb", type=int, default=20)
    args = parser.parse_args()

    db = Path(args.db)
    if not db.exists():
        raise SystemExit(f"Fichier introuvable : {db}")

    out = ASSETS / "db"
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    chunk = args.chunk_mb * 1_000_000
    parts = 0
    with db.open("rb") as src:
        while True:
            data = src.read(chunk)
            if not data:
                break
            (out / f"part_{parts:03d}").write_bytes(data)
            parts += 1

    size = db.stat().st_size
    manifest = {
        "version": f"{date.today().isoformat()}-{size}",
        "parts": parts,
        "size": size,
    }
    con = sqlite3.connect(db)
    manifest["words"] = con.execute("SELECT COUNT(DISTINCT word) FROM entries").fetchone()[0]
    manifest["verbs"] = con.execute(
        "SELECT COUNT(DISTINCT word) FROM entries WHERE pos='verbe' AND is_lemma=1 AND word NOT LIKE '% %'"
    ).fetchone()[0]
    con.close()
    print(f"{manifest['words']} mots, {manifest['verbs']} verbes")
    (out / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    shutil.copyfile(MODELS, ASSETS / "conjugation_models.json")
    print(f"{parts} morceaux ({size / 1_000_000:.1f} Mo) -> {out}")
    print(f"Modèles de conjugaison copiés -> {ASSETS / 'conjugation_models.json'}")


if __name__ == "__main__":
    main()
