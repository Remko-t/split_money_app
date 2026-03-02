import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group.dart';
import '../models/expense.dart';
import '../models/member.dart';

// ZMIANA: Dodaliśmy id dłużnika i wierzyciela do klasy, żeby móc utworzyć dla nich wydatek
class Transfer {
  final String fromId;
  final String fromName;
  final String toId;
  final String toName;
  final double amount;

  Transfer(this.fromId, this.fromName, this.toId, this.toName, this.amount);
}

class SettlementScreen extends StatelessWidget {
  final Group group;

  SettlementScreen({super.key, required this.group});

  final Map<String, Map<String, dynamic>> categories = {
    'food': {'label': 'Jedzenie', 'color': Colors.orange},
    'transport': {'label': 'Transport', 'color': Colors.blue},
    'home': {'label': 'Nocleg', 'color': Colors.purple},
    'entertainment': {'label': 'Rozrywka', 'color': Colors.pink},
    'shopping': {'label': 'Zakupy', 'color': Colors.green},
    'other': {'label': 'Inne', 'color': Colors.grey},
    'repayment': {'label': 'Spłata', 'color': Colors.teal}, // Nowa kategoria
  };

  // --- FUNKCJA SPŁATY DŁUGU ---
  Future<void> _settleDebt(BuildContext context, Transfer transfer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potwierdź spłatę'),
        content: Text('Czy na pewno chcesz oznaczyć, że ${transfer.fromName} oddał(a) ${transfer.amount.toStringAsFixed(2)} ${group.currency} do ${transfer.toName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zatwierdź')
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 1. Tworzymy specjalny wydatek, który zeruje bilans
      final expenseMap = {
        'id': DateTime.now().toString(),
        'title': '💸 Spłata: ${transfer.fromName} ➔ ${transfer.toName}',
        'amount': transfer.amount,
        'payerId': transfer.fromId, // Dłużnik wyciąga kasę
        'beneficiaryIds': [transfer.toId], // Wierzyciel konsumuje kasę
        'date': Timestamp.now(),
        'category': 'repayment', // Używamy nowej, ukrytej kategorii
        'receiptPath': null,
      };

      await FirebaseFirestore.instance.collection('groups').doc(group.id).update({
        'expensesData': FieldValue.arrayUnion([expenseMap])
      });

      // 2. Dodajemy ślad w historii
      final userName = FirebaseAuth.instance.currentUser?.displayName ?? 'Ktoś';
      await FirebaseFirestore.instance.collection('groups').doc(group.id).update({
        'activitiesData': FieldValue.arrayUnion([{
          'id': DateTime.now().toString(),
          'message': "$userName oznaczył(a) dług jako uregulowany: ${transfer.fromName} ➔ ${transfer.toName} (${transfer.amount.toStringAsFixed(2)} ${group.currency})",
          'timestamp': Timestamp.now(),
        }])
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dług został uregulowany! 🎉')));
      }
    }
  }

  // --- LOGIKA ROZLICZEŃ ---
  Map<String, double> _calculateBalances(List<Member> members, List<Expense> expenses) {
    Map<String, double> balances = {};
    for (var member in members) balances[member.id] = 0.0;

    for (var expense in expenses) {
      if (balances.containsKey(expense.payerId)) {
        balances[expense.payerId] = balances[expense.payerId]! + expense.amount;
      }
      if (expense.beneficiaryIds.isNotEmpty) {
        double splitAmount = expense.amount / expense.beneficiaryIds.length;
        for (var beneficiaryId in expense.beneficiaryIds) {
          if (balances.containsKey(beneficiaryId)) {
            balances[beneficiaryId] = balances[beneficiaryId]! - splitAmount;
          }
        }
      }
    }
    return balances;
  }

  List<Transfer> _calculateTransfers(List<Member> members, Map<String, double> balances) {
    List<Transfer> transfers = [];
    Map<String, double> currentBalances = Map.from(balances);

    var debtors = currentBalances.keys.where((k) => currentBalances[k]! < -0.01).toList();
    var creditors = currentBalances.keys.where((k) => currentBalances[k]! > 0.01).toList();

    int i = 0; 
    int j = 0; 

    while (i < debtors.length && j < creditors.length) {
      String debtorId = debtors[i];
      String creditorId = creditors[j];

      double debt = currentBalances[debtorId]!.abs();
      double credit = currentBalances[creditorId]!;
      double amount = debt < credit ? debt : credit;

      String debtorName = members.firstWhere((m) => m.id == debtorId, orElse: () => Member(id: '', name: '?')).name;
      String creditorName = members.firstWhere((m) => m.id == creditorId, orElse: () => Member(id: '', name: '?')).name;

      // ZMIANA: Przekazujemy teraz ID do Transferu, żeby wiedzieć kto komu oddaje w bazie
      transfers.add(Transfer(debtorId, debtorName, creditorId, creditorName, amount));

      currentBalances[debtorId] = currentBalances[debtorId]! + amount;
      currentBalances[creditorId] = currentBalances[creditorId]! - amount;

      if (currentBalances[debtorId]!.abs() < 0.01) i++;
      if (currentBalances[creditorId]! < 0.01) j++;
    }

    return transfers;
  }

  // --- LOGIKA WYKRESU ---
  Map<String, double> _getExpensesByCategory(List<Expense> expenses) {
    Map<String, double> data = {};
    for (var expense in expenses) {
      // IGNORUJEMY SPŁATY NA WYKRESIE!
      if (expense.category == 'repayment') continue; 
      data[expense.category] = (data[expense.category] ?? 0) + expense.amount;
    }
    return data;
  }

  List<PieChartSectionData> _getChartSections(Map<String, double> categoryData, double total) {
    if (total == 0) return [];
    return categoryData.entries.map((entry) {
      final catInfo = categories[entry.key] ?? categories['other']!;
      final value = entry.value;
      final percentage = (value / total * 100).toStringAsFixed(0);
      
      return PieChartSectionData(
        color: catInfo['color'] as Color,
        value: value,
        title: '$percentage%',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Podsumowanie')),
      // ZMIANA: StreamBuilder tutaj pozwala na odświeżanie długów "na żywo" bez cofania się do poprzedniego okna!
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('groups').doc(group.id).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data?.data() == null) return const Center(child: Text("Błąd ładowania."));

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final parsedMembers = (data['membersData'] as List<dynamic>? ?? []).map((m) => Member(id: m['id'], name: m['name'])).toList();
          final parsedExpenses = (data['expensesData'] as List<dynamic>? ?? []).map((e) {
            return Expense(
              id: e['id'], title: e['title'], amount: (e['amount'] as num).toDouble(),
              payerId: e['payerId'], date: (e['date'] as Timestamp).toDate(),
              beneficiaryIds: List<String>.from(e['beneficiaryIds'] ?? []), category: e['category'] ?? 'other', receiptPath: e['receiptPath'],
            );
          }).toList();

          final balances = _calculateBalances(parsedMembers, parsedExpenses);
          final transfers = _calculateTransfers(parsedMembers, balances);
          
          // Wyliczanie sumy pomijając sztuczne wyzerowania długów (repayment)
          final realExpenses = parsedExpenses.where((e) => e.category != 'repayment').toList();
          final totalExpenses = realExpenses.fold(0.0, (sum, item) => sum + item.amount);
          final categoryData = _getExpensesByCategory(parsedExpenses);

          return parsedMembers.isEmpty
              ? const Center(child: Text("Brak uczestników do rozliczenia."))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // WYKRES KOŁOWY
                      if (totalExpenses > 0) ...[
                        SizedBox(
                          height: 200,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: PieChart(
                                  PieChartData(sections: _getChartSections(categoryData, totalExpenses), centerSpaceRadius: 40, sectionsSpace: 2),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: categoryData.keys.map((key) {
                                    final catInfo = categories[key] ?? categories['other']!;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Row(
                                        children: [
                                          Container(width: 16, height: 16, color: catInfo['color'] as Color),
                                          const SizedBox(width: 8),
                                          Text(catInfo['label'] as String, style: const TextStyle(fontSize: 14)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // SUMA WYDATKÓW
                      Card(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Suma wydatków:', style: TextStyle(fontSize: 18)),
                              Text('${totalExpenses.toStringAsFixed(2)} ${group.currency}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // PRZELEWY Z PRZYCISKIEM ODHACZANIA
                      const Text("Jak się rozliczyć (Przelewy):", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      
                      if (transfers.isEmpty)
                        const Padding(padding: EdgeInsets.all(16.0), child: Text("Wszyscy są rozliczeni! 🎉", textAlign: TextAlign.center, style: TextStyle(fontSize: 16)))
                      else
                        ...transfers.map((transfer) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0, right: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(transfer.fromName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16), textAlign: TextAlign.right),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                    child: Column(
                                      children: [
                                        Text('${transfer.amount.toStringAsFixed(2)} ${group.currency}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(transfer.toName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16), textAlign: TextAlign.left),
                                  ),
                                  // --- NOWY PRZYCISK: UREGULUJ ---
                                  IconButton(
                                    icon: const Icon(Icons.task_alt, color: Colors.green, size: 28),
                                    tooltip: 'Oznacz jako spłacone',
                                    onPressed: () => _settleDebt(context, transfer),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                      const SizedBox(height: 30),
                      const Divider(),
                      const SizedBox(height: 10),

                      // OGÓLNY BILANS
                      const Text("Bilanse uczestników (Ogółem):", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 10),
                      
                      ...parsedMembers.map((member) {
                        double balance = balances[member.id] ?? 0.0;
                        balance = double.parse(balance.toStringAsFixed(2));

                        bool isOwed = balance > 0;
                        bool isSettled = balance == 0;

                        Color statusColor = isSettled ? Colors.grey : (isOwed ? Colors.green : Colors.red);
                        String statusText = isSettled ? 'Rozliczony' : (isOwed ? 'Na plusie' : 'Na minusie');
                        String amountText = '${balance.abs().toStringAsFixed(2)} ${group.currency}';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(isSettled ? Icons.check_circle : (isOwed ? Icons.arrow_upward : Icons.arrow_downward), color: statusColor),
                          title: Text(member.name),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(statusText, style: TextStyle(color: statusColor, fontSize: 12)),
                              Text(amountText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
        },
      ),
    );
  }
}