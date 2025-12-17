import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/tourist.dart';
import '../models/alert.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

class DangerZonesScreen extends StatefulWidget {
  final Tourist tourist;

  const DangerZonesScreen({
    super.key,
    required this.tourist,
  });

  @override
  State<DangerZonesScreen> createState() => _DangerZonesScreenState();
}

class _DangerZonesScreenState extends State<DangerZonesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();

  List<RestrictedZone> _restrictedZones = [];
  bool _isLoading = true;
  String? _errorMessage;
  LatLng _currentLocation = const LatLng(28.6139, 77.2090); // Default to Delhi, will be updated

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    AppLogger.info('🚫 Danger Zones Screen initialized');
    _getCurrentLocation();
    _loadRestrictedZones();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRestrictedZones() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final zones = await _apiService.getRestrictedZones();
      
      if (mounted) {
        setState(() {
          _restrictedZones = zones;
          _isLoading = false;
        });
        AppLogger.info('🚫 Loaded ${zones.length} restricted zones');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load danger zones: $e';
        });
      }
      AppLogger.error('Failed to load restricted zones', error: e);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warning('Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.warning('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.warning('Location permissions are permanently denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        
        // Update map center to current location
        _mapController.move(_currentLocation, 12.0);
        
        AppLogger.info('📍 Current location updated: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      AppLogger.error('Failed to get current location', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Danger Zones',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
            onPressed: _loadRestrictedZones,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFEF4444),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFFEF4444),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Map View'),
            Tab(text: 'Zone List'),
            Tab(text: 'Safety Guide'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMapView(),
          _buildZonesList(),
          _buildSafetyGuide(),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFEF4444)),
            SizedBox(height: 16),
            Text(
              'Loading danger zones...',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFEF4444),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRestrictedZones,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: 10.0,
            minZoom: 5.0,
            maxZoom: 18.0,
            keepAlive: true,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.mobile',
              maxNativeZoom: 19,
            ),
            // Add polygon overlays for restricted zones
            ..._restrictedZones.map((zone) => PolygonLayer(
              polygons: [
                Polygon(
                  points: zone.polygonCoordinates,
                  color: const Color(0xFFEF4444).withOpacity(0.3),
                  borderColor: const Color(0xFFEF4444),
                  borderStrokeWidth: 2,
                  label: zone.name,
                  labelStyle: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )),
            // Add markers for zone centers
            MarkerLayer(
              markers: _restrictedZones.map((zone) {
                final center = _calculatePolygonCenter(zone.polygonCoordinates);
                return Marker(
                  point: center,
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => _showZoneDetails(zone),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.warning,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        _buildMapLegend(),
        _buildLocationButton(),
      ],
    );
  }

  Widget _buildZonesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFEF4444)));
    }

    if (_restrictedZones.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Color(0xFF10B981),
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'No danger zones in your area',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'You\'re in a safe area!',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _restrictedZones.length,
      itemBuilder: (context, index) {
        final zone = _restrictedZones[index];
        return _buildZoneCard(zone);
      },
    );
  }

  Widget _buildSafetyGuide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSafetyCard(
            icon: Icons.map,
            title: 'Understanding Zone Classifications',
            color: const Color(0xFFEF4444),
            content: [
              'Red Zones: High-risk areas with recent security incidents',
              'Orange Zones: Moderate risk areas requiring caution',
              'Yellow Zones: Areas with specific restrictions or advisories',
              'Prohibited Areas: Areas strictly off-limits to tourists',
            ],
          ),
          const SizedBox(height: 16),
          _buildSafetyCard(
            icon: Icons.warning_amber,
            title: 'What to Do if You Enter a Danger Zone',
            color: const Color(0xFFEF4444),
            content: [
              'Leave the area immediately via the safest route',
              'Contact local authorities if you feel threatened',
              'Use the SOS feature if in immediate danger',
              'Inform your emergency contacts of your situation',
              'Follow any instructions from security personnel',
            ],
          ),
          const SizedBox(height: 16),
          _buildSafetyCard(
            icon: Icons.navigation,
            title: 'Avoiding Danger Zones',
            color: const Color(0xFFF59E0B),
            content: [
              'Plan your routes using trusted navigation apps',
              'Check zone updates before traveling',
              'Travel during daylight hours when possible',
              'Stay on main roads and avoid shortcuts',
              'Travel in groups when visiting unfamiliar areas',
            ],
          ),
          const SizedBox(height: 16),
          _buildSafetyCard(
            icon: Icons.phone,
            title: 'Emergency Contacts',
            color: const Color(0xFF10B981),
            content: [
              'Police Emergency: 100',
              'Medical Emergency: 108',
              'Tourist Helpline: 1363',
              'Fire Emergency: 101',
              'Your embassy or consulate contact',
            ],
          ),
          const SizedBox(height: 16),
          _buildSOSQuickAccess(),
        ],
      ),
    );
  }

  Widget _buildZoneCard(RestrictedZone zone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    zone.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _showOnMap(zone),
                  icon: const Icon(
                    Icons.map,
                    color: Color(0xFF0EA5E9),
                  ),
                ),
              ],
            ),
            if (zone.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                zone.description,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showZoneDetails(zone),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _getDirectionsAway(zone),
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('Avoid Route'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<String> content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...content.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF475569),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSOSQuickAccess() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.crisis_alert,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Emergency SOS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'If you find yourself in a danger zone or emergency situation, activate SOS immediately',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _activateSOS,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFEF4444),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'Activate SOS',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapLegend() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Legend',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Danger Zone',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationButton() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton(
        onPressed: _centerOnUserLocation,
        backgroundColor: const Color(0xFF0EA5E9),
        child: const Icon(
          Icons.my_location,
          color: Colors.white,
        ),
      ),
    );
  }

  LatLng _calculatePolygonCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    
    double lat = 0;
    double lng = 0;
    
    for (final point in points) {
      lat += point.latitude;
      lng += point.longitude;
    }
    
    return LatLng(lat / points.length, lng / points.length);
  }

  void _showZoneDetails(RestrictedZone zone) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning,
                  color: Color(0xFFEF4444),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    zone.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              zone.description,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF475569),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showOnMap(zone);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                    ),
                    child: const Text('View on Map'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _getDirectionsAway(zone);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                    child: const Text('Avoid Route'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOnMap(RestrictedZone zone) {
    _tabController.animateTo(0); // Switch to map view
    final center = _calculatePolygonCenter(zone.polygonCoordinates);
    _mapController.move(center, 14.0);
  }

  void _getDirectionsAway(RestrictedZone zone) {
    HapticFeedback.lightImpact();
    AppLogger.info('🗺️ Getting directions to avoid zone: ${zone.name}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Finding safe route avoiding ${zone.name}...'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _centerOnUserLocation() {
    HapticFeedback.lightImpact();
    AppLogger.info('📍 Centering map on user location');
    // In a real app, this would get the user's current location
    _mapController.move(_currentLocation, 12.0);
  }

  void _activateSOS() {
    HapticFeedback.heavyImpact();
    AppLogger.info('🚨 SOS activated from Danger Zones screen');
    Navigator.pushNamed(context, '/sos');
  }
}
