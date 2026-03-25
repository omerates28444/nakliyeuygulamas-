import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../models/load.dart';
import '../models/offer.dart';
import '../app_state.dart';
import 'load_create_screen.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';
import 'load_edit_screen.dart';
import 'public_profile_screen.dart';
import 'payment_screen.dart';
import 'ecmr_signature_screen.dart';

class OffersInboxScreen extends StatelessWidget {
  final ScrollController? controller;

  const OffersInboxScreen({super.key, this.controller});

  // Kurumsal Renkler
  final Color logimapNavy = const Color(0xFF081226);
  final Color logimapBlue = const Color(0xFF1976D2);

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text("Oturum yok. Tekrar giriş yap.", style: TextStyle(fontWeight: FontWeight.bold)));
    }

    if (appState.role != "shipper") {
      return const Center(child: Text("Bu ekran Yük Sahibi içindir.", style: TextStyle(fontWeight: FontWeight.bold)));
    }

    final loadsQuery = FirebaseFirestore.instance
        .collection("loads")
        .where("shipperId", isEqualTo: uid)
        .where("status", whereIn: ["open", "matched", "delivered_pending"])
        .orderBy("createdAt", descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: loadsQuery.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Veriler şu an yüklenemiyor. Eğer bu ilk kez oluyorsa Firebase Index gerekebilir.\nBirazdan tekrar dene.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final loads = snap.data!.docs.map((d) => Load.fromDoc(d)).toList();

        // BOŞ DURUM (Ferah Tasarım)
        if (loads.isEmpty) {
          return ListView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text("Henüz aktif bir ilanınız yok.", style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: logimapBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text("Yeni İlan Ver", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoadCreateScreen())),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("İlanlar & Teklifler", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF081226))),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: logimapBlue.withOpacity(0.1),
                    foregroundColor: logimapBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text("İlan Ver", style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoadCreateScreen())),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...loads.map((l) => _LoadOffersCard(load: l)),
          ],
        );
      },
    );
  }
}

class _LoadOffersCard extends StatelessWidget {
  final Load load;
  const _LoadOffersCard({required this.load});

  final Color logimapNavy = const Color(0xFF081226);
  final Color logimapBlue = const Color(0xFF1976D2);

  @override
  Widget build(BuildContext context) {
    final offersQuery = FirebaseFirestore.instance.collection("offers").where("loadId", isEqualTo: load.id);
    final acceptedAlready = (load.acceptedOfferId != null);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🟢 KART BAŞLIĞI VE GİZLİ MENÜ
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: logimapBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.outbox_outlined, color: logimapBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${load.fromCity} → ${load.toCity}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: logimapNavy), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text("${load.weightKg} kg • ${load.priceType == 'fixed' ? '${load.fixedPrice} ₺ (Sabit)' : 'Teklif usulü'}", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),

                // 🟢 ZARİF ÜÇ NOKTA MENÜSÜ (Eski kaba ikonlar yerine)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => LoadEditScreen(load: load)));
                    } else if (value == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("İlan Silinsin mi?"),
                          content: const Text("Bu ilan ve tüm teklifler kalıcı olarak silinecek."),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
                            FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text("Sil")),
                          ],
                        ),
                      );
                      if (ok == true) {
                        try {
                          await _deleteLoadWithOffers(loadId: load.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İlan silindi ✅")));
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Silme hatası: $e")));
                        }
                      }
                    } else if (value == 'cancel') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("İşi İptal Et?"),
                          content: const Text("Şoförle olan anlaşmayı iptal etmek istediğinize emin misiniz?\n\nİlanınız tekrar 'Açık' duruma dönecek ve mevcut teklifler sıfırlanacaktır."),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
                            FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text("İptal Et")),
                          ],
                        ),
                      );
                      if (ok == true) {
                        try {
                          await FirebaseFirestore.instance.collection("loads").doc(load.id).update({"status": "open", "acceptedOfferId": FieldValue.delete(), "acceptedDriverId": FieldValue.delete()});
                          final offers = await FirebaseFirestore.instance.collection("offers").where("loadId", isEqualTo: load.id).get();
                          final batch = FirebaseFirestore.instance.batch();
                          for (final d in offers.docs) { batch.delete(d.reference); }
                          await batch.commit();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İş iptal edildi, ilan tekrar açıldı ✅")));
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("İptal hatası: $e")));
                        }
                      }
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    if (load.status == "open") ...[
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, color: Colors.blue, size: 20), SizedBox(width: 8), Text("Düzenle", style: TextStyle(fontWeight: FontWeight.w600))])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 20), SizedBox(width: 8), Text("İlanı Sil", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600))])),
                    ],
                    if (load.status == "matched")
                      const PopupMenuItem(value: 'cancel', child: Row(children: [Icon(Icons.cancel_outlined, color: Colors.red, size: 20), SizedBox(width: 8), Text("İşi İptal Et", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600))])),
                  ],
                ),
              ],
            ),
          ),

          // 🟢 DİJİTAL İRSALİYE (e-CMR) BÖLÜMÜ
          if (load.status == "matched" || load.status == "delivered_pending") ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection("loads").doc(load.id).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

                  final bool driverSigned = data["ecmrSignedBy_driver"] == true;
                  final bool shipperSigned = data["ecmrSignedBy_shipper"] == true;
                  final String? pdfUrl = data["ecmrUrl_shipper"] ?? data["ecmrUrl_driver"];

                  if (!shipperSigned) {
                    return SizedBox(
                      width: double.infinity, height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: logimapNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EcmrSignatureScreen(loadId: load.id, role: "shipper"))),
                        icon: const Icon(Icons.draw, color: Colors.white, size: 20),
                        label: const Text("Sözleşmeyi İmzala", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    );
                  } else if (!driverSigned) {
                    return Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade300)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.hourglass_empty, size: 18, color: Colors.grey.shade600), const SizedBox(width: 8), Text("Şoförün İmzası Bekleniyor", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold))]),
                    );
                  } else {
                    return SizedBox(
                      width: double.infinity, height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: () => pdfUrl != null ? launchUrl(Uri.parse(pdfUrl), mode: LaunchMode.externalApplication) : null,
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
                        label: const Text("Sözleşmeyi İndir (PDF)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    );
                  }
                },
              ),
            ),
          ],

          // 🟢 TESLİMAT ONAY BÖLÜMÜ
          if (load.status == "delivered_pending")
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, color: Colors.orange.shade800, size: 20),
                        const SizedBox(width: 8),
                        Text("Şoför teslimatı bildirdi", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.orange.shade900, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (load.deliveryPhotoUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          load.deliveryPhotoUrl!,
                          height: 160, width: double.infinity, fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(height: 160, color: Colors.orange.shade100, child: const Center(child: CircularProgressIndicator()));
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity, height: 46,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        icon: const Icon(Icons.verified),
                        label: const Text("Teslimatı Onayla", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Teslimi onayla?"),
                              content: const Text("Onaylarsan iş tamamlanır ve şoföre puan verebilirsin."),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
                                FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700), onPressed: () => Navigator.pop(context, true), child: const Text("Onayla")),
                              ],
                            ),
                          );
                          if (ok != true) return;

                          try {
                            final loadSnap = await FirebaseFirestore.instance.collection("loads").doc(load.id).get();
                            final data = loadSnap.data() ?? {};
                            final driverId = (data["acceptedDriverId"] ?? "").toString();

                            if (driverId.isEmpty) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şoför bilgisi bulunamadı.")));
                              return;
                            }

                            await FirebaseFirestore.instance.collection("loads").doc(load.id).update({
                              "status": "done",
                              "paymentStatus": "transferred_to_driver",
                              "doneAt": FieldValue.serverTimestamp(),
                            });

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Teslim onaylandı ✅ Havuzdaki tutar aktarılıyor."), backgroundColor: Colors.green));

                            await _rateUserDialog(context, toUserId: driverId, toRole: "driver", title: "Şoförü Puanla", loadId: load.id, nameHint: "Şoför");
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 24)),

          // 🟢 TEKLİFLER BÖLÜMÜ
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: offersQuery.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return Text("Teklif hata: ${snap.error}");
                if (!snap.hasData) return const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator()));

                final rawDocs = snap.data!.docs.toList();
                rawDocs.sort((a, b) {
                  final ta = (a.data()["createdAt"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                  final tb = (b.data()["createdAt"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                  return tb.compareTo(ta);
                });

                final allOffers = rawDocs.map((d) => Offer.fromDoc(d)).toList();
                final Map<String, Offer> latestOffers = {};
                for (final o in allOffers) {
                  if (!latestOffers.containsKey(o.driverId)) latestOffers[o.driverId] = o;
                }

                final offers = latestOffers.values.toList();

                if (offers.isEmpty) return const Text("Henüz teklif yok.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600));

                return Column(
                  children: offers.map((o) {
                    Color statusColor(String s) {
                      switch (s) {
                        case "accepted": return Colors.green.shade700;
                        case "rejected": return Colors.red.shade600;
                        case "countered": return Colors.orange.shade800;
                        default: return Colors.blueGrey;
                      }
                    }

                    IconData statusIcon(String s) {
                      switch (s) {
                        case "accepted": return Icons.check_circle_outline;
                        case "rejected": return Icons.cancel_outlined;
                        case "countered": return Icons.handshake_outlined;
                        default: return Icons.hourglass_bottom;
                      }
                    }

                    String statusLabel(String s) {
                      switch (s) {
                        case "accepted": return "Kabul edildi";
                        case "rejected": return "Reddedildi";
                        case "driver_rejected_counter": return "Şoför Reddetti";
                        case "countered": return "Karşı teklif";
                        default: return "Beklemede";
                      }
                    }

                    final isFixed = load.priceType == "fixed";
                    final canAct = (!isFixed && !acceptedAlready && (o.status == "sent" || o.status == "countered" || o.status == "driver_rejected_counter"));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sürücü Bilgisi
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: o.driverId))),
                                  child: CircleAvatar(radius: 20, backgroundColor: logimapBlue.withOpacity(0.1), child: Icon(Icons.person, color: logimapBlue)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: o.driverId))),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(o.driverName.isEmpty ? "Şoför" : o.driverName, style: TextStyle(fontWeight: FontWeight.w900, color: logimapNavy, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 2),
                                        Text("${o.price} ₺", style: TextStyle(fontWeight: FontWeight.w900, color: logimapBlue, fontSize: 16)),
                                      ],
                                    ),
                                  ),
                                ),
                                // Durum Rozeti
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: statusColor(o.status).withOpacity(0.1)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(statusIcon(o.status), size: 14, color: statusColor(o.status)),
                                      const SizedBox(width: 4),
                                      Text(statusLabel(o.status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor(o.status))),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Sohbet İkonu
                                Container(
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.shade50),
                                  child: IconButton(
                                    tooltip: "Şoförle Mesajlaş",
                                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue, size: 20),
                                    onPressed: () async {
                                      final shipperId = load.shipperId ?? "";
                                      if (shipperId.isEmpty) return;
                                      final chatSvc = ChatService();
                                      final chatId = chatSvc.getChatId(loadId: load.id, driverId: o.driverId);
                                      await chatSvc.ensureChat(loadId: load.id, shipperId: shipperId, driverId: o.driverId);
                                      if (!context.mounted) return;
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)));
                                    },
                                  ),
                                ),
                              ],
                            ),

                            if (o.counterPrice != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity, padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200), color: Colors.orange.shade50),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Senin Karşı Teklifin:", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87)),
                                    Text("${o.counterPrice} ₺", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.orange.shade900, fontSize: 15)),
                                  ],
                                ),
                              ),
                            ],

                            // 🟢 AKSİYON BUTONLARI (Zarif ve Kompakt)
                            if (canAct) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // Reddet
                                  IconButton.filled(
                                    style: IconButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                    tooltip: "Reddet",
                                    onPressed: () async {
                                      await FirebaseFirestore.instance.collection("offers").doc(o.id).update({"status": "rejected", "rejectedAt": FieldValue.serverTimestamp()});
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Teklif reddedildi")));
                                    },
                                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                  ),
                                  const SizedBox(width: 8),
                                  // Pazarlık
                                  Expanded(
                                    child: FilledButton.tonalIcon(
                                      style: FilledButton.styleFrom(backgroundColor: Colors.orange.withOpacity(0.1), foregroundColor: Colors.orange.shade900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                      onPressed: () async {
                                        final res = await _counterDialog(context, initial: o.counterPrice?.toString() ?? "");
                                        if (res == null) return;
                                        try { await _sendCounterOffer(offerId: o.id, counterPrice: res, counterNote: ""); }
                                        catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"))); }
                                      },
                                      icon: const Icon(Icons.handshake_outlined, size: 18),
                                      label: const Text("Pazarlık", style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Kabul Et
                                  Expanded(
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(
                                            builder: (_) => PaymentScreen(loadId: load.id, offerId: o.id, driverId: o.driverId, shipperId: load.shipperId ?? "", offerPrice: o.counterPrice ?? o.price)
                                        ));
                                      },
                                      icon: const Icon(Icons.check, size: 18),
                                      label: const Text("Kabul Et", style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Yardımcı Fonksiyonlar (Aynı Bırakıldı) ---

  Future<int?> _counterDialog(BuildContext context, {String initial = ""}) async {
    final priceCtrl = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("Karşı Teklif", style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Karşı Teklif (₺)", prefixIcon: const Icon(Icons.local_offer_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: logimapNavy), onPressed: () => Navigator.pop(context, true), child: const Text("Gönder")),
        ],
      ),
    );
    if (ok != true) return null;
    final p = int.tryParse(priceCtrl.text.trim());
    if (p == null || p <= 0) return null;
    return p;
  }

  Future<void> _sendCounterOffer({required String offerId, required int counterPrice, required String counterNote}) async {
    await FirebaseFirestore.instance.collection("offers").doc(offerId).update({
      "counterPrice": counterPrice,
      "counterNote": counterNote,
      "status": "countered",
      "counterAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteLoadWithOffers({required String loadId}) async {
    final db = FirebaseFirestore.instance;
    final offersSnap = await db.collection("offers").where("loadId", isEqualTo: loadId).get();
    final batch = db.batch();
    for (final d in offersSnap.docs) { batch.delete(d.reference); }
    batch.delete(db.collection("loads").doc(loadId));
    await batch.commit();
  }

  Future<void> _rateUserDialog(BuildContext context, {required String toUserId, required String toRole, required String title, required String loadId, String nameHint = ""}) async {
    int stars = 5;
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (nameHint.trim().isNotEmpty) Text(nameHint, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final val = i + 1;
                      final on = val <= stars;
                      return IconButton(
                        onPressed: () => setState(() => stars = val),
                        icon: Icon(on ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 36),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: noteCtrl, decoration: InputDecoration(labelText: "Not (opsiyonel)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text("Atla")),
                FilledButton(style: FilledButton.styleFrom(backgroundColor: logimapBlue), onPressed: () => Navigator.pop(dialogContext, true), child: const Text("Kaydet")),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;
    final fromUid = AuthService().currentUser?.uid;
    if (fromUid == null) return;
    final db = FirebaseFirestore.instance;

    await db.collection("ratings").add({
      "loadId": loadId, "fromUserId": fromUid, "toUserId": toUserId, "toRole": toRole,
      "stars": stars, "note": noteCtrl.text.trim(), "createdAt": FieldValue.serverTimestamp(),
    });

    final userRef = db.collection("users").doc(toUserId);
    await db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final data = snap.data() ?? {};
      final prevAvg = (data["ratingAvg"] is num) ? (data["ratingAvg"] as num).toDouble() : 0.0;
      final prevCount = (data["ratingCount"] is int) ? data["ratingCount"] as int : 0;
      final newCount = prevCount + 1;
      final newAvg = ((prevAvg * prevCount) + stars) / newCount;
      tx.set(userRef, {"ratingAvg": newAvg, "ratingCount": newCount, "updatedAt": FieldValue.serverTimestamp()}, SetOptions(merge: true));
    });
  }
}