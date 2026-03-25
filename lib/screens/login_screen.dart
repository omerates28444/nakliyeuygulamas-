import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/auth_service.dart';
import 'app_shell.dart';
import 'role_select_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final auth = AuthService();

  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  final pass2Ctrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final cityCtrl = TextEditingController();

  final plateCtrl = TextEditingController();
  final capacityCtrl = TextEditingController();
  String vehicleType = "Kamyonet";

  bool isRegister = false;
  bool loading = false;
  bool acceptTerms = false;

  // 🟢 OSM MAP / FERAH TEMA RENKLERİ 🟢
  final Color primaryDark = const Color(0xFF081226); // Sadece yazılar için
  final Color primaryBlue = const Color(0xFF1976D2); // Butonlar ve ikonlar için (Harita Mavisi)

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    pass2Ctrl.dispose();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    cityCtrl.dispose();
    plateCtrl.dispose();
    capacityCtrl.dispose();
    super.dispose();
  }

  bool get isDriver => appState.role == "driver";

  void _snack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        )
    );
  }

  void _goToApp() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AppShell()),
          (route) => false,
    );
  }

  void _goBackToRoleSelect() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
          (route) => false,
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }

  Future<void> submit() async {
    if (loading) return;
    setState(() => loading = true);
    FocusScope.of(context).unfocus();

    try {
      final email = emailCtrl.text.trim();
      final pass = passCtrl.text.trim();

      if (appState.role.isEmpty) {
        _snack("Önce rol seçmelisin.");
        _goBackToRoleSelect();
        return;
      }

      if (email.isEmpty || pass.isEmpty) {
        _snack("Lütfen e-posta ve şifrenizi girin.");
        return;
      }
      if (!_isValidEmail(email)) {
        _snack("Geçersiz e-posta formatı.");
        return;
      }
      if (pass.length < 6) {
        _snack("Şifreniz en az 6 karakter olmalıdır.");
        return;
      }

      if (isRegister) {
        final name = nameCtrl.text.trim();
        final phone = phoneCtrl.text.trim();
        final city = cityCtrl.text.trim();
        final pass2 = pass2Ctrl.text.trim();

        if (name.isEmpty) return _snack("Ad Soyad giriniz.");
        if (phone.length < 10) return _snack("Geçerli bir telefon numarası giriniz.");
        if (city.isEmpty) return _snack("Şehir giriniz.");
        if (pass2 != pass) return _snack("Şifreler eşleşmiyor.");
        if (!acceptTerms) return _snack("Kullanım şartlarını kabul etmelisiniz.");

        Map<String, dynamic> driverInfo = {};
        if (isDriver) {
          final plate = plateCtrl.text.trim();
          final cap = int.tryParse(capacityCtrl.text.trim());

          if (plate.isEmpty) return _snack("Araç plakası giriniz.");
          if (cap == null || cap <= 0) return _snack("Geçerli bir kapasite (kg) giriniz.");

          driverInfo = {"vehicleType": vehicleType, "plate": plate, "capacityKg": cap};
        }

        await auth.register(
          email: email,
          password: pass,
          name: name,
          role: appState.role,
          phone: phone,
          city: city,
          extra: driverInfo,
        );

        int? registeredCapacity;
        if (isDriver) {
          registeredCapacity = int.tryParse(capacityCtrl.text.trim());
        }
        appState.login(name: name, capacity: registeredCapacity);

        _snack("Kayıt başarılı! Yönlendiriliyorsunuz...", isError: false);
        if (!mounted) return;
        _goToApp();
      } else {
        final selectedRole = appState.role;
        final profile = await auth.login(email: email, password: pass);

        final profileRole = (profile['role'] ?? '').toString();
        final profileName = (profile['name'] ?? 'Kullanıcı').toString();

        if (profileRole != "driver" && profileRole != "shipper") {
          await auth.logout();
          _snack("Hesap rolü bulunamadı.");
          return;
        }

        if (profileRole != selectedRole) {
          await auth.logout();
          return _snack("Bu hesap bir '$profileRole' hesabı. Lütfen doğru rolden giriş yapın.");
        }

        int? loginCapacity;
        if (profileRole == "driver" && profile['extra'] != null) {
          loginCapacity = (profile['extra']['capacityKg'] as num?)?.toInt();
        }

        appState.setRole(profileRole);
        appState.login(name: profileName, capacity: loginCapacity);

        _snack("Giriş başarılı! Hoş geldiniz.", isError: false);
        if (!mounted) return;
        _goToApp();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _snack("E-posta veya şifre hatalı.");
      } else if (e.code == 'email-already-in-use') {
        _snack("Bu e-posta adresi ile zaten bir hesap var.");
      } else if (e.code == 'network-request-failed') {
        _snack("İnternet bağlantınızı kontrol edin.");
      } else if (e.code == 'invalid-email') {
        _snack("Geçersiz bir e-posta adresi girdiniz.");
      } else if (e.code == 'weak-password') {
        _snack("Şifreniz çok zayıf, daha güçlü bir şifre belirleyin.");
      } else {
        _snack("Bir sorun oluştu: ${e.message}");
      }
    } catch (e) {
      _snack("Beklenmeyen bir hata oluştu: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // 🟢 YARDIMCI WIDGET: OSM MAP STİLİ TEXTFIELD 🟢
  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool isPass = false, TextInputType type = TextInputType.text, TextInputAction action = TextInputAction.next}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPass,
        keyboardType: type,
        textInputAction: action,
        style: TextStyle(fontWeight: FontWeight.w600, color: primaryDark),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal),
          prefixIcon: Icon(icon, color: primaryBlue, size: 22),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryBlue, width: 2)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = isDriver ? "Şoför" : "Yük Sahibi";

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (loading) return;
        _goBackToRoleSelect();
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50, // Ferah harita arka planı
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
              child: Icon(Icons.arrow_back_ios_new, color: primaryDark, size: 18),
            ),
            onPressed: loading ? null : _goBackToRoleSelect,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 🟢 LOGO ALANI 🟢
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset('assets/icon.png', fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.local_shipping, size: 45, color: primaryBlue);
                    }),
                  ),
                ),
                const SizedBox(height: 24),

                // 🟢 KARŞILAMA METNİ 🟢
                Text(
                  isRegister ? "Hesap Oluştur" : "Tekrar Hoş Geldiniz",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: primaryDark),
                ),
                const SizedBox(height: 6),
                Text(
                  "$roleLabel olarak devam ediyorsunuz.",
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 32),

                // 🟢 KAYIT FORMU 🟢
                if (isRegister) ...[
                  _SectionCard(
                    title: "Kişisel Bilgiler",
                    child: Column(
                      children: [
                        _buildTextField("Ad Soyad", Icons.person_outline, nameCtrl),
                        _buildTextField("Telefon (05xx...)", Icons.phone_outlined, phoneCtrl, type: TextInputType.phone),
                        _buildTextField("Şehir", Icons.location_city_outlined, cityCtrl, action: isDriver ? TextInputAction.next : TextInputAction.done),
                      ],
                    ),
                  ),
                  if (isDriver) ...[
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: "Araç Bilgileri",
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: DropdownButtonFormField<String>(
                              value: vehicleType,
                              style: TextStyle(fontWeight: FontWeight.w600, color: primaryDark),
                              decoration: InputDecoration(
                                labelText: "Araç Tipi",
                                prefixIcon: Icon(Icons.local_shipping_outlined, color: primaryBlue, size: 22),
                                filled: true, fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryBlue, width: 2)),
                              ),
                              items: const [
                                DropdownMenuItem(value: "Kamyonet", child: Text("Kamyonet")),
                                DropdownMenuItem(value: "Kamyon", child: Text("Kamyon")),
                                DropdownMenuItem(value: "Tır", child: Text("Tır")),
                                DropdownMenuItem(value: "Frigo", child: Text("Frigo")),
                              ],
                              onChanged: loading ? null : (v) => setState(() => vehicleType = v ?? "Kamyonet"),
                            ),
                          ),
                          _buildTextField("Plaka", Icons.pin_outlined, plateCtrl),
                          _buildTextField("Kapasite (kg)", Icons.scale_outlined, capacityCtrl, type: TextInputType.number, action: TextInputAction.done),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],

                // 🟢 GİRİŞ / HESAP FORMU 🟢
                _SectionCard(
                  title: "Hesap Bilgileri",
                  child: Column(
                    children: [
                      _buildTextField("E-posta Adresi", Icons.alternate_email, emailCtrl, type: TextInputType.emailAddress),
                      _buildTextField("Şifre (min 6 karakter)", Icons.lock_outline, passCtrl, isPass: true, action: isRegister ? TextInputAction.next : TextInputAction.done),
                      if (isRegister)
                        _buildTextField("Şifre Tekrar", Icons.lock_outline, pass2Ctrl, isPass: true, action: TextInputAction.done),
                    ],
                  ),
                ),

                if (isRegister) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: CheckboxListTile(
                      value: acceptTerms,
                      activeColor: primaryBlue,
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      onChanged: loading ? null : (v) => setState(() => acceptTerms = v ?? false),
                      title: Text("KVKK ve Kullanım Şartlarını okudum, onaylıyorum.", style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // 🟢 ANA BUTON (HARİTA STİLİ FERAH MAVİ) 🟢
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryBlue, // Haritadaki canlı mavi buton
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    onPressed: loading ? null : submit,
                    child: loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(
                      isRegister ? "Kayıt Ol" : "Giriş Yap",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 🟢 GEÇİŞ BUTONU 🟢
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isRegister ? "Zaten hesabınız var mı?" : "Hesabınız yok mu?",
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    TextButton(
                      onPressed: loading ? null : () => setState(() {
                        isRegister = !isRegister;
                        passCtrl.clear();
                        if (!isRegister) pass2Ctrl.clear();
                      }),
                      style: TextButton.styleFrom(foregroundColor: primaryBlue),
                      child: Text(
                        isRegister ? "Giriş Yap" : "Hemen Kayıt Ol",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 🟢 FERAH KART WIDGET'I (Osm Map Stili) 🟢
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0, left: 4),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF081226))),
            ),
            child,
          ],
        ),
      ),
    );
  }
}