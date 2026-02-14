import 'package:hive/hive.dart';
import 'member.dart';
import 'expense.dart';

part 'group.g.dart';

@HiveType(typeId: 2) // ID 2 dla Group
class Group extends HiveObject { // Dziedziczymy po HiveObject, to ułatwi zapisywanie zmian!
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  List<Member> members;

  @HiveField(4)
  List<Expense> expenses;

  Group({
    required this.id,
    required this.name,
    required this.createdAt,
    List<Member>? members,
    List<Expense>? expenses,
  })  : members = members ?? [],
        expenses = expenses ?? [];
}