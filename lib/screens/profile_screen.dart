import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/auth_service.dart';
import '../models/load.dart';
import '../app_state.dart';
import 'role_select_screen.dart';
import 'kyc_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<void> _profileFuture;
  final auth = AuthService();
  final db = FirebaseFirestore.instance;
  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }
  bool saving = false;

  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final cityCtrl = TextEditingController();

  // şoför ekstra
  final plateCtrl = TextEditingController();
  final capacityCtrl = TextEditingController();
  final vehicleTypeCtrl = TextEditingController();
  String vehicleType = "Kamyonet";
  String kycStatus = "none"; // Durumu saklamak için yeni değişken



  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    cityCtrl.dispose();
    plateCtrl.dispose();
    capacityCtrl.dispose();
    vehicleTypeCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
  Future<bool> _reauthWithPassword(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final passCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Güvenlik Doğrulaması"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Devam etmek için mevcut şifreni gir."),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Mevcut Şifre"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Devam")),
        ],
      ),
    );

    if (ok != true) return false;

    final pass = passCtrl.text.trim();
    if (pass.isEmpty) {
      _snack("Şifre boş olamaz.");
      return false;
    }

    try {
      final email = user.email!;
      final cred = EmailAuthProvider.credential(email: email, password: pass);
      await user.reauthenticateWithCredential(cred);
      return true;
    } catch (e) {
      _snack("Doğrulama başarısız");
      return false;
    }
  }

  Future<void> _loadProfile() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final snap = await db.collection("users").doc(uid).get();
    final data = snap.data() ?? {};

    // 'extra' isimli kutuyu alıyoruz
    final extra = (data["extra"] is Map) ? Map<String, dynamic>.from(data["extra"]) : <String, dynamic>{};

    setState(() {
      nameCtrl.text = (data["name"] ?? "").toString();
      phoneCtrl.text = (data["phone"] ?? "").toString();
      cityCtrl.text = (data["city"] ?? "").toString();

      // Araç bilgilerini 'extra' içinden okuyoruz
      vehicleType = (extra["vehicleType"] ?? "Kamyonet").toString();
      plateCtrl.text = (extra["plate"] ?? "").toString();
      capacityCtrl.text = (extra["capacityKg"] ?? "").toString();

      // EN ÖNEMLİ SATIR: Onay durumunu 'extra' klasöründen alıyoruz
      kycStatus = (extra["kycStatus"] ?? data["kycStatus"] ?? "none").toString();
    });
  }

  Future<void> _saveProfile() async {
    if (saving) return;
    setState(() => saving = true);

    try {
      final uid = auth.currentUser?.uid;
      if (uid == null) throw Exception("Oturum yok");

      final isDriver = appState.role == "driver";

      final name = nameCtrl.text.trim();
      final phone = phoneCtrl.text.trim();
      final city = cityCtrl.text.trim();

      if (name.isEmpty) throw Exception("Ad Soyad boş olamaz");
      if (phone.length < 10) throw Exception("Telefon en az 10 hane olmalı");
      if (city.isEmpty) throw Exception("Şehir boş olamaz");

      final update = <String, dynamic>{
        "name": name,
        "phone": phone,
        "city": city,
        "updatedAt": FieldValue.serverTimestamp(),
      };

      if (isDriver) {
        final cap = int.tryParse(capacityCtrl.text.trim());
        if (plateCtrl.text.trim().isEmpty) throw Exception("Plaka boş olamaz");
        if (cap == null || cap <= 0) throw Exception("Kapasite geçerli olmalı");

        // Nokta (.) kullanarak sadece ilgili alanları güncelliyoruz.
        // Böylece 'kycStatus' (onay durumu) silinmez.
        update["extra.vehicleType"] = vehicleType;
        update["extra.plate"] = plateCtrl.text.trim();
        update["extra.capacityKg"] = cap;
      }

      await db.collection("users").doc(uid).update(update);

      // AppState isim güncelle
      appState.displayName = name;
      appState.notifyListeners();

      _snack("Bilgiler güncellendi ✅");
    } catch (e) {
      _snack("Hata: $e");
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _changePassword() async {
    final pass1 = TextEditingController();
    final pass2 = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Şifre Değiştir"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: pass1, obscureText: true, decoration: const InputDecoration(labelText: "Yeni şifre")),
            const SizedBox(height: 10),
            TextField(controller: pass2, obscureText: true, decoration: const InputDecoration(labelText: "Yeni şifre tekrar")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Güncelle")),
        ],
      ),
    );

    if (ok != true) return;

    final p1 = pass1.text.trim();
    final p2 = pass2.text.trim();
    if (p1.length < 6) return _snack("Şifre en az 6 karakter olmalı");
    if (p1 != p2) return _snack("Şifreler eşleşmiyor");

    try {
      final okReauth = await _reauthWithPassword(context);
      if (!okReauth) return;

      await FirebaseAuth.instance.currentUser!.updatePassword(p1);
      _snack("Şifre güncellendi ✅");
    } catch (e) {
      _snack("Şifre değiştirilemedi");
    }
  }

  Future<void> _changeEmail() async {
    final emailCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("E-posta Değiştir"),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: "Yeni e-posta"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Güncelle")),
        ],
      ),
    );

    if (ok != true) return;

    final newEmail = emailCtrl.text.trim();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(newEmail)) {
      return _snack("E-posta formatı hatalı");
    }

    try {
      final okReauth = await _reauthWithPassword(context);
      if (!okReauth) return;

      await FirebaseAuth.instance.currentUser!.verifyBeforeUpdateEmail(newEmail);



      _snack("Doğrulama maili gönderildi ✅ Mailden onaylayınca e-posta değişir.");
    } catch (e) {
      _snack("E-posta değiştirilemedi: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid;
    if (uid == null) return const Center(child: Text("Oturum yok."));

    final isDriver = appState.role == "driver";
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil"),
        actions: [
          IconButton(
            tooltip: "Çıkış Yap",
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Çıkış yap"),
                  content: const Text("Hesabından çıkmak istiyor musun?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Vazgeç"),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Çıkış Yap"),
                    ),
                  ],
                ),
              );

              if (ok != true) return;

              await AuthService().logout();
              appState.logout();

              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                    (route) => false,
              );
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: _profileFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(child: Text("Profil yüklenemedi"));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [

              // 🔹 PROFİL KARTI
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [

                      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance
                            .collection("users")
                            .doc(AuthService().currentUser?.uid)
                            .get(),
                        builder: (context, snap) {
                          final d = snap.data?.data() ?? {};
                          final avg = (d["ratingAvg"] is num) ? (d["ratingAvg"] as num).toDouble() : 0.0;
                          final cnt = (d["ratingCount"] is int) ? d["ratingCount"] as int : 0;

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "${avg.toStringAsFixed(1)}  •  $cnt değerlendirme",
                                    style: const TextStyle(fontWeight: FontWeight.w900),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: "Ad Soyad"),
                      ),

                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: "Telefon"),
                      ),
                      const SizedBox(height: 10),


                      TextField(
                        controller: cityCtrl,
                        decoration: const InputDecoration(labelText: "Şehir"),
                      ),

                      const SizedBox(height: 10),

                      if (appState.role == "driver") ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Araç Bilgileri",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),

                        DropdownButtonFormField<String>(
                          value: vehicleType,
                          decoration: const InputDecoration(labelText: "Araç tipi"),
                          items: const [
                            DropdownMenuItem(value: "Kamyonet", child: Text("Kamyonet")),
                            DropdownMenuItem(value: "Kamyon", child: Text("Kamyon")),
                            DropdownMenuItem(value: "Tır", child: Text("Tır")),
                            DropdownMenuItem(value: "Frigo", child: Text("Frigo")),
                          ],
                          onChanged: (v) => setState(() => vehicleType = v ?? "Kamyonet"),
                        ),
                        const SizedBox(height: 10),

                        TextField(
                          controller: plateCtrl,
                          decoration: const InputDecoration(labelText: "Plaka"),
                        ),
                        const SizedBox(height: 10),

                        TextField(
                          controller: capacityCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Kapasite (kg)"),
                        ),
                      ],

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saveProfile,
                          icon: const Icon(Icons.save),
                          label: const Text("Bilgileri Kaydet"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 🔹 ŞİFRE + EMAIL
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock),
                      title: const Text("Şifre Değiştir"),
                      subtitle: const Text("Yeni şifre belirle"),
                      onTap: _changePassword,
                    ),
                    ListTile(
                      leading: const Icon(Icons.alternate_email),
                      title: const Text("E-posta Değiştir"),
                      subtitle: const Text("Hesap e-postasını güncelle"),
                      onTap: _changeEmail,
                    ),
                    const Divider(),
                    if (appState.role == "driver")
                      ListTile(
                        leading: Icon(
                          Icons.verified_user,
                          color: kycStatus == 'approved' ? Colors.green : Colors.blue,
                        ),
                        title: const Text("Hesap Doğrulama (KYC)"),
                        subtitle: Text(
                          kycStatus == 'approved'
                              ? "Hesabınız Onaylandı ✅"
                              : "Ehliyet ve Kimlik Yükle",
                        ),
                        trailing: kycStatus == "approved"
                            ? null
                            : const Icon(Icons.chevron_right),
                        onTap: kycStatus == "approved"
                            ? null
                            : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const KycScreen()),
                          );
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 🔹 GEÇMİŞ İŞLER
              const Text("Geçmiş İşler", style: TextStyle(fontWeight: FontWeight.bold)),

              const SizedBox(height: 8),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection("loads")
                    .where(appState.role == "driver" ? "acceptedDriverId" : "shipperId",
                    isEqualTo: AuthService().currentUser?.uid)
                    .where("status", isEqualTo: "done")
                    .orderBy("doneAt", descending: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) return Text("Hata: ${snap.error}");
                  if (!snap.hasData) return const SizedBox();

                  final jobs = snap.data!.docs.map((d) => Load.fromDoc(d)).toList();

                  if (jobs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.history, color: Theme.of(context).colorScheme.outline),
                          const SizedBox(width: 8),
                          Text(
                            "Henüz tamamlanan iş yok.",
                            style: TextStyle(color: Theme.of(context).colorScheme.outline),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: jobs.map((j) {
                      return Card(
                        child: ListTile(
                          title: Text("${j.fromCity} → ${j.toCity}"),
                          subtitle: Text("${j.weightKg} kg"),
                          trailing: const Icon(Icons.check_circle, color: Colors.green),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 12),

              // 🔴 ÇIKIŞ BUTONU

            ],
          );
        },
      ),
    );
  }
}