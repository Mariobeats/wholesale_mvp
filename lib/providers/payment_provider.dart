import 'package:flutter/foundation.dart';
import '../models/payment_model.dart';
import '../services/payment_service.dart';

class PaymentProvider with ChangeNotifier {
  final PaymentService _paymentService = PaymentService();

  List<PaymentModel> _payments = [];
  bool _isLoading = false;
  String? _error;

  List<PaymentModel> get payments => _payments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchAllPayments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _payments = await _paymentService.getAllPayments();
    } catch (e) {
      _error = 'Failed to load payments: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> recordPayment(PaymentModel payment) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newPayment = await _paymentService.recordPayment(payment);
      _payments.insert(0, newPayment);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to record payment: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<PartyLedgerSummary> getPartyLedger(String partyId) async {
    return await _paymentService.getPartyLedgerSummary(partyId);
  }
}
