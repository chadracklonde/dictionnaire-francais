import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import '../data/user_store.dart';
import 'entry_screen.dart';
import 'favorites_screen.dart';
import 'licenses_screen.dart';

void openWord(BuildContext context, String word) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => EntryScreen(word: word)),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<SearchHit> _hits = const [];
  String? _wordOfTheDay;

  @override
  void initState() {
    super.initState();
    AppScope.of(context).repo.wordOfTheDay(DateTime.now()).then((word) {
      if (mounted) setState(() => _wordOfTheDay = word);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() => _hits = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 120), () async {
      final hits = await AppScope.of(context).repo.search(text);
      if (!mounted || _controller.text != text) return;
      setState(() => _hits = hits);
    });
  }

  void _onSubmitted(String text) {
    if (_hits.isNotEmpty) openWord(context, _hits.first.word);
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final query = _controller.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dictionnaire'),
        actions: [
          IconButton(
            tooltip: 'Favoris et historique',
            icon: const Icon(Icons.star_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FavoritesScreen()),
            ),
          ),
          IconButton(
            tooltip: 'À propos et licences',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LicensesScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: false,
              textInputAction: TextInputAction.search,
              onChanged: (text) {
                setState(() {});
                _onChanged(text);
              },
              onSubmitted: _onSubmitted,
              decoration: InputDecoration(
                hintText: 'Rechercher un mot…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _hits = const []);
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          Expanded(
            child: query.isEmpty
                ? _HomeContent(wordOfTheDay: _wordOfTheDay, user: services.user)
                : _Results(hits: _hits, query: query),
          ),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.hits, required this.query});

  final List<SearchHit> hits;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (hits.isEmpty) {
      return Center(child: Text('Aucun résultat pour « $query ».'));
    }
    return ListView.separated(
      itemCount: hits.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final hit = hits[i];
        final subtitle = hit.formOf != null
            ? 'forme de « ${hit.word} » (${hit.formOf})'
            : hit.pos;
        return ListTile(
          title: Text(hit.word),
          subtitle: subtitle == null ? null : Text(subtitle),
          onTap: () => openWord(context, hit.word),
        );
      },
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.wordOfTheDay, required this.user});

  final String? wordOfTheDay;
  final UserStore user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: user,
      builder: (context, _) => _buildList(context, theme),
    );
  }

  Widget _buildList(BuildContext context, ThemeData theme) {
    final history = user.history.take(12).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (wordOfTheDay != null)
          Card(
            color: theme.colorScheme.primaryContainer,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => openWord(context, wordOfTheDay!),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mot du jour',
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer)),
                    const SizedBox(height: 8),
                    Text(wordOfTheDay!,
                        style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer)),
                  ],
                ),
              ),
            ),
          ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Récemment consultés', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final word in history)
                ActionChip(
                  label: Text(word),
                  onPressed: () => openWord(context, word),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
