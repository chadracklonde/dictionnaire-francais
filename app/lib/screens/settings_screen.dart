import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';

import '../app.dart';
import '../data/user_store.dart';
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
              Text('Sauvegarde', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Vos favoris, notes et historique, sans compte : envoyez-vous '
                'le texte (WhatsApp, courriel…) puis collez-le sur le nouvel '
                'appareil.',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Sauvegarder'),
                    onPressed: () => Share.share(user.exportJson(),
                        subject: 'Sauvegarde Dictionnaire et Conjugaison'),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copier'),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(
                          ClipboardData(text: user.exportJson()));
                      messenger.showSnackBar(const SnackBar(
                          content: Text('Sauvegarde copiée.')));
                    },
                  ),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('Restaurer'),
                    onPressed: () => _restore(context, user),
                  ),
                ],
              ),
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

/// Fenêtre de restauration : on colle le texte d'une sauvegarde.
Future<void> _restore(BuildContext context, UserStore user) async {
  final controller = TextEditingController();
  final text = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Restaurer une sauvegarde'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Collez ici le texte de la sauvegarde',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.paste),
              label: const Text('Coller'),
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null) controller.text = data!.text!;
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Restaurer'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (text == null || text.trim().isEmpty || !context.mounted) return;
  final error = await user.importJson(text);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(error ?? 'Sauvegarde restaurée : favoris, notes et historique ajoutés.'),
  ));
}
