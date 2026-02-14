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
  String? _selectedPayerId;

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

    if (title.isEmpty || amount == null || amount <= 0 || _selectedPayerId == null) {
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
        ),
      );
    });

    // ZAPIS HIVE: Zapisujemy zmiany w wydatkach na dysku.
    widget.group.save();

    _expenseTitleController.clear();
    _expenseAmountController.clear();
    _selectedPayerId = null;
    Navigator.pop(context);
  }

  void _showAddExpenseSheet() {
    if (widget.group.members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Najpierw dodaj uczestników!')),
      );
      return;
    }

    // Ustawienie domyślnego płatnika (reset lub pierwszy z listy)
    if (_selectedPayerId == null || !widget.group.members.any((m) => m.id == _selectedPayerId)) {
       _selectedPayerId = widget.group.members.first.id;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nowy Wydatek', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
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
              items: widget.group.members.map((member) {
                return DropdownMenuItem(
                  value: member.id,
                  child: Text(member.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPayerId = value;
                });
              },
              decoration: const InputDecoration(labelText: 'Kto płacił?'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _addExpense,
              icon: const Icon(Icons.check),
              label: const Text('Zapisz wydatek'),
            ),
          ],
        ),
      ),
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
                    itemBuilder: (ctx, index) {
                      final expense = widget.group.expenses[index];
                      final payerName = widget.group.members
                          .firstWhere((m) => m.id == expense.payerId,
                              orElse: () => Member(id: '', name: '?'))
                          .name;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[100],
                          child: const Icon(Icons.attach_money, color: Colors.green),
                        ),
                        title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Płacił: $payerName'),
                        trailing: Text(
                          '${expense.amount.toStringAsFixed(2)} zł',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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