import 'package:flutter/material.dart';
import '../services/settings_manager.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/location_transmission_service.dart';
import '../services/proximity_alert_service.dart';
import '../services/geofencing_service.dart';
import '../utils/logger.dart';
import 'login_screen.dart';
import 'emergency_contacts_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsManager _settings = SettingsManager();
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final LocationTransmissionService _locationTransmissionService = LocationTransmissionService();
  final ProximityAlertService _proximityService = ProximityAlertService.instance;
  final GeofencingService _geofenceService = GeofencingService.instance;
  
  bool _isLoading = true;
  
  // Core settings only
  bool _locationTracking = true;
  bool _proximityAlerts = true;
  bool _geofenceAlerts = true;
  String _updateInterval = '10';
  int _locationUpdateInterval = 15; // minutes
  int _proximityRadius = 5;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      setState(() {
        _locationTracking = _settings.locationTracking;
        _proximityAlerts = _settings.proximityAlerts;
        _geofenceAlerts = _settings.geofenceAlerts;
        _updateInterval = _settings.updateInterval;
        _locationUpdateInterval = _settings.locationUpdateInterval;
        _proximityRadius = _settings.proximityRadius;
      });
      AppLogger.info('✅ Settings loaded');
    } catch (e) {
      AppLogger.error('Failed to load settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _applyLocationTracking(bool value) async {
    await _settings.setLocationTracking(value);
    if (value) {
      await _locationService.startTracking();
      _showSnackBar('📍 Location tracking enabled');
    } else {
      await _locationService.stopTracking();
      _showSnackBar('📍 Location tracking disabled');
    }
  }

  Future<void> _applyUpdateInterval(String value) async {
    await _settings.setUpdateInterval(value);
    if (_locationTracking) {
      await _locationService.stopTracking();
      await _locationService.startTracking();
      _showSnackBar('⏱️ Update interval: ${value}s');
    }
  }

  Future<void> _applyProximityAlerts(bool value) async {
    await _settings.setProximityAlerts(value);
    if (value) {
      await _proximityService.startMonitoring();
      _showSnackBar('📍 Proximity alerts enabled');
    } else {
      _proximityService.stopMonitoring();
      _showSnackBar('📍 Proximity alerts disabled');
    }
  }

  Future<void> _applyGeofenceAlerts(bool value) async {
    await _settings.setGeofenceAlerts(value);
    if (value) {
      await _geofenceService.startMonitoring();
      _showSnackBar('🚧 Geofence alerts enabled');
    } else {
      _geofenceService.stopMonitoring();
      _showSnackBar('🚧 Geofence alerts disabled');
    }
  }

  Future<void> _applyProximityRadius(int value) async {
    await _settings.setProximityRadius(value);
    if (_proximityAlerts) {
      _proximityService.stopMonitoring();
      await _proximityService.startMonitoring();
      _showSnackBar('📏 Alert radius: ${value}km');
    }
  }

  Future<void> _applyLocationUpdateInterval(int minutes) async {
    await _settings.setLocationUpdateInterval(minutes);
    await _locationTransmissionService.updateLocationInterval(minutes);
    if (minutes > 0) {
      _showSnackBar('📍 Location updates every $minutes minutes');
    } else {
      _showSnackBar('📍 Automatic location updates disabled');
    }
  }

  Future<void> _sendManualLocationUpdate() async {
    try {
      setState(() => _isLoading = true);
      await _locationTransmissionService.sendManualLocationUpdate();
      _showSnackBar('📍 Location sent successfully');
    } catch (e) {
      _showSnackBar('❌ Failed to send location: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 12),
            Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _locationService.stopTracking();
      _proximityService.stopMonitoring();
      _geofenceService.stopMonitoring();
      await _apiService.clearAuth();
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1E40AF), size: 22),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF1E40AF),
        secondary: icon != null 
            ? Icon(icon, color: value ? const Color(0xFF1E40AF) : const Color(0xFF94A3B8))
            : null,
      ),
    );
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    IconData? icon,
    Widget? trailing,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: iconColor ?? const Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
        leading: icon != null 
            ? Icon(icon, color: iconColor ?? const Color(0xFF64748B))
            : null,
        trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          
          // LOCATION & TRACKING
          _buildSectionHeader('Location & Tracking', Icons.location_on_rounded),
          _buildSwitchTile(
            title: 'Location Tracking',
            subtitle: 'Real-time location monitoring',
            value: _locationTracking,
            icon: Icons.my_location_rounded,
            onChanged: (value) async {
              setState(() => _locationTracking = value);
              await _applyLocationTracking(value);
            },
          ),
          _buildListTile(
            title: 'Update Interval',
            subtitle: 'Location update frequency',
            icon: Icons.timer_rounded,
            trailing: Text(
              '${_updateInterval}s',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E40AF),
              ),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Update Interval'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: ['5', '10', '15', '30', '60'].map((interval) => 
                      RadioListTile<String>(
                        title: Text('$interval seconds'),
                        subtitle: Text(
                          interval == '5' ? 'High accuracy' : 
                          interval == '60' ? 'Battery saver' : 'Balanced'
                        ),
                        value: interval,
                        groupValue: _updateInterval,
                        activeColor: const Color(0xFF1E40AF),
                        onChanged: (value) async {
                          Navigator.pop(context);
                          setState(() => _updateInterval = value!);
                          await _applyUpdateInterval(value!);
                        },
                      ),
                    ).toList(),
                  ),
                ),
              );
            },
          ),
          _buildListTile(
            title: 'Location Update Interval',
            subtitle: 'Automatic location sharing frequency',
            icon: Icons.schedule_rounded,
            trailing: Text(
              _locationUpdateInterval == 0 ? 'Off' : '${_locationUpdateInterval}min',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E40AF),
              ),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Location Update Interval'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [0, 5, 10, 15, 30, 60].map((minutes) => 
                      RadioListTile<int>(
                        title: Text(minutes == 0 ? 'Disabled' : '$minutes minutes'),
                        subtitle: Text(
                          minutes == 0 ? 'Manual only' :
                          minutes <= 10 ? 'Frequent updates' :
                          minutes <= 30 ? 'Regular updates' : 'Battery saver'
                        ),
                        value: minutes,
                        groupValue: _locationUpdateInterval,
                        activeColor: const Color(0xFF1E40AF),
                        onChanged: (value) async {
                          Navigator.pop(context);
                          setState(() => _locationUpdateInterval = value!);
                          await _applyLocationUpdateInterval(value!);
                        },
                      ),
                    ).toList(),
                  ),
                ),
              );
            },
          ),
          _buildListTile(
            title: 'Send Location Now',
            subtitle: 'Manually share current location',
            icon: Icons.send_rounded,
            trailing: _isLoading ? 
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ) : 
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: _isLoading ? null : () {
              _sendManualLocationUpdate();
            },
          ),

          // ALERTS
          _buildSectionHeader('Alerts', Icons.notifications_rounded),
          _buildSwitchTile(
            title: 'Proximity Alerts',
            subtitle: 'Nearby emergency notifications',
            value: _proximityAlerts,
            icon: Icons.warning_rounded,
            onChanged: (value) async {
              setState(() => _proximityAlerts = value);
              await _applyProximityAlerts(value);
            },
          ),
          _buildSwitchTile(
            title: 'Geofence Alerts',
            subtitle: 'Restricted zone warnings',
            value: _geofenceAlerts,
            icon: Icons.fence_rounded,
            onChanged: (value) async {
              setState(() => _geofenceAlerts = value);
              await _applyGeofenceAlerts(value);
            },
          ),
          _buildListTile(
            title: 'Alert Radius',
            subtitle: 'Detection range for nearby alerts',
            icon: Icons.adjust_rounded,
            trailing: Text(
              '${_proximityRadius}km',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E40AF),
              ),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Alert Radius'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [1, 3, 5, 10, 15, 20].map((radius) => 
                      RadioListTile<int>(
                        title: Text('$radius km'),
                        subtitle: Text(
                          radius <= 3 ? 'Very close' : 
                          radius <= 10 ? 'Moderate' : 'Wide area'
                        ),
                        value: radius,
                        groupValue: _proximityRadius,
                        activeColor: const Color(0xFF1E40AF),
                        onChanged: (value) async {
                          Navigator.pop(context);
                          setState(() => _proximityRadius = value!);
                          await _applyProximityRadius(value!);
                        },
                      ),
                    ).toList(),
                  ),
                ),
              );
            },
          ),

          // ACCOUNT
          _buildSectionHeader('Account', Icons.person_rounded),
          _buildListTile(
            title: 'Emergency Contacts',
            subtitle: 'Manage emergency contacts',
            icon: Icons.contact_emergency_rounded,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmergencyContactsScreen(),
                ),
              );
            },
          ),
          _buildListTile(
            title: 'Logout',
            subtitle: 'Sign out of your account',
            icon: Icons.logout_rounded,
            iconColor: Colors.red,
            onTap: _logout,
          ),

          // SUPPORT
          _buildSectionHeader('Support', Icons.help_rounded),
          _buildListTile(
            title: 'Help & Support',
            subtitle: 'Get help and contact support',
            icon: Icons.help_outline_rounded,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.support_agent_rounded, color: Color(0xFF1E40AF)),
                      SizedBox(width: 12),
                      Text('Help & Support'),
                    ],
                  ),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📧 Email: support@safehorizon.com'),
                      SizedBox(height: 12),
                      Text('📞 Emergency: 112'),
                      SizedBox(height: 12),
                      Text('🌐 Website: www.safehorizon.com'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          _buildListTile(
            title: 'About',
            subtitle: 'App version and information',
            icon: Icons.info_outline_rounded,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.shield_rounded, color: Color(0xFF1E40AF)),
                      SizedBox(width: 12),
                      Text('About SafeHorizon'),
                    ],
                  ),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SafeHorizon',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('Version: 1.0.0'),
                      SizedBox(height: 12),
                      Text('Tourist Safety Platform'),
                      SizedBox(height: 12),
                      Text(
                        'Real-time tracking, emergency alerts, and safety monitoring for tourists.',
                        style: TextStyle(fontSize: 13),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '© 2025 SafeHorizon. All rights reserved.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),
          
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            child: const Column(
              children: [
                Text(
                  'SafeHorizon Tourist Safety Platform',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
