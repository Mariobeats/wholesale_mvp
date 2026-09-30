import 'package:flutter/foundation.dart';
import '../models/payment_model.dart';
import '../models/party_ledger_entry_model.dart';
import 'order_service.dart';
import 'supabase_service.dart';

class PaymentService {
  final SupabaseService _supabaseService = SupabaseService();
  final OrderService _orderService = OrderService();

  static final List<PaymentModel> _demoPayments = [];

  Future<List<PaymentModel>> getAllPayments() async {
    try {
      if (!_supabaseService.isInitialized ||
          SupabaseService().client.auth.currentSession == null) {
        return List.from(_demoPayments);
      }

      final response = await _supabaseService.client
          .from('payments')
          .select('''
            *,
            parties (shop_name),
            profiles (name)
          ''')
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => PaymentModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('PaymentService getAllPayments error: $e');
      return List.from(_demoPayments);
    }
  }

  Future<List<PaymentModel>> getPaymentsForParty(String partyId) async {
    try {
      if (!_supabaseService.isInitialized ||
          SupabaseService().client.auth.currentSession == null) {
        return _demoPayments.where((p) => p.partyId == partyId).toList();
      }

      final response = await _supabaseService.client
          .from('payments')
          .select('''
            *,
            parties (shop_name),
            profiles (name)
          ''')
          .eq('party_id', partyId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => PaymentModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('PaymentService getPaymentsForParty error: $e');
      return _demoPayments.where((p) => p.partyId == partyId).toList();
    }
  }

  Future<PaymentModel> recordPayment(PaymentModel payment) async {
    try {
      if (!_supabaseService.isInitialized ||
          SupabaseService().client.auth.currentSession == null) {
        final newPayment = PaymentModel(
          id: 'pay-${DateTime.now().millisecondsSinceEpoch}',
          partyId: payment.partyId,
          partyShopName: payment.partyShopName,
          salesmanId: payment.salesmanId,
          salesmanName: payment.salesmanName ?? 'Demo Salesman',
          amount: payment.amount,
          paymentMode: payment.paymentMode,
          referenceNo: payment.referenceNo,
          remarks: payment.remarks,
          createdAt: DateTime.now(),
        );
        _demoPayments.insert(0, newPayment);
        return newPayment;
      }

      final jsonToInsert = payment.toJson();
      final response = await _supabaseService.client
          .from('payments')
          .insert(jsonToInsert)
          .select('''
            *,
            parties (shop_name),
            profiles (name)
          ''')
          .single();

      return PaymentModel.fromJson(response);
    } catch (e) {
      debugPrint('PaymentService recordPayment error: $e');
      rethrow;
    }
  }

  /// Calculates Party Ledger (Orders vs Payments timeline with running balance)
  Future<PartyLedgerSummary> getPartyLedgerSummary(String partyId) async {
    final allOrders = await _orderService.getOrders();
    final partyOrders = allOrders.where((o) => o.partyId == partyId).toList();

    final partyPayments = await getPaymentsForParty(partyId);

    // Sort all events chronologically (oldest to newest) to calculate running balance
    final List<Map<String, dynamic>> events = [];

    for (final order in partyOrders) {
      events.add({
        'id': order.id,
        'date': order.createdAt ?? DateTime.now(),
        'type': LedgerEntryType.debit,
        'title': 'Invoice #${order.id.substring(0, order.id.length > 8 ? 8 : order.id.length).toUpperCase()}',
        'subtitle': 'Order items: ${order.items.length}',
        'amount': order.totalAmount,
      });
    }

    for (final pay in partyPayments) {
      final modeStr = pay.paymentMode.toUpperCase();
      final refStr = pay.referenceNo != null && pay.referenceNo!.isNotEmpty
          ? ' (Ref: ${pay.referenceNo})'
          : '';
      events.add({
        'id': pay.id,
        'date': pay.createdAt ?? DateTime.now(),
        'type': LedgerEntryType.credit,
        'title': 'Payment Received ($modeStr)',
        'subtitle': '${pay.remarks ?? "Collection"}$refStr',
        'amount': pay.amount,
      });
    }

    events.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    double runningBalance = 0.0;
    double totalBilled = 0.0;
    double totalPaid = 0.0;

    final List<PartyLedgerEntryModel> ledgerEntries = [];

    for (final event in events) {
      final type = event['type'] as LedgerEntryType;
      final amount = event['amount'] as double;

      if (type == LedgerEntryType.debit) {
        totalBilled += amount;
        runningBalance += amount;
      } else {
        totalPaid += amount;
        runningBalance -= amount;
      }

      ledgerEntries.add(
        PartyLedgerEntryModel(
          id: event['id'] as String,
          date: event['date'] as DateTime,
          type: type,
          title: event['title'] as String,
          subtitle: event['subtitle'] as String?,
          amount: amount,
          runningBalance: runningBalance,
        ),
      );
    }

    // Return newest first for UI display
    final reversedEntries = ledgerEntries.reversed.toList();

    return PartyLedgerSummary(
      totalBilled: totalBilled,
      totalPaid: totalPaid,
      outstandingBalance: totalBilled - totalPaid,
      entries: reversedEntries,
    );
  }
}

class PartyLedgerSummary {
  final double totalBilled;
  final double totalPaid;
  final double outstandingBalance;
  final List<PartyLedgerEntryModel> entries;

  PartyLedgerSummary({
    required this.totalBilled,
    required this.totalPaid,
    required this.outstandingBalance,
    required this.entries,
  });
}
