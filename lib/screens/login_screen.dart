import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/auth_service.dart';
import 'app_shell.dart';
import 'role_select_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LoginContent();
  }
}

class _LoginContent extends StatefulWidget {
  const _LoginContent();

  @override
  State<_LoginContent> createState() => _LoginContentState();
}

class _LoginContentState extends State<_LoginContent> {
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
  bool get isAdmin => appState.role == "admin";
  bool get isEn => appState.language == "en";

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  // ✅ Admin girişi için "admin" kelimesine izin veriliyor
  bool _isValidEmail(String email) {
    if (email == "admin") return true; 
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }

  Future<void> submit() async {
    if (loading) return;
    setState(() => loading = true);
    FocusScope.of(context).unfocus();

    try {
      final email = emailCtrl.text.trim();
      final pass = passCtrl.text.trim();

      // ✅ SAHTE ADMIN GİRİŞİ (Firebase'siz test için geri eklendi)
      if (isAdmin && email == "admin" && pass == "admin") {
        appState.login(name: isEn ? "Administrator" : "Yönetici", admin: true);
        _snack(isEn ? "Admin login successful ✅" : "Yönetici girişi başarılı ✅");
        if (!mounted) return;
        _goToApp();
        return;
      }

      if (appState.role.isEmpty) {
        _snack(isEn ? "Please select a role first." : "Önce rol seçmelisin.");
        _goBackToRoleSelect();
        return;
      }

      if (email.isEmpty || pass.isEmpty) {
        _snack(isEn ? "Enter email and password!" : "Email ve şifre gir!");
        return;
      }
      if (!_isValidEmail(email)) {
        _snack(isEn ? "Invalid email format." : "Email formatı hatalı.");
        return;
      }

      if (isRegister) {
        final name = nameCtrl.text.trim();
        final phone = phoneCtrl.text.trim();
        final city = cityCtrl.text.trim();
        final pass2 = pass2Ctrl.text.trim();

        if (name.isEmpty) {
          _snack(isEn ? "Enter Full Name!" : "Ad Soyad gir!");
          return;
        }
        if (phone.length < 10) {
          _snack(isEn ? "Phone must be at least 10 digits." : "Telefon numarası en az 10 hane olmalı.");
          return;
        }
        if (city.isEmpty) {
          _snack(isEn ? "Enter City!" : "Şehir gir!");
          return;
        }
        if (pass2 != pass) {
          _snack(isEn ? "Passwords do not match." : "Şifreler eşleşmiyor.");
          return;
        }
        if (!acceptTerms) {
          _snack(isEn ? "You must accept terms & conditions." : "KVKK / kullanım şartlarını kabul etmelisin.");
          return;
        }

        Map<String, dynamic> driverInfo = {};
        if (isDriver) {
          final plate = plateCtrl.text.trim();
          final cap = int.tryParse(capacityCtrl.text.trim());
          if (plate.isEmpty) {
            _snack(isEn ? "Enter Plate!" : "Plaka gir!");
            return;
          }
          if (cap == null || cap <= 0) {
            _snack(isEn ? "Capacity must be a number." : "Kapasite (kg) sayı olmalı.");
            return;
          }
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

        appState.login(name: name);
        _snack(isEn ? "Registration successful ✅" : "Kayıt başarılı ✅");
        if (!mounted) return;
        _goToApp();
      } else {
        final selectedRole = appState.role;
        final profile = await auth.login(email: email, password: pass);

        final profileRole = (profile['role'] ?? '').toString();
        final profileName = (profile['name'] ?? 'User').toString();

        if (profileRole == "admin") {
          appState.login(name: profileName, admin: true);
          _snack(isEn ? "Login successful ✅" : "Giriş başarılı ✅");
          if (!mounted) return;
          _goToApp();
          return;
        }

        if (profileRole != selectedRole) {
          await auth.logout();
          appState.logout();
          final roleText = isEn 
              ? (profileRole == "driver" ? "Carrier" : "Shipper")
              : (profileRole == "driver" ? "Şoför" : "Yük Sahibi");
          _snack(isEn 
              ? "This email belongs to a '$roleText' account. Select the correct role." 
              : "Bu email '$roleText' hesabına ait. Doğru rolü seçip giriş yap.");
          if (!mounted) return;
          _goBackToRoleSelect();
          return;
        }

        appState.setRole(profileRole);
        appState.login(name: profileName);
        _snack(isEn ? "Login successful ✅" : "Giriş başarılı ✅");
        if (!mounted) return;
        _goToApp();
      }
    } catch (e) {
      _snack("${isEn ? 'Error' : 'Hata'}: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    String roleLabel = "";
    if (isAdmin) roleLabel = isEn ? "Administrator" : "Yönetici";
    else if (isDriver) roleLabel = isEn ? "Carrier" : "Şoför";
    else roleLabel = isEn ? "Shipper" : "Yük Sahibi";

    final titleText = "$roleLabel • ${isRegister ? (isEn ? 'Sign Up' : 'Kayıt Ol') : (isEn ? 'Login' : 'Giriş Yap')}";

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (loading) return;
        _goBackToRoleSelect();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(titleText),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: loading ? null : _goBackToRoleSelect,
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              if (isRegister && !isAdmin) ...[
                _SectionCard(
                  title: isEn ? "Profile Information" : "Profil Bilgileri",
                  child: Column(
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(labelText: isEn ? "Full Name" : "Ad Soyad"),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: phoneCtrl,
                        decoration: InputDecoration(labelText: isEn ? "Phone (05xx...)" : "Telefon (05xx...)"),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: cityCtrl,
                        decoration: InputDecoration(labelText: isEn ? "City" : "Şehir"),
                        textInputAction: TextInputAction.next,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (isDriver) ...[
                  _SectionCard(
                    title: isEn ? "Vehicle Information" : "Araç Bilgileri",
                    subtitle: isEn ? "Required for carrier registration." : "Sadece şoför kayıt ekranında istenir.",
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: vehicleType,
                          decoration: InputDecoration(labelText: isEn ? "Vehicle Type" : "Araç Tipi"),
                          items: const [
                            DropdownMenuItem(value: "Kamyonet", child: Text("Kamyonet")),
                            DropdownMenuItem(value: "Kamyon", child: Text("Kamyon")),
                            DropdownMenuItem(value: "Tır", child: Text("Tır")),
                            DropdownMenuItem(value: "Frigo", child: Text("Frigo")),
                          ],
                          onChanged: loading ? null : (v) => setState(() => vehicleType = v ?? "Kamyonet"),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: plateCtrl,
                          decoration: InputDecoration(labelText: isEn ? "Plate" : "Plaka"),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: capacityCtrl,
                          decoration: InputDecoration(labelText: isEn ? "Capacity (kg)" : "Kapasite (kg)"),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],

              _SectionCard(
                title: isEn ? "Account Information" : "Hesap Bilgileri",
                child: Column(
                  children: [
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: "Email"),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passCtrl,
                      decoration: InputDecoration(labelText: isEn ? "Password" : "Şifre"),
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: (isRegister && !isAdmin) ? TextInputAction.next : TextInputAction.done,
                    ),
                    if (isRegister && !isAdmin) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: pass2Ctrl,
                        decoration: InputDecoration(labelText: isEn ? "Confirm Password" : "Şifre Tekrar"),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              if (isRegister && !isAdmin)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outlineVariant),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: CheckboxListTile(
                    value: acceptTerms,
                    onChanged: loading ? null : (v) => setState(() => acceptTerms = v ?? false),
                    title: Text(isEn ? "I accept Terms & Conditions." : "KVKK / Kullanım şartlarını kabul ediyorum."),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: loading ? null : submit,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (loading) ...[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(isRegister ? (isEn ? "Sign Up" : "Kayıt Ol") : (isEn ? "Login" : "Giriş Yap")),
                    ],
                  ),
                ),
              ),

              if (!isAdmin) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: loading ? null : () => setState(() => isRegister = !isRegister),
                  child: Text(isRegister 
                      ? (isEn ? "Already have an account? Login" : "Zaten hesabım var (Giriş)") 
                      : (isEn ? "Need an account? Sign Up" : "Hesap oluştur (Kayıt)")),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: TextStyle(color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}