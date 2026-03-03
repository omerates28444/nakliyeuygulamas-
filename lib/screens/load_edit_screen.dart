import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/load.dart';

class LoadEditScreen extends StatefulWidget {
  final Load load;

  const LoadEditScreen({super.key, required this.load});

  @override
  State<LoadEditScreen> createState() => _LoadEditScreenState();
}

class _LoadEditScreenState extends State<LoadEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fromCityCtrl;
  late TextEditingController _toCityCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _priceCtrl;

  DateTime? _selectedDate;
  String _priceType = "offer";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fromCityCtrl = TextEditingController(text: widget.load.fromCity);
    _toCityCtrl = TextEditingController(text: widget.load.toCity);
    _weightCtrl = TextEditingController(text: widget.load.weightKg?.toString() ?? "");
    _priceType = widget.load.priceType ?? "offer";
    _priceCtrl = TextEditingController(text: widget.load.fixedPrice?.toString() ?? "");
    _selectedDate = widget.load.pickupDate;
  }

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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir tarih seçin.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedData = {
        "fromCity": _fromCityCtrl.text.trim(),
        "toCity": _toCityCtrl.text.trim(),
        "weightKg": int.tryParse(_weightCtrl.text.trim()) ?? 0,
        "pickupDate": Timestamp.fromDate(_selectedDate!),
        "priceType": _priceType,
        "fixedPrice": _priceType == "fixed" ? (int.tryParse(_priceCtrl.text.trim()) ?? 0) : null,
        "updatedAt": FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection("loads").doc(widget.load.id).update(updatedData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İlan başarıyla güncellendi ✅")));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 Oluşturma ekranındaki gibi yumuşak gri, köşeleri oval, çizgisiz kutu tasarımı
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
        title: const Text("İlanı Düzenle", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
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

              // 🟢 Nereden Şehir
              TextFormField(
                controller: _fromCityCtrl,
                decoration: inputDecoration.copyWith(hintText: "Nereden (Şehir)"),
                validator: (v) => v!.isEmpty ? "Boş olamaz" : null,
              ),
              const SizedBox(height: 12),

              // 🟢 Nereye Şehir
              TextFormField(
                controller: _toCityCtrl,
                decoration: inputDecoration.copyWith(hintText: "Nereye (Şehir)"),
                validator: (v) => v!.isEmpty ? "Boş olamaz" : null,
              ),
              const SizedBox(height: 12),

              // 🟢 Ağırlık
              TextFormField(
                controller: _weightCtrl,
                keyboardType: TextInputType.number,
                decoration: inputDecoration.copyWith(hintText: "Ağırlık (kg)"),
                validator: (v) => v!.isEmpty ? "Ağırlık girin" : null,
              ),
              const SizedBox(height: 20),

              // 🟢 Alım Tarihi
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

              // 🟢 Fiyat Tipi (Dropdown)
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

              // 🟢 Sabit Fiyat Seçildiyse Çıkan Ücret Kutusu
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

              // 🟢 İlanı Yayınla / Kaydet Butonu
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5A668A), // Fotoğraftaki morumsu/gri butona çok yakın bir renk
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saveChanges,
                  icon: const Icon(Icons.check),
                  label: const Text("Değişiklikleri Kaydet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}