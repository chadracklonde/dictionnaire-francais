import 'dart:math' show Random;

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

  /// « Vouliez-vous dire… ? » : mots proches d'une saisie sans résultat
  /// (distance d'édition de Damerau, sans connexion). Candidats : même
  /// première lettre et longueur voisine ; à défaut, mots contenant un
  /// fragment de la saisie (première lettre fautive).
  Future<List<SearchHit>> suggest(String query, {int limit = 5}) async {
    final q = normalize(query.trim());
    if (q.length < 3 || q.contains(' ')) return const [];
    final n = q.length;
    final maxDist = n <= 4 ? 1 : 2;
    const select = 'SELECT word, norm, MAX(freq) AS freq FROM entries '
        "WHERE is_lemma = 1 AND pos != 'nom propre' AND norm NOT LIKE '% %' "
        'AND length(norm) BETWEEN ? AND ?';

    var rows = await _db.rawQuery(
      '$select AND norm >= ? AND norm < ? GROUP BY word, norm',
      [n - 2, n + 2, q[0], '${q[0]}\uffff'],
    );
    var scored = _scoreSuggestions(q, rows, maxDist);
    if (scored.isEmpty) {
      final fragment = q.substring(1, n < 4 ? n : 4);
      rows = await _db.rawQuery(
        '$select AND norm LIKE ? GROUP BY word, norm',
        [n - 2, n + 2, '%$fragment%'],
      );
      scored = _scoreSuggestions(q, rows, maxDist);
    }
    if (scored.isEmpty) return const [];
    scored.sort((a, b) {
      final byDist = a.dist.compareTo(b.dist);
      if (byDist != 0) return byDist;
      final byFreq = b.freq.compareTo(a.freq);
      return byFreq != 0 ? byFreq : a.word.compareTo(b.word);
    });
    final best = scored.first.dist;
    final seen = <String>{};
    return [
      for (final s in scored)
        if (s.dist == best && seen.add(s.word)) SearchHit(word: s.word),
    ].take(limit).toList();
  }

  static List<({String word, int dist, int freq})> _scoreSuggestions(
    String q,
    List<Map<String, Object?>> rows,
    int maxDist,
  ) {
    final out = <({String word, int dist, int freq})>[];
    for (final r in rows) {
      final d = editDistance(q, r['norm'] as String, maxDist);
      if (d <= maxDist) {
        out.add((
          word: r['word'] as String,
          dist: d,
          freq: (r['freq'] as int?) ?? 0,
        ));
      }
    }
    return out;
  }

  /// Distance de Damerau (substitution, ajout, retrait, échange de deux
  /// lettres voisines) ; s'arrête dès que [max] est dépassé.
  static int editDistance(String a, String b, int max) {
    if ((a.length - b.length).abs() > max) return max + 1;
    var prev2 = List<int>.filled(b.length + 1, 0);
    var prev = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      var best = cur[0];
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var v = prev[j] + 1;
        if (cur[j - 1] + 1 < v) v = cur[j - 1] + 1;
        if (prev[j - 1] + cost < v) v = prev[j - 1] + cost;
        if (i > 1 &&
            j > 1 &&
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
            a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1) &&
            prev2[j - 2] + 1 < v) {
          v = prev2[j - 2] + 1;
        }
        cur[j] = v;
        if (v < best) best = v;
      }
      if (best > max) return max + 1;
      prev2 = prev;
      prev = cur;
    }
    return prev[b.length];
  }

  /// Parcours alphabétique : les mots dont la forme normalisée commence par
  /// [prefix], dans l'ordre du dictionnaire (accents ignorés). Pagination par
  /// clé ([afterNorm]/[afterWord]) : rapide même sur 500 000 entrées.
  Future<({List<SearchHit> hits, String? lastNorm, String? lastWord, bool more})>
      browse(
    String prefix, {
    String? afterNorm,
    String? afterWord,
    int limit = 80,
    bool properNouns = false,
    bool expressions = false,
  }) async {
    final p = normalize(prefix.trim());
    final where = <String>['is_lemma = 1'];
    final args = <Object?>[];
    if (!properNouns) where.add("pos != 'nom propre'");
    if (!expressions) where.add("word NOT LIKE '% %'");
    if (p.isNotEmpty) {
      where.add('norm >= ? AND norm < ?');
      args..add(p)..add('$p\uffff');
    }
    if (afterNorm != null) {
      where.add('(norm > ? OR (norm = ? AND word > ?))');
      args..add(afterNorm)..add(afterNorm)..add(afterWord ?? '');
    }
    final rows = await _db.rawQuery(
      'SELECT word, norm, pos FROM entries WHERE ${where.join(' AND ')} '
      'ORDER BY norm, word LIMIT ?',
      [...args, limit],
    );
    final hits = <SearchHit>[];
    final posByWord = <String, Set<String>>{};
    for (final r in rows) {
      final word = r['word'] as String;
      final pos = r['pos'] as String?;
      final set = posByWord[word];
      if (set == null) {
        posByWord[word] = {if (pos != null && pos.isNotEmpty) pos};
        hits.add(SearchHit(word: word));
      } else if (pos != null && pos.isNotEmpty) {
        set.add(pos);
      }
    }
    final result = [
      for (final h in hits)
        SearchHit(
          word: h.word,
          pos: posByWord[h.word]!.isEmpty ? null : posByWord[h.word]!.join(' · '),
        ),
    ];
    return (
      hits: result,
      lastNorm: rows.isEmpty ? afterNorm : rows.last['norm'] as String,
      lastWord: rows.isEmpty ? afterWord : rows.last['word'] as String,
      more: rows.length == limit,
    );
  }

  /// Ramène un mot touché dans un texte à un mot du dictionnaire :
  /// accents et majuscule ignorés, élision (« l’homme »), forme fléchie.
  Future<String?> resolveWord(String token) async {
    final candidates = <String>[token];
    final afterApostrophe = token.split(RegExp(r"[’']"));
    if (afterApostrophe.length > 1) {
      candidates.add(afterApostrophe.sublist(1).join("'"));
    }
    final hyphenated = token.split('-');
    if (hyphenated.length > 1) candidates.add(hyphenated.first);
    for (final c in candidates) {
      final n = normalize(c);
      if (n.isEmpty) continue;
      final rows = await _db.rawQuery(
        'SELECT word FROM entries WHERE norm = ? AND is_lemma = 1 '
        "ORDER BY (word = ?) DESC, (pos = 'nom propre') ASC, id LIMIT 1",
        [n, c],
      );
      if (rows.isNotEmpty) return rows.first['word'] as String;
      final viaForm = await _db.rawQuery(
        'SELECT e.word AS word FROM forms f JOIN entries e ON e.id = f.entry_id '
        "WHERE f.norm = ? ORDER BY (e.pos = 'nom propre') ASC, e.id LIMIT 1",
        [n],
      );
      if (viaForm.isNotEmpty) return viaForm.first['word'] as String;
    }
    return null;
  }

  int? _minId;
  int? _maxId;

  /// Un mot au hasard (nom, verbe ou adjectif, sans espace).
  Future<String?> randomWord() async {
    if (_minId == null) {
      final r = await _db.rawQuery('SELECT MIN(id) AS a, MAX(id) AS b FROM entries');
      _minId = r.first['a'] as int?;
      _maxId = r.first['b'] as int?;
    }
    final lo = _minId, hi = _maxId;
    if (lo == null || hi == null) return null;
    final pick = lo + Random().nextInt(hi - lo + 1);
    final rows = await _db.rawQuery(
      "SELECT word FROM entries WHERE id >= ? AND is_lemma = 1 "
      "AND pos IN ('nom', 'verbe', 'adjectif') AND word NOT LIKE '% %' "
      'ORDER BY id LIMIT 1',
      [pick],
    );
    return rows.isEmpty ? null : rows.first['word'] as String;
  }

  /// Recherche par motif (mots croisés, Scrabble) : « ? » ou « _ » = une
  /// lettre, « * » = plusieurs lettres (ou aucune). Accents ignorés.
  /// Retourne aussi la clé de reprise pour la page suivante.
  Future<({List<SearchHit> hits, String? lastNorm, String? lastWord, bool more})>
      matchPattern(
    String pattern, {
    String? afterNorm,
    String? afterWord,
    int limit = 100,
  }) async {
    final buf = StringBuffer();
    for (final rune in normalize(pattern.trim()).runes) {
      final ch = String.fromCharCode(rune);
      if (ch == '_' || ch == '?' || ch == '.') {
        buf.write('?');
      } else if (ch == '*') {
        buf.write('*');
      } else if (RegExp(r"[a-z0-9'-]").hasMatch(ch)) {
        buf.write(ch);
      }
    }
    final glob = buf.toString();
    if (glob.replaceAll('*', '').isEmpty) {
      return (hits: const <SearchHit>[], lastNorm: null, lastWord: null, more: false);
    }
    final where = <String>[
      'is_lemma = 1',
      "pos != 'nom propre'",
      "word NOT LIKE '% %'",
      'norm GLOB ?',
    ];
    final args = <Object?>[glob];
    if (!glob.contains('*')) {
      where.add('length(norm) = ?');
      args.add(glob.length);
    }
    if (afterNorm != null) {
      where.add('(norm > ? OR (norm = ? AND word > ?))');
      args..add(afterNorm)..add(afterNorm)..add(afterWord ?? '');
    }
    final rows = await _db.rawQuery(
      'SELECT word, norm, pos FROM entries WHERE ${where.join(' AND ')} '
      'ORDER BY norm, word LIMIT ?',
      [...args, limit],
    );
    final seen = <String>{};
    final hits = <SearchHit>[
      for (final r in rows)
        if (seen.add(r['word'] as String))
          SearchHit(word: r['word'] as String, pos: _joinPos(r['pos'])),
    ];
    return (
      hits: hits,
      lastNorm: rows.isEmpty ? afterNorm : rows.last['norm'] as String,
      lastWord: rows.isEmpty ? afterWord : rows.last['word'] as String,
      more: rows.length == limit,
    );
  }

  Future<Map<String, String>> meta() async {
    final rows = await _db.query('meta');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }
}
