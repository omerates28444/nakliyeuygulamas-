import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import 'osm_map_home_screen.dart';
import 'profile_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // final cs = Theme.of(context).colorScheme;
    final isEn = appState.language == "en";
    final db = Supabase.instance.client;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEn ? "Admin Dashboard" : "Yönetim Paneli",
              style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(isEn ? "System Live" : "Sistem Aktif", style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.account_circle_outlined, color: Colors.black), onPressed: () => // ignore: use_build_context_synchronously
Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          // ✅ GERÇEK İSTATİSTİKLER (StreamBuilder ile)
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: db.from("loads").stream(primaryKey: ['id']),
            builder: (context, loadSnap) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: db.from("users").stream(primaryKey: ['id']),
                builder: (context, userSnap) {
                  final totalUsers = userSnap.data?.length ?? 0;
                  final allLoads = loadSnap.data ?? [];
                  final newLoads = allLoads.where((d) => d["status"] == "open").length;
                  
                  // Toplam Hacim Hesaplama (Done olan yüklerin fiyatlarını topla)
                  double totalRevenue = 0;
                  int doneCount = 0;
                  for (var data in allLoads) {
                    if (data["status"] == "done") {
                      doneCount++;
                      totalRevenue += (data["fixedPrice"] ?? 0).toDouble();
                    }
                  }
                  final successRate = allLoads.isEmpty ? 0.0 : (doneCount / allLoads.length) * 100;

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.3, 
                    children: [
                      _buildModernStatCard(isEn ? "Total Volume" : "Toplam Hacim", "\$ ${totalRevenue.toStringAsFixed(0)}", Icons.account_balance_wallet_outlined, Colors.blue),
                      _buildModernStatCard(isEn ? "Active Loads" : "Aktif Yükler", "$newLoads", Icons.local_shipping_outlined, Colors.orange),
                      _buildModernStatCard(isEn ? "Total Users" : "Toplam Kullanıcı", "$totalUsers", Icons.people_outline_rounded, Colors.purple),
                      _buildModernStatCard(isEn ? "Success Rate" : "Başarı Oranı", "% ${successRate.toStringAsFixed(1)}", Icons.trending_up_rounded, Colors.green),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 24),
          _buildSectionHeader(isEn ? "Developer Sandbox" : "Test Simülasyonu"),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
            child: Row(
              children: [
                Expanded(child: _buildTestTab(title: isEn ? "Carrier" : "Şoför", icon: Icons.local_shipping, isSelected: appState.adminViewRole == "driver", onTap: () { appState.adminViewRole = "driver"; // ignore: use_build_context_synchronously
Navigator.push(context, MaterialPageRoute(builder: (_) => const OsmMapHomeScreen())); }, color: Colors.blue)),
                Expanded(child: _buildTestTab(title: isEn ? "Shipper" : "Yük Sahibi", icon: Icons.inventory_2, isSelected: appState.adminViewRole == "shipper", onTap: () { appState.adminViewRole = "shipper"; // ignore: use_build_context_synchronously
Navigator.push(context, MaterialPageRoute(builder: (_) => const OsmMapHomeScreen())); }, color: Colors.deepPurple)),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader(isEn ? "Live Activity" : "Canlı Akış"),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              // En son eklenen 5 yükü getir
              stream: db.from("loads").stream(primaryKey: ['id']).order("createdAt", ascending: false).limit(5),
              builder: (context, snap) {
                if (!snap.hasData) return const LinearProgressIndicator();
                final docs = snap.data!;
                if (docs.isEmpty) return Padding(padding: const EdgeInsets.all(16), child: Text(isEn ? "No activity yet." : "Henüz hareket yok."));

                return Column(
                  children: docs.map((data) {
                    final from = data["fromCity"] ?? "?";
                    final to = data["toCity"] ?? "?";
                    return _buildActivityItem(
                      "$from → $to",
                      isEn ? "New shipment posted" : "Yeni yük ilanı",
                      Icons.add_location_alt_outlined,
                      Colors.blue
                    );
                  }).toList(),
                );
              },
            ),
          ),
          
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
            label: Text(isEn ? "Global Settings" : "Genel Ayarlar"),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -0.5));
  }

  Widget _buildModernStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
              Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestTab({required String title, required IconData icon, required bool isSelected, required VoidCallback onTap, required Color color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: isSelected ? color.withValues(alpha: 0.05) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500, color: isSelected ? color : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, IconData icon, Color color) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 18),
      title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
    );
  }
}