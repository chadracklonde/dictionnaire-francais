import 'package:flutter_tts/flutter_tts.dart';

/// Prononciation à voix haute avec la voix française du téléphone
/// (synthèse vocale du système : aucune connexion nécessaire).
class Speech {
  FlutterTts? _tts;
  bool _ready = false;

  /// Lit [text] ; renvoie false si aucune voix française n'est disponible.
  Future<bool> speak(String text) async {
    try {
      final tts = _tts ??= FlutterTts();
      if (!_ready) {
        final available = await tts.isLanguageAvailable('fr-FR');
        if (available != true && available != 1) return false;
        await tts.setLanguage('fr-FR');
        await tts.setSpeechRate(0.45);
        _ready = true;
      }
      await tts.stop();
      await tts.speak(text);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final Speech speech = Speech();
