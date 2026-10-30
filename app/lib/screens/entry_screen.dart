import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../data/models.dart';
import 'conjugation_screen.dart';
import 'home_screen.dart';

const Map<String, String> _relationLabels = {
  'synonyme': 'Synonymes',
  'antonyme': 'Antonymes',
  'derive': 'Mots dérivés',
  'expression': 'Expressions',
};

/// Fiche d'un mot : toutes ses entrées (nom, verbe, adjectif…).
class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key, required this.word});

  final String word;

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  late final Future<List<EntryData>> _entries;

  @override
  void initState() {
    super.initState();
    final services = AppScope.of(context);
    _entries = services.repo.entriesFor(widget.word);
    // Après la construction : addHistory notifie d'autres écrans (accueil).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      services.user.addHistory(widget.word);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.word),
        actions: [
          ListenableBuilder(
            listenable: user,
            builder: (context, _) {
              final fav = user.isFavorite(widget.word);
              return IconButton(
                tooltip: fav ? 'Retirer des favoris' : 'Ajouter aux favoris',
                icon: Icon(fav ? Icons.star : Icons.star_outline),
                onPressed: () => user.toggleFavorite(widget.word),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<EntryData>>(
        future: _entries,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return Center(child: Text('« ${widget.word} » est introuvable.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in entries) _EntryCard(entry: entry),
            ],
          );
        },
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final EntryData entry;

  String get _subtitle {
    final parts = <String>[
      if (entry.pos != null) entry.pos!,
      if (entry.gender != null)
        switch (entry.gender) {
          'm' => 'masculin',
          'f' => 'féminin',
          _ => 'masculin et féminin',
        },
      if (!entry.isLemma) 'forme fléchie',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final services = AppScope.of(context);
    final conjugation = entry.pos == 'verbe' && entry.isLemma
        ? services.conjugator.conjugate(entry.word)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.word, style: theme.textTheme.headlineSmall),
            if (_subtitle.isNotEmpty)
              Text(_subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            if (entry.ipa != null) ...[
              const SizedBox(height: 4),
              SelectableText(entry.ipa!, style: theme.textTheme.bodyLarge),
            ],
            if (entry.lemmas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Voir :'),
                  for (final lemma in entry.lemmas)
                    ActionChip(
                      label: Text(lemma),
                      onPressed: () => openWord(context, lemma),
                    ),
                ],
              ),
            ],
            if (conjugation != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Conjuguer'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ConjugationScreen(conjugation: conjugation),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            for (var i = 0; i < entry.senses.length; i++)
              _SenseTile(number: i + 1, sense: entry.senses[i]),
            for (final type in _relationLabels.keys)
              if (entry.relations[type]?.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                Text(_relationLabels[type]!, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final word in entry.relations[type]!.take(30))
                      ActionChip(
                        label: Text(word),
                        onPressed: () => openWord(context, word),
                      ),
                  ],
                ),
              ],
            if (entry.etymology != null) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Étymologie'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(entry.etymology!),
                  ),
                ],
              ),
            ],
            if (entry.sourceUrl != null && entry.source == 'wiktionnaire')
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Voir sur le Wiktionnaire'),
                  onPressed: () => launchUrl(
                    Uri.parse(entry.sourceUrl!),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SenseTile extends StatelessWidget {
  const _SenseTile({required this.number, required this.sense});

  final int number;
  final Sense sense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = [
      if (sense.register != null) sense.register!,
      if (sense.domain != null) sense.domain!,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 28, child: Text('$number.')),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tags.isNotEmpty)
                  Text(tags.join(', '),
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontStyle: FontStyle.italic)),
                SelectableText(sense.definition),
                for (final example in sense.examples.take(3))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SelectableText(
                      example,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
