import 'package:dictionnaire_engine/conjugation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SQLite via FFI sur toutes les plateformes : même moteur partout, FTS5 inclus
  // (les bibliothèques natives viennent de sqlite3_flutter_libs).
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final conjugator = Conjugator.fromJson(
    await rootBundle.loadString('assets/conjugation_models.json'),
  );
  runApp(DictionnaireApp(conjugator: conjugator));
}
