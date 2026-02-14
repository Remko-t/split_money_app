import 'package:hive/hive.dart';

part 'member.g.dart'; // To nazwa pliku, który wygeneruje się sam

@HiveType(typeId: 0) // Unikalne ID dla klasy Member
class Member {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  Member({required this.id, required this.name});
}