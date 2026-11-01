import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import '../data/user_store.dart';
import 'home_screen.dart';

/// Écran de recherche accessible depuis la loupe de l'entête.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<SearchHit> _hits = const [];
  List<SearchHit> _suggestions = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() {
        _hits = const [];
        _suggestions = const [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 120), () async {
      final repo = AppScope.of(context).repo;
      final hits = await repo.search(text);
      if (!mounted || _controller.text != text) return;
      setState(() {
        _hits = hits;
        if (hits.isNotEmpty) _suggestions = const [];
      });
      if (hits.isEmpty) {
        final suggestions = await repo.suggest(text);
        if (!mounted || _controller.text != text) return;
        setState(() => _suggestions = suggestions);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: TextStyle(
              color: Theme.of(context).appBarTheme.foregroundColor ??
                  Theme.of(context).colorScheme.onSurface),
          cursorColor: Theme.of(context).appBarTheme.foregroundColor,
          decoration: InputDecoration(
            hintText: 'Rechercher un mot…',
            hintStyle: TextStyle(
                color: (Theme.of(context).appBarTheme.foregroundColor ??
                        Theme.of(context).colorScheme.onSurface)
                    .withOpacity(0.8)),
            border: InputBorder.none,
          ),
          onChanged: (text) {
            setState(() {});
            _onChanged(text);
          },
          onSubmitted: (_) {
            if (_hits.isNotEmpty) openWord(context, _hits.first.word);
          },
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              tooltip: 'Effacer',
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() {
                  _hits = const [];
                  _suggestions = const [];
                });
              },
            ),
        ],
      ),
      body: query.isEmpty
          ? _Recent(user: AppScope.of(context).user)
          : SearchResults(hits: _hits, query: query, suggestions: _suggestions),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.user});

  final UserStore user;

  @override
  Widget build(BuildContext context) {
    final words = user.history.take(15).toList();
    if (words.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Tapez un mot, ou « conjuguer manger » pour une conjugaison.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Récemment consultés',
              style: Theme.of(context).textTheme.titleSmall),
        ),
        for (final w in words)
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(w),
            onTap: () => openWord(context, w),
          ),
      ],
    );
  }
}
