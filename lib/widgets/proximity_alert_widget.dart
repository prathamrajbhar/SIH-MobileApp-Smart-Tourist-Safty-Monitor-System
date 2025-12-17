import 'package:flutter/material.dart';
import '../services/proximity_alert_service.dart';
import '../theme/app_theme.dart';

/// Widget to display proximity alerts (panic alerts and restricted zones)
class ProximityAlertWidget extends StatelessWidget {
  final ProximityAlertEvent alert;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const ProximityAlertWidget({
    super.key,
    required this.alert,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          color: alert.severityColor,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: alert.severityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  alert.icon,
                  color: alert.severityColor,
                  size: 32,
                ),
              ),
              
              const SizedBox(width: AppSpacing.md),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      alert.title,
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.xxs),
                    
                    // Description
                    Text(
                      alert.description,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: AppSpacing.xs),
                    
                    // Distance badge
                    Row(
                      children: [
                        _buildBadge(
                          icon: Icons.location_on,
                          label: alert.distanceText,
                          color: alert.severityColor,
                        ),
                        
                        const SizedBox(width: AppSpacing.xs),
                        
                        _buildBadge(
                          icon: Icons.access_time,
                          label: _formatTimestamp(alert.timestamp),
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Dismiss button
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close),
                  color: AppColors.textTertiary,
                  iconSize: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Dialog to show proximity alert details
class ProximityAlertDialog extends StatelessWidget {
  final ProximityAlertEvent alert;

  const ProximityAlertDialog({
    super.key,
    required this.alert,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.dialog),
      ),
      title: Row(
        children: [
          Icon(
            alert.icon,
            color: alert.severityColor,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              alert.title,
              style: AppTypography.headingMedium,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: alert.severityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: alert.severityColor),
            ),
            child: Text(
              alert.severity.toUpperCase(),
              style: AppTypography.caption.copyWith(
                color: alert.severityColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Description
          Text(
            alert.description,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Details
          _buildDetailRow(
            icon: Icons.location_on,
            label: 'Distance',
            value: alert.distanceText,
          ),
          
          const SizedBox(height: AppSpacing.xs),
          
          _buildDetailRow(
            icon: Icons.access_time,
            label: 'Detected',
            value: _formatTimestamp(alert.timestamp),
          ),
          
          if (alert.type == ProximityAlertType.panicAlert) ...[
            const SizedBox(height: AppSpacing.xs),
            _buildDetailRow(
              icon: Icons.info_outline,
              label: 'Status',
              value: alert.metadata?['is_active'] == true ? 'Active (<1hr)' : 'Recent',
            ),
          ],
          
          const SizedBox(height: AppSpacing.md),
          
          // Safety tips
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    _getSafetyTip(),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Dismiss',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop('view_map');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: alert.severityColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
          ),
          child: Text(
            'View on Map',
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textTertiary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$label: ',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        Text(
          value,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _getSafetyTip() {
    if (alert.type == ProximityAlertType.panicAlert) {
      if (alert.distanceKm < 1.0) {
        return 'Stay alert! An emergency was reported very close to your location. Consider moving to a safer area or contacting local authorities.';
      }
      return 'Be aware of your surroundings. An emergency was reported nearby. Stay vigilant and avoid the area if possible.';
    } else {
      return 'You are approaching a restricted or dangerous zone. Please exercise caution and follow local safety guidelines.';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}
