import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/load.dart';
import 'ecmr_signature_screen.dart'; // 🟢 İMZA EKRANI EKLENDİ

class ActiveJobsBottomBar extends StatelessWidget {
  final List<Load> jobs;

  final void Function(String jobId) onOpenOnMap;
  final Future<void> Function({required String loadId}) onMarkDelivered;
  final Future<void> Function({required String loadId}) onCancelJob;

  const ActiveJobsBottomBar({
    super.key,
    required this.jobs,
    required this.onOpenOnMap,
    required this.onMarkDelivered,
    required this.onCancelJob,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, -6),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
        border: Border(
          top: BorderSide(color: cs.outlineVariant),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: jobs.isEmpty
            ? const _EmptyBar(key: ValueKey("empty"))
            : _JobBarCard(
          key: ValueKey("job_${jobs.first.id}"),
          job: jobs.first,
          totalCount: jobs.length,
          onOpenOnMap: onOpenOnMap,
          onMarkDelivered: onMarkDelivered,
          onCancelJob: onCancelJob,
        ),
      ),
    );
  }
}

class _EmptyBar extends StatelessWidget {
  const _EmptyBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.work_outline, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Aktif iş yok",
              style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobBarCard extends StatelessWidget {
  final Load job;
  final int totalCount;

  final void Function(String jobId) onOpenOnMap;
  final Future<void> Function({required String loadId}) onMarkDelivered;
  final Future<void> Function({required String loadId}) onCancelJob;

  const _JobBarCard({
    super.key,
    required this.job,
    required this.totalCount,
    required this.onOpenOnMap,
    required this.onMarkDelivered,
    required this.onCancelJob,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPending = job.status == "delivered_pending";

    Color chipColor() => isPending ? Colors.orange : Colors.green;
    IconData chipIcon() => isPending ? Icons.hourglass_bottom : Icons.check_circle_outline;
    String chipText() => isPending ? "Onay bekliyor" : "Aktif";

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Üst satır: rota + chip + (sayı)
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: cs.surfaceContainerHighest,
                ),
                child: Icon(Icons.work_outline, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "${job.fromCity} → ${job.toCity}",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),

              if (totalCount > 1)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    "$totalCount",
                    style: TextStyle(fontWeight: FontWeight.w900, color: cs.primary),
                  ),
                ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: chipColor()),
                  color: chipColor().withOpacity(0.12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(chipIcon(), size: 16, color: chipColor()),
                    const SizedBox(width: 6),
                    Text(
                      chipText(),
                      style: TextStyle(fontWeight: FontWeight.w800, color: chipColor()),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "${job.weightKg} kg • ${job.priceType == 'fixed' ? '${job.fixedPrice} ₺' : 'Teklif'}",
              style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          ),

          const SizedBox(height: 10),

          // Butonlar
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openGoogleMaps(context, job),
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
                        title: const Text("Teslim edildi mi?"),
                        content: const Text(
                          "Devam edersen iş 'Onay bekliyor' durumuna geçer. "
                              "Yük sahibi onaylayınca iş tamamlanır.",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Vazgeç"),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Teslim Ettim"),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;

                    try {
                      await onMarkDelivered(loadId: job.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Teslim bildirimi gönderildi ✅")),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Hata: $e")),
                      );
                    }
                  }
                      : null,
                  child: Text(isPending ? "Onay bekliyor" : "İşi Bitir"),
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
                        content: const Text("İptal edersen iş tekrar açık ilana döner."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Vazgeç"),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("İptal Et"),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;

                    try {
                      await onCancelJob(loadId: job.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("İş iptal edildi ✅")),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("İptal hatası: $e")),
                      );
                    }
                  },
                  child: const Text("İptal"),
                ),
              ),
            ],
          ),

          // _JobBarCard widget'ı içindeki buton bölümünü bununla değiştirin:

          const SizedBox(height: 10),

          // 🟢 AKILLI İMZA BUTONU (Şoför İçin)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection("loads").doc(job.id).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

              final bool driverSigned = data["ecmrSignedBy_driver"] == true;
              final bool shipperSigned = data["ecmrSignedBy_shipper"] == true;
              final String? pdfUrl = data["ecmrUrl_driver"] ?? data["ecmrUrl_shipper"];

              // DURUM 1: Şoför henüz imzalamadı
              if (!driverSigned) {
                return SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.blue.shade800, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EcmrSignatureScreen(loadId: job.id, role: "driver"))),
                    icon: const Icon(Icons.draw, color: Colors.white),
                    label: const Text("Sözleşmeyi İmzala", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                );
              }
              // DURUM 2: Şoför imzaladı ama yük sahibini bekliyor
              else if (!shipperSigned) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.hourglass_empty, size: 18, color: Colors.grey), SizedBox(width: 8), Text("Yük Sahibinin İmzası Bekleniyor", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))]),
                );
              }
              // DURUM 3: Tamamlandı
              else {
                return SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () => pdfUrl != null ? launchUrl(Uri.parse(pdfUrl), mode: LaunchMode.externalApplication) : null,
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    label: const Text("Sözleşmeyi İndir (PDF)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 6),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => onOpenOnMap(job.id),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text("Haritada gör"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGoogleMaps(BuildContext context, Load j) async {
    final lat = j.fromLat;
    final lng = j.fromLng;

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bu işin konumu yok (fromLat/fromLng boş).")),
      );
      return;
    }

    final uri = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving",
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Google Maps açılamadı.")),
      );
    }
  }
}