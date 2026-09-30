import 'package:flutter/foundation.dart';
import '../models/location_capture.dart';
import '../services/location_service.dart';

class LocationProvider with ChangeNotifier {
  final LocationService _locationService = LocationService();

  LocationCaptureModel? _currentCapture;
  ShopVerificationResult? _verificationResult;
  bool _isCapturing = false;
  bool _isVerifying = false;
  String? _error;

  LocationCaptureModel? get currentCapture => _currentCapture;
  ShopVerificationResult? get verificationResult => _verificationResult;
  bool get isCapturing => _isCapturing;
  bool get isVerifying => _isVerifying;
  String? get error => _error;

  /// Captures shop location by sampling multiple GPS readings and validating reported accuracy
  Future<bool> captureShopLocation({
    double maxAccuracyThreshold = LocationService.defaultMaxAccuracyThreshold,
  }) async {
    _isCapturing = true;
    _error = null;
    notifyListeners();

    try {
      final capture = await _locationService.captureAccurateLocation(
        maxAcceptableAccuracy: maxAccuracyThreshold,
      );

      _currentCapture = capture;
      _isCapturing = false;

      if (!capture.isAcceptable(threshold: maxAccuracyThreshold)) {
        _error = 'GPS accuracy is ±${capture.accuracy.toStringAsFixed(1)} m (Threshold: ${maxAccuracyThreshold.toStringAsFixed(0)} m). Move to an open area and retry.';
        notifyListeners();
        return false;
      }

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('LocationProvider captureShopLocation error: $e');
      _error = e.toString().replaceAll('Exception: ', '');
      _isCapturing = false;
      notifyListeners();
      return false;
    }
  }

  /// Verifies whether the salesman is physically at the registered shop location
  Future<ShopVerificationResult?> verifyShopLocation({
    required double registeredLat,
    required double registeredLng,
    double radiusMeters = LocationService.defaultShopVerificationRadius,
  }) async {
    _isVerifying = true;
    _error = null;
    notifyListeners();

    try {
      final currentLoc = await _locationService.captureAccurateLocation(
        maxAcceptableAccuracy: 50.0, // Allow up to 50m accuracy for verification check
      );

      _currentCapture = currentLoc;

      final result = _locationService.verifyShopDistance(
        registeredLat: registeredLat,
        registeredLng: registeredLng,
        currentLat: currentLoc.latitude,
        currentLng: currentLoc.longitude,
        radiusMeters: radiusMeters,
      );

      _verificationResult = result;
      _isVerifying = false;
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('LocationProvider verifyShopLocation error: $e');
      _error = 'Location verification failed: $e';
      _isVerifying = false;
      notifyListeners();
      return null;
    }
  }

  void setManualLocation({
    required double latitude,
    required double longitude,
    double accuracy = 5.0,
    String source = 'map_selected',
  }) {
    _currentCapture = LocationCaptureModel(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      capturedAt: DateTime.now(),
      source: source,
    );
    _error = null;
    notifyListeners();
  }

  void setCurrentCapture(LocationCaptureModel capture) {
    _currentCapture = capture;
    notifyListeners();
  }

  void reset() {
    _currentCapture = null;
    _verificationResult = null;
    _isCapturing = false;
    _isVerifying = false;
    _error = null;
    notifyListeners();
  }
}
