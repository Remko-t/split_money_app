import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group.dart';

class HistoryScreen extends StatelessWidget {
  final Group group;

  const HistoryScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oś czasu wyjazdu 📜'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // Nasłuchujemy zmian w dokumencie grupy, żeby historia odświeżała się na żywo
        stream: FirebaseFirestore.instance.collection('groups').doc(group.id).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return const Center(child: Text("Błąd ładowania historii."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final rawActivities = data['activitiesData'] as List<dynamic>? ?? [];

          if (rawActivities.isEmpty) {
            return const Center(child: Text("Nic się tu jeszcze nie wydarzyło!", style: TextStyle(color: Colors.grey, fontSize: 16)));
          }

          // Sortujemy od najnowszych do najstarszych
          rawActivities.sort((a, b) {
            final timeA = a['timestamp'] as Timestamp;
            final timeB = b['timestamp'] as Timestamp;
            return timeB.compareTo(timeA); // Z-A (najnowsze na górze)
          });

          return ListView.builder(
            itemCount: rawActivities.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (ctx, index) {
              final activity = rawActivities[index];
              final date = (activity['timestamp'] as Timestamp).toDate();
              
              // Formatowanie daty: np. 05.08.2023, 14:30
              final dateString = "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
              final timeString = "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.transparent,
                    child: Icon(Icons.history, color: Colors.blueGrey),
                  ),
                  title: Text(activity['message'], style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text("$dateString, $timeString", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}