import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import 'home_screen.dart' show openWord;

const List<String> alphabet = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
];

/// Index alphabétique : liste des mots par lettre, chargée page par page.
class IndexScreen extends StatefulWidget {
  const IndexScreen({super.key, this.letter = 'A'});

  final String letter;

  @override
  State<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends State<IndexScreen> {
  final _scroll = ScrollController();
  final _prefix = TextEditingController();
  final _hits = <SearchHit>[];
  String? _lastNorm;
  String? _lastWord;
  bool _more = true;
  bool _loading = false;
  bool _properNouns = false;
  bool _expressions = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _prefix.text = widget.letter;
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _loadMore();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _prefix.dispose();
    super.dispose();
  }

  void _reload() {
    _generation++;
    _hits.clear();
    _lastNorm = null;
    _lastWord = null;
    _more = true;
    _loading = false;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {});
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_more) return;
    _loading = true;
    final generation = _generation;
    final page = await AppScope.of(context).repo.browse(
          _prefix.text,
          afterNorm: _lastNorm,
          afterWord: _lastWord,
          properNouns: _properNouns,
          expressions: _expressions,
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

  String get _currentLetter {
    final t = _prefix.text.trim();
    return t.isEmpty ? '' : t[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Index alphabétique')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final l in alphabet)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(l),
                      selected: _currentLetter == l,
                      onSelected: (_) {
                        _prefix.text = l;
                        _reload();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: TextField(
              controller: _prefix,
              textInputAction: TextInputAction.search,
              onChanged: (_) => _reload(),
              decoration: InputDecoration(
                labelText: 'Commence par…',
                prefixIcon: const Icon(Icons.sort_by_alpha),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Inclure les noms propres'),
            value: _properNouns,
            onChanged: (v) {
              _properNouns = v;
              _reload();
            },
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Inclure les expressions'),
            value: _expressions,
            onChanged: (v) {
              _expressions = v;
              _reload();
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: _hits.isEmpty && !_loading && !_more
                ? const Center(child: Text('Aucun mot.'))
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
                                  child: CircularProgressIndicator(strokeWidth: 2.5))),
                        );
                      }
                      final hit = _hits[i];
                      return ListTile(
                        dense: true,
                        title: Text(hit.word),
                        subtitle: hit.pos == null
                            ? null
                            : Text(hit.pos!,
                                style: theme.textTheme.bodySmall),
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
