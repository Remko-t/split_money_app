import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // --- NOWOŚĆ: WŁĄCZENIE TRYBU OFFLINE (FIRESTORE CACHE) ---
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true, // Zezwala na działanie bez internetu
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Może zapisać dużo danych na telefonie
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Rozliczacz',
          debugShowCheckedModeBanner: false,
          
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromARGB(255, 30, 233, 199),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromARGB(255, 30, 233, 199),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          
          themeMode: currentMode,
          
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.hasData) return const HomeScreen(); 
              return const AuthScreen(); 
            },
          ),
        );
      },
    );
  }
}