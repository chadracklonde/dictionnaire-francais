import 'package:dictionnaire_engine/conjugation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:shared_preferences/shared_preferences.dart';

import 'data/db_installer.dart';
import 'data/dictionary_repository.dart';
import 'data/user_store.dart';
import 'screens/home_screen.dart';
import 'screens/install_screen.dart';

/// Version affichée dans « À propos » (à garder alignée sur pubspec.yaml).
const String appVersion = '1.3.0';

/// Services partagés par tous les écrans.
class AppServices {
  AppServices({required this.repo, required this.user, required this.conjugator});

  final DictionaryRepository repo;
  final UserStore user;
  final Conjugator conjugator;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope introuvable dans l\'arbre de widgets');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}

class DictionnaireApp extends StatefulWidget {
  const DictionnaireApp({super.key, required this.conjugator});

  final Conjugator conjugator;

  @override
  State<DictionnaireApp> createState() => _DictionnaireAppState();
}

class _DictionnaireAppState extends State<DictionnaireApp> {
  double _progress = 0;
  String? _error;
  AppServices? _services;
  int? _words;
  int? _verbs;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (_error != null) setState(() => _error = null);
    try {
      final manifest = await DbInstaller.manifest();
      if (mounted) {
        setState(() {
          _words = manifest['words'] as int?;
          _verbs = manifest['verbs'] as int?;
        });
      }
      await for (final p in DbInstaller.install()) {
        if (!mounted) return;
        setState(() => _progress = p);
      }
      final repo = await DictionaryRepository.open();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _services = AppServices(
          repo: repo,
          user: UserStore(prefs),
          conjugator: widget.conjugator,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  /// Identité visuelle : rouge du logo, or et bleu du livre. Chaque couleur de
  /// texte reste à 4,5:1 minimum (WCAG AA) sur ses fonds, en clair comme en sombre.
  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFFAF0B18),
      brightness: brightness,
    );
    final scheme = dark
        ? base.copyWith(
            primary: const Color(0xFFFFB3AE),
            onPrimary: const Color(0xFF5F0010),
            primaryContainer: const Color(0xFF8C0A17),
            onPrimaryContainer: const Color(0xFFFFDAD6),
            secondary: const Color(0xFFA5C8F2),
            onSecondary: const Color(0xFF07304F),
            tertiary: const Color(0xFFF2B632),
            onTertiary: const Color(0xFF3F2E00),
            tertiaryContainer: const Color(0xFF5B4300),
            onTertiaryContainer: const Color(0xFFFFDEA0),
          )
        : base.copyWith(
            primary: const Color(0xFFA50E1A),
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFFFFDAD6),
            onPrimaryContainer: const Color(0xFF410004),
            secondary: const Color(0xFF1C486F),
            onSecondary: Colors.white,
            tertiary: const Color(0xFF6F5000),
            onTertiary: Colors.white,
            tertiaryContainer: const Color(0xFFF2B632),
            onTertiaryContainer: const Color(0xFF2B1D00),
          );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Entête rouge du logo en thème clair (blanc sur rouge : 7,8:1).
      appBarTheme: dark
          ? null
          : const AppBarTheme(
              backgroundColor: Color(0xFFA50E1A),
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              systemOverlayStyle: SystemUiOverlayStyle.light,
            ),
    );
  }

  static ThemeMode _mode(String value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Widget _app(AppServices? services) {
    final user = services?.user;
    return MaterialApp(
      title: 'Dictionnaire et Conjugaison',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _mode(user?.themeMode ?? 'system'),
      builder: (context, child) {
        // Taille du texte choisie, en plus de celle du système.
        final system = MediaQuery.textScalerOf(context).scale(1.0);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(system * (user?.textScale ?? 1.0)),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: services == null
          ? InstallScreen(
              progress: _progress,
              error: _error,
              onRetry: _start,
              words: _words,
              verbs: _verbs,
            )
          : const HomeScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = _services;
    if (services == null) return _app(null);
    return ListenableBuilder(
      listenable: services.user,
      builder: (context, _) =>
          AppScope(services: services, child: _app(services)),
    );
  }
}
