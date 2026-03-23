import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/auth_service.dart';
import 'app_shell.dart';
import 'role_select_screen.dart';

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
        _snack("Email ve şifre gir!");
        return;
      }
      if (!_isValidEmail(email)) {
        _snack("Email formatı hatalı.");
        return;
      }
      if (pass.length < 6) {
        _snack("Şifre en az 6 karakter olmalı.");
        return;
      }

      if (isRegister) {
        final name = nameCtrl.text.trim();
        final phone = phoneCtrl.text.trim();
        final city = cityCtrl.text.trim();
        final pass2 = pass2Ctrl.text.trim();

        if (name.isEmpty) {
          _snack("Ad Soyad gir!");
          return;
        }
        if (phone.length < 10) {
          _snack("Telefon numarası en az 10 hane olmalı.");
          return;
        }
        if (city.isEmpty) {
          _snack("Şehir gir!");
          return;
        }
        if (pass2 != pass) {
          _snack("Şifreler eşleşmiyor.");
          return;
        }
        if (!acceptTerms) {
          _snack("KVKK / kullanım şartlarını kabul etmelisin.");
          return;
        }

        Map<String, dynamic> driverInfo = {};
        if (isDriver) {
          final plate = plateCtrl.text.trim();
          final cap = int.tryParse(capacityCtrl.text.trim());

          if (plate.isEmpty) {
            _snack("Plaka gir!");
            return;
          }
          if (cap == null || cap <= 0) {
            _snack("Kapasite (kg) sayı olmalı.");
            return;
          }

          driverInfo = {
            "vehicleType": vehicleType,
            "plate": plate,
            "capacityKg": cap
          };
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
        _snack("Kayıt başarılı ✅");
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
          appState.logout();

          final roleText = profileRole == "driver" ? "Şoför" : "Yük Sahibi";
          _snack(
              "Bu email '$roleText' hesabına ait. Doğru rolü seçip giriş yap.");

          if (!mounted) return;
          _goBackToRoleSelect();
          return;
        }

        appState.setRole(profileRole);
        appState.login(name: profileName);

        _snack("Giriş başarılı ✅");
        if (!mounted) return;
        _goToApp();
      }
    } catch (e) {
      _snack("Hata: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final roleLabel = isDriver ? "Şoför" : "Yük Sahibi";

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (loading) return;
        _goBackToRoleSelect();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("$roleLabel • ${isRegister ? 'Kayıt Ol' : 'Giriş Yap'}"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: loading ? null : _goBackToRoleSelect,
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              if (isRegister) ...[
                _SectionCard(
                  title: "Profil Bilgileri",
                  child: Column(
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration:
                            const InputDecoration(labelText: "Ad Soyad"),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(
                            labelText: "Telefon (05xx...)"),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: cityCtrl,
                        decoration: const InputDecoration(labelText: "Şehir"),
                        textInputAction: TextInputAction.next,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (isDriver) ...[
                  _SectionCard(
                    title: "Araç Bilgileri",
                    subtitle: "Sadece şoför kayıt ekranında istenir.",
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: vehicleType,
                          decoration:
                              const InputDecoration(labelText: "Araç Tipi"),
                          items: const [
                            DropdownMenuItem(
                                value: "Kamyonet", child: Text("Kamyonet")),
                            DropdownMenuItem(
                                value: "Kamyon", child: Text("Kamyon")),
                            DropdownMenuItem(value: "Tır", child: Text("Tır")),
                            DropdownMenuItem(
                                value: "Frigo", child: Text("Frigo")),
                          ],
                          onChanged: loading
                              ? null
                              : (v) =>
                                  setState(() => vehicleType = v ?? "Kamyonet"),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: plateCtrl,
                          decoration: const InputDecoration(labelText: "Plaka"),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: capacityCtrl,
                          decoration:
                              const InputDecoration(labelText: "Kapasite (kg)"),
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
                title: "Hesap Bilgileri",
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
                      decoration:
                          const InputDecoration(labelText: "Şifre (min 6)"),
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: isRegister
                          ? TextInputAction.next
                          : TextInputAction.done,
                    ),
                    if (isRegister) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: pass2Ctrl,
                        decoration:
                            const InputDecoration(labelText: "Şifre Tekrar"),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (isRegister)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outlineVariant),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: CheckboxListTile(
                    value: acceptTerms,
                    onChanged: loading
                        ? null
                        : (v) => setState(() => acceptTerms = v ?? false),
                    title: const Text(
                        "KVKK / Kullanım şartlarını kabul ediyorum."),
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
                      Text(isRegister ? "Kayıt Ol" : "Giriş Yap"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: loading
                    ? null
                    : () => setState(() => isRegister = !isRegister),
                child: Text(isRegister
                    ? "Zaten hesabım var (Giriş)"
                    : "Hesap oluştur (Kayıt)"),
              ),
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
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
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
