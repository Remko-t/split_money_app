// plik: lib/screens/settlement_screen.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart'; // Import wykresów
import '../models/group.dart';

class SettlementScreen extends StatelessWidget {
  final Group group;

  const SettlementScreen({super.key, required this.group});

  // Kopiujemy mapę kolorów/ikon, żeby wykres był spójny z resztą apki
  // (W idealnym świecie trzymalibyśmy to w jednym pliku utils.dart)
  final Map<String, Map<String, dynamic>> categoriesConfig = const {
    'food': {'label': 'Jedzenie', 'color': Colors.orange},
    'transport': {'label': 'Transport', 'color': Colors.blue},
    'home': {'label': 'Nocleg', 'color': Colors.purple},
    'entertainment': {'label': 'Rozrywka', 'color': Colors.pink},
    'shopping': {'label': 'Zakupy', 'color': Colors.green},
    'other': {'label': 'Inne', 'color': Colors.grey},
  };

  // Funkcja generująca tekst do udostępnienia (bez zmian)
  String _generateReport() {
    Map<String, double> balances = {};
    for (var member in group.members) balances[member.id] = 0.0;
    
    double totalExpense = 0;

    for (var expense in group.expenses) {
      totalExpense += expense.amount;
      if (balances.containsKey(expense.payerId)) {
        balances[expense.payerId] = balances[expense.payerId]! + expense.amount;
      }
      final beneficiaries = expense.beneficiaryIds.isEmpty 
          ? group.members.map((e) => e.id).toList() 
          : expense.beneficiaryIds;
      double splitAmount = expense.amount / beneficiaries.length;
      for (var beneficiaryId in beneficiaries) {
        if (balances.containsKey(beneficiaryId)) {
          balances[beneficiaryId] = balances[beneficiaryId]! - splitAmount;
        }
      }
    }

    StringBuffer report = StringBuffer();
    report.writeln("📊 Rozliczenie grupy: ${group.name}");
    report.writeln("💰 Całkowity koszt: ${totalExpense.toStringAsFixed(2)} zł");
    report.writeln("-------------------");

    for (var member in group.members) {
      double bal = balances[member.id] ?? 0.0;
      if (bal == 0) continue;
      if (bal > 0) {
        report.writeln("✅ ${member.name} ma odzyskać: ${bal.toStringAsFixed(2)} zł");
      } else {
        report.writeln("🔴 ${member.name} musi oddać: ${bal.abs().toStringAsFixed(2)} zł");
      }
    }
    report.writeln("\nWygenerowano w aplikacji Rozliczacz 📱");
    return report.toString();
  }

  // NOWE: Funkcja grupująca wydatki do wykresu
  Map<String, double> _groupExpensesByCategory() {
    Map<String, double> totals = {};
    for (var expense in group.expenses) {
      // Jeśli kategoria nie istnieje w naszej mapie, wrzuć do "other"
      String cat = categoriesConfig.containsKey(expense.category) ? expense.category : 'other';
      totals[cat] = (totals[cat] ?? 0) + expense.amount;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Obliczenia salda (stara logika)
    Map<String, double> paidByMember = {};
    Map<String, double> shareOfMember = {};
    for (var member in group.members) {
      paidByMember[member.id] = 0.0;
      shareOfMember[member.id] = 0.0;
    }
    double totalExpense = 0;
    for (var expense in group.expenses) {
      totalExpense += expense.amount;
      if (paidByMember.containsKey(expense.payerId)) {
        paidByMember[expense.payerId] = paidByMember[expense.payerId]! + expense.amount;
      }
      final beneficiaries = expense.beneficiaryIds.isEmpty 
          ? group.members.map((e) => e.id).toList() 
          : expense.beneficiaryIds;
      double splitAmount = expense.amount / beneficiaries.length;
      for (var beneficiaryId in beneficiaries) {
        if (shareOfMember.containsKey(beneficiaryId)) {
          shareOfMember[beneficiaryId] = shareOfMember[beneficiaryId]! + splitAmount;
        }
      }
    }

    // 2. Przygotowanie danych do wykresu
    final categoryTotals = _groupExpensesByCategory();
    
    // Tworzymy "sekcje" wykresu (kawałki pizzy)
    final List<PieChartSectionData> chartSections = categoryTotals.entries.map((entry) {
      final categoryKey = entry.key;
      final amount = entry.value;
      final color = categoriesConfig[categoryKey]?['color'] as Color;
      
      return PieChartSectionData(
        color: color,
        value: amount,
        title: '${(amount / totalExpense * 100).toStringAsFixed(0)}%', // Procenty
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Podsumowanie'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.share(_generateReport()),
          ),
        ],
      ),
      body: Column(
        children: [
          // SEKCJA 1: Wykres (Tylko jeśli są wydatki)
          if (totalExpense > 0)
            Container(
              height: 220, // Wysokość obszaru wykresu
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Wykres Kołowy
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sections: chartSections,
                        centerSpaceRadius: 40, // Dziura w środku (Donut chart)
                        sectionsSpace: 2, // Przerwy między kawałkami
                      ),
                    ),
                  ),
                  // Legenda (Opis kolorów)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: categoryTotals.keys.map((catKey) {
                      final config = categoriesConfig[catKey]!;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(width: 12, height: 12, color: config['color']),
                            const SizedBox(width: 8),
                            Text(config['label']),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // SEKCJA 2: Całkowity koszt
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Suma wydatków:", style: TextStyle(fontSize: 18)),
                  Text(
                    "${totalExpense.toStringAsFixed(2)} zł",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          const Divider(),

          // SEKCJA 3: Lista dłużników
          Expanded(
            child: ListView.builder(
              itemCount: group.members.length,
              itemBuilder: (ctx, index) {
                final member = group.members[index];
                final paid = paidByMember[member.id] ?? 0.0;
                final shouldPay = shareOfMember[member.id] ?? 0.0;
                final balance = paid - shouldPay;
                final isPositive = balance >= 0;
                final color = isPositive ? Colors.green : Colors.red;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.1),
                      child: Text(member.name[0], style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(member.name),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(isPositive ? "Odzyska" : "Odda", style: TextStyle(color: color, fontSize: 12)),
                        Text(
                          "${balance.abs().toStringAsFixed(2)} zł",
                          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}