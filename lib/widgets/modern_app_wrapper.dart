import 'package:flutter/material.dart';
import '../models/tourist.dart';
import '../theme/app_theme.dart';
import '../screens/home_screen.dart';
import '../screens/map_screen.dart';
import '../screens/broadcast_screen.dart';
import '../screens/profile_screen.dart';
import 'modern_sidebar.dart';

class ModernAppWrapper extends StatefulWidget {
  final Tourist tourist;
  final int initialIndex;

  const ModernAppWrapper({
    super.key,
    required this.tourist,
    this.initialIndex = 0,
  });

  @override
  State<ModernAppWrapper> createState() => _ModernAppWrapperState();
}

class _ModernAppWrapperState extends State<ModernAppWrapper> with SingleTickerProviderStateMixin {
  late int _currentIndex;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Pre-create all screens once to keep them alive
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    
    // Create all screens once and keep them alive
    _screens = [
      HomeScreen(
        tourist: widget.tourist,
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      MapScreen(tourist: widget.tourist),
      const BroadcastScreen(),
      ProfileScreen(tourist: widget.tourist),
    ];
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void dispose() {
    // Screens are disposed automatically by IndexedStack
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: ModernSidebar(
        tourist: widget.tourist,
        onNavigate: (screen) {
          // Close drawer
          Navigator.of(context).pop();
          
          // Navigate to screen using Navigator.push for additional screens
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => screen),
          );
        },
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              offset: const Offset(0, -2),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onBottomNavTap,
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.surface,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textTertiary,
            selectedLabelStyle: AppTypography.labelSmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: AppTypography.labelSmall,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded, size: 24),
                activeIcon: Icon(Icons.home_rounded, size: 26),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map_rounded, size: 24),
                activeIcon: Icon(Icons.map_rounded, size: 26),
                label: 'Map',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.campaign_rounded, size: 24),
                activeIcon: Icon(Icons.campaign_rounded, size: 26),
                label: 'Alerts',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded, size: 24),
                activeIcon: Icon(Icons.person_rounded, size: 26),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
