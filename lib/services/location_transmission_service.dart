import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';
import 'settings_manager.dart';
import '../utils/logger.dart';

/// Transmission types for logging and analytics
enum TransmissionTrigger {
  sos,
  appLaunch,
  geofenceExit,
  periodicUpdate,
  manual,
  emergency
}

/// Enhanced location transmission service for instant and periodic location updates
/// Handles SOS, app launch, geo-fence, and configurable interval location sending
class LocationTransmissionService {
  static final LocationTransmissionService _instance = LocationTransmissionService._internal();
  factory LocationTransmissionService() => _instance;
  LocationTransmissionService._internal();

  final ApiService _apiService = ApiService();
  final SettingsManager _settingsManager = SettingsManager();
  
  Timer? _periodicLocationTimer;
  Position? _lastTransmittedPosition;
  DateTime? _lastTransmissionTime;

  bool get isPeriodicTransmissionActive => _periodicLocationTimer?.isActive ?? false;

  /// Initialize the service and start periodic location updates if enabled
  Future<void> initialize() async {
    AppLogger.service('🚀 Initializing Location Transmission Service');
    
    await _settingsManager.initialize();
    await _apiService.initializeAuth();
    
    // Start periodic updates if enabled in settings
    if (await _settingsManager.getBool(SettingsManager.keyLocationTracking, defaultValue: true)) {
      await startPeriodicLocationUpdates();
    }
    
    AppLogger.service('✅ Location Transmission Service initialized');
  }

  /// Send immediate location for SOS/Panic button
  Future<Map<String, dynamic>> sendSOSLocation() async {
    AppLogger.emergency('🚨 Sending immediate SOS location');
    
    try {
      final position = await _getCurrentLocationFast();
      if (position == null) {
        throw Exception('Unable to get current location for SOS');
      }

      final result = await _transmitLocation(
        position, 
        TransmissionTrigger.sos,
        priority: 'critical',
        context: 'emergency_sos'
      );

      AppLogger.emergency('🚨 SOS location sent successfully: ${position.latitude}, ${position.longitude}');
      return result;
    } catch (e) {
      AppLogger.error('❌ Failed to send SOS location: $e');
      rethrow;
    }
  }

  /// Send immediate location when app launches
  Future<Map<String, dynamic>?> sendAppLaunchLocation() async {
    AppLogger.service('📱 Sending app launch location');
    
    try {
      final position = await _getCurrentLocationFast();
      if (position == null) {
        AppLogger.warning('⚠️ No location available for app launch transmission');
        return null;
      }

      final result = await _transmitLocation(
        position, 
        TransmissionTrigger.appLaunch,
        priority: 'high',
        context: 'app_launch'
      );

      AppLogger.service('✅ App launch location sent: ${position.latitude}, ${position.longitude}');
      return result;
    } catch (e) {
      AppLogger.warning('⚠️ Failed to send app launch location: $e');
      return null; // Non-critical, don't throw
    }
  }

  /// Send immediate location when exiting safe zone or entering restricted area
  Future<Map<String, dynamic>?> sendGeofenceExitLocation({
    required String geofenceType,
    required String zoneName,
  }) async {
    AppLogger.warning('🚪 Sending geofence exit location for: $zoneName ($geofenceType)');
    
    try {
      final position = await _getCurrentLocationFast();
      if (position == null) {
        AppLogger.warning('⚠️ No location available for geofence exit transmission');
        return null;
      }

      final result = await _transmitLocation(
        position, 
        TransmissionTrigger.geofenceExit,
        priority: 'high',
        context: 'geofence_exit',
        metadata: {
          'geofence_type': geofenceType,
          'zone_name': zoneName,
          'exit_timestamp': DateTime.now().toIso8601String(),
        }
      );

      AppLogger.warning('🚪 Geofence exit location sent: ${position.latitude}, ${position.longitude}');
      return result;
    } catch (e) {
      AppLogger.error('❌ Failed to send geofence exit location: $e');
      return null; // Non-critical for geofence, log but don't throw
    }
  }

  /// Start periodic location updates based on user settings
  Future<void> startPeriodicLocationUpdates() async {
    await stopPeriodicLocationUpdates(); // Stop any existing timer
    
    final intervalMinutes = await _getLocationUpdateInterval();
    if (intervalMinutes <= 0) {
      AppLogger.service('⏸️ Periodic location updates disabled by user settings');
      return;
    }

    AppLogger.service('⏰ Starting periodic location updates every $intervalMinutes minutes');
    
    _periodicLocationTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) async {
        try {
          await _sendPeriodicLocationUpdate();
        } catch (e) {
          AppLogger.warning('⚠️ Periodic location update failed: $e');
        }
      },
    );

    // Send initial location update
    try {
      await _sendPeriodicLocationUpdate();
    } catch (e) {
      AppLogger.warning('⚠️ Initial periodic location update failed: $e');
    }
  }

  /// Stop periodic location updates
  Future<void> stopPeriodicLocationUpdates() async {
    _periodicLocationTimer?.cancel();
    _periodicLocationTimer = null;
    AppLogger.service('⏹️ Periodic location updates stopped');
  }

  /// Send manual location update (from settings screen)
  Future<Map<String, dynamic>> sendManualLocationUpdate() async {
    AppLogger.service('👤 Sending manual location update');
    
    try {
      final position = await _getCurrentLocationFast();
      if (position == null) {
        throw Exception('Unable to get current location');
      }

      final result = await _transmitLocation(
        position, 
        TransmissionTrigger.manual,
        priority: 'normal',
        context: 'manual_update'
      );

      AppLogger.service('✅ Manual location sent: ${position.latitude}, ${position.longitude}');
      return result;
    } catch (e) {
      AppLogger.error('❌ Failed to send manual location: $e');
      rethrow;
    }
  }

  /// Update location update interval from settings
  Future<void> updateLocationInterval(int minutes) async {
    await _settingsManager.setInt('location_update_interval', minutes);
    
    if (minutes > 0 && await _settingsManager.getBool(SettingsManager.keyLocationTracking, defaultValue: true)) {
      await startPeriodicLocationUpdates(); // Restart with new interval
    } else {
      await stopPeriodicLocationUpdates();
    }
    
    AppLogger.service('⏰ Location update interval changed to $minutes minutes');
  }

  /// Get current location with fast timeout for emergency situations
  Future<Position?> _getCurrentLocationFast() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0, // Get exact location for emergencies
          timeLimit: Duration(seconds: 10), // Fast timeout
        ),
      );
    } catch (e) {
      AppLogger.warning('⚠️ Fast location failed, trying last known position: $e');
      return Geolocator.getLastKnownPosition();
    }
  }

  /// Core location transmission method
  Future<Map<String, dynamic>> _transmitLocation(
    Position position,
    TransmissionTrigger trigger, {
    String priority = 'normal',
    String context = '',
    Map<String, dynamic>? metadata,
  }) async {
    final transmissionData = {
      'lat': position.latitude,
      'lon': position.longitude,
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'speed': position.speed,
      'timestamp': DateTime.now().toIso8601String(),
      'trigger': trigger.name,
      'priority': priority,
      'context': context,
      if (metadata != null) 'metadata': metadata,
    };

    AppLogger.location('📍 Transmitting location: ${trigger.name} - ${position.latitude}, ${position.longitude}');

    final result = await _apiService.updateLocation(
      lat: position.latitude,
      lon: position.longitude,
      speed: position.speed >= 0 ? position.speed : null,
      altitude: position.altitude,
      accuracy: position.accuracy,
      timestamp: DateTime.now(),
    );

    if (result['success'] == true) {
      _lastTransmittedPosition = position;
      _lastTransmissionTime = DateTime.now();
      
      AppLogger.location('✅ Location transmitted successfully');
      return {
        ...result,
        'transmission_data': transmissionData,
      };
    } else {
      throw Exception(result['message'] ?? 'Location transmission failed');
    }
  }

  /// Send periodic location update
  Future<void> _sendPeriodicLocationUpdate() async {
    try {
      final position = await _getCurrentLocationFast();
      if (position == null) {
        AppLogger.warning('⚠️ No location available for periodic update');
        return;
      }

      // Check if location has changed significantly
      if (_shouldSkipPeriodicUpdate(position)) {
        AppLogger.service('⏭️ Skipping periodic update - location unchanged');
        return;
      }

      await _transmitLocation(
        position, 
        TransmissionTrigger.periodicUpdate,
        priority: 'normal',
        context: 'periodic_update'
      );

      AppLogger.service('⏰ Periodic location update sent');
    } catch (e) {
      AppLogger.warning('⚠️ Periodic location update failed: $e');
    }
  }

  /// Check if we should skip periodic update based on location change
  bool _shouldSkipPeriodicUpdate(Position currentPosition) {
    if (_lastTransmittedPosition == null) return false;
    if (_lastTransmissionTime == null) return false;
    
    final distance = Geolocator.distanceBetween(
      _lastTransmittedPosition!.latitude,
      _lastTransmittedPosition!.longitude,
      currentPosition.latitude,
      currentPosition.longitude,
    );
    
    final timeSinceLastUpdate = DateTime.now().difference(_lastTransmissionTime!).inMinutes;
    
    // Only skip if BOTH conditions are true: small movement AND recent update
    // Increased thresholds for better movement detection
    const double minimumMovementMeters = 100.0; // Increased from 50m
    const int minimumUpdateIntervalMinutes = 15; // Reduced from 30m for better responsiveness
    
    final isSmallMovement = distance < minimumMovementMeters;
    final isRecentUpdate = timeSinceLastUpdate < minimumUpdateIntervalMinutes;
    
    if (isSmallMovement && isRecentUpdate) {
      AppLogger.location('⏭️ Skipping update: ${distance.toInt()}m movement, ${timeSinceLastUpdate}m ago');
      return true;
    }
    
    return false;
  }

  /// Get location update interval from settings
  Future<int> _getLocationUpdateInterval() async {
    return await _settingsManager.getInt('location_update_interval', defaultValue: 15);
  }

  /// Get current transmission statistics
  Map<String, dynamic> getTransmissionStats() {
    return {
      'is_periodic_active': isPeriodicTransmissionActive,
      'last_transmission_time': _lastTransmissionTime?.toIso8601String(),
      'last_transmitted_position': _lastTransmittedPosition != null ? {
        'lat': _lastTransmittedPosition!.latitude,
        'lon': _lastTransmittedPosition!.longitude,
        'accuracy': _lastTransmittedPosition!.accuracy,
        'timestamp': _lastTransmittedPosition!.timestamp.toIso8601String(),
      } : null,
    };
  }

  /// Dispose resources
  void dispose() {
    _periodicLocationTimer?.cancel();
    _periodicLocationTimer = null;
    AppLogger.service('🧹 Location Transmission Service disposed');
  }
}