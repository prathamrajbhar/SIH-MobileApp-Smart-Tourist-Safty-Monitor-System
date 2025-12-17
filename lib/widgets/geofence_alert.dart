import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../models/alert.dart';
import '../services/geofencing_service.dart';

class GeofenceAlertDialog extends StatefulWidget {
  final RestrictedZone zone;
  final GeofenceEventType eventType;

  const GeofenceAlertDialog({
    super.key,
    required this.zone,
    required this.eventType,
  });

  static Future<void> show(
    BuildContext context, 
    RestrictedZone zone, 
    GeofenceEventType eventType,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GeofenceAlertDialog(
        zone: zone,
        eventType: eventType,
      ),
    );
  }

  @override
  State<GeofenceAlertDialog> createState() => _GeofenceAlertDialogState();
}

class _GeofenceAlertDialogState extends State<GeofenceAlertDialog> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _animationController.forward();
    
    // Auto-dismiss after 5 seconds
    if (widget.eventType == GeofenceEventType.exit) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getZoneColor() {
    switch (widget.zone.type) {
      case ZoneType.dangerous:
        return Colors.red.shade700;
      case ZoneType.highRisk:
        return Colors.orange.shade700;
      case ZoneType.restricted:
        return Colors.amber.shade700;
      case ZoneType.caution:
        return Colors.blue.shade600;
      case ZoneType.safe:
        return Colors.green.shade600;
    }
  }

  IconData _getZoneIcon() {
    switch (widget.zone.type) {
      case ZoneType.dangerous:
        return Icons.dangerous;
      case ZoneType.highRisk:
        return Icons.warning;
      case ZoneType.restricted:
        return Icons.do_not_disturb;
      case ZoneType.caution:
        return Icons.info;
      case ZoneType.safe:
        return Icons.check_circle;
    }
  }

  String _getEventTitle() {
    if (widget.eventType == GeofenceEventType.exit) {
      return "Safe Zone";
    }
    
    switch (widget.zone.type) {
      case ZoneType.dangerous:
        return "⚠️ DANGER ZONE";
      case ZoneType.highRisk:
        return "⚠️ HIGH RISK AREA";
      case ZoneType.restricted:
        return "🚫 RESTRICTED AREA";
      case ZoneType.caution:
        return "ℹ️ CAUTION AREA";
      case ZoneType.safe:
        return "✅ SAFE AREA";
    }
  }

  String _getEventMessage() {
    if (widget.eventType == GeofenceEventType.exit) {
      return "You have safely left the restricted area: ${widget.zone.name}";
    }
    
    return (widget.zone.warningMessage?.isNotEmpty ?? false)
        ? widget.zone.warningMessage!
        : "You have entered: ${widget.zone.name}";
  }

  Widget _buildPulsatingIcon() {
    if (widget.eventType == GeofenceEventType.exit) {
      return Icon(
        Icons.check_circle,
        size: 48,
        color: Colors.green.shade600,
      );
    }
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (0.2 * _animationController.value),
          child: Icon(
            _getZoneIcon(),
            size: 48,
            color: _getZoneColor(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExit = widget.eventType == GeofenceEventType.exit;
    final bgColor = isExit ? Colors.green.shade50 : Colors.red.shade50;
    final borderColor = isExit ? Colors.green.shade200 : _getZoneColor().withValues(alpha: 0.3);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: AlertDialog(
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 2),
        ),
        content: Container(
          width: double.maxFinite,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isExit ? Colors.green.shade100 : _getZoneColor().withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    _buildPulsatingIcon(),
                    const SizedBox(height: 12),
                    Text(
                      _getEventTitle(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isExit ? Colors.green.shade800 : _getZoneColor(),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      widget.zone.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getEventMessage(),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    if (!isExit) ...[
                      // Safety recommendations for entry
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.yellow.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb,
                              size: 20,
                              color: Colors.yellow.shade700,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "Stay alert and consider leaving this area if possible.",
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Actions
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                child: Row(
                  children: [
                    if (!isExit) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            // Trigger additional vibration
                            if (await Vibration.hasVibrator()) {
                              await Vibration.vibrate(duration: 200);
                            }
                            if (mounted) Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.vibration, size: 18),
                          label: const Text("Remind Me"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _getZoneColor(),
                            side: BorderSide(color: _getZoneColor()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isExit ? Colors.green.shade600 : _getZoneColor(),
                          foregroundColor: Colors.white,
                          elevation: 2,
                        ),
                        child: Text(isExit ? "Got it" : "Understood"),
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
}

class GeofenceIndicator extends StatelessWidget {
  final List<RestrictedZone> currentZones;
  final VoidCallback? onTap;

  const GeofenceIndicator({
    super.key,
    required this.currentZones,
    this.onTap,
  });

  Color _getHighestRiskColor() {
    if (currentZones.isEmpty) return Colors.green;
    
    ZoneType highestRisk = ZoneType.safe;
    for (final zone in currentZones) {
      switch (zone.type) {
        case ZoneType.dangerous:
          return Colors.red.shade700;
        case ZoneType.highRisk:
          if (highestRisk != ZoneType.dangerous) highestRisk = ZoneType.highRisk;
          break;
        case ZoneType.restricted:
          if (highestRisk == ZoneType.caution || highestRisk == ZoneType.safe) highestRisk = ZoneType.restricted;
          break;
        case ZoneType.caution:
          if (highestRisk == ZoneType.safe) highestRisk = ZoneType.caution;
          break;
        case ZoneType.safe:
          break;
      }
    }
    
    switch (highestRisk) {
      case ZoneType.dangerous:
        return Colors.red.shade700;
      case ZoneType.highRisk:
        return Colors.orange.shade700;
      case ZoneType.restricted:
        return Colors.amber.shade700;
      case ZoneType.caution:
        return Colors.blue.shade600;
      case ZoneType.safe:
        return Colors.green.shade600;
    }
  }

  String _getStatusText() {
    if (currentZones.isEmpty) return "Safe Area";
    if (currentZones.length == 1) return "In ${currentZones.first.name}";
    return "In ${currentZones.length} zones";
  }

  @override
  Widget build(BuildContext context) {
    final color = _getHighestRiskColor();
    final isInZone = currentZones.isNotEmpty;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isInZone ? color.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isInZone ? color : Colors.green,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isInZone ? Icons.warning : Icons.check_circle,
                key: ValueKey(isInZone),
                size: 16,
                color: isInZone ? color : Colors.green,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _getStatusText(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isInZone ? color : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
