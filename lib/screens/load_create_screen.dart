import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'package:flutter/material.dart';

import 'map_picker_screen.dart';

class LoadCreateScreen extends StatefulWidget {
  const LoadCreateScreen({super.key});

  @override
  State<LoadCreateScreen> createState() => _LoadCreateScreenState();
}

class _LoadCreateScreenState extends State<LoadCreateScreen> {
  final fromCtrl = TextEditingController();
  final toCtrl = TextEditingController();
  final weightCtrl = TextEditingController();

  DateTime pickupDate = DateTime.now().add(const Duration(days: 1));
  String priceType = "offer"; // fixed/offer
  final fixedPriceCtrl = TextEditingController();

  double? selectedLat;
  double? selectedLng;

  bool saving = false;

  @override
  void dispose() {
    fromCtrl.dispose();
    toCtrl.dispose();
    weightCtrl.dispose();
    fixedPriceCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    // ignore: use_build_context_synchronously
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _publish() async {
    if (saving) return;
    setState(() => saving = true);

    try {
      final uid = AuthService().currentUser?.id;
      if (uid == null) {
        _snack("Oturum yok. Tekrar giriş yap.");
        return;
      }

      final from = fromCtrl.text.trim();
      final to = toCtrl.text.trim();
      final weight = int.tryParse(weightCtrl.text.trim()) ?? 0;
      final fixedPrice = int.tryParse(fixedPriceCtrl.text.trim());

      if (from.isEmpty || to.isEmpty) {
        _snack("Nereden / Nereye alanlarını doldur.");
        return;
      }
      if (weight <= 0) {
        _snack("Ağırlık (kg) geçerli olmalı.");
        return;
      }

      // ✅ Konum zorunlu
      if (selectedLat == null || selectedLng == null) {
        _snack("Haritadan konum seçmelisin.");
        return;
      }

      // ✅ fixed seçildiyse fiyat zorunlu
      if (priceType == "fixed") {
        if (fixedPrice == null || fixedPrice <= 0) {
          _snack("Sabit fiyat geçerli olmalı.");
          return;
        }
      }

      // Supabase'e yaz
      await Supabase.instance.client.from("loads").insert({
        "fromCity": from,
        "toCity": to,
        "pickupDate": pickupDate.toUtc().toIso8601String(),
        "weightKg": weight,
        "priceType": priceType,
        "fixedPrice": priceType == "fixed" ? fixedPrice : null,
        "status": "open",
        "shipperId": uid,

        // 🔥 KONUM
        "fromLat": selectedLat,
        "fromLng": selectedLng,
      });

      if (!mounted) return;
      // ignore: use_build_context_synchronously
Navigator.pop(context);

      _snack("İlan yayınlandı ✅");
    } catch (e) {
      _snack("Hata: $e");
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText =
        "${pickupDate.year}-${pickupDate.month.toString().padLeft(2, "0")}-${pickupDate.day.toString().padLeft(2, "0")}";

    return Scaffold(
      appBar: AppBar(title: const Text("Yük İlanı Oluştur")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: fromCtrl,
            decoration: const InputDecoration(labelText: "Nereden (Şehir)"),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: toCtrl,
            decoration: const InputDecoration(labelText: "Nereye (Şehir)"),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: weightCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Ağırlık (kg)"),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),

          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text("Alım Tarihi: $dateText"),
            trailing: const Icon(Icons.date_range),
            onTap: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: now.add(const Duration(days: 90)),
              );
              if (d != null) setState(() => pickupDate = d);
            },
          ),

          const Divider(),

          // ✅ Haritadan konum seç
          ElevatedButton.icon(
            icon: const Icon(Icons.map),
            label: Text(
              selectedLat == null
                  ? "Haritadan Konum Seç"
                  : "Konum Seçildi ✅ (${selectedLat!.toStringAsFixed(4)}, ${selectedLng!.toStringAsFixed(4)})",
            ),
            onPressed: saving
                ? null
                : () async {
                    final result = await // ignore: use_build_context_synchronously
Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MapPickerScreen()),
                    );

                    if (result != null) {
                      setState(() {
                        selectedLat = result['lat'] as double;
                        selectedLng = result['lng'] as double;
                      });
                    }
                  },
          ),
          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            initialValue: priceType,
            decoration: const InputDecoration(labelText: "Fiyat Tipi"),
            items: const [
              DropdownMenuItem(value: "offer", child: Text("Teklif Usulü")),
              DropdownMenuItem(value: "fixed", child: Text("Sabit Fiyat")),
            ],
            onChanged:
                saving ? null : (v) => setState(() => priceType = v ?? "offer"),
          ),

          const SizedBox(height: 10),

          if (priceType == "fixed")
            TextField(
              controller: fixedPriceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Sabit Fiyat (₺)"),
            ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.check),
              label: Text(saving ? "Kaydediliyor..." : "İlanı Yayınla"),
              onPressed: saving ? null : _publish,
            ),
          ),
        ],
      ),
    );
  }
}
