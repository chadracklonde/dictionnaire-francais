import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../data/domain_labels.dart';
import '../data/models.dart';
import '../data/speech.dart';
import 'conjugation_screen.dart';
import 'home_screen.dart';
import 'notes_screen.dart';
import 'search_screen.dart';
import 'tappable_text.dart';

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
  List<EntryData> _loaded = const [];

  /// Texte de la fiche à copier ou partager, avec la mention de la source.
  String _plainText() {
    final b = StringBuffer();
    for (final e in _loaded) {
      b.write(e.word);
      if (e.pos != null) b.write(' (${e.pos})');
      b.writeln();
      for (var i = 0; i < e.senses.length && i < 8; i++) {
        b.writeln('${i + 1}. ${e.senses[i].definition}');
      }
      b.writeln();
    }
    b.write('— Dictionnaire et Conjugaison · Wiktionnaire (CC BY-SA 4.0)');
    return b.toString();
  }

  Future<void> _copy() async {
    if (_loaded.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _plainText()));
    messenger.showSnackBar(const SnackBar(content: Text('Définition copiée.')));
  }

  Future<void> _share() async {
    if (_loaded.isEmpty) return;
    await Share.share(_plainText(), subject: widget.word);
  }

  Future<void> _random() async {
    final messenger = ScaffoldMessenger.of(context);
    final word = await AppScope.of(context).repo.randomWord();
    if (!mounted) return;
    if (word == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Aucun mot trouvé.')));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => EntryScreen(word: word)),
    );
  }

  @override
  void initState() {
    super.initState();
    final services = AppScope.of(context);
    _entries = services.repo.entriesFor(widget.word).then((entries) {
      _loaded = entries;
      return entries;
    });
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
          IconButton(
            tooltip: 'Écouter la prononciation',
            icon: const Icon(Icons.volume_up_outlined),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final ok = await speech.speak(widget.word);
              if (!ok) {
                messenger.showSnackBar(const SnackBar(
                  content: Text(
                      'Voix française indisponible. Installez-la dans les '
                      'paramètres du téléphone (Synthèse vocale).'),
                ));
              }
            },
          ),
          IconButton(
            tooltip: 'Copier la définition',
            icon: const Icon(Icons.copy_outlined),
            onPressed: _copy,
          ),
          IconButton(
            tooltip: 'Rechercher un mot',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
            ),
          ),
          ListenableBuilder(
            listenable: user,
            builder: (context, _) {
              final fav = user.isFavorite(widget.word);
              return IconButton(
                tooltip: fav ? 'Retirer des favoris' : 'Ajouter aux favoris',
                icon: Icon(fav ? Icons.star : Icons.star_outline),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  user.toggleFavorite(widget.word);
                },
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        height: 56,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: 'Accueil',
              icon: const Icon(Icons.home_outlined),
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            ),
            IconButton(
              tooltip: 'Mot au hasard',
              icon: const Icon(Icons.shuffle),
              onPressed: _random,
            ),
            IconButton(
              tooltip: 'Partager',
              icon: const Icon(Icons.share_outlined),
              onPressed: _share,
            ),
            ListenableBuilder(
              listenable: user,
              builder: (context, _) => IconButton(
                tooltip: 'Ma note',
                icon: Icon(user.noteFor(widget.word) == null
                    ? Icons.note_add_outlined
                    : Icons.sticky_note_2),
                onPressed: () => editNote(context, widget.word),
              ),
            ),
          ],
        ),
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
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListenableBuilder(
                listenable: user,
                builder: (context, _) {
                  final note = user.noteFor(widget.word);
                  if (note == null) return const SizedBox.shrink();
                  return Card(
                    color: theme.colorScheme.tertiaryContainer,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      leading: const Icon(Icons.sticky_note_2_outlined),
                      title: Text(note),
                      onTap: () => editNote(context, widget.word),
                    ),
                  );
                },
              ),
              for (final entry in entries) _EntryCard(entry: entry),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  'Ce texte est extrait du Wiktionnaire et il est disponible '
                  'sous licence CC BY-SA 4.0.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EntryCard extends StatefulWidget {
  const _EntryCard({required this.entry});

  final EntryData entry;

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  final _sensesKey = GlobalKey();
  final _relationKeys = <String, GlobalKey>{};

  EntryData get entry => widget.entry;

  void _goTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  List<String> get _presentRelations => [
        for (final type in _relationLabels.keys)
          if (entry.relations[type]?.isNotEmpty ?? false) type,
      ];

  String get _subtitle {
    final parts = <String>[
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
            if (entry.pos != null)
              Text(entry.pos!,
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.primary)),
            if (entry.etymology != null)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text('Étymologie',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontStyle: FontStyle.italic)),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TappableText(entry.etymology!),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Semantics(
                    header: true,
                    child: Text(entry.word,
                        style: theme.textTheme.headlineSmall),
                  ),
                ),
                if (conjugation != null) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ConjugationScreen(conjugation: conjugation),
                      ),
                    ),
                    child: const Text('conjugaison'),
                  ),
                ],
              ],
            ),
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
            if (entry.inflections.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InflectionTable(entry: entry),
            ],
            if (_presentRelations.isNotEmpty && entry.senses.length >= 3) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.format_list_numbered, size: 16),
                      label: const Text('Définitions'),
                      onPressed: () => _goTo(_sensesKey),
                    ),
                    for (final type in _presentRelations) ...[
                      const SizedBox(width: 8),
                      ActionChip(
                        label: Text(_relationLabels[type]!),
                        onPressed: () => _goTo(_relationKeys[type]!),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            SizedBox(key: _sensesKey, height: 12),
            for (var i = 0; i < entry.senses.length; i++)
              _SenseTile(number: i + 1, sense: entry.senses[i]),
            for (final type in _relationLabels.keys)
              if (entry.relations[type]?.isNotEmpty ?? false) ...[
                SizedBox(
                    key: _relationKeys.putIfAbsent(type, () => GlobalKey()),
                    height: 12),
                Text(_relationLabels[type]!, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final word in entry.relations[type]!.take(60))
                      ActionChip(
                        label: Text(word),
                        onPressed: () => openWord(context, word),
                      ),
                  ],
                ),
              ],
            if (entry.source == 'wiktionnaire')
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Voir sur le Wiktionnaire'),
                  onPressed: () => launchUrl(
                    Uri.parse(entry.sourceUrl ??
                        'https://fr.wiktionary.org/wiki/'
                            '${Uri.encodeComponent(entry.word.replaceAll(' ', '_'))}'),
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

class _SenseTile extends StatefulWidget {
  const _SenseTile({required this.number, required this.sense});

  final int number;
  final Sense sense;

  @override
  State<_SenseTile> createState() => _SenseTileState();
}

class _SenseTileState extends State<_SenseTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sense = widget.sense;
    final tags = [
      if (sense.register != null) sense.register!,
      if (sense.domain != null) domainFr(sense.domain!),
    ];
    final examples = sense.examples.take(3).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 28, child: Text('${widget.number}.')),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tags.isNotEmpty)
                  Text(tags.join(', '),
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontStyle: FontStyle.italic)),
                TappableText(sense.definition),
                if (examples.isNotEmpty)
                  InkWell(
                    onTap: () => setState(() => _open = !_open),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_open ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                              size: 20, color: theme.colorScheme.primary),
                          Text(
                            _open
                                ? 'enrouler'
                                : 'exemples (${examples.length})',
                            style: theme.textTheme.labelLarge
                                ?.copyWith(color: theme.colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_open)
                  for (final example in examples)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 8),
                      child: TappableText(
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

/// Tableau des accords : singulier/pluriel, masculin/féminin.
class _InflectionTable extends StatelessWidget {
  const _InflectionTable({required this.entry});

  final EntryData entry;

  List<String> _k(String key) => entry.inflections[key] ?? const [];

  String _cell(List<String> forms) => forms.isEmpty ? '—' : forms.join(', ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fs = _k('fs');
    final fp = _k('fp');
    final mp = _k('mp').isNotEmpty ? _k('mp') : _k('p');
    final femPlural = fp.isNotEmpty ? fp : (fs.isNotEmpty ? _k('p') : <String>[]);
    final hasFem = fs.isNotEmpty || fp.isNotEmpty;
    if (!hasFem && mp.isEmpty) return const SizedBox.shrink();

    Widget cell(String text, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(text,
              style: bold
                  ? theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)
                  : theme.textTheme.bodyMedium),
        );

    final rows = <TableRow>[
      TableRow(children: [
        if (hasFem) cell(''),
        cell('Singulier', bold: true),
        cell('Pluriel', bold: true),
      ]),
      if (hasFem) ...[
        TableRow(children: [
          cell('Masculin', bold: true),
          cell(entry.word),
          cell(_cell(mp)),
        ]),
        TableRow(children: [
          cell('Féminin', bold: true),
          cell(_cell(fs)),
          cell(_cell(femPlural)),
        ]),
      ] else
        TableRow(children: [cell(entry.word), cell(_cell(mp))]),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: theme.colorScheme.outlineVariant),
        children: rows,
      ),
    );
  }
}
