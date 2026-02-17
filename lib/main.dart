// plik: lib/main.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/group.dart';
import 'models/member.dart';
import 'models/expense.dart';
import 'screens/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print("--- START APLIKACJI ---");
  // Inicjalizacja Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // 1. Inicjalizacja
  await Hive.initFlutter();
  print("Hive zainicjowany.");

  // 2. Rejestracja adapterów
  Hive.registerAdapter(GroupAdapter());
  Hive.registerAdapter(MemberAdapter());
  Hive.registerAdapter(ExpenseAdapter());
  print("Adaptery zarejestrowane.");

  // 3. Otwarcie pudełka
  var box = await Hive.openBox<Group>('groups_box');
  print("Pudełko otwarte. Liczba grup w bazie: ${box.length}");

  if (box.isNotEmpty) {
    print("Pierwsza grupa: ${box.getAt(0)?.name}");
  } else {
    print("Baza jest PUSTA.");
  }

  print("--- KONIEC INICJALIZACJI ---");

  runApp(const SplitMoneyApp());
}

class SplitMoneyApp extends StatelessWidget {
  const SplitMoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rozliczacz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}