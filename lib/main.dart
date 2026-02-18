import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

// Import konfiguracji Firebase (plik wygenerowany przez terminal)
import 'firebase_options.dart';

// Importy Twoich modeli (potrzebne do Hive)
import 'models/group.dart';
import 'models/expense.dart';
import 'models/member.dart';

// Importy ekranów
import 'screens/home_screen.dart'; // Twoja lista grup (zgodnie ze screenem)
import 'screens/auth_screen.dart'; // Twój nowy ekran logowania

void main() async {
  // 1. Przygotowanie silnika Fluttera
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicjalizacja Firebase (łączenie z chmurą)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Inicjalizacja Hive (lokalna baza danych)
  await Hive.initFlutter();

  // Rejestracja adapterów Hive
  Hive.registerAdapter(GroupAdapter());
  Hive.registerAdapter(ExpenseAdapter());
  Hive.registerAdapter(MemberAdapter());

  // Otwarcie pudełka z grupami
  await Hive.openBox<Group>('groups_box');

  // 4. Start aplikacji
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rozliczacz',
      debugShowCheckedModeBanner: false, // Usuwa pasek "DEBUG"
      theme: ThemeData(
        // Twój morski kolor przewodni
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 30, 233, 199),
        ),
        useMaterial3: true,
      ),
      
      // --- BRAMKA LOGOWANIA ---
      home: StreamBuilder<User?>(
        // Słuchamy, czy użytkownik jest zalogowany w Firebase
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Jeśli mamy dane (użytkownik jest zalogowany) -> Idź do listy grup
          if (snapshot.hasData) {
            return const HomeScreen(); 
          }
          
          // Jeśli nie mamy danych (wylogowany) -> Pokaż logowanie/rejestrację
          return const AuthScreen(); 
        },
      ),
    );
  }
}