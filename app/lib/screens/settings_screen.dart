import 'package:flutter/material.dart';

import '../app.dart';
import '../data/notifier.dart';
import 'licenses_screen.dart';

/// Réglages : thème, taille du texte, rappel quotidien.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListenableBuilder(
        listenable: user,
        builder: (context, _) {
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Thème', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'system', label: Text('Auto')),
                  ButtonSegment(value: 'light', label: Text('Clair')),
                  ButtonSegment(value: 'dark', label: Text('Sombre')),
                ],
                selected: {user.themeMode},
                onSelectionChanged: (s) => user.setThemeMode(s.first),
              ),
              const SizedBox(height: 24),
              Text('Taille du texte', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 0.9, label: Text('Petit')),
                  ButtonSegment(value: 1.0, label: Text('Normal')),
                  ButtonSegment(value: 1.2, label: Text('Grand')),
                  ButtonSegment(value: 1.4, label: Text('Très grand')),
                ],
                selected: {user.textScale},
                onSelectionChanged: (s) => user.setTextScale(s.first),
              ),
              const SizedBox(height: 8),
              Text(
                'Exemple : le français est une langue riche.',
                style: theme.textTheme.bodyLarge,
              ),
              if (DailyWordNotifier.supported) ...[
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Rappel du mot du jour'),
                  subtitle: const Text('Une notification par jour.'),
                  value: user.dailyWord,
                  onChanged: (on) async {
                    final messenger = ScaffoldMessenger.of(context);
                    if (on) {
                      final ok = await DailyWordNotifier.enable();
                      if (!ok) {
                        messenger.showSnackBar(const SnackBar(
                          content: Text(
                              'Notifications refusées : autorisez-les dans '
                              'les paramètres du téléphone.'),
                        ));
                        return;
                      }
                    } else {
                      await DailyWordNotifier.disable();
                    }
                    await user.setDailyWord(on);
                  },
                ),
              ],
              const Divider(height: 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: const Text('À propos et licences'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const LicensesScreen()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
