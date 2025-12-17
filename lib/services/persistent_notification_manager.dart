import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PersistentNotificationManager {
  static const String _channelId = 'location_tracking_channel';
  static const String _channelName = 'Location Tracking';
  static const int _notificationId = 1;
  
  static FlutterLocalNotificationsPlugin? _notificationsPlugin;
  static bool _isInitialized = false;
  
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    
    const AndroidInitializationSettings androidInit = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosInit = 
        DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
        );
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    
    await _notificationsPlugin!.initialize(initSettings);
    await _createNotificationChannel();
    
    _isInitialized = true;
  }

  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'High-priority location tracking for your safety',
      importance: Importance.high, // High priority for foreground service
      playSound: false,
      enableVibration: false,
      showBadge: true,
    );

    await _notificationsPlugin!
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> initializeNotificationChannel() async {
    await initialize();
  }

  static Future<void> showLocationNotification(String message) async {
    if (!_isInitialized) await initialize();
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Your location is shared every minute for safety',
      importance: Importance.high, // High priority
      priority: Priority.high, // High priority
      ongoing: true, // Cannot be dismissed
      autoCancel: false, // Cannot be auto-cancelled
      playSound: false,
      enableVibration: false,
      icon: '@mipmap/ic_launcher',
      showWhen: true, // Show timestamp
      onlyAlertOnce: true,
      usesChronometer: true, // Show elapsed time
      category: AndroidNotificationCategory.service,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin!.show(
      _notificationId,
      '🛡️ SafeHorizon - Protection Active',
      message,
      details,
    );
  }

  static Future<void> startPersistentNotification() async {
    await showLocationNotification('Location shared every minute for your safety');
  }

  static Future<void> updateLocationNotification(String locationInfo) async {
    if (!_isInitialized) await initialize();
    
    // Update notification with new location info
    await showLocationNotification(locationInfo);
  }

  static Future<void> stopPersistentNotification() async {
    if (_notificationsPlugin != null) {
      await _notificationsPlugin!.cancel(_notificationId);
    }
  }
}
