import 'package:flutter/material.dart';
import '../app_state.dart';
import 'login_screen.dart';
import 'package:flutter/services.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  // 🟢 LOGIMAP 2026 RENKLERİ 🟢
  final Color logimapNavy = const Color(0xFF081226);
  final Color logimapBlue = const Color(0xFF1976D2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50, // Ferah arkaplan
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          children: [
            // 🟢 LOGO VE BAŞLIK ALANI 🟢
            Center(
              child: Column(
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: logimapNavy.withOpacity(0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        "assets/logo.png",
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Eğer logo dosyası henüz yoksa şık bir ikon gösterir
                          return Icon(Icons.local_shipping, size: 60, color: logimapBlue);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "LogiMap",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: logimapNavy,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Akıllı Nakliye Platformu",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),

            // 🟢 ŞOFÖR KARTI 🟢
            _RoleCard(
              title: "Şoför",
              subtitle: "Haritadan işleri gör, teklif ver ve kabul edilen işlere yol tarifini aç.",
              icon: Icons.local_shipping_outlined,
              iconColor: logimapBlue,
              onTap: () {
                appState.setRole("driver");
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
            const SizedBox(height: 16),

            // 🟢 YÜK SAHİBİ KARTI 🟢
            _RoleCard(
              title: "Yük Sahibi",
              subtitle: "İlan ver, gelen teklifleri gör ve en uygun şoförle işi eşleştir.",
              icon: Icons.inventory_2_outlined,
              iconColor: logimapBlue,
              onTap: () {
                appState.setRole("shipper");
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
            const SizedBox(height: 32),

            // 🟢 BİLGİLENDİRME KUTUSU 🟢
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.grey.shade600, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Rol seçimi sadece arayüz yönlendirmesi içindir. Hesap rolü Firestore profilinden doğrulanır.",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 🟢 ÇIKIŞ BUTONU 🟢
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                icon: const Icon(Icons.exit_to_app, size: 20),
                label: const Text("Uygulamadan Çık", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () {
                  SystemNavigator.pop();
                },
              ),
            ),
            const SizedBox(height: 40),

            // 🟢 FOOTER 🟢
            Center(
              child: Column(
                children: [
                  Text("LogiMap v1.0", style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text("© 2026 LogiMap", style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🟢 ÖZEL MODERN ROL KARTI WIDGET'I 🟢
class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // İkon Kutusu
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 28, color: iconColor),
                ),
                const SizedBox(width: 16),
                // Yazılar
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Color(0xFF081226),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Sağ Ok (Chevron)
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}