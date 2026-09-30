import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_capture.dart';

class ShopVerificationResult {
  final bool isVerified;
  final double distanceMeters;
  final double verificationRadiusMeters;
  final String statusLabel;
  final String message;
  final DateTime verifiedAt;

  ShopVerificationResult({
    required this.isVerified,
    required this.distanceMeters,
    required this.verificationRadiusMeters,
    required this.statusLabel,
    required this.message,
    required this.verifiedAt,
  });
}

class LocationService {
  static const double defaultMaxAccuracyThreshold = 10.0; // 10 meters threshold
  static const double defaultShopVerificationRadius = 30.0; // 30 meters radius

  /// Check whether system GPS location services are turned ON
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check location permissions
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permissions
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Open device location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Acquires high-accuracy GPS position by evaluating multiple readings for stability
  Future<LocationCaptureModel> captureAccurateLocation({
    double maxAcceptableAccuracy = defaultMaxAccuracyThreshold,
    int maxReadings = 5,
    Duration timeoutDuration = const Duration(seconds: 15),
  }) async {
    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceDisabledException();
    }

    LocationPermission permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationPermissionDeniedException('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionPermanentlyDeniedException('Location permission permanently denied.');
    }

    // Configure platform-specific location settings for best accuracy
    LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        forceLocationManager: false,
        intervalDuration: const Duration(milliseconds: 500),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.fitness,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.best,
      );
    }

    final Completer<LocationCaptureModel> completer = Completer<LocationCaptureModel>();
    final List<Position> collectedReadings = [];
    StreamSubscription<Position>? streamSubscription;
    Timer? timeoutTimer;

    void cleanup() {
      timeoutTimer?.cancel();
      streamSubscription?.cancel();
    }

    timeoutTimer = Timer(timeoutDuration, () {
      if (!completer.isCompleted) {
        cleanup();
        if (collectedReadings.isNotEmpty) {
          // Pick the reading with best accuracy captured before timeout
          collectedReadings.sort((a, b) => a.accuracy.compareTo(b.accuracy));
          final best = collectedReadings.first;
          completer.complete(
            LocationCaptureModel(
              latitude: best.latitude,
              longitude: best.longitude,
              accuracy: best.accuracy,
              capturedAt: DateTime.now(),
              source: 'gps',
            ),
          );
        } else {
          completer.completeError(
            TimeoutException('GPS signal timeout. Unable to obtain stable location.'),
          );
        }
      }
    });

    try {
      streamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position position) {
          collectedReadings.add(position);
          debugPrint('Captured GPS reading #${collectedReadings.length}: ${position.latitude}, ${position.longitude} (Accuracy: ±${position.accuracy.toStringAsFixed(1)}m)');

          // If we receive a reading that is already within <= 5m (excellent), we can complete immediately
          if (position.accuracy <= 5.0 && !completer.isCompleted) {
            cleanup();
            completer.complete(
              LocationCaptureModel(
                latitude: position.latitude,
                longitude: position.longitude,
                accuracy: position.accuracy,
                capturedAt: DateTime.now(),
                source: 'gps',
              ),
            );
          } else if (collectedReadings.length >= maxReadings && !completer.isCompleted) {
            cleanup();
            // Sort to pick the position with minimum error margin (best accuracy)
            collectedReadings.sort((a, b) => a.accuracy.compareTo(b.accuracy));
            final best = collectedReadings.first;
            completer.complete(
              LocationCaptureModel(
                latitude: best.latitude,
                longitude: best.longitude,
                accuracy: best.accuracy,
                capturedAt: DateTime.now(),
                source: 'gps',
              ),
            );
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            cleanup();
            completer.completeError(error);
          }
        },
      );
    } catch (e) {
      cleanup();
      // Fallback to single getCurrentPosition call if stream fails
      final singlePos = await Geolocator.getCurrentPosition(locationSettings: locationSettings);
      return LocationCaptureModel(
        latitude: singlePos.latitude,
        longitude: singlePos.longitude,
        accuracy: singlePos.accuracy,
        capturedAt: DateTime.now(),
        source: 'gps',
      );
    }

    return await completer.future;
  }

  /// Calculates physical distance in meters between current location and registered shop coordinates
  ShopVerificationResult verifyShopDistance({
    required double registeredLat,
    required double registeredLng,
    required double currentLat,
    required double currentLng,
    double radiusMeters = defaultShopVerificationRadius,
  }) {
    final double distanceMeters = Geolocator.distanceBetween(
      currentLat,
      currentLng,
      registeredLat,
      registeredLng,
    );

    final bool isVerified = distanceMeters <= radiusMeters;

    final String statusLabel = isVerified ? 'SHOP VERIFIED 🟢' : 'SHOP NOT VERIFIED 🔴';

    final String formattedDist = distanceMeters >= 1000
        ? '${(distanceMeters / 1000).toStringAsFixed(2)} km'
        : '${distanceMeters.toStringAsFixed(1)} m';

    final String message = isVerified
        ? 'You are within the $radiusMeters m shop verification radius ($formattedDist away).'
        : 'You are approximately $formattedDist away from the registered shop location.';

    return ShopVerificationResult(
      isVerified: isVerified,
      distanceMeters: distanceMeters,
      verificationRadiusMeters: radiusMeters,
      statusLabel: statusLabel,
      message: message,
      verifiedAt: DateTime.now(),
    );
  }
}

class LocationPermissionDeniedException implements Exception {
  final String message;
  LocationPermissionDeniedException(this.message);
  @override
  String toString() => message;
}

class LocationPermissionPermanentlyDeniedException implements Exception {
  final String message;
  LocationPermissionPermanentlyDeniedException(this.message);
  @override
  String toString() => message;
}
