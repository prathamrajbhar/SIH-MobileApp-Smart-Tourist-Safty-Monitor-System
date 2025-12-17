import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/geospatial_heat.dart';

/// Professional gradient-based heatmap layer
/// Uses smooth color gradients to visualize risk intensity
class HeatmapLayer extends StatelessWidget {
  final List<GeospatialHeatPoint> heatPoints;
  final double radiusKm;
  final double opacity;
  final bool visible;

  const HeatmapLayer({
    super.key,
    required this.heatPoints,
    this.radiusKm = 5.0,
    this.opacity = 0.6,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || heatPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    return Builder(
      builder: (context) {
        try {
          final mapController = MapController.maybeOf(context);
          if (mapController == null) {
            return const SizedBox.shrink();
          }
          
          return StreamBuilder<MapEvent>(
            stream: mapController.mapEventStream,
            builder: (context, snapshot) {
              final camera = MapCamera.of(context);
              
              return CustomPaint(
                painter: _HeatmapPainter(
                  camera: camera,
                  heatPoints: heatPoints,
                  radiusKm: radiusKm,
                  opacity: opacity,
                ),
                size: Size.infinite,
                isComplex: true,
                willChange: true,
              );
            },
          );
        } catch (e) {
          // If MapController is not available yet, return empty widget
          return const SizedBox.shrink();
        }
      },
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final MapCamera camera;
  final List<GeospatialHeatPoint> heatPoints;
  final double radiusKm;
  final double opacity;

  _HeatmapPainter({
    required this.camera,
    required this.heatPoints,
    required this.radiusKm,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (heatPoints.isEmpty) return;

    // Filter visible points
    final visiblePoints = heatPoints.where((point) {
      final projected = _projectToScreen(LatLng(point.latitude, point.longitude), size);
      if (projected == null) return false;
      
      final radiusPixels = _kmToPixels(radiusKm, point.latitude);
      final padding = radiusPixels * 1.5;
      return projected.dx >= -padding && 
             projected.dx <= size.width + padding &&
             projected.dy >= -padding && 
             projected.dy <= size.height + padding;
    }).toList();

    if (visiblePoints.isEmpty) return;

    // Sort by intensity (low to high) so high-intensity zones draw on top
    visiblePoints.sort((a, b) => a.intensity.compareTo(b.intensity));

    // Use a picture recorder for better performance
    final recorder = ui.PictureRecorder();
    final tempCanvas = Canvas(recorder);

    // Draw all heatmap gradients
    for (final point in visiblePoints) {
      _paintHeatGradient(tempCanvas, size, point);
    }

    // Apply the picture to the main canvas
    final picture = recorder.endRecording();
    canvas.drawPicture(picture);
  }

  void _paintHeatGradient(Canvas canvas, Size size, GeospatialHeatPoint point) {
    final latLng = LatLng(point.latitude, point.longitude);
    final projected = _projectToScreen(latLng, size);
    if (projected == null) return;

    final radiusPixels = _kmToPixels(radiusKm, point.latitude);
    
    // Get color based on intensity
    final color = _getHeatColor(point.intensity);
    
    // Create smooth radial gradient with multiple stops
    final gradient = RadialGradient(
      colors: [
        // Center: Most intense
        color.withValues(alpha: opacity * point.intensity),
        // Middle: Medium intensity
        color.withValues(alpha: opacity * point.intensity * 0.7),
        // Outer middle: Low intensity
        color.withValues(alpha: opacity * point.intensity * 0.4),
        // Edge: Fade to transparent
        color.withValues(alpha: opacity * point.intensity * 0.1),
        color.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.3, 0.6, 0.85, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(
        center: projected,
        radius: radiusPixels,
      ))
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.plus; // Additive blending for overlapping areas

    canvas.drawCircle(projected, radiusPixels, paint);

    // Add a small marker dot at the center for precision
    _paintCenterDot(canvas, projected, point);
  }

  void _paintCenterDot(Canvas canvas, Offset center, GeospatialHeatPoint point) {
    final color = _getHeatColor(point.intensity);
    final dotSize = 8.0 + (point.intensity * 4.0); // 8-12px based on intensity
    
    // Outer glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center, dotSize * 0.8, glowPaint);
    
    // Main dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, dotSize * 0.5, dotPaint);
    
    // White border for contrast
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, dotSize * 0.5, borderPaint);
    
    // Inner highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6);
    canvas.drawCircle(center, dotSize * 0.2, highlightPaint);
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
    final latRad = latitude * math.pi / 180.0;
    final kmPerDegreeLat = 111.0;
    final kmPerDegreeLng = 111.0 * math.cos(latRad);
    
    final avgKmPerDegree = (kmPerDegreeLat + kmPerDegreeLng) / 2;
    final degrees = km / avgKmPerDegree;
    
    final zoom = camera.zoom;
    final pixelsPerDegree = 256 * math.pow(2, zoom) / 360;
    
    return degrees * pixelsPerDegree;
  }

  Color _getHeatColor(double intensity) {
    // Professional heat gradient colors
    if (intensity >= 0.9) {
      return const Color(0xFFDC2626); // Critical red
    } else if (intensity >= 0.75) {
      return const Color(0xFFEF4444); // High red
    } else if (intensity >= 0.6) {
      return const Color(0xFFFF5722); // Orange-red
    } else if (intensity >= 0.45) {
      return const Color(0xFFFF9800); // Orange
    } else if (intensity >= 0.3) {
      return const Color(0xFFFB8C00); // Dark orange
    } else if (intensity >= 0.15) {
      return const Color(0xFFFFC107); // Amber
    } else {
      return const Color(0xFFFDD835); // Yellow
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter oldDelegate) {
    final cameraChanged = oldDelegate.camera.center != camera.center ||
                          oldDelegate.camera.zoom != camera.zoom ||
                          oldDelegate.camera.rotation != camera.rotation;
    
    return cameraChanged ||
           oldDelegate.heatPoints != heatPoints ||
           oldDelegate.radiusKm != radiusKm ||
           oldDelegate.opacity != opacity;
  }
}
