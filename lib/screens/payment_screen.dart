import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/OfferService.dart';

class PaymentScreen extends StatefulWidget {
  final String loadId;
  final String offerId;
  final String driverId;
  final String shipperId;
  final int offerPrice;

  const PaymentScreen({
    super.key,
    required this.loadId,
    required this.offerId,
    required this.driverId,
    required this.shipperId,
    required this.offerPrice,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;

  // LogiMap Hizmet Bedeli (Örneğin %5)
  double get _serviceFee => widget.offerPrice * 0.05;
  double get _totalAmount => widget.offerPrice + _serviceFee;

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      // BURASI SİMÜLASYON: Gerçekte burada kredi kartı verilerini şifreleyip
      // Firebase Cloud Functions üzerinden İyzico/PayTR'ye göndereceğiz.
      // Şimdilik 2 saniye bekleyip "Ödeme Başarılı" varsayıyoruz.
      await Future.delayed(const Duration(seconds: 2));

      // Ödeme havuza alındıktan sonra eşleşmeyi gerçekleştiriyoruz
      await OfferService().acceptOfferByShipper(
        loadId: widget.loadId,
        offerId: widget.offerId,
        driverId: widget.driverId,
        shipperId: widget.shipperId,
      );

      if (!mounted) return;

      // Başarı animasyonu ve geri dönüş
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ödeme başarılı! Tutar güvenli havuza alındı ✅"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context); // Ödeme ekranını kapatır, panelde iş "Eşleşti" olarak görünür.

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ödeme hatası: $e")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // 🟢 TEST İÇİN GEÇİCİ FONKSİYON (Canlıya alırken silinecek)
  Future<void> _bypassPayment() async {
    setState(() => _isProcessing = true);
    try {
      // Doğrudan eşleşmeyi gerçekleştir (Kart kontrolü yapmaz)
      await OfferService().acceptOfferByShipper(
        loadId: widget.loadId,
        offerId: widget.offerId,
        driverId: widget.driverId,
        shipperId: widget.shipperId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("TEST: Ödeme atlandı, iş eşleşti ✅"),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pop(context); // Ekranı kapat
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Güvenli Ödeme", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isProcessing
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text("İşlem yapılıyor, lütfen bekleyin...", style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FİŞ / ÖZET KARTI
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade800, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Taşıma Bedeli", style: TextStyle(color: Colors.white70, fontSize: 15)),
                        Text("${widget.offerPrice} ₺", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Hizmet Bedeli", style: TextStyle(color: Colors.white70, fontSize: 15)),
                        Text("${_serviceFee.toStringAsFixed(2)} ₺", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const Divider(color: Colors.white30, height: 24, thickness: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Ödenecek Tutar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                        Text("${_totalAmount.toStringAsFixed(2)} ₺", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.security, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Tutar, iş teslim edilene kadar LogiMap güvenli havuz hesabında bloke edilir.",
                      style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 30),

              // KART BİLGİLERİ FORMU
              const Text("Kart Bilgileri", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              TextFormField(
                decoration: inputDecoration.copyWith(labelText: "Kart Üzerindeki İsim", prefixIcon: const Icon(Icons.person_outline)),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => v == null || v.isEmpty ? "Zorunlu alan" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(16)],
                decoration: inputDecoration.copyWith(labelText: "Kart Numarası", prefixIcon: const Icon(Icons.credit_card)),
                validator: (v) => v == null || v.length < 16 ? "16 haneli numarayı girin" : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      keyboardType: TextInputType.number,
                      inputFormatters: [LengthLimitingTextInputFormatter(5)], // Örn: 12/25
                      decoration: inputDecoration.copyWith(labelText: "SKT (AA/YY)", prefixIcon: const Icon(Icons.date_range)),
                      validator: (v) => v == null || v.length < 5 ? "Geçersiz" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                      obscureText: true,
                      decoration: inputDecoration.copyWith(labelText: "CVV", prefixIcon: const Icon(Icons.lock_outline)),
                      validator: (v) => v == null || v.length < 3 ? "Geçersiz" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // ÖDEME BUTONU
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _processPayment,
                  icon: const Icon(Icons.lock, size: 20),
                  label: Text(
                    "${_totalAmount.toStringAsFixed(2)} ₺ GÜVENLİ ÖDE",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 🟢 TEST İÇİN GEÇİCİ BUTON
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _bypassPayment,
                  icon: const Icon(Icons.fast_forward, color: Colors.orange),
                  label: const Text(
                    "TEST: Hızlı Geç (Ödeme Yapılmış Say)",
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}