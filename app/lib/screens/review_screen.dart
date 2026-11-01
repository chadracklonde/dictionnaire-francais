import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';

/// Révision : les mots du carnet (favoris) comme des cartes à retourner.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.words});

  final List<String> words;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final List<String> _queue = List.of(widget.words)..shuffle();
  late final int _total = widget.words.length;
  int _known = 0;
  bool _revealed = false;
  Future<List<EntryData>>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (_queue.isEmpty) return;
    _entries = AppScope.of(context).repo.entriesFor(_queue.first);
  }

  void _answer({required bool knew}) {
    setState(() {
      final word = _queue.removeAt(0);
      if (knew) {
        _known++;
      } else {
        _queue.add(word);
      }
      _revealed = false;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = _queue.isEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Réviser mes mots')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: done
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_outlined, size: 56),
                    const SizedBox(height: 12),
                    Text('Révision terminée !',
                        style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('$_known mot${_known > 1 ? 's' : ''} retenu'
                        '${_known > 1 ? 's' : ''} sur $_total.'),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Retour'),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: _known / _total),
                  const SizedBox(height: 8),
                  Text('$_known / $_total retenus',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _revealed = true),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text(_queue.first,
                                    style: theme.textTheme.headlineMedium),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: _revealed
                                    ? _Definitions(future: _entries!)
                                    : Center(
                                        child: Text(
                                          'Touchez la carte pour voir la définition.',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                  color: theme.colorScheme
                                                      .onSurfaceVariant),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_revealed)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.replay),
                            label: const Text('À revoir'),
                            onPressed: () => _answer(knew: false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text('Je savais'),
                            onPressed: () => _answer(knew: true),
                          ),
                        ),
                      ],
                    )
                  else
                    FilledButton.tonal(
                      onPressed: () => setState(() => _revealed = true),
                      child: const Text('Voir la définition'),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Definitions extends StatelessWidget {
  const _Definitions({required this.future});

  final Future<List<EntryData>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EntryData>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snapshot.data!;
        if (entries.isEmpty) {
          return const Center(child: Text('Définition introuvable.'));
        }
        return ListView(
          children: [
            for (final entry in entries.take(2)) ...[
              if (entry.pos != null)
                Text(entry.pos!,
                    style: Theme.of(context).textTheme.labelLarge),
              for (var i = 0; i < entry.senses.length && i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${i + 1}. ${entry.senses[i].definition}'),
                ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}
