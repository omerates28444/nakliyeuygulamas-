import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
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

  bool sending = false;

  @override
  void dispose() {
    priceCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<String?> _resolveShipperId(String loadId, String? shipperIdFromModel) async {
    // 1) Modelde varsa onu kullan
    if (shipperIdFromModel != null && shipperIdFromModel.trim().isNotEmpty) {
      return shipperIdFromModel.trim();
    }

    // 2) Yoksa loads/{loadId} içinden çek
    final snap = await FirebaseFirestore.instance.collection("loads").doc(loadId).get();
    final shipperId = snap.data()?["shipperId"];
    if (shipperId is String && shipperId.trim().isNotEmpty) return shipperId.trim();

    return null;
  }

  Future<void> _sendOffer() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _snack("Oturum yok. Tekrar giriş yap.");
      return;
    }

    final l = widget.match.load;

    final price = int.tryParse(priceCtrl.text.trim());
    if (price == null || price <= 0) {
      _snack("Geçerli bir teklif fiyatı gir (örn: 2500).");
      return;
    }

    setState(() => sending = true);

    try {
      final shipperId = await _resolveShipperId(l.id, l.shipperId);
      if (shipperId == null) {
        _snack("shipperId bulunamadı. loads/${l.id} içinde shipperId olmalı.");
        return;
      }

      final driverName = (appState.displayName ?? "").trim().isNotEmpty
          ? appState.displayName!.trim()
          : "Bir şoför";

      await FirebaseFirestore.instance.collection("offers").add({
        "loadId": l.id,
        "shipperId": shipperId, // 🔥 Bildirim için kritik alan
        "driverId": uid,
        "driverName": driverName,
        "price": price,
        "note": noteCtrl.text.trim(),
        "status": "sent",
        "createdAt": FieldValue.serverTimestamp(),
      });

      _snack("Teklif gönderildi ✅");

      // İstersen aç:
      // priceCtrl.clear();
      // noteCtrl.clear();
    } catch (e) {
      _snack("Hata: $e");
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.match.load;

    return Scaffold(
      appBar: AppBar(title: const Text("Yük Detayı")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "${l.fromCity} → ${l.toCity}",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
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
            decoration: const InputDecoration(
              labelText: "Teklifiniz (₺)",
              prefixIcon: Icon(Icons.local_offer_outlined),
            ),
          ),
          const SizedBox(height: 8),

          // YENİ BİLGİLENDİRME MESAJI
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Yük sahibiyle sohbete başlamak ve detayları konuşmak için önce teklif göndermelisiniz.",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: sending ? null : _sendOffer,
              child: sending
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text("Teklif Gönder"),
            ),
          ),
        ],
      ),
    );
  }
}