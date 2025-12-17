import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/tourist.dart';
import '../models/geospatial_heat.dart';
import '../models/alert.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/proximity_alert_service.dart';
import '../services/geofencing_service.dart';
import '../utils/logger.dart';
import '../widgets/panic_alert_pulse_layer.dart';
import '../widgets/heatmap_layer.dart';
import '../widgets/alert_marker.dart';
import '../theme/app_theme.dart';

/// Professional, modern map screen with advanced UI/UX
/// Features: Real-time tracking, heatmap, search, safety zones, alerts
class MapScreen extends StatefulWidget {
  final Tourist tourist;

  const MapScreen({
    super.key,
    required this.tourist,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  // Controllers
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final ProximityAlertService _proximityAlertService = ProximityAlertService.instance;
  final GeofencingService _geofencingService = GeofencingService.instance;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _pulseController;
  late AnimationController _slideController;
  
  // Core state
  LatLng? _currentLocation;
  bool _isLoading = true;
  bool _isTrackingUser = true;
  double _currentZoom = 13.0;
  bool _isMapReady = false; // Track map readiness
  
  // Heatmap & zones
  List<GeospatialHeatPoint> _heatmapData = [];
  List<RestrictedZone> _restrictedZones = [];
  bool _showHeatmap = true;
  bool _showRestrictedZones = true;
  double _heatmapRadiusKm = 5.0; // Adjustable heatmap radius
  double _heatmapOpacity = 0.7; // Adjustable opacity
  
  // Search
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  LatLng? _searchedLocation;
  Timer? _searchDebounce;
  
  // Safety & alerts
  int? _locationSafetyScore;
  String? _locationRiskLevel;
  List<GeospatialHeatPoint> _recentPanicAlerts = [];
  List<Alert> _nearbyUnresolvedAlerts = [];
  Alert? _selectedAlert;
  Timer? _alertRefreshTimer;
  
  // UI state

  bool _showSafetyPanel = false;
  
  // Subscriptions
  StreamSubscription<ProximityAlertEvent>? _proximitySubscription;
  StreamSubscription<GeofenceEvent>? _geofenceSubscription;
  Timer? _panicMonitorTimer;

  @override
  void initState() {
    super.initState();
    
    // Add lifecycle observer for battery optimization
    WidgetsBinding.instance.addObserver(this);
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    _initializeMap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App is active - ensure real-time location updates are enabled
        _locationService.enableRealtimeMode();
        AppLogger.info('🗺️ App resumed - real-time location active');
        
        // Refresh alerts when app becomes active to get latest data
        if (_currentLocation != null) {
          _loadNearbyUnresolvedAlerts(forceRefresh: true);
          AppLogger.info('🚨 App resumed - refreshing alerts for latest data');
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Keep real-time mode active for seamless location tracking
        AppLogger.info('�️ App backgrounded - maintaining real-time location for continuous tracking');
        break;
    }
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Disable real-time mode when disposing
    _locationService.disableRealtimeMode();
    
    // Animation controllers
    _pulseController.dispose();
    _slideController.dispose();
    
    // Text and focus controllers
    _searchController.dispose();
    _searchFocusNode.dispose();
    
    // Timers - cancel and clear references
    _searchDebounce?.cancel();
    _searchDebounce = null;
    _panicMonitorTimer?.cancel();
    _panicMonitorTimer = null;
    _alertRefreshTimer?.cancel();
    _alertRefreshTimer = null;
    
    // Stream subscriptions - cancel and clear references
    _proximitySubscription?.cancel();
    _proximitySubscription = null;
    _geofenceSubscription?.cancel();
    _geofenceSubscription = null;
    
    // Clear data collections to prevent memory leaks
    _heatmapData.clear();
    _restrictedZones.clear();
    _searchResults.clear();
    _recentPanicAlerts.clear();
    
    AppLogger.info('🧹 MapScreen resources disposed properly');
    super.dispose();
  }

  Future<void> _initializeMap() async {
    setState(() => _isLoading = true);
    
    try {
      // First get location and load basic map data
      await Future.wait([
        _getCurrentLocation(),
        _loadHeatmapData(),
        _loadRestrictedZones(),
      ]);
      
      // Then load location-dependent data after location is available
      await _loadNearbyUnresolvedAlerts();
      
      _listenToLocationUpdates();
      _listenToProximityAlerts();
      _listenToGeofenceEvents();
      _startPanicMonitoring();
      _startAlertRefreshTimer();
      
      // Enable real-time location updates for map display
      await _locationService.enableRealtimeMode();
      
      await _checkNearbyPanicAlerts();
    } catch (e) {
      AppLogger.error('Map initialization failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================================
  // LOCATION MANAGEMENT
  // ============================================================================
  
  Future<void> _getCurrentLocation() async {
    try {
      AppLogger.info('🗺️ Getting current location...');
      final position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        AppLogger.info('🗺️ Current location obtained: $_currentLocation');
        
        // Only move map if it's ready to avoid MapController errors
        if (_isMapReady) {
          _safeMapMove(_currentLocation!, _currentZoom);
        }
      } else {
        AppLogger.warning('🗺️ Unable to get current location');
      }
    } catch (e) {
      AppLogger.error('Failed to get location: $e');
      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location access failed: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _getCurrentLocation,
            ),
          ),
        );
      }
    }
  }

  void _listenToLocationUpdates() {
    // Listen to regular location stream for general updates
    _locationService.locationStream.listen((locationData) {
      if (!mounted) return;
      
      final previousLocation = _currentLocation;
      setState(() {
        _currentLocation = locationData.latLng;
      });
      
      // Auto-follow user if tracking enabled and map is ready
      if (_isTrackingUser && _isMapReady) {
        _safeMapMove(_currentLocation!, _currentZoom);
      }
      
      // Refresh nearby alerts when location changes significantly (>500m for real-time updates)
      if (previousLocation == null || 
          _calculateDistance(
            previousLocation.latitude, 
            previousLocation.longitude, 
            _currentLocation!.latitude, 
            _currentLocation!.longitude
          ) > 0.5) {
        _loadNearbyUnresolvedAlerts();
        AppLogger.info('🚨 Location changed - refreshing nearby alerts for real-time updates');
      }
    });
    
    // Listen to real-time location stream for high-frequency map updates
    _locationService.realtimeLocationStream.listen((locationData) {
      if (!mounted) return;
      
      final previousLocation = _currentLocation;
      setState(() {
        _currentLocation = locationData.latLng;
      });
      
      // Always update map immediately for real-time tracking
      if (_isMapReady && _isTrackingUser) {
        _safeMapMove(_currentLocation!, _currentZoom);
        AppLogger.info('🗺️ Real-time location: ${locationData.latLng.toString()}');
      }
      
      // Refresh alerts more frequently for real-time updates (every 200m)
      if (previousLocation == null || 
          _calculateDistance(
            previousLocation.latitude, 
            previousLocation.longitude, 
            _currentLocation!.latitude, 
            _currentLocation!.longitude
          ) > 0.2) {
        _loadNearbyUnresolvedAlerts();
        AppLogger.info('🚨 Real-time location change - updating nearby alerts');
      }
    });
  }

  /// Safe map movement that handles controller readiness
  void _safeMapMove(LatLng location, double zoom) {
    try {
      if (_isMapReady && mounted) {
        _mapController.move(location, zoom);
      }
    } catch (e) {
      AppLogger.warning('Map move failed: $e');
      // Retry after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_isMapReady && mounted) {
          try {
            _mapController.move(location, zoom);
          } catch (e) {
            AppLogger.error('Map move retry failed: $e');
          }
        }
      });
    }
  }

  void _centerOnUser() async {
    try {
      // Check permissions first
      final hasPermissions = await _locationService.checkAndRequestPermissions();
      if (!hasPermissions) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are required to show your current location.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // If we don't have current location, try to get it
      if (_currentLocation == null) {
        await _getCurrentLocation();
      }
      
      // If we still don't have location, show a message
      if (_currentLocation == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get your current location. Please check location permissions.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // Center map on user location
      _safeMapMove(_currentLocation!, 16.0);
      setState(() {
        _isTrackingUser = true;
        _currentZoom = 16.0;
      });
      
      AppLogger.info('🗺️ Centered map on user location: $_currentLocation');
    } catch (e) {
      AppLogger.error('Failed to center on user location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get your location. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ============================================================================
  // DATA LOADING
  // ============================================================================
  
  Future<void> _loadHeatmapData() async {
    try {
      // Load panic data and zones in parallel, with individual error handling
      final List<Future> futures = [
        _apiService.getPanicAlertHeatData(
          daysPast: 30,
          excludeTouristId: widget.tourist.id,
        ).catchError((e) {
          AppLogger.info('Panic alert data unavailable (tourist role) - continuing without alert heatmap');
          return <GeospatialHeatPoint>[];
        }),
        _apiService.getRestrictedZones().catchError((e) {
          AppLogger.warning('Failed to load restricted zones: $e');
          return <RestrictedZone>[];
        }),
      ];
      
      final results = await Future.wait(futures);
      final panicData = results[0] as List<GeospatialHeatPoint>;
      final zones = results[1] as List<RestrictedZone>;
      
      final zoneHeatData = zones.map((zone) {
        try {
          if (zone.polygonCoordinates.isEmpty) return null;
          
          final avgLat = zone.polygonCoordinates
              .map((p) => p.latitude)
              .reduce((a, b) => a + b) / zone.polygonCoordinates.length;
          final avgLng = zone.polygonCoordinates
              .map((p) => p.longitude)
              .reduce((a, b) => a + b) / zone.polygonCoordinates.length;
          
          return GeospatialHeatPoint.fromRestrictedZone(
            latitude: avgLat,
            longitude: avgLng,
            intensity: _getZoneIntensity(zone.type),
            description: zone.name,
          );
        } catch (e) {
          AppLogger.warning('Failed to process zone ${zone.name}: $e');
          return null;
        }
      }).whereType<GeospatialHeatPoint>().toList();

      if (mounted) {
        setState(() {
          _heatmapData = [...panicData, ...zoneHeatData];
        });
      }
      
      AppLogger.info('🗺️ Loaded ${_heatmapData.length} heat points (${panicData.length} alerts, ${zoneHeatData.length} zones)');
    } catch (e) {
      AppLogger.error('Failed to load heatmap data: $e');
      // Continue with empty heatmap rather than failing completely
      if (mounted) {
        setState(() {
          _heatmapData = [];
        });
      }
    }
  }

  Future<void> _loadRestrictedZones() async {
    try {
      await _geofencingService.initialize();
      setState(() {
        _restrictedZones = _geofencingService.restrictedZones;
      });
      AppLogger.info('🚧 Loaded ${_restrictedZones.length} restricted zones');
    } catch (e) {
      AppLogger.error('Failed to load zones: $e');
    }
  }

  /// Load nearby unresolved alerts for persistent display
  Future<void> _loadNearbyUnresolvedAlerts({bool forceRefresh = false}) async {
    if (_currentLocation == null) {
      AppLogger.warning('🚨 Cannot load alerts - current location is null');
      return;
    }
    
    AppLogger.info('🚨 Loading nearby alerts for location: ${_currentLocation!.latitude}, ${_currentLocation!.longitude} (force: $forceRefresh)');
    
    try {
      final alerts = await _apiService.getNearbyUnresolvedAlerts(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        radiusKm: 15.0, // Increased radius for better visibility
      );
      
      if (mounted) {
        setState(() {
          _nearbyUnresolvedAlerts = alerts;
        });
        
        AppLogger.info('🚨 Successfully loaded ${alerts.length} nearby unresolved alerts');
        
        // Debug: Print details of loaded alerts
        for (int i = 0; i < alerts.length && i < 5; i++) {
          final alert = alerts[i];
          AppLogger.info('🚨 Alert ${i + 1}: ${alert.title} at ${alert.latitude}, ${alert.longitude} (${alert.type.name})');
        }
        
        // Log if no alerts found
        if (alerts.isEmpty) {
          AppLogger.info('🚨 No unresolved alerts found in 15km radius');
        }
      }

      // ENHANCED: Also check for restricted zones when searching for nearby alerts
      await _checkNearbyRestrictedZones();
      
    } catch (e) {
      AppLogger.error('Failed to load nearby alerts: $e');
    }
  }

  /// Check for nearby restricted zones and trigger alerts if user is close to or inside them
  Future<void> _checkNearbyRestrictedZones() async {
    if (_currentLocation == null) return;
    
    try {
      AppLogger.info('🛡️ Checking nearby restricted zones...');
      
      // Get restricted zones from geofencing service
      final restrictedZones = _geofencingService.restrictedZones;
      
      if (restrictedZones.isEmpty) {
        AppLogger.info('🛡️ No restricted zones loaded for checking');
        return;
      }
      
      AppLogger.info('🛡️ Checking ${restrictedZones.length} restricted zones for proximity');
      
      for (final zone in restrictedZones) {
        // Check if user is inside the restricted zone
        final isInside = _geofencingService.isPointInPolygon(_currentLocation!, zone.polygonCoordinates);
        
        if (isInside) {
          AppLogger.warning('🚨 ALERT: User is INSIDE restricted zone: ${zone.name}');
          await _triggerRestrictedZoneAlert(zone, 0.0, isInside: true);
          continue;
        }
        
        // Calculate distance to zone center for proximity alerts
        final zoneCenter = zone.center ?? _calculatePolygonCentroid(zone.polygonCoordinates);
        final distanceToZone = _calculateDistance(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          zoneCenter.latitude,
          zoneCenter.longitude,
        );
        
        // Check if user is within critical proximity (100m)
        if (distanceToZone <= 0.1) {
          AppLogger.warning('⚠️ CRITICAL: User within ${(distanceToZone * 1000).toInt()}m of restricted zone: ${zone.name}');
          await _triggerRestrictedZoneAlert(zone, distanceToZone, isInside: false, isCritical: true);
        }
        // Check if user is within nearby proximity (500m)
        else if (distanceToZone <= 0.5) {
          AppLogger.info('⚠️ WARNING: User within ${(distanceToZone * 1000).toInt()}m of restricted zone: ${zone.name}');
          await _triggerRestrictedZoneAlert(zone, distanceToZone, isInside: false, isCritical: false);
        }
      }
      
    } catch (e) {
      AppLogger.error('Failed to check restricted zones: $e');
    }
  }

  /// Trigger restricted zone alert notification
  Future<void> _triggerRestrictedZoneAlert(RestrictedZone zone, double distanceKm, {required bool isInside, bool isCritical = false}) async {
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
      
      AppLogger.warning('🚨 Triggering restricted zone alert: $alertTitle - $alertBody');
      
      // Show phone notification using geofencing service
      await _geofencingService.showEmergencyZoneAlert(zone, distanceKm * 1000, isInside: isInside);
      
    } catch (e) {
      AppLogger.error('Failed to trigger restricted zone alert: $e');
    }
  }



  /// Calculate polygon centroid for zones without center coordinates
  LatLng _calculatePolygonCentroid(List<LatLng> coordinates) {
    if (coordinates.isEmpty) return const LatLng(0, 0);
    
    double lat = 0.0, lng = 0.0;
    for (final point in coordinates) {
      lat += point.latitude;
      lng += point.longitude;
    }
    
    return LatLng(lat / coordinates.length, lng / coordinates.length);
  }

  /// Manually refresh alerts (for pull-to-refresh functionality)
  Future<void> _refreshAlerts() async {
    await _loadNearbyUnresolvedAlerts(forceRefresh: true);
  }

  /// Start timer to refresh unresolved alerts periodically (real-time updates)
  void _startAlertRefreshTimer() {
    _alertRefreshTimer?.cancel();
    _alertRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _currentLocation != null) {
        _loadNearbyUnresolvedAlerts();
      }
    });
  }

  /// Handle alert marker tap
  void _onAlertTap(Alert alert) {
    setState(() {
      _selectedAlert = alert;
    });
    
    // Center map on alert location if coordinates are available
    if (alert.latitude != null && alert.longitude != null) {
      _safeMapMove(LatLng(alert.latitude!, alert.longitude!), 16.0);
    }
    
    AppLogger.info('🚨 Alert selected: ${alert.title}');
  }

  /// Close alert popup
  void _closeAlertPopup() {
    setState(() {
      _selectedAlert = null;
    });
  }

  /// Build markers for unresolved alerts with debug logging
  List<Marker> _buildUnresolvedAlertMarkers() {
    final validAlerts = _nearbyUnresolvedAlerts
        .where((alert) => alert.latitude != null && alert.longitude != null)
        .toList();
    
    AppLogger.info('🗺️ Building ${validAlerts.length} alert markers from ${_nearbyUnresolvedAlerts.length} total alerts');
    
    return validAlerts.map((alert) {
      AppLogger.info('🚨 Creating marker for alert: ${alert.title} at ${alert.latitude}, ${alert.longitude}');
      return AlertMarkerBuilder.buildSingleAlertMarker(
        alert,
        onTap: () => _onAlertTap(alert),
      );
    }).toList();
  }

  double _getZoneIntensity(dynamic type) {
    final typeStr = type.toString().toLowerCase();
    if (typeStr.contains('danger')) return 0.9;
    if (typeStr.contains('high') || typeStr.contains('risk')) return 0.85;
    if (typeStr.contains('restrict')) return 0.7;
    if (typeStr.contains('caution')) return 0.5;
    return 0.3;
  }

  // ============================================================================
  // SEARCH FUNCTIONALITY
  // ============================================================================
  
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);

    try {
      final results = await _apiService.searchLocation(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      AppLogger.error('Search failed: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _selectSearchResult(Map<String, dynamic> result) async {
    final lat = result['lat'] as double;
    final lon = result['lon'] as double;
    final name = result['display_name'] as String;

    setState(() {
      _searchedLocation = LatLng(lat, lon);
      _searchResults = [];
      _searchController.clear();
      _searchFocusNode.unfocus();
      _isTrackingUser = false;
    });

    _safeMapMove(_searchedLocation!, 15.0);
    await _calculateSafetyScore(lat, lon);
    
    _showSnackBar('📍 $name', isSuccess: true);
  }

  // ============================================================================
  // SAFETY SCORE CALCULATION
  // ============================================================================
  
  Future<void> _calculateSafetyScore(double lat, double lon) async {
    try {
      int score = 100;
      
      for (final point in _heatmapData) {
        final distance = _calculateDistance(lat, lon, point.latitude, point.longitude);
        
        if (distance < 0.5 && point.intensity > 0.8) {
          score = (score - 40).clamp(0, 100);
        } else if (distance < 1.0 && point.intensity > 0.6) {
          score = (score - 20).clamp(0, 100);
        } else if (distance < 2.0 && point.intensity > 0.4) {
          score = (score - 10).clamp(0, 100);
        }
      }

      String riskLevel = score >= 80 ? 'Safe' 
          : score >= 60 ? 'Moderate'
          : score >= 40 ? 'Risky'
          : 'Dangerous';

      if (mounted) {
        setState(() {
          _locationSafetyScore = score;
          _locationRiskLevel = riskLevel;
          _showSafetyPanel = true;
        });
      }
    } catch (e) {
      AppLogger.error('Safety score calculation failed: $e');
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    return R * 2 * math.asin(math.sqrt(a));
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  // ============================================================================
  // ALERT MONITORING
  // ============================================================================
  
  void _listenToProximityAlerts() {
    _proximitySubscription = _proximityAlertService.events.listen((event) {
      if (!mounted) return;
      
      _checkNearbyPanicAlerts();
      _showAlertNotification(event.title, event.distanceKm);
    });
  }

  void _listenToGeofenceEvents() {
    _geofenceSubscription = _geofencingService.events.listen((event) {
      if (!mounted) return;
      
      if (event.eventType == GeofenceEventType.enter) {
        // Only log entry - notification is handled by GeofencingService
        AppLogger.info('Geofence alert: Entered ${event.zone.name} - notification sent');
      }
    });
  }

  void _startPanicMonitoring() {
    _panicMonitorTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkNearbyPanicAlerts();
    });
  }

  Future<void> _checkNearbyPanicAlerts() async {
    if (_currentLocation == null) return;

    try {
      // Pass the current tourist ID to exclude their own alerts
      final alerts = await _apiService.getPublicPanicAlerts(
        excludeTouristId: widget.tourist.id,
      );
      
      final nearbyAlerts = alerts.where((alert) {
        // Double-check: Filter out self-created alerts (in case backend doesn't support exclude parameter)
        final alertTouristId = alert['tourist_id'] ?? alert['user_id'];
        if (alertTouristId != null && alertTouristId.toString() == widget.tourist.id) {
          AppLogger.info('🚫 Filtered out self-created panic alert (client-side)');
          return false;
        }
        
        // Check distance - only show alerts within 20km
        // Safely extract latitude and longitude with null checks (support nested location object)
        double? lat;
        double? lng;
        
        // Try direct fields first
        if (alert['latitude'] != null) {
          lat = alert['latitude'] is num ? alert['latitude'].toDouble() : double.tryParse(alert['latitude'].toString());
        } else if (alert['lat'] != null) {
          lat = alert['lat'] is num ? alert['lat'].toDouble() : double.tryParse(alert['lat'].toString());
        }
        
        if (alert['longitude'] != null) {
          lng = alert['longitude'] is num ? alert['longitude'].toDouble() : double.tryParse(alert['longitude'].toString());
        } else if (alert['lon'] != null) {
          lng = alert['lon'] is num ? alert['lon'].toDouble() : double.tryParse(alert['lon'].toString());
        } else if (alert['lng'] != null) {
          lng = alert['lng'] is num ? alert['lng'].toDouble() : double.tryParse(alert['lng'].toString());
        }
        
        // Try nested location object if direct fields not found
        if ((lat == null || lng == null) && alert['location'] is Map<String, dynamic>) {
          final location = alert['location'] as Map<String, dynamic>;
          if (lat == null) {
            if (location['lat'] != null) {
              lat = location['lat'] is num ? location['lat'].toDouble() : double.tryParse(location['lat'].toString());
            } else if (location['latitude'] != null) {
              lat = location['latitude'] is num ? location['latitude'].toDouble() : double.tryParse(location['latitude'].toString());
            }
          }
          if (lng == null) {
            if (location['lon'] != null) {
              lng = location['lon'] is num ? location['lon'].toDouble() : double.tryParse(location['lon'].toString());
            } else if (location['lng'] != null) {
              lng = location['lng'] is num ? location['lng'].toDouble() : double.tryParse(location['lng'].toString());
            } else if (location['longitude'] != null) {
              lng = location['longitude'] is num ? location['longitude'].toDouble() : double.tryParse(location['longitude'].toString());
            }
          }
        }
        
        if (lat == null || lng == null) {
          AppLogger.warning('Alert missing coordinates after all attempts: $alert');
          return false;
        }
        
        AppLogger.info('🗺️ Found coordinates: lat=$lat, lng=$lng for alert ${alert['alert_id']}');
        
        try {
          final distance = _calculateDistance(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
            lat,
            lng,
          );
          return distance <= 20.0;
        } catch (e) {
          AppLogger.warning('Invalid coordinates in alert: lat=$lat, lng=$lng, error=$e');
          return false;
        }
      }).map((alert) {
        try {
          // Extract coordinates using the same logic as above
          double? lat;
          double? lng;
          
          // Try direct fields first
          if (alert['latitude'] != null) {
            lat = alert['latitude'] is num ? alert['latitude'].toDouble() : double.tryParse(alert['latitude'].toString());
          } else if (alert['lat'] != null) {
            lat = alert['lat'] is num ? alert['lat'].toDouble() : double.tryParse(alert['lat'].toString());
          }
          
          if (alert['longitude'] != null) {
            lng = alert['longitude'] is num ? alert['longitude'].toDouble() : double.tryParse(alert['longitude'].toString());
          } else if (alert['lon'] != null) {
            lng = alert['lon'] is num ? alert['lon'].toDouble() : double.tryParse(alert['lon'].toString());
          } else if (alert['lng'] != null) {
            lng = alert['lng'] is num ? alert['lng'].toDouble() : double.tryParse(alert['lng'].toString());
          }
          
          // Try nested location object if direct fields not found
          if ((lat == null || lng == null) && alert['location'] is Map<String, dynamic>) {
            final location = alert['location'] as Map<String, dynamic>;
            if (lat == null) {
              if (location['lat'] != null) {
                lat = location['lat'] is num ? location['lat'].toDouble() : double.tryParse(location['lat'].toString());
              } else if (location['latitude'] != null) {
                lat = location['latitude'] is num ? location['latitude'].toDouble() : double.tryParse(location['latitude'].toString());
              }
            }
            if (lng == null) {
              if (location['lon'] != null) {
                lng = location['lon'] is num ? location['lon'].toDouble() : double.tryParse(location['lon'].toString());
              } else if (location['lng'] != null) {
                lng = location['lng'] is num ? location['lng'].toDouble() : double.tryParse(location['lng'].toString());
              } else if (location['longitude'] != null) {
                lng = location['longitude'] is num ? location['longitude'].toDouble() : double.tryParse(location['longitude'].toString());
              }
            }
          }
          
          if (lat == null || lng == null) {
            AppLogger.warning('Cannot create GeospatialHeatPoint - missing coordinates: $alert');
            return null;
          }
          
          return GeospatialHeatPoint.fromPanicAlert(
            latitude: lat,
            longitude: lng,
            timestamp: DateTime.parse(alert['timestamp'] ?? DateTime.now().toIso8601String()),
            intensity: 0.9,
            description: 'Emergency Alert',
          );
        } catch (e) {
          AppLogger.warning('Failed to create GeospatialHeatPoint from alert: $alert, error: $e');
          return null;
        }
      }).whereType<GeospatialHeatPoint>().toList();

      if (mounted) {
        setState(() {
          _recentPanicAlerts = nearbyAlerts;
        });
      }
    } catch (e) {
      AppLogger.error('Panic alert check failed: $e');
    }
  }

  // ============================================================================
  // UI HELPERS
  // ============================================================================
  
  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AppColors.success : AppColors.info,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showAlertNotification(String title, double distance) {
    _showSnackBar('⚠️ $title - ${distance.toStringAsFixed(1)}km away');
  }



  void _showHeatmapSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.tune_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  'Heatmap Settings',
                  style: AppTypography.headingMedium,
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Radius slider
            Text(
              'Influence Radius',
              style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${_heatmapRadiusKm.toStringAsFixed(1)}km', 
                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Slider(
                    value: _heatmapRadiusKm,
                    min: 2.0,
                    max: 10.0,
                    divisions: 16,
                    activeColor: AppColors.primary,
                    label: '${_heatmapRadiusKm.toStringAsFixed(1)}km',
                    onChanged: (value) {
                      setState(() {
                        _heatmapRadiusKm = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Opacity slider
            Text(
              'Opacity',
              style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${(_heatmapOpacity * 100).toStringAsFixed(0)}%', 
                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Slider(
                    value: _heatmapOpacity,
                    min: 0.3,
                    max: 1.0,
                    divisions: 14,
                    activeColor: AppColors.primary,
                    label: '${(_heatmapOpacity * 100).toStringAsFixed(0)}%',
                    onChanged: (value) {
                      setState(() {
                        _heatmapOpacity = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Info text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Adjust the heatmap visualization to see risk areas more clearly',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // UI BUILD METHODS
  // ============================================================================
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // Background map skeleton
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.surfaceVariant,
                    AppColors.surface,
                    AppColors.surfaceVariant,
                  ],
                ),
              ),
            ),
            
            // Animated loading overlay
            AnimatedBuilder(
              animation: _slideController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1.0 + (_slideController.value * 2), 0.0),
                      end: Alignment(1.0 + (_slideController.value * 2), 0.0),
                      colors: [
                        Colors.transparent,
                        AppColors.shimmer.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // Loading content with skeleton
            Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow.withValues(alpha: 0.1),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated loading indicator
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Text(
                      'Loading Map',
                      style: AppTypography.headingMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Text(
                      'Preparing your safety dashboard...',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    // Loading steps skeleton
                    _buildLoadingStep('Fetching location', true),
                    _buildLoadingStep('Loading safety data', _currentLocation != null),
                    _buildLoadingStep('Initializing map', _heatmapData.isNotEmpty),
                  ],
                ),
              ),
            ),
            
            // Search bar skeleton
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(
                        Icons.search_rounded,
                        color: AppColors.textTertiary,
                        size: 20,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 16,
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: AppColors.shimmer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Map with pull-to-refresh for real-time alerts
          RefreshIndicator(
            onRefresh: _refreshAlerts,
            child: GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onTap: () {
                // Hide search results when tapping on map
                if (_searchResults.isNotEmpty) {
                  setState(() {
                    _searchResults.clear();
                  });
                }
                // Unfocus search field
                _searchFocusNode.unfocus();
              },
              child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation ?? const LatLng(28.6139, 77.2090),
                initialZoom: _currentZoom,
                minZoom: 3,
                maxZoom: 18,
                onMapReady: () {
                  setState(() {
                    _isMapReady = true;
                  });
                  AppLogger.info('🗺️ Map is now ready');
                  
                  // Move to current location if available
                  if (_currentLocation != null) {
                    _safeMapMove(_currentLocation!, _currentZoom);
                  }
                },
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    setState(() {
                      _isTrackingUser = false;
                      _currentZoom = position.zoom;
                    });
                  }
                },
              ),
              children: [
                // Tile layer
                TileLayer(
                  urlTemplate: _getMapTileUrl(),
                  userAgentPackageName: 'com.safehorizon.app',
                ),
                
                // Professional gradient heatmap
                if (_showHeatmap && _heatmapData.isNotEmpty)
                  HeatmapLayer(
                    heatPoints: _heatmapData,
                    radiusKm: _heatmapRadiusKm,
                    opacity: _heatmapOpacity,
                    visible: _showHeatmap,
                  ),
                
                // Restricted zone polygons
                if (_showRestrictedZones)
                  PolygonLayer(
                    polygons: _restrictedZones.map((zone) {
                      final color = _getZoneColor(zone.type).withValues(alpha: 0.2);
                      final borderColor = _getZoneColor(zone.type);
                      
                      return Polygon(
                        points: zone.polygonCoordinates,
                        color: color,
                        borderColor: borderColor,
                        borderStrokeWidth: 2.5,
                      );
                    }).toList(),
                  ),
                
                // Panic alert pulses
                if (_recentPanicAlerts.isNotEmpty)
                  StreamBuilder<MapEvent>(
                    stream: _mapController.mapEventStream,
                    builder: (context, snapshot) {
                      return PanicAlertPulseLayer(
                        panicAlerts: _recentPanicAlerts,
                        camera: _mapController.camera,
                      );
                    },
                  ),
                
                // Markers
                MarkerLayer(
                  markers: [
                    // User location
                    if (_currentLocation != null)
                      Marker(
                        point: _currentLocation!,
                        width: 100,
                        height: 100,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return _buildUserLocationMarker();
                          },
                        ),
                      ),
                    
                    // Unresolved alert markers (persistent until resolved)
                    ..._buildUnresolvedAlertMarkers(),
                    
                    // Panic alert markers
                    ..._recentPanicAlerts.map((alert) {
                      final distance = _currentLocation != null
                          ? _calculateDistance(
                              _currentLocation!.latitude,
                              _currentLocation!.longitude,
                              alert.latitude,
                              alert.longitude,
                            )
                          : 0.0;
                      
                      return Marker(
                        point: LatLng(alert.latitude, alert.longitude),
                        width: 80,
                        height: 100,
                        child: GestureDetector(
                          onTap: () {
                            // Show alert details in snackbar
                            _showSnackBar(
                              '🚨 Emergency Alert - ${distance.toStringAsFixed(1)}km away',
                            );
                          },
                          child: Column(
                            children: [
                              // Distance badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${distance.toStringAsFixed(1)}km',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Alert icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.error.withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.emergency_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    
                    // Searched location marker
                    if (_searchedLocation != null)
                      Marker(
                        point: _searchedLocation!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.place,
                          color: AppColors.success,
                          size: 40,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          ), // End of RefreshIndicator
          
          // Top UI
          _buildTopBar(),
          
          // Search results
          if (_searchResults.isNotEmpty) _buildSearchResults(),
          
          // Safety panel
          if (_showSafetyPanel) _buildSafetyPanel(),
          
          // Map controls (right side, comfortable position)
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 140,
            child: _buildMapControls(),
          ),
          
          // Alert detail popup
          if (_selectedAlert != null)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: AlertDetailPopup(
                alert: _selectedAlert!,
                onClose: _closeAlertPopup,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.background.withValues(alpha: 0.95),
              Colors.transparent,
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        child: Column(
          children: [
            // Modern search bar
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                    spreadRadius: 0,
                  ),
                ],
                border: Border.all(
                  color: _searchFocusNode.hasFocus 
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.border,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Search field
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: _onSearchChanged,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search locations...',
                        hintStyle: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchFocusNode.unfocus(),
                    ),
                  ),
                  
                  // Search/clear button
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _searchController.clear();
                        setState(() {
                          _searchResults.clear();
                          _searchedLocation = null;
                        });
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      splashRadius: 22,
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Icon(
                        _isSearching ? Icons.hourglass_empty : Icons.search_rounded,
                        color: _isSearching ? AppColors.primary : AppColors.textTertiary,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
            
            // Search loading indicator
            if (_isSearching)
              Container(
                margin: const EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(
                  backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 88,
      left: 16,
      right: 16,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.12),
              blurRadius: 32,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _searchResults.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: AppColors.border.withValues(alpha: 0.3),
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final result = _searchResults[index];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _selectSearchResult(result);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, 
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.place_rounded, 
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result['display_name'].toString().split(',')[0],
                                style: AppTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                result['display_name'],
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.north_east_rounded,
                          color: AppColors.textTertiary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyPanel() {
    final score = _locationSafetyScore ?? 0;
    final riskLevel = _locationRiskLevel ?? 'Unknown';
    
    Color scoreColor = score >= 80 ? AppColors.success
        : score >= 60 ? AppColors.warning
        : AppColors.error;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.15),
              blurRadius: 32,
              offset: const Offset(0, -8),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modern drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                children: [
                  // Header with close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Location Safety',
                          style: AppTypography.headingMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Material(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _showSafetyPanel = false);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.close_rounded,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Enhanced score display card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: scoreColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Animated score circle
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                scoreColor.withValues(alpha: 0.1),
                                scoreColor.withValues(alpha: 0.05),
                              ],
                            ),
                            border: Border.all(color: scoreColor, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: scoreColor.withValues(alpha: 0.2),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '$score',
                              style: AppTypography.headingLarge.copyWith(
                                color: scoreColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 32,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                riskLevel,
                                style: AppTypography.headingSmall.copyWith(
                                  color: scoreColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _getScoreDescription(score),
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Enhanced safety tip card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.infoLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.lightbulb_rounded, 
                            color: AppColors.info, 
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _getSafetyTip(score),
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
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
      ),
    );
  }

  Widget _buildMapControls() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom in
          _buildControlButton(
            icon: Icons.add_rounded,
            onPressed: () {
              _currentZoom = (_currentZoom + 1).clamp(3, 18);
              _safeMapMove(_mapController.camera.center, _currentZoom);
            },
            tooltip: 'Zoom In',
          ),
          
          const SizedBox(height: 2),
          
          // Zoom out
          _buildControlButton(
            icon: Icons.remove_rounded,
            onPressed: () {
              _currentZoom = (_currentZoom - 1).clamp(3, 18);
              _safeMapMove(_mapController.camera.center, _currentZoom);
            },
            tooltip: 'Zoom Out',
          ),
          
          const SizedBox(height: 2),
          
          // Center on user
          _buildControlButton(
            icon: Icons.my_location_rounded,
            onPressed: _centerOnUser,
            isPrimary: _isTrackingUser,
            tooltip: 'My Location',
          ),
          
          const SizedBox(height: 2),
          
          // Toggle heatmap
          _buildControlButton(
            icon: _showHeatmap ? Icons.layers_rounded : Icons.layers_clear_rounded,
            onPressed: () => setState(() => _showHeatmap = !_showHeatmap),
            isActive: _showHeatmap,
            tooltip: _showHeatmap ? 'Hide Heatmap' : 'Show Heatmap',
          ),
          
          // Heatmap settings
          if (_showHeatmap) ...[
            const SizedBox(height: 2),
            _buildControlButton(
              icon: Icons.tune_rounded,
              onPressed: _showHeatmapSettings,
              tooltip: 'Heatmap Settings',
            ),
          ],
          
          const SizedBox(height: 2),
          
          // Toggle zones
          _buildControlButton(
            icon: _showRestrictedZones ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            onPressed: () => setState(() => _showRestrictedZones = !_showRestrictedZones),
            isActive: _showRestrictedZones,
            tooltip: _showRestrictedZones ? 'Hide Zones' : 'Show Zones',
          ),
        ],
      ),
    );
  }


  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isPrimary = false,
    bool isActive = false,
    String? tooltip,
  }) {
    final isHighlighted = isPrimary || isActive;
    
    return Tooltip(
      message: tooltip ?? '',
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          borderRadius: BorderRadius.circular(12),
          splashColor: AppColors.primary.withValues(alpha: 0.2),
          highlightColor: AppColors.primary.withValues(alpha: 0.1),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isHighlighted 
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: isHighlighted
                  ? Border.all(
                      color: AppColors.primary,
                      width: 2,
                    )
                  : Border.all(
                      color: AppColors.border,
                      width: 0.5,
                    ),
            ),
            child: Icon(
              icon,
              color: isHighlighted 
                  ? AppColors.primary
                  : AppColors.textPrimary,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }









  Widget _buildLoadingStep(String text, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isCompleted 
                  ? AppColors.success 
                  : AppColors.border,
              shape: BoxShape.circle,
            ),
            child: isCompleted
                ? const Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: isCompleted 
                  ? AppColors.textPrimary 
                  : AppColors.textSecondary,
              fontWeight: isCompleted 
                  ? FontWeight.w600 
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  String _getMapTileUrl() {
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  Color _getZoneColor(dynamic type) {
    final typeStr = type.toString().toLowerCase();
    if (typeStr.contains('danger')) return AppColors.error;
    if (typeStr.contains('high') || typeStr.contains('risk')) return Colors.orange;
    if (typeStr.contains('restrict')) return AppColors.warning;
    return AppColors.info;
  }

  String _getScoreDescription(int score) {
    if (score >= 80) return 'This area is generally safe for tourists.';
    if (score >= 60) return 'Exercise normal caution in this area.';
    if (score >= 40) return 'Be cautious and aware of your surroundings.';
    return 'High-risk area. Consider avoiding this location.';
  }

  String _getSafetyTip(int score) {
    if (score >= 80) return 'Enjoy your visit! Keep your belongings secure.';
    if (score >= 60) return 'Stay in well-lit areas and travel in groups when possible.';
    if (score >= 40) return 'Keep emergency contacts ready and stay alert.';
    return 'Use the panic button if you feel unsafe. Police are available 24/7.';
  }

  /// Build user location marker for real-time tracking
  Widget _buildUserLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Animated pulse ring for real-time indication
        Container(
          width: 60 * (1 + _pulseController.value * 0.6),
          height: 60 * (1 + _pulseController.value * 0.6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(
              alpha: 0.4 * (1 - _pulseController.value),
            ),
          ),
        ),
        
        // Secondary pulse for real-time effect
        Container(
          width: 40 * (1 + _pulseController.value * 0.3),
          height: 40 * (1 + _pulseController.value * 0.3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(
              alpha: 0.6 * (1 - _pulseController.value),
            ),
          ),
        ),
        
        // User location dot
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
        
        // Real-time indicator dot
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.5),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
