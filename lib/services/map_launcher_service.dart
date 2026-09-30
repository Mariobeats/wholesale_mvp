import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MapLauncherService {
  /// Opens the given coordinates in Google Maps or the default device maps application.
  static Future<void> openMap(
    BuildContext context,
    double latitude,
    double longitude, {
    String? title,
  }) async {
    final String query = '$latitude,$longitude';
    final String encodedTitle = Uri.encodeComponent(title ?? 'Shop Location');

    // List of URLs to attempt in order of preference
    final List<Uri> urisToTry = [
      // Standard Google Maps web query (works on Android, iOS, and Web)
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'),
      // Legacy Google Maps web link
      Uri.parse('https://maps.google.com/?q=$query'),
      // Native Android geo intent
      Uri.parse('geo:$query?q=$query($encodedTitle)'),
    ];

    bool launched = false;

    for (final uri in urisToTry) {
      try {
        if (await canLaunchUrl(uri)) {
          launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) break;
        }
      } catch (_) {
        // Continue to fallback launch
      }

      // Direct launch fallback without canLaunchUrl check
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
        if (launched) break;
      } catch (_) {}
    }

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open map for coordinates ($latitude, $longitude)'),
          backgroundColor: Colors.red.shade700,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }
}
