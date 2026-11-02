import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

abstract class LinkLauncher {
  /// Opens any standard web link or custom URI scheme.
  static Future<bool> url(
    String link, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return false;
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: mode);
      }
    } catch (e) {
      debugPrint('LinkLauncher.url error: $e');
    }
    return false;
  }

  /// Redirects to Google Maps with the destination (e.g. college name & locality).
  ///
  /// Intelligently builds the query using the college name and location hint
  /// (e.g. Kozhikode, Malappuram, Kerala).
  /// On mobile, attempts to launch native Google Maps application or geo intent first,
  /// with a robust fallback to Google Maps web navigation URL.
  static Future<bool> launchCollegeMapsDirections(
    String collegeName, {
    String? locationHint,
  }) async {
    final cleanCollege = collegeName.trim();
    if (cleanCollege.isEmpty) return false;

    // Construct intelligent search query
    String query = cleanCollege;
    if (locationHint != null && locationHint.trim().isNotEmpty) {
      // If subtitle has "Kozhikode, Kerala · 10:30 AM", extract location before the dot/bullet
      final hint = locationHint.split('·').first.trim();
      if (hint.isNotEmpty &&
          !cleanCollege.toLowerCase().contains(hint.toLowerCase())) {
        query = '$query, $hint';
      }
    }

    // Ensure Kerala, India context if not present to avoid ambiguities
    if (!query.toLowerCase().contains('kerala') &&
        !query.toLowerCase().contains('india')) {
      query = '$query, Kerala, India';
    }

    final encodedQuery = Uri.encodeComponent(query);

    // 1. Universal Google Maps search URL (works on Android, iOS, Web, Windows, macOS)
    final webMapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encodedQuery',
    );

    // 2. Android native geo intent
    final geoUri = Uri.parse('geo:0,0?q=$encodedQuery');

    // On native mobile (Android/iOS), try geo scheme or Google Maps app intent
    if (!kIsWeb) {
      try {
        if (await canLaunchUrl(geoUri)) {
          final launched = await launchUrl(
            geoUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        }
      } catch (e) {
        debugPrint('Native geoUri launch failed, falling back to webMapsUri: $e');
      }
    }

    // Fallback: Launch universal web maps URL
    try {
      final launched = await launchUrl(
        webMapsUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;
    } catch (e) {
      debugPrint('externalApplication maps launch failed: $e');
    }

    // Secondary fallback with platformDefault
    try {
      return await launchUrl(webMapsUri, mode: LaunchMode.platformDefault);
    } catch (e) {
      debugPrint('platformDefault maps launch failed: $e');
      return false;
    }
  }
}
