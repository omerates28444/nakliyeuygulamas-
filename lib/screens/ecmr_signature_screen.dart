import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/pdf_service.dart';

class EcmrSignatureScreen extends StatefulWidget {
  final String loadId;
  final String role; // "driver" veya "shipper"

  const EcmrSignatureScreen({super.key, required this.loadId, required this.role});

  @override
  State<EcmrSignatureScreen> createState() => _EcmrSignatureScreenState();
}

class _EcmrSignatureScreenState extends State<EcmrSignatureScreen> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3.5, // Daha zarif bir kalem kalınlığı
    penColor: const Color(0xFF081226), // LogiMap Laciverti
    exportBackgroundColor: Colors.transparent, // Arka plan şeffaf
  );

  bool _isProcessing = false;

  final Color logimapNavy = const Color(0xFF081226);
  final Color logimapBlue = const Color(0xFF1976D2);

  Future<void> _saveSignature() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Lütfen önce kutuya imzanızı atın!", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          )
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final Uint8List? signatureBytes = await _controller.toPngBytes();
      if (signatureBytes == null) throw Exception("İmza oluşturulamadı.");

      final db = FirebaseFirestore.instance;

      // 1. İlan Bilgilerini Çek
      final loadSnap = await db.collection("loads").doc(widget.loadId).get();
      final loadData = loadSnap.data() ?? {};

      final fromCity = loadData["fromCity"]?.toString() ?? "Bilinmiyor";
      final toCity = loadData["toCity"]?.toString() ?? "Bilinmiyor";
      final shipperId = loadData["shipperId"]?.toString() ?? "";
      final driverId = loadData["acceptedDriverId"]?.toString() ?? "";
      final weight = loadData["weightKg"]?.toString() ?? "-";

      // Fiyat Bilgisini Çek
      String price = "Sistemde Kayıtlı";
      if (loadData["priceType"] == "fixed" && loadData["fixedPrice"] != null) {
        price = loadData["fixedPrice"].toString();
      } else if (loadData["acceptedPrice"] != null) {
        price = loadData["acceptedPrice"].toString();
      }

      // 2. Kullanıcıların Gerçek İsimlerini ve Plakayı Çek
      String shipperName = "Yük Sahibi";
      String driverName = "Taşıyıcı Şoför";
      String plate = "-";

      if (shipperId.isNotEmpty) {
        final sDoc = await db.collection("users").doc(shipperId).get();
        if (sDoc.exists) shipperName = sDoc.data()?["name"] ?? "Yük Sahibi";
      }

      if (driverId.isNotEmpty) {
        final dDoc = await db.collection("users").doc(driverId).get();
        if (dDoc.exists) {
          final dData = dDoc.data() ?? {};
          driverName = dData["name"] ?? "Taşıyıcı Şoför";
          if (dData["extra"] != null && dData["extra"]["plate"] != null) {
            plate = dData["extra"]["plate"].toString();
          }
        }
      }

      // 3. İmzaları Ayarla (Karşı taraf imzaladıysa onu da PDF'e dahil et)
      final String mySignatureBase64 = base64Encode(signatureBytes); // Kendi imzanı Base64'e çevir
      final String otherRole = widget.role == "driver" ? "shipper" : "driver";
      final String? otherSignatureBase64 = loadData["ecmrSignatureBase64_$otherRole"]; // Diğer imza var mı?

      Uint8List? shipperBytes;
      Uint8List? driverBytes;

      if (widget.role == "shipper") {
        shipperBytes = signatureBytes;
        if (otherSignatureBase64 != null) driverBytes = base64Decode(otherSignatureBase64);
      } else {
        driverBytes = signatureBytes;
        if (otherSignatureBase64 != null) shipperBytes = base64Decode(otherSignatureBase64);
      }

      // Resmi Evrak Numarası Oluştur
      final docId = "LM-${widget.loadId.length > 5 ? widget.loadId.substring(0,5).toUpperCase() : '2026'}";

      // 4. Mükemmel PDF'i Üret!
      final pdfBytes = await PdfService.generateEcmrPdf(
        documentId: docId,
        fromCity: fromCity,
        toCity: toCity,
        driverName: driverName,
        shipperName: shipperName,
        price: price,
        weight: weight,
        plate: plate,
        shipperSignatureBytes: shipperBytes,
        driverSignatureBytes: driverBytes,
      );

      // 5. PDF'i Storage'a Yükle
      final storageRef = FirebaseStorage.instance.ref().child("ecmr_documents/${widget.loadId}_${widget.role}.pdf");
      await storageRef.putData(pdfBytes, SettableMetadata(contentType: "application/pdf"));
      final downloadUrl = await storageRef.getDownloadURL();

      // 6. Firestore'u Güncelle (Kendi imzanın Base64'ünü de kaydet ki karşı taraf PDF oluştururken çekebilsin)
      await db.collection("loads").doc(widget.loadId).update({
        "ecmrUrl_${widget.role}": downloadUrl,
        "ecmrSignedBy_${widget.role}": true,
        "ecmrSignedAt_${widget.role}": FieldValue.serverTimestamp(),
        "ecmrSignatureBase64_${widget.role}": mySignatureBase64, // Diğer tarafın kullanması için
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("İmza başarıyla sözleşmeye eklendi ✅", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hata: $e", style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          )
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleName = widget.role == "driver" ? "Şoför" : "Yük Sahibi";

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Sözleşme İmzala", style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF081226))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF081226)),
        centerTitle: true,
      ),
      body: _isProcessing
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: logimapBlue),
            const SizedBox(height: 16),
            Text("Sözleşme Şifreleniyor...", style: TextStyle(fontWeight: FontWeight.w600, color: logimapNavy, fontSize: 16)),
            const SizedBox(height: 8),
            Text("Lütfen bekleyin", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
      )
          : SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // 🟢 BİLGİ KUTUSU 🟢
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: logimapBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: logimapBlue.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: logimapBlue, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Sayın $roleName, lütfen e-CMR dijital taşıma sözleşmesi için aşağıdaki alana parmağınızla imzanızı atın. İmzanız resmi belgede görünecektir.",
                      style: TextStyle(color: logimapNavy, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 🟢 İMZA ALANI (ÇİZİM BÖLÜMÜ) 🟢
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
                      // Arkadaki imza çizgisi (Rehber)
                      Center(
                        child: Container(
                          width: 200,
                          height: 2,
                          color: Colors.grey.shade200,
                        ),
                      ),
                      // İmza Modülü
                      Signature(
                        controller: _controller,
                        backgroundColor: Colors.transparent,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 🟢 AKSİYON BUTONLARI 🟢
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 54,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade300, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          foregroundColor: Colors.red.shade700,
                        ),
                        onPressed: () => _controller.clear(),
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text("Temizle", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: logimapNavy,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                        onPressed: _saveSignature,
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: const Text("İmzayı Kaydet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}