import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Favoris et historique, enregistrés sur l'appareil.
class UserStore extends ChangeNotifier {
  UserStore(this._prefs)
      : favorites = List.of(_prefs.getStringList('favorites') ?? const []),
        history = List.of(_prefs.getStringList('history') ?? const []);

  static const int _historyMax = 100;

  final SharedPreferences _prefs;
  final List<String> favorites;
  final List<String> history;

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
