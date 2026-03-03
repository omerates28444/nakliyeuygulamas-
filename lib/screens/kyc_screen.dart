import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  File? _idImage;
  File? _licenseImage;

  bool _isLoading = false;

  // KYC status
  String _kycStatus = "none";
  bool _loadingStatus = true;

  @override
  void initState() {
    super.initState();
    _loadKycStatus();
  }

  Future<void> _loadKycStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingStatus = false);
      return;
    }

    try {
      final doc =
      await FirebaseFirestore.instance.collection("users").doc(uid).get();
      final data = doc.data() ?? {};
      final extra = (data["extra"] is Map)
          ? Map<String, dynamic>.from(data["extra"])
          : <String, dynamic>{};

      setState(() {
        // hem extra hem root destek (senin db karışık olduğu için)
        _kycStatus =
            (extra["kycStatus"] ?? data["kycStatus"] ?? "none").toString();
        _loadingStatus = false;
      });
    } catch (_) {
      setState(() => _loadingStatus = false);
    }
  }

  Future<void> _pickImage(bool isIdCard) async {
    // approved/pending iken tekrar belge yükletmeyelim
    if (_kycStatus == "approved" || _kycStatus == "pending") {
      final msg = _kycStatus == "approved"
          ? "KYC onaylı. Tekrar belge yükleyemezsiniz ✅"
          : "Belgeler incelemede. Şimdilik tekrar yükleyemezsiniz ⏳";
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final picker = ImagePicker();
    final pickedFile =
    await picker.pickImage(source: ImageSource.camera, imageQuality: 50);

    if (pickedFile != null) {
      setState(() {
        if (isIdCard) {
          _idImage = File(pickedFile.path);
        } else {
          _licenseImage = File(pickedFile.path);
        }
      });
    }
  }

  Future<void> _uploadAndSubmit() async {
    // approved/pending iken gönderme engeli
    if (_kycStatus == "approved" || _kycStatus == "pending") return;

    if (_idImage == null || _licenseImage == null) return;

    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      // 1) Kimlik
      final idRef =
      FirebaseStorage.instance.ref().child('kyc/$uid/id_card.jpg');
      await idRef.putFile(_idImage!);
      final idUrl = await idRef.getDownloadURL();

      // 2) Ehliyet
      final licenseRef =
      FirebaseStorage.instance.ref().child('kyc/$uid/license.jpg');
      await licenseRef.putFile(_licenseImage!);
      final licenseUrl = await licenseRef.getDownloadURL();

      // 3) Firestore update (extra içine)
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'extra.idCardUrl': idUrl,
        'extra.licenseUrl': licenseUrl,
        'extra.kycStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Belgeler başarıyla yüklendi! ✅")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _isLoading || _loadingStatus;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hesap Doğrulama", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (_kycStatus == "approved")
          ? _ApprovedView(onBack: () => Navigator.pop(context))
          : (_kycStatus == "pending")
          ? _PendingView(onBack: () => Navigator.pop(context))
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Şoförlük yapabilmeniz için kimlik ve ehliyetinizi yüklemeniz gerekmektedir.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            _buildUploadBox(
                "Kimlik Ön Yüzü", _idImage, () => _pickImage(true)),
            const SizedBox(height: 20),
            _buildUploadBox("Ehliyet Ön Yüzü", _licenseImage,
                    () => _pickImage(false)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_idImage != null && _licenseImage != null)
                    ? _uploadAndSubmit
                    : null,
                child: const Text("Doğrulamaya Gönder"),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildUploadBox(String title, File? image, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: image != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(image, fit: BoxFit.cover),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, size: 40, color: Colors.grey),
            const SizedBox(height: 8),
            Text(title),
          ],
        ),
      ),
    );
  }
}

class _ApprovedView extends StatelessWidget {
  final VoidCallback onBack;
  const _ApprovedView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified, size: 72, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            "KYC Onaylandı ✅",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            "Hesabınız doğrulanmıştır. Tekrar belge yüklemenize gerek yok.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onBack,
              child: const Text("Geri Dön"),
            ),
          )
        ],
      ),
    );
  }
}

class _PendingView extends StatelessWidget {
  final VoidCallback onBack;
  const _PendingView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_top, size: 72, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            "İnceleme Bekleniyor ⏳",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            "Belgeleriniz incelemede. Sonuçlanınca profilinizde güncellenecek.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onBack,
              child: const Text("Geri Dön"),
            ),
          )
        ],
      ),
    );
  }
}