import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Importujemy globalną zmienną motywu z main.dart
import '../main.dart'; 

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? user = FirebaseAuth.instance.currentUser;

  // Funkcja zmiany imienia
  Future<void> _updateName() async {
    final controller = TextEditingController(text: user?.displayName ?? '');
    
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zmień swoje imię'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Imię w aplikacji'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()), 
            child: const Text('Zapisz')
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      // Zapisujemy nowe imię w Firebase Auth
      await user?.updateDisplayName(newName);
      await user?.reload(); // Odświeżamy dane
      setState(() {
        user = FirebaseAuth.instance.currentUser; // Aktualizujemy ekran
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zaktualizowano imię!')));
      }
    }
  }

  // Funkcja usuwania konta
  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń konto', style: TextStyle(color: Colors.red)),
        content: const Text('Czy na pewno chcesz trwale usunąć swoje konto? Tej operacji nie można cofnąć.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Usuń trwale')
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await user?.delete(); // Usuwa konto
        if (mounted) Navigator.of(context).pop(); // Zamyka ekran (Bramka w main wyłapie wylogowanie)
      } on FirebaseAuthException catch (e) {
        // Jeśli logowanie było dawno temu, Firebase ze względów bezpieczeństwa zablokuje usunięcie
        if (e.code == 'requires-recent-login') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Musisz się wylogować i zalogować ponownie, aby usunąć konto.'), backgroundColor: Colors.red),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- PROFIL ---
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      (user?.displayName != null && user!.displayName!.isNotEmpty) 
                          ? user!.displayName![0].toUpperCase() 
                          : '?',
                      style: const TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Nie ustawiono imienia',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(user?.email ?? '', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: _updateName, // Kliknięcie otwiera edycję imienia
                  )
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          const Text("Wygląd", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),

          // --- PRZEŁĄCZNIK DARK MODE ---
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, currentMode, _) {
              return SwitchListTile(
                title: const Text('Tryb Ciemny (Dark Mode)'),
                secondary: const Icon(Icons.dark_mode),
                value: currentMode == ThemeMode.dark,
                onChanged: (bool isDark) {
                  // Zmiana globalnej zmiennej motywu
                  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
                },
              );
            },
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          const Text("Konto", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),

          // --- WYLOGOWANIE ---
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Wyloguj się'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),

          // --- USUWANIE KONTA ---
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Usuń konto', style: TextStyle(color: Colors.red)),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}