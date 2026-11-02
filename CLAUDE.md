# Dictionnaire et Conjugaison — dossier complet du projet

> Ce fichier contient tout ce qu'il faut pour reprendre le projet avec Claude (Claude Code, claude.ai ou autre).
> Il est dans le dépôt sous le nom `CLAUDE.md` : Claude Code le lit automatiquement à l'ouverture du dépôt.
> **Il ne contient aucun mot de passe.** Les secrets sont décrits (où ils sont, comment ils s'appellent), jamais écrits.
> Dernière mise à jour : 2 novembre 2026 · version publiée : 1.0.0 (code de version 1).

---

## 1. En bref

- **Nom** : Dictionnaire et Conjugaison (sous-titre de l'écran de démarrage : « en Français »)
- **Auteur / éditeur** : Chadrack Londe, Kindu (RDC)
- **But** : dictionnaire français monolingue + conjugaison, **100 % hors ligne**, grand public.
- **Plateformes** : Android (publié sur le Play Store), Windows, macOS.
- **Technologie** : Flutter (Dart) · base SQLite avec FTS5 · compilation entièrement par GitHub Actions (aucun SDK Flutter local requis).
- **Dépôt** : `chadracklonde/dictionnaire-francais` (public), branche `main`.
- **Identifiant Android (définitif, ne jamais changer)** : `com.chadracklonde.dictionnaire`
- **Contenu** : issu du Wiktionnaire (licence **CC BY-SA 4.0**), via l'extraction JSONL de kaikki.org. La mention de licence et de source est dans l'application (À propos, pied de fiche).
- **Chiffres** : 521 367 mots · 36 341 verbes conjugués · 20 temps par verbe (6 modes) · 320 354 formes d'accord.

## 2. Principes et décisions

1. **Monolingue français**, sans traductions pour la V1 (les traductions sont une option, non faite).
2. **Tout est hors ligne** : aucune connexion réseau, aucun compte, aucune publicité, aucune statistique. La politique de confidentialité l'affirme : toute fonction qui envoie des données oblige à la mettre à jour **avant** publication.
3. **Une seule compilation CI par lot de modifications** (pas après chaque étape) : on regroupe les changements puis on compile une fois.
4. **Accessibilité** : tout texte respecte WCAG AA (contraste 4,5:1 minimum), en thème clair et sombre.
5. Le titre de l'écran de démarrage (« Dictionnaire & Conjugaison en Français ») diffère encore du nom officiel (« Dictionnaire et Conjugaison ») : à trancher.
6. L'interface est en français, ton simple, pour le grand public.

## 3. Disposition du dépôt

```
.github/workflows/
  build.yml          Compile Android (APK + AAB), Windows, macOS ; tests
  data.yml           Génère la base de données depuis kaikki.org et la publie
app/                 L'application Flutter
  lib/main.dart, app.dart          Démarrage, thème (rouge/or/bleu), version affichée
  lib/data/                        Accès aux données et réglages
    db_installer.dart              Reconstruit la base au premier lancement (morceaux gz)
    dictionary_repository.dart     Toutes les requêtes SQL (recherche, suggestions, index, motif…)
    models.dart                    EntryData, Sense, SearchHit…
    user_store.dart                Favoris, historique, notes, réglages, sauvegarde JSON (SharedPreferences)
    speech.dart                    Prononciation (flutter_tts, fr-FR)
    notifier.dart                  Rappel quotidien du mot du jour (Android seulement)
    domain_labels.dart             Traduit les domaines anglais du Wiktionnaire (lexicography → lexicographie)
  lib/screens/                     Un fichier par écran (voir §5)
  assets/db/                       Base découpée en morceaux gz + manifest.json (une base de démonstration est versionnée ;
                                   la vraie base est téléchargée par la CI depuis la release `base-donnees`)
  assets/icon/                     logo.png, logo_full.png, logo_background.png, logo_foreground.png, book.png
  icons_config/                    Configuration flutter_launcher_icons (android/windows/macos)
engine/              Moteur de conjugaison en Dart pur (dictionnaire_engine), testé
  lib/conjugation.dart, data/conjugation_models.json, test/
tools/               Scripts Python
  import_wiktionnaire.py           Importe le JSONL kaikki dans SQLite
  schema.sql                       Schéma de la base
  conjugation_ref.py               Référence Python de la conjugaison (miroir du moteur Dart)
  verify_conjugation.py            Compare conjugaison calculée et formes du Wiktionnaire
  report_db.py                     Rapport de qualité (chiffres, exemples) émis comme annotations GitHub
  build_assets.py                  Découpe la base en morceaux gz pour les assets de l'app
  test_*.py, sample.jsonl          Tests
docs/confidentialite.html          Page de politique de confidentialité (GitHub Pages, si activé)
CONFIDENTIALITE.md                 Même politique, lisible directement sur GitHub (URL donnée à Google Play)
CLAUDE.md                          Ce fichier
```

## 4. Données

### 4.1 Source
`https://kaikki.org/dictionary/downloads/fr/fr-extract.jsonl.gz` (extraction Wiktionnaire français).

### 4.2 Régénérer la base (workflow `data.yml`)
1. Onglet Actions → « Générer la base de données » → Run workflow, avec `jsonl_url` = l'URL ci-dessus (champ `limit` vide pour tout importer).
2. La CI importe, vérifie, produit un rapport (annotation `RAPPORT-COMPLET`), compresse et **publie `dictionnaire.db.gz` dans la release `base-donnees`**.
3. Lancer ensuite `build.yml` : les builds téléchargent cette release, découpent la base (`tools/build_assets.py`) et l'embarquent.
Durée : plusieurs dizaines de minutes ; limite du job : 350 min.

### 4.3 Schéma (`tools/schema.sql`)
- `entries` (mot, `norm` = forme sans accents/ligatures, nature, genre, API, étymologie, `is_lemma`, `freq`, source…)
- `senses` (définition, registre, domaine) · `examples` · `relations` (synonymes, antonymes, etc.)
- `forms` (formes fléchies → lemme) · `search_fts` (FTS5 sur `norm`)
- `inflections(entry_id, kind, form, rank)` : accords ; `kind` ∈ ms, fs, mp, fp, s, p ; `rank` 1 = variante rare (masquée quand une forme courante existe)
- `meta` (licence, etc.)
Les mots fléchis sont des redirections : leur glose (« Féminin pluriel de beau. ») est analysée pour en tirer le type d'accord.

### 4.4 État de la qualité
- Conjugaison : 468/468 tests Python ; les écarts restants viennent surtout de lacunes du Wiktionnaire (concordance ≈ 96,8 %).
- Règle -eler/-eter : accent grave par défaut ; doublement pour une liste de familles (regex `DOUBLE_RE` dans `conjugation_ref.py` et `_doubleRe` dans `engine/lib/conjugation.dart` — **à garder identiques**).
- Cas connu : « œil » garde « zyeux » et « z’yeux » comme pluriels non rares.

## 5. Fonctionnalités de l'application

| Écran / fonction | Fichier | Détail |
|---|---|---|
| Accueil | `home_screen.dart` | Recherche, mot du jour, Outils, index A–Z, récemment consultés (en bas) |
| Recherche | `home_screen.dart`, `search_screen.dart` | Accents facultatifs, formes accordées/conjuguées → lemme, « Vouliez-vous dire » (Damerau-Levenshtein + proximité phonétique), raccourci « conjuguer manger » |
| Loupe | entête de chaque fiche et de l'accueil | Ouvre `SearchScreen` (historique si champ vide) |
| Fiche d'un mot | `entry_screen.dart` | Étymologie repliable, API, tableau des accords, boutons d'ancres (Définitions, Synonymes…), définitions à mots cliquables, exemples repliables, relations, lien Wiktionnaire, prononciation, copier, partager, favori, note, mot au hasard, retour accueil |
| Conjugaison | `conjugation_screen.dart` | 6 modes en onglets, 20 temps, copie d'un temps |
| Index alphabétique | `index_screen.dart` | Pagination par clé (norm, word) |
| Recherche par motif | `pattern_screen.dart` | `?` = une lettre, `*` = plusieurs ; GLOB SQLite |
| Favoris / historique | `favorites_screen.dart` | |
| Révision | `review_screen.dart` | Cartes de révision des favoris |
| Notes | `notes_screen.dart` | Une note par mot |
| Réglages | `settings_screen.dart` | Thème auto/clair/sombre, taille du texte, rappel quotidien, sauvegarde/restauration (texte JSON), tutoriel, À propos |
| Tutoriel | `tutorial_screen.dart` | 7 pages au premier lancement (drapeau `tutorialSeen`), rouvrable depuis Réglages |
| À propos et licences | `licenses_screen.dart` | Chiffres, licence CC BY-SA, source |
| Écran de démarrage | `install_screen.dart` | Préparation de la base (pourcentage), chiffres réels |

Paquets : sqflite_common_ffi, sqlite3_flutter_libs, shared_preferences, url_launcher, flutter_tts, share_plus, flutter_local_notifications (Android seulement), path, path_provider.

## 6. Identité visuelle
- Rouge du logo `#AF0B18` (splash dégradé `#F71918` → `#4A0010`), or `#F2B632`, bleu du livre `#1C486F`.
- Thème clair : entête rouge `#A50E1A` (blanc dessus 7,8:1), liens en bleu, note en or. Thème sombre : fond neutre, accents rose clair / bleu clair / or.
- Les couleurs de texte ont été calculées ≥ 4,5:1 ; garder cette règle à chaque changement (voir `_theme` dans `app/lib/app.dart`).

## 7. Compilation et publication

### 7.1 Workflow `build.yml`
Déclencheurs : push sur `main`, pull request, lancement manuel. Jobs : `tests` → `android`, `windows`, `macos`.
- Le projet Android est **généré à chaque build** (`flutter create --org com.chadracklonde --platforms=android .`) puis patché par script : étiquette de l'appli, intentions (lien https, TTS), permissions (notifications, démarrage), récepteurs de notifications, désucrage de bibliothèques Java, **signature**.
- Étape « Analyse » : `flutter analyze` ; en cas d'erreur, elles sont émises en annotation `ANALYSE …` (les journaux complets sont inaccessibles depuis Claude).
- Sortie Android : `app-release.apk` **et** `app-release.aab`, publiés dans la release **`apk-dernier`** (`dictionnaire-et-conjugaison.apk`, `dictionnaire-et-conjugaison.aab`) — téléchargement direct, sans zip.
- Windows et macOS : artefacts zip dans les résultats de la compilation.

### 7.2 Version
`app/pubspec.yaml` : `version: 1.0.0+1` (nom + code). `app/lib/app.dart` : `appVersion`. **À chaque nouvelle publication Play Store, augmenter le code de version (+2, +3…)** — Google refuse un code déjà utilisé.

### 7.3 Signature Android
- Clé : `dictionnaire-et-conjugaison.jks` (alias `dictionnaire`, PKCS12, RSA 2048, validité ≈ 27 ans). Empreinte SHA-256 du certificat :
  `24:BC:56:FA:EF:C9:E9:E1:C6:15:49:8A:F2:71:5F:BC:30:34:27:C7:CE:E3:DC:52:57:77:AC:5D:79:47:9A:F8`
- **Le fichier .jks et son mot de passe sont chez Chadrack** (sauvegarde à faire en deux endroits). **Sans eux, aucune mise à jour du Play Store n'est possible.** Ils ne sont pas dans le dépôt.
- Dans GitHub : 4 secrets d'Actions — `KEYSTORE_BASE64` (le .jks en base64), `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`. Sans eux, la CI signe avec la clé de débogage (avertissement) et l'APK n'est pas publiable.
- Les secrets ne peuvent pas être créés depuis une session Claude (accès bloqué) : les ajouter à la main dans Settings → Secrets and variables → Actions.

### 7.4 Play Store
- Application créée avec le nom « Dictionnaire et Conjugaison », langue fr-FR, gratuite, catégorie Livres et ouvrages de référence.
- Politique de confidentialité : `https://github.com/chadracklonde/dictionnaire-francais/blob/main/CONFIDENTIALITE.md`
- Public cible : 13 ans et plus (pas de « Famille »). Classification : référence/éducation ; le dictionnaire contient des mots vulgaires avec leur définition.
- Sécurité des données : aucune donnée collectée ni partagée.
- Autorisations à justifier : notifications (mot du jour) et réception du démarrage (reprogrammer le rappel).
- Version 1.0.0 : `.aab` de 189 Mo téléversé. La base de 347 Mo est stockée compressée dans les assets ; le module principal reste sous la limite de 200 Mo. **Si Google refuse pour la taille : passer au Play Asset Delivery** (non fait).
- Visuels produits : icône 512×512, image de présentation 1024×500, 8 captures téléphone (1080×2160), 3 visuels tablette (2560×1600), 4 visuels ordinateur/Chromebook (2560×1440). Les captures montrent les écrans de l'application (les visuels tablette/ordinateur sont des cadres autour de captures de téléphone, pas de vraies captures de tablette).

## 8. Reprendre le travail avec Claude

### 8.1 Contraintes de l'environnement Claude (Claude Code sur le web)
- Pas de SDK Flutter ni de `pub.dev` : **le code Dart n'est jamais compilé localement**. La validation passe par la CI (`flutter analyze` + build). Relire soigneusement les imports et types avant de pousser.
- Pas d'accès à kaikki.org ni à `storage.googleapis.com` depuis la session ; l'import de données se fait via la CI.
- L'API GraphQL de GitHub est bloquée : `gh workflow run` échoue. Lancer un workflow par l'API REST :
  `gh api -X POST repos/chadracklonde/dictionnaire-francais/actions/workflows/build.yml/dispatches -f ref=main`
- L'API des secrets et de GitHub Pages est bloquée : ces réglages se font à la main dans l'interface GitHub.
- Les journaux de jobs ne sont pas téléchargeables (403) : lire les **annotations** (`gh api repos/…/check-runs/<id>/annotations`).
- Attendre la fin d'une compilation : interroger `actions/runs/<id>` jusqu'à `status=completed`, puis `actions/runs/<id>/jobs`.

### 8.2 Modèle de message pour redémarrer
> Je reprends mon application « Dictionnaire et Conjugaison » (dépôt chadracklonde/dictionnaire-francais). Lis `CLAUDE.md` au complet. Je voudrais : [décrire la modification]. Regroupe les changements et ne lance la CI qu'une seule fois à la fin. Vérifie les contrastes WCAG AA si tu touches aux couleurs. Augmente le code de version dans `pubspec.yaml` si c'est pour une nouvelle publication.

### 8.3 Pour publier une mise à jour
1. Modifier le code, **augmenter le code de version** (`1.0.1+2`, etc.), mettre à jour `appVersion`.
2. Pousser sur `main` → la CI produit l'`.aab` dans la release `apk-dernier`.
3. Play Console → Production → Créer une version → téléverser l'`.aab` → renseigner les notes de version (format `<fr-FR>…</fr-FR>`).
4. Si la base a changé : relancer `data.yml` d'abord, puis `build.yml`.

## 9. Idées et dette connue
- **À faire / décider** : harmoniser le titre de l'écran de démarrage ; vérifier le Play Asset Delivery si Google refuse la taille ; retoucher « œil » (pluriels rares) ; compléter `domain_labels.dart` si des domaines restent en anglais.
- **Améliorations possibles** : traductions (option du lot D, non faite) ; widget de mot du jour ; équivalences phonétiques plus fines dans les suggestions ; autres cas de conjugaison (-érer, inclure…) ; vraies captures de tablette ; mise en page adaptée aux grands écrans.
- **Non testé sur appareil par Claude** : tout le Dart a été validé par la CI seulement ; les retours de Chadrack sur téléphone ont servi de test réel.
- Le tutoriel et les textes de la fiche Play Store sont en français uniquement.

## 10. Historique résumé des lots
- **Base** : import Wiktionnaire réel (521 k mots, 36 k verbes), moteur de conjugaison, CI trois plateformes.
- **Lot A** : suggestions orthographiques, prononciation.
- **Lot B** : recherche par motif, mots liés, copier/partager, notification quotidienne, favoris/révision, réglages.
- **Lot C** : mots cliquables, exemples repliables, mot au hasard, notes, sauvegarde/restauration, mise en page des fiches.
- **Lot D** : tableau des accords (singulier/pluriel, masculin/féminin).
- **Ergonomie** : loupe d'entête, récents sous l'index, retour accueil, recherche phonétique, ancres de fiche, « conjuguer … », copie d'un temps.
- **Identité visuelle** : thème rouge/or/bleu conforme WCAG AA.
- **Publication** : tutoriel de bienvenue, signature, `.aab`, version 1.0.0, politique de confidentialité, visuels du Play Store.
