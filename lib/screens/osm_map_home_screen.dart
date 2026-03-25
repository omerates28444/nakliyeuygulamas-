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
import '../services/load_service.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import 'chats_list_screen.dart';
import 'ecmr_signature_screen.dart';

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

  final Color logimapNavy = const Color(0xFF081226);
  final Color logimapBlue = const Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

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

    if (_pos != null) {
      markers.add(
        Marker(
          point: LatLng(_pos!.latitude, _pos!.longitude),
          width: 46,
          height: 46,
          child: Container(
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.20), shape: BoxShape.circle),
            child: Center(
              child: Container(width: 14, height: 14, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
            ),
          ),
        ),
      );
    }

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

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600))),
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: logimapNavy, fontSize: 15)),
      ],
    );
  }

  Widget _statusChip(String text, {IconData? icon, bool isOpen = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: isOpen ? Colors.green.shade400 : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: isOpen ? Colors.green.shade700 : Colors.grey.shade600),
            const SizedBox(width: 6),
          ],
          Text(text, style: TextStyle(fontWeight: FontWeight.w800, color: isOpen ? Colors.green.shade800 : Colors.grey.shade700, fontSize: 13)),
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
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) {
        final priceText = (l.priceType == "fixed" && l.fixedPrice != null) ? "${l.fixedPrice} ₺ (Sabit)" : "Teklif usulü";

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 24 + MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text("${l.fromCity} → ${l.toCity}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: logimapNavy)),
                      ),
                      if (isDriver)
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(color: logimapBlue.withOpacity(0.1), shape: BoxShape.circle),
                          child: IconButton(
                            tooltip: "Yük Sahibiyle Mesajlaş",
                            icon: Icon(Icons.chat_bubble_outline, color: logimapBlue, size: 22),
                            onPressed: () async {
                              final uid = FirebaseAuth.instance.currentUser?.uid;
                              final shipperId = l.shipperId ?? "";
                              if (uid == null || shipperId.isEmpty) return;
                              final chatSvc = ChatService();
                              final chatId = chatSvc.getChatId(loadId: l.id, driverId: uid);
                              await chatSvc.ensureChat(loadId: l.id, shipperId: shipperId, driverId: uid);
                              if (!context.mounted) return;
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)));
                            },
                          ),
                        ),
                      _statusChip(l.status == "open" ? "Açık" : "Eşleşti", icon: Icons.circle, isOpen: l.status == "open"),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        _infoRow(Icons.scale_outlined, "Ağırlık", "${l.weightKg} kg"),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                        _infoRow(Icons.payments_outlined, "Ücret", priceText),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                        _infoRow(Icons.calendar_today_outlined, "Teslim Tarihi", DateFormat("dd.MM.yyyy").format(l.pickupDate)),
                      ],
                    ),
                  ),

                  if (!isDriver)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Colors.grey.shade500),
                          const SizedBox(width: 8),
                          Expanded(child: Text("Bu pencere şoför teklif vermek içindir. Teklif yönetimi panelde Yük Sahibi kısmında.", style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  if (isDriver) ...[
                    Builder(
                      builder: (context) {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        final Stream<QuerySnapshot<Map<String, dynamic>>> myOfferStream = (uid == null)
                            ? const Stream.empty()
                            : FirebaseFirestore.instance.collection("offers").where("loadId", isEqualTo: l.id).where("driverId", isEqualTo: uid).snapshots();

                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: myOfferStream,
                          builder: (context, snap) {
                            if (snap.hasError) return Text("Teklif okunamadı: ${snap.error}");
                            if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                            final docs = snap.data!.docs.toList();
                            docs.sort((a, b) {
                              final ta = (a.data()["createdAt"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                              final tb = (b.data()["createdAt"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                              return tb.compareTo(ta);
                            });

                            final myOffers = docs.map((d) => Offer.fromDoc(d)).toList();
                            final Offer? lastOffer = myOffers.isNotEmpty ? myOffers.first : null;
                            final bool isFixed = (l.priceType == "fixed" && l.fixedPrice != null);
                            final int fixedPrice = l.fixedPrice ?? 0;

                            if (isFixed) {
                              final bool alreadyAcceptedByMe = lastOffer?.status == "accepted";
                              final bool notOpen = l.status != "open";

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Sabit Ücreti Kabul Et", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: logimapNavy)),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                                    child: Row(
                                      children: [
                                        Icon(Icons.payments_outlined, color: logimapBlue, size: 28),
                                        const SizedBox(width: 12),
                                        Text("$fixedPrice ₺", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: logimapNavy)),
                                        const Spacer(),
                                        Text("Sabit Fiyat", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity, height: 52,
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(backgroundColor: logimapNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                                      label: Text(notOpen ? "İlan artık uygun değil" : (alreadyAcceptedByMe ? "Zaten kabul ettin" : "Ücreti Kabul Et ve İşi Al"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                      onPressed: (uid == null || notOpen || alreadyAcceptedByMe) ? null : () async {
                                        try {
                                          final db = FirebaseFirestore.instance;
                                          final newOfferRef = db.collection("offers").doc();
                                          await db.runTransaction((tx) async {
                                            final loadRef = db.collection("loads").doc(l.id);
                                            final loadSnap = await tx.get(loadRef);
                                            if (!loadSnap.exists) throw Exception("İlan bulunamadı");
                                            final data = loadSnap.data() as Map<String, dynamic>;
                                            if (data["status"] != "open") throw Exception("Bu ilan artık uygun değil.");
                                            if (data["acceptedOfferId"] != null) throw Exception("Bu ilan eşleşmiş.");

                                            tx.set(newOfferRef, {"loadId": l.id, "driverId": uid, "driverName": appState.displayName, "price": fixedPrice, "note": "", "status": "accepted", "createdAt": FieldValue.serverTimestamp()});
                                            tx.update(loadRef, {"status": "matched", "acceptedOfferId": newOfferRef.id, "acceptedDriverId": uid});
                                          });

                                          final others = await db.collection("offers").where("loadId", isEqualTo: l.id).get();
                                          final batch = db.batch();
                                          for (final d in others.docs) { if (d.id != newOfferRef.id) batch.update(d.reference, {"status": "rejected"}); }
                                          await batch.commit();

                                          if (!mounted) return;
                                          Navigator.pop(context);
                                          _snack("Sabit ücret kabul edildi ve iş alındı ✅");
                                        } catch (e) { _snack("Kabul hatası: $e"); }
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }

                            final st = lastOffer?.status;
                            final bool canSendNewOffer = (lastOffer == null) || (st == "rejected") || (st == "driver_rejected_counter");

                            if (canSendNewOffer) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (myOffers.isNotEmpty) ...[
                                    Text("Geçmiş Tekliflerin", style: TextStyle(fontWeight: FontWeight.w900, color: logimapNavy, fontSize: 16)),
                                    const SizedBox(height: 8),
                                    ...myOffers.take(3).map((o) {
                                      final label = o.status == "rejected" ? "Reddedildi" : o.status == "accepted" ? "Kabul edildi" : o.status == "countered" ? "Karşı teklif" : "Beklemede";
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          children: [
                                            Expanded(child: Text("${o.price} ₺ • $label", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700))),
                                          ],
                                        ),
                                      );
                                    }),
                                    const Divider(height: 20),
                                  ],

                                  Text("Teklif Ver", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: logimapNavy)),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: priceCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: logimapNavy),
                                    decoration: InputDecoration(
                                      labelText: "Teklif Tutarınız (₺)",
                                      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                      prefixIcon: Icon(Icons.local_offer_outlined, color: logimapBlue),
                                      filled: true, fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: logimapBlue, width: 2)),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity, height: 52,
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(backgroundColor: logimapBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                                      label: const Text("Teklifi Gönder", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                      onPressed: () async {
                                        try {
                                          final uid2 = FirebaseAuth.instance.currentUser?.uid;
                                          if (uid2 == null) { _snack("Oturum yok. Tekrar giriş yap."); return; }
                                          final price = int.tryParse(priceCtrl.text.trim()) ?? 0;
                                          if (price <= 0) { _snack("Teklif tutarı geçerli olmalı."); return; }

                                          await FirebaseFirestore.instance.collection("offers").add({"loadId": l.id, "driverId": uid2, "driverName": appState.displayName, "price": price, "note": noteCtrl.text.trim(), "status": "sent", "createdAt": FieldValue.serverTimestamp()});
                                          if (!mounted) return;
                                          Navigator.pop(context);
                                          _snack("Teklif gönderildi ✅");
                                        } catch (e) { _snack("Teklif hatası: $e"); }
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }

                            final myOffer = lastOffer!;
                            final counter = myOffer.counterPrice;

                            String statusText; IconData statusIcon;
                            switch (myOffer.status) {
                              case "countered": statusText = "Karşı teklif var"; statusIcon = Icons.forum_outlined; break;
                              case "accepted": statusText = "Kabul edildi"; statusIcon = Icons.check_circle_outline; break;
                              case "rejected": statusText = "Reddedildi"; statusIcon = Icons.cancel_outlined; break;
                              default: statusText = "Beklemede"; statusIcon = Icons.hourglass_bottom;
                            }
                            final bool canRespondToCounter = myOffer.status == "countered";

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(statusIcon, color: logimapBlue),
                                      const SizedBox(width: 8),
                                      Text("Senin teklifin: ${myOffer.price} ₺", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: logimapNavy)),
                                      const Spacer(),
                                      _statusChip(statusText),
                                    ],
                                  ),

                                  if (counter != null) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text("Yük Sahibinin Teklifi:", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87)),
                                          Text("$counter ₺", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.orange.shade900, fontSize: 16)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        IconButton.filled(
                                          style: IconButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                          tooltip: "Reddet",
                                          onPressed: canRespondToCounter ? () async {
                                            try {
                                              await FirebaseFirestore.instance.collection("offers").doc(myOffer.id).update({"status": "driver_rejected_counter"});
                                              if (!mounted) return; _snack("Teklifi reddettiniz.");
                                            } catch (e) { _snack("Hata: $e"); }
                                          } : null,
                                          icon: const Icon(Icons.close, color: Colors.red),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FilledButton.tonalIcon(
                                            style: FilledButton.styleFrom(backgroundColor: Colors.orange.withOpacity(0.1), foregroundColor: Colors.orange.shade900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                            onPressed: canRespondToCounter ? () async {
                                              final priceCtrlDialog = TextEditingController();
                                              final ok = await showDialog<bool>(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  backgroundColor: Colors.white,
                                                  title: const Text("Yeni Teklif İlet", style: TextStyle(fontWeight: FontWeight.w900)),
                                                  content: TextField(controller: priceCtrlDialog, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Yeni Teklifiniz (₺)", prefixIcon: const Icon(Icons.local_offer_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
                                                    FilledButton(style: FilledButton.styleFrom(backgroundColor: logimapNavy), onPressed: () => Navigator.pop(context, true), child: const Text("Gönder")),
                                                  ],
                                                ),
                                              );
                                              if (ok != true) return;
                                              final newPrice = int.tryParse(priceCtrlDialog.text.trim()) ?? 0;
                                              if (newPrice <= 0) return _snack("Geçerli bir tutar girin.");
                                              try {
                                                await FirebaseFirestore.instance.collection("offers").doc(myOffer.id).update({"status": "driver_rejected_counter"});
                                                final uid2 = FirebaseAuth.instance.currentUser?.uid;
                                                await FirebaseFirestore.instance.collection("offers").add({"loadId": l.id, "driverId": uid2, "driverName": appState.displayName, "price": newPrice, "note": "", "status": "sent", "createdAt": FieldValue.serverTimestamp()});
                                                if (!mounted) return; Navigator.pop(context); _snack("Yeni teklifiniz iletildi ✅");
                                              } catch (e) { _snack("Hata: $e"); }
                                            } : null,
                                            icon: const Icon(Icons.handshake_outlined, size: 18),
                                            label: const Text("Pazarlık Yap", style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FilledButton.icon(
                                            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                            onPressed: canRespondToCounter ? () async {
                                              try {
                                                await OfferService().acceptCounterOffer(l, myOffer);
                                                if (!mounted) return; Navigator.pop(context); _snack("Karşı teklif kabul edildi ✅");
                                              } catch (e) { _snack("Kabul hatası: $e"); }
                                            } : null,
                                            icon: const Icon(Icons.check, size: 18, color: Colors.white),
                                            label: const Text("Kabul Et", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 🟢 YOL TARİFİ (Zarif İkincil Buton)
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        foregroundColor: logimapNavy,
                      ),
                      onPressed: () => _openDirections(dest),
                      icon: const Icon(Icons.directions, size: 20),
                      label: const Text("Haritada Yol Tarifi Al", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
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
    final uri = Uri.parse("https://www.google.com/maps/dir/?api=1${origin.isNotEmpty ? '&origin=$origin' : ''}&destination=${dest.latitude},${dest.longitude}&travelmode=driving");
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) { _snack("Yol tarifi açılamadı."); }
  }

  Widget _buildDraggablePanel() {
    final isDriver = appState.role == "driver";
    return DraggableScrollableSheet(
      initialChildSize: 0.12, minChildSize: 0.10, maxChildSize: 0.85, snap: true, snapSizes: const [0.12, 0.40, 0.85],
      builder: (context, scrollController) {
        return Material(
          elevation: 20,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28))),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 50, height: 6, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(99))),
                const SizedBox(height: 12),
                Expanded(child: isDriver ? _DriverActiveJobsSheet(scrollController: scrollController, onOpenOnMap: focusJobById) : _ShipperLoadsSheet(scrollController: scrollController)),
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
    Query<Map<String, dynamic>> loadsQuery = FirebaseFirestore.instance.collection("loads").where("status", isEqualTo: "open");
    if (appState.role == "driver" && appState.capacityKg != null) { loadsQuery = loadsQuery.where("weightKg", isLessThanOrEqualTo: appState.capacityKg); }
    final loadsStream = loadsQuery.snapshots();

    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: loadsStream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Harita veri hatası: ${snap.error}"));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final allLoads = snap.data!.docs.map((d) => Load.fromDoc(d)).toList();
          final loads = allLoads.where((l) => !_isExpiredForDelete(l)).toList();

          if (!_cleanupRan) {
            _cleanupRan = true;
            WidgetsBinding.instance.addPostFrameCallback((_) { _cleanupExpiredLoads(allLoads); });
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: trCenter, initialZoom: 5.3, minZoom: 3, maxZoom: 19, interactionOptions: const InteractionOptions(flags: InteractiveFlag.all)),
                children: [
                  TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: "com.example.nakliyeyg"),
                  MarkerLayer(markers: _buildMarkers(loads)),
                ],
              ),

              Positioned(
                top: MediaQuery.of(context).padding.top + 10, left: 16, right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))]),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: logimapBlue.withOpacity(0.15), radius: 18,
                        child: Icon(_pos == null ? Icons.location_searching : Icons.my_location, color: _locLoading ? Colors.grey : (_pos == null ? Colors.red : logimapBlue), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text("Merhaba, ${appState.displayName}", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: logimapNavy), overflow: TextOverflow.ellipsis)),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatsListScreen())),
                        child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle), child: Icon(Icons.chat_bubble_outline_rounded, color: logimapNavy, size: 22)),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                        child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle), child: Icon(Icons.person_outline, color: logimapNavy, size: 22)),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                right: 16, bottom: 18 + 90,
                child: FloatingActionButton(
                  backgroundColor: logimapBlue, foregroundColor: Colors.white, elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: () { if (_pos == null) _initLocation(); else _goToMyLocation(); },
                  child: const Icon(Icons.my_location),
                ),
              ),

              _buildDraggablePanel(),
            ],
          );
        },
      ),
    );
  }
}

class _DriverActiveJobsSheet extends StatelessWidget {
  final ScrollController scrollController;
  final void Function(String jobId) onOpenOnMap;
  const _DriverActiveJobsSheet({required this.scrollController, required this.onOpenOnMap});

  Widget _quickActionButton({required IconData icon, required String label, required VoidCallback onTap, Color color = const Color(0xFF081226)}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.08), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return ListView(controller: scrollController, children: const [Padding(padding: EdgeInsets.all(16), child: Text("Oturum yok. Tekrar giriş yap."))]);

    final q = FirebaseFirestore.instance.collection("loads").where("acceptedDriverId", isEqualTo: uid).where("status", whereIn: ["matched", "delivered_pending"]).orderBy("createdAt", descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return ListView(controller: scrollController, children: [Padding(padding: const EdgeInsets.all(16), child: Text("Hata: ${snap.error}"))]);
        if (!snap.hasData) return ListView(controller: scrollController, children: const [Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))]);

        final jobs = snap.data!.docs.map((d) => Load.fromDoc(d)).toList();

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const Padding(padding: EdgeInsets.only(bottom: 12), child: Text("Aktif İşlerim", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF081226)))),
            if (jobs.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text("Henüz aktif işin yok.", style: TextStyle(color: Colors.grey))),

            ...jobs.map((j) {
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection("loads").doc(j.id).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

                  final bool driverSigned = data["ecmrSignedBy_driver"] == true;
                  final bool shipperSigned = data["ecmrSignedBy_shipper"] == true;
                  final String? pdfUrl = data["ecmrUrl_driver"] ?? data["ecmrUrl_shipper"];
                  final isPending = data["status"] == "delivered_pending";

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                          child: Row(
                            children: [
                              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF1976D2).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF1976D2), size: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("${j.fromCity} → ${j.toCity}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF081226)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text("${j.weightKg} kg • ${j.priceType == 'fixed' ? '${j.fixedPrice} ₺' : 'Teklif Usulü'}", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.grey),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onSelected: (value) async {
                                  if (value == 'cancel') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text("İşi iptal et?"), content: const Text("Emin misiniz? İlan tekrar açık duruma dönecektir."),
                                        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text("İptal Et"))],
                                      ),
                                    );
                                    if (ok == true) {
                                      await FirebaseFirestore.instance.collection("loads").doc(j.id).update({"status": "open", "acceptedOfferId": FieldValue.delete(), "acceptedDriverId": FieldValue.delete()});
                                      final offers = await FirebaseFirestore.instance.collection("offers").where("loadId", isEqualTo: j.id).get();
                                      final batch = FirebaseFirestore.instance.batch();
                                      for (final d in offers.docs) { batch.delete(d.reference); }
                                      await batch.commit();
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İş iptal edildi ✅")));
                                    }
                                  }
                                },
                                itemBuilder: (BuildContext context) => [const PopupMenuItem(value: 'cancel', child: Row(children: [Icon(Icons.cancel_outlined, color: Colors.red, size: 20), SizedBox(width: 8), Text("İşi İptal Et", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]))],
                              ),
                            ],
                          ),
                        ),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 24)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // 🟢 BURASI DÜZELTİLEN YOL TARİFİ BUTONU 🟢
                            _quickActionButton(
                                icon: Icons.directions,
                                label: "Yol Tarifi",
                                color: const Color(0xFF1976D2),
                                onTap: () async {
                                  final double? lat = j.fromLat;
                                  final double? lng = j.fromLng;
                                  if (lat == null || lng == null) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu işin konum bilgisi eksik.")));
                                    }
                                    return;
                                  }
                                  final String url = "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng";
                                  final uri = Uri.parse(url);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harita açılamadı.")));
                                    }
                                  }
                                }
                            ),
                            _quickActionButton(icon: Icons.chat_bubble_outline, label: "Sohbet", color: Colors.orange.shade800, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: "load_${j.id}")))),
                            _quickActionButton(icon: Icons.map_outlined, label: "Harita", onTap: () => onOpenOnMap(j.id)),
                            if (pdfUrl != null && driverSigned && shipperSigned)
                              _quickActionButton(icon: Icons.picture_as_pdf, label: "Sözleşme", color: Colors.green.shade700, onTap: () => launchUrl(Uri.parse(pdfUrl), mode: LaunchMode.externalApplication)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Builder(
                            builder: (context) {
                              if (!driverSigned) {
                                return SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF081226), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EcmrSignatureScreen(loadId: j.id, role: "driver"))), icon: const Icon(Icons.draw, color: Colors.white), label: const Text("Sözleşmeyi İmzala", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))));
                              } else if (!shipperSigned) {
                                return Container(width: double.infinity, height: 50, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade300)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.hourglass_empty, size: 20, color: Colors.grey.shade600), const SizedBox(width: 8), Text("Yük Sahibinin İmzası Bekleniyor", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold))]));
                              } else {
                                return SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: isPending ? Colors.orange.shade600 : Colors.green.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: isPending ? null : () async {
                                  try {
                                    final picker = ImagePicker(); final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                                    if (image == null) return;
                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fotoğraf yükleniyor...")));
                                    final storageRef = FirebaseStorage.instance.ref().child('deliveries/${j.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
                                    await storageRef.putFile(File(image.path));
                                    final downloadUrl = await storageRef.getDownloadURL();
                                    await FirebaseFirestore.instance.collection("loads").doc(j.id).update({"status": "delivered_pending", "deliveredAt": FieldValue.serverTimestamp(), "deliveryPhotoUrl": downloadUrl});
                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Teslim kanıtı yüklendi ✅")));
                                  } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"))); }
                                }, icon: Icon(isPending ? Icons.access_time_filled : Icons.check_circle, color: Colors.white), label: Text(isPending ? "Müşteri Onayı Bekleniyor" : "İşi Bitir", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          ],
        );
      },
    );
  }
}

class _ShipperLoadsSheet extends StatelessWidget {
  final ScrollController scrollController;
  const _ShipperLoadsSheet({required this.scrollController});
  @override Widget build(BuildContext context) { return OffersInboxScreen(controller: scrollController); }
}