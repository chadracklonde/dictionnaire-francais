import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import 'home_screen.dart' show openWord;

/// Mots outils : non cliquables (comme « le », « de », « pour »…).
const Set<String> _stopWords = {
  'les', 'des', 'une', 'aux', 'son', 'ses', 'mon', 'mes', 'ton', 'tes', 'nos',
  'vos', 'leur', 'leurs', 'ces', 'cet', 'cette', 'qui', 'que', 'quoi', 'dont',
  'est', 'sont', 'été', 'être', 'avec', 'sans', 'pour', 'par', 'sur', 'sous',
  'dans', 'chez', 'vers', 'entre', 'ainsi', 'mais', 'donc', 'car', 'puis',
  'plus', 'très', 'tout', 'tous', 'toute', 'toutes', 'bien', 'aussi', 'comme',
  'elle', 'elles', 'ils', 'nous', 'vous', 'lui', 'eux', 'ceux', 'celui',
  'celle', 'celles', 'ici', 'peut', 'fait', 'etc', 'pas', 'ne', 'ou', 'où',
  'et', 'en', 'au', 'du', 'de', 'la', 'le', 'un', 'on', 'se', 'sa', 'ce',
  'qu', 'ni', 'si', 'se', 'ça', 'y',
};

final RegExp _wordPattern =
    RegExp(r"[\p{L}\p{M}]+(?:['’\-][\p{L}\p{M}]+)*", unicode: true);

/// Ouvre la fiche du mot touché dans un texte (forme fléchie, élision,
/// majuscule : tout est ramené au mot du dictionnaire).
Future<void> openToken(BuildContext context, String token) async {
  final messenger = ScaffoldMessenger.of(context);
  final repo = AppScope.of(context).repo;
  final word = await repo.resolveWord(token);
  if (!context.mounted) return;
  if (word == null) {
    messenger.showSnackBar(
      SnackBar(content: Text('« $token » est introuvable dans le dictionnaire.')),
    );
    return;
  }
  openWord(context, word);
}

/// Texte dont chaque mot significatif ouvre sa propre fiche.
class TappableText extends StatefulWidget {
  const TappableText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<TappableText> createState() => _TappableTextState();
}

class _TappableTextState extends State<TappableText> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final link = TextStyle(color: Theme.of(context).colorScheme.primary);
    final text = widget.text;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _wordPattern.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final token = m.group(0)!;
      if (token.length < 3 || _stopWords.contains(token.toLowerCase())) {
        spans.add(TextSpan(text: token));
      } else {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => openToken(context, token);
        _recognizers.add(recognizer);
        spans.add(TextSpan(text: token, style: link, recognizer: recognizer));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(children: spans), style: widget.style);
  }
}
