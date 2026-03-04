class ExpenseItem {
  final String name;
  final double price;
  final List<String> beneficiaries;

  ExpenseItem({required this.name, required this.price, required this.beneficiaries});

  Map<String, dynamic> toMap() => {
    'name': name,
    'price': price,
    'beneficiaries': beneficiaries,
  };

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    return ExpenseItem(
      name: map['name'] ?? '',
      price: (map['price'] as num).toDouble(),
      beneficiaries: List<String>.from(map['beneficiaries'] ?? []),
    );
  }
}

class Expense {
  final String id;
  final String title;
  final double amount;
  final String payerId;
  final List<String> beneficiaryIds;
  final DateTime date;
  final String category;
  final String? receiptPath;
  final List<ExpenseItem> items;
  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.payerId,
    required this.date,
    required this.category,
    this.beneficiaryIds = const [],
    this.receiptPath,
    this.items = const [],
  });
}