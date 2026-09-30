enum GpsAccuracyLevel {
  excellent, // <= 5m 🟢
  good,      // > 5m - 10m 🟢
  moderate,  // > 10m - 20m 🟡
  poor,      // > 20m - 50m 🟠
  veryPoor,  // > 50m 🔴
}

class LocationCaptureModel {
  final double latitude;
  final double longitude;
  final double accuracy; // Device-reported error margin in meters
  final DateTime capturedAt;
  final String source;

  static const double maxAcceptableAccuracyThreshold = 10.0; // Default threshold = 10m

  LocationCaptureModel({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
    this.source = 'gps',
  });

  GpsAccuracyLevel get accuracyLevel {
    if (accuracy <= 5.0) return GpsAccuracyLevel.excellent;
    if (accuracy <= 10.0) return GpsAccuracyLevel.good;
    if (accuracy <= 20.0) return GpsAccuracyLevel.moderate;
    if (accuracy <= 50.0) return GpsAccuracyLevel.poor;
    return GpsAccuracyLevel.veryPoor;
  }

  bool isAcceptable({double threshold = maxAcceptableAccuracyThreshold}) {
    return accuracy <= threshold;
  }

  String get accuracyLabel {
    switch (accuracyLevel) {
      case GpsAccuracyLevel.excellent:
        return 'Excellent Location Accuracy';
      case GpsAccuracyLevel.good:
        return 'Good Location Accuracy';
      case GpsAccuracyLevel.moderate:
        return 'Moderate Location Accuracy';
      case GpsAccuracyLevel.poor:
        return 'Poor Location Accuracy';
      case GpsAccuracyLevel.veryPoor:
        return 'Very Poor Location Accuracy';
    }
  }

  factory LocationCaptureModel.fromJson(Map<String, dynamic> json) {
    return LocationCaptureModel(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['gps_accuracy'] as num?)?.toDouble() ?? 0.0,
      capturedAt: json['location_captured_at'] != null
          ? DateTime.tryParse(json['location_captured_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      source: json['location_source'] as String? ?? 'gps',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy': accuracy,
      'location_captured_at': capturedAt.toIso8601String(),
      'location_source': source,
    };
  }
}
