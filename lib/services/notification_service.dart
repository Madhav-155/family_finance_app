import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/time/ist_time.dart';
import '../shared/domain/finance_models.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    IstTime.initialize();
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
    final reminder = IstTime.at(
      year: emi.dueDate.year,
      month: emi.dueDate.month,
      day: emi.dueDate.day,
      hour: 9,
    ).subtract(const Duration(days: 1));
    if (reminder.isBefore(IstTime.now())) return;
    await _plugin.zonedSchedule(
      id: emi.id.hashCode.abs() % 2147483647,
      title: 'EMI due tomorrow',
      body: '${emi.loanName} payment is due.',
      scheduledDate: reminder,
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
