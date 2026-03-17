import 'package:flutter/material.dart';
import '../app_state.dart';
import 'login_screen.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final isEn = appState.language == "en";

        // ✅ Basit Dil Map'i
        final texts = {
          "title": isEn ? "RoadMap" : "RoadMap",
          "subtitle": isEn ? "Global Logistics Network" : "Küresel Lojistik Ağı",
          "welcome": isEn ? "Welcome back.\nPlease select your portal to continue." : "Tekrar hoş geldiniz.\nDevam etmek için bir portal seçin.",
          "carrierTitle": isEn ? "Carrier Portal" : "Nakliyeci Portalı",
          "carrierSub": isEn ? "Find loads, manage trips, and grow your fleet." : "Yük bulun, seferleri yönetin ve filonuzu büyütün.",
          "shipperTitle": isEn ? "Shipper Portal" : "Yük Sahibi Portalı",
          "shipperSub": isEn ? "Post shipments, track deliveries, and optimize costs." : "Yük ilanı verin, teslimatları takip edin ve maliyetleri düşürün.",
          "footer": isEn ? "Trusted by 10,000+ professionals worldwide." : "Dünya çapında 10.000+ profesyonel tarafından güvenilen."
        };

        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              Positioned(
                top: -100,
                right: -100,
                child: CircleAvatar(
                  radius: 150,
                  backgroundColor: cs.primary.withOpacity(0.05),
                ),
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // ✅ Expanded eklendi: Metinler sığmadığında ikonları sıkıştırmaz
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  texts["title"]!,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: cs.primary,
                                    letterSpacing: -1,
                                  ),
                                ),
                                Text(
                                  texts["subtitle"]!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis, // Sığmazsa üç nokta koy
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              // ✅ DİL SEÇİMİ (TR / EN)
                              TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  appState.setLanguage(isEn ? "tr" : "en");
                                },
                                child: Text(isEn ? "TR" : "EN", style: const TextStyle(fontWeight: FontWeight.w900)),
                              ),
                              // ✅ Admin İkonu
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                                onPressed: () {
                                  appState.setRole("admin");
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  );
                                },
                                icon: Icon(Icons.admin_panel_settings_outlined, color: cs.primary.withOpacity(0.5)),
                                tooltip: isEn ? "Admin Access" : "Yönetici Erişimi",
                              ),
                            ],
                          ),
                        ],
                      ),

                      const Spacer(),

                      Text(
                        texts["welcome"]!,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 32),

                      _ModernRoleCard(
                        title: texts["carrierTitle"]!,
                        subtitle: texts["carrierSub"]!,
                        icon: Icons.local_shipping_rounded,
                        onTap: () {
                          appState.setRole("driver");
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                        },
                      ),

                      const SizedBox(height: 16),

                      _ModernRoleCard(
                        title: texts["shipperTitle"]!,
                        subtitle: texts["shipperSub"]!,
                        icon: Icons.inventory_2_rounded,
                        onTap: () {
                          appState.setRole("shipper");
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                        },
                      ),

                      const Spacer(flex: 2),

                      Center(
                        child: Text(
                          texts["footer"]!,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant.withOpacity(0.7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModernRoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModernRoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: cs.primary, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: cs.primary.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}