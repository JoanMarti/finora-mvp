import 'dart:async';
import 'dart:ui' show Color;

import 'package:finora/domain/local_reminders.dart';
import 'package:finora/domain/purchases.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Reminders as Android notifications, scheduled on the device. Times are
/// Swiss local time, since Finora is for Switzerland.
class AndroidLocalReminders
    implements LocalReminderScheduler, NotificationPermissions {
  AndroidLocalReminders({
    required this.channelName,
    required this.channelDescription,
  });

  static const _channelId = 'finora_reminders';

  /// Localised in bootstrap; Android shows it in the app's notification
  /// settings.
  final String channelName;
  final String channelDescription;

  final _plugin = FlutterLocalNotificationsPlugin();
  final _opened = StreamController<String>.broadcast();
  Future<void>? _ready;

  Future<void> _init() => _ready ??= () async {
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.startsWith('/')) _opened.add(route);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final route = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true &&
        route != null &&
        route.startsWith('/')) {
      // Delivered after the first frame, once the router listens.
      Timer.run(() => _opened.add(route));
    }
  }();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Android 13 and later ask the user; earlier versions allow it unless
  /// the user turned notifications off.
  @override
  Future<bool> request() async {
    await _init();
    final android = _android;
    if (android == null) return false;
    final granted = await android.requestNotificationsPermission();
    return granted ?? await android.areNotificationsEnabled() ?? false;
  }

  @override
  Future<void> replaceAll(List<ScheduledReminder> reminders) async {
    await _init();
    await _plugin.cancelAll();
    if (reminders.isEmpty) return;
    final zurich = tz.getLocation('Europe/Zurich');
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@drawable/ic_notification',
        color: const Color(0xFF027DB9),
      ),
    );
    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        reminder.id,
        reminder.title,
        reminder.body,
        tz.TZDateTime(
          zurich,
          reminder.at.year,
          reminder.at.month,
          reminder.at.day,
          reminder.at.hour,
          reminder.at.minute,
        ),
        details,
        // Inexact is enough for a reminder a week ahead and needs no
        // exact-alarm permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: reminder.route,
      );
    }
  }

  @override
  Stream<String> get openedRoutes async* {
    await _init();
    yield* _opened.stream;
  }
}
