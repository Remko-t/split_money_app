import 'package:hive/hive.dart';

part 'expense.g.dart';

@HiveType(typeId: 1) // ID 1 dla Expense
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

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.payerId,
    required this.date,
  });
}