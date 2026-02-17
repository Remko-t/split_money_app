// plik: lib/models/expense.dart
import 'package:hive/hive.dart';

part 'expense.g.dart';

@HiveType(typeId: 1)
class Expense {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final String payerId;

  @HiveField(4)
  final DateTime date;

  @HiveField(5)
  final List<String> beneficiaryIds;

  @HiveField(6, defaultValue: 'other')
  final String category;

  @HiveField(7) // NOWE POLE
  final String? receiptPath; // Może być null (brak zdjęcia)

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.payerId,
    required this.date,
    this.beneficiaryIds = const [],
    this.category = 'other',
    this.receiptPath, // Dodaj to w konstruktorze
  });
}