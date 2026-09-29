import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (SupabaseConfig.url.contains('xyzcompany')) {
        debugPrint('Supabase initialized in Demo Mode (Mock/Offline enabled).');
        _initialized = true;
        return;
      }

      await Supabase.initialize(
        url: SupabaseConfig.url,
        // ignore: deprecated_member_use
        anonKey: SupabaseConfig.anonKey,
      );
      _initialized = true;
      debugPrint('Supabase initialized successfully.');
    } catch (e) {
      debugPrint('Supabase initialization warning: $e');
      _initialized = true; // allow app to run safely in offline/mock mode
    }
  }

  SupabaseClient get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw Exception('Supabase client not connected. Please provide SUPABASE_URL and SUPABASE_ANON_KEY.');
    }
  }
}
