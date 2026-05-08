import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationDetails(
    'water_channel', 'Su Hatırlatıcı',
    channelDescription: 'Su içme hatırlatmaları',
    importance: Importance.max,
    priority: Priority.max,
    icon: '@mipmap/ic_launcher',
    playSound: true,
    enableVibration: true,
  );

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  // Anlık bildirim
  static Future<void> showWaterReminder() async {
    await _plugin.show(
      0,
      '💧 Su İçme Zamanı!',
      'Günlük su hedefine ulaşmayı unutma!',
      NotificationDetails(android: _channel),
    );
  }

  // Periyodik bildirim — everyMinute, hourly, daily
  static Future<void> scheduleRepeatingReminder(int minutes) async {
    await cancelReminders();

    RepeatInterval interval;
    String title;
    String body;

    if (minutes == 1) {
      interval = RepeatInterval.everyMinute;
      title = '💧 Test Bildirimi';
      body = 'Her dakika hatırlatıyorum!';
    } else if (minutes <= 60) {
      interval = RepeatInterval.hourly;
      title = '💧 Su İçme Zamanı!';
      body = 'Saatlik su hatırlatıcısı 💪';
    } else {
      interval = RepeatInterval.daily;
      title = '💧 Su İçme Zamanı!';
      body = 'Günlük su hedefini kontrol et!';
    }

    await _plugin.periodicallyShow(
      100,
      title,
      body,
      interval,
      NotificationDetails(android: _channel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancelReminders() async {
    await _plugin.cancel(100);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}