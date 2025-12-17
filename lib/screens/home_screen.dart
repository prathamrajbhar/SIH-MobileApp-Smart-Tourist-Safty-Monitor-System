import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/tourist.dart';
import '../models/location.dart';
import '../models/alert.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/geofencing_service.dart';
import '../services/proximity_alert_service.dart';
import '../services/safety_score_manager.dart';
import '../utils/logger.dart';
import 'notification_screen.dart';
import 'map_screen.dart';
import '../widgets/safety_score_widget.dart';

import '../widgets/proximity_alert_widget.dart';

import 'efir_form_screen.dart';
import 'sos_countdown_screen.dart';
import 'safety_tips_screen.dart';
import 'danger_zones_screen.dart';
import 'tourist_services_screen.dart';
import 'trip_monitor_screen_professional.dart';

class HomeScreen extends StatefulWidget {
  final Tourist tourist;
  final VoidCallback? onMenuTap;

  const HomeScreen({
    super.key,
    required this.tourist,
    this.onMenuTap,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> 
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  
  // Singleton services for better memory management
  static final ApiService _apiService = ApiService();
  static final LocationService _locationService = LocationService();
  static final GeofencingService _geofencingService = GeofencingService.instance;
  static final ProximityAlertService _proximityAlertService = ProximityAlertService.instance;
  
  // Optimized state variables with proper types
  SafetyScore? _safetyScore;
  List<Alert> _alerts = const [];
  List<ProximityAlertEvent> _proximityAlerts = const [];
  
  // Loading states with debouncing
  bool _isLoadingSafetyScore = false;
  bool _isLoadingAlerts = false;
  bool _isLoadingLocation = false;
  
  // Caching and offline capabilities
  bool _safetyScoreOfflineMode = false;
  int _safetyScoreRetryCount = 0;
  static const int _maxRetryAttempts = 2; // Reduced for better UX
  
  // Timers and subscriptions for proper cleanup
  Timer? _safetyScoreRefreshTimer;
  Timer? _debounceTimer;
  
  // Location state optimization
  String _locationStatus = 'Initializing...';
  Map<String, dynamic>? _currentLocationInfo;
  
  // Performance monitoring
  DateTime _lastUpdate = DateTime.now();
  static const Duration _updateThrottle = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAppOptimized();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      default:
        break;
    }
  }

  /// Optimized app initialization with parallel loading and error recovery
  Future<void> _initializeAppOptimized() async {
    try {
      // Initialize core services first
      await _initializeServicesOptimized();
      
      // Load data in parallel for better performance
      await Future.wait([
        _loadSafetyScoreOptimized(),
        _loadAlertsOptimized(),
        _getCurrentLocationOptimized(),
      ], eagerError: false); // Continue even if some fail
      
      // Initialize monitoring services after data load
      _initializeGeofencingOptimized();
      _initializeProximityAlertsOptimized();
      
    } catch (e) {
      AppLogger.error('App initialization failed: $e');
      _handleInitializationError(e);
    }
  }

  /// Optimized lifecycle management methods
  void _handleAppResumed() {
    AppLogger.info('App resumed - refreshing critical data');
    if (_shouldRefreshData()) {
      _refreshCriticalData();
    }
  }

  void _handleAppPaused() {
    AppLogger.info('App paused - optimizing resources');
    _debounceTimer?.cancel();
    // Keep essential services running but reduce frequency
  }

  void _handleAppDetached() {
    AppLogger.info('App detached - cleaning up resources');
    _safetyScoreRefreshTimer?.cancel();
    _debounceTimer?.cancel();
  }

  void _handleInitializationError(dynamic error) {
    AppLogger.error('Initialization error handled: $error');
    if (mounted) {
      setState(() {
        _locationStatus = 'Initialization failed - retrying...';
      });
      // Retry initialization after delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _initializeAppOptimized();
      });
    }
  }

  bool _shouldRefreshData() {
    final now = DateTime.now();
    return now.difference(_lastUpdate) > _updateThrottle;
  }

  void _refreshCriticalData() {
    _lastUpdate = DateTime.now();
    _loadSafetyScoreOptimized();
    _getCurrentLocationOptimized();
  }

  /// Optimized service initialization with better error handling
  Future<void> _initializeServicesOptimized() async {
    try {
      // Initialize API service with retry logic
      await _apiService.initializeAuth();
      
      // Start location tracking with optimization
      await _locationService.startTracking();
      
      // Listen to location updates with debouncing
      _locationService.statusStream.listen((status) {
        _debounceLocationUpdate(status);
      });
      
      AppLogger.service('✅ Core services initialized successfully');
    } catch (e) {
      AppLogger.error('Service initialization failed: $e');
      rethrow;
    }
  }

  /// Enhanced location status debouncing with priority handling
  void _debounceLocationUpdate(String status) {
    // Cancel existing timer
    _debounceTimer?.cancel();
    
    // Handle critical status updates immediately
    final criticalStatuses = {
      'Location permission required',
      'Location services disabled',
      'Location permission denied',
      'Initialization failed'
    };
    
    if (criticalStatuses.any((critical) => status.contains(critical))) {
      // Update critical status immediately
      if (mounted) {
        setState(() {
          _locationStatus = status;
        });
      }
      AppLogger.warning('🚨 Critical location status: $status');
      return;
    }
    
    // Debounce non-critical updates
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _locationStatus = status;
        });
      }
    });
  }

  /// Optimized data loading methods
  Future<void> _loadSafetyScoreOptimized() async {
    if (_isLoadingSafetyScore) return;
    
    try {
      await _loadSafetyScore();
    } catch (e) {
      AppLogger.warning('Safety score loading failed, using cache: $e');
    }
  }

  Future<void> _loadAlertsOptimized() async {
    if (_isLoadingAlerts) return;
    
    try {
      await _loadAlerts();
    } catch (e) {
      AppLogger.warning('Alerts loading failed: $e');
    }
  }

  Future<void> _getCurrentLocationOptimized() async {
    if (_isLoadingLocation) return;
    
    try {
      await _getCurrentLocation();
    } catch (e) {
      AppLogger.warning('Location loading failed: $e');
    }
  }

  Future<void> _initializeGeofencingOptimized() async {
    try {
      // Start geofencing monitoring
      await _geofencingService.startMonitoring();
      
      // Listen to geofence events (notifications handled by GeofencingService)
      _geofencingService.events.listen((event) {
        if (mounted) {
          _showGeofenceAlert(event.zone, event.eventType);
        }
      });
      AppLogger.service('✅ Geofencing monitoring initialized');
    } catch (e) {
      AppLogger.warning('Geofencing initialization failed: $e');
    }
  }

  Future<void> _initializeProximityAlertsOptimized() async {
    try {
      // Initialize and start proximity alert service
      await _proximityAlertService.initialize();
      
      // Set current tourist ID to exclude own alerts - ensure it's a string
      final touristId = widget.tourist.id.toString().trim();
      AppLogger.info('🆔 Setting proximity alert tourist ID: "$touristId" (from: "${widget.tourist.id}")');
      _proximityAlertService.setCurrentTouristId(touristId);
      
      await _proximityAlertService.startMonitoring();
      
      // Debug current state
      _proximityAlertService.debugCurrentState();
      
      // Listen to proximity alert events with debouncing
      _proximityAlertService.events.listen((event) {
        if (mounted) {
          _debounceProximityAlert(event);
        }
      });
      
      AppLogger.service('✅ Proximity alerts monitoring initialized');
    } catch (e) {
      AppLogger.warning('Proximity alerts initialization failed: $e');
    }
  }
  
  /// Enhanced proximity alert handling with smart debouncing and memory management
  Timer? _proximityAlertDebounceTimer;
  final List<ProximityAlertEvent> _pendingProximityAlerts = [];
  static const Duration _proximityDebounceTime = Duration(milliseconds: 800);
  
  void _debounceProximityAlert(ProximityAlertEvent event) {
    // Add to pending list
    _pendingProximityAlerts.add(event);
    
    // Cancel existing timer and set new one
    _proximityAlertDebounceTimer?.cancel();
    _proximityAlertDebounceTimer = Timer(_proximityDebounceTime, () {
      _processPendingProximityAlerts();
    });
  }
  
  /// Process all pending proximity alerts in batch
  void _processPendingProximityAlerts() {
    if (_pendingProximityAlerts.isEmpty) return;
    
    final alertsToProcess = List<ProximityAlertEvent>.from(_pendingProximityAlerts);
    _pendingProximityAlerts.clear();
    
    setState(() {
      for (final event in alertsToProcess) {
        final alertId = event.metadata?['alert_id'];
        final isResolved = event.metadata?['resolved'] == true;
        
        // Remove if resolved
        if (isResolved) {
          _proximityAlerts.removeWhere((e) => 
              e.metadata?['alert_id'] == alertId);
          AppLogger.info('✅ Removed resolved alert from home screen: $alertId');
        } else {
          // Check for duplicates more efficiently
          final existingIndex = _proximityAlerts.indexWhere(
            (e) => e.metadata?['alert_id'] == alertId,
          );
          
          if (existingIndex == -1) {
            // Add new unresolved alert at the beginning
            _proximityAlerts.insert(0, event);
            AppLogger.info('🚨 Added new proximity alert: $alertId');
          } else {
            // Update existing alert with newer data
            _proximityAlerts[existingIndex] = event;
            AppLogger.info('🔄 Updated existing proximity alert: $alertId');
          }
        }
      }
      
      // Maintain memory efficiency - keep only last 15 alerts
      if (_proximityAlerts.length > 15) {
        final removed = _proximityAlerts.length - 15;
        _proximityAlerts.removeRange(15, _proximityAlerts.length);
        AppLogger.info('🧹 Cleaned up $removed old proximity alerts');
      }
    });
    
    // Show dialog for critical alerts (only if not resolved)
    final criticalAlerts = alertsToProcess.where(
      (event) => event.severity == 'critical' && event.metadata?['resolved'] != true,
    );
    
    if (criticalAlerts.isNotEmpty) {
      // Show only the most recent critical alert to avoid dialog spam
      final mostRecentCritical = criticalAlerts.last;
      _showProximityAlertDialog(mostRecentCritical);
    }
  }

  @override
  void dispose() {
    AppLogger.info('🧹 Disposing HomeScreen resources');
    
    // Cancel all timers and subscriptions
    _safetyScoreRefreshTimer?.cancel();
    _debounceTimer?.cancel();
    _proximityAlertDebounceTimer?.cancel();
    
    // Clean up pending alerts
    _pendingProximityAlerts.clear();
    
    // Clean up services properly
    _locationService.dispose();
    _geofencingService.stopMonitoring();
    _proximityAlertService.stopMonitoring();
    
    // Remove observers
    WidgetsBinding.instance.removeObserver(this);
    
    AppLogger.info('✅ HomeScreen disposed successfully');
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true; // Keep screen alive when switching tabs

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingLocation = true;
    });
    
    try {
      final locationInfo = await _locationService.getCurrentLocationWithAddress();
      
      if (mounted) {
        setState(() {
          _currentLocationInfo = locationInfo;
          _isLoadingLocation = false;
          if (locationInfo != null) {
            _locationStatus = 'Location sharing active';
          } else {
            _locationStatus = 'Location access unavailable';
          }
        });
      }
    } catch (e) {
      AppLogger.warning('Home screen location access failed: $e');
      
      if (mounted) {
        setState(() {
          _currentLocationInfo = null;
          _isLoadingLocation = false;
          
          // Provide user-friendly status message
          if (e.toString().contains('FlutterMap widget rendered')) {
            _locationStatus = 'Initializing location services...';
            // Retry after a short delay
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) _getCurrentLocation();
            });
          } else if (e.toString().contains('Permission denied')) {
            _locationStatus = 'Location permission required';
          } else if (e.toString().contains('Location services are disabled')) {
            _locationStatus = 'Location services disabled';
          } else {
            _locationStatus = 'Location temporarily unavailable';
          }
        });
      }
    }
  }


  
  void _showGeofenceAlert(RestrictedZone zone, GeofenceEventType eventType) {
    // Only show notification, no dialog
    AppLogger.info('Geofence alert: ${eventType == GeofenceEventType.enter ? "Entered" : "Exited"} ${zone.name}');
  }

  void _showProximityAlertDialog(ProximityAlertEvent event) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ProximityAlertDialog(alert: event),
    ).then((result) {
      // If user taps "View on Map", navigate to map screen
      if (result == 'view_map') {
        // You can add navigation to map screen here
        // For now, just log
        AppLogger.info('User wants to view alert on map');
      }
    });
  }

  Future<void> _loadSafetyScore() async {
    AppLogger.api('🎯 Enhanced safety score loading for tourist: ${widget.tourist.id}');
    
    if (_isLoadingSafetyScore) {
      AppLogger.api('⏳ Safety score loading already in progress, skipping...');
      return;
    }

    setState(() {
      _isLoadingSafetyScore = true;
      _safetyScoreOfflineMode = false;
    });

    try {
      // First, try to get cached data for immediate display
      Map<String, dynamic>? cachedScore = await SafetyScoreManager.getCachedSafetyScore();
      if (cachedScore != null && _safetyScore == null) {
        AppLogger.api('⚡ Displaying cached safety score while loading fresh data');
        _updateSafetyScoreUI(cachedScore, isFromCache: true);
      }

      // Attempt to load fresh data with retry logic
      Map<String, dynamic>? freshScore = await _loadSafetyScoreWithRetry();
      
      if (freshScore != null) {
        // Success - use fresh data
        AppLogger.api('✅ Fresh safety score loaded successfully');
        await SafetyScoreManager.cacheSafetyScore(freshScore);
        _updateSafetyScoreUI(freshScore);
        _safetyScoreRetryCount = 0; // Reset retry count on success
        _schedulePeriodicRefresh();
      } else {
        // Failed - try intelligent offline calculation
        AppLogger.warning('⚠️ API failed, attempting offline calculation...');
        Map<String, dynamic>? offlineScore = await _calculateOfflineSafetyScore();
        
        if (offlineScore != null) {
          AppLogger.api('🔋 Using offline safety score calculation');
          _updateSafetyScoreUI(offlineScore, isOffline: true);
        } else if (cachedScore != null) {
          AppLogger.api('💾 Falling back to cached data');
          _updateSafetyScoreUI(cachedScore, isFromCache: true);
        } else {
          // Last resort - show default safe score with warning
          _showFallbackSafetyScore();
        }
      }
    } catch (e) {
      AppLogger.error('🚨 Critical error in safety score loading: $e');
      _handleSafetyScoreError(e);
    } finally {
      setState(() {
        _isLoadingSafetyScore = false;
      });
    }
  }

  /// Load safety score with intelligent retry logic
  Future<Map<String, dynamic>?> _loadSafetyScoreWithRetry() async {
    for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        AppLogger.api('📡 Attempt $attempt/$_maxRetryAttempts: Calling getSafetyScore API...');
        
        final response = await _apiService.getSafetyScore().timeout(
          Duration(seconds: 10 + (attempt * 5)), // Progressive timeout
        );
        
        AppLogger.api('📋 Received response: $response');
        
        if (response['success'] == true) {
          AppLogger.api('✅ API call successful on attempt $attempt');
          return {
            "success": true,
            "safety_score": response['safety_score'],
            "risk_level": response['risk_level'],
            "last_updated": response['last_updated'],
            "source": "api",
          };
        } else if (response['auth_error'] == true) {
          AppLogger.error('🚫 Authentication error - stopping retry attempts');
          return null; // Don't retry auth errors
        } else {
          AppLogger.warning('⚠️ API returned success=false on attempt $attempt: $response');
        }
      } catch (e) {
        AppLogger.warning('🔄 Attempt $attempt failed: $e');
        
        if (attempt < _maxRetryAttempts) {
          int delaySeconds = attempt * 2; // Progressive delay: 2s, 4s, 6s
          AppLogger.api('⏱️ Waiting ${delaySeconds}s before retry...');
          await Future.delayed(Duration(seconds: delaySeconds));
        }
      }
    }
    
    AppLogger.error('❌ All retry attempts failed for safety score');
    _safetyScoreRetryCount++;
    return null;
  }

  /// Calculate safety score offline using intelligent algorithms
  Future<Map<String, dynamic>?> _calculateOfflineSafetyScore() async {
    try {
      // Get current location
      LocationData? currentLocation;
      if (_currentLocationInfo != null) {
        currentLocation = LocationData(
          touristId: widget.tourist.id,
          latitude: _currentLocationInfo!['lat'] ?? 0.0,
          longitude: _currentLocationInfo!['lng'] ?? 0.0,
          timestamp: DateTime.now(),
        );
      }

      // Get cached risk zones and incidents
      List<Map<String, dynamic>> riskZones = []; // TODO: Implement zone caching
      List<Map<String, dynamic>> recentIncidents = []; // TODO: Implement incident caching
      
      // Get cached score for smoothing
      int? previousScore = _safetyScore?.score;
      
      // Calculate using intelligent algorithm
      return await SafetyScoreManager.calculateIntelligentSafetyScore(
        currentLocation: currentLocation,
        riskZones: riskZones,
        recentIncidents: recentIncidents,
        timeOfDay: DateTime.now().hour.toString(),
        cachedScore: previousScore,
      );
    } catch (e) {
      AppLogger.error('🚨 Offline calculation failed: $e');
      return null;
    }
  }

  /// Update the UI with safety score data
  void _updateSafetyScoreUI(Map<String, dynamic> scoreData, {bool isFromCache = false, bool isOffline = false}) {
    final score = SafetyScore(
      touristId: widget.tourist.id,
      score: scoreData['safety_score'] ?? 75,
      riskLevel: scoreData['risk_level'] ?? 'medium',
      scoreBreakdown: Map<String, double>.from(
        scoreData['score_breakdown']?.map((k, v) => MapEntry(k, v.toDouble())) ?? {}
      ),
      componentWeights: Map<String, double>.from(
        scoreData['component_weights']?.map((k, v) => MapEntry(k, v.toDouble())) ?? {}
      ),
      recommendations: List<String>.from(scoreData['recommendations'] ?? []),
      lastUpdated: DateTime.tryParse(scoreData['last_updated'] ?? '') ?? DateTime.now(),
    );
    
    setState(() {
      _safetyScore = score;
      _safetyScoreOfflineMode = isOffline;
    });
    
    // Log the update with appropriate emoji
    String source = isFromCache ? '💾 cache' : isOffline ? '🔋 offline' : '🌐 API';
    AppLogger.api('🎉 Safety score updated from $source: ${score.score}% (${score.level})');
    
    // Show user-friendly notification for offline mode
    if (isOffline && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white),
              SizedBox(width: 8),
              Text('Using offline safety calculation'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Handle safety score loading errors gracefully
  void _handleSafetyScoreError(dynamic error) {
    AppLogger.error('📍 Error details: ${error.runtimeType} - ${error.toString()}');
    
    String userMessage = 'Unable to load safety score';
    Color backgroundColor = Colors.red;
    
    // Provide specific user-friendly messages based on error type
    if (error.toString().contains('TimeoutException')) {
      userMessage = 'Connection timeout - using cached data';
      backgroundColor = Colors.orange;
    } else if (error.toString().contains('SocketException')) {
      userMessage = 'No internet connection - using offline mode';
      backgroundColor = Colors.blue;
    } else if (_safetyScoreRetryCount > 5) {
      userMessage = 'Service temporarily unavailable';
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text(userMessage)),
            ],
          ),
          backgroundColor: backgroundColor,
          duration: Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _loadSafetyScore(),
          ),
        ),
      );
    }
  }

  /// Show error state when safety score cannot be loaded
  void _showFallbackSafetyScore() {
    // No mock data - show null to trigger error UI
    setState(() {
      _safetyScore = null;
      _safetyScoreOfflineMode = true;
    });
    
    AppLogger.warning('❌ Unable to load safety score from API - showing error state');
    
    // Show error message to user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Unable to load safety score. Please check your connection and try again.'),
              ),
            ],
          ),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Schedule periodic refresh of safety score
  void _schedulePeriodicRefresh() {
    _safetyScoreRefreshTimer?.cancel();
    _safetyScoreRefreshTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      if (!_isLoadingSafetyScore) {
        AppLogger.api('🔄 Periodic safety score refresh');
        _loadSafetyScore();
      }
    });
  }

  Future<void> _loadAlerts() async {
    if (_isLoadingAlerts) return;
    
    setState(() => _isLoadingAlerts = true);
    
    try {
      // Get current location for area-based alerts
      final position = await _locationService.getCurrentLocation();
      
      List<Alert> activeAlerts = [];
      if (position != null) {
        // Load active alerts in the user's area
        activeAlerts = await _apiService.getActiveAlerts(
          latitude: position.latitude,
          longitude: position.longitude,
          radiusKm: 15.0, // 15km radius for home screen alerts
        );
      } else {
        // Load active alerts without location filtering
        activeAlerts = await _apiService.getActiveAlerts();
      }
      
      if (mounted) {
        setState(() {
          _alerts = activeAlerts;
          _isLoadingAlerts = false;
        });
      }
      
      AppLogger.info('🏠 Loaded ${activeAlerts.length} active alerts for home screen');

      // ENHANCED: Also check for restricted zones when loading alerts
      if (position != null) {
        await _checkNearbyRestrictedZonesFromHome(LatLng(position.latitude, position.longitude));
      }
    } catch (e) {
      AppLogger.error('Failed to load alerts: $e');
      if (mounted) {
        setState(() {
          _alerts = [];
          _isLoadingAlerts = false;
        });
      }
    }
  }

  /// Check for nearby restricted zones from home screen and trigger alerts if user is close to them
  Future<void> _checkNearbyRestrictedZonesFromHome(LatLng currentLocation) async {
    try {
      AppLogger.info('🏠 Checking nearby restricted zones from home screen...');
      
      // Get restricted zones from geofencing service
      final restrictedZones = _geofencingService.restrictedZones;
      
      if (restrictedZones.isEmpty) {
        AppLogger.info('🛡️ No restricted zones loaded for checking from home');
        return;
      }
      
      AppLogger.info('🛡️ Checking ${restrictedZones.length} restricted zones for proximity from home');
      
      for (final zone in restrictedZones) {
        // Check if user is inside the restricted zone
        final isInside = _geofencingService.isPointInPolygon(currentLocation, zone.polygonCoordinates);
        
        if (isInside) {
          AppLogger.warning('🚨 ALERT: User is INSIDE restricted zone: ${zone.name}');
          await _triggerRestrictedZoneAlertFromHome(zone, 0.0, isInside: true);
          continue;
        }
        
        // Calculate distance to zone center for proximity alerts
        final zoneCenter = zone.center ?? _calculatePolygonCentroidHome(zone.polygonCoordinates);
        final distanceToZone = _calculateDistanceHome(
          currentLocation.latitude,
          currentLocation.longitude,
          zoneCenter.latitude,
          zoneCenter.longitude,
        );
        
        // Check if user is within critical proximity (100m)
        if (distanceToZone <= 0.1) {
          AppLogger.warning('⚠️ CRITICAL: User within ${(distanceToZone * 1000).toInt()}m of restricted zone: ${zone.name}');
          await _triggerRestrictedZoneAlertFromHome(zone, distanceToZone, isInside: false, isCritical: true);
        }
        // Check if user is within nearby proximity (500m)
        else if (distanceToZone <= 0.5) {
          AppLogger.info('⚠️ WARNING: User within ${(distanceToZone * 1000).toInt()}m of restricted zone: ${zone.name}');
          await _triggerRestrictedZoneAlertFromHome(zone, distanceToZone, isInside: false, isCritical: false);
        }
      }
      
    } catch (e) {
      AppLogger.error('Failed to check restricted zones from home: $e');
    }
  }

  /// Trigger restricted zone alert notification from home screen
  Future<void> _triggerRestrictedZoneAlertFromHome(RestrictedZone zone, double distanceKm, {required bool isInside, bool isCritical = false}) async {
    try {
      String alertTitle;
      String alertBody;
      
      if (isInside) {
        alertTitle = '🚨 DANGER - Inside Restricted Zone';
        alertBody = 'You are currently inside "${zone.name}". Please leave immediately for your safety!';
      } else if (isCritical) {
        alertTitle = '⚠️ CRITICAL - Restricted Zone Nearby';
        alertBody = 'DANGER: You are ${(distanceKm * 1000).toInt()}m from "${zone.name}". Do not proceed further!';
      } else {
        alertTitle = '⚠️ WARNING - Restricted Zone Nearby';
        alertBody = 'WARNING: You are ${(distanceKm * 1000).toInt()}m from "${zone.name}". Exercise caution.';
      }
      
      AppLogger.warning('🏠 Triggering restricted zone alert from home: $alertTitle - $alertBody');
      
      // Show notification using geofencing service
      await _geofencingService.showEmergencyZoneAlert(zone, distanceKm * 1000, isInside: isInside);
      
    } catch (e) {
      AppLogger.error('Failed to trigger restricted zone alert from home: $e');
    }
  }

  /// Calculate distance between two points in kilometers
  double _calculateDistanceHome(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    final double lat1Rad = lat1 * (math.pi / 180);
    final double lat2Rad = lat2 * (math.pi / 180);
    final double deltaLatRad = (lat2 - lat1) * (math.pi / 180);
    final double deltaLonRad = (lon2 - lon1) * (math.pi / 180);

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLonRad / 2) * math.sin(deltaLonRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Calculate polygon centroid for zones without center coordinates
  LatLng _calculatePolygonCentroidHome(List<LatLng> coordinates) {
    if (coordinates.isEmpty) return const LatLng(0, 0);
    
    double lat = 0.0, lng = 0.0;
    for (final point in coordinates) {
      lat += point.latitude;
      lng += point.longitude;
    }
    
    return LatLng(lat / coordinates.length, lng / coordinates.length);
  }

  Future<void> _handleSOSPress() async {
    // Navigate to countdown screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SOSCountdownScreen(tourist: widget.tourist),
      ),
    );
  }

  void _navigateToNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NotificationScreen(
          touristId: widget.tourist.id,
          initialAlerts: _alerts,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Must call super when using AutomaticKeepAliveClientMixin
    return Scaffold(
      body: _buildHomeTab(),
    );
  }

  Widget _buildHomeTab() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AppBar(
              leading: widget.onMenuTap != null
                  ? IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: widget.onMenuTap,
                      tooltip: 'Menu',
                    )
                  : null,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SafeHorizon',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Hi, ${widget.tourist.name.split(' ')[0]}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              actions: [
                Stack(
                  children: [
                    IconButton(
                      onPressed: _navigateToNotifications,
                      icon: const Icon(Icons.notifications_outlined),
                      tooltip: 'Notifications',
                    ),
                    if (_alerts.where((alert) => !alert.isAcknowledged).isNotEmpty)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  _loadSafetyScore(),
                  _loadAlerts(),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
            // Safety Score Widget
            if (_isLoadingSafetyScore)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_safetyScore != null)
              SafetyScoreWidget(
                safetyScore: _safetyScore!,
                onRefresh: _loadSafetyScore,
                isOfflineMode: _safetyScoreOfflineMode,
                isFromCache: false,
              ),

            const SizedBox(height: 16),

            _buildLocationCard(),
            
            const SizedBox(height: 16),

            // Emergency SOS Button
            _buildSosSection(),

            if (_alerts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildAlertsSection(),
            ],

            // Proximity Alerts Section (Panic Alerts & Restricted Zones)
            if (_proximityAlerts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildProximityAlertsSection(),
            ],

            const SizedBox(height: 16),

            _buildQuickActions(),

            const SizedBox(height: 20),
          ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF1E40AF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentLocationInfo != null 
                        ? (_currentLocationInfo!['address'] ?? 'Current Location')
                        : 'Current Location',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _locationStatus,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoadingLocation)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  onPressed: _getCurrentLocation,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  tooltip: 'Refresh location',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: const Color(0xFF64748B),
                ),
            ],
          ),
          if (_currentLocationInfo != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Coordinates
                  Row(
                    children: [
                      const Icon(
                        Icons.my_location,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentLocationInfo!['coordinates'] ?? 
                          '${_currentLocationInfo!['lat']?.toStringAsFixed(6) ?? '0.000000'}, ${_currentLocationInfo!['lng']?.toStringAsFixed(6) ?? '0.000000'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      // Copy coordinates button
                      InkWell(
                        onTap: () async {
                          // Copy coordinates to clipboard
                          final coords = _currentLocationInfo!['coordinates'] ?? 
                              '${_currentLocationInfo!['lat']}, ${_currentLocationInfo!['lng']}';
                          await Clipboard.setData(ClipboardData(text: coords));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                                    SizedBox(width: 12),
                                    Text('Coordinates copied to clipboard'),
                                  ],
                                ),
                                backgroundColor: Color(0xFF10B981),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.copy,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Accuracy indicator
                  if (_currentLocationInfo!['accuracy'] != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.gps_fixed,
                          size: 12,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Accuracy: ${_currentLocationInfo!['accuracy']}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.dashboard_outlined,
                size: 20,
                color: Color(0xFF0EA5E9),
              ),
              const SizedBox(width: 8),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Grid layout with proper titles
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.shield_outlined,
                      title: 'Safety Tips',
                      subtitle: 'Travel guidelines',
                      color: const Color(0xFF22C55E),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SafetyTipsScreen(tourist: widget.tourist),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.description_outlined,
                      title: 'E-FIR',
                      subtitle: 'File complaint',
                      color: const Color(0xFF3B82F6),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => EFIRFormScreen(tourist: widget.tourist)),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.local_hospital_outlined,
                      title: 'Services',
                      subtitle: 'Emergency help',
                      color: const Color(0xFFEF4444),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => TouristServicesScreen(tourist: widget.tourist)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.warning_outlined,
                      title: 'Danger Zones',
                      subtitle: 'Risk areas',
                      color: const Color(0xFFF59E0B),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DangerZonesScreen(tourist: widget.tourist),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Trip Monitor - Full width as it's the main feature
              _buildActionCard(
                icon: Icons.monitor_heart_outlined,
                title: 'Trip Monitor',
                subtitle: 'Auto location tracking every 20s',
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TripMonitorScreen(),
                    ),
                  );
                },
                isFullWidth: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: isFullWidth 
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: color,
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAlertsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  size: 16,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Alerts',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              if (_isLoadingAlerts)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const Spacer(),
              if (_alerts.length > 3)
                TextButton(
                  onPressed: _showAllAlertsDialog,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View all (${_alerts.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ..._alerts.take(3).map((alert) => _buildAlertItem(alert)),
        ],
      ),
    );
  }

  Widget _buildProximityAlertsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF9800)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9800).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.emergency,
                  size: 16,
                  color: Color(0xFFFF9800),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Nearby Alerts',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_proximityAlerts.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9E6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Color(0xFFFF9800),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Emergency situations or restricted zones detected near your location',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Display proximity alerts
          ..._proximityAlerts.take(3).map((alert) => 
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ProximityAlertWidget(
                alert: alert,
                onTap: () => _showProximityAlertDialog(alert),
                onDismiss: () {
                  setState(() {
                    _proximityAlerts.remove(alert);
                  });
                },
              ),
            ),
          ),
          // View on map button
          if (_proximityAlerts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to map screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapScreen(tourist: widget.tourist),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('View All on Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          // Show "View all" button if more than 3 alerts
          if (_proximityAlerts.length > 3)
            Center(
              child: TextButton(
                onPressed: _showAllProximityAlertsDialog,
                child: Text(
                  'View all ${_proximityAlerts.length} alerts',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF9800),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAllProximityAlertsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Nearby Alerts'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _proximityAlerts.length,
            itemBuilder: (context, index) {
              final alert = _proximityAlerts[index];
              return ProximityAlertWidget(
                alert: alert,
                onTap: () {
                  Navigator.pop(context);
                  _showProximityAlertDialog(alert);
                },
                onDismiss: () {
                  setState(() {
                    _proximityAlerts.removeAt(index);
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(Alert alert) {
    final color = _getAlertColor(alert.severity);
    final isUnread = !alert.isAcknowledged;
    final isUnresolved = !alert.isResolved;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnresolved 
            ? color.withValues(alpha: 0.08) 
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUnresolved 
              ? color.withValues(alpha: 0.3) 
              : const Color(0xFFE2E8F0),
          width: isUnresolved ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getAlertIcon(alert.type),
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isUnresolved)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatTime(alert.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alert.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                if (isUnresolved && alert.latitude != null && alert.longitude != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Nearby incident - exercise caution',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Removed legacy _buildQuickActionButton after redesign.

  Widget _buildAlertTile(Alert alert) {
    return ListTile(
      leading: Icon(
        _getAlertIcon(alert.type),
        color: _getAlertColor(alert.severity),
      ),
      title: Text(
        alert.title,
        style: TextStyle(
          fontWeight: alert.isAcknowledged ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(
        alert.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatTime(alert.createdAt),
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      onTap: () {
        // Mark as read and show alert details
        _showAlertDialog(alert);
      },
    );
  }

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.sos:
        return Icons.emergency;
      case AlertType.geofence:
        return Icons.location_on;
      case AlertType.safety:
        return Icons.security;
      case AlertType.emergency:
        return Icons.warning;
      case AlertType.anomaly:
        return Icons.warning_amber;
      case AlertType.sequence:
        return Icons.timeline;
      case AlertType.general:
        return Icons.info;
    }
  }

  Color _getAlertColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return Colors.red;
      case AlertSeverity.high:
        return Colors.orange;
      case AlertSeverity.medium:
        return Colors.yellow;
      default:
        return Colors.blue;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  void _showAlertDialog(Alert alert) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _getAlertIcon(alert.type),
                color: _getAlertColor(alert.severity),
              ),
              const SizedBox(width: 8),
              Text(alert.title),
            ],
          ),
          content: Text(alert.description),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showAllAlertsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 400),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'All Alerts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _alerts.length,
                    itemBuilder: (context, index) {
                      return _buildAlertTile(_alerts[index]);
                    },
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSosSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleSOSPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.emergency_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EMERGENCY SOS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to trigger emergency alert',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }












}
