// plik: lib/screens/settlement_screen.dart
import 'package:flutter/material.dart';
import '../models/group.dart';

class SettlementScreen extends StatelessWidget {
  final Group group;

  const SettlementScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    // 1. Obliczamy sumę wszystkich wydatków
    double totalExpense = 0;
    // Mapa: ID użytkownika -> Ile zapłacił
    Map<String, double> paidByMember = {};

    // Inicjalizujemy mapę zerami
    for (var member in group.members) {
      paidByMember[member.id] = 0.0;
    }

    // Sumujemy wydatki
    for (var expense in group.expenses) {
      totalExpense += expense.amount;
      if (paidByMember.containsKey(expense.payerId)) {
        paidByMember[expense.payerId] = paidByMember[expense.payerId]! + expense.amount;
      }
    }

    // 2. Obliczamy średnią na osobę
    // Jeśli nie ma członków, dzielimy przez 1 żeby uniknąć błędu
    double sharePerPerson = totalExpense / (group.members.isEmpty ? 1 : group.members.length);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Podsumowanie'),
        backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
      ),
      body: Column(
        children: [
          // Karta z ogólną sumą
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
          
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text("Bilans (równy podział):", style: TextStyle(fontWeight: FontWeight.bold)),
          ),

          // Lista z bilansem każdego uczestnika
          Expanded(
            child: ListView.builder(
              itemCount: group.members.length,
              itemBuilder: (ctx, index) {
                final member = group.members[index];
                final paid = paidByMember[member.id] ?? 0.0;
                final balance = paid - sharePerPerson; 
                // Jeśli balance > 0 -> ktoś ma odzyskać
                // Jeśli balance < 0 -> ktoś musi oddać

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
                    subtitle: Text("Zapłacił(a): ${paid.toStringAsFixed(2)} zł"),
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