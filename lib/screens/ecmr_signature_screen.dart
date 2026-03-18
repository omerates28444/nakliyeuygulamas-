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
    penStrokeWidth: 4,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _isProcessing = false;

  Future<void> _saveSignature() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen önce imza atın!")));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final Uint8List? signatureBytes = await _controller.toPngBytes();
      if (signatureBytes == null) throw Exception("İmza dönüştürülemedi.");

      final db = FirebaseFirestore.instance;
      final loadSnap = await db.collection("loads").doc(widget.loadId).get();
      final loadData = loadSnap.data() ?? {};

      // PDF için gerekli verileri topla
      final fromCity = loadData["fromCity"] ?? "Bilinmiyor";
      final toCity = loadData["toCity"] ?? "Bilinmiyor";
      final shipperId = loadData["shipperId"] ?? "";
      final driverId = loadData["acceptedDriverId"] ?? "";
      final price = loadData["acceptedPrice"]?.toString() ?? "Sistemde kayitli";

      // PDF Üret ve Storage'a Yükle
      final pdfBytes = await PdfService.generateEcmrPdf(
        fromCity: fromCity, toCity: toCity, driverName: "Tasimaci", shipperName: "Yuk Sahibi",
        price: price, signatureBytes: signatureBytes, role: widget.role,
      );

      final storageRef = FirebaseStorage.instance.ref().child("ecmr_documents/${widget.loadId}_${widget.role}.pdf");
      await storageRef.putData(pdfBytes, SettableMetadata(contentType: "application/pdf"));
      final downloadUrl = await storageRef.getDownloadURL();

      // Firestore Güncelle
      await db.collection("loads").doc(widget.loadId).update({
        "ecmrUrl_${widget.role}": downloadUrl,
        "ecmrSignedBy_${widget.role}": true,
        "ecmrSignedAt_${widget.role}": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İmza başarıyla kaydedildi ✅"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dijital İrsaliye İmza")),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text("Lütfen aşağıdaki alana imzanızı atın.")),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
              child: Signature(controller: _controller, backgroundColor: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => _controller.clear(), child: const Text("Temizle"))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: _saveSignature, child: const Text("İmzayı Onayla"))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}