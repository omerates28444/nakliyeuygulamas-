import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/load.dart';
import '../services/auth_service.dart';

class ActiveJobsScreen extends StatelessWidget {
  final void Function(String jobId)
      onOpenOnMap; // (artık zorunlu değil ama dursun)

  const ActiveJobsScreen({super.key, required this.onOpenOnMap});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.id;

    if (uid == null) {
      return const Center(child: Text("Oturum yok. Tekrar giriş yap."));
    }

    final stream = Supabase.instance.client
        .from("loads")
        .stream(primaryKey: ['id'])
        .eq("acceptedDriverId", uid)
        .order("createdAt", ascending: false);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text("Hata: ${snap.error}"));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allJobs = snap.data!.map((d) => Load.fromMap(d)).toList();
        final jobs = allJobs.where((j) => j.status == 'matched' || j.status == 'delivered_pending').toList();

        if (jobs.isEmpty) {
          return const Center(child: Text("Henüz kabul edilen işin yok."));
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text("Aktif İşler",
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            ...jobs.map((j) {
              final cs = Theme.of(context).colorScheme;
              final isPending = j.status == "delivered_pending";

              Widget pill(String text, {required Color color, IconData? icon}) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color),
                    color: color.withValues(alpha: 0.12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 16, color: color),
                        const SizedBox(width: 6),
                      ],
                      Text(text,
                          style: TextStyle(
                              fontWeight: FontWeight.w800, color: color)),
                    ],
                  ),
                );
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Üst satır: rota + durum rozeti
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: cs.surfaceContainerHighest,
                              child: Icon(Icons.work_outline,
                                  color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "${j.fromCity} → ${j.toCity}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isPending)
                              pill("Onay bekliyor",
                                  color: Colors.orange,
                                  icon: Icons.hourglass_bottom)
                            else
                              pill("Aktif",
                                  color: Colors.green,
                                  icon: Icons.check_circle_outline),
                          ],
                        ),

                        const SizedBox(height: 6),
                        Text(
                          "${j.weightKg} kg • ${j.priceType == 'fixed' ? '${j.fixedPrice} ₺' : 'Teklif'}",
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openGoogleMaps(context, j),
                                icon: const Icon(Icons.directions),
                                label: const Text("Yol tarifi"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: (!isPending)
                                    ? () async {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title:
                                                const Text("Teslim edildi mi?"),
                                            content: const Text(
                                              "Devam edersen iş 'Onay bekliyor' durumuna geçer. "
                                              "Yük sahibi onaylayınca iş tamamlanır.",
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, false),
                                                child: const Text("Vazgeç"),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(
                                                    context, true),
                                                child:
                                                    const Text("Teslim Ettim"),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (ok != true) return;

                                        try {
                                          await _markDelivered(loadId: j.id);
                                          if (!context.mounted) return;
                                          // ignore: use_build_context_synchronously
ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    "Teslim bildirimi gönderildi ✅")),
                                          );
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          // ignore: use_build_context_synchronously
ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(content: Text("Hata: $e")),
                                          );
                                        }
                                      }
                                    : null,
                                child: Text(
                                    isPending ? "Onay bekliyor" : "İşi Bitir"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("İşi iptal et?"),
                                      content: const Text(
                                          "İptal edersen iş tekrar açık ilana döner ve teklifler silinir."),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text("Vazgeç"),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text("İptal Et"),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok != true) return;

                                  try {
                                    await _cancelJob(loadId: j.id);
                                    if (!context.mounted) return;
                                    // ignore: use_build_context_synchronously
ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text("İş iptal edildi ✅")),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    // ignore: use_build_context_synchronously
ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text("İptal hatası: $e")),
                                    );
                                  }
                                },
                                child: const Text("İptal"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _openGoogleMaps(BuildContext context, Load j) async {
    final lat = j.fromLat;
    final lng = j.fromLng;

    if (lat == null || lng == null) {
      // ignore: use_build_context_synchronously
ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Bu işin konumu yok (fromLat/fromLng boş).")),
      );
      return;
    }

    final uri = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving",
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      // ignore: use_build_context_synchronously
ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Google Maps açılamadı.")),
      );
    }
  }

  // ✅ Şoför teslim etti bildirimi (iş: onay bekliyor)
  Future<void> _markDelivered({required String loadId}) async {
    final db = Supabase.instance.client;
    final uid = db.auth.currentUser?.id;
    if (uid == null) throw Exception("Oturum yok");

    final data = await db.from("loads").select().eq("id", loadId).maybeSingle();
    if (data == null) throw Exception("İlan bulunamadı");

    if ((data["acceptedDriverId"] ?? "") != uid) {
      throw Exception("Bu işi bitirme yetkin yok");
    }

    final status = (data["status"] ?? "").toString();
    if (status == "done") return;

    await db.from("loads").update({
      "status": "delivered_pending",
      "deliveredAt": DateTime.now().toUtc().toIso8601String(),
      "deliveredByDriverId": uid,
    }).eq("id", loadId);
  }

  Future<void> _cancelJob({required String loadId}) async {
    final db = Supabase.instance.client;
    final uid = db.auth.currentUser?.id;
    if (uid == null) throw Exception("Oturum yok");

    final data = await db.from("loads").select().eq("id", loadId).maybeSingle();
    if (data == null) throw Exception("İlan bulunamadı");

    if ((data["acceptedDriverId"] ?? "") != uid) {
      throw Exception("Bu işi iptal etme yetkin yok");
    }

    // ✅ 1) İşi tekrar open yap
    await db.from("loads").update({
      "status": "open",
      "acceptedOfferId": null,
      "acceptedDriverId": null,
    }).eq("id", loadId);

    // ✅ 2) O işe ait tüm teklifleri SİL (sıfırdan teklif verilebilsin)
    await db.from("offers").delete().eq("loadId", loadId);
  }
}
