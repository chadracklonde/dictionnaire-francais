# Application Dictionnaire (Flutter)

Android, Windows et macOS à partir d'un seul code. Tout fonctionne hors ligne.

## Lancer l'application

```bash
cd dictionnaire/app

# 1. Générer les dossiers de plateforme (une seule fois).
#    Ne remplace pas lib/ ; si lib/main.dart est modifié, le restaurer.
flutter create --platforms=android,windows,macos .

flutter pub get
flutter run -d windows        # ou -d macos, ou un appareil Android
```

Le dossier `assets/` contient pour l'instant **une base de démonstration de 7 mots**
(manger, beau, école, droit…). Pour mettre la vraie base :

```bash
cd dictionnaire/tools
python3 import_wiktionnaire.py kaikki-fr.jsonl dictionnaire.db
python3 build_assets.py dictionnaire.db      # découpe en morceaux de 20 Mo
```

## Ce que fait l'application

- **Accueil** : recherche instantanée avec autocomplétion (sans accents,
  « ecole » trouve « école »), mot du jour, mots récemment consultés
- **Formes fléchies** : « mangeons » propose *manger*
- **Fiche d'un mot** : définitions, exemples, registre, domaine, synonymes,
  antonymes, dérivés, étymologie, lien vers le Wiktionnaire
- **Conjugaison** : tous les modes et temps (bouton « Conjuguer » sur les verbes)
- **Favoris et historique**, mode sombre automatique
- **À propos et licences** : attribution CC BY-SA 4.0

## Premier lancement

La base est livrée en morceaux dans `assets/db/` et copiée une fois dans le
dossier de l'application (écran de progression). SQLite est utilisé via FFI
sur toutes les plateformes (`sqflite_common_ffi` + `sqlite3_flutter_libs`),
pour avoir le même SQLite, avec FTS5, partout.

## À vérifier au premier essai

Ce code n'a pas pu être compilé là où il a été écrit (Flutter indisponible).
Si `flutter run` signale une erreur, c'est probablement ici :

- **Android** : ajouter dans `android/app/src/main/AndroidManifest.xml`, dans
  `<manifest>`, pour que le lien « Voir sur le Wiktionnaire » fonctionne :
  ```xml
  <queries>
    <intent>
      <action android:name="android.intent.action.VIEW"/>
      <data android:scheme="https"/>
    </intent>
  </queries>
  ```
- **Taille Android** : une base complète (50 à 200 Mo) dépasse la limite de
  200 Mo du Play Store avec l'application ; prévoir Play Asset Delivery pour
  `assets/db/` au moment de la publication.
- **macOS** : si une erreur de sandbox apparaît, vérifier les entitlements
  dans `macos/Runner/*.entitlements`.
