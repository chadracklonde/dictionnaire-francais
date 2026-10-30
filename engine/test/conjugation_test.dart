import 'dart:convert';
import 'dart:io';

import 'package:dictionnaire_engine/conjugation.dart';
import 'package:test/test.dart';

/// Lancer depuis le dossier engine/ :  dart test
void main() {
  final conjugator = Conjugator.fromJson(
    File('data/conjugation_models.json').readAsStringSync(),
  );
  final expected = json.decode(
    File('test/conjugation_expected.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final tests = expected['tests'] as Map<String, dynamic>;

  tests.forEach((verb, cases) {
    test(verb, () {
      final result = conjugator.conjugate(verb);
      expect(result, isNotNull, reason: 'verbe inconnu : $verb');
      (cases as Map<String, dynamic>).forEach((key, want) {
        final parts = key.split('#');
        final path = parts[0].split('.');
        final row = result!.moods[path[0]]![path[1]]!;
        if (parts.length > 1) {
          final i = int.parse(parts[1]);
          final got = i < row.length ? row[i] : '';
          expect(got, want as String, reason: '$verb / $key');
        } else {
          final text = want as String;
          final wantList = text.isEmpty ? <String>[] : text.split(' | ');
          expect(row, wantList, reason: '$verb / $key');
        }
      });
    });
  });

  test('verbes inconnus', () {
    for (final verb in (expected['unknown'] as List).cast<String>()) {
      expect(conjugator.conjugate(verb), isNull, reason: verb);
    }
  });
}
