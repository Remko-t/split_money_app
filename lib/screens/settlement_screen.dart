import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Import paczki od wykresów
import '../models/group.dart';

// Klasa pomocnicza przechowująca instrukcję pojedynczego przelewu
class Transfer {
  final String fromName;
  final String toName;
  final double amount;

  Transfer(this.fromName, this.toName, this.amount);
}

class SettlementScreen extends StatelessWidget {
  final Group group;

  SettlementScreen({super.key, required this.group});

  // Mapa kategorii (żeby wykres miał kolory i nazwy)
  final Map<String, Map<String, dynamic>> categories = {
    'food': {'label': 'Jedzenie', 'color': Colors.orange},
    'transport': {'label': 'Transport', 'color': Colors.blue},
    'home': {'label': 'Nocleg', 'color': Colors.purple},
    'entertainment': {'label': 'Rozrywka', 'color': Colors.pink},
    'shopping': {'label': 'Zakupy', 'color': Colors.green},
    'other': {'label': 'Inne', 'color': Colors.grey},
  };

  // --- LOGIKA ROZLICZEŃ ---

  Map<String, double> _calculateBalances() {
    Map<String, double> balances = {};
    for (var member in group.members) balances[member.id] = 0.0;

    for (var expense in group.expenses) {
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

  List<Transfer> _calculateTransfers(Map<String, double> balances) {
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

      String debtorName = group.members.firstWhere((m) => m.id == debtorId).name;
      String creditorName = group.members.firstWhere((m) => m.id == creditorId).name;

      transfers.add(Transfer(debtorName, creditorName, amount));

      currentBalances[debtorId] = currentBalances[debtorId]! + amount;
      currentBalances[creditorId] = currentBalances[creditorId]! - amount;

      if (currentBalances[debtorId]!.abs() < 0.01) i++;
      if (currentBalances[creditorId]! < 0.01) j++;
    }

    return transfers;
  }

  // --- LOGIKA WYKRESU ---

  Map<String, double> _getExpensesByCategory() {
    Map<String, double> data = {};
    for (var expense in group.expenses) {
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
    final balances = _calculateBalances();
    final transfers = _calculateTransfers(balances);
    final totalExpenses = group.expenses.fold(0.0, (sum, item) => sum + item.amount);
    
    // Dane do wykresu
    final categoryData = _getExpensesByCategory();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Podsumowanie'),
      ),
      body: group.members.isEmpty
          ? const Center(child: Text("Brak uczestników do rozliczenia."))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- WYKRES KOŁOWY ---
                  if (totalExpenses > 0) ...[
                    SizedBox(
                      height: 200,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: PieChart(
                              PieChartData(
                                sections: _getChartSections(categoryData, totalExpenses),
                                centerSpaceRadius: 40,
                                sectionsSpace: 2,
                              ),
                            ),
                          ),
                          // Legenda wykresu
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
                                      Container(
                                        width: 16, height: 16,
                                        color: catInfo['color'] as Color,
                                      ),
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

                  // --- KARTA: SUMA WYDATKÓW ---
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
                          Text(
                            '${totalExpenses.toStringAsFixed(2)} zł',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- KTO KOMU PRZELEWA (GOTOWE INSTRUKCJE) ---
                  const Text(
                    "Jak się rozliczyć (Przelewy):",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  
                  if (transfers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("Wszyscy są rozliczeni! 🎉", textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                    )
                  else
                    ...transfers.map((transfer) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  transfer.fromName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                child: Column(
                                  children: [
                                    Text(
                                      '${transfer.amount.toStringAsFixed(2)} zł',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  transfer.toName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 30),
                  const Divider(),
                  const SizedBox(height: 10),

                  // --- OGÓLNY BILANS ---
                  const Text(
                    "Bilanse uczestników (Ogółem):",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  
                  ...group.members.map((member) {
                    double balance = balances[member.id] ?? 0.0;
                    balance = double.parse(balance.toStringAsFixed(2));

                    bool isOwed = balance > 0;
                    bool isSettled = balance == 0;

                    Color statusColor = isSettled ? Colors.grey : (isOwed ? Colors.green : Colors.red);
                    String statusText = isSettled ? 'Rozliczony' : (isOwed ? 'Na plusie' : 'Na minusie');
                    String amountText = '${balance.abs().toStringAsFixed(2)} zł';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isSettled ? Icons.check_circle : (isOwed ? Icons.arrow_upward : Icons.arrow_downward),
                        color: statusColor,
                      ),
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
            ),
    );
  }
}