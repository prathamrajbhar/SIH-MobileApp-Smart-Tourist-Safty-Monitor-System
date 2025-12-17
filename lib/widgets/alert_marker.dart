import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/alert.dart';

/// Custom marker widget for displaying unresolved alerts on the map
/// These markers persist until the alert is resolved by authorities
class AlertMarker extends StatelessWidget {
  final Alert alert;
  final VoidCallback? onTap;

  const AlertMarker({
    super.key,
    required this.alert,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getAlertColor(alert.type, alert.severity),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _getAlertColor(alert.type, alert.severity).withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          _getAlertIcon(alert.type),
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  /// Get color based on alert type and severity
  Color _getAlertColor(AlertType type, AlertSeverity severity) {
    switch (type) {
      case AlertType.sos:
        return Colors.red.shade600; // Critical red for SOS
      case AlertType.emergency:
        return severity == AlertSeverity.critical 
            ? Colors.red.shade700 
            : Colors.orange.shade600;
      case AlertType.safety:
        return severity == AlertSeverity.high 
            ? Colors.orange.shade600 
            : Colors.yellow.shade600;
      case AlertType.geofence:
        return Colors.purple.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  /// Get icon based on alert type
  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.sos:
        return Icons.emergency;
      case AlertType.emergency:
        return Icons.warning;
      case AlertType.safety:
        return Icons.shield;
      case AlertType.geofence:
        return Icons.location_off;
      default:
        return Icons.info;
    }
  }
}

/// Creates map markers for a list of unresolved alerts
class AlertMarkerBuilder {
  /// Build markers for unresolved alerts
  static List<Marker> buildAlertMarkers(
    List<Alert> alerts, {
    required Function(Alert) onAlertTap,
  }) {
    return alerts
        .where((alert) => alert.latitude != null && alert.longitude != null)
        .map((alert) {
      return Marker(
        point: LatLng(alert.latitude!, alert.longitude!),
        width: 40,
        height: 40,
        child: AlertMarker(
          alert: alert,
          onTap: () => onAlertTap(alert),
        ),
      );
    }).toList();
  }

  /// Build a single marker for an alert
  static Marker buildSingleAlertMarker(
    Alert alert, {
    required VoidCallback onTap,
  }) {
    // Only create marker if location is available
    if (alert.latitude == null || alert.longitude == null) {
      throw ArgumentError('Alert must have valid latitude and longitude');
    }
    
    return Marker(
      point: LatLng(alert.latitude!, alert.longitude!),
      width: 40,
      height: 40,
      child: AlertMarker(
        alert: alert,
        onTap: onTap,
      ),
    );
  }
}

/// Alert detail popup shown when user taps on an alert marker
class AlertDetailPopup extends StatelessWidget {
  final Alert alert;
  final VoidCallback onClose;

  const AlertDetailPopup({
    super.key,
    required this.alert,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeAgo = _formatTimeAgo(alert.createdAt);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with alert type and close button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getAlertColor(alert.type, alert.severity),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getAlertIcon(alert.type),
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getAlertTypeLabel(alert.type),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Alert title
          Text(
            alert.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Alert description
          Text(
            alert.description,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          
          // Time and status info
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: theme.textTheme.bodySmall?.color,
              ),
              const SizedBox(width: 4),
              Text(
                timeAgo,
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'UNRESOLVED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getAlertColor(AlertType type, AlertSeverity severity) {
    switch (type) {
      case AlertType.sos:
        return Colors.red.shade600;
      case AlertType.emergency:
        return severity == AlertSeverity.critical 
            ? Colors.red.shade700 
            : Colors.orange.shade600;
      case AlertType.safety:
        return severity == AlertSeverity.high 
            ? Colors.orange.shade600 
            : Colors.yellow.shade600;
      case AlertType.geofence:
        return Colors.purple.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.sos:
        return Icons.emergency;
      case AlertType.emergency:
        return Icons.warning;
      case AlertType.safety:
        return Icons.shield;
      case AlertType.geofence:
        return Icons.location_off;
      default:
        return Icons.info;
    }
  }

  String _getAlertTypeLabel(AlertType type) {
    switch (type) {
      case AlertType.sos:
        return 'SOS';
      case AlertType.emergency:
        return 'EMERGENCY';
      case AlertType.safety:
        return 'SAFETY';
      case AlertType.geofence:
        return 'RESTRICTED';
      default:
        return 'ALERT';
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}