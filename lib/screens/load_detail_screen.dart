import 'package:flutter/material.dart';
import '../services/match_service.dart';

class LoadDetailScreen extends StatefulWidget {
  final MatchResult match;
  const LoadDetailScreen({super.key, required this.match});

  @override
  State<LoadDetailScreen> createState() => _LoadDetailScreenState();
}

class _LoadDetailScreenState extends State<LoadDetailScreen> {
  final priceCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  @override
  void dispose() {
    priceCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.match.load;

    return Scaffold(
      appBar: AppBar(title: const Text("Yük Detayı")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("${l.fromCity} → ${l.toCity}", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text("Ağırlık: ${l.weightKg} kg"),
          Text("Alım Tarihi: ${l.pickupDate.year}-${l.pickupDate.month}-${l.pickupDate.day}"),
          const SizedBox(height: 8),
          Text("AI Skor: ${widget.match.score}"),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: widget.match.reasons.map((r) => Chip(label: Text(r))).toList(),
          ),
          const Divider(height: 32),
          TextField(
            controller: priceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Teklif (₺)"),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(labelText: "Not (opsiyonel)"),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("V1: Teklif kaydı (Firebase sonraki adım)")),
              );
            },
            child: const Text("Teklif Gönder"),
          )
        ],
      ),
    );
  }
}
