import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:vibration/vibration.dart';

import '../utils/logger.dart';
import 'api_service.dart';
import 'geofencing_service.dart';

/// Alert type for proximity alerts
enum ProximityAlertType {
  panicAlert,
  restrictedZone,
}

/// Proximity alert event
class ProximityAlertEvent {
  final ProximityAlertType type;
  final String title;
  final String description;
  final LatLng location;
  final double distanceKm;
  final String severity; // 'critical', 'high', 'medium'
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ProximityAlertEvent({
    required this.type,
    required this.title,
    required this.description,
    required this.location,
    required this.distanceKm,
    required this.severity,
    required this.timestamp,
    this.metadata,
  });

  String get distanceText {
    if (distanceKm < 0.1) {
      return '${(distanceKm * 1000).toInt()}m';
    }
    return '${distanceKm.toStringAsFixed(1)}km';
  }

  Color get severityColor {
    switch (severity) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow.shade700;
      default:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (type) {
      case ProximityAlertType.panicAlert:
        return Icons.emergency;
      case ProximityAlertType.restrictedZone:
        return Icons.warning_amber_rounded;
    }
  }
}

/// Service to monitor proximity to panic alerts and restricted zones
class ProximityAlertService {
  static ProximityAlertService? _instance;
  static ProximityAlertService get instance {
    _instance ??= ProximityAlertService._internal();
    return _instance!;
  }

  ProximityAlertService._internal();

  final ApiService _apiService = ApiService();
  final GeofencingService _geofencingService = GeofencingService.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = 
      FlutterLocalNotificationsPlugin();

  // Enhanced alert tracking with debouncing
  final Set<int> _acknowledgedPanicAlerts = {}; // Track shown panic alerts
  final Set<String> _acknowledgedZones = {}; // Track shown zone alerts
  final Map<String, DateTime> _lastAlertTimes = {}; // Debouncing timestamps
  final Map<String, Timer> _alertDebounceTimers = {}; // Individual debounce timers
  
  Timer? _monitoringTimer;
  bool _isMonitoring = false;
  String? _currentTouristId; // Current user's tourist ID to exclude own alerts
  
  // Debouncing configuration
  static const Duration _alertDebounceTime = Duration(seconds: 30);
  static const Duration _criticalAlertDebounceTime = Duration(seconds: 10);
  static const int _maxAlertsPerSession = 20;
  
  // Stream for proximity events with enhanced control
  StreamController<ProximityAlertEvent>? _eventController;
  Stream<ProximityAlertEvent> get events {
    _eventController ??= StreamController<ProximityAlertEvent>.broadcast();
    return _eventController!.stream;
  }
  
  /// Check if alert should be debounced
  bool _shouldDebounceAlert(String alertKey, String severity) {
    final now = DateTime.now();
    final lastAlertTime = _lastAlertTimes[alertKey];
    
    if (lastAlertTime == null) {
      return false; // First time seeing this alert
    }
    
    final debounceTime = severity == 'critical' 
        ? _criticalAlertDebounceTime 
        : _alertDebounceTime;
    
    final timeSinceLastAlert = now.difference(lastAlertTime);
    final shouldDebounce = timeSinceLastAlert < debounceTime;
    
    if (shouldDebounce) {
      AppLogger.service('🔇 Alert debounced: $alertKey (${timeSinceLastAlert.inSeconds}s ago)');
    }
    
    return shouldDebounce;
  }
  
  /// Record alert time for debouncing
  void _recordAlertTime(String alertKey) {
    _lastAlertTimes[alertKey] = DateTime.now();
    
    // Clean up old entries to prevent memory leaks
    if (_lastAlertTimes.length > _maxAlertsPerSession) {
      final sortedEntries = _lastAlertTimes.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      // Remove oldest 25% of entries
      final toRemove = sortedEntries.take(_maxAlertsPerSession ~/ 4);
      for (final entry in toRemove) {
        _lastAlertTimes.remove(entry.key);
      }
    }
  }

  // Stream for real-time location updates
  StreamController<LatLng>? _locationController;
  Stream<LatLng> get locationUpdates {
    _locationController ??= StreamController<LatLng>.broadcast();
    return _locationController!.stream;
  }

  // Track last known alerts for map display
  List<ProximityAlertEvent> _activeAlerts = [];
  List<ProximityAlertEvent> get activeAlerts => List.unmodifiable(_activeAlerts);

  // Configuration
  static const Duration _checkInterval = Duration(seconds: 10); // Real-time: check every 10 seconds
  static const double _panicAlertRadiusKm = 5.0; // Alert within 5km
  static const double _criticalDistanceKm = 1.0; // Critical within 1km
  static const double _warningDistanceKm = 2.5; // Warning within 2.5km
  
  // Location tracking
  StreamSubscription<Position>? _locationSubscription;

  /// Initialize the proximity alert service
  Future<void> initialize() async {
    await _initializeNotifications();
    AppLogger.service('✅ Proximity Alert Service initialized');
  }

  /// Set the current tourist ID to exclude own alerts
  void setCurrentTouristId(String? touristId) {
    _currentTouristId = touristId?.toString().trim();
    AppLogger.info('🆔 Proximity service tourist ID set: "$_currentTouristId" (type: ${_currentTouristId.runtimeType})');
    
    // Clear acknowledged alerts when tourist ID changes
    _acknowledgedPanicAlerts.clear();
    AppLogger.info('🧹 Cleared acknowledged alerts cache');
  }

  /// Initialize notification channels
  Future<void> _initializeNotifications() async {
    // Create Android notification channels
    const AndroidNotificationChannel panicChannel = AndroidNotificationChannel(
      'proximity_panic_alerts',
      'Nearby Panic Alerts',
      description: 'Alerts when panic alerts are reported nearby',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFFFF0000),
    );

    const AndroidNotificationChannel zoneChannel = AndroidNotificationChannel(
      'proximity_zone_alerts',
      'Nearby Restricted Zones',
      description: 'Alerts when approaching restricted or dangerous zones',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFFFFA500),
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(panicChannel);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(zoneChannel);

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

  /// Start monitoring for nearby alerts
  Future<void> startMonitoring() async {
    if (_isMonitoring) {
      AppLogger.service('Proximity monitoring already active');
      return;
    }

    AppLogger.service('🔍 Starting proximity alert monitoring...');

    // Check location permission
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || 
        permission == LocationPermission.deniedForever) {
      AppLogger.warning('Location permission denied for proximity monitoring');
      return;
    }

    _isMonitoring = true;

    // Start geofencing service if not already running
    await _geofencingService.startMonitoring();

    // Do initial check immediately
    await _checkProximity();

    // Start continuous location tracking
    _startContinuousLocationTracking();

    // Start periodic checking
    _monitoringTimer = Timer.periodic(_checkInterval, (timer) async {
      await _checkProximity();
    });

    AppLogger.service('✅ Proximity alert monitoring started (real-time mode)');
  }

  /// Start continuous location tracking for real-time updates
  void _startContinuousLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50, // Update every 50 meters
    );

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        final location = LatLng(position.latitude, position.longitude);
        
        // Emit location update
        _locationController?.add(location);
        
        // Check if we need to update proximity (significant movement)
        if (_shouldCheckProximity()) {
          _checkProximity();
        }
      },
      onError: (error) {
        AppLogger.error('Location tracking error: $error');
      },
    );
    
    AppLogger.service('🌍 Continuous location tracking started');
  }

  /// Check if proximity check is needed based on location changes
  bool _shouldCheckProximity() {
    // Always check - real-time mode
    return true;
  }

  /// Stop monitoring
  void stopMonitoring() {
    AppLogger.service('⏹️ Stopping proximity alert monitoring...');
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _acknowledgedPanicAlerts.clear();
    _acknowledgedZones.clear();
    _activeAlerts.clear();
  }

  /// Check proximity to panic alerts and zones
  Future<void> _checkProximity() async {
    if (!_isMonitoring) return;

    try {
      // Get current location
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 10));

      final currentLocation = LatLng(position.latitude, position.longitude);

      // Check panic alerts (only unresolved ones)
      await _checkNearbyPanicAlerts(currentLocation);

      // Geofencing service already handles restricted zones
      // We just listen to its events

    } catch (e) {
      AppLogger.error('Proximity check failed: $e');
    }
  }

  /// Check for nearby panic alerts (only unresolved/pending)
  Future<void> _checkNearbyPanicAlerts(LatLng currentLocation) async {
    try {
      AppLogger.info('🔍 Checking for nearby panic alerts...');
      AppLogger.info('🆔 Current tourist ID for filtering: $_currentTouristId');

      // Fetch only UNRESOLVED panic alerts, excluding current user's alerts
      final publicAlerts = await _apiService.getPublicPanicAlerts(
        limit: 100,
        hoursBack: 24, // Last 24 hours
        excludeTouristId: _currentTouristId, // Exclude current user's own alerts
      );
      
      AppLogger.info('📡 Server returned ${publicAlerts.length} alerts after server-side filtering');

      if (publicAlerts.isEmpty) {
        AppLogger.info('ℹ️ No unresolved panic alerts found');
        return;
      }

      AppLogger.info('📍 Found ${publicAlerts.length} unresolved panic alerts');

      // Filter for alerts within radius
      final nearbyAlerts = <Map<String, dynamic>>[];
      for (final alert in publicAlerts) {
        final location = alert['location'] as Map<String, dynamic>?;
        if (location == null) continue;

        final alertLat = (location['lat'] as num).toDouble();
        final alertLon = (location['lon'] as num).toDouble();

        final distance = _calculateDistance(
          currentLocation.latitude,
          currentLocation.longitude,
          alertLat,
          alertLon,
        );

        if (distance <= _panicAlertRadiusKm) {
          nearbyAlerts.add({
            ...alert,
            '_distance': distance,
          });
        }
      }

      if (nearbyAlerts.isEmpty) {
        AppLogger.info('ℹ️ No panic alerts within ${_panicAlertRadiusKm}km radius');
        return;
      }

      AppLogger.warning('🚨 Found ${nearbyAlerts.length} unresolved panic alerts within ${_panicAlertRadiusKm}km');

      // Sort by distance (nearest first)
      nearbyAlerts.sort((a, b) => 
        (a['_distance'] as double).compareTo(b['_distance'] as double));

      // Process alerts (only show new ones)
      for (final alert in nearbyAlerts) {
        final alertId = alert['alert_id'] as int;
        
        // COMPREHENSIVE CHECK: Skip if this alert is from current user
        final alertTouristId = alert['tourist_id']?.toString().trim();
        final alertUserId = alert['user_id']?.toString().trim();
        final alertCreatorId = alert['creator_id']?.toString().trim(); // Additional field check
        
        // Debug: Log all alert data for troubleshooting
        AppLogger.info('📋 Alert data: $alert');
        
        // Check all possible ID fields
        bool isOwnAlert = false;
        if (_currentTouristId != null && _currentTouristId!.isNotEmpty) {
          isOwnAlert = (alertTouristId == _currentTouristId) ||
                      (alertUserId == _currentTouristId) ||
                      (alertCreatorId == _currentTouristId);
        }
        
        if (isOwnAlert) {
          AppLogger.info('🚫 FILTERED OWN ALERT: ID=$alertId, touristId="$alertTouristId", userId="$alertUserId", creatorId="$alertCreatorId", currentId="$_currentTouristId"');
          continue;
        }
        
        AppLogger.info('✅ SHOWING OTHER\'S ALERT: ID=$alertId, touristId="$alertTouristId", userId="$alertUserId", currentId="$_currentTouristId"');
        
        // Skip if already acknowledged
        if (_acknowledgedPanicAlerts.contains(alertId)) continue;

        // Mark as acknowledged
        _acknowledgedPanicAlerts.add(alertId);

        final distance = alert['_distance'] as double;
        final location = alert['location'] as Map<String, dynamic>;
        final alertLat = (location['lat'] as num).toDouble();
        final alertLon = (location['lon'] as num).toDouble();
        final status = alert['status']?.toString() ?? 'older';
        final timeAgo = alert['time_ago']?.toString() ?? 'unknown';

        // Determine severity based on distance
        String severity;
        if (distance <= _criticalDistanceKm) {
          severity = 'critical';
        } else if (distance <= _warningDistanceKm) {
          severity = 'high';
        } else {
          severity = 'medium';
        }

        // Create event
        final event = ProximityAlertEvent(
          type: ProximityAlertType.panicAlert,
          title: '🚨 Emergency Alert Nearby',
          description: 'Unresolved emergency reported ${distance.toStringAsFixed(1)}km away ($timeAgo)',
          location: LatLng(alertLat, alertLon),
          distanceKm: distance,
          severity: severity,
          timestamp: DateTime.now(),
          metadata: {
            'alert_id': alertId,
            'status': status,
            'time_ago': timeAgo,
            'is_active': status == 'active',
          },
        );

        // Add to active alerts
        _activeAlerts.add(event);

        // Emit event
        _eventController?.add(event);

        // Show notification
        await _showPanicAlertNotification(event);

        // Trigger haptic feedback (stronger vibration for real-time alerts)
        await _triggerStrongHapticFeedback(severity);

        AppLogger.warning(
          '🚨 REAL-TIME ALERT: Unresolved panic alert ${event.distanceText} away (${severity.toUpperCase()})'
        );
      }

    } catch (e) {
      AppLogger.error('Failed to check nearby panic alerts: $e');
    }
  }

  /// Show panic alert notification
  Future<void> _showPanicAlertNotification(ProximityAlertEvent event) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'proximity_panic_alerts',
        'Nearby Panic Alerts',
        channelDescription: 'Alerts when panic alerts are reported nearby',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: event.severity == 'critical',
        category: AndroidNotificationCategory.alarm,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(
          event.description,
          contentTitle: event.title,
          summaryText: 'SafeHorizon Alert • ${event.distanceText} away',
        ),
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'view',
            'View on Map',
            showsUserInterface: true,
          ),
          const AndroidNotificationAction(
            'dismiss',
            'Dismiss',
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        event.metadata?['alert_id'] ?? DateTime.now().millisecondsSinceEpoch,
        event.title,
        event.description,
        details,
        payload: 'panic_alert:${event.metadata?['alert_id']}',
      );

      AppLogger.service('📲 Panic alert notification sent');
    } catch (e) {
      AppLogger.error('Failed to show panic alert notification: $e');
    }
  }

  /// Trigger strong haptic feedback for real-time alerts
  Future<void> _triggerStrongHapticFeedback(String severity) async {
    try {
      if (!(await Vibration.hasVibrator())) return;

      switch (severity) {
        case 'critical':
          // URGENT: Long strong pattern for critical real-time alerts
          await Vibration.vibrate(
            pattern: [0, 800, 300, 800, 300, 800, 300, 500],
            intensities: [0, 255, 0, 255, 0, 255, 0, 200],
          );
          break;
        case 'high':
          // Strong vibration pattern for high alerts
          await Vibration.vibrate(
            pattern: [0, 500, 200, 500, 200, 500],
            intensities: [0, 255, 0, 255, 0, 255],
          );
          break;
        case 'medium':
          // Medium vibration for medium alerts
          await Vibration.vibrate(
            pattern: [0, 400, 300, 400],
            intensities: [0, 200, 0, 200],
          );
          break;
      }
    } catch (e) {
      AppLogger.warning('Strong vibration not supported: $e');
    }
  }

  /// Get current active alerts count
  int get activeAlertsCount => _activeAlerts.length;

  /// Calculate distance between two points in kilometers
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  /// Reset acknowledged alerts (useful for testing or manual refresh)
  void resetAcknowledged() {
    _acknowledgedPanicAlerts.clear();
    _acknowledgedZones.clear();
    AppLogger.info('Acknowledged alerts cleared');
  }

  /// Debug method to print current state
  void debugCurrentState() {
    AppLogger.info('🔍 ProximityAlertService Debug State:');
    AppLogger.info('  - Current Tourist ID: "$_currentTouristId"');
    AppLogger.info('  - Acknowledged Panic Alerts: ${_acknowledgedPanicAlerts.length}');
    AppLogger.info('  - Acknowledged Zones: ${_acknowledgedZones.length}');
  }

  /// Dispose service
  void dispose() {
    stopMonitoring();
    _eventController?.close();
    _eventController = null;
    _locationController?.close();
    _locationController = null;
  }
}
