import 'package:flutter/material.dart';

import '../app.dart';
import 'home_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Favoris et historique'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Favoris'), Tab(text: 'Historique')],
          ),
          actions: [
            IconButton(
              tooltip: 'Effacer l\'historique',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => user.clearHistory(),
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: user,
          builder: (context, _) => TabBarView(
            children: [
              _WordList(
                words: user.favorites,
                emptyText: 'Aucun favori. Touchez l\'étoile sur la fiche d\'un mot.',
              ),
              _WordList(
                words: user.history,
                emptyText: 'Aucun mot consulté.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordList extends StatelessWidget {
  const _WordList({required this.words, required this.emptyText});

  final List<String> words;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(emptyText, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.separated(
      itemCount: words.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) => ListTile(
        title: Text(words[i]),
        onTap: () => openWord(context, words[i]),
      ),
    );
  }
}
