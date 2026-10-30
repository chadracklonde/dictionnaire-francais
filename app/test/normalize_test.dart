import 'package:dictionnaire/data/dictionary_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalisation identique à l\'import Python', () {
    expect(DictionaryRepository.normalize('École'), 'ecole');
    expect(DictionaryRepository.normalize('œuvre'), 'oeuvre');
    expect(DictionaryRepository.normalize('Œuvre'), 'oeuvre');
    expect(DictionaryRepository.normalize('l’eau'), "l'eau");
    expect(DictionaryRepository.normalize('garçon'), 'garcon');
    expect(DictionaryRepository.normalize('maïs'), 'mais');
  });
}
