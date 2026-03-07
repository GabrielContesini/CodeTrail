import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/app_entities.dart';

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _sessionChannelId = 'study_sessions';
  static const _reviewChannelId = 'review_reminders';
  static const _ongoingSessionNotificationId = 41001;
  static const _endingSessionNotificationId = 41002;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);

    const androidSettings = AndroidInitializationSettings('ic_stat_codetrail');

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidImplementation?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await initialize();
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.requestNotificationsPermission();
  }

  Future<void> showOngoingStudySession({
    required String title,
    required String body,
  }) async {
    await initialize();

    await _plugin.show(
      _ongoingSessionNotificationId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _sessionChannelId,
          'Sessões de estudo',
          channelDescription: 'Alertas para estudo em andamento.',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          onlyAlertOnce: true,
          icon: 'ic_stat_codetrail',
        ),
      ),
    );
  }

  Future<void> scheduleEndingSessionReminder({
    required DateTime remindAt,
    required String title,
    required String body,
  }) async {
    await initialize();

    final target = tz.TZDateTime.from(remindAt.toUtc(), tz.UTC);
    if (target.isBefore(tz.TZDateTime.now(tz.UTC))) {
      return;
    }

    await _plugin.zonedSchedule(
      _endingSessionNotificationId,
      title,
      body,
      target,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _sessionChannelId,
          'Sessões de estudo',
          channelDescription: 'Alertas para estudo em andamento.',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_codetrail',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelSessionNotifications() async {
    await initialize();
    await _plugin.cancel(_ongoingSessionNotificationId);
    await _plugin.cancel(_endingSessionNotificationId);
  }

  Future<void> scheduleReviewReminder(ReviewEntity review) async {
    await initialize();

    final target = tz.TZDateTime.from(review.scheduledFor.toUtc(), tz.UTC);
    if (target.isBefore(tz.TZDateTime.now(tz.UTC))) {
      return;
    }

    await _plugin.zonedSchedule(
      _idFor('review-${review.id}'),
      'Revisão ${review.intervalLabel}',
      'Hora de revisar ${review.title}.',
      target,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _reviewChannelId,
          'Revisões',
          channelDescription: 'Lembretes de revisão espaçada.',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_codetrail',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelReviewReminder(String reviewId) async {
    await initialize();
    await _plugin.cancel(_idFor('review-$reviewId'));
  }

  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  int _idFor(String value) => value.hashCode & 0x7fffffff;
}
