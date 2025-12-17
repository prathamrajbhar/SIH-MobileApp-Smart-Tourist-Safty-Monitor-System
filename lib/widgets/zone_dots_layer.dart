import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/geospatial_heat.dart';

/// Clean zone visualization with small circular dots
/// Shows zones and their influence area that moves with map
/// Now interactive - tap on dots to see zone information
class ZoneDotsLayer extends StatelessWidget {
  final List<GeospatialHeatPoint> heatPoints;
  final double dotSize;
  final double influenceRadiusKm;
  final bool visible;
  final Function(GeospatialHeatPoint)? onZoneTap;

  const ZoneDotsLayer({
    super.key,
    required this.heatPoints,
    this.dotSize = 12.0,
    this.influenceRadiusKm = 30.0,
    this.visible = true,
    this.onZoneTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || heatPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTapDown: (details) {
        final camera = MapCamera.of(context);
        final tappedZone = _findTappedZone(
          details.localPosition,
          camera,
          MediaQuery.of(context).size,
        );
        
        if (tappedZone != null && onZoneTap != null) {
          onZoneTap!(tappedZone);
        }
      },
      child: StreamBuilder<MapEvent>(
        stream: MapController.maybeOf(context)?.mapEventStream ?? const Stream.empty(),
        builder: (context, snapshot) {
          final camera = MapCamera.of(context);
          
          return CustomPaint(
            painter: _ZoneDotsPainter(
              camera: camera,
              heatPoints: heatPoints,
              dotSize: dotSize,
              influenceRadiusKm: influenceRadiusKm,
            ),
            size: Size.infinite,
            isComplex: true,
            willChange: true,
          );
        },
      ),
    );
  }

  GeospatialHeatPoint? _findTappedZone(
    Offset tapPosition,
    MapCamera camera,
    Size size,
  ) {
    // Filter visible points
    final visiblePoints = heatPoints.where((point) {
      final projected = _projectToScreen(
        LatLng(point.latitude, point.longitude),
        camera,
        size,
      );
      if (projected == null) return false;
      
      final padding = dotSize * 3;
      return projected.dx >= -padding && 
             projected.dx <= size.width + padding &&
             projected.dy >= -padding && 
             projected.dy <= size.height + padding;
    }).toList();

    // Sort by intensity (high to low) for proper tap priority
    visiblePoints.sort((a, b) => b.intensity.compareTo(a.intensity));

    // Find which zone was tapped
    for (final point in visiblePoints) {
      final projected = _projectToScreen(
        LatLng(point.latitude, point.longitude),
        camera,
        size,
      );
      
      if (projected == null) continue;

      // Check if tap is within dot area (considering intensity-based sizing)
      final intensityScale = (0.8 + (point.intensity * 0.4)).clamp(0.8, 1.2);
      final effectiveDotSize = dotSize * intensityScale;
      final tapRadius = effectiveDotSize * 0.8; // Slightly larger for easier tapping
      
      final distance = (tapPosition - projected).distance;
      
      if (distance <= tapRadius) {
        return point;
      }
    }

    return null;
  }

  Offset? _projectToScreen(LatLng latLng, MapCamera camera, Size size) {
    try {
      final bounds = camera.visibleBounds;
      
      final latRange = bounds.north - bounds.south;
      final lngRange = bounds.east - bounds.west;
      
      final x = ((latLng.longitude - bounds.west) / lngRange) * size.width;
      final y = ((bounds.north - latLng.latitude) / latRange) * size.height;
      
      return Offset(x, y);
    } catch (e) {
      return null;
    }
  }
}

class _ZoneDotsPainter extends CustomPainter {
  final MapCamera camera;
  final List<GeospatialHeatPoint> heatPoints;
  final double dotSize;
  final double influenceRadiusKm;

  _ZoneDotsPainter({
    required this.camera,
    required this.heatPoints,
    required this.dotSize,
    required this.influenceRadiusKm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (heatPoints.isEmpty) return;

    // Filter visible points only
    final visiblePoints = heatPoints.where((point) {
      final projected = _projectToScreen(LatLng(point.latitude, point.longitude), size);
      if (projected == null) return false;
      
      final padding = dotSize * 3;
      return projected.dx >= -padding && 
             projected.dx <= size.width + padding &&
             projected.dy >= -padding && 
             projected.dy <= size.height + padding;
    }).toList();

    // Sort by intensity (low to high) so high-intensity zones draw on top
    visiblePoints.sort((a, b) => a.intensity.compareTo(b.intensity));

    // First, draw influence circles (30km radius) with light transparency
    for (final point in visiblePoints) {
      _paintInfluenceCircle(canvas, size, point);
    }

    // Then, draw the dots on top
    for (final point in visiblePoints) {
      _paintZoneDot(canvas, size, point);
    }
  }

  void _paintInfluenceCircle(Canvas canvas, Size size, GeospatialHeatPoint point) {
    final latLng = LatLng(point.latitude, point.longitude);
    final projected = _projectToScreen(latLng, size);
    if (projected == null) return;

    // Calculate influence radius in screen pixels (scale with zoom)
    final zoom = camera.zoom;
    final radiusPixels = _kmToPixels(influenceRadiusKm, point.latitude);
    
    // Skip if circle is too large (low zoom) or completely outside
    if (radiusPixels > size.width || radiusPixels > size.height) {
      return; // Circle too big, skip to reduce clutter
    }
    
    final padding = radiusPixels;
    if (projected.dx < -padding || projected.dx > size.width + padding ||
        projected.dy < -padding || projected.dy > size.height + padding) {
      return;
    }

    final color = _getZoneColor(point.type, point.intensity);
    
    // Better opacity: higher intensity = more visible
    // Scale opacity with zoom level for clarity
    final baseOpacity = (point.intensity * 0.12).clamp(0.03, 0.20);
    final zoomFactor = (zoom / 15.0).clamp(0.5, 1.5);
    final opacity = (baseOpacity * zoomFactor).clamp(0.02, 0.25);

    // Draw influence circle with radial gradient for smoother look
    final gradient = RadialGradient(
      colors: [
        color.withValues(alpha: opacity * 0.8),
        color.withValues(alpha: opacity * 0.4),
        color.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.7, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(
        center: projected,
        radius: radiusPixels,
      ))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(projected, radiusPixels, paint);
  }

  void _paintZoneDot(Canvas canvas, Size size, GeospatialHeatPoint point) {
    final latLng = LatLng(point.latitude, point.longitude);
    final projected = _projectToScreen(latLng, size);
    if (projected == null) return;

    // Skip if dot is outside visible area with small padding
    final padding = dotSize * 2;
    if (projected.dx < -padding || projected.dx > size.width + padding ||
        projected.dy < -padding || projected.dy > size.height + padding) {
      return;
    }

    final color = _getZoneColor(point.type, point.intensity);
    
    // Scale dot size based on intensity for better visual hierarchy
    final intensityScale = (0.8 + (point.intensity * 0.4)).clamp(0.8, 1.2);
    final effectiveDotSize = dotSize * intensityScale;
    
    // Draw outer glow (stronger for high intensity)
    final glowAlpha = (0.2 + (point.intensity * 0.3)).clamp(0.2, 0.5);
    final glowPaint = Paint()
      ..color = color.withValues(alpha: glowAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(projected, effectiveDotSize * 0.9, glowPaint);

    // Draw shadow for depth
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(projected.translate(0.5, 0.5), effectiveDotSize * 0.65, shadowPaint);

    // Draw main dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(projected, effectiveDotSize * 0.6, dotPaint);

    // Draw white border for contrast (thicker for high intensity)
    final borderWidth = (1.5 + (point.intensity * 0.5)).clamp(1.5, 2.0);
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawCircle(projected, effectiveDotSize * 0.6, borderPaint);

    // Draw inner highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5);
    canvas.drawCircle(projected, effectiveDotSize * 0.25, highlightPaint);
  }

  Offset? _projectToScreen(LatLng latLng, Size size) {
    try {
      final bounds = camera.visibleBounds;
      
      final latRange = bounds.north - bounds.south;
      final lngRange = bounds.east - bounds.west;
      
      final x = ((latLng.longitude - bounds.west) / lngRange) * size.width;
      final y = ((bounds.north - latLng.latitude) / latRange) * size.height;
      
      return Offset(x, y);
    } catch (e) {
      return null;
    }
  }

  double _kmToPixels(double km, double latitude) {
    // Convert km to degrees at this latitude
    final latRad = latitude * math.pi / 180.0;
    final kmPerDegreeLat = 111.0; // Approximate
    final kmPerDegreeLng = 111.0 * math.cos(latRad);
    
    // Average between lat and lng for circular appearance
    final avgKmPerDegree = (kmPerDegreeLat + kmPerDegreeLng) / 2;
    final degrees = km / avgKmPerDegree;
    
    // Convert degrees to pixels based on current zoom
    final zoom = camera.zoom;
    final pixelsPerDegree = 256 * math.pow(2, zoom) / 360;
    
    return degrees * pixelsPerDegree;
  }

  Color _getZoneColor(HeatPointType type, double intensity) {
    // Intensify color based on intensity value
    if (intensity > 0.8) {
      return const Color(0xFFD32F2F); // Bright red - dangerous
    } else if (intensity > 0.6) {
      return const Color(0xFFFF5722); // Deep orange - risky
    } else if (intensity > 0.4) {
      return const Color(0xFFFF9800); // Orange - caution
    } else {
      return const Color(0xFFFFC107); // Yellow - mild
    }
  }

  @override
  bool shouldRepaint(_ZoneDotsPainter oldDelegate) {
    // Always repaint if camera has changed (position, zoom, rotation)
    final cameraChanged = oldDelegate.camera.center != camera.center ||
                          oldDelegate.camera.zoom != camera.zoom ||
                          oldDelegate.camera.rotation != camera.rotation;
    
    return cameraChanged ||
           oldDelegate.heatPoints != heatPoints ||
           oldDelegate.dotSize != dotSize ||
           oldDelegate.influenceRadiusKm != influenceRadiusKm;
  }
}
