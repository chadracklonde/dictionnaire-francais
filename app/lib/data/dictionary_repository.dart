import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'db_installer.dart';
import 'models.dart';

const Map<String, String> _fold = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ÿ': 'y', 'ñ': 'n',
  'œ': 'oe', 'æ': 'ae', '’': "'", 'ʼ': "'",
};

/// Accès en lecture seule à la base du dictionnaire.
class DictionaryRepository {
  DictionaryRepository._(this._db);

  final Database _db;

  static Future<DictionaryRepository> open() async {
    final db = await databaseFactory.openDatabase(
      await DbInstaller.dbPath(),
      options: OpenDatabaseOptions(readOnly: true),
    );
    return DictionaryRepository._(db);
  }

  /// Minuscules, sans accents, ligatures dépliées (même règle que l'import).
  static String normalize(String text) {
    final lower = text.toLowerCase();
    final out = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      out.write(_fold[ch] ?? ch);
    }
    return out.toString();
  }

  static String? _joinPos(Object? raw) {
    if (raw == null) return null;
    final text = (raw as String).split(',').where((s) => s.isNotEmpty).join(' · ');
    return text.isEmpty ? null : text;
  }

  /// Autocomplétion : formes fléchies d'abord (« mangeons » -> manger),
  /// puis les mots qui commencent par la saisie, puis recherche plein texte.
  Future<List<SearchHit>> search(String query, {int limit = 30}) async {
    final q = normalize(query.trim());
    if (q.isEmpty) return const [];
    final hits = <SearchHit>[];
    final seen = <String>{};

    final formRows = await _db.rawQuery(
      'SELECT e.word AS word, group_concat(DISTINCT e.pos) AS pos, '
      'MIN(COALESCE(NULLIF(f.form, \'\'), f.norm)) AS form FROM forms f JOIN entries e ON e.id = f.entry_id '
      'WHERE f.norm = ? AND e.norm != ? GROUP BY e.word LIMIT 5',
      [q, q],
    );
    for (final r in formRows) {
      final word = r['word'] as String;
      if (seen.add(word)) {
        hits.add(SearchHit(
          word: word,
          pos: _joinPos(r['pos']),
          formOf: r['form'] as String?,
        ));
      }
    }

    final rows = await _db.rawQuery(
      'SELECT word, group_concat(DISTINCT pos) AS pos, '
      'MAX(is_lemma) AS lem, MAX(freq) AS fq FROM entries '
      'WHERE norm >= ? AND norm < ? GROUP BY word '
      'ORDER BY (MIN(norm) = ?) DESC, lem DESC, fq DESC, length(word), word '
      'LIMIT ?',
      [q, '$q￿', q, limit],
    );
    for (final r in rows) {
      final word = r['word'] as String;
      if (seen.add(word)) {
        hits.add(SearchHit(word: word, pos: _joinPos(r['pos'])));
      }
    }

    if (hits.length < 5 && q.length >= 3) {
      hits.addAll(await _fullText(q, seen));
    }
    return hits;
  }

  Future<List<SearchHit>> _fullText(String q, Set<String> seen) async {
    final tokens =
        q.split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return const [];
    final terms = [
      for (var i = 0; i < tokens.length; i++)
        i == tokens.length - 1 ? '"${tokens[i]}"*' : '"${tokens[i]}"',
    ].join(' ');
    try {
      final rows = await _db.rawQuery(
        'SELECT e.word AS word, e.pos AS pos FROM search_fts f '
        'JOIN entries e ON e.id = f.rowid WHERE search_fts MATCH ? LIMIT 20',
        ['norm : ($terms)'],
      );
      return [
        for (final r in rows)
          if (seen.add(r['word'] as String))
            SearchHit(word: r['word'] as String, pos: _joinPos(r['pos'])),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Toutes les entrées d'un mot (nom, verbe, adjectif…).
  Future<List<EntryData>> entriesFor(String word) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM entries WHERE word = ? ORDER BY is_lemma DESC, id',
      [word],
    );
    return [for (final r in rows) await _load(r)];
  }

  Future<EntryData> _load(Map<String, Object?> row) async {
    final id = row['id'] as int;
    final senseRows = await _db.query(
      'senses',
      where: 'entry_id = ?',
      whereArgs: [id],
      orderBy: 'ord',
    );
    final exampleRows = await _db.rawQuery(
      'SELECT x.sense_id AS sid, x.text AS text FROM examples x '
      'JOIN senses s ON s.id = x.sense_id WHERE s.entry_id = ? ORDER BY x.id',
      [id],
    );
    final examplesBySense = <int, List<String>>{};
    for (final r in exampleRows) {
      (examplesBySense[r['sid'] as int] ??= []).add(r['text'] as String);
    }
    final senses = [
      for (final r in senseRows)
        Sense(
          definition: r['definition'] as String,
          register: r['register'] as String?,
          domain: r['domain'] as String?,
          examples: examplesBySense[r['id'] as int] ?? const [],
        ),
    ];

    final relationRows = await _db.query(
      'relations',
      where: 'entry_id = ?',
      whereArgs: [id],
    );
    final relations = <String, List<String>>{};
    for (final r in relationRows) {
      (relations[r['type'] as String] ??= []).add(r['word'] as String);
    }

    final word = row['word'] as String;
    final isLemma = (row['is_lemma'] as int) == 1;
    var lemmas = <String>[];
    if (!isLemma) {
      final lemmaRows = await _db.rawQuery(
        'SELECT DISTINCT e.word AS word FROM forms f '
        'JOIN entries e ON e.id = f.entry_id '
        'WHERE f.norm = ? AND f.form = ? AND e.word != ?',
        [row['norm'], word, word],
      );
      lemmas = [for (final r in lemmaRows) r['word'] as String];
    }

    return EntryData(
      id: id,
      word: word,
      isLemma: isLemma,
      pos: row['pos'] as String?,
      gender: row['gender'] as String?,
      ipa: row['ipa'] as String?,
      etymology: row['etymology'] as String?,
      source: row['source'] as String?,
      sourceUrl: row['source_url'] as String?,
      senses: senses,
      relations: relations,
      lemmas: lemmas,
    );
  }

  /// Un mot du jour : le même pour tout le monde à une date donnée.
  Future<String?> wordOfTheDay(DateTime day) async {
    const filter = "is_lemma = 1 AND pos IN ('nom','verbe','adjectif')";
    final countRows =
        await _db.rawQuery('SELECT COUNT(*) AS n FROM entries WHERE $filter');
    final count = countRows.first['n'] as int;
    if (count == 0) return null;
    final seed = day.year * 10000 + day.month * 100 + day.day;
    final offset = (seed * 2654435761) % count;
    final rows = await _db.rawQuery(
      'SELECT word FROM entries WHERE $filter LIMIT 1 OFFSET ?',
      [offset],
    );
    return rows.isEmpty ? null : rows.first['word'] as String;
  }

  /// Chiffres réels de la base : mots distincts et verbes (infinitifs).
  Future<({int words, int verbs})> stats() async {
    final w = await _db.rawQuery('SELECT COUNT(DISTINCT word) AS n FROM entries');
    final v = await _db.rawQuery(
      "SELECT COUNT(DISTINCT word) AS n FROM entries "
      "WHERE pos = 'verbe' AND is_lemma = 1 AND word NOT LIKE '% %'",
    );
    return (words: w.first['n'] as int, verbs: v.first['n'] as int);
  }

  Future<Map<String, String>> meta() async {
    final rows = await _db.query('meta');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }
}
