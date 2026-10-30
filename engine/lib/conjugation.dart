/// Moteur de conjugaison française (Dart pur).
///
/// Même algorithme que tools/conjugation_ref.py. Les verbes irréguliers sont
/// décrits dans data/conjugation_models.json ; les verbes en -er et les
/// verbes réguliers en -ir sont traités par des règles.
///
/// Utilisation :
/// ```dart
/// final c = Conjugator.fromJson(await rootBundle.loadString('assets/conjugation_models.json'));
/// final r = c.conjugate('se laver');
/// print(r?.moods['indicatif']!['present']); // [je me lave, tu te laves, ...]
/// ```
library;

import 'dart:convert';

const List<String> _persons = ['je', 'tu', 'il/elle', 'nous', 'vous', 'ils/elles'];
const List<String> _reflexive = ['me', 'te', 'se', 'nous', 'vous', 'se'];
const Map<String, String> _elision = {
  'je': "j'",
  'que': "qu'",
  'me': "m'",
  'te': "t'",
  'se': "s'",
};
const String _vowels = 'aeiouyâàäéèêëîïôöûùü';
const String _vowelsScan = 'aeiouâêîôûéèïü';
const Map<String, String> _circ = {'a': 'â', 'e': 'ê', 'i': 'î', 'o': 'ô', 'u': 'û'};
const String _cons = 'bcdfghjklmnpqrstvwxz';

const List<String> _impfEnd = ['ais', 'ais', 'ait', 'ions', 'iez', 'aient'];
const List<String> _futEnd = ['ai', 'as', 'a', 'ons', 'ez', 'ont'];
const List<String> _ps1End = ['ai', 'as', 'a', 'âmes', 'âtes', 'èrent'];
const List<String> _ppAgree = ['(e)', '(e)', '(e)', '(e)s', '(e)(s)', '(e)s'];

/// Verbes en -eler / -eter qui prennent un accent grave (au lieu de doubler).
const Set<String> _graveExact = {
  'acheter', 'racheter', 'haleter', 'fureter', 'bégueter', 'corseter',
  'crocheter', 'fileter', 'geler', 'dégeler', 'congeler', 'surgeler',
  'regeler', 'peler', 'celer', 'déceler', 'receler', 'harceler', 'ciseler',
  'démanteler', 'écarteler', 'encasteler', 'marteler', 'modeler',
};

final RegExp _reEAcute = RegExp(r'é([^aeiouyéèêëàâäîïôöûùü]{1,2})$');
final RegExp _reEGu = RegExp(r'é(gu|qu)$');

/// Libellés pour l'interface.
const Map<String, String> moodLabels = {
  'indicatif': 'Indicatif',
  'subjonctif': 'Subjonctif',
  'conditionnel': 'Conditionnel',
  'imperatif': 'Impératif',
  'infinitif': 'Infinitif',
  'participe': 'Participe',
};

const Map<String, String> tenseLabels = {
  'present': 'Présent',
  'passe_compose': 'Passé composé',
  'imparfait': 'Imparfait',
  'plus_que_parfait': 'Plus-que-parfait',
  'passe_simple': 'Passé simple',
  'passe_anterieur': 'Passé antérieur',
  'futur_simple': 'Futur simple',
  'futur_anterieur': 'Futur antérieur',
  'passe': 'Passé',
};

/// Résultat d'une conjugaison.
///
/// [moods] : mode -> temps -> formes (6 personnes, 3 pour l'impératif).
/// Une forme vide signifie « n'existe pas » (verbes défectifs, impersonnels).
class Conjugation {
  const Conjugation({
    required this.infinitive,
    required this.reflexive,
    required this.auxiliary,
    required this.pastParticiple,
    required this.presentParticiple,
    required this.moods,
  });

  final String infinitive;
  final bool reflexive;
  final String auxiliary;
  final String pastParticiple;
  final String presentParticiple;
  final Map<String, Map<String, List<String>>> moods;
}

class _Model {
  _Model({
    required this.strip,
    required this.match,
    required this.exclude,
    required this.pres,
    required this.impf,
    required this.fut,
    required this.pp,
    this.ps,
    this.subj,
    this.prp,
    this.imp,
  });

  factory _Model.fromJson(Map<String, dynamic> j) => _Model(
        strip: j['strip'] as String,
        match: (j['match'] as List).cast<String>(),
        exclude: ((j['exclude'] as List?) ?? const []).cast<String>(),
        pres: j['pres'] as String,
        impf: j['impf'] as String,
        fut: j['fut'] as String,
        pp: j['pp'] as String,
        ps: j['ps'] as String?,
        subj: j['subj'] as String?,
        prp: j['prp'] as String?,
        imp: j['imp'] as String?,
      );

  final String strip;
  final List<String> match;
  final List<String> exclude;
  final String pres;
  final String impf;
  final String fut;
  final String pp;
  final String? ps;
  final String? subj;
  final String? prp;
  final String? imp;
}

/// Formes simples d'un verbe (avant composition des temps).
class _Simple {
  _Simple({
    required this.pres,
    required this.impf,
    required this.fut,
    required this.cond,
    required this.subj,
    required this.pp,
    required this.prp,
    this.ps,
    this.imp,
  });

  final List<String> pres;
  final List<String> impf;
  final List<String>? ps;
  final List<String> fut;
  final List<String> cond;
  final List<String> subj;
  final String pp;
  final String prp;
  final List<String>? imp;
}

/// c -> ç et g -> ge devant a, o, â.
String _soft(String stem, String ending) {
  if (ending.isNotEmpty && 'aoâ'.contains(ending[0])) {
    if (stem.endsWith('c')) return stem.substring(0, stem.length - 1) + 'ç';
    if (stem.endsWith('g')) return stem + 'e';
  }
  return stem;
}

String _circumflex(String stem) {
  for (var i = stem.length - 1; i >= 0; i--) {
    final ch = stem[i];
    if (_vowelsScan.contains(ch)) {
      return stem.substring(0, i) + (_circ[ch] ?? ch) + stem.substring(i + 1);
    }
  }
  return stem;
}

List<String>? _subjImparfait(List<String>? ps) {
  if (ps == null || !ps[1].endsWith('s')) return null;
  final stem = ps[1].substring(0, ps[1].length - 1);
  return [
    stem + 'sse',
    stem + 'sses',
    _circumflex(stem) + 't',
    stem + 'ssions',
    stem + 'ssiez',
    stem + 'ssent',
  ];
}

bool _elides(String word, bool hAspire) {
  final first = word[0];
  if (_vowels.contains(first)) return true;
  return first == 'h' && !hAspire;
}

String _joinTokens(List<String> tokens, bool hAspire) {
  var out = '';
  String? prev;
  for (final tok in tokens) {
    if (tok.isEmpty) continue;
    if (prev == null) {
      out = tok;
    } else if (_elision.containsKey(prev) && _elides(tok, hAspire)) {
      out = out.substring(0, out.length - prev.length) + _elision[prev]! + tok;
    } else {
      out = out + ' ' + tok;
    }
    prev = tok;
  }
  return out;
}

_Simple _group1(String inf) {
  final stem = inf.substring(0, inf.length - 2);
  var kind = 'plain';
  var sstem = stem;
  if (stem.length > 2 && stem.endsWith('y') && !stem.endsWith('ey')) {
    kind = 'y';
    sstem = stem.substring(0, stem.length - 1) + 'i';
  } else if (stem.endsWith('el') || stem.endsWith('et')) {
    final last = stem[stem.length - 1];
    if (_graveExact.contains(inf)) {
      kind = 'grave';
      sstem = stem.substring(0, stem.length - 2) + 'è' + last;
    } else {
      kind = 'double';
      sstem = stem + last;
    }
  } else if (stem.length >= 2 &&
      stem[stem.length - 2] == 'e' &&
      _cons.contains(stem[stem.length - 1])) {
    kind = 'grave';
    sstem = stem.substring(0, stem.length - 2) + 'è' + stem[stem.length - 1];
  } else {
    final m = _reEAcute.firstMatch(stem) ?? _reEGu.firstMatch(stem);
    if (m != null) {
      kind = 'acute';
      sstem = stem.substring(0, m.start) + 'è' + stem.substring(m.start + 1);
    }
  }

  final pres = [
    sstem + 'e',
    sstem + 'es',
    sstem + 'e',
    _soft(stem, 'ons') + 'ons',
    stem + 'ez',
    sstem + 'ent',
  ];
  var futBase = (kind == 'acute' ? stem : sstem) + 'er';
  if (inf.endsWith('envoyer')) {
    futBase = stem.substring(0, stem.length - 2) + 'err';
  }
  return _Simple(
    pres: pres,
    impf: [for (final e in _impfEnd) _soft(stem, e) + e],
    ps: [for (final e in _ps1End) _soft(stem, e) + e],
    fut: [for (final e in _futEnd) futBase + e],
    cond: [for (final e in _impfEnd) futBase + e],
    subj: [
      sstem + 'e',
      sstem + 'es',
      sstem + 'e',
      stem + 'ions',
      stem + 'iez',
      sstem + 'ent',
    ],
    pp: stem + 'é',
    prp: _soft(stem, 'ant') + 'ant',
    imp: [pres[0], pres[3], pres[4]],
  );
}

_Simple _group2(String inf) {
  final stem = inf.substring(0, inf.length - 2);
  final pres = [
    for (final e in ['is', 'is', 'it', 'issons', 'issez', 'issent']) stem + e
  ];
  return _Simple(
    pres: pres,
    impf: [for (final e in _impfEnd) stem + 'iss' + e],
    ps: [for (final e in ['is', 'is', 'it', 'îmes', 'îtes', 'irent']) stem + e],
    fut: [for (final e in _futEnd) inf + e],
    cond: [for (final e in _impfEnd) inf + e],
    subj: [
      for (final e in ['isse', 'isses', 'isse', 'issions', 'issiez', 'issent'])
        stem + e
    ],
    pp: stem + 'i',
    prp: stem + 'issant',
    imp: [pres[1], pres[3], pres[4]],
  );
}

/// Conjugue un infinitif (simple ou pronominal : « se laver », « s'appeler »).
class Conjugator {
  Conjugator._(this._models, this._etreVerbs, this._impersonal, this._hAspire);

  /// [source] : contenu de conjugation_models.json.
  factory Conjugator.fromJson(String source) {
    final data = json.decode(source) as Map<String, dynamic>;
    final models = (data['models'] as Map<String, dynamic>)
        .values
        .map((m) => _Model.fromJson(m as Map<String, dynamic>))
        .toList();
    return Conjugator._(
      models,
      (data['etre_verbs'] as List).cast<String>().toSet(),
      (data['impersonal'] as List).cast<String>().toSet(),
      (data['h_aspire'] as List).cast<String>().toSet(),
    );
  }

  final List<_Model> _models;
  final Set<String> _etreVerbs;
  final Set<String> _impersonal;
  final Set<String> _hAspire;

  _Model? _findModel(String inf) {
    _Model? best;
    var bestScore = -1;
    for (final m in _models) {
      if (m.exclude.contains(inf)) continue;
      for (final pat in m.match) {
        int score;
        if (pat.startsWith('^')) {
          if (inf != pat.substring(1)) continue;
          score = 1000 + pat.length;
        } else if (inf.endsWith(pat)) {
          score = pat.length;
        } else {
          continue;
        }
        if (score > bestScore) {
          best = m;
          bestScore = score;
        }
      }
    }
    return best;
  }

  _Simple _fromModel(String inf, _Model m) {
    final root = inf.substring(0, inf.length - m.strip.length);
    List<String> tails(String text) =>
        [for (final t in text.split(' ')) root + (t == '_' ? '' : t)];

    final pres = tails(m.pres);
    final impfStem = root + (m.impf == '_' ? '' : m.impf);
    final futStem = root + m.fut;

    List<String> subj;
    if (m.subj != null) {
      subj = tails(m.subj!);
    } else {
      final s1 = pres[5].substring(0, pres[5].length - 3);
      subj = [
        s1 + 'e',
        s1 + 'es',
        s1 + 'e',
        impfStem + 'ions',
        impfStem + 'iez',
        s1 + 'ent',
      ];
    }

    List<String>? imp;
    if (m.imp == 'none') {
      imp = null;
    } else if (m.imp != null) {
      imp = tails(m.imp!);
    } else {
      final tu = pres[1].endsWith('es')
          ? pres[1].substring(0, pres[1].length - 1)
          : pres[1];
      imp = [tu, pres[3], pres[4]];
    }

    return _Simple(
      pres: pres,
      impf: [for (final e in _impfEnd) impfStem + e],
      ps: m.ps != null ? tails(m.ps!) : null,
      fut: [for (final e in _futEnd) futStem + e],
      cond: [for (final e in _impfEnd) futStem + e],
      subj: subj,
      pp: root + m.pp,
      prp: m.prp != null ? root + m.prp! : impfStem + 'ant',
      imp: imp,
    );
  }

  _Simple? _simpleForms(String inf) {
    final model = _findModel(inf);
    if (model != null) return _fromModel(inf, model);
    if (inf.endsWith('er')) return _group1(inf);
    if (inf.endsWith('ir')) return _group2(inf);
    return null;
  }

  /// Renvoie null si le verbe n'est pas reconnu.
  Conjugation? conjugate(String text) {
    var inf = text.trim().toLowerCase().replaceAll('’', "'");
    var reflexive = false;
    if (inf.startsWith('se ')) {
      reflexive = true;
      inf = inf.substring(3).trim();
    } else if (inf.startsWith("s'")) {
      reflexive = true;
      inf = inf.substring(2).trim();
    }
    if (inf.isEmpty) return null;
    final s = _simpleForms(inf);
    if (s == null) return null;

    final useEtre = reflexive || _etreVerbs.contains(inf);
    final aux = _simpleForms(useEtre ? 'être' : 'avoir')!;
    final impersonal = _impersonal.contains(inf);
    final hAsp = _hAspire.contains(inf);
    final pp = s.pp;

    String agree(int i) => useEtre ? pp + _ppAgree[i] : pp;

    List<String> row(List<String> forms, {bool subjunctive = false}) {
      final rows = <String>[];
      for (var i = 0; i < forms.length; i++) {
        final f = forms[i];
        if (f.isEmpty || (impersonal && i != 2)) {
          rows.add('');
          continue;
        }
        final tokens = <String>[
          if (subjunctive) 'que',
          impersonal ? 'il' : _persons[i],
          if (reflexive) _reflexive[i],
          f,
        ];
        rows.add(_joinTokens(tokens, hAsp));
      }
      return rows;
    }

    List<String> compound(List<String>? auxForms) {
      if (auxForms == null) return List.filled(6, '');
      return [for (var i = 0; i < 6; i++) auxForms[i] + ' ' + agree(i)];
    }

    List<String> blank(List<String>? forms) => forms ?? List.filled(6, '');

    final subjImp = _subjImparfait(s.ps);
    final auxSubjImp = _subjImparfait(aux.ps);
    final moods = <String, Map<String, List<String>>>{};

    moods['indicatif'] = {
      'present': row(s.pres),
      'passe_compose': row(compound(aux.pres)),
      'imparfait': row(s.impf),
      'plus_que_parfait': row(compound(aux.impf)),
      'passe_simple': row(blank(s.ps)),
      'passe_anterieur':
          s.ps != null ? row(compound(aux.ps)) : List.filled(6, ''),
      'futur_simple': row(s.fut),
      'futur_anterieur': row(compound(aux.fut)),
    };
    moods['subjonctif'] = {
      'present': row(s.subj, subjunctive: true),
      'passe': row(compound(aux.subj), subjunctive: true),
      'imparfait': row(blank(subjImp), subjunctive: true),
      'plus_que_parfait': subjImp != null
          ? row(compound(auxSubjImp), subjunctive: true)
          : List.filled(6, ''),
    };
    moods['conditionnel'] = {
      'present': row(s.cond),
      'passe': row(compound(aux.cond)),
    };

    List<String> impNow = [];
    List<String> impPast = [];
    if (s.imp != null && !impersonal) {
      final tu = s.imp![0];
      final nous = s.imp![1];
      final vous = s.imp![2];
      if (reflexive) {
        impNow = [tu + '-toi', nous + '-nous', vous + '-vous'];
      } else {
        impNow = [tu, nous, vous];
        final a = aux.imp!;
        impPast = [
          a[0] + ' ' + agree(1),
          a[1] + ' ' + agree(3),
          a[2] + ' ' + agree(4),
        ];
      }
    }
    moods['imperatif'] = {'present': impNow, 'passe': impPast};

    final infAux = useEtre ? 'être' : 'avoir';
    final ppAny = useEtre ? pp + '(e)(s)' : pp;
    final se = reflexive ? ['se'] : <String>[];
    moods['infinitif'] = {
      'present': [_joinTokens([...se, inf], hAsp)],
      'passe': [_joinTokens([...se, infAux, ppAny], false)],
    };
    final partAux = useEtre ? 'étant' : 'ayant';
    moods['participe'] = {
      'present': [_joinTokens([...se, s.prp], hAsp)],
      'passe': [pp, _joinTokens([...se, partAux, ppAny], false)],
    };

    return Conjugation(
      infinitive: inf,
      reflexive: reflexive,
      auxiliary: infAux,
      pastParticiple: pp,
      presentParticiple: s.prp,
      moods: moods,
    );
  }
}
