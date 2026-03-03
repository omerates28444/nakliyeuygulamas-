import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../services/auth_service.dart';
import 'map_picker_screen.dart';

class LoadCreateScreen extends StatefulWidget {
  const LoadCreateScreen({super.key});

  @override
  State<LoadCreateScreen> createState() => _LoadCreateScreenState();
}

class _LoadCreateScreenState extends State<LoadCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fromCityCtrl = TextEditingController();
  final _toCityCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  DateTime? _selectedDate;
  String _priceType = "offer";
  bool _isLoading = false;

  // 🟢 EKLENEN KONUM DEĞİŞKENLERİ
  double? _fromLat;
  double? _fromLng;

  @override
  void dispose() {
    _fromCityCtrl.dispose();
    _toCityCtrl.dispose();
    _weightCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _createLoad() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen alım tarihi seçin.")));
      return;
    }

    // Konum seçilmesini zorunlu yapmak istersen bu yorum satırını açabilirsin:
    /*
    if (_fromLat == null || _fromLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen haritadan konum seçin.")));
      return;
    }
    */

    setState(() => _isLoading = true);

    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) throw Exception("Oturum yok");

      final data = {
        "shipperId": uid,
        "fromCity": _fromCityCtrl.text.trim(),
        "toCity": _toCityCtrl.text.trim(),
        "weightKg": int.tryParse(_weightCtrl.text.trim()) ?? 0,
        "pickupDate": Timestamp.fromDate(_selectedDate!),
        "priceType": _priceType,
        "fixedPrice": _priceType == "fixed" ? (int.tryParse(_priceCtrl.text.trim()) ?? 0) : null,
        "fromLat": _fromLat, // 🟢 KONUM VERİTABANINA YAZILIYOR
        "fromLng": _fromLng, // 🟢 KONUM VERİTABANINA YAZILIYOR
        "status": "open",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection("loads").add(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İlan başarıyla yayınlandı ✅")));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Yük İlanı Oluştur", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _fromCityCtrl,
                decoration: inputDecoration.copyWith(hintText: "Nereden (Şehir)"),
                validator: (v) => v!.isEmpty ? "Zorunlu alan" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _toCityCtrl,
                decoration: inputDecoration.copyWith(hintText: "Nereye (Şehir)"),
                validator: (v) => v!.isEmpty ? "Zorunlu alan" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _weightCtrl,
                keyboardType: TextInputType.number,
                decoration: inputDecoration.copyWith(hintText: "Ağırlık (kg)"),
                validator: (v) => v!.isEmpty ? "Zorunlu alan" : null,
              ),
              const SizedBox(height: 20),

              InkWell(
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          _selectedDate == null
                              ? "Alım Tarihi Seçin"
                              : "Alım Tarihi: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}",
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade800)
                      ),
                      Icon(Icons.calendar_today_outlined, color: Colors.grey.shade600),
                    ],
                  ),
                ),
              ),
              Divider(color: Colors.grey.shade300, thickness: 1),
              const SizedBox(height: 16),

              // 🟢 HARİTADAN KONUM SEÇ BUTONU (YENİDEN EKLENDİ)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5A668A).withOpacity(0.08),
                    foregroundColor: const Color(0xFF5A668A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    // 🟢 HARİTA SAYFASINI AÇ VE DÖNEN KONUMU YAKALA
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
                    );

                    // 🟢 EĞER KULLANICI KONUM SEÇİP DÖNDÜYSE DEĞİŞKENLERE KAYDET
                    if (result != null && result is Map) {
                      setState(() {
                        _fromLat = result["lat"];
                        _fromLng = result["lng"];
                      });
                    }
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: Text(
                      _fromLat != null ? "Konum Seçildi ✅" : "Haritadan Konum Seç",
                      style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Text("Fiyat Tipi", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _priceType,
                decoration: inputDecoration,
                icon: const Icon(Icons.arrow_drop_down),
                items: const [
                  DropdownMenuItem(value: "offer", child: Text("Teklif Usulü", style: TextStyle(fontWeight: FontWeight.bold))),
                  DropdownMenuItem(value: "fixed", child: Text("Sabit Fiyat", style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                onChanged: (v) => setState(() => _priceType = v ?? "offer"),
              ),

              if (_priceType == "fixed") ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: inputDecoration.copyWith(hintText: "Sabit Ücret (₺)"),
                  validator: (v) => (_priceType == "fixed" && v!.isEmpty) ? "Ücret girin" : null,
                ),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5A668A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _createLoad,
                  icon: const Icon(Icons.check),
                  label: const Text("İlanı Yayınla", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}