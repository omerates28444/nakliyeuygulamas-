import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../models/load.dart';
import '../models/offer.dart';
import '../app_state.dart';
import 'load_create_screen.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class OffersInboxScreen extends StatelessWidget {
  final ScrollController? controller;

  const OffersInboxScreen({super.key, this.controller});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text("Oturum yok. Tekrar giriş yap."));
    }

    if (appState.role != "shipper") {
      return const Center(child: Text("Bu ekran Yük Sahibi içindir."));
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
                "Veriler şu an yüklenemiyor. Eğer bu ilk kez oluyorsa Firebase Index gerekebilir.\n"
                    "Birazdan tekrar dene.",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final loads = snap.data!.docs.map((d) => Load.fromDoc(d)).toList();

        // ✅ BOŞKEN DE ListView DÖNDÜR (sheet + scroll controller düzgün çalışsın)
        if (loads.isEmpty) {
          return ListView(
            controller: controller,
            padding: const EdgeInsets.all(16),
            children: [
              const Text("Henüz ilanın yok. İlan vererek başla."),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("İlan Ver"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoadCreateScreen()),
                    );
                  },
                ),
              ),
            ],
          );
        }

        return ListView(
          controller: controller,
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "İlanların & Teklifler",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("İlan Ver"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoadCreateScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
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

  @override
  Widget build(BuildContext context) {
    final offersQuery =
    FirebaseFirestore.instance.collection("offers").where("loadId", isEqualTo: load.id);

    final acceptedAlready = (load.acceptedOfferId != null);
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık + Sil
            Row(
              children: [
                Expanded(
                  child: Text(
                    "${load.fromCity} → ${load.toCity}",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                IconButton(
                  tooltip: "İlanı Sil",
                  icon: const Icon(Icons.delete_outline),
                  onPressed: (load.status == "matched" || load.status == "delivered_pending")
                      ? null
                      : () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("İlan Silinsin mi?"),
                        content: const Text("Bu ilan ve tüm teklifler kalıcı olarak silinecek."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Vazgeç"),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Sil"),
                          ),
                        ],
                      ),
                    );

                    if (ok == true) {
                      try {
                        await _deleteLoadWithOffers(loadId: load.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("İlan silindi ✅")),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Silme hatası: $e")),
                        );
                      }
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 4),

            Text(
              "${load.weightKg} kg • ${load.priceType == 'fixed' ? '${load.fixedPrice} ₺ (Sabit)' : 'Teklif usulü'}",
              style: TextStyle(color: cs.onSurfaceVariant),
            ),



            if (load.status == "delivered_pending")
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Durum: Teslim bildirildi ⏳", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    const SizedBox(height: 10),

                    if (load.deliveryPhotoUrl != null) ...[
                      const Text("Teslimat Kanıtı:", style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          load.deliveryPhotoUrl!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.verified),
                        label: const Text("Teslimi Onayla"),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Teslimi onayla?"),
                              content: const Text("Onaylarsan iş tamamlanır ve şoföre puan verebilirsin."),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("Vazgeç"),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Onayla"),
                                ),
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Şoför bilgisi bulunamadı (acceptedDriverId boş).")),
                              );
                              return;
                            }

                            await _rateUserDialog(
                              context,
                              toUserId: driverId,
                              toRole: "driver",
                              title: "Şoförü Puanla",
                              loadId: load.id,
                              nameHint: "Şoför",
                            );

                            await FirebaseFirestore.instance.collection("loads").doc(load.id).update({
                              "status": "done",
                              "doneAt": FieldValue.serverTimestamp(),
                            });

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Teslim onaylandı ✅ İş tamamlandı.")),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Hata: $e")),
                            );
                          }
                        },
                      ),
                    ), // SizedBox kapanışı
                  ], // Column children kapanışı
                ), // Column kapanışı
              ), // Padding kapanışı

            const SizedBox(height: 10),
            const Divider(),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: offersQuery.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return Text("Teklif hata: ${snap.error}");
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  );
                }

                final offers = snap.data!.docs.map((d) => Offer.fromDoc(d)).toList();
                if (offers.isEmpty) return const Text("Henüz teklif yok.");

                return Column(
                  children: offers.map((o) {
                    Color statusColor(String s) {
                      switch (s) {
                        case "accepted":
                          return Colors.green;
                        case "rejected":
                          return Colors.red;
                        case "countered":
                          return Colors.orange;
                        default:
                          return cs.onSurfaceVariant;
                      }
                    }

                    IconData statusIcon(String s) {
                      switch (s) {
                        case "accepted":
                          return Icons.check_circle_outline;
                        case "rejected":
                          return Icons.cancel_outlined;
                        case "countered":
                          return Icons.forum_outlined;
                        default:
                          return Icons.hourglass_bottom;
                      }
                    }

                    String statusLabel(String s) {
                      switch (s) {
                        case "accepted":
                          return "Kabul edildi";
                        case "rejected":
                          return "Reddedildi";
                        case "driver_rejected_counter":
                          return "Şoför Reddetti"; // 🟢 DAHA KISA VE ŞIK
                        case "countered":
                          return "Karşı teklif";
                        default:
                          return "Beklemede";

                      }
                    }

                    final isFixed = load.priceType == "fixed";

                    // ✅ sabitte "Karşı Teklif" kapalı (istersen kaldırma, böyle daha doğru)
                    // 🟢 YENİ HALİ: Şoför reddetse bile yük sahibi tekrar aksiyon alabilir!
                    final canAct = (!isFixed && !acceptedAlready && (o.status == "sent" || o.status == "countered" || o.status == "driver_rejected_counter"));
                    final canAccept = (!acceptedAlready && (o.status == "sent" || o.status == "countered" || o.status == "driver_rejected_counter"));

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
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: cs.surfaceContainerHighest,
                                    child: Icon(Icons.person_outline, color: cs.onSurfaceVariant),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          o.driverName.isEmpty ? "Şoför" : o.driverName,
                                          style: const TextStyle(fontWeight: FontWeight.w900),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "${o.price} ₺",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: cs.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 🟢 FLEXIBLE EKLENDİ VE METİN TAŞMASI ENGELLENDİ
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: statusColor(o.status)),
                                        color: statusColor(o.status).withOpacity(0.12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(statusIcon(o.status), size: 14, color: statusColor(o.status)),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              statusLabel(o.status),
                                              overflow: TextOverflow.ellipsis, // 🟢 ÇOK UZUNSA NOKTA NOKTA YAPAR (...)
                                              style: TextStyle(
                                                fontSize: 12, // 🟢 YER KAPLAMAMASI İÇİN BİRAZ KÜÇÜLTÜLDÜ
                                                fontWeight: FontWeight.w800,
                                                color: statusColor(o.status),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
// YENİ EKLENEN SOHBET İKONU
                                  IconButton(
                                    tooltip: "Şoförle Mesajlaş",
                                    icon: const Icon(Icons.chat, color: Colors.blue),
                                    onPressed: () async {
                                      final shipperId = load.shipperId ?? "";
                                      if (shipperId.isEmpty) return;

                                      final chatSvc = ChatService();
                                      final chatId = chatSvc.getChatId(loadId: load.id, driverId: o.driverId);

                                      await chatSvc.ensureChat(loadId: load.id, shipperId: shipperId, driverId: o.driverId);

                                      if (!context.mounted) return;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 6),

                                  // ✅ BURASI DOĞRU YER
                                  PopupMenuButton<String>(
                                    tooltip: "İşlemler",
                                    onSelected: (v) async {
                                      if (v == "reject") {
                                        await FirebaseFirestore.instance.collection("offers").doc(o.id).update({
                                          "status": "rejected",
                                          "rejectedAt": FieldValue.serverTimestamp(),
                                        });
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Teklif reddedildi ✅")),
                                        );
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: "reject",
                                        enabled: (!acceptedAlready && (o.status == "sent" || o.status == "countered")),
                                        child: const Text("Reddet"),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              if (o.note.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: cs.surfaceContainerHighest,
                                    border: Border.all(color: cs.outlineVariant),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.notes_outlined, size: 18, color: cs.onSurfaceVariant),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          o.note.trim(),
                                          style: Theme.of(context).textTheme.bodySmall,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              if (o.counterPrice != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange),
                                    color: Colors.orange.withOpacity(0.10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.local_offer_outlined, size: 18),
                                          SizedBox(width: 6),
                                          Text("Karşı teklif", style: TextStyle(fontWeight: FontWeight.w900)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text("Fiyat: ${o.counterPrice} ₺", style: const TextStyle(fontWeight: FontWeight.w800)),
                                      if ((o.counterNote ?? "").trim().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          "Not: ${o.counterNote}",
                                          style: Theme.of(context).textTheme.bodySmall,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),

                              Column(
                                children: [
                                  // ÜST: KARŞI TEKLİF
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: OutlinedButton.icon(
                                      onPressed: canAct
                                          ? () async {
                                        final res = await _counterDialog(
                                          context,
                                          initial: o.counterPrice?.toString() ?? "",
                                        );
                                        if (res == null) return;

                                        try {
                                          await _sendCounterOffer(
                                            offerId: o.id,
                                            counterPrice: res.$1,
                                            counterNote: res.$2,
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("Karşı teklif gönderildi ✅")),
                                          );
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text("Hata: $e")),
                                          );
                                        }
                                      }
                                          : null,
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text("Karşı Teklif Gönder"),
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // ALT: REDDET + KABUL
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 44,
                                          child: OutlinedButton.icon(
                                            // 🟢 Şoför reddettiği durumda bile teklifi tamamen listeden silebilmek için
                                            onPressed: (!acceptedAlready && (o.status == "sent" || o.status == "countered" || o.status == "driver_rejected_counter"))
                                                ? () async {
                                              final ok = await showDialog<bool>(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  title: const Text("Teklif reddedilsin mi?"),
                                                  content: const Text("Bu teklifi reddedersen şoför tekrar teklif verebilir."),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, false),
                                                      child: const Text("Vazgeç"),
                                                    ),
                                                    FilledButton(
                                                      onPressed: () => Navigator.pop(context, true),
                                                      child: const Text("Reddet"),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (ok != true) return;

                                              await FirebaseFirestore.instance.collection("offers").doc(o.id).update({
                                                "status": "rejected",
                                                "rejectedAt": FieldValue.serverTimestamp(),
                                              });

                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text("Teklif reddedildi ✅")),
                                              );
                                            }
                                                : null,
                                            icon: const Icon(Icons.close),
                                            label: const Text("Reddet"),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: SizedBox(
                                          height: 44,
                                          child: FilledButton.icon(
                                            onPressed: canAccept
                                                ? () async {
                                              await _acceptOffer(
                                                loadId: load.id,
                                                offerId: o.id,
                                                driverId: o.driverId,
                                                shipperId: load.shipperId ?? "",
                                              );

                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text("Teklif kabul edildi ✅")),
                                              );
                                            }
                                                : null,
                                            icon: const Icon(Icons.check),
                                            label: const Text("Kabul Et"),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<(int, String)?> _counterDialog(BuildContext context, {String initial = ""}) async {
    final priceCtrl = TextEditingController(text: initial);
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Karşı Teklif"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Karşı Teklif (₺)"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: "Not (opsiyonel)"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Gönder")),
        ],
      ),
    );

    if (ok != true) return null;

    final p = int.tryParse(priceCtrl.text.trim());
    if (p == null || p <= 0) return null;

    return (p, noteCtrl.text.trim());
  }

  Future<void> _sendCounterOffer({
    required String offerId,
    required int counterPrice,
    required String counterNote,
  }) async {
    await FirebaseFirestore.instance.collection("offers").doc(offerId).update({
      "counterPrice": counterPrice,
      "counterNote": counterNote,
      "status": "countered",
      "counterAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> _acceptOffer({
    required String loadId,
    required String offerId,
    required String driverId,
    required String shipperId,
  }) async {
    final db = FirebaseFirestore.instance;

    // ✅ shipperId boş gelirse loads/{loadId} içinden çek
    String realShipperId = shipperId.trim();
    if (realShipperId.isEmpty) {
      final loadSnap = await db.collection("loads").doc(loadId).get();
      final s = loadSnap.data()?["shipperId"];
      if (s is String && s.trim().isNotEmpty) {
        realShipperId = s.trim();
      }
    }

    if (realShipperId.isEmpty) {
      throw Exception("shipperId bulunamadı. loads/$loadId içinde shipperId olmalı.");
    }

    final chatSvc = ChatService();

    final loadRef = db.collection("loads").doc(loadId);
    final offerRef = db.collection("offers").doc(offerId);

    final othersSnap = await db.collection("offers").where("loadId", isEqualTo: loadId).get();

    // İlan zaten eşleşmişse, şoförün ID'sini load.acceptedDriverId üzerinden alırız
    final driverId = load.acceptedDriverId ?? "";
    final chatId = chatSvc.getChatId(loadId: load.id, driverId: driverId);
    final chatRef = db.collection("chats").doc(chatId);

    final batch = db.batch();

    batch.update(loadRef, {
      "acceptedOfferId": offerId,
      "acceptedDriverId": driverId,
      "status": "matched",
      "chatId": chatId,
    });

    batch.update(offerRef, {"status": "accepted"});

    for (final d in othersSnap.docs) {
      if (d.id == offerId) continue;
      batch.update(d.reference, {"status": "rejected"});
    }

    batch.set(chatRef, {
      "loadId": loadId,
      "shipperId": realShipperId,
      "driverId": driverId,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
      "lastMessage": null,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> _deleteLoadWithOffers({required String loadId}) async {
    final db = FirebaseFirestore.instance;
    final offersSnap = await db.collection("offers").where("loadId", isEqualTo: loadId).get();

    final batch = db.batch();
    for (final d in offersSnap.docs) {
      batch.delete(d.reference);
    }
    batch.delete(db.collection("loads").doc(loadId));

    await batch.commit();
  }

  Future<void> _rateUserDialog(
      BuildContext context, {
        required String toUserId,
        required String toRole,
        required String title,
        required String loadId,
        String nameHint = "",
      }) async {
    int stars = 5;
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (nameHint.trim().isNotEmpty)
                    Text(nameHint, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final val = i + 1;
                      final on = val <= stars;
                      return IconButton(
                        onPressed: () => setState(() => stars = val),
                        icon: Icon(on ? Icons.star : Icons.star_border),
                      );
                    }),
                  ),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: "Not (opsiyonel)"),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text("Atla"),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text("Kaydet"),
                ),
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
      "loadId": loadId,
      "fromUserId": fromUid,
      "toUserId": toUserId,
      "toRole": toRole,
      "stars": stars,
      "note": noteCtrl.text.trim(),
      "createdAt": FieldValue.serverTimestamp(),
    });

    final userRef = db.collection("users").doc(toUserId);

    await db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final data = snap.data() ?? {};

      final prevAvg = (data["ratingAvg"] is num) ? (data["ratingAvg"] as num).toDouble() : 0.0;
      final prevCount = (data["ratingCount"] is int) ? data["ratingCount"] as int : 0;

      final newCount = prevCount + 1;
      final newAvg = ((prevAvg * prevCount) + stars) / newCount;

      tx.set(
        userRef,
        {
          "ratingAvg": newAvg,
          "ratingCount": newCount,
          "updatedAt": FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }
}