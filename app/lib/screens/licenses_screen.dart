import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../data/format.dart';

const String _licenceUrl = 'https://creativecommons.org/licenses/by-sa/4.0/deed.fr';
const String _wiktionaryUrl = 'https://fr.wiktionary.org/';

/// À propos : présentation, chiffres réels de la base et attribution exigée
/// par la licence CC BY-SA 4.0.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = AppScope.of(context).repo;

    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: FutureBuilder<List<Object>>(
        future: Future.wait<Object>([repo.meta(), repo.stats()]),
        builder: (context, snapshot) {
          final data = snapshot.data;
          final meta = data == null
              ? const <String, String>{}
              : data[0] as Map<String, String>;
          final stats =
              data == null ? null : data[1] as ({int words, int verbs});

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset('assets/icon/logo.png', width: 96),
                      ),
                      const SizedBox(height: 12),
                      Text('Dictionnaire en Français',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text('Version $appVersion',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      const Text(
                        'Dictionnaire français complet, consultable sans '
                        'Internet, avec conjugaison.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          _Figure(
                            value: stats == null
                                ? '…'
                                : formatCount(stats.words),
                            label: 'mots',
                          ),
                          _Figure(
                            value: stats == null
                                ? '…'
                                : formatCount(stats.verbs),
                            label: 'verbes conjugués',
                          ),
                          const _Figure(value: '20', label: 'temps par verbe'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Contenu', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    meta['attribution'] ??
                        'Les définitions proviennent du Wiktionnaire et de ses '
                            'contributeurs.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Licence : ${meta['licence'] ?? 'CC BY-SA 4.0'}. '
                    'Vous pouvez réutiliser ce contenu à condition de citer sa '
                    'source et de le partager dans les mêmes conditions.',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _open(_wiktionaryUrl),
                        child: const Text('Wiktionnaire'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            _open(meta['licence_url'] ?? _licenceUrl),
                        child: const Text('Licence CC BY-SA 4.0'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Conjugaison', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'Les tableaux de conjugaison sont calculés par '
                    'l\'application à partir de règles et d\'une liste de '
                    'verbes irréguliers : 6 modes, 20 temps, formes '
                    'composées et pronominales comprises.',
                  ),
                  const SizedBox(height: 24),
                  Text('Développement', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Développé par Chadrack Londe.'),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: 'Dictionnaire en Français',
                      applicationVersion: appVersion,
                    ),
                    child: const Text('Licences des composants logiciels'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
