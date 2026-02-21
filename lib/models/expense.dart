class Expense {
  final String id;
  final String title;
  final double amount;
  final String payerId;
  final List<String> beneficiaryIds;
  final DateTime date;
  final String category;
  final String? receiptPath;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.payerId,
    required this.beneficiaryIds,
    required this.date,
    this.category = 'other',
    this.receiptPath,
  });
}