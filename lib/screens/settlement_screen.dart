// plik: lib/screens/settlement_screen.dart
import 'package:flutter/material.dart';
import '../models/group.dart';

class SettlementScreen extends StatelessWidget {
  final Group group;

  const SettlementScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    // 1. Mapa: Kto ile zapłacił (wydał z portfela)
    Map<String, double> paidByMember = {};
    // 2. Mapa: Kto ile powinien był zapłacić (skonsumował)
    Map<String, double> shareOfMember = {};

    // Inicjalizacja zerami
    for (var member in group.members) {
      paidByMember[member.id] = 0.0;
      shareOfMember[member.id] = 0.0;
    }

    double totalExpense = 0;

    for (var expense in group.expenses) {
      totalExpense += expense.amount;
      
      // Dodajemy do tego, co zapłacił z własnej kieszeni
      if (paidByMember.containsKey(expense.payerId)) {
        paidByMember[expense.payerId] = paidByMember[expense.payerId]! + expense.amount;
      }

      // KROK KLUCZOWY: Ustalamy, na kogo dzielimy
      // Jeśli lista jest pusta (stare wydatki), zakładamy, że na wszystkich
      final beneficiaries = expense.beneficiaryIds.isEmpty 
          ? group.members.map((e) => e.id).toList() 
          : expense.beneficiaryIds;

      double splitAmount = expense.amount / beneficiaries.length;

      // Dodajemy dług każdemu beneficjentowi
      for (var beneficiaryId in beneficiaries) {
        if (shareOfMember.containsKey(beneficiaryId)) {
          shareOfMember[beneficiaryId] = shareOfMember[beneficiaryId]! + splitAmount;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Podsumowanie'),
        backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Całkowity koszt:", style: TextStyle(fontSize: 18)),
                  Text(
                    "${totalExpense.toStringAsFixed(2)} zł",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              itemCount: group.members.length,
              itemBuilder: (ctx, index) {
                final member = group.members[index];
                final paid = paidByMember[member.id] ?? 0.0;
                final shouldPay = shareOfMember[member.id] ?? 0.0;
                
                // Bilans = To co zapłaciłem - To co zjadłem
                final balance = paid - shouldPay; 

                final isPositive = balance >= 0;
                final color = isPositive ? Colors.green : Colors.red;
                final statusText = isPositive ? "Ma odzyskać" : "Musi oddać";
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.2),
                      child: Text(member.name[0], style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(member.name),
                    subtitle: Text("Zapłacił: ${paid.toStringAsFixed(2)} zł\nSkonsumował: ${shouldPay.toStringAsFixed(2)} zł"),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(statusText, style: TextStyle(color: color, fontSize: 12)),
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