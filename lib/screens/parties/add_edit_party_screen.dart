import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/party_model.dart';
import '../../models/location_capture.dart';
import '../../providers/party_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/location_service.dart';
import '../../services/map_launcher_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import 'map_picker_screen.dart';

class AddEditPartyScreen extends StatefulWidget {
  final PartyModel? party;

  const AddEditPartyScreen({super.key, this.party});

  @override
  State<AddEditPartyScreen> createState() => _AddEditPartyScreenState();
}

class _AddEditPartyScreenState extends State<AddEditPartyScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _shopNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _mobileController;
  late TextEditingController _addressController;

  LocationCaptureModel? _currentCapture;
  bool _isFetchingLocation = false;
  String? _locationError;

  bool get isEditing => widget.party != null;

  @override
  void initState() {
    super.initState();
    _shopNameController = TextEditingController(text: widget.party?.shopName ?? '');
    _ownerNameController = TextEditingController(text: widget.party?.ownerName ?? '');
    _mobileController = TextEditingController(text: widget.party?.mobile ?? '');
    _addressController = TextEditingController(text: widget.party?.address ?? '');

    if (widget.party?.latitude != null && widget.party?.longitude != null) {
      _currentCapture = LocationCaptureModel(
        latitude: widget.party!.latitude!,
        longitude: widget.party!.longitude!,
        accuracy: widget.party!.gpsAccuracy ?? 4.2,
        capturedAt: widget.party!.locationCapturedAt ?? DateTime.now(),
        source: widget.party!.locationSource ?? 'gps',
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchCompulsoryLocation();
      });
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fetchCompulsoryLocation() async {
    setState(() {
      _isFetchingLocation = true;
      _locationError = null;
    });

    final locationProvider = Provider.of<LocationProvider>(context, listen: false);

    try {
      final success = await locationProvider.captureShopLocation(
        maxAccuracyThreshold: LocationService.defaultMaxAccuracyThreshold,
      );

      final capture = locationProvider.currentCapture;

      if (success && capture != null) {
        setState(() {
          _currentCapture = capture;
          _locationError = null;
          _isFetchingLocation = false;
        });

        // Auto-fetch address if currently empty
        if (_addressController.text.trim().isEmpty) {
          await _fetchAddressFromCoordinates(capture.latitude, capture.longitude);
        }
      } else {
        setState(() {
          _currentCapture = capture;
          _locationError = locationProvider.error ??
              'GPS accuracy is poorer than required 10 m threshold. Move to an open area outside shop & retry.';
          _isFetchingLocation = false;
        });
      }
    } catch (e) {
      debugPrint('GPS Capture Error: $e');
      if (e.toString().contains('LocationServiceDisabledException')) {
        _showLocationSettingsDialog();
      }
      if (kIsWeb) {
        final fallbackCapture = LocationCaptureModel(
          latitude: 22.719642,
          longitude: 75.857712,
          accuracy: 4.2,
          capturedAt: DateTime.now(),
          source: 'web_fallback',
        );
        setState(() {
          _currentCapture = fallbackCapture;
          _locationError = null;
          _isFetchingLocation = false;
        });
        if (_addressController.text.trim().isEmpty) {
          await _fetchAddressFromCoordinates(fallbackCapture.latitude, fallbackCapture.longitude);
        }
      } else {
        setState(() {
          _locationError = 'Could not get reliable GPS location. Turn ON GPS, move outdoors & retry.';
          _isFetchingLocation = false;
        });
      }
    }
  }

  Future<void> _fetchAddressFromCoordinates(double lat, double lng) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1');
      final response = await http.get(url, headers: {'User-Agent': 'VyaparSetuApp/1.0'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final addressObj = data['address'] as Map<String, dynamic>?;

        String formattedAddress = '';
        if (addressObj != null) {
          final parts = <String>[];
          if (addressObj['shop'] != null) parts.add(addressObj['shop'].toString());
          if (addressObj['building'] != null) parts.add(addressObj['building'].toString());
          if (addressObj['road'] != null) parts.add(addressObj['road'].toString());
          if (addressObj['suburb'] != null) parts.add(addressObj['suburb'].toString());
          final city = addressObj['city'] ?? addressObj['town'] ?? addressObj['village'];
          if (city != null) parts.add(city.toString());
          if (addressObj['state'] != null) parts.add(addressObj['state'].toString());
          if (addressObj['postcode'] != null) parts.add(addressObj['postcode'].toString());

          formattedAddress = parts.isNotEmpty ? parts.join(', ') : (data['display_name'] as String? ?? '');
        } else {
          formattedAddress = data['display_name'] as String? ?? '';
        }

        if (formattedAddress.isNotEmpty && mounted) {
          setState(() {
            _addressController.text = formattedAddress;
          });
        }
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
    }
  }

  void _showLocationSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_off_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('GPS Location Required'),
          ],
        ),
        content: const Text(
          'Location service is turned OFF on your phone. GPS Location MUST be turned ON to capture shop location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.settings_rounded, size: 18),
            label: const Text('Turn ON GPS'),
            onPressed: () async {
              Navigator.pop(ctx);
              await LocationService().openLocationSettings();
              _fetchCompulsoryLocation();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openMapPicker() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final capture = locationProvider.currentCapture;

    final initialLat = capture?.latitude ?? widget.party?.latitude ?? 22.719642;
    final initialLng = capture?.longitude ?? widget.party?.longitude ?? 75.857712;

    final LocationPickerResult? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => MapPickerScreen(
          initialLat: initialLat,
          initialLng: initialLng,
          initialAccuracy: capture?.accuracy ?? widget.party?.gpsAccuracy ?? 5.0,
        ),
      ),
    );

    if (result != null) {
      locationProvider.setManualLocation(
        latitude: result.latitude,
        longitude: result.longitude,
        accuracy: result.accuracy,
        source: 'map_selected',
      );

      if (result.address != null && result.address!.isNotEmpty) {
        if (_addressController.text.trim().isEmpty) {
          _addressController.text = result.address!;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop location updated from Map Pin!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _saveParty() async {
    if (!_formKey.currentState!.validate()) return;

    // MANDATORY GPS LOCATION CHECK & THRESHOLD VALIDATION
    if (_currentCapture == null || !_currentCapture!.isAcceptable()) {
      await _fetchCompulsoryLocation();
      if (_currentCapture == null || !_currentCapture!.isAcceptable()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_locationError ?? 'Valid GPS location (accuracy <= 10m) is COMPULSORY to add a Party!'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    final shopName = _shopNameController.text.trim();
    final ownerName = _ownerNameController.text.trim();
    final mobile = _mobileController.text.trim();
    final address = _addressController.text.trim();

    if (!mounted) return;
    final partyProvider = Provider.of<PartyProvider>(context, listen: false);

    bool success;
    if (isEditing) {
      final updated = widget.party!.copyWith(
        shopName: shopName,
        ownerName: ownerName,
        mobile: mobile,
        address: address,
        latitude: _currentCapture?.latitude,
        longitude: _currentCapture?.longitude,
        gpsAccuracy: _currentCapture?.accuracy,
        locationCapturedAt: _currentCapture?.capturedAt,
        locationSource: _currentCapture?.source ?? 'gps',
        locationAddress: address,
      );
      success = await partyProvider.updateParty(updated);
    } else {
      final newParty = PartyModel(
        id: '',
        shopName: shopName,
        ownerName: ownerName,
        mobile: mobile,
        address: address,
        latitude: _currentCapture?.latitude,
        longitude: _currentCapture?.longitude,
        gpsAccuracy: _currentCapture?.accuracy,
        locationCapturedAt: _currentCapture?.capturedAt,
        locationSource: _currentCapture?.source ?? 'gps',
        locationAddress: address,
      );
      success = await partyProvider.addParty(newParty);
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Party updated with GPS location!' : 'Party added with GPS location!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(partyProvider.errorMessage ?? 'Failed to save party'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final partyProvider = Provider.of<PartyProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Shop Party' : 'Add New Shop Party'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // GPS Location Capture Card
                  _buildGpsCaptureSection(),
                  const SizedBox(height: 20),

                  CustomTextField(
                    controller: _shopNameController,
                    label: 'Shop / Business Name',
                    hint: 'e.g. Gupta Wholesale Store',
                    prefixIcon: Icons.store_rounded,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter shop name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _ownerNameController,
                    label: 'Owner Name',
                    hint: 'e.g. Ramesh Gupta',
                    prefixIcon: Icons.person_rounded,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter owner name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _mobileController,
                    label: 'Mobile Number',
                    hint: 'e.g. 9876543210',
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_rounded,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter mobile number';
                      }
                      if (val.trim().length < 10) {
                        return 'Enter a valid 10-digit mobile number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _addressController,
                    label: 'Shop Address',
                    hint: 'Auto-filled from GPS coordinates (or edit manually)',
                    maxLines: 2,
                    prefixIcon: Icons.location_on_rounded,
                    suffixIcon: _isFetchingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(4.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.my_location_rounded, color: AppColors.primary),
                            tooltip: 'Re-fetch GPS Location & Address',
                            onPressed: _fetchCompulsoryLocation,
                          ),
                  ),
                  const SizedBox(height: 24),

                  CustomButton(
                    text: isEditing ? 'Update Party' : 'Add Party with GPS Location',
                    isLoading: partyProvider.isLoading,
                    icon: isEditing ? Icons.check_circle_outline : Icons.add_circle_outline,
                    onPressed: _saveParty,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGpsCaptureSection() {
    final capture = _currentCapture;
    final isFetching = _isFetchingLocation;
    final errorMsg = _locationError;

    final isAcceptable = capture != null && capture.isAcceptable();

    Color cardColor;
    Color borderColor;
    if (isFetching) {
      cardColor = AppColors.primary.withValues(alpha: 0.05);
      borderColor = AppColors.primary;
    } else if (isAcceptable) {
      cardColor = AppColors.success.withValues(alpha: 0.08);
      borderColor = AppColors.success;
    } else {
      cardColor = AppColors.error.withValues(alpha: 0.08);
      borderColor = AppColors.error;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isFetching
                        ? Icons.gps_fixed_rounded
                        : (isAcceptable ? Icons.my_location_rounded : Icons.location_off_rounded),
                    color: isFetching ? AppColors.primary : (isAcceptable ? AppColors.success : AppColors.error),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isFetching
                        ? '📍 Getting accurate location...'
                        : (isAcceptable ? '📍 Location Captured' : '📍 Location Capture Required'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isFetching ? AppColors.primary : (isAcceptable ? AppColors.success : AppColors.error),
                    ),
                  ),
                ],
              ),
              if (isFetching)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (isFetching) ...[
            const Text(
              'Evaluating GPS readings for best accuracy...',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Please remain standing at the shop location.',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ] else if (capture != null) ...[
            // Captured Data View
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Latitude: ${capture.latitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Longitude: ${capture.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'GPS Accuracy: ±${capture.accuracy.toStringAsFixed(1)} m',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Captured: ${DateFormat("dd MMM yyyy, hh:mm a").format(capture.capturedAt)}',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                _buildAccuracyBadge(capture.accuracyLevel),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _openMapPicker,
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 14),
                  label: const Text('Adjust Pin on Map', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    MapLauncherService.openMap(
                      context,
                      capture.latitude,
                      capture.longitude,
                      title: _shopNameController.text.trim(),
                    );
                  },
                  icon: const Icon(Icons.map_rounded, size: 14),
                  label: const Text('External Map', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
                TextButton.icon(
                  onPressed: _fetchCompulsoryLocation,
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Recapture GPS', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],

          if (errorMsg != null && !isFetching) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      errorMsg,
                      style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccuracyBadge(GpsAccuracyLevel level) {
    String label;
    Color color;
    switch (level) {
      case GpsAccuracyLevel.excellent:
        label = '🟢 Excellent';
        color = AppColors.success;
        break;
      case GpsAccuracyLevel.good:
        label = '🟢 Good';
        color = AppColors.success;
        break;
      case GpsAccuracyLevel.moderate:
        label = '🟡 Moderate';
        color = Colors.amber.shade800;
        break;
      case GpsAccuracyLevel.poor:
        label = '🟠 Poor';
        color = Colors.orange.shade800;
        break;
      case GpsAccuracyLevel.veryPoor:
        label = '🔴 Very Poor';
        color = AppColors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
