// plik: lib/screens/group_detail_screen.dart
import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../models/expense.dart';
import 'settlement_screen.dart'; // Import ekranu rozliczeń

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
  String _selectedCategory = 'other'; // Domyślnie "Inne"
  String? _selectedPayerId;
  // To będzie trzymać zaznaczone osoby podczas dodawania
List<String> _selectedBeneficiaries = [];

  // --- Funkcje do obsługi Członków ---

  void _addMember() {
    if (_memberController.text.isEmpty) return;
    
    setState(() {
      widget.group.members.add(
        Member(id: DateTime.now().toString(), name: _memberController.text),
      );
    });

    // ZAPIS HIVE: To jest kluczowe! Zapisujemy stan obiektu na dysku.
    widget.group.save(); 

    _memberController.clear();
    Navigator.pop(context);
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dodaj osobę'),
        content: TextField(
          controller: _memberController,
          decoration: const InputDecoration(labelText: 'Imię'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
          FilledButton(onPressed: _addMember, child: const Text('Dodaj')),
        ],
      ),
    );
  }

  // --- Funkcje do obsługi Wydatków ---

  void _addExpense() {
  final title = _expenseTitleController.text;
  final amount = double.tryParse(_expenseAmountController.text);

  // Walidacja: Musi być tytuł, kwota > 0, płatnik ORAZ przynajmniej 1 osoba obciążona
  if (title.isEmpty || amount == null || amount <= 0 || _selectedPayerId == null || _selectedBeneficiaries.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('Uzupełnij dane i wybierz kogo obciążyć!')),
    );
    return;
  }

  setState(() {
    widget.group.expenses.add(
      Expense(
        id: DateTime.now().toString(),
        title: title,
        amount: amount,
        payerId: _selectedPayerId!,
        date: DateTime.now(),
        beneficiaryIds: List.from(_selectedBeneficiaries), // Kopiujemy listę
        category: _selectedCategory
      ),
    );
  });

  widget.group.save(); // Zapis do Hive

  _expenseTitleController.clear();
  _expenseAmountController.clear();
  _selectedPayerId = null;
  _selectedBeneficiaries = []; // Reset
  Navigator.pop(context);
  _selectedCategory = 'other';
}

  void _showAddExpenseSheet() {
  if (widget.group.members.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Najpierw dodaj uczestników!')));
    return;
  }

  if (_selectedPayerId == null) _selectedPayerId = widget.group.members.first.id;

  // Domyślnie zaznaczamy WSZYSTKICH
  _selectedBeneficiaries = widget.group.members.map((e) => e.id).toList();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      // StatefulBuilder pozwala odświeżać wygląd WEWNĄTRZ BottomSheet
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20, right: 20, top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Nowy Wydatek', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                const Text("Wybierz kategorię:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.entries.map((entry) {
                    final key = entry.key;
                    final data = entry.value;
                    final isSelected = _selectedCategory == key;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(data['label']),
                        avatar: Icon(data['icon'], size: 18, color: isSelected ? Colors.white : data['color']),
                        selected: isSelected,
                        selectedColor: data['color'], // Kolor tła gdy zaznaczone
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                        onSelected: (bool selected) {
                          setModalState(() { // Używamy setModalState z StatefulBuilder!
                            _selectedCategory = (selected ? key : 'other');
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 15),
                TextField(
                  controller: _expenseTitleController,
                  decoration: const InputDecoration(labelText: 'Co kupiono?'),
                  autofocus: true,
                ),
                TextField(
                  controller: _expenseAmountController,
                  decoration: const InputDecoration(labelText: 'Kwota'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedPayerId,
                  items: widget.group.members.map((member) => DropdownMenuItem(value: member.id, child: Text(member.name))).toList(),
                  onChanged: (value) => setModalState(() => _selectedPayerId = value),
                  decoration: const InputDecoration(labelText: 'Kto płacił?'),
                ),
                const SizedBox(height: 15),
                const Text("Dla kogo? (Odznacz, jeśli ktoś nie korzystał)", style: TextStyle(fontWeight: FontWeight.bold)),

                // Lista Checkboxów
                SizedBox(
                  height: 150, // Ograniczamy wysokość listy
                  child: ListView(
                    shrinkWrap: true,
                    children: widget.group.members.map((member) {
                      final isSelected = _selectedBeneficiaries.contains(member.id);
                      return CheckboxListTile(
                        title: Text(member.name),
                        value: isSelected,
                        onChanged: (bool? checked) {
                          setModalState(() {
                            if (checked == true) {
                              _selectedBeneficiaries.add(member.id);
                            } else {
                              _selectedBeneficiaries.remove(member.id);
                            }
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _addExpense,
                  icon: const Icon(Icons.check),
                  label: const Text('Zapisz wydatek'),
                ),
              ],
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
        title: Text(widget.group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart),
            tooltip: "Podsumowanie",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => SettlementScreen(group: widget.group),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: "Dodaj osobę",
            onPressed: _showAddMemberDialog,
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 80,
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: widget.group.members.isEmpty 
              ? const Center(child: Text("Brak uczestników"))
              : ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.group.members.length,
                itemBuilder: (ctx, index) {
                  final member = widget.group.members[index];
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Chip(
                      avatar: CircleAvatar(child: Text(member.name.isNotEmpty ? member.name[0] : '?')),
                      label: Text(member.name),
                    ),
                  );
                },
              ),
          ),
          const Divider(height: 1),
          Expanded(
            child: widget.group.expenses.isEmpty
                ? const Center(child: Text("Brak wydatków. Dodaj pierwszy!"))
                : ListView.builder(
                    itemCount: widget.group.expenses.length,
                    // W pliku group_detail_screen.dart -> sekcja wydatków:

                    itemBuilder: (ctx, index) {
                      final expense = widget.group.expenses[index];
                      final catData = categories[expense.category] ?? categories['other']!;
                      // Szukamy imienia płatnika (bez zmian)
                      final payerName = widget.group.members
                          .firstWhere((m) => m.id == expense.payerId,
                              orElse: () => Member(id: '', name: '?'))
                          .name;

                      return Dismissible(
                        key: Key(expense.id), // Klucz wydatku
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red.withOpacity(0.8),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete_forever, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          // LOGIKA USUWANIA WYDATKU:
                          setState(() {
                            // 1. Usuwamy z lokalnej listy
                            widget.group.expenses.removeAt(index);
                          });
                          // 2. Zapisujemy zmianę w Hive (nadpisujemy grupę na dysku)
                          widget.group.save();

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Wydatek usunięty')),
                          );
                        },
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: (catData['color'] as Color).withOpacity(0.2), // Jasne tło
                            child: Icon(catData['icon'] as IconData, color: catData['color'] as Color), // Kolorowa ikona
                          ),
                          title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Płacił: $payerName'),
                          trailing: Text(
                            '${expense.amount.toStringAsFixed(2)} zł',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseSheet,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Wydatek'),
      ),
    );
  }
}

// Mapa: klucz kategorii -> Ikona i Kolor
final Map<String, Map<String, dynamic>> categories = {
  'food': {'icon': Icons.fastfood, 'label': 'Jedzenie', 'color': Colors.orange},
  'transport': {'icon': Icons.directions_car, 'label': 'Transport', 'color': Colors.blue},
  'home': {'icon': Icons.home, 'label': 'Nocleg', 'color': Colors.purple},
  'entertainment': {'icon': Icons.movie, 'label': 'Rozrywka', 'color': Colors.pink},
  'shopping': {'icon': Icons.shopping_bag, 'label': 'Zakupy', 'color': Colors.green},
  'other': {'icon': Icons.more_horiz, 'label': 'Inne', 'color': Colors.grey},
};