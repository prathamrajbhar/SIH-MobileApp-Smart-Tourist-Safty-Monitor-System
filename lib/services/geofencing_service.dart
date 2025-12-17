import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:vibration/vibration.dart';

import '../models/alert.dart';
import '../utils/logger.dart';
import 'api_service.dart';
import 'location_transmission_service.dart';

enum GeofenceEventType {
  enter,
  exit,
}

class GeofenceEvent {
  final RestrictedZone zone;
  final GeofenceEventType eventType;
  final LatLng currentLocation;
  final DateTime timestamp;

  GeofenceEvent({
    required this.zone,
    required this.eventType,
    required this.currentLocation,
    required this.timestamp,
  });
}

class GeofencingService {
  static GeofencingService? _instance;
  static GeofencingService get instance {
    _instance ??= GeofencingService._internal();
    return _instance!;
  }

  GeofencingService._internal();

  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final LocationTransmissionService _locationTransmissionService = LocationTransmissionService();

  List<RestrictedZone> _restrictedZones = [];
  Set<String> _currentZones = {}; // Track which zones user is currently in
  Set<String> _nearbyZones = {}; // Track which zones user is approaching
  StreamController<GeofenceEvent>? _eventController;
  Timer? _locationTimer;
  bool _isMonitoring = false;

  // Public access to restricted zones for map display
  List<RestrictedZone> get restrictedZones => List.unmodifiable(_restrictedZones);

  // Configuration
  static const Duration _checkInterval = Duration(seconds: 5); // Check location every 5 seconds for faster response
  static const double _nearbyThresholdMeters = 500.0; // Alert when within 500m
  static const double _criticalThresholdMeters = 100.0; // Critical alert when within 100m

  Stream<GeofenceEvent> get events {
    _eventController ??= StreamController<GeofenceEvent>.broadcast();
    return _eventController!.stream;
  }

  /// Public method to check if a point is inside a polygon
  bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    return _isPointInPolygon(point, polygon);
  }

  /// Public method to show simple restricted zone notification
  Future<void> showEmergencyZoneAlert(RestrictedZone zone, double distance, {required bool isInside}) async {
    await _showSimpleRestrictedZoneNotification(zone, distance, isInside: isInside);
  }

  /// Show simple restricted zone notification (similar to SOS nearby alerts)
  Future<void> _showSimpleRestrictedZoneNotification(RestrictedZone zone, double distance, {required bool isInside}) async {
    try {
      String title;
      String body;
      
      if (isInside) {
        title = '🚨 DANGER - Restricted Zone';
        body = 'You are inside "${zone.name}". Please leave immediately!';
      } else if (distance <= 100) {
        title = '⚠️ CRITICAL - Restricted Zone Nearby';
        body = 'DANGER: ${distance.toInt()}m from "${zone.name}". Do not proceed!';
      } else {
        title = '⚠️ WARNING - Restricted Zone Nearby';
        body = 'WARNING: ${distance.toInt()}m from "${zone.name}". Exercise caution.';
      }

      // Simple Android notification details (no custom sounds or complex settings)
      const androidDetails = AndroidNotificationDetails(
        'restricted_zone_alerts',
        'Restricted Zone Alerts',
        channelDescription: 'Alerts when approaching or entering restricted zones',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        autoCancel: true,
        category: AndroidNotificationCategory.alarm,
        icon: '@mipmap/ic_launcher',
      );

      // Simple iOS notification details
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Show simple notification
      await _notificationsPlugin.show(
        zone.id.hashCode, // Use zone ID as notification ID
        title,
        body,
        details,
        payload: 'restricted_zone:${zone.id}',
      );

      AppLogger.info('📲 Simple restricted zone notification sent: $title');
      
    } catch (e) {
      AppLogger.error('Failed to show restricted zone notification: $e');
    }
  }

  /// Initialize the geofencing service
  Future<void> initialize() async {
    await _initializeNotifications();
    await _loadRestrictedZones();
  }

  /// Initialize simple notification system
  Future<void> _initializeNotifications() async {
    // Create simple Android notification channel (no custom sounds to avoid errors)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'restricted_zone_alerts',
      'Restricted Zone Alerts',
      description: 'Alerts when approaching or entering restricted zones',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  /// Load restricted zones from API
  Future<void> _loadRestrictedZones() async {
    try {
      _restrictedZones = await _apiService.getRestrictedZones();
      AppLogger.info('Loaded ${_restrictedZones.length} restricted zones for geofencing');
    } catch (e) {
      AppLogger.error('Failed to load restricted zones for geofencing: $e');
      _restrictedZones = [];
    }
  }

  /// Start monitoring geofences
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;
    
    AppLogger.info('Starting geofencing monitoring service...');
    
    // Check location permission
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      AppLogger.warning('Location permission denied, cannot start geofencing');
      return;
    }

    await _loadRestrictedZones();
    
    _isMonitoring = true;
    
    // Start periodic location checking
    _locationTimer = Timer.periodic(_checkInterval, (timer) async {
      await _checkCurrentLocation();
    });
    
    AppLogger.info('Geofencing monitoring started with ${_restrictedZones.length} zones');
  }

  /// Stop monitoring geofences  
  void stopMonitoring() {
    AppLogger.info('Stopping geofencing monitoring...');
    _isMonitoring = false;
    _locationTimer?.cancel();
    _locationTimer = null;
    _currentZones.clear();
  }

  /// Check current location against all restricted zones
  Future<void> _checkCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final currentLocation = LatLng(position.latitude, position.longitude);
      
      final Set<String> newCurrentZones = {};
      final Set<String> newNearbyZones = {};
      
      // Check each restricted zone
      for (final zone in _restrictedZones) {
        final isInside = _isPointInPolygon(currentLocation, zone.polygonCoordinates);
        
        // Calculate distance to zone center for proximity alerts
        // Use proper geometric centroid or fallback to center from API
        final zoneCenter = zone.center ?? _calculatePolygonCentroid(zone.polygonCoordinates);
        final distanceToZone = Geolocator.distanceBetween(
          currentLocation.latitude,
          currentLocation.longitude,
          zoneCenter.latitude,
          zoneCenter.longitude,
        );
        
        if (isInside) {
          newCurrentZones.add(zone.id);
          
          // Check if this is a new entry
          if (!_currentZones.contains(zone.id)) {
            await _handleZoneEntry(zone, currentLocation, distanceToZone);
          }
        } else {
          // Check if this is an exit (was inside before, now outside)
          if (_currentZones.contains(zone.id)) {
            await _handleZoneExit(zone, currentLocation);
          }
          
          // Check proximity - critical distance (within 100m)
          if (distanceToZone <= _criticalThresholdMeters) {
            newNearbyZones.add('${zone.id}-critical');
            if (!_nearbyZones.contains('${zone.id}-critical')) {
              await _handleCriticalProximity(zone, currentLocation, distanceToZone);
            }
          }
          // Check proximity - nearby distance (within 500m)
          else if (distanceToZone <= _nearbyThresholdMeters) {
            newNearbyZones.add('${zone.id}-nearby');
            if (!_nearbyZones.contains('${zone.id}-nearby') && !_nearbyZones.contains('${zone.id}-critical')) {
              await _handleNearbyProximity(zone, currentLocation, distanceToZone);
            }
          }
        }
      }
      
      _currentZones = newCurrentZones;
      _nearbyZones = newNearbyZones;
      
    } catch (e) {
      // Log geofencing check error for debugging
      AppLogger.error('Geofencing check error: $e');
    }
  }

  /// Handle zone entry event
  Future<void> _handleZoneEntry(RestrictedZone zone, LatLng location, double distance) async {
    AppLogger.warning('🚨 EMERGENCY: User entered restricted zone: ${zone.name}');
    
    final event = GeofenceEvent(
      zone: zone,
      eventType: GeofenceEventType.enter,
      currentLocation: location,
      timestamp: DateTime.now(),
    );

    // Emit event
    _eventController?.add(event);
    
    // Trigger EMERGENCY haptic feedback
    await _triggerHapticFeedback(zone.type);
    
    // Show simple notification
    await _showSimpleRestrictedZoneNotification(zone, distance, isInside: true);
  }

  /// Handle critical proximity (within 100m)
  Future<void> _handleCriticalProximity(RestrictedZone zone, LatLng location, double distance) async {
    AppLogger.warning('⚠️ CRITICAL: User within ${distance.toInt()}m of restricted zone: ${zone.name}');
    
    // Trigger strong vibration
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(
          pattern: [0, 500, 200, 500],
          intensities: [0, 255, 0, 255],
        );
      }
    } catch (e) {
      AppLogger.warning('Vibration not supported: $e');
    }
    
    // Show simple critical proximity notification
    await _showSimpleRestrictedZoneNotification(zone, distance, isInside: false);
  }

  /// Handle nearby proximity (within 500m)
  Future<void> _handleNearbyProximity(RestrictedZone zone, LatLng location, double distance) async {
    AppLogger.info('⚠️ WARNING: User within ${distance.toInt()}m of restricted zone: ${zone.name}');
    
    // Trigger warning vibration
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(
          pattern: [0, 200, 100, 200],
          intensities: [0, 128, 0, 128],
        );
      }
    } catch (e) {
      AppLogger.warning('Vibration not supported: $e');
    }
    
    // Show simple nearby proximity notification
    await _showSimpleRestrictedZoneNotification(zone, distance, isInside: false);
  }

  /// Handle zone exit event  
  Future<void> _handleZoneExit(RestrictedZone zone, LatLng location) async {
    AppLogger.info('User exited restricted zone: ${zone.name}');
    
    final event = GeofenceEvent(
      zone: zone,
      eventType: GeofenceEventType.exit,
      currentLocation: location,
      timestamp: DateTime.now(),
    );

    // Send immediate location update for geofence exit
    try {
      await _locationTransmissionService.sendGeofenceExitLocation(
        geofenceType: zone.type.name,
        zoneName: zone.name,
      );
      AppLogger.warning('📍 Geofence exit location sent for zone: ${zone.name}');
    } catch (e) {
      AppLogger.error('❌ Failed to send geofence exit location: $e');
    }

    // Emit event
    _eventController?.add(event);
    
    // Light haptic feedback for exit
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 200);
      }
    } catch (e) {
      // Vibration not supported on this device
    }
  }

  /// Check if a point is inside a polygon using ray casting algorithm
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    
    bool inside = false;
    int j = polygon.length - 1;
    
    for (int i = 0; i < polygon.length; i++) {
      final pi = polygon[i];
      final pj = polygon[j];
      
      if (((pi.longitude > point.longitude) != (pj.longitude > point.longitude)) &&
          (point.latitude < (pj.latitude - pi.latitude) * (point.longitude - pi.longitude) / 
           (pj.longitude - pi.longitude) + pi.latitude)) {
        inside = !inside;
      }
      j = i;
    }
    
    return inside;
  }

  /// Trigger haptic feedback based on zone type
  Future<void> _triggerHapticFeedback(ZoneType zoneType) async {
    try {
      if (!(await Vibration.hasVibrator())) return;
      
      switch (zoneType) {
        case ZoneType.dangerous:
          // Strong, urgent vibration pattern
          await Vibration.vibrate(
            pattern: [0, 500, 200, 500, 200, 500],
            intensities: [0, 255, 0, 255, 0, 255],
          );
          break;
          
        case ZoneType.highRisk:
          // Medium intensity vibration pattern
          await Vibration.vibrate(
            pattern: [0, 400, 300, 400],
            intensities: [0, 200, 0, 200],
          );
          break;
          
        case ZoneType.restricted:
          // Moderate vibration
          await Vibration.vibrate(
            pattern: [0, 300, 200, 300],
            intensities: [0, 150, 0, 150],
          );
          break;
          
        case ZoneType.caution:
          // Gentle notification vibration
          await Vibration.vibrate(duration: 300);
          break;
          
        case ZoneType.safe:
          // No vibration for safe zones
          break;
      }
    } catch (e) {
      // Vibration not supported on this device
      AppLogger.warning('Vibration not supported: $e');
    }
  }



  /// Get current zones user is in
  List<String> get currentZoneIds => _currentZones.toList();
  
  /// Get current zone objects
  List<RestrictedZone> get currentZones {
    return _restrictedZones.where((zone) => _currentZones.contains(zone.id)).toList();
  }

  /// Calculate the geometric centroid of a polygon
  /// Uses proper polygon centroid algorithm instead of arithmetic mean
  LatLng _calculatePolygonCentroid(List<LatLng> polygonCoordinates) {
    if (polygonCoordinates.isEmpty) {
      throw ArgumentError('Cannot calculate centroid of empty polygon');
    }
    
    if (polygonCoordinates.length == 1) {
      return polygonCoordinates.first;
    }
    
    // For simple cases (3 or fewer points), use arithmetic mean as fallback
    if (polygonCoordinates.length <= 3) {
      final avgLat = polygonCoordinates.map((p) => p.latitude).reduce((a, b) => a + b) / polygonCoordinates.length;
      final avgLng = polygonCoordinates.map((p) => p.longitude).reduce((a, b) => a + b) / polygonCoordinates.length;
      return LatLng(avgLat, avgLng);
    }
    
    // Calculate proper geometric centroid for complex polygons
    double centroidX = 0;
    double centroidY = 0;
    double signedArea = 0;
    
    for (int i = 0; i < polygonCoordinates.length; i++) {
      final x0 = polygonCoordinates[i].latitude;
      final y0 = polygonCoordinates[i].longitude;
      final x1 = polygonCoordinates[(i + 1) % polygonCoordinates.length].latitude;
      final y1 = polygonCoordinates[(i + 1) % polygonCoordinates.length].longitude;
      
      final a = x0 * y1 - x1 * y0;
      signedArea += a;
      centroidX += (x0 + x1) * a;
      centroidY += (y0 + y1) * a;
    }
    
    signedArea *= 0.5;
    
    // Handle degenerate case where area is zero
    if (signedArea.abs() < 1e-10) {
      // Fallback to arithmetic mean
      final avgLat = polygonCoordinates.map((p) => p.latitude).reduce((a, b) => a + b) / polygonCoordinates.length;
      final avgLng = polygonCoordinates.map((p) => p.longitude).reduce((a, b) => a + b) / polygonCoordinates.length;
      return LatLng(avgLat, avgLng);
    }
    
    centroidX /= (6.0 * signedArea);
    centroidY /= (6.0 * signedArea);
    
    return LatLng(centroidX, centroidY);
  }

  /// Cleanup resources
  void dispose() {
    stopMonitoring();
    _eventController?.close();
    _eventController = null;
    _restrictedZones.clear();
    _currentZones.clear();
    AppLogger.info('GeofencingService disposed');
  }
}
