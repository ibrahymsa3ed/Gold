import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationsService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(settings);
  }

  Future<void> showSettingsSavedNotification() async {
    const android = AndroidNotificationDetails(
      'settings',
      'Settings',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);

    await _plugin.show(
      1,
      'Gold Family App',
      'Notification settings updated',
      details,
    );
  }
}
