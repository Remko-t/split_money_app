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
  bool _isSearching = false; // Czy pasek szukania jest otwarty?
  String _searchQuery = "";  // Co wpisał użytkownik?
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

  void _saveExpense({String? existingId}) {
  final title = _expenseTitleController.text;
  final amount = double.tryParse(_expenseAmountController.text);

  if (title.isEmpty || amount == null || amount <= 0 || _selectedPayerId == null || _selectedBeneficiaries.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uzupełnij dane!')));
    return;
  }

  // Tworzymy nowy obiekt wydatku
  final newExpense = Expense(
    id: existingId ?? DateTime.now().toString(), // Zachowaj stare ID lub wygeneruj nowe
    title: title,
    amount: amount,
    payerId: _selectedPayerId!,
    date: DateTime.now(),
    category: _selectedCategory,
    beneficiaryIds: List.from(_selectedBeneficiaries),
  );

  setState(() {
    if (existingId != null) {
      // TRYB EDYCJI: Znajdź indeks starego wydatku i podmień go
      final index = widget.group.expenses.indexWhere((e) => e.id == existingId);
      if (index != -1) {
        widget.group.expenses[index] = newExpense;
      }
    } else {
      // TRYB DODAWANIA: Dodaj na koniec listy
      widget.group.expenses.add(newExpense);
    }
  });

  widget.group.save(); // Zapisz zmiany w Hive

  // Czyścimy kontrolery
  _expenseTitleController.clear();
  _expenseAmountController.clear();
  _selectedPayerId = null;
  _selectedBeneficiaries = [];
  Navigator.pop(context);
}

  void _showAddExpenseSheet({Expense? existingExpense}) {
  // --- POPRAWKA: ZABEZPIECZENIE ---
  // Sprawdzamy, czy w ogóle jest kto płacić. Jeśli lista pusta -> przerywamy.
  if (widget.group.members.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Najpierw dodaj uczestników do grupy!'),
        backgroundColor: Colors.red,
      ),
    );
    return; // Stop! Nie idź dalej, bo wyrzucisz błąd.
  }
  // --------------------------------

  final isEditing = existingExpense != null;

  if (isEditing) {
    _expenseTitleController.text = existingExpense.title;
    _expenseAmountController.text = existingExpense.amount.toString();
    
    // Sprawdzamy, czy płatnik nadal istnieje w grupie (na wypadek gdybyś go usunął)
    if (widget.group.members.any((m) => m.id == existingExpense.payerId)) {
       _selectedPayerId = existingExpense.payerId;
    } else {
       _selectedPayerId = widget.group.members.first.id; // Fallback
    }

    _selectedCategory = existingExpense.category;
    _selectedBeneficiaries = existingExpense.beneficiaryIds.isEmpty 
        ? widget.group.members.map((e) => e.id).toList() 
        : List.from(existingExpense.beneficiaryIds);
  } else {
    // Nowy wydatek
    _expenseTitleController.clear();
    _expenseAmountController.clear();
    
    // Tu był błąd! Teraz jest bezpiecznie, bo wiemy, że members.first istnieje (dzięki if na górze)
    _selectedPayerId = widget.group.members.first.id;
    
    _selectedCategory = 'other';
    _selectedBeneficiaries = widget.group.members.map((e) => e.id).toList();
  }

  showModalBottomSheet(
    // ... reszta kodu bez zmian (context, builder itd.) ...
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
           // ... (tu wklej resztę zawartości buildera z poprzedniego kroku) ...
           // Jeśli nie wiesz co tu wkleić, daj znać, wyślę cały plik!
           return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20, right: 20, top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(isEditing ? 'Edytuj Wydatek' : 'Nowy Wydatek', style: Theme.of(context).textTheme.titleLarge),
                
                // ... Kod kategorii ...
                const SizedBox(height: 10),
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
                          selectedColor: data['color'],
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                          onSelected: (bool selected) {
                            setModalState(() {
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
                  autofocus: !isEditing,
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
                const Text("Dla kogo?", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 150,
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
                  onPressed: () => _saveExpense(existingId: existingExpense?.id),
                  icon: const Icon(Icons.check),
                  label: Text(isEditing ? 'Zapisz zmiany' : 'Dodaj wydatek'),
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
    // 1. FILTROWANIE LISTY
    // Tworzymy nową listę, która zawiera tylko pasujące elementy
    final displayedExpenses = widget.group.expenses.where((expense) {
      final searchLower = _searchQuery.toLowerCase();
      final titleLower = expense.title.toLowerCase();
      // Szukamy w tytule LUB w kategorii
      return titleLower.contains(searchLower) || expense.category.contains(searchLower);
    }).toList();

    // Odwracamy kolejność, żeby nowe były na górze (Opcjonalny bajer UX)
    final expensesToShow = displayedExpenses.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        // 2. DYNAMICZNY TYTUŁ
        iconTheme: const IconThemeData(color: Colors.black),

        title: _isSearching
            ? TextField(
                autofocus: true,
                cursorColor: Colors.black, // 1. CZARNY KURSOR
                style: const TextStyle(
                  color: Colors.black, // 2. CZARNY TEKST (widoczny na jasnym tle)
                  fontSize: 18,
                ),
                decoration: const InputDecoration(
                  hintText: 'Szukaj wydatku...',
                  hintStyle: TextStyle(color: Colors.black54), // 3. SZARA PODPOWIEDŹ
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : Text(
                widget.group.name,
                style: const TextStyle(color: Colors.black), // Tytuł też czarny
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart),
            tooltip: "Podsumowanie",
            // Ikona będzie brała kolor z iconTheme (czarny)
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => SettlementScreen(group: widget.group),
                ),
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
      body: Column(
        children: [
          // Pasek z członkami grupy (bez zmian)
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
          
          // LISTA WYDATKÓW (Zaktualizowana)
          Expanded(
            child: widget.group.expenses.isEmpty
                ? const Center(child: Text("Brak wydatków. Dodaj pierwszy!"))
                : expensesToShow.isEmpty // Jeśli są wydatki, ale filtr je ukrył
                    ? const Center(child: Text("Nie znaleziono wydatków pasujących do wyszukiwania."))
                    : ListView.builder(
                        itemCount: expensesToShow.length,
                        itemBuilder: (ctx, index) {
                          final expense = expensesToShow[index];
                          
                          final payerName = widget.group.members
                              .firstWhere((m) => m.id == expense.payerId,
                                  orElse: () => Member(id: '', name: '?'))
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
                            onDismissed: (direction) {
                              // --- NOWA LOGIKA USUWANIA (Bezpieczna) ---
                              setState(() {
                                // Usuwamy konkretny obiekt po ID, a nie po indeksie
                                widget.group.expenses.removeWhere((e) => e.id == expense.id);
                              });
                              widget.group.save();

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Wydatek usunięty')),
                              );
                            },
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: (catData['color'] as Color).withOpacity(0.2),
                                child: Icon(catData['icon'] as IconData, color: catData['color'] as Color),
                              ),
                              title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Płacił: $payerName'),
                              trailing: Text(
                                '${expense.amount.toStringAsFixed(2)} zł',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseSheet(),
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