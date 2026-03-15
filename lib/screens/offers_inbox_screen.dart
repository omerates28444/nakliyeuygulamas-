import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
                      // 🟢 BURADAKİ CONST KELİMESİ SİLİNDİ
                      MaterialPageRoute(builder: (_) => LoadCreateScreen()),
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
                      // 🟢 BURADAKİ CONST KELİMESİ SİLİNDİ
                      MaterialPageRoute(builder: (_) => LoadCreateScreen()),
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
            // Başlık + Düzenle + Sil
            // Başlık + Düzenle + Sil/İptal
            Row(
              children: [
                Expanded(
                  child: Text(
                    "${load.fromCity} → ${load.toCity}",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),

                // 🟢 İLAN SADECE "OPEN" (AÇIK) DURUMDAYSA DÜZENLEME İKONU ÇIKSIN
                if (load.status == "open")
                  IconButton(
                    tooltip: "İlanı Düzenle",
                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LoadEditScreen(load: load)),
                      );
                    },
                  ),

                // 🟢 İLAN AÇIKSA "SİL", EŞLEŞTİYSE "İPTAL ET" BUTONU ÇIKSIN
                if (load.status == "open")
                  IconButton(
                    tooltip: "İlanı Sil",
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("İlan Silinsin mi?"),
                          content: const Text("Bu ilan ve tüm teklifler kalıcı olarak silinecek."),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İlan silindi ✅")));
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Silme hatası: $e")));
                        }
                      }
                    },
                  )
                else if (load.status == "matched")
                  IconButton(
                    tooltip: "İşi İptal Et",
                    icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("İşi İptal Et?"),
                          content: const Text("Şoförle olan anlaşmayı iptal etmek istediğinize emin misiniz?\n\nİlanınız tekrar 'Açık' duruma dönecek ve mevcut teklifler sıfırlanacaktır."),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("İptal Et"),
                            ),
                          ],
                        ),
                      );

                      if (ok == true) {
                        try {
                          // 1. İlanı tekrar 'open' yap ve şoförü çıkar
                          await FirebaseFirestore.instance.collection("loads").doc(load.id).update({
                            "status": "open",
                            "acceptedOfferId": FieldValue.delete(),
                            "acceptedDriverId": FieldValue.delete(),
                          });

                          // 2. Eski teklifleri temizle ki baştan temiz teklif alabilsin
                          final offers = await FirebaseFirestore.instance.collection("offers").where("loadId", isEqualTo: load.id).get();
                          final batch = FirebaseFirestore.instance.batch();
                          for (final d in offers.docs) {
                            batch.delete(d.reference);
                          }
                          await batch.commit();

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İş iptal edildi, ilan tekrar açıldı ✅")));
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("İptal hatası: $e")));
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

                            // 🟢 1. ADIM: İŞİ TAMAMLA VE PARAYI ŞOFÖRE AKTAR (Sinyal gönder)
                            await FirebaseFirestore.instance.collection("loads").doc(load.id).update({
                              "status": "done",
                              "paymentStatus": "transferred_to_driver", // 🟢 YENİ: Ödeme altyapısına giden sinyal
                              "doneAt": FieldValue.serverTimestamp(),
                            });

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Teslim onaylandı ✅ Havuzdaki tutar şoförün IBAN'ına aktarılıyor."),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 4),
                              ),
                            );

                            // 🟢 2. ADIM: SONRA PUANLAMA EKRANINI AÇ (Artık geri basarsa sadece puanlamayı atlamış olur)
                            await _rateUserDialog(
                              context,
                              toUserId: driverId,
                              toRole: "driver",
                              title: "Şoförü Puanla",
                              loadId: load.id,
                              nameHint: "Şoför",
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

                final rawDocs = snap.data!.docs.toList();

                // 🟢 1. Teklifleri tarihe göre sırala (En yeni teklif her zaman ilk sırada olsun)
                rawDocs.sort((a, b) {
                  final ta = (a.data()["createdAt"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                  final tb = (b.data()["createdAt"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                  return tb.compareTo(ta);
                });

                final allOffers = rawDocs.map((d) => Offer.fromDoc(d)).toList();

                // 🟢 2. Sadece EN GÜNCEL teklifleri tut (Aynı şoförün eski tekliflerini gizle)
                final Map<String, Offer> latestOffers = {};
                for (final o in allOffers) {
                  if (!latestOffers.containsKey(o.driverId)) {
                    latestOffers[o.driverId] = o;
                  }
                }

                // Ekranda gösterilecek temizlenmiş liste
                final offers = latestOffers.values.toList();

                if (offers.isEmpty) return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Henüz teklif yok."),
                );

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
                              // 🟢 ŞOFÖRÜN ADINA TIKLAYINCA AÇIK PROFİLİNE (YORUMLARA) GİTME
                              Row(
                                children: [
                                  // 1. Tıklanabilir Profil Avatarı
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: o.driverId)),
                                      );
                                    },
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: cs.surfaceContainerHighest,
                                      child: Icon(Icons.person_outline, color: cs.onSurfaceVariant),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // 2. Tıklanabilir Şoför Adı ve Fiyat
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: o.driverId)),
                                        );
                                      },
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            o.driverName.isEmpty ? "Şoför" : o.driverName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: cs.primary,
                                              decoration: TextDecoration.underline,
                                              decorationColor: cs.primary,
                                            ),
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
                                  ),

                                  // 3. Durum Etiketi (Beklemede vb.)
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
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: statusColor(o.status),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // 4. Sohbet İkonu
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
                                ],
                              ), // ROW KAPANIŞI

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
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),

                              if (!acceptedAlready && (o.status == "sent" || o.status == "countered" || o.status == "driver_rejected_counter"))
                                Row(
                                  children: [
                                    IconButton.filled(
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.red.withOpacity(0.1),
                                      ),
                                      tooltip: "Reddet",
                                      onPressed: () async {
                                        await FirebaseFirestore.instance.collection("offers").doc(o.id).update({
                                          "status": "rejected",
                                          "rejectedAt": FieldValue.serverTimestamp(),
                                        });
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Teklif reddedildi")));
                                      },
                                      icon: const Icon(Icons.close, color: Colors.red),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.orange.withOpacity(0.1),
                                          foregroundColor: Colors.orange.shade900,
                                        ),
                                        onPressed: () async {
                                          final res = await _counterDialog(context, initial: o.counterPrice?.toString() ?? "");
                                          if (res == null) return;
                                          try {
                                            await _sendCounterOffer(offerId: o.id, counterPrice: res, counterNote: "");
                                          } catch (e) {
                                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
                                          }
                                        },
                                        icon: const Icon(Icons.handshake_outlined, size: 18),
                                        label: const Text("Pazarlık Yap", style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                        onPressed: () {
                                          // 🟢 Yük sahibi ödemeyi yapmak için PaymentScreen'e yönlendirilir
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => PaymentScreen(
                                                loadId: load.id,
                                                offerId: o.id,
                                                driverId: o.driverId,
                                                shipperId: load.shipperId ?? "",
                                                offerPrice: o.counterPrice ?? o.price,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text("Kabul Et", style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
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

  Future<int?> _counterDialog(BuildContext context, {String initial = ""}) async {
    final priceCtrl = TextEditingController(text: initial);

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
              decoration: const InputDecoration(labelText: "Karşı Teklif (₺)", prefixIcon: Icon(Icons.local_offer_outlined)),
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

    return p;
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

    String realShipperId = shipperId.trim();
    if (realShipperId.isEmpty) {
      final loadSnap = await db.collection("loads").doc(loadId).get();
      final s = loadSnap.data()?["shipperId"];
      if (s is String && s.trim().isNotEmpty) {
        realShipperId = s.trim();
      }
    }

    if (realShipperId.isEmpty) {
      throw Exception("shipperId bulunamadı.");
    }

    final chatSvc = ChatService();
    final loadRef = db.collection("loads").doc(loadId);
    final offerRef = db.collection("offers").doc(offerId);

    final chatId = chatSvc.getChatId(loadId: loadId, driverId: driverId);
    final chatRef = db.collection("chats").doc(chatId);

    final othersSnap = await db.collection("offers").where("loadId", isEqualTo: loadId).get();

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