import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/geospatial_heat.dart';

/// Animated pulsing layer for recent panic alerts on map
/// Shows real-time emergency alerts with privacy protection (aggregated locations only)
class PanicAlertPulseLayer extends StatefulWidget {
  final List<GeospatialHeatPoint> panicAlerts;
  final MapCamera camera;

  const PanicAlertPulseLayer({
    super.key,
    required this.panicAlerts,
    required this.camera,
  });

  @override
  State<PanicAlertPulseLayer> createState() => _PanicAlertPulseLayerState();
}

class _PanicAlertPulseLayerState extends State<PanicAlertPulseLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.panicAlerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _PanicAlertPulsePainter(
            panicAlerts: widget.panicAlerts,
            camera: widget.camera,
            animationValue: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _PanicAlertPulsePainter extends CustomPainter {
  final List<GeospatialHeatPoint> panicAlerts;
  final MapCamera camera;
  final double animationValue;

  _PanicAlertPulsePainter({
    required this.panicAlerts,
    required this.camera,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final alert in panicAlerts) {
      final point = _projectToScreen(alert.latitude, alert.longitude, size);
      if (point != null) {
        _drawPulsingAlert(canvas, point, alert);
      }
    }
  }

  Offset? _projectToScreen(double latitude, double longitude, Size size) {
    try {
      final latLng = LatLng(latitude, longitude);
      final bounds = camera.visibleBounds;
      
      // Check if point is visible
      if (!bounds.contains(latLng)) {
        return null;
      }
      
      final latRange = bounds.north - bounds.south;
      final lngRange = bounds.east - bounds.west;
      
      final x = ((latLng.longitude - bounds.west) / lngRange) * size.width;
      final y = ((bounds.north - latLng.latitude) / latRange) * size.height;
      
      return Offset(x, y);
    } catch (e) {
      return null;
    }
  }

  void _drawPulsingAlert(Canvas canvas, Offset center, GeospatialHeatPoint alert) {
    // Outer pulsing circle (expanding and fading)
    final pulseRadius = 30.0 + (animationValue * 40.0);
    final pulseOpacity = (1.0 - animationValue) * 0.4;
    
    final pulsePaint = Paint()
      ..color = Colors.red.withOpacity(pulseOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    canvas.drawCircle(center, pulseRadius, pulsePaint);
    
    // Middle pulse (slightly delayed)
    final midValue = (animationValue - 0.2).clamp(0.0, 1.0);
    if (midValue > 0) {
      final midRadius = 25.0 + (midValue * 35.0);
      final midOpacity = (1.0 - midValue) * 0.5;
      
      final midPaint = Paint()
        ..color = Colors.red.withOpacity(midOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      
      canvas.drawCircle(center, midRadius, midPaint);
    }
    
    // Inner solid circle (always visible, slight pulse)
    final innerScale = 1.0 + (animationValue * 0.2);
    final innerRadius = 16.0 * innerScale;
    
    // Glow effect
    final glowPaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawCircle(center, innerRadius + 4, glowPaint);
    
    // Solid circle with gradient
    final solidPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.red.shade300,
          Colors.red.shade700,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: innerRadius));
    canvas.drawCircle(center, innerRadius, solidPaint);
    
    // Emergency icon
    final iconPainter = TextPainter(
      text: const TextSpan(
        text: '🚨',
        style: TextStyle(
          fontSize: 18,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    iconPainter.paint(
      canvas,
      Offset(
        center.dx - iconPainter.width / 2,
        center.dy - iconPainter.height / 2,
      ),
    );
    
    // Alert count badge (if multiple alerts aggregated)
    if (alert.alertCount > 1) {
      _drawAlertCountBadge(canvas, center, alert.alertCount);
    }
  }

  void _drawAlertCountBadge(Canvas canvas, Offset center, int count) {
    final badgeRadius = 10.0;
    final badgeCenter = Offset(center.dx + 15, center.dy - 15);
    
    // Badge background
    final badgePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(badgeCenter, badgeRadius, badgePaint);
    
    // Badge border
    final borderPaint = Paint()
      ..color = Colors.red.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(badgeCenter, badgeRadius, borderPaint);
    
    // Count text
    final textPainter = TextPainter(
      text: TextSpan(
        text: count > 99 ? '99+' : count.toString(),
        style: TextStyle(
          color: Colors.red.shade700,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    textPainter.paint(
      canvas,
      Offset(
        badgeCenter.dx - textPainter.width / 2,
        badgeCenter.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_PanicAlertPulsePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.panicAlerts != panicAlerts ||
           oldDelegate.camera != camera;
  }
}
