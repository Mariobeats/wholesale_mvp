import 'package:flutter/foundation.dart';
import '../models/party_model.dart';
import 'supabase_service.dart';

class PartyService {
  final SupabaseService _supabaseService = SupabaseService();

  static final List<PartyModel> _demoParties = [
    PartyModel(
      id: 'party-1',
      shopName: 'Gupta General Store',
      ownerName: 'Ramesh Gupta',
      mobile: '9876543210',
      address: 'Main Market, Block A, City Center',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    PartyModel(
      id: 'party-2',
      shopName: 'Sharma Traders & Supermarket',
      ownerName: 'Sunil Sharma',
      mobile: '9123456789',
      address: 'Shop #42, Grain Market, Sector 12',
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
    ),
    PartyModel(
      id: 'party-3',
      shopName: 'Apna Bazar Wholesale Store',
      ownerName: 'Vikram Singh',
      mobile: '9988776655',
      address: 'GT Road, Near Railway Station',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  Future<List<PartyModel>> getParties() async {
    try {
      if (!_supabaseService.isInitialized || 
          SupabaseService().client.auth.currentSession == null) {
        return List.from(_demoParties);
      }

      final response = await _supabaseService.client
          .from('parties')
          .select()
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) {
        return List.from(_demoParties);
      }
      return data.map((json) => PartyModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('PartyService getParties fallback: $e');
      return List.from(_demoParties);
    }
  }

  Future<PartyModel> addParty(PartyModel party) async {
    try {
      if (!_supabaseService.isInitialized || 
          SupabaseService().client.auth.currentSession == null) {
        final newParty = party.copyWith(
          id: 'party-${DateTime.now().millisecondsSinceEpoch}',
          createdAt: DateTime.now(),
        );
        _demoParties.insert(0, newParty);
        return newParty;
      }

      final response = await _supabaseService.client
          .from('parties')
          .insert({
            'shop_name': party.shopName,
            'owner_name': party.ownerName,
            'mobile': party.mobile,
            'address': party.address,
          })
          .select()
          .single();

      return PartyModel.fromJson(response);
    } catch (e) {
      debugPrint('PartyService addParty fallback: $e');
      final newParty = party.copyWith(
        id: 'party-${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
      );
      _demoParties.insert(0, newParty);
      return newParty;
    }
  }

  Future<PartyModel> updateParty(PartyModel party) async {
    try {
      if (!_supabaseService.isInitialized || 
          SupabaseService().client.auth.currentSession == null) {
        final index = _demoParties.indexWhere((p) => p.id == party.id);
        if (index != -1) {
          _demoParties[index] = party;
        }
        return party;
      }

      final response = await _supabaseService.client
          .from('parties')
          .update({
            'shop_name': party.shopName,
            'owner_name': party.ownerName,
            'mobile': party.mobile,
            'address': party.address,
          })
          .eq('id', party.id)
          .select()
          .single();

      return PartyModel.fromJson(response);
    } catch (e) {
      debugPrint('PartyService updateParty fallback: $e');
      final index = _demoParties.indexWhere((p) => p.id == party.id);
      if (index != -1) {
        _demoParties[index] = party;
      }
      return party;
    }
  }

  Future<void> deleteParty(String id) async {
    try {
      if (!_supabaseService.isInitialized || 
          SupabaseService().client.auth.currentSession == null) {
        _demoParties.removeWhere((p) => p.id == id);
        return;
      }

      await _supabaseService.client.from('parties').delete().eq('id', id);
    } catch (e) {
      debugPrint('PartyService deleteParty fallback: $e');
      _demoParties.removeWhere((p) => p.id == id);
    }
  }
}
