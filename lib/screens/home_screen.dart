import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group.dart';
import 'group_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final currentUser = FirebaseAuth.instance.currentUser!;

  void _addNewGroup(String name) {
    if (name.isEmpty) return;

    final myName = currentUser.displayName != null && currentUser.displayName!.isNotEmpty 
        ? currentUser.displayName! 
        : 'Ja';

    FirebaseFirestore.instance.collection('groups').add({
      'name': name,
      'ownerId': currentUser.uid,
      'created': Timestamp.now(),
      'memberIds': [currentUser.uid], 
      'membersData': [
        {'id': currentUser.uid, 'name': myName}
      ], 
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

  Group _mapFirestoreToGroup(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    DateTime parsedDate = DateTime.now();
    if (data['created'] != null) {
      parsedDate = (data['created'] as Timestamp).toDate();
    }

    return Group(
      id: doc.id, 
      name: data['name'] ?? 'Bez nazwy',
      createdAt: parsedDate,
      members: [], 
      expenses: [], 
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Twoje Wyjazdy 🌍'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ustawienia',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .where('memberIds', arrayContains: currentUser.uid)
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
          
          // Sortujemy wyjazdy (najnowsze na górze)
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['created'] as Timestamp?;
            final bTime = bData['created'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (ctx, index) {
              final groupDoc = docs[index];
              final groupData = groupDoc.data() as Map<String, dynamic>;
              
              return Dismissible(
                key: Key(groupDoc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red.withOpacity(0.8),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_forever, color: Colors.white, size: 30),
                ),
                // Okienko potwierdzenia usunięcia wyjazdu
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Usuń wyjazd'),
                      content: const Text('Czy na pewno chcesz usunąć ten wyjazd ze wszystkimi wydatkami? Tej akcji nie można cofnąć.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Usuń'),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) {
                  // Usuwamy wyjazd z bazy w chmurze
                  FirebaseFirestore.instance.collection('groups').doc(groupDoc.id).delete();
                },
                child: Card(
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
                    subtitle: Text("ID: ...${groupDoc.id.substring(groupDoc.id.length - 4)}"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      final groupObject = _mapFirestoreToGroup(groupDoc);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => GroupDetailScreen(group: groupObject),
                        ),
                      );
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
        label: const Text('Nowy Wyjazd'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}