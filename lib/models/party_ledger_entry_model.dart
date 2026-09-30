enum LedgerEntryType {
  debit,  // Invoice Billed (+Outstanding Due)
  credit, // Payment Received (-Outstanding Due)
}

class PartyLedgerEntryModel {
  final String id;
  final DateTime date;
  final LedgerEntryType type;
  final String title;
  final String? subtitle;
  final double amount;
  final double runningBalance;
  final String? referenceId;

  PartyLedgerEntryModel({
    required this.id,
    required this.date,
    required this.type,
    required this.title,
    this.subtitle,
    required this.amount,
    required this.runningBalance,
    this.referenceId,
  });
}
