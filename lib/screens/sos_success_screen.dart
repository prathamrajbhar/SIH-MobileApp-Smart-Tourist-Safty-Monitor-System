import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tourist.dart';
import 'emergency_contacts_screen.dart';
import 'map_screen.dart';

class SOSSuccessScreen extends StatefulWidget {
  final Tourist tourist;

  const SOSSuccessScreen({
    super.key,
    required this.tourist,
  });

  @override
  State<SOSSuccessScreen> createState() => _SOSSuccessScreenState();
}

class _SOSSuccessScreenState extends State<SOSSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Success haptic feedback
    HapticFeedback.heavyImpact();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openMap() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MapScreen(tourist: widget.tourist),
      ),
    );
  }

  void _openEmergencyContacts() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EmergencyContactsScreen(),
      ),
    );
  }

  void _callPolice() {
    // In a real app, this would trigger a phone call
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚨 Calling emergency services...'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Success animation
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green.shade600,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              // Success message
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    const Text(
                      'SOS Alert Sent!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Emergency services have been notified with your location',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Safety options
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView(
                    children: [
                      const Text(
                        'Safety Options',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Emergency Call
                      _buildSafetyOption(
                        icon: Icons.phone,
                        title: 'Call Emergency Services',
                        subtitle: 'Direct call to police (100)',
                        color: Colors.red,
                        onTap: _callPolice,
                      ),
                      
                      // Share Location
                      _buildSafetyOption(
                        icon: Icons.share_location,
                        title: 'Share Live Location',
                        subtitle: 'View your location on map',
                        color: Colors.blue,
                        onTap: _openMap,
                      ),
                      
                      // Emergency Contacts
                      _buildSafetyOption(
                        icon: Icons.contacts,
                        title: 'Emergency Contacts',
                        subtitle: 'Call trusted contacts',
                        color: Colors.orange,
                        onTap: _openEmergencyContacts,
                      ),
                      
                      // Safety Tips
                      _buildSafetyOption(
                        icon: Icons.lightbulb_outline,
                        title: 'Safety Tips',
                        subtitle: 'Quick safety reminders',
                        color: Colors.purple,
                        onTap: _showSafetyTips,
                      ),
                      
                      // Find Safe Place
                      _buildSafetyOption(
                        icon: Icons.local_hospital,
                        title: 'Find Safe Places',
                        subtitle: 'Hospitals, police stations nearby',
                        color: Colors.teal,
                        onTap: _findSafePlaces,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Bottom actions
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _goHome,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Return to Home',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Help is on the way. Stay calm and safe.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSafetyTips() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Safety Tips'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('• Stay calm and find a safe, well-lit area'),
              SizedBox(height: 8),
              Text('• Keep your phone charged and within reach'),
              SizedBox(height: 8),
              Text('• Avoid isolated areas and stay in public spaces'),
              SizedBox(height: 8),
              Text('• Trust your instincts - if something feels wrong, act'),
              SizedBox(height: 8),
              Text('• Keep emergency contacts easily accessible'),
              SizedBox(height: 8),
              Text('• Share your location with trusted contacts'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _findSafePlaces() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.local_hospital, color: Colors.teal),
            SizedBox(width: 8),
            Text('Safe Places'),
          ],
        ),
        content: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Look for these safe places nearby:'),
            SizedBox(height: 12),
            Text('🏥 Hospitals and medical centers'),
            SizedBox(height: 8),
            Text('🚔 Police stations'),
            SizedBox(height: 8),
            Text('🏪 24/7 stores and shops'),
            SizedBox(height: 8),
            Text('🏨 Hotels and public buildings'),
            SizedBox(height: 8),
            Text('🚇 Transportation hubs'),
            SizedBox(height: 12),
            Text(
              'Tip: Use the map to locate these places near you.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Understood'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openMap();
            },
            child: const Text('Open Map'),
          ),
        ],
      ),
    );
  }
}