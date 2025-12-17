import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/location.dart';
import 'api_service.dart';
import 'background_location_service.dart';
import '../utils/logger.dart';

/// Industry-grade location service with smart filtering and battery optimization
class LocationService {
  // Singleton pattern
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Adaptive polling intervals based on movement and battery state
  static const int _baseLocationUpdateInterval = 300; // 5 minutes base
  static const int _activeLocationUpdateInterval = 60;  // 1 minute when active
  static const int _staticLocationUpdateInterval = 900; // 15 minutes when static
  
  // Real-time map display intervals
  static const int _realtimeLocationUpdateInterval = 2; // 2 seconds for map display
  static const int _highFrequencyLocationUpdateInterval = 1; // 1 second for high accuracy mode
  
  // Movement detection thresholds
  static const double _significantMovementThreshold = 10.0; // meters
  static const double _highSpeedThreshold = 5.0; // m/s (18 km/h)
  static const double _realtimeMovementThreshold = 1.0; // meters for real-time updates
  
  final ApiService _apiService = ApiService();
  StreamSubscription<Position>? _positionSubscription;
  Timer? _updateTimer;
  
  // Optimized location tracking state
  Position? _lastKnownPosition;
  Position? _lastSignificantPosition;
  DateTime _lastLocationUpdate = DateTime.now();
  int _currentUpdateInterval = _baseLocationUpdateInterval;
  
  // Smart filtering variables
  double _totalDistance = 0.0;
  DateTime _sessionStart = DateTime.now();
  bool _isStationary = false;
  int _stationaryCount = 0;
  
  final StreamController<LocationData> _locationController = StreamController<LocationData>.broadcast();
  final StreamController<LocationData> _realtimeLocationController = StreamController<LocationData>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();

  Stream<LocationData> get locationStream => _locationController.stream;
  Stream<LocationData> get realtimeLocationStream => _realtimeLocationController.stream;
  Stream<String> get statusStream => _statusController.stream;
  
  // Real-time tracking state
  bool _isRealtimeMode = false;
  Timer? _realtimeUpdateTimer;
  Position? _lastRealtimePosition;

  Position? get lastKnownPosition => _lastKnownPosition;
  bool get isTracking => _positionSubscription != null || _updateTimer != null;
  bool get isRealtimeModeActive => _isRealtimeMode;
  double get totalDistance => _totalDistance;
  Duration get sessionDuration => DateTime.now().difference(_sessionStart);
  
  /// Enhanced permission handling with mandatory requirements and persistent requests
  Future<bool> checkAndRequestPermissions({int maxRetries = 3}) async {
    AppLogger.service('🔐 Starting comprehensive permission check (attempt 1 of $maxRetries)');
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      AppLogger.service('📍 Permission check attempt $attempt/$maxRetries');
      
      // 1. Check location services first
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _addStatus('❌ Location services are disabled. This app requires location services to function.');
        AppLogger.warning('Location services disabled - showing persistent request');
        
        // Show persistent dialog until user enables location services
        await _showPersistentLocationServiceDialog();
        
        // Recheck after user interaction
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (attempt < maxRetries) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          return false;
        }
      }

      // 2. Request location permissions with persistence
      LocationPermission locationPermission = await Geolocator.checkPermission();
      
      if (locationPermission == LocationPermission.denied) {
        AppLogger.service('📍 Requesting location permission');
        locationPermission = await Geolocator.requestPermission();
        
        if (locationPermission == LocationPermission.denied) {
          _addStatus('❌ Location permission is required for safety features.');
          await _showPersistentPermissionDialog('Location', 'location access');
          
          if (attempt < maxRetries) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          return false;
        }
      }

      if (locationPermission == LocationPermission.deniedForever) {
        _addStatus('❌ Location permission permanently denied. Please enable in device settings.');
        await _showPersistentSettingsDialog('Location');
        return false;
      }

      // 3. Request background location permission (critical for safety)
      final backgroundLocationStatus = await Permission.locationAlways.status;
      if (backgroundLocationStatus != PermissionStatus.granted) {
        AppLogger.service('📍 Requesting background location permission');
        final result = await Permission.locationAlways.request();
        
        if (result != PermissionStatus.granted) {
          _addStatus('⚠️ Background location is required for continuous safety monitoring.');
          await _showPersistentPermissionDialog('Background Location', 'continuous location access');
          
          if (attempt < maxRetries) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          // Continue with reduced functionality warning
          AppLogger.warning('Continuing without background location - reduced functionality');
        }
      }

      // 4. Request notification permissions (mandatory for alerts)
      final notificationStatus = await Permission.notification.status;
      if (notificationStatus != PermissionStatus.granted) {
        AppLogger.service('🔔 Requesting notification permission');
        final result = await Permission.notification.request();
        
        if (result != PermissionStatus.granted) {
          _addStatus('❌ Notification permission is required for safety alerts.');
          await _showPersistentPermissionDialog('Notifications', 'safety alerts');
          
          if (attempt < maxRetries) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          return false;
        }
      }

      // 5. Request battery optimization exemption (important for background operation)
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      if (batteryStatus != PermissionStatus.granted) {
        AppLogger.service('🔋 Requesting battery optimization exemption');
        final result = await Permission.ignoreBatteryOptimizations.request();
        
        if (result != PermissionStatus.granted) {
          _addStatus('⚠️ Battery optimization exemption recommended for reliable operation.');
          // This is not critical, so we don't block on it
          AppLogger.warning('Battery optimization exemption not granted - may affect background operation');
        }
      }

      // All critical permissions granted
      _addStatus('✅ All permissions granted successfully.');
      AppLogger.service('✅ All permissions granted on attempt $attempt');
      return true;
    }

    AppLogger.error('❌ Failed to obtain required permissions after $maxRetries attempts');
    return false;
  }
  
  /// Show persistent dialog for location services
  Future<void> _showPersistentLocationServiceDialog() async {
    // This would typically show a dialog in the UI context
    // For now, we log and wait for manual intervention
    AppLogger.warning('📍 Location services required - user must enable manually');
    await Future.delayed(const Duration(seconds: 3));
  }
  
  /// Show persistent dialog for permissions
  Future<void> _showPersistentPermissionDialog(String permissionName, String purpose) async {
    AppLogger.warning('🔐 $permissionName permission required for $purpose');
    await Future.delayed(const Duration(seconds: 2));
  }
  
  /// Show dialog directing user to settings
  Future<void> _showPersistentSettingsDialog(String permissionName) async {
    AppLogger.warning('⚙️ $permissionName permission permanently denied - directing to settings');
    await Future.delayed(const Duration(seconds: 2));
  }

  // Helper method to safely add status updates
  void _addStatus(String status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);  
      AppLogger.service('Location Status: $status');
    }
  }

  /// Smart location filtering to reduce unnecessary updates and save battery
  bool _shouldProcessLocation(Position newPosition) {
    if (_lastSignificantPosition == null) {
      _lastSignificantPosition = newPosition;
      return true;
    }
    
    // Calculate distance from last significant position
    final distance = Geolocator.distanceBetween(
      _lastSignificantPosition!.latitude,
      _lastSignificantPosition!.longitude,
      newPosition.latitude,
      newPosition.longitude,
    );
    
    // Check if movement is significant
    final isSignificantMovement = distance >= _significantMovementThreshold;
    final isHighSpeed = newPosition.speed > _highSpeedThreshold;
    final timeSinceLastUpdate = DateTime.now().difference(_lastLocationUpdate);
    
    // Update stationary detection
    if (!isSignificantMovement) {
      _stationaryCount++;
      _isStationary = _stationaryCount >= 3;
    } else {
      _stationaryCount = 0;
      _isStationary = false;
      _totalDistance += distance;
    }
    
    // Adaptive update intervals
    if (_isStationary) {
      _currentUpdateInterval = _staticLocationUpdateInterval;
    } else if (isHighSpeed) {
      _currentUpdateInterval = _activeLocationUpdateInterval;
    } else {
      _currentUpdateInterval = _baseLocationUpdateInterval;
    }
    
    // Process location if:
    // 1. Significant movement detected
    // 2. High speed detected
    // 3. Forced update due to time interval
    final shouldUpdate = isSignificantMovement || 
                        isHighSpeed || 
                        timeSinceLastUpdate.inSeconds >= _currentUpdateInterval;
    
    if (shouldUpdate) {
      _lastSignificantPosition = newPosition;
      _lastLocationUpdate = DateTime.now();
      AppLogger.info('📍 Location update: ${distance.toStringAsFixed(1)}m moved, speed: ${newPosition.speed.toStringAsFixed(1)}m/s');
    }
    
    return shouldUpdate;
  }

  // Get current location with formatted address
  Future<Map<String, dynamic>?> getCurrentLocationWithAddress() async {
    try {
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      _lastKnownPosition = position;
      
      // Get human-readable address using reverse geocoding
      String address;
      try {
        address = await _apiService.reverseGeocode(
          lat: position.latitude,
          lon: position.longitude,
        );
      } catch (e) {
        // Fallback to coordinates if reverse geocoding fails
        address = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      }
      
      // Create a formatted location response
      final locationInfo = {
        'position': position,
        'lat': position.latitude,
        'lng': position.longitude,
        'address': address,
        'coordinates': '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
        'accuracy': '±${position.accuracy.round()}m',
        'timestamp': DateTime.now(),
      };

      _addStatus('Location sharing active');
      return locationInfo;
    } catch (e) {
      _addStatus('Your location will be sharing');
      return null;
    }
  }

  // Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      _lastKnownPosition = position;
      return position;
    } catch (e) {
      _addStatus('Failed to get current location: $e');
      return null;
    }
  }

  // Get location settings
  Future<Map<String, dynamic>> getLocationSettings() async {
    return {
      'isTracking': isTracking,
      'totalDistance': _totalDistance,
      'sessionDuration': sessionDuration.inMinutes,
      'isStationary': _isStationary,
      'updateInterval': _currentUpdateInterval,
      'lastUpdate': _lastLocationUpdate.toIso8601String(),
    };
  }

  /// Enable real-time location mode for map display (high frequency updates)
  Future<void> enableRealtimeMode() async {
    if (_isRealtimeMode) return;
    
    AppLogger.service('🗺️ Enabling real-time location mode for map display');
    _isRealtimeMode = true;
    
    // Start high-frequency position updates for real-time map display
    await _startRealtimeLocationUpdates();
  }
  
  /// Disable real-time location mode to save battery
  void disableRealtimeMode() {
    if (!_isRealtimeMode) return;
    
    AppLogger.service('🔋 Disabling real-time location mode to save battery');
    _isRealtimeMode = false;
    
    _realtimeUpdateTimer?.cancel();
    _realtimeUpdateTimer = null;
  }
  
  /// Start high-frequency location updates for real-time map display
  Future<void> _startRealtimeLocationUpdates() async {
    try {
      // High accuracy location settings for real-time updates
      const LocationSettings realtimeSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, // Update every 1 meter of movement
        timeLimit: Duration(seconds: 10),
      );
      
      // Start adaptive real-time location stream
      _realtimeUpdateTimer = Timer.periodic(
        Duration(seconds: _realtimeLocationUpdateInterval),
        (timer) async {
          try {
            final position = await Geolocator.getCurrentPosition(
              locationSettings: realtimeSettings,
            );
            
            // Always update for real-time map display (minimal filtering)
            if (_shouldUpdateRealtimeLocation(position)) {
              _handleRealtimeLocationUpdate(position);
              
              // Adaptive frequency based on GPS accuracy
              _adjustRealtimeFrequency(position.accuracy);
            }
          } catch (e) {
            AppLogger.warning('Real-time location update failed: $e');
          }
        },
      );
      
      AppLogger.service('🗺️ Real-time location updates started (${_realtimeLocationUpdateInterval}s intervals)');
    } catch (e) {
      AppLogger.error('Failed to start real-time location updates: $e');
    }
  }
  
  /// Adjust real-time update frequency based on GPS signal quality
  void _adjustRealtimeFrequency(double accuracy) {
    if (!_isRealtimeMode) return;
    
    int newInterval;
    if (accuracy <= 5) {
      // Excellent GPS - use high frequency
      newInterval = _highFrequencyLocationUpdateInterval;
    } else if (accuracy <= 15) {
      // Good GPS - use standard real-time frequency  
      newInterval = _realtimeLocationUpdateInterval;
    } else {
      // Poor GPS - reduce frequency to save battery
      newInterval = _realtimeLocationUpdateInterval * 2;
    }
    
    // Only restart timer if interval changed significantly
    if (newInterval != _realtimeLocationUpdateInterval && _realtimeUpdateTimer != null) {
      _realtimeUpdateTimer?.cancel();
      
      _realtimeUpdateTimer = Timer.periodic(
        Duration(seconds: newInterval),
        (timer) async {
          try {
            const LocationSettings realtimeSettings = LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 1,
              timeLimit: Duration(seconds: 10),
            );
            
            final position = await Geolocator.getCurrentPosition(
              locationSettings: realtimeSettings,
            );
            
            if (_shouldUpdateRealtimeLocation(position)) {
              _handleRealtimeLocationUpdate(position);
              _adjustRealtimeFrequency(position.accuracy);
            }
          } catch (e) {
            AppLogger.warning('Adaptive real-time location update failed: $e');
          }
        },
      );
      
      AppLogger.service('🔄 Adjusted real-time frequency to ${newInterval}s based on GPS accuracy (±${accuracy.toStringAsFixed(1)}m)');
    }
  }
  
  /// Check if real-time location should be updated (minimal filtering)
  bool _shouldUpdateRealtimeLocation(Position position) {
    if (_lastRealtimePosition == null) return true;
    
    // For real-time updates, use minimal movement threshold
    final distance = Geolocator.distanceBetween(
      _lastRealtimePosition!.latitude,
      _lastRealtimePosition!.longitude,
      position.latitude,
      position.longitude,
    );
    
    // Update if moved more than 1 meter or accuracy improved significantly
    return distance >= _realtimeMovementThreshold || 
           position.accuracy < (_lastRealtimePosition!.accuracy - 5.0);
  }
  
  /// Handle real-time location updates for map display
  void _handleRealtimeLocationUpdate(Position position) {
    _lastRealtimePosition = position;
    
    final locationData = LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
      accuracy: position.accuracy,
      speed: position.speed,
      altitude: position.altitude,
    );
    
    // Send to real-time stream for map display
    _realtimeLocationController.add(locationData);
    
    AppLogger.service('🗺️ Real-time location: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)} (±${position.accuracy.toStringAsFixed(1)}m)');
  }

  /// Start optimized location tracking with smart filtering and battery efficiency
  Future<void> startTracking() async {
    if (isTracking) {
      await stopTracking();
    }

    // Initialize API service with authentication
    await _apiService.initializeAuth();
    
    _addStatus('Initializing location services...');
    
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) return;

    _addStatus('Your location will be sharing');
    
    // Reset session tracking
    _sessionStart = DateTime.now();
    _totalDistance = 0.0;
    _isStationary = false;
    _stationaryCount = 0;

    try {
      // Get initial current location immediately
      final currentPosition = await getCurrentLocation();
      if (currentPosition != null) {
        _addStatus('Location sharing active');
        _lastSignificantPosition = currentPosition;
        _handleLocationUpdateOptimized(currentPosition, forceUpdate: true);
      }

      // Enable wake lock to prevent device from sleeping (only when needed)
      await WakelockPlus.enable();
      
      AppLogger.service('Using optimized foreground location tracking with smart filtering');
      
      // Adaptive location settings based on device capabilities
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.medium, // Changed from high to medium for battery
        distanceFilter: 5, // Update when user moves 5 meters
        timeLimit: Duration(seconds: 30), // Timeout for location requests
      );

      // Start continuous location tracking with smart filtering
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _addStatus('Location sharing active');
          _handleLocationUpdate(position);
        },
        onError: (error) {
          _addStatus('Location error: $error');
        },
      );

      // Set up periodic updates to backend
      _updateTimer = Timer.periodic(
        Duration(seconds: _currentUpdateInterval),
        (timer) async {
          if (_lastKnownPosition != null) {
            await _sendLocationToBackend(_lastKnownPosition!);
          }
        },
      );

    } catch (e) {
      _addStatus('Failed to start tracking: $e');
    }
  }

  /// Optimized location update handler with smart filtering
  void _handleLocationUpdateOptimized(Position position, {bool forceUpdate = false}) {
    // Apply smart filtering unless forced
    if (!forceUpdate && !_shouldProcessLocation(position)) {
      AppLogger.service('📍 Location filtered out (insufficient movement)');
      return;
    }
    
    AppLogger.service('📍 Processing location update: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}');
    
    _lastKnownPosition = position;
    
    // Create optimized location data
    final locationData = LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
      accuracy: position.accuracy,
      speed: position.speed,
      altitude: position.altitude,
    );
    
    // Emit to stream if controller is still active
    if (!_locationController.isClosed) {
      _locationController.add(locationData);
    }
    
    // Update location on server (async with exponential backoff)
    _updateLocationOnServerOptimized(position);
  }

  /// Legacy method for backward compatibility
  void _handleLocationUpdate(Position position) {
    _handleLocationUpdateOptimized(position);
  }

  /// Optimized server update with exponential backoff and batching
  int _serverUpdateFailCount = 0;
  static const int _maxRetryAttempts = 3;
  Timer? _batchUpdateTimer;
  final List<Position> _pendingUpdates = [];
  
  Future<void> _updateLocationOnServerOptimized(Position position) async {
    // Add to pending updates for potential batching
    _pendingUpdates.add(position);
    
    // Cancel existing timer and set new one for batching
    _batchUpdateTimer?.cancel();
    _batchUpdateTimer = Timer(const Duration(seconds: 5), () {
      _processPendingUpdates();
    });
  }
  
  Future<void> _processPendingUpdates() async {
    if (_pendingUpdates.isEmpty) return;
    
    // Use the most recent position for the update
    final latestPosition = _pendingUpdates.last;
    final updateCount = _pendingUpdates.length;
    _pendingUpdates.clear();
    
    try {
      await _updateLocationWithRetry(latestPosition);
      _serverUpdateFailCount = 0; // Reset on success
      AppLogger.service('✅ Batch updated $updateCount location(s) on server');
    } catch (e) {
      _serverUpdateFailCount++;
      final backoffDelay = math.pow(2, _serverUpdateFailCount.clamp(0, 5)).toInt();
      AppLogger.warning('❌ Location server update failed (attempt $_serverUpdateFailCount): $e');
      
      if (_serverUpdateFailCount <= _maxRetryAttempts) {
        AppLogger.info('🔄 Retrying location update in ${backoffDelay}s');
        Timer(Duration(seconds: backoffDelay), () {
          _processPendingUpdates();
        });
      }
    }
  }
  
  Future<void> _updateLocationWithRetry(Position position) async {
    await _apiService.updateLocation(
      lat: position.latitude,
      lon: position.longitude,
      speed: position.speed,
      altitude: position.altitude,
      accuracy: position.accuracy,
      timestamp: DateTime.now(),
    );
  }

  // Send location to backend
  Future<void> _sendLocationToBackend(Position position) async {
    try {
      await _apiService.updateLocation(
        lat: position.latitude,
        lon: position.longitude,
        speed: position.speed,
        altitude: position.altitude,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      AppLogger.warning('Failed to send location to backend: $e');
    }
  }

  // Stop location tracking and background service
  Future<void> stopTracking() async {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    
    _updateTimer?.cancel();
    _updateTimer = null;
    
    _batchUpdateTimer?.cancel();
    _batchUpdateTimer = null;
    
    // Stop real-time mode
    disableRealtimeMode();
    
    // Clear pending updates
    _pendingUpdates.clear();
    
    // Disable wake lock
    await WakelockPlus.disable();
    
    // Stop background service
    await BackgroundLocationService.stopService();
    
    // Safely add status if controller is not closed
    if (!_statusController.isClosed) {
      _addStatus('Location tracking stopped.');
    }
    
    AppLogger.service('🛑 Location tracking stopped');
  }

  // Optimized resource disposal with comprehensive cleanup
  void dispose() {
    AppLogger.service('🧹 Disposing LocationService resources');
    
    // Stop tracking first
    stopTracking();
    
    // Cancel batch update timer
    _batchUpdateTimer?.cancel();
    _batchUpdateTimer = null;
    
    // Clear pending updates
    _pendingUpdates.clear();
    
    // Close stream controllers safely
    if (!_locationController.isClosed) {
      _locationController.close();
    }
    
    if (!_realtimeLocationController.isClosed) {
      _realtimeLocationController.close();
    }
    
    if (!_statusController.isClosed) {
      _statusController.close();
    }
    
    // Reset state variables for memory efficiency
    _lastKnownPosition = null;
    _lastSignificantPosition = null;
    _totalDistance = 0.0;
    _isStationary = false;
    _stationaryCount = 0;
    _serverUpdateFailCount = 0;
    
    // Dispose API service
    _apiService.dispose();
    
    AppLogger.service('✅ LocationService disposed successfully');
  }
}
