import 'package:flutter/material.dart';

import '../data/format.dart';

/// Écran de démarrage : affiché pendant la préparation de la base
/// (copie unique au premier lancement, quelques secondes ensuite).
class InstallScreen extends StatelessWidget {
  const InstallScreen({
    super.key,
    required this.progress,
    required this.error,
    required this.onRetry,
    this.words,
    this.verbs,
  });

  final double progress;
  final String? error;
  final VoidCallback onRetry;

  /// Chiffres réels lus dans le manifest de la base ; absents = texte neutre.
  final int? words;
  final int? verbs;

  static const _gold = Color(0xFFF2B632);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bookWidth = (size.shortestSide * 0.6).clamp(160.0, 300.0);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF71918), Color(0xFF4A0010)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/icon/book.png', width: bookWidth),
                    const SizedBox(height: 32),
                    const Text(
                      'Dictionnaire',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const Text(
                      'en Français',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _gold,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 36),
                    _Feature(
                      icon: Icons.manage_search_rounded,
                      text: words != null
                          ? '${formatCount(words!)} ${words == 1 ? 'mot' : 'mots'}'
                          : 'Des centaines de milliers de mots',
                    ),
                    const SizedBox(height: 14),
                    _Feature(
                      icon: Icons.menu_book_rounded,
                      text: verbs != null
                          ? '${formatCount(verbs!)} ${verbs == 1 ? 'verbe conjugué' : 'verbes conjugués'}'
                          : 'Conjugaison complète',
                    ),
                    const SizedBox(height: 40),
                    if (error == null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              value: progress == 0 ? null : progress,
                              color: Colors.white,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            progress == 0 || progress >= 1
                                ? 'Chargement…'
                                : 'Préparation… ${(progress * 100).round()} %',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                      if (progress > 0 && progress < 1) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Une seule fois, sans Internet.',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ] else ...[
                      const Text(
                        'Impossible de préparer le dictionnaire.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF8A0010),
                        ),
                        onPressed: onRetry,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white70, size: 30),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
