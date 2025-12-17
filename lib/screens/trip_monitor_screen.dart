import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

class TripMonitorScreen extends StatefulWidget {
  const TripMonitorScreen({super.key});

  @override
  State<TripMonitorScreen> createState() => _TripMonitorScreenState();
}

class _TripMonitorScreenState extends State<TripMonitorScreen> {
  final TextEditingController _destinationController = TextEditingController();
  
  // Simple state variables
  double _currentLat = 0.0;
  double _currentLon = 0.0;
  double _speed = 0.0;
  String _address = "Getting location...";
  
  String? _destinationName;
  double _distance = 0.0;
  bool _isMonitoring = false;
  bool _isLoading = false;
  
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _addLog("Location service disabled");
        setState(() {
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _addLog("Location permission denied");
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      
      setState(() {
        _currentLat = position.latitude;
        _currentLon = position.longitude;
        _speed = position.speed * 3.6;
        _isLoading = false;
      });
      
      _addLog("Location updated");
      _getAddress();
      
    } catch (e) {
      _addLog("Error: ${e.toString()}");
      setState(() {
        _isLoading = false;
      });
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
    
    setState(() {
      _isLoading = true;
    });

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
          _addLog("Destination set: $_destinationName");
        } else {
          _addLog("Destination not found");
        }
      }
    } catch (e) {
      _addLog("Search failed");
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  void _toggleMonitoring() {
    setState(() {
      _isMonitoring = !_isMonitoring;
    });
    _addLog(_isMonitoring ? "Monitoring started" : "Monitoring stopped");
  }

  void _sendSOS() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SOS Alert Sent'),
        content: Text('Emergency alert sent!\nLocation: ${_currentLat.toStringAsFixed(4)}, ${_currentLon.toStringAsFixed(4)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    _addLog("SOS Alert sent");
  }

  void _addLog(String message) {
    final time = TimeOfDay.now();
    setState(() {
      _logs.insert(0, "${time.hour}:${time.minute.toString().padLeft(2, '0')} - $message");
      if (_logs.length > 10) _logs.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Monitor'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Current Location Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text('Current Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          if (_isLoading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Address: $_address'),
                      const SizedBox(height: 8),
                      Text('Latitude: ${_currentLat.toStringAsFixed(6)}'),
                      Text('Longitude: ${_currentLon.toStringAsFixed(6)}'),
                      Text('Speed: ${_speed.toStringAsFixed(1)} km/h'),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _getCurrentLocation,
                          icon: const Icon(Icons.refresh),
                          label: Text(_isLoading ? 'Updating...' : 'Update Location'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Destination Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.place, color: Colors.green),
                          const SizedBox(width: 8),
                          const Text('Destination', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _destinationController,
                        decoration: const InputDecoration(
                          hintText: 'Enter destination (e.g., Delhi)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _searchDestination,
                          icon: const Icon(Icons.search),
                          label: Text(_isLoading ? 'Searching...' : 'Search'),
                        ),
                      ),
                      if (_destinationName != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Selected: $_destinationName', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Distance: ${_distance.toStringAsFixed(1)} km'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Controls Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.control_point, color: Colors.orange),
                          const SizedBox(width: 8),
                          const Text('Controls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _toggleMonitoring,
                              icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
                              label: Text(_isMonitoring ? 'Stop Monitor' : 'Start Monitor'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isMonitoring ? Colors.orange : Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _sendSOS,
                          icon: const Icon(Icons.emergency),
                          label: const Text('Send SOS Alert'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Activity Log Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.history, color: Colors.purple),
                          const SizedBox(width: 8),
                          const Text('Activity Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _logs.isEmpty
                            ? const Center(child: Text('No activity yet'))
                            : ListView.builder(
                                itemCount: _logs.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    child: Text(
                                      _logs[index],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: index == 0 ? Colors.blue : Colors.black87,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 80), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }
}