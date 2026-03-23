import re
import codecs

def process_file(path, replacements):
    with codecs.open(path, 'r', 'utf-8') as f:
        code = f.read()
    
    # Normalize newlines to \n
    code = code.replace('\r\n', '\n')
    
    for old, new in replacements:
        if old not in code:
            print(f"Warning: Chunk not found in {path}\n{old[:50]}...")
        code = code.replace(old, new)
        
    with codecs.open(path, 'w', 'utf-8') as f:
        f.write(code)

# ----------------- admin_dashboard_screen.dart -----------------
replacements_admin = [
    (
        "import 'package:cloud_firestore/cloud_firestore.dart';",
        "import 'package:supabase_flutter/supabase_flutter.dart';"
    ),
    (
        "final db = FirebaseFirestore.instance;",
        "final db = Supabase.instance.client;"
    ),
    (
        '''          StreamBuilder<QuerySnapshot>(
            stream: db.collection("loads").snapshots(),
            builder: (context, loadSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: db.collection("users").snapshots(),
                builder: (context, userSnap) {
                  final totalUsers = userSnap.data?.docs.length ?? 0;
                  final allLoads = loadSnap.data?.docs ?? [];
                  final newLoads = allLoads.where((d) => d["status"] == "open").length;
                  
                  // Toplam Hacim Hesaplama (Done olan yüklerin fiyatlarını topla)
                  double totalRevenue = 0;
                  int doneCount = 0;
                  for (var doc in allLoads) {
                    final data = doc.data() as Map<String, dynamic>;''',
        '''          StreamBuilder<List<Map<String, dynamic>>>(
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
                  for (var data in allLoads) {'''
    ),
    (
        '''            child: StreamBuilder<QuerySnapshot>(
              // En son eklenen 5 yükü getir
              stream: db.collection("loads").orderBy("createdAt", descending: true).limit(5).snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const LinearProgressIndicator();
                final docs = snap.data!.docs;
                if (docs.isEmpty) return Padding(padding: const EdgeInsets.all(16), child: Text(isEn ? "No activity yet." : "Henüz hareket yok."));

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final from = data["fromCity"] ?? "?";''',
        '''            child: StreamBuilder<List<Map<String, dynamic>>>(
              // En son eklenen 5 yükü getir
              stream: db.from("loads").stream(primaryKey: ['id']).order("createdAt", ascending: false).limit(5),
              builder: (context, snap) {
                if (!snap.hasData) return const LinearProgressIndicator();
                final docs = snap.data!;
                if (docs.isEmpty) return Padding(padding: const EdgeInsets.all(16), child: Text(isEn ? "No activity yet." : "Henüz hareket yok."));

                return Column(
                  children: docs.map((data) {
                    final from = data["fromCity"] ?? "?";'''
    )
]
process_file('lib/screens/admin_dashboard_screen.dart', replacements_admin)

# ----------------- user_management_screen.dart -----------------
replacements_user = [
    (
        "import 'package:cloud_firestore/cloud_firestore.dart';",
        "import 'package:supabase_flutter/supabase_flutter.dart';"
    ),
    (
        "final db = FirebaseFirestore.instance;",
        "final db = Supabase.instance.client;"
    ),
    (
        '''      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection("users").orderBy("createdAt", descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Hata: ${snap.error}"));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return Center(child: Text(isEn ? "No users found." : "Kullanıcı bulunamadı."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final uid = docs[index].id;''',
        '''      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.from("users").stream(primaryKey: ['id']).order("createdAt", ascending: false),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Hata: ${snap.error}"));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!;

          if (docs.isEmpty) {
            return Center(child: Text(isEn ? "No users found." : "Kullanıcı bulunamadı."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index];
              final uid = data['id'].toString();'''
    ),
    (
        '''  Future<void> _verifyUser(BuildContext context, String uid, String name) async {
    try {
      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "isVerified": true,
        "verifiedAt": FieldValue.serverTimestamp(),
      });''',
        '''  Future<void> _verifyUser(BuildContext context, String uid, String name) async {
    try {
      await Supabase.instance.client.from("users").update({
        "isVerified": true,
        "verifiedAt": DateTime.now().toUtc().toIso8601String(),
      }).eq("id", uid);'''
    )
]
process_file('lib/screens/user_management_screen.dart', replacements_user)

# ----------------- load_create_screen.dart -----------------
replacements_create = [
    (
        '''import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';''',
        '''import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';'''
    ),
    (
        "final uid = FirebaseAuth.instance.currentUser?.uid;",
        "final uid = AuthService().currentUser?.id;"
    ),
    (
        '''      // Firestore'a yaz
      await FirebaseFirestore.instance.collection("loads").add({
        "fromCity": from,
        "toCity": to,
        "pickupDate": Timestamp.fromDate(pickupDate),
        "weightKg": weight,
        "priceType": priceType,
        "fixedPrice": priceType == "fixed" ? fixedPrice : null,
        "status": "open",
        "shipperId": uid,
        "createdAt": FieldValue.serverTimestamp(),

        // 🔥 KONUM
        "fromLat": selectedLat,
        "fromLng": selectedLng,
      });''',
        '''      // Supabase'e yaz
      await Supabase.instance.client.from("loads").insert({
        "fromCity": from,
        "toCity": to,
        "pickupDate": pickupDate.toUtc().toIso8601String(),
        "weightKg": weight,
        "priceType": priceType,
        "fixedPrice": priceType == "fixed" ? fixedPrice : null,
        "status": "open",
        "shipperId": uid,

        // 🔥 KONUM
        "fromLat": selectedLat,
        "fromLng": selectedLng,
      });'''
    )
]
process_file('lib/screens/load_create_screen.dart', replacements_create)

# ----------------- osm_map_home_screen.dart -----------------
replacements_map = [
    (
        '''import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';''',
        '''import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';'''
    ),
    (
        '''  /// Panel/iş listesinden haritayı o işe odakla
  void focusJobById(String jobId) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection("loads").doc(jobId).get();
      if (!doc.exists) return;
      final l = Load.fromDoc(doc);''',
        '''  /// Panel/iş listesinden haritayı o işe odakla
  void focusJobById(String jobId) async {
    try {
      final data =
          await Supabase.instance.client.from("loads").select().eq("id", jobId).maybeSingle();
      if (data == null) return;
      final l = Load.fromMap(data);'''
    ),
    (
        '''  // ✅ driver karşı teklifi kabul
  Future<void> _driverAcceptCounter({
    required Load load,
    required Offer myOffer,
  }) async {
    final db = FirebaseFirestore.instance;

    await db.runTransaction((tx) async {
      final loadRef = db.collection("loads").doc(load.id);
      final offerRef = db.collection("offers").doc(myOffer.id);

      final loadSnap = await tx.get(loadRef);
      if (!loadSnap.exists) throw Exception("İlan bulunamadı");

      final data = loadSnap.data() as Map<String, dynamic>;
      final status = (data["status"] ?? "open").toString();
      final acceptedOfferId = data["acceptedOfferId"];

      // ✅ Başkası aldıysa / ilan kapalıysa engelle
      if (status != "open" && status != "matched") {
        throw Exception("Bu ilan artık uygun değil.");
      }
      if (acceptedOfferId != null && acceptedOfferId.toString().isNotEmpty) {
        throw Exception("Bu ilan başka bir şoförle eşleşmiş.");
      }

      // ✅ benim teklifimi accepted
      tx.update(offerRef, {"status": "accepted"});

      // ✅ load'u matched yap
      tx.update(loadRef, {
        "status": "matched",
        "acceptedOfferId": myOffer.id,
        "acceptedDriverId": myOffer.driverId,
      });
    });

    // ✅ transaction sonrası diğer teklifleri reddet
    final others =
        await db.collection("offers").where("loadId", isEqualTo: load.id).get();
    final batch = db.batch();
    for (final d in others.docs) {
      if (d.id == myOffer.id) continue;
      batch.update(d.reference, {"status": "rejected"});
    }
    await batch.commit();
  }''',
        '''  // ✅ driver karşı teklifi kabul
  Future<void> _driverAcceptCounter({
    required Load load,
    required Offer myOffer,
  }) async {
    final db = Supabase.instance.client;

    final data = await db.from("loads").select().eq("id", load.id).maybeSingle() ?? {};
    final status = (data["status"] ?? "open").toString();
    final acceptedOfferId = data["acceptedOfferId"];

    if (status != "open" && status != "matched") {
      throw Exception("Bu ilan artık uygun değil.");
    }
    if (acceptedOfferId != null && acceptedOfferId.toString().isNotEmpty) {
      throw Exception("Bu ilan başka bir şoförle eşleşmiş.");
    }

    await db.from("offers").update({"status": "accepted"}).eq("id", myOffer.id);

    await db.from("loads").update({
      "status": "matched",
      "acceptedOfferId": myOffer.id,
      "acceptedDriverId": myOffer.driverId,
    }).eq("id", load.id);

    final others = await db.from("offers").select().eq("loadId", load.id).neq("id", myOffer.id);
    for (final d in others) {
      await db.from("offers").update({"status": "rejected"}).eq("id", d["id"]);
    }
  }'''
    ),
    (
        '''  // ✅ driver karşı teklifi reddedince: teklif silinsin
  Future<void> _driverRejectCounter({required Offer myOffer}) async {
    await FirebaseFirestore.instance
        .collection("offers")
        .doc(myOffer.id)
        .update({
      "status": "driver_rejected_counter",
      "driverRejectedAt": FieldValue.serverTimestamp(),
    });
  }''',
        '''  // ✅ driver karşı teklifi reddedince: teklif silinsin
  Future<void> _driverRejectCounter({required Offer myOffer}) async {
    await Supabase.instance.client.from("offers").update({
      "status": "driver_rejected_counter",
      "driverRejectedAt": DateTime.now().toUtc().toIso8601String(),
    }).eq("id", myOffer.id);
  }'''
    ),
    (
        '''  Future<void> _deleteLoadWithOffersById(String loadId) async {
    final db = FirebaseFirestore.instance;

    final offersSnap =
        await db.collection("offers").where("loadId", isEqualTo: loadId).get();
    final batch = db.batch();

    for (final d in offersSnap.docs) {
      batch.delete(d.reference);
    }
    batch.delete(db.collection("loads").doc(loadId));

    await batch.commit();
  }''',
        '''  Future<void> _deleteLoadWithOffersById(String loadId) async {
    final db = Supabase.instance.client;
    await db.from("offers").delete().eq("loadId", loadId);
    await db.from("loads").delete().eq("id", loadId);
  }'''
    ),
    (
        '''    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;''',
        '''    final uid = AuthService().currentUser?.id;
    if (uid == null) return;'''
    ),
    (
        '''                        final uid = FirebaseAuth.instance.currentUser?.uid;

                        final Stream<QuerySnapshot<Map<String, dynamic>>>
                            myOfferStream = (uid == null)
                                ? const Stream.empty()
                                : FirebaseFirestore.instance
                                    .collection("offers")
                                    .where("loadId", isEqualTo: l.id)
                                    .where("driverId", isEqualTo: uid)
                                    .snapshots();

                        return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>>(
                          stream: myOfferStream,
                          builder: (context, snap) {
                            if (snap.hasError) {
                              return Text("Teklif okunamadı: ${snap.error}");
                            }
                            if (!snap.hasData) {
                              return const Padding(
                                padding: EdgeInsets.all(8),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            }

                            final docs = snap.data!.docs.toList();

                            // ✅ createdAt'e göre (client-side) sırala: en yeni en üstte
                            docs.sort((a, b) {
                              final ta = (a.data()["createdAt"] as Timestamp?)
                                      ?.millisecondsSinceEpoch ??
                                  0;
                              final tb = (b.data()["createdAt"] as Timestamp?)
                                      ?.millisecondsSinceEpoch ??
                                  0;
                              return tb.compareTo(ta);
                            });

                            // ✅ Tüm teklif geçmişin (en yeni -> en eski)
                            final myOffers =
                                docs.map((d) => Offer.fromDoc(d)).toList();''',
        '''                        final uid = AuthService().currentUser?.id;

                        final Stream<List<Map<String, dynamic>>>
                            myOfferStream = (uid == null)
                                ? const Stream.empty()
                                : Supabase.instance.client
                                    .from("offers")
                                    .stream(primaryKey: ['id'])
                                    .eq("loadId", l.id)
                                    .order("createdAt", ascending: false);

                        return StreamBuilder<List<Map<String, dynamic>>>(
                          stream: myOfferStream,
                          builder: (context, snap) {
                            if (snap.hasError) {
                              return Text("Teklif okunamadı: ${snap.error}");
                            }
                            if (!snap.hasData) {
                              return const Padding(
                                padding: EdgeInsets.all(8),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            }

                            final docs = snap.data!.where((d) => d['driverId'] == uid).toList();

                            // ✅ Tüm teklif geçmişin (en yeni -> en eski)
                            final myOffers =
                                docs.map((d) => Offer.fromMap(d)).toList();'''
    ),
    (
        '''                                                    final db = FirebaseFirestore
                                                        .instance;

                                                    // ✅ Sabit ilanı kabul et: teklif oluştur + load'u matched yap (transaction)
                                                    final newOfferRef = db
                                                        .collection("offers")
                                                        .doc();

                                                    await db.runTransaction(
                                                        (tx) async {
                                                      final loadRef = db
                                                          .collection("loads")
                                                          .doc(l.id);

                                                      final loadSnap =
                                                          await tx.get(loadRef);
                                                      if (!loadSnap.exists)
                                                        throw Exception(
                                                            "İlan bulunamadı");

                                                      final data =
                                                          loadSnap.data()
                                                              as Map<String,
                                                                  dynamic>;
                                                      final status =
                                                          (data["status"] ??
                                                                  "open")
                                                              .toString();
                                                      final acceptedOfferId =
                                                          data[
                                                              "acceptedOfferId"];

                                                      if (status != "open") {
                                                        throw Exception(
                                                            "Bu ilan artık uygun değil.");
                                                      }
                                                      if (acceptedOfferId !=
                                                              null &&
                                                          acceptedOfferId
                                                              .toString()
                                                              .isNotEmpty) {
                                                        throw Exception(
                                                            "Bu ilan başka bir şoförle eşleşmiş.");
                                                      }

                                                      tx.set(newOfferRef, {
                                                        "loadId": l.id,
                                                        "driverId": uid,
                                                        "driverName": appState
                                                            .displayName,
                                                        "price": fixedPrice,
                                                        "note": "",
                                                        "status": "accepted",
                                                        "createdAt": FieldValue
                                                            .serverTimestamp(),
                                                      });

                                                      tx.update(loadRef, {
                                                        "status": "matched",
                                                        "acceptedOfferId":
                                                            newOfferRef.id,
                                                        "acceptedDriverId": uid,
                                                      });
                                                    });

                                                    // ✅ diğer teklifleri reddet
                                                    final others = await db
                                                        .collection("offers")
                                                        .where("loadId",
                                                            isEqualTo: l.id)
                                                        .get();

                                                    final batch = db.batch();
                                                    for (final d
                                                        in others.docs) {
                                                      if (d.id ==
                                                          newOfferRef.id)
                                                        continue;
                                                      batch.update(
                                                          d.reference, {
                                                        "status": "rejected"
                                                      });
                                                    }
                                                    await batch.commit();''',
        '''                                                    final db = Supabase.instance.client;

                                                    final data = await db.from("loads").select().eq("id", l.id).maybeSingle() ?? {};
                                                    final status = (data["status"] ?? "open").toString();
                                                    final acceptedOfferId = data["acceptedOfferId"];

                                                    if (status != "open") {
                                                      throw Exception("Bu ilan artık uygun değil.");
                                                    }
                                                    if (acceptedOfferId != null && acceptedOfferId.toString().isNotEmpty) {
                                                      throw Exception("Bu ilan başka bir şoförle eşleşmiş.");
                                                    }

                                                    final offerData = await db.from("offers").insert({
                                                      "loadId": l.id,
                                                      "driverId": uid,
                                                      "driverName": appState.displayName,
                                                      "price": fixedPrice,
                                                      "note": "",
                                                      "status": "accepted",
                                                    }).select().maybeSingle();

                                                    if (offerData == null) throw Exception("Teklif oluşturulamadı");
                                                    final newOfferId = offerData['id'].toString();

                                                    await db.from("loads").update({
                                                      "status": "matched",
                                                      "acceptedOfferId": newOfferId,
                                                      "acceptedDriverId": uid,
                                                    }).eq("id", l.id);

                                                    final others = await db.from("offers").select().eq("loadId", l.id).neq("id", newOfferId);
                                                    for (final d in others) {
                                                      await db.from("offers").update({"status": "rejected"}).eq("id", d["id"]);
                                                    }'''
    ),
    (
        '''                                        final uid2 = FirebaseAuth
                                            .instance.currentUser?.uid;
                                        if (uid2 == null) {
                                          _snack(
                                              "Oturum yok. Tekrar giriş yap.");
                                          return;
                                        }

                                        final price = int.tryParse(
                                                priceCtrl.text.trim()) ??
                                            0;
                                        if (price <= 0) {
                                          _snack(
                                              "Teklif tutarı geçerli olmalı.");
                                          return;
                                        }

                                        await FirebaseFirestore.instance
                                            .collection("offers")
                                            .add({
                                          "loadId": l.id,
                                          "driverId": uid2,
                                          "driverName": appState.displayName,
                                          "price": price,
                                          "note": noteCtrl.text.trim(),
                                          "status": "sent",
                                          "createdAt":
                                              FieldValue.serverTimestamp(),
                                        });''',
        '''                                        final uid2 = AuthService().currentUser?.id;
                                        if (uid2 == null) {
                                          _snack(
                                              "Oturum yok. Tekrar giriş yap.");
                                          return;
                                        }

                                        final price = int.tryParse(
                                                priceCtrl.text.trim()) ??
                                            0;
                                        if (price <= 0) {
                                          _snack(
                                              "Teklif tutarı geçerli olmalı.");
                                          return;
                                        }

                                        await Supabase.instance.client
                                            .from("offers")
                                            .insert({
                                          "loadId": l.id,
                                          "driverId": uid2,
                                          "driverName": appState.displayName,
                                          "price": price,
                                          "note": noteCtrl.text.trim(),
                                          "status": "sent",
                                        });'''
    ),
    (
        '''  @override
  Widget build(BuildContext context) {
    const trCenter = LatLng(39.0, 35.0);
    final loadsStream =
        FirebaseFirestore.instance.collection("loads").snapshots();

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

          final allLoads = snap.data!.docs.map((d) => Load.fromDoc(d)).toList();''',
        '''  @override
  Widget build(BuildContext context) {
    const trCenter = LatLng(39.0, 35.0);
    final stream = Supabase.instance.client.from("loads").stream(primaryKey: ['id']).order("createdAt", ascending: false);

    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text("Harita veri hatası: ${snap.error}"));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allLoads = snap.data!.map((d) => Load.fromMap(d)).toList();'''
    ),
    (
        '''  @override
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
        .where("status", whereIn: ["matched", "delivered_pending"]).orderBy(
            "createdAt",
            descending: true);

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

        final jobs = snap.data!.docs.map((d) => Load.fromDoc(d)).toList();''',
        '''  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.id;
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

    final stream = Supabase.instance.client
        .from("loads")
        .stream(primaryKey: ['id'])
        .eq("acceptedDriverId", uid)
        .order("createdAt", ascending: false);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
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

        final allJobs = snap.data!.map((d) => Load.fromMap(d)).toList();
        final jobs = allJobs.where((j) => ['matched', 'delivered_pending'].contains(j.status)).toList();'''
    ),
    (
        '''                                      await FirebaseFirestore.instance
                                          .collection("loads")
                                          .doc(j.id)
                                          .update({
                                        "status": "delivered_pending",
                                        "deliveredAt":
                                            FieldValue.serverTimestamp(),
                                      });''',
        '''                                      await Supabase.instance.client
                                          .from("loads")
                                          .update({
                                        "status": "delivered_pending",
                                        "deliveredAt": DateTime.now().toUtc().toIso8601String(),
                                      }).eq("id", j.id);'''
    ),
    (
        '''                            await FirebaseFirestore.instance
                                .collection("loads")
                                .doc(j.id)
                                .update({
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
                            await batch.commit();''',
        '''                            await Supabase.instance.client
                                .from("loads")
                                .update({
                              "status": "open",
                              "acceptedOfferId": null,
                              "acceptedDriverId": null,
                            }).eq("id", j.id);

                            await Supabase.instance.client
                                .from("offers")
                                .delete()
                                .eq("loadId", j.id);'''
    )
]
process_file('lib/screens/osm_map_home_screen.dart', replacements_map)

print("done script3!")
