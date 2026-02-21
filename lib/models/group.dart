import 'member.dart';
import 'expense.dart';

class Group {
  final String id;
  final String name;
  final DateTime createdAt;
  List<Member> members;
  List<Expense> expenses;

  Group({
    required this.id,
    required this.name,
    required this.createdAt,
    this.members = const [],
    this.expenses = const [],
  });
}