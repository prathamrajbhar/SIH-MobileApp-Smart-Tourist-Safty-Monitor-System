import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../services/geofencing_service.dart';
import '../models/alert.dart';
import '../utils/logger.dart';

class TripMonitorScreen extends StatefulWidget {
  const TripMonitorScreen({super.key});

  @override
  State<TripMonitorScreen> createState() => _TripMonitorScreenState();
}

class _TripMonitorScreenState extends State<TripMonitorScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  Timer? _locationTimer;
  StreamSubscription<GeofenceEvent>? _geofenceSubscription;
  final GeofencingService _geofencingService = GeofencingService.instance;
  
  // Basic state
  double _currentLat = 0.0;
  double _currentLon = 0.0;
  double _speed = 0.0;
  String _address = "Getting location...";
  String? _destinationName;
  double _distance = 0.0;
  bool _isMonitoring = false;
  bool _isUpdatingLocation = false;
  int _updateCount = 0;
  final List<String> _logs = [];
  final TextEditingController _destinationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _getCurrentLocation();
    _startAutoLocationUpdates();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _geofenceSubscription?.cancel();
    _tabController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _startAutoLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isMonitoring && mounted) {
        _getCurrentLocation(isAutoUpdate: true);
      }
    });
  }

  Future<void> _getCurrentLocation({bool isAutoUpdate = false}) async {
    if (isAutoUpdate && !_isMonitoring) return;
    
    setState(() {
      _isUpdatingLocation = true;
    });
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _addLog("GPS service disabled");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _addLog("Location permission denied");
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      
      setState(() {
        _currentLat = position.latitude;
        _currentLon = position.longitude;
        _speed = position.speed * 3.6;
        _updateCount++;
        _isUpdatingLocation = false;
      });
      
      final updateType = isAutoUpdate ? "Auto update #$_updateCount" : "Manual update";
      _addLog("$updateType - Location refreshed");
      _getAddress();
      
      // Update distance if destination is set
      if (_destinationName != null && isAutoUpdate) {
        _updateDistance();
      }
    } catch (e) {
      setState(() {
        _isUpdatingLocation = false;
      });
      _addLog("Location error: ${e.toString().split('.').last}");
    }
  }

  Future<void> _getAddress() async {
    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$_currentLat&lon=$_currentLon'),
        headers: {'User-Agent': 'TouristApp'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _address = data['display_name']?.split(',').take(2).join(', ') ?? 'Unknown';
        });
      }
    } catch (e) {
      setState(() {
        _address = 'Address not available';
      });
    }
  }

  Future<void> _searchDestination() async {
    if (_destinationController.text.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=${_destinationController.text}&limit=1'),
        headers: {'User-Agent': 'TouristApp'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final place = data[0];
          setState(() {
            _destinationName = place['display_name'].split(',').take(2).join(', ');
            _distance = Geolocator.distanceBetween(
              _currentLat, _currentLon,
              double.parse(place['lat']), double.parse(place['lon'])
            ) / 1000;
          });
          _addLog("Destination set");
        }
      }
    } catch (e) {
      _addLog("Search failed");
    }
  }

  void _updateDistance() {
    // Recalculate distance if destination is set
    // This would be called during auto updates to show changing distance
  }

  void _toggleMonitoring() {
    setState(() {
      _isMonitoring = !_isMonitoring;
      if (_isMonitoring) {
        _updateCount = 0;
        _startGeofenceMonitoring();
      } else {
        _stopGeofenceMonitoring();
      }
    });
    final status = _isMonitoring ? "started - Auto updates every 1s + Restricted zone alerts" : "stopped";
    _addLog("Monitoring $status");
    
    if (_isMonitoring) {
      _getCurrentLocation(isAutoUpdate: false);
    }
  }

  /// Start geofence monitoring for restricted zones
  Future<void> _startGeofenceMonitoring() async {
    try {
      await _geofencingService.initialize();
      await _geofencingService.startMonitoring();
      
      // Listen to geofence events
      _geofenceSubscription = _geofencingService.events.listen((event) {
        if (mounted) {
          _handleGeofenceEvent(event);
        }
      });
      
      _addLog("🛡️ Restricted zone monitoring activated");
    } catch (e) {
      _addLog("⚠️ Geofencing setup failed: ${e.toString().split('.').last}");
    }
  }

  /// Stop geofence monitoring
  void _stopGeofenceMonitoring() {
    _geofenceSubscription?.cancel();
    _geofencingService.stopMonitoring();
    _addLog("🛡️ Restricted zone monitoring deactivated");
  }

  /// Handle geofence events (entry/exit)
  void _handleGeofenceEvent(GeofenceEvent event) {
    final eventType = event.eventType == GeofenceEventType.enter ? "ENTERED" : "EXITED";
    final alertLevel = event.zone.type == ZoneType.dangerous ? "🚨 DANGER" : "⚠️ RESTRICTED";
    
    _addLog("$alertLevel: $eventType ${event.zone.name}");
    
    // Log zone entry (notification is handled by GeofencingService)
    if (event.eventType == GeofenceEventType.enter) {
      _showRestrictedZoneDialog(event.zone);
    }
  }

  /// Log restricted zone entry (no dialog shown)
  void _showRestrictedZoneDialog(RestrictedZone zone) {
    // Only log entry, no dialog - notification is handled by GeofencingService
    AppLogger.warning('Restricted zone entered: ${zone.name} - notification sent via GeofencingService');
  }

  void _addLog(String message) {
    final time = TimeOfDay.now();
    setState(() {
      _logs.insert(0, "${time.hour}:${time.minute.toString().padLeft(2, '0')} - $message");
      if (_logs.length > 15) _logs.removeLast();
    });
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
          'Trip Monitor',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0EA5E9),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF0EA5E9),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Our Trip'),
            Tab(text: 'Activity'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOurTripTab(),
          _buildActivityTab(),
        ],
      ),
    );
  }

  Widget _buildOurTripTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Location Card
          _buildInfoCard(
            icon: _isUpdatingLocation ? Icons.sync : Icons.location_on,
            title: 'Current Location ${_isUpdatingLocation ? "(Updating...)" : ""}',
            children: [
              _buildInfoRow('Address', _address),
              _buildInfoRow('Coordinates', '${_currentLat.toStringAsFixed(6)}, ${_currentLon.toStringAsFixed(6)}'),
              _buildInfoRow('Speed', '${_speed.toStringAsFixed(1)} km/h'),
              if (_updateCount > 0)
                _buildInfoRow('Updates', '$_updateCount auto-updates completed'),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Destination Search Card
          _buildInfoCard(
            icon: Icons.search,
            title: 'Set Destination',
            children: [
              TextField(
                controller: _destinationController,
                decoration: const InputDecoration(
                  hintText: 'Enter destination name',
                  filled: true,
                  fillColor: Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _searchDestination,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Search Destination'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Destination Info Card (if set)
          if (_destinationName != null)
            _buildInfoCard(
              icon: Icons.place,
              title: 'Destination',
              children: [
                _buildInfoRow('Name', _destinationName!),
                _buildInfoRow('Distance', '${_distance.toStringAsFixed(1)} km'),
              ],
            ),
          
          const SizedBox(height: 16),
          
          // Trip Status Card
          _buildStatusCard(),
          
          const SizedBox(height: 16),
          
          // Auto-refresh active when monitoring. Manual refresh removed.
          const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Trip Activities',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _logs.clear();
                  });
                },
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: Color(0xFF0EA5E9)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _logs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 48,
                            color: Color(0xFF94A3B8),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No activities yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0EA5E9),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _logs[index],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0EA5E9), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isMonitoring ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isMonitoring ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isUpdatingLocation ? Icons.sync : (_isMonitoring ? Icons.trip_origin : Icons.pause_circle),
                color: _isMonitoring ? const Color(0xFF22C55E) : const Color(0xFF64748B),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Trip Status',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (_isUpdatingLocation)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isMonitoring 
                ? (_isUpdatingLocation ? 'Updating location...' : 'Active - Updates every 1s + Zone alerts')
                : 'Monitoring Inactive',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _isMonitoring ? const Color(0xFF22C55E) : const Color(0xFF64748B),
            ),
          ),
          if (_isMonitoring && _updateCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Last update: ${DateTime.now().toString().substring(11, 19)}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _toggleMonitoring,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: _isMonitoring ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                ),
                foregroundColor: _isMonitoring ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
              ),
              child: Text(_isMonitoring ? 'Stop Monitoring' : 'Start Monitoring'),
            ),
          ),
        ],
      ),
    );
  }
}