import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';

const String _licenceUrl = 'https://creativecommons.org/licenses/by-sa/4.0/deed.fr';
const String _wiktionaryUrl = 'https://fr.wiktionary.org/';

/// À propos / Licences : attribution exigée par la licence CC BY-SA 4.0.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = AppScope.of(context).repo;

    return Scaffold(
      appBar: AppBar(title: const Text('À propos et licences')),
      body: FutureBuilder<Map<String, String>>(
        future: repo.meta(),
        builder: (context, snapshot) {
          final meta = snapshot.data ?? const <String, String>{};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Dictionnaire', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              const Text('Dictionnaire français consultable sans Internet.'),
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
              if (meta['entrees'] != null) ...[
                const SizedBox(height: 8),
                Text('Nombre d\'entrées : ${meta['entrees']}'),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => _open(_wiktionaryUrl),
                    child: const Text('Wiktionnaire'),
                  ),
                  OutlinedButton(
                    onPressed: () => _open(meta['licence_url'] ?? _licenceUrl),
                    child: const Text('Licence CC BY-SA 4.0'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Conjugaison', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Les tableaux de conjugaison sont calculés par l\'application '
                'à partir de règles et d\'une liste de verbes irréguliers.',
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'Dictionnaire',
                ),
                child: const Text('Licences des composants logiciels'),
              ),
            ],
          );
        },
      ),
    );
  }
}
