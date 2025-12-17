import 'package:latlong2/latlong.dart';

/// Model for geospatial heatmap data points based on panic alerts and safety incidents
class GeospatialHeatPoint {
  final double latitude;
  final double longitude;
  final double intensity; // 0.0 to 1.0
  final HeatPointType type;
  final DateTime timestamp;
  final String? description;
  final int alertCount; // Number of incidents at this location

  GeospatialHeatPoint({
    required this.latitude,
    required this.longitude,
    required this.intensity,
    required this.type,
    required this.timestamp,
    this.description,
    this.alertCount = 1,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  factory GeospatialHeatPoint.fromPanicAlert({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    double intensity = 0.8,
    int alertCount = 1,
    String? description,
  }) {
    return GeospatialHeatPoint(
      latitude: latitude,
      longitude: longitude,
      intensity: intensity, // High intensity for panic alerts
      type: HeatPointType.panicAlert,
      timestamp: timestamp,
      description: description,
      alertCount: alertCount,
    );
  }

  factory GeospatialHeatPoint.fromRestrictedZone({
    required double latitude,
    required double longitude,
    required double intensity,
    required String description,
  }) {
    return GeospatialHeatPoint(
      latitude: latitude,
      longitude: longitude,
      intensity: intensity,
      type: HeatPointType.restrictedZone,
      timestamp: DateTime.now(),
      description: description,
      alertCount: 1,
    );
  }

  factory GeospatialHeatPoint.fromJson(Map<String, dynamic> json) {
    return GeospatialHeatPoint(
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      intensity: json['intensity'].toDouble(),
      type: HeatPointType.values.firstWhere(
        (e) => e.toString() == 'HeatPointType.${json['type']}',
        orElse: () => HeatPointType.general,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      description: json['description'],
      alertCount: json['alert_count'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'intensity': intensity,
      'type': type.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'alert_count': alertCount,
    };
  }

  /// Merge with another heat point at similar location
  GeospatialHeatPoint mergeWith(GeospatialHeatPoint other) {
    final newIntensity = ((intensity + other.intensity) / 2).clamp(0.0, 1.0);
    final newAlertCount = alertCount + other.alertCount;
    
    return GeospatialHeatPoint(
      latitude: (latitude + other.latitude) / 2,
      longitude: (longitude + other.longitude) / 2,
      intensity: newIntensity,
      type: intensity > other.intensity ? type : other.type,
      timestamp: timestamp.isAfter(other.timestamp) ? timestamp : other.timestamp,
      description: description ?? other.description,
      alertCount: newAlertCount,
    );
  }
}

enum HeatPointType {
  panicAlert,
  restrictedZone,
  safetyIncident,
  general,
}

/// Configuration for heatmap visualization
class HeatmapConfig {
  final double baseRadius;
  final double minOpacity;
  final double maxOpacity;
  final bool showLegend;
  final bool showIntensityScale;
  final List<HeatPointType> visibleTypes;
  final int maxPoints;
  final Duration dataTimeWindow;

  const HeatmapConfig({
    this.baseRadius = 80.0,
    this.minOpacity = 0.1,
    this.maxOpacity = 0.8,
    this.showLegend = true,
    this.showIntensityScale = true,
    this.visibleTypes = const [
      HeatPointType.panicAlert,
      HeatPointType.restrictedZone,
      HeatPointType.safetyIncident,
    ],
    this.maxPoints = 500,
    this.dataTimeWindow = const Duration(days: 30),
  });
}
