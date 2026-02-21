import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/group.dart';
import '../models/expense.dart';
import '../models/member.dart';
import 'settlement_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _memberController = TextEditingController();
  final _expenseTitleController = TextEditingController();
  final _expenseAmountController = TextEditingController();

  bool _isSearching = false;
  String _searchQuery = "";

  String? _selectedPayerId;
  List<String> _selectedBeneficiaries = [];
  String _selectedCategory = 'other';

  final ImagePicker _picker = ImagePicker();
  String? _selectedReceiptPath;

  final Map<String, Map<String, dynamic>> categories = {
    'food': {'label': 'Jedzenie', 'icon': Icons.restaurant, 'color': Colors.orange},
    'transport': {'label': 'Transport', 'icon': Icons.directions_car, 'color': Colors.blue},
    'home': {'label': 'Nocleg', 'icon': Icons.home, 'color': Colors.purple},
    'entertainment': {'label': 'Rozrywka', 'icon': Icons.movie, 'color': Colors.pink},
    'shopping': {'label': 'Zakupy', 'icon': Icons.shopping_cart, 'color': Colors.green},
    'other': {'label': 'Inne', 'icon': Icons.category, 'color': Colors.grey},
  };

  Future<void> _pickImage(ImageSource source, StateSetter setModalState) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 50);
      if (pickedFile != null) {
        setModalState(() { _selectedReceiptPath = pickedFile.path; });
      }
    } catch (e) {
      debugPrint("Błąd zdjęcia: $e");
    }
  }

  void _showReceiptDialog(String path) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 450),
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Zamknij"),
            )
          ],
        ),
      ),
    );
  }

  void _addMember() {
    final name = _memberController.text.trim();
    if (name.isNotEmpty) {
      final newMember = {'id': DateTime.now().toString(), 'name': name};
      FirebaseFirestore.instance.collection('groups').doc(widget.group.id).update({
        'membersData': FieldValue.arrayUnion([newMember])
      });
      _memberController.clear();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dodano osobę: $name')));
    }
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dodaj Uczestnika'),
        content: TextField(
          controller: _memberController,
          decoration: const InputDecoration(labelText: 'Imię'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Anuluj')),
          ElevatedButton(onPressed: _addMember, child: const Text('Dodaj')),
        ],
      ),
    );
  }

  // --- NOWE FUNKCJE: EDYCJA I USUWANIE UCZESTNIKA ---
  void _editMember(Member member) {
    final editController = TextEditingController(text: member.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edytuj uczestnika'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(labelText: 'Zmień imię'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
          ElevatedButton(
            onPressed: () async {
              final newName = editController.text.trim();
              if (newName.isNotEmpty && newName != member.name) {
                final docRef = FirebaseFirestore.instance.collection('groups').doc(widget.group.id);
                final doc = await docRef.get();
                final currentData = doc.data()?['membersData'] as List<dynamic>? ?? [];
                
                // Podmieniamy imię osoby w tablicy
                final updatedList = currentData.map((m) {
                  return m['id'] == member.id ? {'id': member.id, 'name': newName} : m;
                }).toList();
                
                await docRef.update({'membersData': updatedList});
              }
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMember(Member member) async {
    // 1. Sprawdzamy, czy osoba nie jest połączona z żadnym wydatkiem
    final hasExpenses = widget.group.expenses.any((e) => 
        e.payerId == member.id || e.beneficiaryIds.contains(member.id));
        
    if (hasExpenses) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie można usunąć uczestnika, który bierze udział w wydatkach!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. Potwierdzenie usunięcia
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń uczestnika'),
        content: Text('Czy na pewno chcesz usunąć osobę: ${member.name}?'),
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

    // 3. Wyrzucamy z bazy
    if (confirm == true) {
      final docRef = FirebaseFirestore.instance.collection('groups').doc(widget.group.id);
      final doc = await docRef.get();
      final currentData = doc.data()?['membersData'] as List<dynamic>? ?? [];
      
      final updatedList = currentData.where((m) => m['id'] != member.id).toList();
      
      await docRef.update({
        'membersData': updatedList,
        'memberIds': FieldValue.arrayRemove([member.id]) // Usuwamy też ewentualny dostęp konta
      });
    }
  }
  // ---------------------------------------------------

  Future<void> _saveExpense({String? existingId}) async {
    final title = _expenseTitleController.text.trim();
    final amount = double.tryParse(_expenseAmountController.text) ?? 0;

    if (title.isEmpty || amount <= 0 || _selectedPayerId == null || _selectedBeneficiaries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wypełnij poprawnie wszystkie pola i wybierz osoby!')),
      );
      return;
    }

    final expenseMap = {
      'id': existingId ?? DateTime.now().toString(),
      'title': title,
      'amount': amount,
      'payerId': _selectedPayerId,
      'beneficiaryIds': _selectedBeneficiaries,
      'date': Timestamp.now(),
      'category': _selectedCategory,
      'receiptPath': _selectedReceiptPath,
    };

    final docRef = FirebaseFirestore.instance.collection('groups').doc(widget.group.id);

    if (existingId == null) {
      await docRef.update({
        'expensesData': FieldValue.arrayUnion([expenseMap])
      });
    } else {
      final doc = await docRef.get();
      final currentData = doc.data()?['expensesData'] as List<dynamic>? ?? [];
      final updatedList = currentData.map((e) {
        return (e['id'] == existingId) ? expenseMap : e;
      }).toList();
      await docRef.update({'expensesData': updatedList});
    }

    _expenseTitleController.clear();
    _expenseAmountController.clear();
    _selectedReceiptPath = null;
    
    if (mounted) Navigator.of(context).pop();
  }

  void _showAddExpenseSheet({Expense? existingExpense}) {
    if (widget.group.members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Najpierw dodaj uczestników!')),
      );
      return;
    }

    final isEditing = existingExpense != null;

    if (isEditing) {
      _expenseTitleController.text = existingExpense.title;
      _expenseAmountController.text = existingExpense.amount.toString();
      _selectedPayerId = existingExpense.payerId;
      _selectedBeneficiaries = List.from(existingExpense.beneficiaryIds);
      _selectedCategory = existingExpense.category;
      _selectedReceiptPath = existingExpense.receiptPath;
    } else {
      _expenseTitleController.clear();
      _expenseAmountController.clear();
      _selectedPayerId = widget.group.members.first.id;
      _selectedBeneficiaries = widget.group.members.map((m) => m.id).toList();
      _selectedCategory = 'other';
      _selectedReceiptPath = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20, right: 20, top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(isEditing ? 'Edytuj Wydatek' : 'Nowy Wydatek', style: Theme.of(context).textTheme.titleLarge),
                    
                    TextField(
                      controller: _expenseTitleController,
                      decoration: const InputDecoration(labelText: 'Tytuł (np. Pizza)'),
                    ),
                    TextField(
                      controller: _expenseAmountController,
                      decoration: const InputDecoration(labelText: 'Kwota (zł)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'Kategoria'),
                      items: categories.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Row(
                            children: [
                              Icon(entry.value['icon'] as IconData, color: entry.value['color'] as Color),
                              const SizedBox(width: 10),
                              Text(entry.value['label'] as String),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setModalState(() { _selectedCategory = val!; });
                      },
                    ),
                    const SizedBox(height: 15),
                    
                    const Text("Paragon (opcjonalnie):", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (_selectedReceiptPath != null)
                          Stack(
                            children: [
                              Container(
                                width: 80, height: 80,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: FileImage(File(_selectedReceiptPath!)),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0, top: 0,
                                child: GestureDetector(
                                  onTap: () => setModalState(() => _selectedReceiptPath = null),
                                  child: const CircleAvatar(
                                    radius: 10, backgroundColor: Colors.red,
                                    child: Icon(Icons.close, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextButton.icon(
                              onPressed: () => _pickImage(ImageSource.camera, setModalState),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text("Zrób zdjęcie"),
                            ),
                            TextButton.icon(
                              onPressed: () => _pickImage(ImageSource.gallery, setModalState),
                              icon: const Icon(Icons.photo_library),
                              label: const Text("Z galerii"),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    DropdownButtonFormField<String>(
                      value: _selectedPayerId,
                      decoration: const InputDecoration(labelText: 'Kto płacił?'),
                      items: widget.group.members.map((m) {
                        return DropdownMenuItem(value: m.id, child: Text(m.name));
                      }).toList(),
                      onChanged: (val) {
                        setModalState(() { _selectedPayerId = val; });
                      },
                    ),
                    const SizedBox(height: 15),

                    const Text('Dla kogo (kto z tego korzystał):', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...widget.group.members.map((m) {
                      return CheckboxListTile(
                        title: Text(m.name),
                        value: _selectedBeneficiaries.contains(m.id),
                        onChanged: (bool? checked) {
                          setModalState(() {
                            if (checked == true) {
                              _selectedBeneficiaries.add(m.id);
                            } else {
                              _selectedBeneficiaries.remove(m.id);
                            }
                          });
                        },
                      );
                    }),

                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => _saveExpense(existingId: isEditing ? existingExpense.id : null),
                      child: Text(isEditing ? 'Zapisz zmiany' : 'Dodaj Wydatek'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // USUNIĘTO sztywne "color: Colors.black" z AppBar, żeby działało w Dark Mode
        title: _isSearching
            ? TextField(
                autofocus: true,
                style: const TextStyle(fontSize: 18), 
                decoration: const InputDecoration(
                  hintText: 'Szukaj wydatku...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() { _searchQuery = value; });
                },
              )
            : Text(widget.group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart),
            tooltip: "Podsumowanie",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => SettlementScreen(group: widget.group)),
              );
            },
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = "";
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: "Dodaj osobę",
              onPressed: _showAddMemberDialog,
            )
        ],
      ),
      
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('groups').doc(widget.group.id).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return const Center(child: Text("Błąd ładowania danych grupy."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          
          final rawMembers = data['membersData'] as List<dynamic>? ?? [];
          final cloudMembers = rawMembers.map((m) => Member(id: m['id'], name: m['name'])).toList();
          
          final rawExpenses = data['expensesData'] as List<dynamic>? ?? [];
          final cloudExpenses = rawExpenses.map((e) {
            return Expense(
              id: e['id'],
              title: e['title'],
              amount: (e['amount'] as num).toDouble(),
              payerId: e['payerId'],
              date: (e['date'] as Timestamp).toDate(),
              beneficiaryIds: List<String>.from(e['beneficiaryIds'] ?? []),
              category: e['category'] ?? 'other',
              receiptPath: e['receiptPath'],
            );
          }).toList();

          widget.group.members = cloudMembers;
          widget.group.expenses = cloudExpenses;

          final displayedExpenses = cloudExpenses.where((expense) {
            final searchLower = _searchQuery.toLowerCase();
            final titleLower = expense.title.toLowerCase();
            return titleLower.contains(searchLower) || expense.category.contains(searchLower);
          }).toList().reversed.toList(); 

          return Column(
            children: [
              // PASEK Z UCZESTNIKAMI (Teraz z edycją i usuwaniem)
              Container(
                height: 80,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                child: cloudMembers.isEmpty 
                  ? const Center(child: Text("Brak uczestników"))
                  : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: cloudMembers.length,
                    itemBuilder: (ctx, index) {
                      final member = cloudMembers[index];
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        // ZAMIANA: Chip -> InputChip (pozwala na interakcję i ma krzyżyk do usunięcia)
                        child: InputChip(
                          avatar: CircleAvatar(child: Text(member.name.isNotEmpty ? member.name[0].toUpperCase() : '?')),
                          label: Text(member.name),
                          onPressed: () => _editMember(member), // Kliknięcie -> Edycja
                          onDeleted: () => _deleteMember(member), // Kliknięcie w 'X' -> Usuwanie
                        ),
                      );
                    },
                  ),
              ),
              const Divider(height: 1),
              
              // LISTA WYDATKÓW
              Expanded(
                child: cloudExpenses.isEmpty
                    ? const Center(child: Text("Brak wydatków. Dodaj pierwszy!"))
                    : displayedExpenses.isEmpty
                        ? const Center(child: Text("Nie znaleziono pasujących wydatków."))
                        : ListView.builder(
                            itemCount: displayedExpenses.length,
                            itemBuilder: (ctx, index) {
                              final expense = displayedExpenses[index];
                              
                              final payerName = cloudMembers
                                  .firstWhere((m) => m.id == expense.payerId, orElse: () => Member(id: '', name: '?'))
                                  .name;

                              final catData = categories[expense.category] ?? categories['other']!;

                              return Dismissible(
                                key: Key(expense.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: Colors.red.withOpacity(0.8),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.delete_forever, color: Colors.white),
                                ),
                                onDismissed: (direction) async {
                                  final docRef = FirebaseFirestore.instance.collection('groups').doc(widget.group.id);
                                  final currentDoc = await docRef.get();
                                  final currentData = currentDoc.data()?['expensesData'] as List<dynamic>? ?? [];
                                  
                                  final updatedList = currentData.where((e) => e['id'] != expense.id).toList();
                                  
                                  await docRef.update({'expensesData': updatedList});

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Wydatek usunięty z chmury')),
                                    );
                                  }
                                },
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: (catData['color'] as Color).withOpacity(0.2),
                                    child: Icon(catData['icon'] as IconData, color: catData['color'] as Color),
                                  ),
                                  title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Płacił: $payerName'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (expense.receiptPath != null)
                                        IconButton(
                                          icon: const Icon(Icons.receipt_long, color: Colors.blueGrey),
                                          onPressed: () => _showReceiptDialog(expense.receiptPath!),
                                        ),
                                      Text(
                                        '${expense.amount.toStringAsFixed(2)} zł',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    _showAddExpenseSheet(existingExpense: expense);
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseSheet(),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Wydatek'),
      ),
    );
  }
}