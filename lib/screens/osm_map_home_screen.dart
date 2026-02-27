import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../app_state.dart';
import '../models/load.dart';
import '../models/offer.dart';
import '../services/OfferService.dart';
import '../services/chat_service.dart';
import 'offers_inbox_screen.dart';
import '../screens/active_jobs_panel.dart'; // ActiveJobsBottomBar burada
import '../services/load_service.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';

class OsmMapHomeScreen extends StatefulWidget {
  const OsmMapHomeScreen({super.key});

  @override
  State<OsmMapHomeScreen> createState() => OsmMapHomeScreenState();
}

class OsmMapHomeScreenState extends State<OsmMapHomeScreen> {
  final MapController _mapController = MapController();

  Position? _pos;
  bool _locLoading = false;
  bool _cleanupRan = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  /// Panel/iş listesinden haritayı o işe odakla
  void focusJobById(String jobId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection("loads").doc(jobId).get();
      if (!doc.exists) return;
      final l = Load.fromDoc(doc);
      if (l.fromLat == null || l.fromLng == null) return;
      _mapController.move(LatLng(l.fromLat!, l.fromLng!), 14);
    } catch (_) {}
  }

  Future<void> _initLocation() async {
    if (_locLoading) return;
    setState(() => _locLoading = true);

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _snack("Konum servisi kapalı.");
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _snack("Konum izni verilmedi.");
        return;
      }

      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) setState(() => _pos = last);

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) setState(() => _pos = pos);
    } finally {
      if (mounted) setState(() => _locLoading = false);
    }
  }

  void _goToMyLocation() {
    if (_pos == null) {
      _snack("Konum alınamadı.");
      return;
    }
    _mapController.move(LatLng(_pos!.latitude, _pos!.longitude), 12);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<Marker> _buildMarkers(List<Load> loads) {
    final markers = <Marker>[];

    // kullanıcı konumu
    if (_pos != null) {
      markers.add(
        Marker(
          point: LatLng(_pos!.latitude, _pos!.longitude),
          width: 46,
          height: 46,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.20),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      );
    }

    // ✅ sadece OPEN ilanlar marker
    for (final l in loads) {
      if (l.fromLat == null || l.fromLng == null) continue;
      if (l.status != "open") continue;

      final p = LatLng(l.fromLat!, l.fromLng!);
      markers.add(
        Marker(
          point: p,
          width: 54,
          height: 54,
          child: GestureDetector(
            onTap: () => _openJobSheet(l, p),
            child: const Icon(Icons.location_on, size: 44, color: Colors.red),
          ),
        ),
      );
    }

    return markers;
  }

  // ✅ driver karşı teklifi kabul


  // ✅ driver karşı teklifi reddedince: teklif silinsin


  bool _isExpiredForDelete(Load l) {
    final deadline = l.pickupDate.add(const Duration(days: 7));
    return DateTime.now().isAfter(deadline);
  }



  Future<void> _cleanupExpiredLoads(List<Load> loads) async {
    if (appState.role != "shipper") return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final myExpired = loads.where((l) => l.shipperId == uid && _isExpiredForDelete(l)).toList();
    if (myExpired.isEmpty) return;

    for (final l in myExpired) {
      try {
        await OfferService().deleteLoadWithOffers(l.id);
      } catch (_) {}
    }
  }

  // ---------- UI helpers ----------

  Widget _pill({required IconData icon, required String text}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _statusChip(String text, {IconData? icon, bool isOpen = false}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green.withOpacity(0.15) : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: isOpen ? Colors.green : cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: 6),
          ],
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  void _openJobSheet(Load l, LatLng dest) {
    final isDriver = appState.role == "driver";
    final priceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        final priceText = (l.priceType == "fixed" && l.fixedPrice != null)
            ? "${l.fixedPrice} ₺ (Sabit)"
            : "Teklif usulü";

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          "${l.fromCity} → ${l.toCity}",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ),
                      _statusChip(
                        l.status == "open" ? "Açık" : "Eşleşti",
                        icon: Icons.circle,
                        isOpen: l.status == "open",
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _infoRow("Ağırlık", "${l.weightKg} kg"),
                          _infoRow("Ücret", priceText),
                          _infoRow("Teslim Tarihi", DateFormat("dd.MM.yyyy").format(l.pickupDate)),
                          if (!isDriver)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Bu pencere şoför teklif vermek içindir. Teklif yönetimi panelde Yük Sahibi kısmında.",
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  )
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (isDriver) ...[
                    Builder(
                      builder: (context) {
                        final uid = FirebaseAuth.instance.currentUser?.uid;

                        final Stream<QuerySnapshot<Map<String, dynamic>>> myOfferStream = (uid == null)
                            ? const Stream.empty()
                            : FirebaseFirestore.instance
                            .collection("offers")
                            .where("loadId", isEqualTo: l.id)
                            .where("driverId", isEqualTo: uid)
                            .snapshots();

                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: myOfferStream,
                          builder: (context, snap) {
                            if (snap.hasError) {
                              return Text("Teklif okunamadı: ${snap.error}");
                            }
                            if (!snap.hasData) {
                              return const Padding(
                                padding: EdgeInsets.all(8),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            final docs = snap.data!.docs.toList();

                            // ✅ createdAt'e göre (client-side) sırala: en yeni en üstte
                            docs.sort((a, b) {
                              final ta = (a.data()["createdAt"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                              final tb = (b.data()["createdAt"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                              return tb.compareTo(ta);
                            });

                            // ✅ Tüm teklif geçmişin (en yeni -> en eski)
                            final myOffers = docs.map((d) => Offer.fromDoc(d)).toList();

                            // ✅ En son teklifin
                            final Offer? lastOffer = myOffers.isNotEmpty ? myOffers.first : null;

                            // ✅ SABİT FİYAT mı?
                            final bool isFixed = (l.priceType == "fixed" && l.fixedPrice != null);
                            final int fixedPrice = l.fixedPrice ?? 0;

                            // ------------------------------------------------------------
                            // ✅ SABİT İLAN: TEKLİF FORMU GÖSTERME -> "ÜCRETİ KABUL ET"
                            // ------------------------------------------------------------
                            if (isFixed) {
                              // Eğer daha önce kabul ettiyse / zaten matched ise
                              final bool alreadyAcceptedByMe = lastOffer?.status == "accepted";
                              final bool notOpen = l.status != "open"; // marker zaten open gösteriyor ama garanti

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Sabit Ücret", style: TextStyle(fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 8),
                                      _statusChip("$fixedPrice ₺ (Sabit)", icon: Icons.payments_outlined, isOpen: true),

                                      if (myOffers.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        const Divider(),
                                        const Text("Geçmiş İşlemlerin", style: TextStyle(fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 8),
                                        ...myOffers.take(3).map((o) {
                                          final st = o.status;
                                          final label = st == "rejected"
                                              ? "Reddedildi"
                                              : st == "accepted"
                                              ? "Kabul edildi"
                                              : st == "countered"
                                              ? "Karşı teklif"
                                              : "Beklemede";
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 6),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    "${o.price} ₺ • $label",
                                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                                  ),
                                                ),
                                                if ((o.note ?? "").trim().isNotEmpty)
                                                  Text((o.note ?? "").trim(), style: const TextStyle(fontSize: 12)),
                                              ],
                                            ),
                                          );
                                        }),
                                        const SizedBox(height: 6),
                                      ],

                                      const SizedBox(height: 8),

                                      SizedBox(
                                        width: double.infinity,
                                        height: 46,
                                        child: FilledButton.icon(
                                          icon: const Icon(Icons.check_circle_outline),
                                          label: Text(
                                            notOpen
                                                ? "İlan artık uygun değil"
                                                : (alreadyAcceptedByMe ? "Zaten kabul ettin" : "Ücreti Kabul Et"),
                                          ),
                                          onPressed: (uid == null || notOpen || alreadyAcceptedByMe)
                                              ? null
                                              : () async {
                                            try {
                                              final db = FirebaseFirestore.instance;

                                              // ✅ Sabit ilanı kabul et: teklif oluştur + load'u matched yap (transaction)
                                              final newOfferRef = db.collection("offers").doc();

                                              await db.runTransaction((tx) async {
                                                final loadRef = db.collection("loads").doc(l.id);

                                                final loadSnap = await tx.get(loadRef);
                                                if (!loadSnap.exists) throw Exception("İlan bulunamadı");

                                                final data = loadSnap.data() as Map<String, dynamic>;
                                                final status = (data["status"] ?? "open").toString();
                                                final acceptedOfferId = data["acceptedOfferId"];

                                                if (status != "open") {
                                                  throw Exception("Bu ilan artık uygun değil.");
                                                }
                                                if (acceptedOfferId != null && acceptedOfferId.toString().isNotEmpty) {
                                                  throw Exception("Bu ilan başka bir şoförle eşleşmiş.");
                                                }

                                                tx.set(newOfferRef, {
                                                  "loadId": l.id,
                                                  "driverId": uid,
                                                  "driverName": appState.displayName,
                                                  "price": fixedPrice,
                                                  "note": "",
                                                  "status": "accepted",
                                                  "createdAt": FieldValue.serverTimestamp(),
                                                });

                                                tx.update(loadRef, {
                                                  "status": "matched",
                                                  "acceptedOfferId": newOfferRef.id,
                                                  "acceptedDriverId": uid,
                                                });
                                              });

                                              // ✅ diğer teklifleri reddet
                                              final others = await db
                                                  .collection("offers")
                                                  .where("loadId", isEqualTo: l.id)
                                                  .get();

                                              final batch = db.batch();
                                              for (final d in others.docs) {
                                                if (d.id == newOfferRef.id) continue;
                                                batch.update(d.reference, {"status": "rejected"});
                                              }
                                              await batch.commit();

                                              if (!mounted) return;
                                              Navigator.pop(context);
                                              _snack("Sabit ücret kabul edildi ✅");
                                            } catch (e) {
                                              _snack("Kabul hatası: $e");
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            // ------------------------------------------------------------
                            // ✅ TEKLİF USULÜ: reddedildiyse tekrar teklif + geçmiş göster
                            // ------------------------------------------------------------
                            final st = lastOffer?.status;
                            final bool canSendNewOffer = (lastOffer == null) ||
                                (st == "rejected") ||
                                (st == "driver_rejected_counter");

                            // Reddedildiyse: geçmiş kalsın ama yeni teklif formu açılsın
                            if (canSendNewOffer) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (myOffers.isNotEmpty) ...[
                                    const Text("Geçmiş Tekliflerin", style: TextStyle(fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 8),
                                    ...myOffers.take(3).map((o) {
                                      final st = o.status;
                                      final label = st == "rejected"
                                          ? "Reddedildi"
                                          : st == "accepted"
                                          ? "Kabul edildi"
                                          : st == "countered"
                                          ? "Karşı teklif"
                                          : "Beklemede";
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                "${o.price} ₺ • $label",
                                                style: const TextStyle(fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                            if ((o.note ?? "").trim().isNotEmpty)
                                              Text((o.note ?? "").trim(), style: const TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                      );
                                    }),
                                    const Divider(),
                                    const SizedBox(height: 6),
                                  ],

                                  const Text("Teklif Ver", style: TextStyle(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: priceCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: "Teklifiniz (₺)",
                                      prefixIcon: Icon(Icons.local_offer_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // YENİ BİLGİLENDİRME MESAJI

                                  const SizedBox(height: 12),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    icon: const Icon(Icons.send),
                                    label: const Text("Teklifi Gönder"),
                                    onPressed: () async {
                                      try {
                                        final uid2 = FirebaseAuth.instance.currentUser?.uid;
                                        if (uid2 == null) {
                                          _snack("Oturum yok. Tekrar giriş yap.");
                                          return;
                                        }

                                        final price = int.tryParse(priceCtrl.text.trim()) ?? 0;
                                        if (price <= 0) {
                                          _snack("Teklif tutarı geçerli olmalı.");
                                          return;
                                        }

                                        await FirebaseFirestore.instance.collection("offers").add({
                                          "loadId": l.id,
                                          "driverId": uid2,
                                          "driverName": appState.displayName,
                                          "price": price,
                                          "note": noteCtrl.text.trim(),
                                          "status": "sent",
                                          "createdAt": FieldValue.serverTimestamp(),
                                        });

                                        if (!mounted) return;
                                        Navigator.pop(context);
                                        _snack("Teklif gönderildi ✅");
                                      } catch (e) {
                                        _snack("Teklif hatası: $e");
                                      }
                                    },
                                  ),
                                ],
                              );
                            }

                            // Son teklif rejected değilse: mevcut teklif kartı
                            final myOffer = lastOffer!;
                            final counter = myOffer.counterPrice;
                            final counterNote = (myOffer.counterNote ?? "").trim();

                            String statusText;
                            IconData statusIcon;
                            switch (myOffer.status) {
                              case "countered":
                                statusText = "Karşı teklif var";
                                statusIcon = Icons.forum_outlined;
                                break;
                              case "accepted":
                                statusText = "Kabul edildi";
                                statusIcon = Icons.check_circle_outline;
                                break;
                              case "rejected":
                                statusText = "Reddedildi";
                                statusIcon = Icons.cancel_outlined;
                                break;
                              default:
                                statusText = "Beklemede";
                                statusIcon = Icons.hourglass_bottom;
                            }
                            final bool canRespondToCounter = myOffer.status == "countered";
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (myOffers.isNotEmpty) ...[
                                      const Text("Geçmiş Tekliflerin", style: TextStyle(fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 8),
                                      ...myOffers.take(3).map((o) {
                                        final st = o.status;
                                        final label = st == "rejected"
                                            ? "Reddedildi"
                                            : st == "accepted"
                                            ? "Kabul edildi"
                                            : st == "countered"
                                            ? "Karşı teklif"
                                            : "Beklemede";
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  "${o.price} ₺ • $label",
                                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                                ),
                                              ),
                                              if ((o.note ?? "").trim().isNotEmpty)
                                                Text((o.note ?? "").trim(), style: const TextStyle(fontSize: 12)),
                                            ],
                                          ),
                                        );
                                      }),
                                      const Divider(),
                                    ],

                                    Row(
                                      children: [
                                        Icon(statusIcon),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Senin teklifin: ${myOffer.price} ₺",
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                        ),
                                        const Spacer(),
                                        _statusChip(statusText),
                                      ],
                                    ),


                                    if (counter != null) ...[
                                      const SizedBox(height: 12),
                                      const Divider(),
                                      Text(
                                        "Yük sahibinin karşı teklifi",
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 6),
                                      _statusChip("$counter ₺", icon: Icons.payments_outlined),
                                      if (counterNote.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text("Not: $counterNote", style: Theme.of(context).textTheme.bodySmall),
                                      ],
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: FilledButton(
                                            onPressed: canRespondToCounter
                                            ? () async {
                            try {
                              await OfferService().acceptCounterOffer(l, myOffer);
                            if (!mounted) return;
                            Navigator.pop(context);
                            _snack("Karşı teklif kabul edildi ✅");
                            } catch (e) {
                            _snack("Kabul hatası: $e");
                            }
                            }
                                : null,
                                              child: const Text("Kabul Et"),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton(
                            onPressed: canRespondToCounter
                            ? () async {
                            try {
                              await OfferService().acceptCounterOffer(l, myOffer);
                            if (!mounted) return;
                            _snack("Karşı teklif reddedildi");
                            } catch (e) {
                            _snack("Hata: $e");
                            }
                            }
                                : null,
                                              child: const Text("Reddet"),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
// YENİ EKLENEN ŞOFÖR SOHBET BUTONU
                  // 🟢 AKILLI SOHBET / BİLGİ ALANI
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("offers")
                        .where("loadId", isEqualTo: l.id)
                        .where("driverId", isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .snapshots(),
                    builder: (context, snap) {
                      final hasOffer = snap.hasData && snap.data!.docs.isNotEmpty;

                      // EĞER TEKLİF VERMİŞSE -> SOHBET BUTONU ÇIKSIN
                      if (hasOffer) {
                        return Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final uid = FirebaseAuth.instance.currentUser?.uid;
                                  final shipperId = l.shipperId ?? "";
                                  if (uid == null || shipperId.isEmpty) return;

                                  final chatSvc = ChatService();
                                  final chatId = chatSvc.getChatId(loadId: l.id, driverId: uid);
                                  await chatSvc.ensureChat(loadId: l.id, shipperId: shipperId, driverId: uid);

                                  if (!context.mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)),
                                  );
                                },
                                icon: const Icon(Icons.chat),
                                label: const Text("Yük Sahibi ile Mesajlaş"),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        );
                      }
                      // EĞER TEKLİF VERMEMİŞSE -> BİLGİLENDİRME YAZISI ÇIKSIN
                      else {
                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.lock_outline, size: 20, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Yük sahibiyle sohbete başlamak için önce teklif göndermelisiniz.",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      }
                    },
                  ),
                  // 🟢 AKILLI ALAN BİTİŞİ
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: () => _openDirections(dest),
                      icon: const Icon(Icons.directions),
                      label: const Text("Yol Tarifi"),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDirections(LatLng dest) async {
    final origin = _pos != null ? "${_pos!.latitude},${_pos!.longitude}" : "";
    final uri = Uri.parse(
      "https://www.google.com/maps/dir/?api=1"
          "${origin.isNotEmpty ? "&origin=$origin" : ""}"
          "&destination=${dest.latitude},${dest.longitude}"
          "&travelmode=driving",
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack("Yol tarifi açılamadı.");
    }
  }

  // ✅ HARİTADAKİ HAREKETLİ PANEL
  Widget _buildDraggablePanel() {
    final isDriver = appState.role == "driver";

    return DraggableScrollableSheet(
      initialChildSize: 0.12,
      minChildSize: 0.10,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.12, 0.40, 0.85],
      builder: (context, scrollController) {
        return Material(
          elevation: 12,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
              border: Border(
                top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: isDriver
                      ? _DriverActiveJobsSheet(
                    scrollController: scrollController,
                    onOpenOnMap: focusJobById,
                  )
                      : _ShipperLoadsSheet(
                    scrollController: scrollController,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final trCenter = LatLng(39.0, 35.0);
    // Sadece 'open' olan ilanları getir. (Şoförler için)
    final loadsStream = FirebaseFirestore.instance
        .collection("loads")
        .where("status", isEqualTo: "open") // SADECE AÇIK İLANLAR
        .snapshots();

    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: loadsStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text("Harita veri hatası: ${snap.error}"));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allLoads = snap.data!.docs.map((d) => Load.fromDoc(d)).toList();

          // ✅ Driver tarafında: teslim tarihinden 1 hafta geçen ilanları gösterme
          final loads = allLoads.where((l) => !_isExpiredForDelete(l)).toList();

          // ✅ Shipper uygulamaya girince kendi süresi geçen ilanlarını temizle
          if (!_cleanupRan) {
            _cleanupRan = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _cleanupExpiredLoads(allLoads);
            });
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: trCenter,
                  initialZoom: 5.3,
                  minZoom: 3,
                  maxZoom: 19,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    userAgentPackageName: "com.example.nakliyeyg",
                  ),
                  MarkerLayer(markers: _buildMarkers(loads)),
                ],
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _pill(
                          icon: Icons.map_outlined,
                          text: "Merhaba, ${appState.displayName}",
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_locLoading) _pill(icon: Icons.gps_fixed, text: "GPS…"),
                      if (!_locLoading && _pos == null) _pill(icon: Icons.gps_off, text: "GPS yok"),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: "Profil",
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        },
                        icon: const Icon(Icons.person),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                right: 14,
                bottom: 18 + 80, // panel üstüne binsin diye biraz yukarı
                child: FloatingActionButton(
                  onPressed: () {
                    if (_pos == null) {
                      _initLocation();
                    } else {
                      _goToMyLocation();
                    }
                  },
                  child: const Icon(Icons.my_location),
                ),
              ),

              // ✅ EN ÖNEMLİ: draggable panel en sonda (üstte görünür)
              _buildDraggablePanel(),

            ],
          );
        },
      ),
    );
  }
}

// =================== DRIVER PANEL ===================

class _DriverActiveJobsSheet extends StatelessWidget {
  final ScrollController scrollController;
  final void Function(String jobId) onOpenOnMap;

  const _DriverActiveJobsSheet({
    required this.scrollController,
    required this.onOpenOnMap,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return ListView(
        controller: scrollController,
        children: const [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text("Oturum yok. Tekrar giriş yap."),
          ),
        ],
      );
    }

    final q = FirebaseFirestore.instance
        .collection("loads")
        .where("acceptedDriverId", isEqualTo: uid)
        .where("status", whereIn: ["matched", "delivered_pending"])
        .orderBy("createdAt", descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return ListView(
            controller: scrollController,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text("Hata: ${snap.error}"),
              ),
            ],
          );
        }
        if (!snap.hasData) {
          return ListView(
            controller: scrollController,
            children: const [
              Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }

        final jobs = snap.data!.docs.map((d) => Load.fromDoc(d)).toList();

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          children: [
            const Text("Aktif İşler", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),

            if (jobs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text("Henüz aktif işin yok."),
              ),

            ...jobs.map((j) {
              final cs = Theme.of(context).colorScheme;
              final isPending = j.status == "delivered_pending";

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
                      Row(
                        children: [
                          const Icon(Icons.work_outline),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "${j.fromCity} → ${j.toCity}",
                              style: const TextStyle(fontWeight: FontWeight.w900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${j.weightKg} kg • ${j.priceType == 'fixed' ? '${j.fixedPrice} ₺' : 'Teklif'}",
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: () {
                            // Sohbet odasının ID'si her zaman "load_" + ilan ID'sidir
                            final chatId = "load_${j.id}";

                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text("Yük Sahibi ile Sohbet Et"),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final lat = j.fromLat;
                                final lng = j.fromLng;

                                if (lat == null || lng == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Bu işin konumu yok.")),
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
                              },
                              icon: const Icon(Icons.directions),
                              label: const Text("Yol tarifi"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: isPending
                                  ? null
                                  : () async {
                                try {
                                  final picker = ImagePicker();
                                  final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);

                                  if (image == null) return;

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fotoğraf yükleniyor, lütfen bekleyin...")));
                                  }

                                  final storageRef = FirebaseStorage.instance.ref().child('deliveries/${j.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
                                  await storageRef.putFile(File(image.path));
                                  final downloadUrl = await storageRef.getDownloadURL();

                                  await FirebaseFirestore.instance.collection("loads").doc(j.id).update({
                                    "status": "delivered_pending",
                                    "deliveredAt": FieldValue.serverTimestamp(),
                                    "deliveryPhotoUrl": downloadUrl,
                                  });

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Teslim kanıtı yüklendi ve bildirildi ✅")),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
                                }
                              },
                              child: Text(isPending ? "Onay bekliyor" : "İşi Bitir"),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: () async {
                            await FirebaseFirestore.instance.collection("loads").doc(j.id).update({
                              "status": "open",
                              "acceptedOfferId": FieldValue.delete(),
                              "acceptedDriverId": FieldValue.delete(),
                            });

                            final offers = await FirebaseFirestore.instance
                                .collection("offers")
                                .where("loadId", isEqualTo: j.id)
                                .get();

                            final batch = FirebaseFirestore.instance.batch();
                            for (final d in offers.docs) {
                              batch.delete(d.reference);
                            }
                            await batch.commit();

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("İş iptal edildi ✅")),
                              );
                            }
                          },
                          child: const Text("İptal Et"),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// =================== SHIPPER PANEL ===================

class _ShipperLoadsSheet extends StatelessWidget {
  final ScrollController scrollController;
  const _ShipperLoadsSheet({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    // ✅ Draggable sheet ile aynı controller'ı kullan
    return OffersInboxScreen(controller: scrollController);
  }
}