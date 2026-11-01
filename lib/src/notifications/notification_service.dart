import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static const _notificationSound =
      RawResourceAndroidNotificationSound('drink_water');
  static const _firstReminderId = 1000;
  static const _goalReachedId = 2000;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  void Function()? _onNotificationTap;

  void setNotificationTapHandler(void Function() handler) {
    _onNotificationTap = handler;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        final id = response.id;
        if (id != null) {
          await _plugin.cancel(id);
        }
        _onNotificationTap?.call();
      },
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<bool> areNotificationsEnabled() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? true;
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
    final channelId = await _configureNotificationChannel(
      sound: sound,
      vibration: vibration,
    );
    if (!enabled) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'Hydration reminders',
        channelDescription:
            'Gentle reminders to log water during active hours.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: sound,
        sound: sound ? _notificationSound : null,
        enableVibration: vibration,
        ongoing: true,
        autoCancel: false,
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

      var reminderIndex = 0;
      while (
          reminder.isBefore(end) && notificationId < _firstReminderId + 250) {
        final isFirst = reminderIndex == 0;
        if (reminder.isAfter(now) && !(stopAfterGoal && goalReachedToday)) {
          final scheduled = tz.TZDateTime.from(reminder, tz.local);
          final copy = _reminderCopy(
            time: reminder,
            isFirst: isFirst,
            goalReachedToday: goalReachedToday,
            stopAfterGoal: stopAfterGoal,
          );
          await _plugin.zonedSchedule(
            notificationId++,
            copy.$1,
            copy.$2,
            scheduled,
            details,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
        reminderIndex++;
        reminder = reminder.add(
          Duration(minutes: (intervalHours * 60).round()),
        );
      }
    }
  }

  Future<void> showGoalReachedNotification({
    required bool enabled,
    required bool sound,
    required bool vibration,
  }) async {
    await initialize();
    if (!enabled || !await areNotificationsEnabled()) return;

    final channelId = await _configureNotificationChannel(
      sound: sound,
      vibration: vibration,
    );
    await _plugin.show(
      _goalReachedId,
      'Daily goal reached',
      'Congratulations! You reached your hydration goal today.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Hydration milestones',
          channelDescription: 'Notifications for reaching hydration goals.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: sound,
          sound: sound ? _notificationSound : null,
          enableVibration: vibration,
          autoCancel: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  (String, String) _reminderCopy({
    required DateTime time,
    required bool isFirst,
    required bool goalReachedToday,
    required bool stopAfterGoal,
  }) {
    if (goalReachedToday && !stopAfterGoal) {
      return (
        'Daily goal reached',
        'You have reached your goal. Be cautious about drinking too much water.',
      );
    }

    if (isFirst) {
      final greeting = time.hour < 12
          ? 'Good morning'
          : time.hour < 18
              ? 'Good afternoon'
              : 'Good evening';
      return (
        '$greeting, it is time to hydrate',
        'Start your day with your first sip of water.',
      );
    }

    return (
      'You still need to hydrate',
      'Take a moment to drink some water before the next reminder.',
    );
  }

  Future<String> _configureNotificationChannel({
    required bool sound,
    required bool vibration,
  }) async {
    final channelId =
        'hydration_reminders_v2_${sound ? 'sound' : 'silent'}_${vibration ? 'vibrate' : 'quiet'}';
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return channelId;

    await android.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        'Hydration reminders',
        description: 'Gentle reminders to log water during active hours.',
        importance: Importance.defaultImportance,
        playSound: sound,
        sound: sound ? _notificationSound : null,
        enableVibration: vibration,
      ),
    );
    return channelId;
  }
}
