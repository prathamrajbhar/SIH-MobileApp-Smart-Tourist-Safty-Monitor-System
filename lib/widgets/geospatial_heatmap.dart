import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/geospatial_heat.dart';

/// Professional geospatial heatmap layer for flutter_map
/// Renders smooth heat visualization based on panic alerts and restricted zones
class GeospatialHeatmapLayer extends StatelessWidget {
  final List<GeospatialHeatPoint> heatPoints;
  final HeatmapConfig config;
  final bool visible;

  const GeospatialHeatmapLayer({
    super.key,
    required this.heatPoints,
    this.config = const HeatmapConfig(),
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || heatPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: RepaintBoundary(
        child: Builder(
          builder: (context) {
            try {
              final mapController = MapController.maybeOf(context);
              if (mapController == null) {
                return const SizedBox.shrink();
              }
              
              final camera = mapController.camera;
              
              return CustomPaint(
                painter: _GeospatialHeatmapPainter(
                  camera: camera,
                  heatPoints: heatPoints,
                  config: config,
                ),
                size: Size.infinite,
              );
            } catch (e) {
              // If MapController is not available yet, return empty widget
              return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }
}

class _GeospatialHeatmapPainter extends CustomPainter {
  final MapCamera camera;
  final List<GeospatialHeatPoint> heatPoints;
  final HeatmapConfig config;

  _GeospatialHeatmapPainter({
    required this.camera,
    required this.heatPoints,
    required this.config,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final filteredPoints = heatPoints
        .where((point) => config.visibleTypes.contains(point.type))
        .take(config.maxPoints)
        .toList();

    if (filteredPoints.isEmpty) return;

    // Calculate effective radius based on zoom
    final zoom = camera.zoom;
    final zoomScale = math.pow(2.0, zoom - 15.0);
    final effectiveRadius = (config.baseRadius * zoomScale).clamp(30.0, 200.0);

    // Group nearby points to avoid over-cluttering
    final processedPoints = _groupNearbyPoints(filteredPoints, effectiveRadius / 4);

    for (final point in processedPoints) {
      _paintHeatPoint(canvas, size, point, effectiveRadius);
    }
  }

  void _paintHeatPoint(Canvas canvas, Size size, GeospatialHeatPoint point, double radius) {
    final latLng = LatLng(point.latitude, point.longitude);
    
    // Convert to screen coordinates using flutter_map's projection
    final projected = _projectToScreen(latLng, size);
    if (projected == null) return;

    // Skip if point is outside visible area with padding
    final padding = radius * 2;
    if (projected.dx < -padding || projected.dx > size.width + padding ||
        projected.dy < -padding || projected.dy > size.height + padding) {
      return;
    }

    final intensity = point.intensity.clamp(0.0, 1.0);
    final opacity = (config.minOpacity + (config.maxOpacity - config.minOpacity) * intensity).clamp(0.0, 1.0);
    
    // Get color based on heat point type and intensity
    final color = _getHeatColor(point.type, intensity);
    
    // Create smooth radial gradient
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacity * 0.9),
          color.withValues(alpha: opacity * 0.6),
          color.withValues(alpha: opacity * 0.3),
          color.withValues(alpha: opacity * 0.1),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(Rect.fromCircle(
        center: projected,
        radius: radius,
      ))
      ..blendMode = BlendMode.screen; // Use screen blend for additive effect

    canvas.drawCircle(projected, radius, paint);
  }

  Offset? _projectToScreen(LatLng latLng, Size size) {
    try {
      // Use flutter_map's camera to project coordinates
      final bounds = camera.visibleBounds;
      
      // Simple linear projection within visible bounds
      final latRange = bounds.north - bounds.south;
      final lngRange = bounds.east - bounds.west;
      
      final x = ((latLng.longitude - bounds.west) / lngRange) * size.width;
      final y = ((bounds.north - latLng.latitude) / latRange) * size.height;
      
      return Offset(x, y);
    } catch (e) {
      return null;
    }
  }

  Color _getHeatColor(HeatPointType type, double intensity) {
    switch (type) {
      case HeatPointType.panicAlert:
        return _interpolateColor(
          const Color(0xFF8E24AA), // Deep purple
          const Color(0xFFE91E63), // Pink/red
          intensity,
        );
      case HeatPointType.restrictedZone:
        return _interpolateColor(
          const Color(0xFF1565C0), // Blue
          const Color(0xFF00BCD4), // Cyan
          intensity,
        );
      case HeatPointType.safetyIncident:
        return _interpolateColor(
          const Color(0xFFFF6F00), // Orange
          const Color(0xFFFF5722), // Deep orange
          intensity,
        );
      case HeatPointType.general:
        return _interpolateColor(
          const Color(0xFF388E3C), // Green
          const Color(0xFF8BC34A), // Light green
          intensity,
        );
    }
  }

  Color _interpolateColor(Color startColor, Color endColor, double t) {
    return Color.lerp(startColor, endColor, t.clamp(0.0, 1.0)) ?? startColor;
  }

  List<GeospatialHeatPoint> _groupNearbyPoints(List<GeospatialHeatPoint> points, double threshold) {
    final grouped = <GeospatialHeatPoint>[];
    final processed = List<bool>.filled(points.length, false);

    for (int i = 0; i < points.length; i++) {
      if (processed[i]) continue;

      GeospatialHeatPoint current = points[i];
      processed[i] = true;

      // Find nearby points to merge
      for (int j = i + 1; j < points.length; j++) {
        if (processed[j]) continue;

        final distance = _calculateDistance(
          current.latitude, current.longitude,
          points[j].latitude, points[j].longitude,
        );

        if (distance < threshold) {
          current = current.mergeWith(points[j]);
          processed[j] = true;
        }
      }

      grouped.add(current);
    }

    return grouped;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
        math.cos(lat2 * math.pi / 180) *
        math.sin(dLon / 2) *
        math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  @override
  bool shouldRepaint(covariant _GeospatialHeatmapPainter oldDelegate) {
    return oldDelegate.heatPoints != heatPoints ||
        oldDelegate.camera.zoom != camera.zoom ||
        oldDelegate.camera.center != camera.center ||
        oldDelegate.config != config;
  }
}
