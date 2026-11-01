import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import 'home_screen.dart' show openWord;

/// Recherche par motif : mots croisés, Scrabble, jeux de mots.
class PatternScreen extends StatefulWidget {
  const PatternScreen({super.key});

  @override
  State<PatternScreen> createState() => _PatternScreenState();
}

class _PatternScreenState extends State<PatternScreen> {
  final _scroll = ScrollController();
  final _pattern = TextEditingController();
  final _hits = <SearchHit>[];
  String? _lastNorm;
  String? _lastWord;
  bool _more = false;
  bool _loading = false;
  bool _searched = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pattern.dispose();
    super.dispose();
  }

  void _search() {
    _generation++;
    _hits.clear();
    _lastNorm = null;
    _lastWord = null;
    _more = true;
    _loading = false;
    _searched = _pattern.text.trim().isNotEmpty;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {});
    if (_searched) {
      _loadMore();
    } else {
      setState(() => _more = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_more) return;
    _loading = true;
    final generation = _generation;
    final page = await AppScope.of(context).repo.matchPattern(
          _pattern.text,
          afterNorm: _lastNorm,
          afterWord: _lastWord,
        );
    if (!mounted || generation != _generation) return;
    setState(() {
      _hits.addAll(page.hits);
      _lastNorm = page.lastNorm;
      _lastWord = page.lastWord;
      _more = page.more;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Recherche par motif')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _pattern,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              onChanged: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Motif, par exemple a?r?n ou ma*ion',
                prefixIcon: const Icon(Icons.grid_view_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '?  remplace une lettre   ·   *  remplace plusieurs lettres\n'
                'Les accents sont ignorés. Exemple : ?a?on  →  balon, canon, raison…',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: !_searched
                ? const Center(child: Text('Tapez un motif pour commencer.'))
                : _hits.isEmpty && !_more
                    ? const Center(child: Text('Aucun mot ne correspond.'))
                    : ListView.builder(
                        controller: _scroll,
                        itemCount: _hits.length + (_more ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i >= _hits.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5),
                                ),
                              ),
                            );
                          }
                          final hit = _hits[i];
                          return ListTile(
                            dense: true,
                            title: Text(hit.word),
                            subtitle: hit.pos == null ? null : Text(hit.pos!),
                            onTap: () => openWord(context, hit.word),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
