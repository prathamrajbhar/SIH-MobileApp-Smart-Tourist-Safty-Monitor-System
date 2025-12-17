import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'persistent_notification_manager.dart';

@pragma('vm:entry-point')
class BackgroundLocationService {
  static const String _notificationChannelId = 'location_tracking_channel';
  static const int _notificationId = 1;
  
  // Location settings optimized for 1-minute updates
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high, // Higher accuracy for safety
    distanceFilter: 10, // Update if moved 10+ meters
  );

  /// Initialize the background service with optimized settings
  static Future<void> initializeService() async {
    try {
      
      final service = FlutterBackgroundService();

      // Initialize notification manager first
      await PersistentNotificationManager.initialize();
      
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: true, // Auto-start for high priority
          isForegroundMode: true, // Run as foreground service (high priority)
          notificationChannelId: _notificationChannelId,
          initialNotificationTitle: '🛡️ SafeHorizon - Protection Active',
          initialNotificationContent: 'Your location is being shared every minute for your safety',
          foregroundServiceNotificationId: _notificationId,
          autoStartOnBoot: true, // Restart after device reboot
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );
      
      // Start the persistent notification after service is configured
      await PersistentNotificationManager.startPersistentNotification();
      
      service.startService();
    } catch (e) {
      // Service initialization failed
    }
  }

  /// Main service entry point - optimized for battery efficiency
  @pragma('vm:entry-point')
  /// Entry point for the background service
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // Update location every 60 seconds (1 minute)
    Timer? serviceTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // Update notification with current time
          final now = DateTime.now();
          final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          
          service.setForegroundNotificationInfo(
            title: '🛡️ SafeHorizon - Protection Active',
            content: 'Location shared at $timeStr • Keeping you safe',
          );
          
          await _trackLocation(service);
        }
      } else {
        await _trackLocation(service);
      }
    });

    service.on('stopService').listen((event) {
      serviceTimer.cancel();
      service.stopSelf();
    });
  }

  /// iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  /// Track location with smart filtering for battery optimization
  static Future<void> _trackLocation(ServiceInstance service) async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        // Location permission required
        return;
      }

      // Get current position with battery-optimized settings
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      ).timeout(const Duration(seconds: 10));

      // Get tourist ID from preferences
      final prefs = await SharedPreferences.getInstance();
      final touristId = prefs.getString('tourist_id');
      
      if (touristId != null) {
        // Always send location every minute (no filtering)
        await _sendLocationUpdate(touristId, position);
        
        // Store last position and update time
        await prefs.setDouble('last_lat', position.latitude);
        await prefs.setDouble('last_lng', position.longitude);
        await prefs.setInt('last_update', DateTime.now().millisecondsSinceEpoch);
      } else {
        // Tourist ID not found
      }
    } catch (e) {
      // Location tracking error occurred
    }
  }

  /// Send location update to backend with error handling
  static Future<void> _sendLocationUpdate(String touristId, Position position) async {
    try {
      final touristIdInt = int.tryParse(touristId);
      if (touristIdInt == null) return;

      // Get API base URL from shared preferences (set during app initialization)
      final prefs = await SharedPreferences.getInstance();
      final apiBaseUrl = prefs.getString('api_base_url')!;

      await http.post(
        Uri.parse('$apiBaseUrl/location/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tourist_id': touristIdInt,
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      ).timeout(const Duration(seconds: 8));

    } catch (e) {
      // Location update error occurred
    }
  }

  /// Stop the background service
  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  /// Check if service is running
  static Future<bool> isServiceRunning() async {
    final service = FlutterBackgroundService();
    return service.isRunning();
  }
}
