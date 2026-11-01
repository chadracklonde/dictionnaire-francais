import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Favoris et historique, enregistrés sur l'appareil.
class UserStore extends ChangeNotifier {
  UserStore(this._prefs)
      : favorites = List.of(_prefs.getStringList('favorites') ?? const []),
        history = List.of(_prefs.getStringList('history') ?? const []),
        _notes = _readNotes(_prefs);

  static const int _historyMax = 100;

  final SharedPreferences _prefs;
  final List<String> favorites;
  final List<String> history;
  final Map<String, String> _notes;

  static Map<String, String> _readNotes(SharedPreferences prefs) {
    try {
      final raw = prefs.getString('notes');
      if (raw == null) return {};
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final e in data.entries) e.key: '${e.value}'};
    } catch (_) {
      return {};
    }
  }

  /// Notes personnelles, par mot.
  Map<String, String> get notes => Map.unmodifiable(_notes);
  String? noteFor(String word) => _notes[word];

  Future<void> setNote(String word, String text) async {
    final t = text.trim();
    if (t.isEmpty) {
      _notes.remove(word);
    } else {
      _notes[word] = t;
    }
    await _prefs.setString('notes', jsonEncode(_notes));
    notifyListeners();
  }

  /// Sauvegarde : favoris, notes, historique et réglages, en texte JSON.
  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'app': 'dictionnaire-et-conjugaison',
        'version': 1,
        'favorites': favorites,
        'notes': _notes,
        'history': history,
        'themeMode': themeMode,
        'textScale': textScale,
      });

  /// Restaure une sauvegarde (fusion avec l'existant). Renvoie un message
  /// d'erreur, ou null si tout s'est bien passé.
  Future<String?> importJson(String text) async {
    try {
      final data = jsonDecode(text.trim());
      if (data is! Map || data['app'] != 'dictionnaire-et-conjugaison') {
        return 'Ce texte n\'est pas une sauvegarde de l\'application.';
      }
      final favs = [for (final w in (data['favorites'] as List? ?? const [])) '$w'];
      final hist = [for (final w in (data['history'] as List? ?? const [])) '$w'];
      final notes = (data['notes'] as Map?) ?? const {};
      for (final w in favs.reversed) {
        if (!favorites.contains(w)) favorites.insert(0, w);
      }
      for (final w in hist.reversed) {
        if (!history.contains(w)) history.insert(0, w);
      }
      if (history.length > _historyMax) {
        history.removeRange(_historyMax, history.length);
      }
      for (final e in notes.entries) {
        _notes['${e.key}'] = '${e.value}';
      }
      await _prefs.setStringList('favorites', favorites);
      await _prefs.setStringList('history', history);
      await _prefs.setString('notes', jsonEncode(_notes));
      notifyListeners();
      return null;
    } catch (_) {
      return 'Sauvegarde illisible : copiez le texte en entier.';
    }
  }

  /// Réglages : thème (system, light, dark), taille du texte, rappel quotidien.
  String get themeMode => _prefs.getString('themeMode') ?? 'system';
  double get textScale => _prefs.getDouble('textScale') ?? 1.0;
  bool get dailyWord => _prefs.getBool('dailyWord') ?? false;

  Future<void> setThemeMode(String value) async {
    await _prefs.setString('themeMode', value);
    notifyListeners();
  }

  Future<void> setTextScale(double value) async {
    await _prefs.setDouble('textScale', value);
    notifyListeners();
  }

  Future<void> setDailyWord(bool value) async {
    await _prefs.setBool('dailyWord', value);
    notifyListeners();
  }

  bool isFavorite(String word) => favorites.contains(word);

  Future<void> toggleFavorite(String word) async {
    if (!favorites.remove(word)) favorites.insert(0, word);
    await _prefs.setStringList('favorites', favorites);
    notifyListeners();
  }

  Future<void> addHistory(String word) async {
    history.remove(word);
    history.insert(0, word);
    if (history.length > _historyMax) {
      history.removeRange(_historyMax, history.length);
    }
    await _prefs.setStringList('history', history);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    history.clear();
    await _prefs.setStringList('history', history);
    notifyListeners();
  }
}
