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

  final plateCtrl = TextEditingController();
  final capacityCtrl = TextEditingController();
  final vehicleTypeCtrl = TextEditingController();
  final ibanCtrl = TextEditingController();

  String vehicleType = "Kamyonet";
  String kycStatus = "none";

  // Harita Arayüzü Renkleri (Ferah ve Temiz)
  final Color primaryDark = const Color(0xFF081226); // Sadece yazılar için
  final Color primaryBlue = const Color(0xFF1976D2); // Butonlar ve ikonlar için

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    cityCtrl.dispose();
    plateCtrl.dispose();
    capacityCtrl.dispose();
    vehicleTypeCtrl.dispose();
    ibanCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  Future<bool> _reauthWithPassword(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final passCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("Güvenlik Doğrulaması", style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Devam etmek için mevcut şifreni gir."),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Mevcut Şifre",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: primaryBlue), onPressed: () => Navigator.pop(context, true), child: const Text("Devam")),
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
        final iban = ibanCtrl.text.trim().replaceAll(" ", "");

        if (plateCtrl.text.trim().isEmpty) throw Exception("Plaka boş olamaz");
        if (cap == null || cap <= 0) throw Exception("Kapasite geçerli olmalı");
        if (iban.isNotEmpty && !iban.toUpperCase().startsWith("TR")) {
          throw Exception("IBAN 'TR' ile başlamalıdır");
        }

        update["extra.vehicleType"] = vehicleType;
        update["extra.plate"] = plateCtrl.text.trim();
        update["extra.capacityKg"] = cap;
        update["extra.iban"] = iban.toUpperCase();
      }

      await db.collection("users").doc(uid).update(update);

      appState.displayName = name;
      appState.notifyListeners();

      _snack("Bilgiler başarıyla güncellendi ✅");
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
        backgroundColor: Colors.white,
        title: const Text("Şifre Değiştir", style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: pass1, obscureText: true, decoration: InputDecoration(labelText: "Yeni şifre", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            TextField(controller: pass2, obscureText: true, decoration: InputDecoration(labelText: "Yeni şifre tekrar", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: primaryBlue), onPressed: () => Navigator.pop(context, true), child: const Text("Güncelle")),
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
      _snack("Şifre başarıyla güncellendi ✅");
    } catch (e) {
      _snack("Şifre değiştirilemedi");
    }
  }

  Future<void> _changeEmail() async {
    final emailCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("E-posta Değiştir", style: TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: "Yeni e-posta", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: primaryBlue), onPressed: () => Navigator.pop(context, true), child: const Text("Güncelle")),
        ],
      ),
    );

    if (ok != true) return;
    final newEmail = emailCtrl.text.trim();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(newEmail)) return _snack("E-posta formatı hatalı");

    try {
      final okReauth = await _reauthWithPassword(context);
      if (!okReauth) return;
      await FirebaseAuth.instance.currentUser!.verifyBeforeUpdateEmail(newEmail);
      _snack("Doğrulama maili gönderildi ✅ Mailden onaylayınca e-posta değişir.");
    } catch (e) {
      _snack("E-posta değiştirilemedi: $e");
    }
  }

  // YARDIMCI WIDGET: Harita Paneli Tarzı TextField
  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        style: const TextStyle(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal),
          prefixIcon: Icon(icon, color: primaryBlue, size: 22),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryBlue, width: 1.5)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text("Oturum yok.")));

    final isDriver = appState.role == "driver";

    return Scaffold(
      backgroundColor: Colors.grey.shade50, // Arka planı çok hafif gri yaptık, beyaz kartlar öne çıksın
      appBar: AppBar(
        title: Text("Profilim", style: TextStyle(fontWeight: FontWeight.w900, color: primaryDark, fontSize: 22)),
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: primaryDark),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: "Çıkış Yap",
            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 26),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: const Text("Çıkış yap"),
                  content: const Text("Hesabından çıkmak istiyor musun?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
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
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RoleSelectScreen()), (route) => false);
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: _profileFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            children: [
              // 🟢 FERAH PROFİL KARTI (Harita stili)
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
                  final firstLetter = displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : "?";

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        // Haritadaki gibi hafif saydam mavi arkaplanlı avatar
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: primaryBlue.withOpacity(0.12),
                          child: Text(
                            firstLetter,
                            style: TextStyle(fontSize: 30, color: primaryBlue, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryDark)),
                              const SizedBox(height: 2),
                              Text(email, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                              if (isDriver) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star_rounded, color: Colors.orange.shade800, size: 18),
                                      const SizedBox(width: 4),
                                      Text("${avg.toStringAsFixed(1)} ($cnt)", style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w800, fontSize: 12)),
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

              const SizedBox(height: 24),

              // 🟢 KİŞİSEL BİLGİLER
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text("Kişisel Bilgiler", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryDark)),
              ),
              _buildTextField("Ad Soyad", Icons.person_outline, nameCtrl),
              _buildTextField("Telefon", Icons.phone_outlined, phoneCtrl, type: TextInputType.phone),
              _buildTextField("Şehir", Icons.location_city_outlined, cityCtrl),

              if (isDriver) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.black12),
                const SizedBox(height: 16),

                // 🟢 ARAÇ VE FİNANS BİLGİLERİ
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text("Araç & Finans Bilgileri", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryDark)),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: DropdownButtonFormField<String>(
                    value: vehicleType,
                    style: TextStyle(fontWeight: FontWeight.w600, color: primaryDark),
                    decoration: InputDecoration(
                      labelText: "Araç tipi",
                      labelStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal),
                      prefixIcon: Icon(Icons.local_shipping_outlined, color: primaryBlue, size: 22),
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryBlue, width: 1.5)),
                    ),
                    items: const [
                      DropdownMenuItem(value: "Kamyonet", child: Text("Kamyonet")),
                      DropdownMenuItem(value: "Kamyon", child: Text("Kamyon")),
                      DropdownMenuItem(value: "Tır", child: Text("Tır")),
                      DropdownMenuItem(value: "Frigo", child: Text("Frigo")),
                    ],
                    onChanged: (v) => setState(() => vehicleType = v ?? "Kamyonet"),
                  ),
                ),
                _buildTextField("Plaka", Icons.pin_outlined, plateCtrl),
                _buildTextField("Kapasite (kg)", Icons.scale_outlined, capacityCtrl, type: TextInputType.number),
                _buildTextField("Banka IBAN (TR...)", Icons.account_balance_wallet_outlined, ibanCtrl),

                // 🟢 FERAH BİLGİ KUTUSU (Harita stili soft yeşil)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.2))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Teslimat tamamlandığında ücretiniz hiçbir kesinti olmadan bu IBAN'a yatırılacaktır.",
                          style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w600, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // 🟢 KAYDET BUTONU (Haritadaki FAB rengi)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _saveProfile,
                  icon: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save, size: 22),
                  label: Text(saving ? "Kaydediliyor..." : "Bilgileri Kaydet", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 32),

              // 🟢 HESAP AYARLARI
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text("Hesap Ayarları", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryDark)),
              ),

              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.lock_outline, color: primaryBlue, size: 20)),
                      title: Text("Şifre Değiştir", style: TextStyle(fontWeight: FontWeight.w700, color: primaryDark)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: _changePassword,
                    ),
                    const Divider(height: 1, indent: 60),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.alternate_email, color: primaryBlue, size: 20)),
                      title: Text("E-posta Değiştir", style: TextStyle(fontWeight: FontWeight.w700, color: primaryDark)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: _changeEmail,
                    ),
                    if (isDriver) ...[
                      const Divider(height: 1, indent: 60),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: kycStatus == 'approved' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.verified_user_outlined, color: kycStatus == 'approved' ? Colors.green.shade700 : Colors.orange.shade800, size: 20),
                        ),
                        title: Text("Hesap Doğrulama (KYC)", style: TextStyle(fontWeight: FontWeight.w700, color: primaryDark)),
                        subtitle: Text(
                          kycStatus == 'approved' ? "Hesabınız Onaylandı" : "Ehliyet ve Kimlik Yükle",
                          style: TextStyle(color: kycStatus == 'approved' ? Colors.green.shade700 : Colors.orange.shade800, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        trailing: kycStatus == "approved" ? null : const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: kycStatus == "approved" ? null : () => Navigator.push(context, MaterialPageRoute(builder: (context) => const KycScreen())),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 🟢 GEÇMİŞ İŞLERİM
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text("Geçmiş İşlerim", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryDark)),
              ),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection("loads").where(isDriver ? "acceptedDriverId" : "shipperId", isEqualTo: uid).where("status", isEqualTo: "done").orderBy("doneAt", descending: true).snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) return Center(child: Text("Hata: ${snap.error}"));
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                  final jobsDoc = snap.data?.docs ?? [];

                  if (jobsDoc.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(
                        children: [
                          Icon(Icons.history, size: 40, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text("Henüz tamamlanan iş yok.", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 14)),
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

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: isDriver ? Colors.orange.withOpacity(0.1) : primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Icon(isDriver ? Icons.local_shipping_outlined : Icons.outbox_outlined, color: isDriver ? Colors.orange.shade800 : primaryBlue),
                          ),
                          title: Text("$fromCity ➔ $toCity", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: primaryDark)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(isDriver ? "Taşıdınız • $weight kg" : "Gönderdiniz • $weight kg", style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                child: Text("Tamamlandı", style: TextStyle(color: Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.w800)),
                              ),
                              if (dateStr.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
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
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text("Değerlendirmelerim", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryDark)),
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
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                        child: Text("Henüz bir yorum almadınız.", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 14)),
                      );
                    }

                    return Column(
                      children: docs.map((d) {
                        final data = d.data();
                        final stars = data["stars"] ?? 5;
                        final note = data["note"] ?? "";

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: List.generate(5, (i) => Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 20)),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  note.toString().trim().isEmpty ? "Yorum yapılmadı." : "❝ $note ❞",
                                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade700, fontSize: 14, height: 1.4),
                                ),
                              ],
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