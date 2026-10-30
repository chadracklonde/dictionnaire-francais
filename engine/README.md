# Moteur de conjugaison (Dart pur)

Génère tous les modes et temps d'un verbe français, y compris les verbes
pronominaux (« se laver », « s'appeler ») et les temps composés.

## Fichiers

- `lib/conjugation.dart` : le moteur
- `data/conjugation_models.json` : les verbes irréguliers (64 modèles, regroupés par terminaison)
- `test/conjugation_test.dart` + `test/conjugation_expected.json` : tests
- `../tools/conjugation_ref.py` : version Python de référence (même algorithme)
- `../tools/verify_conjugation.py` : comparaison avec les formes du Wiktionnaire

## Tester

```bash
cd engine
dart pub get
dart test
```

## Utiliser dans l'application Flutter

Déclare `data/conjugation_models.json` comme asset, puis :

```dart
final c = Conjugator.fromJson(
    await rootBundle.loadString('assets/conjugation_models.json'));
final r = c.conjugate('manger');          // null si le verbe est inconnu
r?.moods['indicatif']!['present'];        // [je mange, tu manges, ...]
```

Une forme vide dans une liste signifie « n'existe pas » (verbes impersonnels
ou défectifs, par exemple `falloir`).

## Comment ça marche

1. Un modèle JSON est cherché par terminaison (la plus longue gagne,
   `^mot` = infinitif exact). Exemple : `apprendre` suit le modèle `prendre`.
2. Sinon : règles du 1er groupe (c→ç, g→ge, y→i, doublement ou accent
   grave de eler/eter, é→è) ou du 2e groupe.
3. Les temps composés sont construits avec `avoir` ou `être`
   (liste `etre_verbs`, tous les pronominaux).

## Limites connues

- Verbes absents : `clore`, `frire` (partiellement), `braire`, `absoudre`,
  `dissoudre`, `gésir`, `paître`, `faillir`, `s'en aller`… (`conjugate`
  renvoie `null`).
- L'accord du participe passé avec le complément d'objet n'est pas traité ;
  seuls les accords avec le sujet (`être`, pronominaux) sont affichés `(e)(s)`.
- Pour `-ayer` (payer), seule la forme en « i » est donnée (je paie).
- Les verbes dont l'auxiliaire varie (monter, descendre, passer…) utilisent `avoir`.

## Ajouter un verbe irrégulier

Ajoute une entrée dans `data/conjugation_models.json` (voir `_doc` en tête
du fichier), ajoute des cas dans `test/conjugation_expected.json`, puis lance
`python3 tools/test_conjugation.py` et `dart test`.
