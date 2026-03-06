import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group.dart';
import 'group_detail_screen.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  Group _mapFirestoreToGroup(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    DateTime parsedDate = DateTime.now();
    if (data['created'] != null) parsedDate = (data['created'] as Timestamp).toDate();

    return Group(
      id: doc.id, 
      name: data['name'] ?? 'Bez nazwy',
      createdAt: parsedDate,
      inviteCode: data['inviteCode'],
      currency: data['currency'] ?? 'zł',
      isArchived: data['isArchived'] == true,
      members: [], 
      expenses: [], 
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archiwum 📦'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('groups').where('memberIds', arrayContains: currentUser.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Brak zarchiwizowanych wyjazdów."));

          // FILTRUJEMY: Pokazujemy TYLKO te, które MAJĄ flagę isArchived na true
          final archivedDocs = snapshot.data!.docs.where((doc) {
            return (doc.data() as Map<String, dynamic>)['isArchived'] == true;
          }).toList();

          archivedDocs.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['created'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['created'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          if (archivedDocs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Archiwum jest puste.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: archivedDocs.length,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemBuilder: (ctx, index) {
              final groupDoc = archivedDocs[index];
              final groupData = groupDoc.data() as Map<String, dynamic>;
              
              final String name = groupData['name'] ?? 'Bez nazwy';
              final String currency = groupData['currency'] ?? 'zł';
              final int memberCount = (groupData['memberIds'] as List?)?.length ?? 1;

              return Dismissible(
                key: Key(groupDoc.id), 
                direction: DismissDirection.startToEnd, // Swipe w prawo, by przywrócić
                background: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(16)), 
                  alignment: Alignment.centerLeft, 
                  padding: const EdgeInsets.only(left: 20), 
                  child: const Icon(Icons.unarchive, color: Colors.white, size: 30)
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Przywróć wyjazd'), content: const Text('Czy chcesz przywrócić ten wyjazd na główną listę?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('Przywróć'))]));
                },
                onDismissed: (direction) { 
                  FirebaseFirestore.instance.collection('groups').doc(groupDoc.id).update({'isArchived': false}); 
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wyjazd przywrócony z archiwum!')));
                },
                child: Opacity(
                  opacity: 0.7, // Zarchiwizowane są lekko przezroczyste
                  child: Card(
                    elevation: 1, 
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        final groupObject = _mapFirestoreToGroup(groupDoc);
                        Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => GroupDetailScreen(group: groupObject)));
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(width: 54, height: 54, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(14)), child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black54)))),
                            const SizedBox(width: 16),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 8), Row(children: [const Icon(Icons.group, size: 14, color: Colors.grey), const SizedBox(width: 4), Text('$memberCount', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)), child: Text(currency, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)))])])),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}