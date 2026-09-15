import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../shared/domain/finance_models.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> scheduleEmiReminder(Emi emi) async {
    await initialize();
    final reminder = DateTime(
      emi.dueDate.year,
      emi.dueDate.month,
      emi.dueDate.day,
      9,
    ).subtract(const Duration(days: 1));
    if (reminder.isBefore(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: emi.id.hashCode.abs() % 2147483647,
      title: 'EMI due tomorrow',
      body: '${emi.loanName} payment is due.',
      scheduledDate: tz.TZDateTime.from(reminder, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'emi_reminders',
          'EMI reminders',
          channelDescription: 'Reminders for upcoming EMI payments',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
