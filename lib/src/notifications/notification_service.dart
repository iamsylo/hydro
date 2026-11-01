import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static const _channelId = 'hydration_reminders';
  static const _firstReminderId = 1000;
  static const _snoozeId = 9000;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  Future<void> scheduleReminders({
    required bool enabled,
    required DateTime now,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required double intervalHours,
    required bool stopAfterGoal,
    required bool goalReachedToday,
    required bool sound,
    required bool vibration,
  }) async {
    await initialize();
    await _plugin.cancelAll();
    await _configureNotificationChannel(
      sound: sound,
      vibration: vibration,
    );
    if (!enabled || (stopAfterGoal && goalReachedToday)) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Hydration reminders',
        channelDescription:
            'Gentle reminders to log water during active hours.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: sound,
        enableVibration: vibration,
        icon: '@mipmap/ic_launcher',
      ),
    );

    var notificationId = _firstReminderId;
    // Keep the queue bounded so startup and settings changes stay responsive.
    // The next app launch refreshes the rolling schedule.
    for (var dayOffset = 0; dayOffset < 3; dayOffset++) {
      final date = DateTime(now.year, now.month, now.day + dayOffset);
      var reminder = DateTime(
        date.year,
        date.month,
        date.day,
        startHour,
        startMinute,
      );
      final end = DateTime(
        date.year,
        date.month,
        date.day,
        endHour,
        endMinute,
      );
      if (end.isBefore(reminder)) {
        continue;
      }

      while (
          reminder.isBefore(end) && notificationId < _firstReminderId + 250) {
        if (reminder.isAfter(now)) {
          final scheduled = tz.TZDateTime.from(reminder, tz.local);
          await _plugin.zonedSchedule(
            notificationId++,
            'Time for a sip',
            'Take a moment to drink some water.',
            scheduled,
            details,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
        reminder = reminder.add(
          Duration(minutes: (intervalHours * 60).round()),
        );
      }
    }
  }

  Future<void> scheduleSnooze({
    required bool sound,
    required bool vibration,
  }) async {
    await initialize();
    await _configureNotificationChannel(
      sound: sound,
      vibration: vibration,
    );
    await _plugin.zonedSchedule(
      _snoozeId,
      'Hydro reminder',
      'Your snoozed hydration reminder is ready.',
      tz.TZDateTime.now(tz.local).add(const Duration(minutes: 30)),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Hydration reminders',
          channelDescription:
              'Gentle reminders to log water during active hours.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: sound,
          enableVibration: vibration,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> _configureNotificationChannel({
    required bool sound,
    required bool vibration,
  }) async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    // Android keeps channel sound and vibration settings after creation.
    // Recreate the channel so the in-app settings apply to future reminders.
    await android.deleteNotificationChannel(_channelId);
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        'Hydration reminders',
        description: 'Gentle reminders to log water during active hours.',
        importance: Importance.defaultImportance,
        playSound: sound,
        enableVibration: vibration,
      ),
    );
  }
}
