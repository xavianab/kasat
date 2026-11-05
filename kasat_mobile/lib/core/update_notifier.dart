import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Lock-screen notice for a new officer reply.
///
/// The text is fixed. The reply body, the tracking code, and the word
/// "police" are never passed in.
class UpdateNotifier {
  UpdateNotifier._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _title = 'Kasat';
  static const _body = 'You have an update';

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    _ready = true;
  }

  static Future<void> show() async {
    if (!_ready) return;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'kasat.updates',
        'Updates',
        channelDescription: 'A short note when something new is waiting',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
      ),
    );
    await _plugin.show(
      id: 1,
      title: _title,
      body: _body,
      notificationDetails: details,
    );
  }
}
