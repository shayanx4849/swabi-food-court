import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Handles ON-DEVICE local notifications only (pickup-time reminders).
///
/// This is NOT the same as Firebase Cloud Messaging (FCM) push
/// notifications, which require a server-side trigger (a Cloud Function)
/// and therefore the paid Blaze plan. Local notifications need no server,
/// no billing account, and work fully offline — perfect for scheduling a
/// "your pickup window is closing soon" alert right when a customer
/// reserves a bag.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(settings);

    // Android 13+ requires runtime notification permission. This is
    // intentionally NOT awaited — some devices/emulators are known to
    // leave this Future unresolved even after the user responds to the
    // dialog, which would otherwise hang init() indefinitely.
    _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Shows an immediate notification (used for instant in-app style alerts
  /// if you want a system-tray popup right away).
  static Future<void> showNow({required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'bachaokhana_general',
      'General',
      channelDescription: 'General app notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
  }

  /// Schedules a local reminder to fire a few minutes before a listing's
  /// pickup window closes, so the customer doesn't forget to collect it.
  static Future<void> schedulePickupReminder({
    required int notificationId,
    required String listingTitle,
    required String businessName,
    required DateTime pickupEnd,
  }) async {
    final reminderTime = pickupEnd.subtract(const Duration(minutes: 30));
    if (reminderTime.isBefore(DateTime.now())) return; // too late to schedule

    const androidDetails = AndroidNotificationDetails(
      'bachaokhana_reminders',
      'Pickup reminders',
      channelDescription: 'Reminders for upcoming food pickups',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      notificationId,
      'Pickup window closing soon',
      'Don\'t forget to collect "$listingTitle" from $businessName!',
      tz.TZDateTime.from(reminderTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
