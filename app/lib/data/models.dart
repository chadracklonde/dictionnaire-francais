/// Résultat de recherche (un mot, éventuellement plusieurs catégories).
class SearchHit {
  const SearchHit({required this.word, this.pos, this.formOf});

  final String word;

  /// Catégories grammaticales, par exemple « nom · adjectif ».
  final String? pos;

  /// Si le mot tapé est une forme fléchie : le mot dont elle dérive.
  final String? formOf;
}

class Sense {
  const Sense({
    required this.definition,
    this.register,
    this.domain,
    this.examples = const [],
  });

  final String definition;
  final String? register;
  final String? domain;
  final List<String> examples;
}

class EntryData {
  const EntryData({
    required this.id,
    required this.word,
    required this.isLemma,
    required this.senses,
    required this.relations,
    required this.lemmas,
    this.pos,
    this.gender,
    this.ipa,
    this.etymology,
    this.source,
    this.sourceUrl,
    this.inflections = const {},
  });

  final int id;
  final String word;
  final bool isLemma;
  final String? pos;
  final String? gender;
  final String? ipa;
  final String? etymology;
  final String? source;
  final String? sourceUrl;
  final List<Sense> senses;

  /// type (synonyme, antonyme, derive, expression) -> mots liés.
  final Map<String, List<String>> relations;

  /// Pour une forme fléchie : les mots dont elle dérive.
  final List<String> lemmas;

  /// Accords : ms, fs, mp, fp, s, p -> formes (noms et adjectifs).
  final Map<String, List<String>> inflections;
}
