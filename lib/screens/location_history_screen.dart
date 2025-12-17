// ignore_for_file: unused_element

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../models/location.dart';
import '../theme/app_theme.dart';

class LocationHistoryScreen extends StatefulWidget {
  const LocationHistoryScreen({super.key});

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();
  late TabController _tabController;
  
  List<LocationData> _locations = [];
  List<LocationData> _filteredLocations = [];
  bool _isLoading = false; // Start false to show map immediately
  bool _hasLoadedOnce = false; // Track if data has been loaded
  bool _isMapReady = false; // Track map readiness
  String _selectedFilter = 'Today';
  int? _selectedLocationIndex;
  bool _showPathLine = true;
  
  // Default center (Delhi, India) - used until real data loads
  static const LatLng _defaultCenter = LatLng(28.6139, 77.2090);
  
  final List<String> _timeFilters = ['Today', 'This Week', 'This Month', 'All Time'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLocationHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Safe map movement that handles controller readiness
  void _safeMapMove(LatLng location, double zoom) {
    try {
      if (_isMapReady && mounted) {
        _mapController.move(location, zoom);
      }
    } catch (e) {
      print('Map move failed: $e');
      // Retry after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_isMapReady && mounted) {
          try {
            _mapController.move(location, zoom);
          } catch (e) {
            print('Map move retry failed: $e');
          }
        }
      });
    }
  }

  /// Safe fit bounds method
  void _safeFitBounds(List<LatLng> points) {
    try {
      if (_isMapReady && mounted && points.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(50),
          ),
        );
      }
    } catch (e) {
      print('Map fit bounds failed: $e');
    }
  }

  Future<void> _loadLocationHistory() async {
    // Only show loading indicator for subsequent loads, not initial
    if (_hasLoadedOnce) {
      setState(() => _isLoading = true);
    }
    
    try {
      final response = await _apiService.getLocationHistory(limit: 100);
      final List<dynamic> locationData = response['locations'] ?? [];
      final locations = locationData
          .map((json) => LocationData.fromJson(json as Map<String, dynamic>))
          .toList();
      
      if (mounted) {
        setState(() {
          _locations = locations;
          _applyFilter();
          _isLoading = false;
        });

        // Center map on latest location if available (only on first load)
        if (_filteredLocations.isNotEmpty && !_hasLoadedOnce) {
          final latest = _filteredLocations.first;
          _safeMapMove(LatLng(latest.latitude, latest.longitude), 15.0);
        }
        
        // Mark as loaded after state update
        setState(() {
          _hasLoadedOnce = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLoadedOnce = true;
        });
        
        // Only show error snackbar if we have no data to display
        if (_locations.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load location history: $e'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _loadLocationHistory,
              ),
            ),
          );
        }
      }
    }
  }

  bool _filterByTime(LocationData location) {
    final now = DateTime.now();
    final locationTime = location.timestamp;
    
    switch (_selectedFilter) {
      case 'Today':
        return locationTime.day == now.day && 
               locationTime.month == now.month && 
               locationTime.year == now.year;
      case 'This Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return locationTime.isAfter(weekStart.subtract(const Duration(days: 1)));
      case 'This Month':
        return locationTime.month == now.month && locationTime.year == now.year;
      case 'All Time':
      default:
        return true;
    }
  }

  void _applyFilter() {
    _filteredLocations = _locations.where(_filterByTime).toList();
    _selectedLocationIndex = null; // Reset selection when filter changes
  }

  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  double _calculateTotalDistance() {
    if (_filteredLocations.length < 2) return 0.0;
    
    double totalDistance = 0.0;
    for (int i = 0; i < _filteredLocations.length - 1; i++) {
      totalDistance += _calculateDistance(
        _filteredLocations[i].latitude,
        _filteredLocations[i].longitude,
        _filteredLocations[i + 1].latitude,
        _filteredLocations[i + 1].longitude,
      );
    }
    return totalDistance;
  }

  double _calculateAverageSafetyScore() {
    if (_filteredLocations.isEmpty) return 0.0;
    
    final scores = _filteredLocations
        .where((loc) => loc.safetyScore != null)
        .map((loc) => loc.safetyScore!.toDouble())
        .toList();
    
    if (scores.isEmpty) return 0.0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  List<Marker> _buildMapMarkers() {
    if (_filteredLocations.isEmpty) return [];
    
    final markers = <Marker>[];
    
    // Add path markers with selection support
    for (int i = 0; i < _filteredLocations.length; i++) {
      final location = _filteredLocations[i];
      final isFirst = i == 0;
      final isLast = i == _filteredLocations.length - 1;
      final isSelected = i == _selectedLocationIndex;
      
      markers.add(
        Marker(
          point: LatLng(location.latitude, location.longitude),
          width: isSelected ? 50 : (isFirst || isLast ? 40 : 30),
          height: isSelected ? 50 : (isFirst || isLast ? 40 : 30),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedLocationIndex = i;
              });
              _showLocationDetails(location, i);
            },
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFF59E0B) // Orange for selected
                    : isFirst
                        ? const Color(0xFF10B981) // Green for start
                        : isLast
                            ? const Color(0xFFEF4444) // Red for end
                            : const Color(0xFF3B82F6), // Blue for middle
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: isSelected ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isFirst ? Icons.flag : (isLast ? Icons.location_on : Icons.circle),
                  color: Colors.white,
                  size: isSelected ? 24 : (isFirst || isLast ? 20 : 12),
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return markers;
  }

  List<Polyline> _buildMapPolylines() {
    if (_filteredLocations.length < 2 || !_showPathLine) return [];
    
    final points = _filteredLocations
        .map((loc) => LatLng(loc.latitude, loc.longitude))
        .toList();
    
    return [
      Polyline(
        points: points,
        strokeWidth: 3.0,
        color: AppColors.primary.withValues(alpha: 0.7),
      ),
    ];
  }

  void _showLocationDetails(LocationData location, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Location Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Position', '${index + 1} of ${_filteredLocations.length}'),
            _buildDetailRow('Latitude', location.latitude.toStringAsFixed(6)),
            _buildDetailRow('Longitude', location.longitude.toStringAsFixed(6)),
            _buildDetailRow('Time', _formatDateTime(location.timestamp)),
            if (location.safetyScore != null)
              _buildDetailRow(
                'Safety Score',
                '${location.safetyScore}/100',
                valueColor: location.safetyScore! >= 80
                    ? const Color(0xFF10B981)
                    : location.safetyScore! >= 60
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFEF4444),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _safeMapMove(
                    LatLng(location.latitude, location.longitude),
                    17.0,
                  );
                },
                icon: const Icon(Icons.my_location),
                label: const Text('Center on Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Location Data',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final locationDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    String datePrefix;
    if (locationDate == today) {
      datePrefix = 'Today';
    } else if (locationDate == today.subtract(const Duration(days: 1))) {
      datePrefix = 'Yesterday';
    } else {
      datePrefix = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    
    final timeString = '${dateTime.hour.toString().padLeft(2, '0')}:'
                      '${dateTime.minute.toString().padLeft(2, '0')}';
    
    return '$datePrefix at $timeString';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location History'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.map), text: 'Map'),
            Tab(icon: Icon(Icons.list), text: 'List'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
                _applyFilter();
              });
            },
            itemBuilder: (context) => _timeFilters.map((filter) {
              return PopupMenuItem(
                value: filter,
                child: Row(
                  children: [
                    if (filter == _selectedFilter)
                      const Icon(Icons.check, color: Color(0xFF3B82F6), size: 20),
                    if (filter == _selectedFilter)
                      const SizedBox(width: 8),
                    Text(filter),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Always show the main content (map/list tabs)
          Column(
            children: [
              // Statistics Card - show even when loading
              if (_hasLoadedOnce && _filteredLocations.isNotEmpty)
                _buildStatisticsCard(),
              // Content - always render tabs
              Expanded(
                child: _hasLoadedOnce && _filteredLocations.isEmpty
                    ? _buildEmptyState('No locations found for the selected filter.')
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildMapView(), // Map always renders
                          _hasLoadedOnce
                              ? _buildListView()
                              : const Center(
                                  child: CircularProgressIndicator(),
                                ), // List needs data
                        ],
                      ),
              ),
            ],
          ),
          // Loading overlay only on first load
          if (!_hasLoadedOnce)
            Container(
              color: Colors.white.withValues(alpha: 0.9),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading location history...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Map will appear shortly',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
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

  Widget _buildStatisticsCard() {
    final totalDistance = _calculateTotalDistance();
    final avgSafety = _calculateAverageSafetyScore();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.route,
            label: 'Distance',
            value: '${totalDistance.toStringAsFixed(1)} km',
            color: const Color(0xFF3B82F6),
          ),
          _buildStatItem(
            icon: Icons.pin_drop,
            label: 'Locations',
            value: '${_filteredLocations.length}',
            color: const Color(0xFF10B981),
          ),
          _buildStatItem(
            icon: Icons.shield,
            label: 'Avg Safety',
            value: '${avgSafety.toStringAsFixed(0)}%',
            color: avgSafety >= 80
                ? const Color(0xFF10B981)
                : avgSafety >= 60
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _filteredLocations.isNotEmpty
                ? LatLng(_filteredLocations.first.latitude,
                    _filteredLocations.first.longitude)
                : _defaultCenter, // Use constant default center
            initialZoom: _filteredLocations.isNotEmpty ? 15.0 : 12.0,
            onMapReady: () {
              setState(() {
                _isMapReady = true;
              });
              print('🗺️ Location History Map is now ready');
              
              // Center on latest location if available and not loaded once
              if (_filteredLocations.isNotEmpty && !_hasLoadedOnce) {
                final latest = _filteredLocations.first;
                _safeMapMove(LatLng(latest.latitude, latest.longitude), 15.0);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.safehorizon.app',
            ),
            if (_showPathLine) PolylineLayer(polylines: _buildMapPolylines()),
            MarkerLayer(markers: _buildMapMarkers()),
          ],
        ),
        // Subtle loading overlay when refreshing data
        if (_isLoading)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Updating...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Map Controls
        Positioned(
          right: 16,
          bottom: 80,
          child: Column(
            children: [
              // Toggle Path Line
              FloatingActionButton.small(
                heroTag: 'togglePath',
                onPressed: () {
                  setState(() {
                    _showPathLine = !_showPathLine;
                  });
                },
                backgroundColor: Colors.white,
                child: Icon(
                  _showPathLine ? Icons.timeline : Icons.timeline_outlined,
                  color: _showPathLine ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              // Fit All Markers
              FloatingActionButton.small(
                heroTag: 'fitBounds',
                onPressed: () {
                  if (_filteredLocations.isEmpty) return;
                  
                  double minLat = _filteredLocations.first.latitude;
                  double maxLat = _filteredLocations.first.latitude;
                  double minLon = _filteredLocations.first.longitude;
                  double maxLon = _filteredLocations.first.longitude;
                  
                  for (final loc in _filteredLocations) {
                    if (loc.latitude < minLat) minLat = loc.latitude;
                    if (loc.latitude > maxLat) maxLat = loc.latitude;
                    if (loc.longitude < minLon) minLon = loc.longitude;
                    if (loc.longitude > maxLon) maxLon = loc.longitude;
                  }
                  
                  final points = [
                    LatLng(minLat, minLon),
                    LatLng(maxLat, maxLon),
                  ];
                  _safeFitBounds(points);
                },
                backgroundColor: Colors.white,
                child: Icon(Icons.fit_screen, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: _filteredLocations.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final location = _filteredLocations[index];
        final isSelected = index == _selectedLocationIndex;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (index == 0
                        ? const Color(0xFF10B981)
                        : index == _filteredLocations.length - 1
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF3B82F6))
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                index == 0
                    ? Icons.flag
                    : index == _filteredLocations.length - 1
                        ? Icons.location_on
                        : Icons.circle,
                color: index == 0
                    ? const Color(0xFF10B981)
                    : index == _filteredLocations.length - 1
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF3B82F6),
              ),
            ),
            title: Text(
              '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(location.timestamp),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (location.safetyScore != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.shield,
                        size: 14,
                        color: location.safetyScore! >= 80
                            ? const Color(0xFF10B981)
                            : location.safetyScore! >= 60
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Safety: ${location.safetyScore}/100',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: location.safetyScore! >= 80
                              ? const Color(0xFF10B981)
                              : location.safetyScore! >= 60
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              setState(() {
                _selectedLocationIndex = index;
              });
              _showLocationDetails(location, index);
            },
          ),
        );
      },
    );
  }
}
