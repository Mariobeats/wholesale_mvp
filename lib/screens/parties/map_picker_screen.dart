import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../models/location_capture.dart';
import '../../services/location_service.dart';

class LocationPickerResult {
  final double latitude;
  final double longitude;
  final double accuracy;
  final String? address;

  LocationPickerResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.address,
  });
}

class MapPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final double initialAccuracy;

  const MapPickerScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.initialAccuracy = 5.0,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late LatLng _selectedLocation;
  late double _accuracy;
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();

  bool _isLocating = false;
  bool _isResolvingAddress = false;
  String? _resolvedAddress;

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(widget.initialLat, widget.initialLng);
    _accuracy = widget.initialAccuracy;
    _reverseGeocode(_selectedLocation.latitude, _selectedLocation.longitude);
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    setState(() {
      _isResolvingAddress = true;
    });

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'VyaparSetu/1.0 (B2B Wholesale Platform)',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] as String?;
        if (mounted) {
          setState(() {
            _resolvedAddress = displayName;
            _isResolvingAddress = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isResolvingAddress = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isResolvingAddress = false;
        });
      }
    }
  }

  Future<void> _goToCurrentGps() async {
    setState(() {
      _isLocating = true;
    });

    try {
      final LocationCaptureModel capture = await _locationService.captureAccurateLocation();
      final newLatLng = LatLng(capture.latitude, capture.longitude);
      
      if (mounted) {
        setState(() {
          _selectedLocation = newLatLng;
          _accuracy = capture.accuracy;
          _isLocating = false;
        });

        _mapController.move(newLatLng, 17.0);
        _reverseGeocode(capture.latitude, capture.longitude);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not fetch current GPS: $e')),
        );
      }
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      final center = camera.center;
      setState(() {
        _selectedLocation = center;
      });
    }
  }

  void _onMapTapped(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
    });
    _mapController.move(point, _mapController.camera.zoom);
    _reverseGeocode(point.latitude, point.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Shop Location on Map'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            tooltip: 'Go to Current Location',
            onPressed: _isLocating ? null : _goToCurrentGps,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 16.5,
              onPositionChanged: _onPositionChanged,
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  _reverseGeocode(
                    _selectedLocation.latitude,
                    _selectedLocation.longitude,
                  );
                }
              },
              onTap: _onMapTapped,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.vyaparsetu.app',
              ),
            ],
          ),

          // Center Marker (Fixed Pin at Map Center)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36.0), // Offset for pin point
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: const Text(
                      'Shop Position',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(
                    Icons.location_on_rounded,
                    size: 44,
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ),
          ),

          // Top Coordinate Status Card
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(Icons.pin_drop_rounded, color: AppColors.primary, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}, Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (_isResolvingAddress)
                            const Text(
                              'Resolving shop address...',
                              style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                            )
                          else if (_resolvedAddress != null)
                            Text(
                              _resolvedAddress!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // GPS Recapture Float Button
          Positioned(
            right: 16,
            bottom: 110,
            child: FloatingActionButton.extended(
              heroTag: 'map_gps_fab',
              onPressed: _isLocating ? null : _goToCurrentGps,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              icon: _isLocating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Icon(Icons.gps_fixed_rounded),
              label: Text(_isLocating ? 'Locating...' : 'My Location'),
            ),
          ),

          // Bottom Confirm Button
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  LocationPickerResult(
                    latitude: _selectedLocation.latitude,
                    longitude: _selectedLocation.longitude,
                    accuracy: _accuracy,
                    address: _resolvedAddress,
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: const Text(
                'CONFIRM THIS SHOP LOCATION',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
