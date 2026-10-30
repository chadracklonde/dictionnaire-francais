import 'package:flutter/material.dart';

/// Premier lancement : copie de la base vers l'appareil (une seule fois).
class InstallScreen extends StatelessWidget {
  const InstallScreen({
    super.key,
    required this.progress,
    required this.error,
    required this.onRetry,
  });

  final double progress;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_rounded,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('Dictionnaire', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 24),
                if (error == null) ...[
                  LinearProgressIndicator(value: progress == 0 ? null : progress),
                  const SizedBox(height: 12),
                  Text(
                    'Préparation du dictionnaire… ${(progress * 100).round()} %\n'
                    'Cette étape n\'a lieu qu\'une seule fois, sans Internet.',
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Text(
                    'Impossible de préparer le dictionnaire.',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
