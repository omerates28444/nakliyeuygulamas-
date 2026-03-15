import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/auth_service.dart';
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
  final ibanCtrl = TextEditingController(); // 🟢 YENİ: IBAN KONTROLCÜSÜ

  String vehicleType = "Kamyonet";
  String kycStatus = "none";

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    cityCtrl.dispose();
    plateCtrl.dispose();
    capacityCtrl.dispose();
    vehicleTypeCtrl.dispose();
    ibanCtrl.dispose(); // 🟢 YENİ EKLENDİ
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

    final extra = (data["extra"] is Map) ? Map<String, dynamic>.from(data["extra"]) : <String, dynamic>{};

    setState(() {
      nameCtrl.text = (data["name"] ?? "").toString();
      phoneCtrl.text = (data["phone"] ?? "").toString();
      cityCtrl.text = (data["city"] ?? "").toString();

      vehicleType = (extra["vehicleType"] ?? "Kamyonet").toString();
      plateCtrl.text = (extra["plate"] ?? "").toString();
      capacityCtrl.text = (extra["capacityKg"] ?? "").toString();

      // 🟢 YENİ: Firebase'den IBAN'ı okuma
      ibanCtrl.text = (extra["iban"] ?? "").toString();

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
        final iban = ibanCtrl.text.trim().replaceAll(" ", ""); // 🟢 Boşlukları temizle

        if (plateCtrl.text.trim().isEmpty) throw Exception("Plaka boş olamaz");
        if (cap == null || cap <= 0) throw Exception("Kapasite geçerli olmalı");
        if (iban.isNotEmpty && !iban.toUpperCase().startsWith("TR")) {
          throw Exception("IBAN 'TR' ile başlamalıdır");
        }

        update["extra.vehicleType"] = vehicleType;
        update["extra.plate"] = plateCtrl.text.trim();
        update["extra.capacityKg"] = cap;
        update["extra.iban"] = iban.toUpperCase(); // 🟢 YENİ: IBAN'ı kaydet
      }

      await db.collection("users").doc(uid).update(update);

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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profilim", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            tooltip: "Çıkış Yap",
            icon: const Icon(Icons.logout, color: Colors.redAccent),
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
                      style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
                builder: (context, userSnap) {
                  final d = userSnap.data?.data() ?? {};
                  final avg = (d["ratingAvg"] is num) ? (d["ratingAvg"] as num).toDouble() : 5.0;
                  final cnt = (d["ratingCount"] is int) ? d["ratingCount"] as int : 0;

                  String displayName = "İsimsiz";
                  if (d["name"] != null && d["name"].toString().trim().isNotEmpty) {
                    displayName = d["name"].toString();
                  } else if (nameCtrl.text.isNotEmpty) {
                    displayName = nameCtrl.text;
                  }

                  final email = auth.currentUser?.email ?? "";
                  final firstLetter = displayName.toString().isNotEmpty ? displayName.toString().substring(0, 1).toUpperCase() : "?";

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withOpacity(0.8),
                          Theme.of(context).colorScheme.primary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white,
                          child: Text(
                            firstLetter,
                            style: TextStyle(
                              fontSize: 28,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8)),
                              ),
                              if (isDriver) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 18),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${avg.toStringAsFixed(1)} ($cnt Puan)",
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text("Kişisel Bilgiler", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: "Ad Soyad", prefixIcon: Icon(Icons.person_outline)),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: "Telefon", prefixIcon: Icon(Icons.phone_outlined)),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: cityCtrl,
                        decoration: const InputDecoration(labelText: "Şehir", prefixIcon: Icon(Icons.location_city_outlined)),
                      ),
                      const SizedBox(height: 10),

                      if (isDriver) ...[
                        const Divider(height: 30),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Araç & Finans Bilgileri", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: vehicleType,
                          decoration: const InputDecoration(labelText: "Araç tipi", prefixIcon: Icon(Icons.local_shipping_outlined)),
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
                          decoration: const InputDecoration(labelText: "Plaka", prefixIcon: Icon(Icons.pin_outlined)),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: capacityCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Kapasite (kg)", prefixIcon: Icon(Icons.scale_outlined)),
                        ),
                        const SizedBox(height: 10),

                        // 🟢 YENİ: IBAN ALANI EKLENDİ
                        TextField(
                          controller: ibanCtrl,
                          decoration: const InputDecoration(
                            labelText: "Banka IBAN",
                            hintText: "TR...",
                            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 6, left: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Teslimat tamamlandığında ücretiniz bu IBAN'a yatırılacaktır.",
                              style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _saveProfile,
                          icon: const Icon(Icons.save),
                          label: const Text("Bilgileri Kaydet", style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text("Hesap Ayarları", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 1,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text("Şifre Değiştir"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changePassword,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.alternate_email),
                      title: const Text("E-posta Değiştir"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changeEmail,
                    ),
                    if (isDriver) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.verified_user_outlined,
                          color: kycStatus == 'approved' ? Colors.green : Colors.orange,
                        ),
                        title: const Text("Hesap Doğrulama (KYC)"),
                        subtitle: Text(
                          kycStatus == 'approved'
                              ? "Hesabınız Onaylandı ✅"
                              : "Ehliyet ve Kimlik Yükle",
                          style: TextStyle(color: kycStatus == 'approved' ? Colors.green : Colors.orange),
                        ),
                        trailing: kycStatus == "approved" ? null : const Icon(Icons.chevron_right),
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
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text("Geçmiş İşlerim", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection("loads")
                    .where(isDriver ? "acceptedDriverId" : "shipperId", isEqualTo: uid)
                    .where("status", isEqualTo: "done")
                    .orderBy("doneAt", descending: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) return Center(child: Text("Hata: ${snap.error}"));
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                  final jobsDoc = snap.data?.docs ?? [];

                  if (jobsDoc.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16)
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.history, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text("Henüz tamamlanan iş yok.", style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: jobsDoc.map((d) {
                      final data = d.data();
                      final fromCity = data["fromCity"] ?? "Bilinmiyor";
                      final toCity = data["toCity"] ?? "Bilinmiyor";
                      final weight = data["weightKg"] ?? "0";

                      String dateStr = "";
                      final doneAt = data["doneAt"] as Timestamp?;
                      if (doneAt != null) {
                        final dt = doneAt.toDate();
                        dateStr = "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}";
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isDriver ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                            child: Icon(
                              isDriver ? Icons.local_shipping : Icons.outbox,
                              color: isDriver ? Colors.orange : Colors.blue,
                            ),
                          ),
                          title: Text("$fromCity ➔ $toCity", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              isDriver ? "Yük Taşıdınız • $weight kg" : "Yük Gönderdiniz • $weight kg",
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "Tamamlandı",
                                  style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (dateStr.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              ]
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              if (isDriver) ...[
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text("Değerlendirmelerim", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection("ratings").where("toUserId", isEqualTo: uid).snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                    final docs = snap.data!.docs.toList();
                    docs.sort((a, b) {
                      final ta = (a.data()["createdAt"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                      final tb = (b.data()["createdAt"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                      return tb.compareTo(ta);
                    });

                    if (docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                        child: Text("Henüz bir yorum almadınız.", style: TextStyle(color: Colors.grey.shade600)),
                      );
                    }

                    return Column(
                      children: docs.map((d) {
                        final data = d.data();
                        final stars = data["stars"] ?? 5;
                        final note = data["note"] ?? "";

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Row(
                              children: List.generate(5, (i) => Icon(
                                i < stars ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 18,
                              )),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(note.toString().trim().isEmpty ? "Yorum yapılmadı." : "❝ $note ❞", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade800)),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}