import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../provider/notification_provider.dart';

class NotiService {
  static final NotiService _instance = NotiService._internal();
  factory NotiService() => _instance;
  NotiService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initNotification() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iOSSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iOSSettings,
      );

      final initialized = await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initialized == true) {
        _isInitialized = true;
        print('Notifications initialized successfully');
      }

      // Request permissions for Android 13+
      await _requestPermissions();
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        print('Notification permission granted: $granted');
        
        // Don't automatically request exact alarm permission - only request when needed
        // final exactAlarmGranted = await androidPlugin.requestExactAlarmsPermission();
        // print('Exact alarm permission granted: $exactAlarmGranted');
      }
    } catch (e) {
      print('Error requesting notification permissions: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // Handle notification tap if needed
  }

  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      await initNotification();
    }

    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'smart_notes_channel',
        'Smart Notes Notifications',
        channelDescription: 'Channel for Smart Notes reminders and updates',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
      );
      
      print('Notification shown: $title - $body');
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    WidgetRef? ref,
  }) async {
    if (!_isInitialized) {
      await initNotification();
    }

    // Check if notifications are enabled
    if (ref != null) {
      final notificationsEnabled = ref.read(notificationsEnabledProvider);
      if (!notificationsEnabled) {
        print('Notifications are disabled - skipping schedule');
        return;
      }
    }

    try {
      // Request exact alarm permission only when needed
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        final exactAlarmGranted = await androidPlugin.requestExactAlarmsPermission();
        print('Exact alarm permission granted: $exactAlarmGranted');
        
        if (exactAlarmGranted != true) {
          print('Exact alarm permission denied - notification may not work precisely');
        }
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'smart_notes_channel',
        'Smart Notes Notifications',
        channelDescription: 'Channel for Smart Notes reminders and updates',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidDetails);

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      
      print('Notification scheduled: $title for ${scheduledDate.toString()}');
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      print('Notification cancelled: $id');
    } catch (e) {
      print('Error canceling notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      print('All notifications cancelled');
    } catch (e) {
      print('Error canceling all notifications: $e');
    }
  }
}

// Riverpod Provider
final notiServiceProvider = Provider<NotiService>((ref) => NotiService());