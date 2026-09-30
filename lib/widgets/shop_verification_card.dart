import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../models/party_model.dart';
import '../providers/location_provider.dart';
import '../services/map_launcher_service.dart';

class ShopVerificationCard extends StatelessWidget {
  final PartyModel party;

  const ShopVerificationCard({
    super.key,
    required this.party,
  });

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final result = locationProvider.verificationResult;
    final capture = locationProvider.currentCapture;

    final bool hasGps = party.latitude != null && party.longitude != null;

    if (!hasGps) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.amber.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: const [
              Icon(Icons.location_off_rounded, color: Colors.amber, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No GPS coordinates registered for this shop yet. Register location by editing Party.',
                  style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Shop Visit Location Verification',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    MapLauncherService.openMap(
                      context,
                      party.latitude!,
                      party.longitude!,
                      title: party.shopName,
                    );
                  },
                  icon: const Icon(Icons.map_rounded, size: 14),
                  label: const Text('Open Map', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Registered Coordinates: ${party.latitude!.toStringAsFixed(6)}, ${party.longitude!.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            if (party.gpsAccuracy != null) ...[
              const SizedBox(height: 2),
              Text(
                'Registration Accuracy: ±${party.gpsAccuracy!.toStringAsFixed(1)} m | Source: ${party.locationSource ?? "gps"}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 14),

            // Verification Result Box
            if (result != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: result.isVerified
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: result.isVerified ? AppColors.success : AppColors.error,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          result.isVerified ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: result.isVerified ? AppColors.success : AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          result.statusLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: result.isVerified ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result.message,
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                    if (capture != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Current Fix Accuracy: ±${capture.accuracy.toStringAsFixed(1)} m (${capture.accuracyLabel})',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      Text(
                        'Verified At: ${DateFormat("dd MMM yyyy, hh:mm a").format(result.verifiedAt)}',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (locationProvider.error != null) ...[
              Text(
                locationProvider.error!,
                style: const TextStyle(fontSize: 11, color: AppColors.error),
              ),
              const SizedBox(height: 8),
            ],

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: locationProvider.isVerifying
                    ? null
                    : () {
                        locationProvider.verifyShopLocation(
                          registeredLat: party.latitude!,
                          registeredLng: party.longitude!,
                        );
                      },
                icon: locationProvider.isVerifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.my_location_rounded, size: 18),
                label: Text(
                  locationProvider.isVerifying
                      ? 'Acquiring GPS Fix & Verifying...'
                      : 'VERIFY MY PHYSICAL LOCATION AT SHOP (30m Radius)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
