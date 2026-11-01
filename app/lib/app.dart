import 'package:dictionnaire_engine/conjugation.dart';
import 'package:flutter/material.dart';
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

  ThemeData _theme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1B5E8C),
        brightness: brightness,
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
