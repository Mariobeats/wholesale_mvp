import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../models/party_model.dart';
import '../../providers/party_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';

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

  Position? _currentPosition;
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
      _currentPosition = Position(
        latitude: widget.party!.latitude!,
        longitude: widget.party!.longitude!,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    } else {
      _fetchCompulsoryLocation();
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

    try {
      if (!kIsWeb) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          setState(() {
            _locationError = 'GPS Location service is turned OFF! Please turn ON GPS.';
            _isFetchingLocation = false;
          });
          _showLocationSettingsDialog();
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            setState(() {
              _locationError = 'Location permission denied. GPS access is compulsory.';
              _isFetchingLocation = false;
            });
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          setState(() {
            _locationError = 'Location permission permanently denied. Enable in phone settings.';
            _isFetchingLocation = false;
          });
          return;
        }
      }

      Position? position;
      try {
        // Level 1: Try Live High Accuracy GPS (20 sec timeout)
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } catch (e) {
        debugPrint('High accuracy GPS timed out/failed: $e. Trying medium accuracy...');
        try {
          // Level 2: Fallback to Medium Accuracy (Cellular/Wi-Fi triangulation)
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 10),
            ),
          );
        } catch (e2) {
          debugPrint('Medium accuracy location failed: $e2. Trying last known cached position...');
          try {
            // Level 3: Fallback to Last Known Cached Position
            position = await Geolocator.getLastKnownPosition();
          } catch (err) {
            debugPrint('getLastKnownPosition error: $err');
          }
        }
      }

      if (position == null) {
        throw Exception('Could not obtain GPS position. Please ensure GPS is ON and move outdoors.');
      }

      setState(() {
        _currentPosition = position;
        _locationError = null;
        _isFetchingLocation = false;
      });

      // Auto-fetch human readable address if address is currently blank
      if (_addressController.text.trim().isEmpty) {
        await _fetchAddressFromCoordinates(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint('GPS Location error: $e');
      if (kIsWeb) {
        // Fallback ONLY for Web / Desktop emulator testing
        final fallbackPosition = Position(
          latitude: 22.7196,
          longitude: 75.8577,
          timestamp: DateTime.now(),
          accuracy: 10,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );

        setState(() {
          _currentPosition = fallbackPosition;
          _locationError = null;
          _isFetchingLocation = false;
        });

        if (_addressController.text.trim().isEmpty) {
          await _fetchAddressFromCoordinates(fallbackPosition.latitude, fallbackPosition.longitude);
        }
      } else {
        setState(() {
          _locationError = 'GPS Signal weak or timed out. Turn ON GPS, move outdoors & tap Refresh 🔄';
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
          'Location service is turned OFF on your phone. GPS Location MUST be turned ON to add a new Party.',
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
              await Geolocator.openLocationSettings();
              _fetchCompulsoryLocation();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveParty() async {
    if (!_formKey.currentState!.validate()) return;

    // MANDATORY GPS LOCATION CHECK
    if (_currentPosition == null) {
      await _fetchCompulsoryLocation();
      if (_currentPosition == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_locationError ?? 'GPS Location is COMPULSORY to add a Party! Please turn ON GPS.'),
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
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
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
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
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
        title: Text(isEditing ? 'Edit Party' : 'Add Party'),
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
                  // Compulsory GPS Location Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: _currentPosition != null
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _currentPosition != null ? AppColors.success : AppColors.error,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _currentPosition != null ? Icons.my_location_rounded : Icons.location_off_rounded,
                          color: _currentPosition != null ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _currentPosition != null
                                        ? 'GPS Pinpoint Captured (Compulsory)'
                                        : 'GPS Location Required (Compulsory)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: _currentPosition != null ? AppColors.success : AppColors.error,
                                    ),
                                  ),
                                  if (_currentPosition != null && _currentPosition!.accuracy > 0) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '(±${_currentPosition!.accuracy.toStringAsFixed(1)}m)',
                                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isFetchingLocation
                                    ? 'Fetching GPS & Auto-filling Address...'
                                    : _currentPosition != null
                                        ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Long: ${_currentPosition!.longitude.toStringAsFixed(6)}'
                                        : (_locationError ?? 'Turn ON GPS Location on your phone to add party.'),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (_isFetchingLocation)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else ...[
                          if (_currentPosition != null)
                            IconButton(
                              icon: const Icon(Icons.map_rounded, size: 20),
                              color: AppColors.primary,
                              tooltip: 'Verify on Google Maps',
                              onPressed: () async {
                                final Uri mapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude},${_currentPosition!.longitude}');
                                if (await canLaunchUrl(mapsUri)) {
                                  await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            color: AppColors.primary,
                            tooltip: 'Refresh GPS & Auto Address',
                            onPressed: _fetchCompulsoryLocation,
                          ),
                        ],
                      ],
                    ),
                  ),

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
                  const SizedBox(height: 18),
                  CustomTextField(
                    controller: _ownerNameController,
                    label: 'Owner Full Name',
                    hint: 'e.g. Ramesh Gupta',
                    prefixIcon: Icons.person_rounded,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter owner name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  CustomTextField(
                    controller: _mobileController,
                    label: 'Mobile Number',
                    hint: 'e.g. 9876543210',
                    prefixIcon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter mobile number';
                      }
                      if (val.trim().length < 10) {
                        return 'Please enter a valid 10-digit mobile number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  CustomTextField(
                    controller: _addressController,
                    label: 'Shop Address (Auto-filled by GPS)',
                    hint: 'Fetching automatic GPS address...',
                    prefixIcon: Icons.location_on_rounded,
                    maxLines: 3,
                    suffixIcon: _isFetchingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.my_location_rounded, color: AppColors.primary),
                            tooltip: 'Auto-fill GPS Address',
                            onPressed: _fetchCompulsoryLocation,
                          ),
                  ),
                  const SizedBox(height: 28),
                  CustomButton(
                    text: isEditing ? 'Update Party' : 'Save Party',
                    icon: isEditing ? Icons.check_circle_outline : Icons.add_circle_outline,
                    isLoading: partyProvider.isLoading,
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
}
