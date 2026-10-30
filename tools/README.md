# Outils de génération de la base du dictionnaire

## 1. Récupérer les données (sur ton ordinateur)

Télécharge le fichier JSONL du français depuis kaikki.org (extraction du
Wiktionnaire par wiktextract). Il fait plusieurs centaines de Mo. Choisis
l'extraction du **Wiktionnaire français**, et vérifie que les lignes
contiennent bien `"lang_code": "fr"`.

## 2. Générer la base

```bash
python3 import_wiktionnaire.py kaikki-fr.jsonl dictionnaire.db
# Test rapide sur 5000 lignes :
python3 import_wiktionnaire.py kaikki-fr.jsonl test.db --limit 5000
```

Aucune dépendance : Python 3 et SQLite suffisent.

## 3. Vérifier

```bash
python3 test_import.py dictionnaire.db
```

## Licence

Le contenu vient du Wiktionnaire : CC BY-SA 4.0.
La table `meta` de la base contient l'attribution à afficher dans l'écran
« À propos / Licences » de l'application. Chaque entrée garde le lien vers
sa page d'origine (`source_url`).
