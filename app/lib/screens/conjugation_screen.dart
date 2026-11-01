import 'package:dictionnaire_engine/conjugation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

/// Tous les modes et temps d'un verbe, un onglet par mode.
class ConjugationScreen extends StatelessWidget {
  const ConjugationScreen({super.key, required this.conjugation});

  final Conjugation conjugation;

  @override
  Widget build(BuildContext context) {
    final moods = conjugation.moods.keys.toList();
    final theme = Theme.of(context);
    final title = conjugation.reflexive
        ? 'se ${conjugation.infinitive}'
        : conjugation.infinitive;

    return DefaultTabController(
      length: moods.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final m in moods) Tab(text: moodLabels[m] ?? m)],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Auxiliaire : ${conjugation.auxiliary} · '
                  'participe passé : ${conjugation.pastParticiple}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final mood in moods)
                    _MoodView(
                      mood: mood,
                      tenses: conjugation.moods[mood]!,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodView extends StatelessWidget {
  const _MoodView({required this.mood, required this.tenses});

  final String mood;
  final Map<String, List<String>> tenses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = <Widget>[];
    tenses.forEach((tense, forms) {
      final lines = forms.where((f) => f.isNotEmpty).toList();
      if (lines.isEmpty) return;
      cards.add(
        SizedBox(
          width: 320,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(tenseLabels[tense] ?? tense,
                            style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary)),
                      ),
                      IconButton(
                        tooltip: 'Copier ce temps',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.copy_outlined, size: 20),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await Clipboard.setData(ClipboardData(
                              text: '${tenseLabels[tense] ?? tense}\n'
                                  '${lines.join('\n')}'));
                          messenger.showSnackBar(const SnackBar(
                              content: Text('Temps copié.')));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final line in lines) SelectableText(line),
                ],
              ),
            ),
          ),
        ),
      );
    });

    if (cards.isEmpty) {
      return const Center(child: Text('Ce mode n\'existe pas pour ce verbe.'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Wrap(spacing: 8, runSpacing: 8, children: cards),
    );
  }
}
