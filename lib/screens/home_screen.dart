// plik: lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Import Hive
import '../models/group.dart';
import 'group_detail_screen.dart'; // Import ekranu szczegółów

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 1. To jest ta brakująca linijka! Kontroler pola tekstowego:
  final TextEditingController _titleController = TextEditingController();
  
  // 2. Pobieramy otwarte pudełko z danymi
  // Upewnij się, że nazwa 'groups_box' jest taka sama jak w main.dart
  late Box<Group> _groupBox;

  @override
  void initState() {
    super.initState();
    // Pobieramy referencję do otwartego pudełka
    _groupBox = Hive.box<Group>('groups_box');
  }

  void _addNewGroup(String title) {
    if (title.isEmpty) return;

    final newGroup = Group(
      id: DateTime.now().toString(),
      name: title,
      createdAt: DateTime.now(),
      members: [],  // Inicjalizujemy puste listy
      expenses: [],
    );

    // ZAPIS: Dodajemy do bazy Hive. To automatycznie zapisuje na dysk!
    _groupBox.add(newGroup);
    
    _titleController.clear(); // Czyścimy pole
    Navigator.of(context).pop(); // Zamykamy okno
  }

  void _showAddGroupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nowa Grupa'),
        content: TextField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'Nazwa (np. Mazury 2024)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => _addNewGroup(_titleController.text),
            child: const Text('Utwórz'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje Wyjazdy'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      
      // ODCZYT: Używamy ValueListenableBuilder.
      // To widget, który sam się odświeża, gdy coś zmieni się w bazie Hive!
      body: ValueListenableBuilder(
        valueListenable: _groupBox.listenable(),
        builder: (context, Box<Group> box, _) {
          // Pobieramy dane z pudełka jako listę
          // cast<Group>() upewnia się, że typy się zgadzają
          final groups = box.values.toList().cast<Group>();

          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.group_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Brak grup. Dodaj pierwszą!', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: groups.length,
            // W pliku home_screen.dart -> wewnątrz ListView.builder:

            itemBuilder: (ctx, index) {
              final group = groups[index];

              // Dismissible to widget, który pozwala na przesuwanie (swipe)
              return Dismissible(
                key: Key(group.id), // Unikalny klucz wymagany przez Fluttera
                direction: DismissDirection.endToStart, // Przesuwanie od prawej do lewej
                background: Container(
                  color: Colors.red, // Czerwone tło
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10), // Żeby pasowało do Card
                  child: const Icon(Icons.delete, color: Colors.white, size: 30),
                ),
                onDismissed: (direction) {
                  // LOGIKA USUWANIA:
                  // Ponieważ Group dziedziczy po HiveObject, ma metodę delete()!
                  group.delete(); 
                  
                  // Opcjonalnie: Pokaż dymek z info
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Usunięto grupę: ${group.name}')),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Utworzono: ${group.createdAt.toString().split(' ')[0]}'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => GroupDetailScreen(group: group),
                        ),
                      ).then((_) {
                        setState(() {});
                      });
                    },
                  ),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddGroupDialog,
        label: const Text('Nowa grupa'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}