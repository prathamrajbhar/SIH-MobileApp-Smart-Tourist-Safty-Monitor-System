import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tourist.dart';
import '../services/location_service.dart';
import '../screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Tourist tourist;

  const ProfileScreen({
    super.key,
    required this.tourist,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
  final LocationService _locationService = LocationService();
  Map<String, dynamic> _locationSettings = {};
  bool _isLoadingLocationSettings = true;

  @override
  void initState() {
    super.initState();
    _loadLocationSettings();
  }

  Future<void> _loadLocationSettings() async {
    try {
      final settings = await _locationService.getLocationSettings();
      setState(() {
        _locationSettings = settings;
        _isLoadingLocationSettings = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingLocationSettings = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await _showLogoutConfirmation();
    if (!confirmed) return;

    try {
      // Stop location tracking
      await _locationService.stopTracking();
      
      // Clear user data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Navigate to login screen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showLogoutConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout? This will stop location tracking.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  bool get wantKeepAlive => true; // Keep screen alive when switching tabs

  @override
  Widget build(BuildContext context) {
    super.build(context); // Must call super when using AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        shadowColor: Colors.black12,
        scrolledUnderElevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(24),
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
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E40AF), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E40AF).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      widget.tourist.name.isNotEmpty 
                          ? widget.tourist.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Name
                Text(
                  widget.tourist.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Tourist ID
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'ID: ${widget.tourist.id}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Contact Information
          Container(
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
                const Text(
                  'Contact Information',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.tourist.phone != null) ...[
                  _buildInfoRow(
                    icon: Icons.phone_rounded,
                    label: 'Phone',
                    value: '+91 ${widget.tourist.phone}',
                  ),
                  const SizedBox(height: 12),
                ],
                _buildInfoRow(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  value: widget.tourist.email,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Registered',
                  value: widget.tourist.registrationDate != null
                      ? '${widget.tourist.registrationDate!.day}/${widget.tourist.registrationDate!.month}/${widget.tourist.registrationDate!.year}'
                      : 'Today',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Location Settings
          Container(
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
                const Text(
                  'Location Settings',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoadingLocationSettings)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  _buildInfoRow(
                    icon: Icons.location_on_rounded,
                    label: 'Location Service',
                    value: _locationSettings['serviceEnabled'] == true ? 'Enabled' : 'Disabled',
                    valueColor: _locationSettings['serviceEnabled'] == true ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.security_rounded,
                    label: 'Permission',
                    value: _locationSettings['permission']?.toString().split('.').last ?? 'Unknown',
                    valueColor: _locationSettings['permission']?.toString().contains('granted') == true ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.track_changes_rounded,
                    label: 'Tracking',
                    value: _locationSettings['isTracking'] == true ? 'Active' : 'Inactive',
                    valueColor: _locationSettings['isTracking'] == true ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Logout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
