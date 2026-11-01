import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Rappel quotidien du mot du jour (Android seulement).
class DailyWordNotifier {
  DailyWordNotifier._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const int _id = 1;

  static bool get supported => Platform.isAndroid;

  static Future<void> _init() async {
    if (_initialized) return;
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    _initialized = true;
  }

  /// Active le rappel ; false si la permission est refusée ou impossible.
  static Future<bool> enable() async {
    if (!supported) return false;
    try {
      await _init();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      if (granted == false) return false;
      await _plugin.periodicallyShow(
        _id,
        'Mot du jour',
        'Découvrez le mot du jour dans Dictionnaire et Conjugaison.',
        RepeatInterval.daily,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'mot_du_jour',
            'Mot du jour',
            channelDescription: 'Rappel quotidien du mot du jour',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> disable() async {
    if (!supported) return;
    try {
      await _init();
      await _plugin.cancel(_id);
    } catch (_) {}
  }
}
