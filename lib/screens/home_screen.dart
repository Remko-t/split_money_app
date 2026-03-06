import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group.dart';
import 'group_detail_screen.dart';
import 'settings_screen.dart';
import 'archive_screen.dart'; // <--- DODANY IMPORT ARCHIWUM

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final currentUser = FirebaseAuth.instance.currentUser!;

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  void _addNewGroup(String name, String currency) {
    if (name.isEmpty) return;

    final myName = currentUser.displayName != null && currentUser.displayName!.isNotEmpty 
        ? currentUser.displayName! : 'Ja';

    FirebaseFirestore.instance.collection('groups').add({
      'name': name,
      'ownerId': currentUser.uid,
      'created': Timestamp.now(),
      'inviteCode': _generateInviteCode(),
      'currency': currency,
      'isArchived': false, // <--- USTAWIANA PRZY TWORZENIU
      'memberIds': [currentUser.uid], 
      'membersData': [{'id': currentUser.uid, 'name': myName}], 
      'expensesData': [],
    });
  }

  Future<void> _joinGroup(String code, BuildContext dialogContext) async {
    code = code.trim().toUpperCase();
    if (code.isEmpty) return;

    try {
      final query = await FirebaseFirestore.instance.collection('groups').where('inviteCode', isEqualTo: code).get();
      if (query.docs.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nie znaleziono wyjazdu z takim kodem! ❌')));
        return;
      }

      final doc = query.docs.first;
      final data = doc.data();
      List<dynamic> currentMemberIds = data['memberIds'] ?? [];

      if (currentMemberIds.contains(currentUser.uid)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Już jesteś w tym wyjeździe!')));
        return;
      }

      final myName = currentUser.displayName != null && currentUser.displayName!.isNotEmpty ? currentUser.displayName! : 'Ktoś';

      await doc.reference.update({
        'memberIds': FieldValue.arrayUnion([currentUser.uid]),
        'membersData': FieldValue.arrayUnion([{'id': currentUser.uid, 'name': myName}])
      });

      await doc.reference.update({
        'activitiesData': FieldValue.arrayUnion([{
          'id': DateTime.now().toString(),
          'message': "$myName dołączył(a) do wyjazdu za pomocą kodu!",
          'timestamp': Timestamp.now(),
        }])
      });

      if (mounted) {
        Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dołączono do wyjazdu: ${data['name']}! 🎉')));
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd: $e')));
    }
  }

  void _showAddGroupDialog() {
    final nameController = TextEditingController();
    String selectedCurrency = 'zł';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Nowa Grupa'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nazwa wyjazdu (np. Mazury)'),
                  autofocus: true,
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: selectedCurrency,
                  decoration: const InputDecoration(labelText: 'Waluta rozliczeń'),
                  items: const [
                    DropdownMenuItem(value: 'zł', child: Text('PLN (zł)')),
                    DropdownMenuItem(value: '€', child: Text('EUR (€)')),
                    DropdownMenuItem(value: '\$', child: Text('USD (\$)' )),
                    DropdownMenuItem(value: '£', child: Text('GBP (£)')),
                    DropdownMenuItem(value: 'Kč', child: Text('CZK (Kč)')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedCurrency = val!),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Anuluj')),
              ElevatedButton(
                onPressed: () {
                  _addNewGroup(nameController.text, selectedCurrency);
                  Navigator.of(ctx).pop();
                },
                child: const Text('Utwórz'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showJoinGroupDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dołącz do wyjazdu'),
        content: TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Wpisz 6-znakowy kod', hintText: 'np. X7B9KQ'), textCapitalization: TextCapitalization.characters, autofocus: true),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Anuluj')), ElevatedButton(onPressed: () => _joinGroup(codeController.text, ctx), child: const Text('Dołącz'))],
      ),
    );
  }

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
      isArchived: data['isArchived'] == true, // <--- POBIERAMY Z BAZY
      members: [], 
      expenses: [], 
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: const Text('Twoje Wyjazdy 🌍', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // --- NOWY PRZYCISK: ARCHIWUM ---
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined), 
            tooltip: 'Archiwum', 
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const ArchiveScreen()))
          ),
          IconButton(
            icon: const Icon(Icons.settings), 
            tooltip: 'Ustawienia', 
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const SettingsScreen()))
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('groups').where('memberIds', arrayContains: currentUser.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          // FILTRUJEMY: Odrzucamy zarchiwizowane
          final visibleDocs = snapshot.data?.docs.where((doc) {
            return (doc.data() as Map<String, dynamic>)['isArchived'] != true;
          }).toList() ?? [];

          if (visibleDocs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.beach_access, size: 80, color: Colors.grey), const SizedBox(height: 20), Text('Brak aktywnych wyjazdów.\nKliknij "+" aby dodać pierwszy!', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey))]));
          }

          visibleDocs.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['created'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['created'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            itemCount: visibleDocs.length,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemBuilder: (ctx, index) {
              final groupDoc = visibleDocs[index];
              final groupData = groupDoc.data() as Map<String, dynamic>;
              
              final String name = groupData['name'] ?? 'Bez nazwy';
              final String currency = groupData['currency'] ?? 'zł';
              final Timestamp? createdTs = groupData['created'] as Timestamp?;
              final int memberCount = (groupData['memberIds'] as List?)?.length ?? 1;

              String dateStr = '';
              if (createdTs != null) {
                final date = createdTs.toDate();
                dateStr = "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
              }

              return Dismissible(
                key: Key(groupDoc.id), 
                direction: DismissDirection.horizontal, // <--- Można w obie strony
                
                // Tło przy swajpowaniu w prawo (Archiwizuj)
                background: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: Colors.blueGrey, borderRadius: BorderRadius.circular(16)), 
                  alignment: Alignment.centerLeft, 
                  padding: const EdgeInsets.only(left: 20), 
                  child: const Icon(Icons.inventory_2, color: Colors.white, size: 30)
                ),
                
                // Tło przy swajpowaniu w lewo (Usuń)
                secondaryBackground: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.8), borderRadius: BorderRadius.circular(16)), 
                  alignment: Alignment.centerRight, 
                  padding: const EdgeInsets.only(right: 20), 
                  child: const Icon(Icons.delete_forever, color: Colors.white, size: 30)
                ),

                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    // Czerwone usunięcie
                    return await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Usuń wyjazd'), content: const Text('Czy na pewno chcesz usunąć ten wyjazd ze wszystkimi wydatkami? Tej akcji nie można cofnąć.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('Usuń'))]));
                  } else {
                    // Szara archiwizacja
                    return await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Zarchiwizuj wyjazd 📦'), content: const Text('Ten wyjazd zniknie z głównej listy i trafi do Archiwum. Nie usunie to jego danych i zawsze możesz go stamtąd przywrócić.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('Archiwizuj'))]));
                  }
                },
                onDismissed: (direction) { 
                  if (direction == DismissDirection.endToStart) {
                    FirebaseFirestore.instance.collection('groups').doc(groupDoc.id).delete(); 
                  } else {
                    FirebaseFirestore.instance.collection('groups').doc(groupDoc.id).update({'isArchived': true});
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Przeniesiono do archiwum!')));
                  }
                },
                
                child: Card(
                  elevation: 2, 
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
                          Container(
                            width: 54, height: 54, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
                            child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer))),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.group, size: 14, color: Colors.grey), const SizedBox(width: 4), Text('$memberCount', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                                    const Spacer(),
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)), child: Text(currency, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8), const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(context: context, builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [const Padding(padding: EdgeInsets.all(16.0), child: Text("Co chcesz zrobić?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), ListTile(leading: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 30), title: const Text('Stwórz nowy wyjazd', style: TextStyle(fontSize: 16)), onTap: () { Navigator.pop(ctx); _showAddGroupDialog(); }), ListTile(leading: const Icon(Icons.group_add, color: Colors.green, size: 30), title: const Text('Dołącz po kodzie', style: TextStyle(fontSize: 16)), onTap: () { Navigator.pop(ctx); _showJoinGroupDialog(); }), const SizedBox(height: 20)]));
        },
        label: const Text('Wyjazdy'), icon: const Icon(Icons.menu),
      ),
    );
  }
}