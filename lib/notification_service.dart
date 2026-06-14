import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final pendingNotificationTap = ValueNotifier<Map<String, String>?>(null);

  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static const _channelId = 'valorant_lineups';
  static const _channelName = 'Valorant Lineups';

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();

    // OneSignal.initialize() is called early in main() before runApp.
    // Here we request permission and set up listeners.
    await OneSignal.Notifications.requestPermission(true);

    // Handle notification tap from background or terminated state
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data == null) return;
      final type = data['type'] as String?;
      if (type != null) {
        pendingNotificationTap.value = {
          ...data.map((k, v) => MapEntry(k, v.toString())),
          'type': type,
        };
      }
    });

    // Show notifications when app is in foreground
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.notification.display();
    });

    // flutter_local_notifications — used for scheduled notifications (duels, exclusive)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      pendingNotificationTap.value = {'type': payload};
    }
  }

  /// Sets OneSignal external user ID so this device is targetable by Firebase UID.
  /// Call after the user signs in.
  static Future<void> loginUser(String uid) async {
    await OneSignal.login(uid);
  }

  /// Clears OneSignal external user ID. Call after the user signs out.
  static Future<void> logoutUser() async {
    await OneSignal.logout();
  }

  static Future<void> showLocalNotification(
    int id,
    String title,
    String body, {
    String? payload,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }

  /// Schedules a local notification at [scheduledDate].
  /// Uses inexact timing — does not require SCHEDULE_EXACT_ALARM permission.
  static Future<void> scheduleLocalNotification(
    int id,
    String title,
    String body,
    DateTime scheduledDate, {
    String? payload,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }
}
