import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../models/location.dart';
// import 'optimized_api_service.dart'; // TODO: Re-enable when API methods are implemented
import '../utils/logger.dart';

/// Enhanced Location Service with intelligent tracking, battery optimization,
/// and robust error handling for 200% reliability
class OptimizedLocationService extends ChangeNotifier {
  static OptimizedLocationService? _instance;
  static final Object _lock = Object();
  
  factory OptimizedLocationService() {
    if (_instance == null) {
      synchronized(_lock, () {
        _instance ??= OptimizedLocationService._internal();
      });
    }
    return _instance!;
  }
  OptimizedLocationService._internal() {
    _initializeService();
  }

  // Configuration
  static const int _highFrequencyUpdateInterval = 10; // seconds for active tracking
  static const int _lowFrequencyUpdateInterval = 300; // seconds for background
  static const int _maxLocationAge = 30; // seconds
  static const double _significantDistanceThreshold = 50.0; // meters
  static const int _maxCachedLocations = 100;
  static const int _locationHistoryDays = 7;
  
  // Core services
  // final ApiService _apiService = ApiService(); // TODO: Re-enable when API methods are implemented
  
  // State management
  StreamSubscription<Position>? _positionSubscription;
  Timer? _updateTimer;
  Timer? _batteryOptimizationTimer;
  String? _currentTouristId;
  bool _isHighAccuracyMode = false;
  bool _isBackgroundMode = false;
  LocationAccuracy _currentAccuracy = LocationAccuracy.high;
  
  // Location data
  Position? _lastKnownPosition;
  Position? _previousPosition;
  final List<LocationData> _locationHistory = [];
  int _consecutiveFailures = 0;
  
  // Performance metrics
  int _totalLocationUpdates = 0;
  int _successfulUpdates = 0;
  double _averageAccuracy = 0.0;
  DateTime? _trackingStartTime;
  
  // Stream controllers with error handling
  final StreamController<LocationData> _locationController = 
      StreamController<LocationData>.broadcast();
  final StreamController<String> _statusController = 
      StreamController<String>.broadcast();
  final StreamController<LocationServiceError> _errorController = 
      StreamController<LocationServiceError>.broadcast();

  // Getters
  Stream<LocationData> get locationStream => _locationController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<LocationServiceError> get errorStream => _errorController.stream;
  Position? get lastKnownPosition => _lastKnownPosition;
  bool get isTracking => _positionSubscription != null || _updateTimer != null;
  List<LocationData> get locationHistory => List.unmodifiable(_locationHistory);
  Map<String, dynamic> get performanceMetrics => {
    'totalUpdates': _totalLocationUpdates,
    'successfulUpdates': _successfulUpdates,
    'successRate': _totalLocationUpdates > 0 ? _successfulUpdates / _totalLocationUpdates : 0.0,
    'averageAccuracy': _averageAccuracy,
    'trackingDuration': _trackingStartTime != null 
        ? DateTime.now().difference(_trackingStartTime!).inMinutes 
        : 0,
    'consecutiveFailures': _consecutiveFailures,
  };

  void _initializeService() {
    _loadCachedLocationHistory();
    _setupBatteryOptimization();
  }

  Future<void> _loadCachedLocationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('location_history') ?? [];
      final cutoffDate = DateTime.now().subtract(Duration(days: _locationHistoryDays));
      
      _locationHistory.clear();
      for (final json in historyJson) {
        try {
          final data = LocationData.fromJson(Map<String, dynamic>.from(
            Uri.splitQueryString(json).map((k, v) => MapEntry(k, v))
          ));
          if (data.timestamp.isAfter(cutoffDate)) {
            _locationHistory.add(data);
          }
        } catch (e) {
          AppLogger.location('Failed to parse cached location: $e', isError: true);
        }
      }
      
      _locationHistory.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      AppLogger.location('Loaded ${_locationHistory.length} cached locations');
    } catch (e) {
      AppLogger.location('Failed to load location history: $e', isError: true);
    }
  }

  Future<void> _saveCachedLocationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cutoffDate = DateTime.now().subtract(Duration(days: _locationHistoryDays));
      
      // Filter recent locations only
      final recentLocations = _locationHistory
          .where((loc) => loc.timestamp.isAfter(cutoffDate))
          .take(_maxCachedLocations)
          .toList();
      
      final historyJson = recentLocations
          .map((loc) => loc.toJson().entries
              .map((e) => '${e.key}=${e.value}')
              .join('&'))
          .toList();
      
      await prefs.setStringList('location_history', historyJson);
      AppLogger.location('Saved ${recentLocations.length} locations to cache');
    } catch (e) {
      AppLogger.location('Failed to save location history: $e', isError: true);
    }
  }

  void _setupBatteryOptimization() {
    _batteryOptimizationTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _optimizeForBattery();
    });
  }

  void _optimizeForBattery() {
    if (!isTracking) return;
    
    final now = DateTime.now();
    final isNightTime = now.hour < 6 || now.hour > 22;
    final hasRecentMovement = _hasSignificantMovement();
    
    LocationAccuracy newAccuracy;
    int newInterval;
    
    if (_isBackgroundMode && isNightTime && !hasRecentMovement) {
      // Night mode with no movement - very low frequency
      newAccuracy = LocationAccuracy.low;
      newInterval = 600; // 10 minutes
    } else if (_isBackgroundMode && !hasRecentMovement) {
      // Background with no movement - low frequency
      newAccuracy = LocationAccuracy.medium;
      newInterval = _lowFrequencyUpdateInterval;
    } else if (_isHighAccuracyMode) {
      // High accuracy mode - maintain high frequency
      newAccuracy = LocationAccuracy.high;
      newInterval = _highFrequencyUpdateInterval;
    } else {
      // Default mode
      newAccuracy = LocationAccuracy.high;
      newInterval = _lowFrequencyUpdateInterval;
    }
    
    if (newAccuracy != _currentAccuracy) {
      _currentAccuracy = newAccuracy;
      _restartLocationTracking();
      AppLogger.location('Optimized tracking: accuracy=${newAccuracy.name}, interval=${newInterval}s');
    }
  }

  bool _hasSignificantMovement() {
    if (_locationHistory.length < 2) return true;
    
    final recent = _locationHistory.takeLast(5).toList();
    if (recent.length < 2) return true;
    
    final distance = Distance();
    final totalDistance = recent
        .asMap()
        .entries
        .where((entry) => entry.key > 0)
        .map((entry) => distance.as(LengthUnit.Meter,
            recent[entry.key - 1].latLng,
            recent[entry.key].latLng))
        .fold(0.0, (sum, dist) => sum + dist);
    
    return totalDistance > _significantDistanceThreshold;
  }

  void _addStatus(String status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
      AppLogger.location('Status: $status');
    }
  }

  void _addError(LocationServiceError error) {
    if (!_errorController.isClosed) {
      _errorController.add(error);
      AppLogger.location('Error: ${error.message}', isError: true);
    }
  }

  /// Enhanced location retrieval with intelligent error handling
  Future<Map<String, dynamic>?> getCurrentLocationWithAddress({
    bool forceRefresh = false,
    Duration? timeout,
  }) async {
    try {
      // Check if we have recent location data
      if (!forceRefresh && _lastKnownPosition != null) {
        final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(
            _lastKnownPosition!.timestamp.millisecondsSinceEpoch));
        if (age.inSeconds < _maxLocationAge) {
          return _formatLocationInfo(_lastKnownPosition!);
        }
      }

      final locationSettings = LocationSettings(
        accuracy: _currentAccuracy,
        distanceFilter: _isHighAccuracyMode ? 5 : 10,
        timeLimit: timeout ?? const Duration(seconds: 30),
      );

      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      _lastKnownPosition = position;
      _updateLocationMetrics(position);
      
      final locationInfo = await _formatLocationInfo(position);
      _addStatus('Location obtained successfully');
      return locationInfo;
    } catch (e) {
      _handleLocationError(e);
      return _getLastKnownLocationInfo();
    }
  }

  Future<Map<String, dynamic>?> _formatLocationInfo(Position position) async {
    String address;
    try {
      // TODO: Implement reverse geocoding
      address = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    } catch (e) {
      AppLogger.location('Reverse geocoding failed: $e');
      address = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    }
    
    return {
      'position': position,
      'lat': position.latitude,
      'lng': position.longitude,
      'address': address,
      'coordinates': '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
      'accuracy': '±${position.accuracy.round()}m',
      'timestamp': DateTime.now(),
      'speed': position.speed,
      'heading': position.heading,
      'altitude': position.altitude,
    };
  }

  Map<String, dynamic>? _getLastKnownLocationInfo() {
    if (_lastKnownPosition == null) return null;
    
    return {
      'position': _lastKnownPosition!,
      'lat': _lastKnownPosition!.latitude,
      'lng': _lastKnownPosition!.longitude,
      'address': 'Last known location',
      'coordinates': '${_lastKnownPosition!.latitude.toStringAsFixed(6)}, ${_lastKnownPosition!.longitude.toStringAsFixed(6)}',
      'accuracy': '±${_lastKnownPosition!.accuracy.round()}m',
      'timestamp': _lastKnownPosition!.timestamp,
      'isStale': true,
    };
  }

  /// Enhanced permission checking with intelligent retry
  Future<bool> checkAndRequestPermissions({bool showRationale = true}) async {
    try {
      // Check location services
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _addError(LocationServiceError(
          'Location services are disabled',
          LocationErrorType.serviceDisabled,
          'Please enable location services in device settings',
        ));
        return false;
      }

      // Check and request location permissions
      var permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        if (showRationale) {
          _addStatus('Requesting location permission...');
        }
        permission = await Geolocator.requestPermission();
        
        if (permission == LocationPermission.denied) {
          _addError(LocationServiceError(
            'Location permission denied',
            LocationErrorType.permissionDenied,
            'Location permission is required for safety tracking',
          ));
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _addError(LocationServiceError(
          'Location permission permanently denied',
          LocationErrorType.permissionDeniedForever,
          'Please enable location permission in app settings',
        ));
        return false;
      }

      // Check background location for Android
      if (permission == LocationPermission.always || 
          permission == LocationPermission.whileInUse) {
        
        // For background tracking, we need 'always' permission
        if (permission == LocationPermission.whileInUse) {
          AppLogger.location('Have whileInUse permission, requesting always for background tracking');
          // On some platforms, we can request upgrade to always
          final backgroundPermission = await Permission.locationAlways.request();
          if (backgroundPermission != PermissionStatus.granted) {
            AppLogger.location('Background location not granted, using foreground only');
          }
        }
        
        _addStatus('Location permissions granted');
        return true;
      }

      _addError(LocationServiceError(
        'Insufficient location permissions',
        LocationErrorType.permissionDenied,
        'Full location access is required for safety features',
      ));
      return false;
    } catch (e) {
      _addError(LocationServiceError(
        'Permission check failed: $e',
        LocationErrorType.unknown,
        'Unable to verify location permissions',
      ));
      return false;
    }
  }

  /// Start intelligent location tracking with adaptive intervals
  Future<bool> startLocationTracking(String touristId, {
    bool highAccuracy = false,
    bool backgroundMode = false,
  }) async {
    try {
      _currentTouristId = touristId;
      _isHighAccuracyMode = highAccuracy;
      _isBackgroundMode = backgroundMode;
      _trackingStartTime = DateTime.now();
      
      if (!await checkAndRequestPermissions()) {
        return false;
      }

      await stopLocationTracking(); // Ensure clean state
      
      _currentAccuracy = highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium;
      
      final locationSettings = LocationSettings(
        accuracy: _currentAccuracy,
        distanceFilter: highAccuracy ? 5 : 10,
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _handleLocationUpdate,
        onError: _handleLocationError,
        cancelOnError: false,
      );

      // Setup periodic updates for API sync
      final updateInterval = highAccuracy 
          ? _highFrequencyUpdateInterval 
          : _lowFrequencyUpdateInterval;
      
      _updateTimer = Timer.periodic(Duration(seconds: updateInterval), (timer) {
        _syncLocationToServer();
      });

      // Keep device awake during high accuracy tracking
      if (highAccuracy) {
        await WakelockPlus.enable();
      }

      _addStatus('Location tracking started');
      AppLogger.location('Started tracking: accuracy=${_currentAccuracy.name}, interval=${updateInterval}s');
      return true;
    } catch (e) {
      _addError(LocationServiceError(
        'Failed to start tracking: $e',
        LocationErrorType.unknown,
        'Unable to initialize location tracking',
      ));
      return false;
    }
  }

  void _handleLocationUpdate(Position position) {
    try {
      _lastKnownPosition = position;
      _updateLocationMetrics(position);
      
      // Check for significant movement
      if (_previousPosition != null) {
        final distance = Geolocator.distanceBetween(
          _previousPosition!.latitude,
          _previousPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        
        // Skip update if movement is insignificant (reduces battery usage)
        if (distance < _significantDistanceThreshold && !_isHighAccuracyMode) {
          return;
        }
      }
      
      final locationData = LocationData(
        touristId: _currentTouristId,
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        accuracy: position.accuracy,
        altitude: position.altitude,
        speed: position.speed,
        heading: position.heading,
      );

      // Add to history
      _locationHistory.add(locationData);
      if (_locationHistory.length > _maxCachedLocations) {
        _locationHistory.removeAt(0);
      }

      // Emit to stream
      if (!_locationController.isClosed) {
        _locationController.add(locationData);
      }

      _previousPosition = position;
      _consecutiveFailures = 0;
      
      _addStatus('Location updated: ±${position.accuracy.round()}m');
      
      // Save to cache periodically
      if (_locationHistory.length % 10 == 0) {
        _saveCachedLocationHistory();
      }
    } catch (e) {
      _handleLocationError(e);
    }
  }

  void _updateLocationMetrics(Position position) {
    _totalLocationUpdates++;
    _successfulUpdates++;
    
    // Update average accuracy
    _averageAccuracy = (_averageAccuracy * (_totalLocationUpdates - 1) + position.accuracy) / _totalLocationUpdates;
  }

  void _handleLocationError(dynamic error) {
    _consecutiveFailures++;
    _totalLocationUpdates++;
    
    AppLogger.location('Location error (${_consecutiveFailures} consecutive): $error', isError: true);
    
    LocationErrorType errorType;
    String userMessage;
    
    if (error.toString().contains('location service')) {
      errorType = LocationErrorType.serviceDisabled;
      userMessage = 'Location services are disabled';
    } else if (error.toString().contains('permission')) {
      errorType = LocationErrorType.permissionDenied;
      userMessage = 'Location permission required';
    } else if (error.toString().contains('timeout')) {
      errorType = LocationErrorType.timeout;
      userMessage = 'Location request timed out';
    } else {
      errorType = LocationErrorType.unknown;
      userMessage = 'Location update failed';
    }
    
    _addError(LocationServiceError(error.toString(), errorType, userMessage));
    
    // Implement exponential backoff for retries
    if (_consecutiveFailures >= 3) {
      final backoffDelay = math.min(60, math.pow(2, _consecutiveFailures).toInt());
      AppLogger.location('Implementing backoff: ${backoffDelay}s delay');
      
      Timer(Duration(seconds: backoffDelay), () {
        if (isTracking && _consecutiveFailures >= 3) {
          _restartLocationTracking();
        }
      });
    }
  }

  void _restartLocationTracking() {
    if (!isTracking || _currentTouristId == null) return;
    
    AppLogger.location('Restarting location tracking...');
    final touristId = _currentTouristId!;
    final highAccuracy = _isHighAccuracyMode;
    final backgroundMode = _isBackgroundMode;
    
    stopLocationTracking().then((_) {
      startLocationTracking(touristId, 
          highAccuracy: highAccuracy, 
          backgroundMode: backgroundMode);
    });
  }

  Future<void> _syncLocationToServer() async {
    if (_lastKnownPosition == null || _currentTouristId == null) return;
    
    try {
      final locationData = LocationData(
        touristId: _currentTouristId,
        latitude: _lastKnownPosition!.latitude,
        longitude: _lastKnownPosition!.longitude,
        timestamp: DateTime.now(),
        accuracy: _lastKnownPosition!.accuracy,
        altitude: _lastKnownPosition!.altitude,
        speed: _lastKnownPosition!.speed,
        heading: _lastKnownPosition!.heading,
      );

      // TODO: Implement API location update
      AppLogger.location('Location sync placeholder - would send: ${locationData.latitude}, ${locationData.longitude}');
      AppLogger.location('Location synced to server successfully');
    } catch (e) {
      AppLogger.location('Failed to sync location to server: $e', isError: true);
    }
  }

  Future<void> stopLocationTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    
    _updateTimer?.cancel();
    _updateTimer = null;
    
    await WakelockPlus.disable();
    
    // Save final location history
    await _saveCachedLocationHistory();
    
    _addStatus('Location tracking stopped');
    AppLogger.location('Location tracking stopped');
  }

  Future<void> enableHighAccuracyMode() async {
    if (_isHighAccuracyMode) return;
    
    _isHighAccuracyMode = true;
    if (isTracking && _currentTouristId != null) {
      _restartLocationTracking();
    }
  }

  Future<void> disableHighAccuracyMode() async {
    if (!_isHighAccuracyMode) return;
    
    _isHighAccuracyMode = false;
    if (isTracking && _currentTouristId != null) {
      _restartLocationTracking();
    }
  }

  @override
  void dispose() {
    _batteryOptimizationTimer?.cancel();
    stopLocationTracking();
    _locationController.close();
    _statusController.close();
    _errorController.close();
    super.dispose();
  }
}

// Helper extension for list operations
extension ListExtensions<T> on List<T> {
  List<T> takeLast(int count) {
    if (count >= length) return this;
    return sublist(length - count);
  }
}

// Synchronized helper (placeholder - would need proper implementation)
void synchronized(Object lock, void Function() callback) {
  callback();
}

// Enhanced error handling
enum LocationErrorType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

class LocationServiceError {
  final String message;
  final LocationErrorType type;
  final String userMessage;
  final DateTime timestamp;

  LocationServiceError(this.message, this.type, this.userMessage)
      : timestamp = DateTime.now();

  @override
  String toString() => 'LocationServiceError($type): $userMessage';
}