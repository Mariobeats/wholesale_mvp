import 'package:flutter/material.dart';
import '../models/party_model.dart';
import '../services/party_service.dart';

class PartyProvider extends ChangeNotifier {
  final PartyService _partyService = PartyService();

  List<PartyModel> _parties = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _errorMessage;

  List<PartyModel> get parties => _parties;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get errorMessage => _errorMessage;

  List<PartyModel> get filteredParties {
    if (_searchQuery.trim().isEmpty) {
      return _parties;
    }
    final query = _searchQuery.toLowerCase().trim();
    return _parties.where((p) =>
      p.shopName.toLowerCase().contains(query) ||
      p.ownerName.toLowerCase().contains(query) ||
      p.mobile.contains(query)
    ).toList();
  }

  int get totalPartiesCount => _parties.length;

  Future<void> fetchParties() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _parties = await _partyService.getParties();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<bool> addParty(PartyModel party) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newParty = await _partyService.addParty(party);
      _parties.insert(0, newParty);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateParty(PartyModel party) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updated = await _partyService.updateParty(party);
      final index = _parties.indexWhere((p) => p.id == party.id);
      if (index != -1) {
        _parties[index] = updated;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteParty(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _partyService.deleteParty(id);
      _parties.removeWhere((p) => p.id == id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
