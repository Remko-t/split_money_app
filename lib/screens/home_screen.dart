import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Użytkownik
import 'package:cloud_firestore/cloud_firestore.dart'; // Baza danych
import '../models/group.dart';
import '../models/member.dart';
import 'group_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Pobieramy obecnego użytkownika (wiemy, że jest, bo przeszliśmy logowanie)
  final currentUser = FirebaseAuth.instance.currentUser!;

  void _addNewGroup(String name) {
    if (name.isEmpty) return;

    // TWORZENIE GRUPY W CHMURZE (Firestore)
    FirebaseFirestore.instance.collection('groups').add({
      'name': name,
      'ownerId': currentUser.uid, // Zapisujemy, kto założył
      'created': Timestamp.now(),
      // Lista osób, które mają dostęp (na start tylko Ty)
      'memberIds': [currentUser.uid], 
      // Na początku lista wydatków i członków (imiona) jest pusta
      'membersData': [], 
      'expensesData': [],
    });
  }

  void _showAddGroupDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nowa Grupa'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Nazwa wyjazdu (np. Mazury)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () {
              _addNewGroup(nameController.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Utwórz'),
          ),
        ],
      ),
    );
  }

  // Funkcja pomocnicza: Zamienia "brzydkie" dane z chmury na nasz obiekt Group
  // (To tymczasowe rozwiązanie, żeby nie psuć reszty aplikacji)
  Group _mapFirestoreToGroup(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Firebase przechowuje daty jako Timestamp. Musimy to zamienić na DateTime.
    // Jeśli z jakiegoś powodu daty nie ma w bazie, dajemy dzisiejszą jako zabezpieczenie.
    DateTime parsedDate = DateTime.now();
    if (data['created'] != null) {
      parsedDate = (data['created'] as Timestamp).toDate();
    }

    // Tworzymy grupę "w locie"
    final group = Group(
      id: doc.id, 
      name: data['name'] ?? 'Bez nazwy',
      createdAt: parsedDate, // <--- DODANY BRAKUJĄCY PARAMETR
      members: [], 
      expenses: [], 
    );
    
    return group;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Twoje Wyjazdy 🌍'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(), // Wylogowanie
          ),
        ],
      ),
      // NASŁUCHIWANIE DANYCH Z CHMURY
      body: StreamBuilder<QuerySnapshot>(
        // Pytanie do bazy: "Daj mi grupy, gdzie jestem na liście uczestników"
        stream: FirebaseFirestore.instance
            .collection('groups')
            .where('memberIds', arrayContains: currentUser.uid)
            // orderBy('created', descending: true) // Najnowsze na górze
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.beach_access, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  Text(
                    'Brak wyjazdów.\nKliknij "+" aby dodać pierwszy!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (ctx, index) {
              final groupDoc = docs[index];
              final groupData = groupDoc.data() as Map<String, dynamic>;
              
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      (groupData['name'] as String).isNotEmpty ? (groupData['name'] as String)[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    groupData['name'], 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Text("ID: ...${groupDoc.id.substring(groupDoc.id.length - 4)}"), // Pokazuje końcówkę ID
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Konwertujemy na obiekt Group i wchodzimy do środka
                    final groupObject = _mapFirestoreToGroup(groupDoc);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => GroupDetailScreen(group: groupObject),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddGroupDialog,
        label: const Text('Nowy Wyjazd'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}