import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/group.dart';
import '../models/expense.dart';
import '../models/member.dart';
import 'settlement_screen.dart';
import 'history_screen.dart';

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

  String _sortBy = 'newest'; 
  bool _filterMyExpenses = false;
  String _filterCategory = 'all';

  String? _selectedPayerId;
  List<String> _selectedBeneficiaries = [];
  String _selectedCategory = 'other';
  DateTime _selectedExpenseDate = DateTime.now();

  final ImagePicker _picker = ImagePicker();
  String? _selectedReceiptPath;

  final Map<String, Map<String, dynamic>> categories = {
    'food': {'label': 'Jedzenie', 'icon': Icons.restaurant, 'color': Colors.orange},
    'transport': {'label': 'Transport', 'icon': Icons.directions_car, 'color': Colors.blue},
    'home': {'label': 'Nocleg', 'icon': Icons.home, 'color': Colors.purple},
    'entertainment': {'label': 'Rozrywka', 'icon': Icons.movie, 'color': Colors.pink},
    'shopping': {'label': 'Zakupy', 'icon': Icons.shopping_cart, 'color': Colors.green},
    'other': {'label': 'Inne', 'icon': Icons.category, 'color': Colors.grey},
    'repayment': {'label': 'Spłata długu', 'icon': Icons.handshake, 'color': Colors.teal},
  };

  String _getWeekdayName(int weekday) {
    const days = ['Poniedziałek', 'Wtorek', 'Środa', 'Czwartek', 'Piątek', 'Sobota', 'Niedziela'];
    return days[weekday - 1];
  }

  Future<void> _logActivity(String message) async {
    final userName = FirebaseAuth.instance.currentUser?.displayName ?? 'Ktoś';
    final fullMessage = "$userName $message";
    await FirebaseFirestore.instance.collection('groups').doc(widget.group.id).update({
      'activitiesData': FieldValue.arrayUnion([{'id': DateTime.now().toString(), 'message': fullMessage, 'timestamp': Timestamp.now()}])
    });
  }

  Future<void> _pickImage(ImageSource source, StateSetter setModalState) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 50);
      if (pickedFile != null) setModalState(() { _selectedReceiptPath = pickedFile.path; });
    } catch (e) { debugPrint("Błąd zdjęcia: $e"); }
  }

  void _showReceiptDialog(String path) {
    showDialog(context: context, builder: (ctx) => Dialog(child: Column(mainAxisSize: MainAxisSize.min, children: [ConstrainedBox(constraints: const BoxConstraints(maxHeight: 450), child: Image.file(File(path), fit: BoxFit.contain)), TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Zamknij"))])));
  }

  void _addMember() {
    final name = _memberController.text.trim();
    if (name.isNotEmpty) {
      final newMember = {'id': DateTime.now().toString(), 'name': name};
      FirebaseFirestore.instance.collection('groups').doc(widget.group.id).update({ 'membersData': FieldValue.arrayUnion([newMember]) });
      _logActivity('dodał(a) uczestnika lokalnego: $name');
      _memberController.clear();
      Navigator.of(context).pop();
    }
  }

  void _showAddMemberDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Dodaj Uczestnika bez aplikacji'), content: TextField(controller: _memberController, decoration: const InputDecoration(labelText: 'Imię'), autofocus: true), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Anuluj')), ElevatedButton(onPressed: _addMember, child: const Text('Dodaj'))]));
  }

  void _editMember(Member member) {
    final editController = TextEditingController(text: member.name);
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Edytuj uczestnika'), content: TextField(controller: editController, decoration: const InputDecoration(labelText: 'Zmień imię'), autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')), ElevatedButton(onPressed: () async {
      final newName = editController.text.trim();
      if (newName.isNotEmpty && newName != member.name) {
        final docRef = FirebaseFirestore.instance.collection('groups').doc(widget.group.id);
        final doc = await docRef.get();
        final currentData = doc.data()?['membersData'] as List<dynamic>? ?? [];
        final updatedList = currentData.map((m) => m['id'] == member.id ? {'id': member.id, 'name': newName} : m).toList();
        await docRef.update({'membersData': updatedList});
        _logActivity('zmienił(a) imię: ${member.name} ➔ $newName');
      }
      if (mounted) Navigator.pop(ctx);
    }, child: const Text('Zapisz'))]));
  }

  Future<void> _deleteMember(Member member) async {
    final hasExpenses = widget.group.expenses.any((e) => e.payerId == member.id || e.beneficiaryIds.contains(member.id));
    if (hasExpenses) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nie można usunąć uczestnika, który brał udział w wydatkach!'), backgroundColor: Colors.red));
      return;
    }
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Usuń uczestnika'), content: Text('Czy na pewno chcesz usunąć osobę: ${member.name}?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('Usuń'))]));
    if (confirm == true) {
      final docRef = FirebaseFirestore.instance.collection('groups').doc(widget.group.id);
      final doc = await docRef.get();
      final currentData = doc.data()?['membersData'] as List<dynamic>? ?? [];
      final updatedList = currentData.where((m) => m['id'] != member.id).toList();
      await docRef.update({'membersData': updatedList, 'memberIds': FieldValue.arrayRemove([member.id])});
      _logActivity('usunął/ęła uczestnika: ${member.name}');
    }
  }

  Future<void> _claimProfile(Member localMember) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final myName = FirebaseAuth.instance.currentUser?.displayName ?? 'Ja';

    if (localMember.id == myUid) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('To Twój profil?'),
        content: Text('Czy chcesz przypisać profil "${localMember.name}" do swojego konta?\n\nWydatki zostaną zachowane, a profil zaktualizuje się na Twoje dane.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tak, to ja!'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final docRef = FirebaseFirestore.instance.collection('groups').doc(widget.group.id);
      final doc = await docRef.get();
      final data = doc.data() ?? {};

      final currentExpenses = data['expensesData'] as List<dynamic>? ?? [];
      List<dynamic> currentMembers = data['membersData'] as List<dynamic>? ?? [];

      final updatedExpenses = currentExpenses.map((e) {
        final expenseMap = Map<String, dynamic>.from(e);
        if (expenseMap['payerId'] == localMember.id) {
          expenseMap['payerId'] = myUid;
        }
        final beneficiaries = List<String>.from(expenseMap['beneficiaryIds'] ?? []);
        if (beneficiaries.contains(localMember.id)) {
          beneficiaries.remove(localMember.id);
          if (!beneficiaries.contains(myUid)) beneficiaries.add(myUid);
          expenseMap['beneficiaryIds'] = beneficiaries;
        }
        return expenseMap;
      }).toList();

      final filteredMembers = currentMembers.where((m) => m['id'] != localMember.id && m['id'] != myUid).toList();
      filteredMembers.add({'id': myUid, 'name': myName});

      await docRef.update({
        'expensesData': updatedExpenses,
        'membersData': filteredMembers,
      });

      _logActivity('połączył(a) swój profil z: ${localMember.name}');
      
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil zaktualizowany i połączony! 🎉')));
      }
    }
  }

  void _showManageMembersSheet() {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('groups').doc(widget.group.id).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data?.data() == null) return const SizedBox.shrink();
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final rawMembers = data['membersData'] as List<dynamic>? ?? [];
            final currentMembers = rawMembers.map((m) => Member(id: m['id'], name: m['name'])).toList();

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 20, left: 16, right: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Zarządzaj uczestnikami', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: currentMembers.length,
                    itemBuilder: (context, index) {
                      final m = currentMembers[index];
                      final isMe = m.id == myUid;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.primaries[index % Colors.primaries.length].withOpacity(0.8),
                          child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        ),
                        title: Row(
                          children: [
                            Text(m.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                            if (isMe) 
                              const Padding(padding: EdgeInsets.only(left: 8.0), child: Text('(Ty)', style: TextStyle(color: Colors.grey, fontSize: 12)))
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isMe)
                              IconButton(
                                icon: const Icon(Icons.link, color: Colors.teal),
                                tooltip: 'Przypisz ten profil do siebie',
                                onPressed: () => _claimProfile(m),
                              ),
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blueGrey), onPressed: () => _editMember(m)),
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteMember(m)),
                          ]
                        )
                      );
                    }
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showAddMemberDialog();
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Dodaj nową osobę lokalnie'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  ),
                  const SizedBox(height: 20),
                ]
              )
            );
          }
        );
      }
    );
  }

  Widget _buildStackedAvatars(List<Member> members) {
    if (members.isEmpty) return const Text("Brak uczestników", style: TextStyle(color: Colors.grey));
    
    int maxAvatars = 8; 
    int displayCount = members.length > maxAvatars ? maxAvatars - 1 : members.length;
    int remaining = members.length - displayCount;

    List<Widget> stackChildren = [];
    for (int i = 0; i < displayCount; i++) {
      stackChildren.add(
        Positioned(
          left: i * 26.0,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
            ),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.primaries[i % Colors.primaries.length].withOpacity(0.9),
              child: Text(
                members[i].name.isNotEmpty ? members[i].name[0].toUpperCase() : '?', 
                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)
              ),
            ),
          ),
        ),
      );
    }

    if (remaining > 0) {
      stackChildren.add(
        Positioned(
          left: displayCount * 26.0,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
            ),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text('+$remaining', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: (displayCount * 26.0) + (remaining > 0 ? 32.0 : 32.0),
      height: 32,
      child: Stack(children: stackChildren),
    );
  }

  Future<void> _saveExpense({String? existingId}) async {
    final title = _expenseTitleController.text.trim();
    final amount = double.tryParse(_expenseAmountController.text) ?? 0;
    if (title.isEmpty || amount <= 0 || _selectedPayerId == null || _selectedBeneficiaries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wypełnij poprawnie wszystkie pola i wybierz osoby!')));
      return;
    }
    final expenseMap = {
      'id': existingId ?? DateTime.now().toString(), 'title': title, 'amount': amount, 'payerId': _selectedPayerId,
      'beneficiaryIds': _selectedBeneficiaries, 'date': Timestamp.fromDate(_selectedExpenseDate), 'category': _selectedCategory, 'receiptPath': _selectedReceiptPath,
    };
    final docRef = FirebaseFirestore.instance.collection('groups').doc(widget.group.id);
    if (existingId == null) {
      await docRef.update({'expensesData': FieldValue.arrayUnion([expenseMap])});
      _logActivity('dodał(a) wydatek: $title (${amount.toStringAsFixed(2)} ${widget.group.currency})');
    } else {
      final doc = await docRef.get();
      final currentData = doc.data()?['expensesData'] as List<dynamic>? ?? [];
      final updatedList = currentData.map((e) => (e['id'] == existingId) ? expenseMap : e).toList();
      await docRef.update({'expensesData': updatedList});
      _logActivity('edytował(a) wydatek: $title');
    }
    _expenseTitleController.clear();
    _expenseAmountController.clear();
    _selectedReceiptPath = null;
    if (mounted) Navigator.of(context).pop();
  }

  void _showAddExpenseSheet({Expense? existingExpense}) {
    final uniqueMembers = <Member>[];
    final seenIds = <String>{};
    for (var m in widget.group.members) {
      if (!seenIds.contains(m.id)) {
        seenIds.add(m.id);
        uniqueMembers.add(m);
      }
    }

    if (uniqueMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brak uczestników!')));
      return;
    }

    final isEditing = existingExpense != null;
    if (isEditing) {
      _expenseTitleController.text = existingExpense.title; _expenseAmountController.text = existingExpense.amount.toString();
      _selectedPayerId = existingExpense.payerId; _selectedBeneficiaries = List.from(existingExpense.beneficiaryIds);
      _selectedCategory = existingExpense.category; _selectedReceiptPath = existingExpense.receiptPath; _selectedExpenseDate = existingExpense.date;
      
      if (!uniqueMembers.any((m) => m.id == _selectedPayerId)) {
        _selectedPayerId = uniqueMembers.first.id;
      }
    } else {
      _expenseTitleController.clear(); _expenseAmountController.clear(); _selectedPayerId = uniqueMembers.first.id;
      _selectedBeneficiaries = uniqueMembers.map((m) => m.id).toList(); _selectedCategory = 'other';
      _selectedReceiptPath = null; _selectedExpenseDate = DateTime.now();
    }
    
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final dateString = "${_selectedExpenseDate.day.toString().padLeft(2,'0')}.${_selectedExpenseDate.month.toString().padLeft(2,'0')}.${_selectedExpenseDate.year}";
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(isEditing ? 'Edytuj Wydatek' : 'Nowy Wydatek', style: Theme.of(context).textTheme.titleLarge), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop())]),
                    TextField(controller: _expenseTitleController, decoration: const InputDecoration(labelText: 'Tytuł (np. Pizza)')),
                    TextField(controller: _expenseAmountController, decoration: InputDecoration(labelText: 'Kwota (${widget.group.currency})'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero, title: Text('Data zakupu: $dateString', style: const TextStyle(fontWeight: FontWeight.bold)), trailing: const Icon(Icons.calendar_today, color: Colors.blue),
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: _selectedExpenseDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                        if (picked != null) setModalState(() => _selectedExpenseDate = picked);
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory, decoration: const InputDecoration(labelText: 'Kategoria'),
                      items: categories.entries.map((entry) => DropdownMenuItem<String>(value: entry.key, child: Row(children: [Icon(entry.value['icon'] as IconData, color: entry.value['color'] as Color), const SizedBox(width: 10), Text(entry.value['label'] as String)]))).toList(),
                      onChanged: (val) => setModalState(() { _selectedCategory = val!; }),
                    ),
                    const SizedBox(height: 15),
                    const Text("Paragon (opcjonalnie):", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (_selectedReceiptPath != null) Stack(children: [Container(width: 80, height: 80, margin: const EdgeInsets.only(right: 10), decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8), image: DecorationImage(image: FileImage(File(_selectedReceiptPath!)), fit: BoxFit.cover))), Positioned(right: 0, top: 0, child: GestureDetector(onTap: () => setModalState(() => _selectedReceiptPath = null), child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white))))]),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [TextButton.icon(onPressed: () => _pickImage(ImageSource.camera, setModalState), icon: const Icon(Icons.camera_alt), label: const Text("Zrób zdjęcie")), TextButton.icon(onPressed: () => _pickImage(ImageSource.gallery, setModalState), icon: const Icon(Icons.photo_library), label: const Text("Z galerii"))]),
                      ],
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: _selectedPayerId, decoration: const InputDecoration(labelText: 'Kto płacił?'),
                      items: uniqueMembers.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
                      onChanged: (val) => setModalState(() { _selectedPayerId = val; }),
                    ),
                    const SizedBox(height: 15),
                    const Text('Dla kogo (kto z tego korzystał):', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...uniqueMembers.map((m) {
                      return CheckboxListTile(title: Text(m.name), value: _selectedBeneficiaries.contains(m.id), onChanged: (bool? checked) { setModalState(() { if (checked == true) _selectedBeneficiaries.add(m.id); else _selectedBeneficiaries.remove(m.id); }); });
                    }),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anuluj', style: TextStyle(color: Colors.grey))), const SizedBox(width: 10), ElevatedButton(onPressed: () => _saveExpense(existingId: isEditing ? existingExpense.id : null), child: Text(isEditing ? 'Zapisz zmiany' : 'Dodaj Wydatek'))],
                    ),
                    const SizedBox(height: 10), 
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
        title: _isSearching
            ? TextField(
                autofocus: true, style: const TextStyle(fontSize: 18), 
                decoration: const InputDecoration(hintText: 'Szukaj wydatku...', border: InputBorder.none),
                onChanged: (value) => setState(() { _searchQuery = value; }),
              )
            : Text(widget.group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.blue),
            tooltip: "Zaproś znajomych",
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Zaproś znajomych 🌍', textAlign: TextAlign.center),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Podaj znajomym ten kod, aby mogli dołączyć do wyjazdu w swojej aplikacji:', textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                        child: Text(widget.group.inviteCode ?? 'Brak kodu', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                      ),
                    ],
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Gotowe'))],
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.history, color: Colors.purple), tooltip: "Historia", onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => HistoryScreen(group: widget.group)))),
          IconButton(icon: const Icon(Icons.pie_chart, color: Colors.green), tooltip: "Podsumowanie", onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => SettlementScreen(group: widget.group)))),
          IconButton(icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.orange), onPressed: () => setState(() { if (_isSearching) { _isSearching = false; _searchQuery = ""; } else { _isSearching = true; } })),
          if (!_isSearching)
            IconButton(icon: const Icon(Icons.manage_accounts, color: Colors.redAccent), tooltip: 'Zarządzaj uczestnikami', onPressed: _showManageMembersSheet)
        ],
      ),
      
      // --- ZMIANA: Dodano nasłuchiwanie na metadane cache (Offline) ---
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('groups').doc(widget.group.id).snapshots(includeMetadataChanges: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data?.data() == null) return const Center(child: Text("Błąd ładowania."));

          // Sprawdzamy, czy dane są ładowane z pamięci telefonu (brak neta)
          final bool isOffline = snapshot.data!.metadata.isFromCache;
          
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final rawMembers = data['membersData'] as List<dynamic>? ?? [];
          final cloudMembers = rawMembers.map((m) => Member(id: m['id'], name: m['name'])).toList();
          
          final rawExpenses = data['expensesData'] as List<dynamic>? ?? [];
          final cloudExpenses = rawExpenses.map((e) {
            return Expense(
              id: e['id'], title: e['title'], amount: (e['amount'] as num).toDouble(),
              payerId: e['payerId'], date: (e['date'] as Timestamp).toDate(),
              beneficiaryIds: List<String>.from(e['beneficiaryIds'] ?? []), category: e['category'] ?? 'other', receiptPath: e['receiptPath'],
            );
          }).toList();

          widget.group.members = cloudMembers;
          widget.group.expenses = cloudExpenses;

          final displayedExpenses = cloudExpenses.where((expense) {
            if (_searchQuery.isNotEmpty) {
              final searchLower = _searchQuery.toLowerCase();
              if (!expense.title.toLowerCase().contains(searchLower) && !expense.category.contains(searchLower)) return false;
            }
            if (_filterMyExpenses) {
              final myId = FirebaseAuth.instance.currentUser?.uid;
              if (myId != null && expense.payerId != myId && !expense.beneficiaryIds.contains(myId)) return false;
            }
            if (_filterCategory != 'all' && expense.category != _filterCategory) return false;
            return true;
          }).toList(); 

          displayedExpenses.sort((a, b) {
            if (_sortBy == 'newest') return b.date.compareTo(a.date);
            if (_sortBy == 'oldest') return a.date.compareTo(b.date);
            if (_sortBy == 'highest') return b.amount.compareTo(a.amount);
            if (_sortBy == 'lowest') return a.amount.compareTo(b.amount);
            return 0;
          });

          return Column(
            children: [
              // --- NOWOŚĆ: PASEK OFFLINE ---
              if (isOffline)
                Container(
                  width: double.infinity,
                  color: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: const Text(
                    'Brak internetu. Działasz w trybie offline ☁️',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),

              InkWell(
                onTap: _showManageMembersSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2),
                  child: Row(
                    children: [
                      const Icon(Icons.group, color: Colors.blueGrey, size: 20),
                      const SizedBox(width: 8),
                      const Text('Uczestnicy: ', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      _buildStackedAvatars(cloudMembers),
                      const Spacer(),
                      const Icon(Icons.edit, color: Colors.grey, size: 18),
                    ],
                  ),
                ),
              ),
              
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: const Text('Tylko moje'),
                        selected: _filterMyExpenses,
                        onSelected: (val) => setState(() => _filterMyExpenses = val),
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: PopupMenuButton<String>(
                        initialValue: _sortBy,
                        onSelected: (val) => setState(() => _sortBy = val),
                        itemBuilder: (ctx) => const [
                          PopupMenuItem(value: 'newest', child: Text('🗓️ Najnowsze')),
                          PopupMenuItem(value: 'oldest', child: Text('🗓️ Najstarsze')),
                          PopupMenuItem(value: 'highest', child: Text('💰 Najdroższe')),
                          PopupMenuItem(value: 'lowest', child: Text('🪙 Najtańsze')),
                        ],
                        child: Chip(
                          label: Row(children: [Text(_sortBy == 'newest' ? 'Najnowsze' : _sortBy == 'oldest' ? 'Najstarsze' : _sortBy == 'highest' ? 'Najdroższe' : 'Najtańsze'), const Icon(Icons.arrow_drop_down, size: 18)]),
                          backgroundColor: _sortBy != 'newest' ? Theme.of(context).colorScheme.primaryContainer : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: PopupMenuButton<String>(
                        initialValue: _filterCategory,
                        onSelected: (val) => setState(() => _filterCategory = val),
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'all', child: Text('Wszystkie kategorie')),
                          ...categories.entries.map((e) => PopupMenuItem(value: e.key, child: Text(e.value['label']))),
                        ],
                        child: Chip(
                          label: Row(children: [Text(_filterCategory == 'all' ? 'Kategoria' : categories[_filterCategory]!['label']), const Icon(Icons.arrow_drop_down, size: 18)]),
                          backgroundColor: _filterCategory != 'all' ? Theme.of(context).colorScheme.primaryContainer : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              Expanded(
                child: cloudExpenses.isEmpty
                    ? const Center(child: Text("Brak wydatków. Dodaj pierwszy!"))
                    : displayedExpenses.isEmpty
                        ? const Center(child: Text("Nie znaleziono wydatków dla tych filtrów."))
                        : ListView.builder(
                            itemCount: displayedExpenses.length,
                            itemBuilder: (ctx, index) {
                              final expense = displayedExpenses[index];
                              
                              bool showDateHeader = false;
                              if (_sortBy == 'newest' || _sortBy == 'oldest') {
                                if (index == 0) {
                                  showDateHeader = true; 
                                } else {
                                  final prevExpense = displayedExpenses[index - 1];
                                  if (expense.date.year != prevExpense.date.year ||
                                      expense.date.month != prevExpense.date.month ||
                                      expense.date.day != prevExpense.date.day) {
                                    showDateHeader = true;
                                  }
                                }
                              }

                              final payerName = cloudMembers.firstWhere((m) => m.id == expense.payerId, orElse: () => Member(id: '', name: '?')).name;
                              final catData = categories[expense.category] ?? categories['other']!;
                              final dateStr = "${expense.date.day.toString().padLeft(2,'0')}.${expense.date.month.toString().padLeft(2,'0')}.${expense.date.year}";

                              Widget expenseTile = Dismissible(
                                key: Key(expense.id),
                                direction: DismissDirection.endToStart,
                                background: Container(color: Colors.red.withOpacity(0.8), alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete_forever, color: Colors.white)),
                                onDismissed: (direction) async {
                                  final docRef = FirebaseFirestore.instance.collection('groups').doc(widget.group.id);
                                  final currentDoc = await docRef.get();
                                  final currentData = currentDoc.data()?['expensesData'] as List<dynamic>? ?? [];
                                  final updatedList = currentData.where((e) => e['id'] != expense.id).toList();
                                  await docRef.update({'expensesData': updatedList});
                                  _logActivity('usunął/ęła wydatek: ${expense.title}');
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wydatek usunięty')));
                                },
                                child: ListTile(
                                  leading: CircleAvatar(backgroundColor: (catData['color'] as Color).withOpacity(0.2), child: Icon(catData['icon'] as IconData, color: catData['color'] as Color)),
                                  title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Płacił: $payerName'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (expense.receiptPath != null) IconButton(icon: const Icon(Icons.receipt_long, color: Colors.blueGrey), onPressed: () => _showReceiptDialog(expense.receiptPath!)),
                                      Text('${expense.amount.toStringAsFixed(2)} ${widget.group.currency}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  onTap: () => _showAddExpenseSheet(existingExpense: expense),
                                ),
                              );

                              if (showDateHeader) {
                                final dayName = _getWeekdayName(expense.date.weekday);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
                                      child: Text("$dateStr • $dayName", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                                    ),
                                    expenseTile,
                                  ],
                                );
                              }

                              return expenseTile;
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