import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tourist.dart';
import '../theme/app_theme.dart';
import '../screens/location_history_screen.dart';
import '../screens/emergency_contacts_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/efir_form_screen.dart';
import '../screens/trip_monitor_screen_professional.dart';

import '../screens/notification_screen.dart';
import '../screens/login_screen.dart';

class ModernSidebar extends StatelessWidget {
  final Tourist tourist;
  final Function(Widget) onNavigate;

  const ModernSidebar({
    super.key,
    required this.tourist,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(child: _buildNavigationItems(context)),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: AppElevation.shadowMd,
            ),
            child: Center(
              child: Text(
                tourist.name.isNotEmpty ? tourist.name[0].toUpperCase() : '?',
                style: AppTypography.displayMedium.copyWith(
                  color: AppColors.textOnPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            tourist.name,
            style: AppTypography.headingSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Text(
              'ID: ${tourist.id}',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItems(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      children: [
        _buildItem(
          context,
          Icons.notifications_rounded,
          'Notifications',
          NotificationScreen(
            touristId: tourist.id,
            initialAlerts: const [],
          ),
        ),
        _buildItem(
          context,
          Icons.description_rounded,
          'File E-FIR',
          EFIRFormScreen(tourist: tourist),
        ),
        _buildItem(
          context,
          Icons.monitor_heart_rounded,
          'Trip Monitor',
          const TripMonitorScreen(),
        ),
        _buildItem(
          context,
          Icons.location_history_rounded,
          'Location History',
          const LocationHistoryScreen(),
        ),
        _buildItem(
          context,
          Icons.contacts_rounded,
          'Emergency Contacts',
          const EmergencyContactsScreen(),
        ),
        _buildItem(
          context,
          Icons.settings_rounded,
          'Settings',
          const SettingsScreen(),
        ),
      ],
    );
  }

  Widget _buildItem(
    BuildContext context,
    IconData icon,
    String title,
    Widget screen,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(
          icon,
          color: AppColors.textSecondary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textTertiary,
        size: 20,
      ),
      onTap: () => onNavigate(screen),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _showLogoutDialog(context),
            borderRadius: BorderRadius.circular(AppRadius.button),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(color: AppColors.error, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Logout',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'SafeHorizon v1.0.0',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        backgroundColor: AppColors.surface,
        title: Text(
          'Logout',
          style: AppTypography.headingMedium,
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: textButtonStyle,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              }
            },
            style: dangerButtonStyle,
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
