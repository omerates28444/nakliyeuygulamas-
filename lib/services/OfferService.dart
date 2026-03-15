import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/load.dart';
import '../models/offer.dart';
import 'chat_service.dart';

class OfferService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🟢 YENİ: Şoförün ilk teklifi göndermesi
  Future<void> sendOffer({
    required String loadId,
    required String shipperId, // İlan sahibinin ID'si (Bildirimler için çok önemli)
    required String driverId,
    required String driverName,
    required int price,
    required String note,
  }) async {
    await _db.collection("offers").add({
      "loadId": loadId,
      "shipperId": shipperId,
      "driverId": driverId,
      "driverName": driverName,
      "price": price,
      "note": note,
      "status": "sent",
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  // 🟢 YENİ: Yük sahibinin karşı (pazarlık) teklif göndermesi
  Future<void> sendCounterOffer({
    required String offerId,
    required int counterPrice,
    required String counterNote,
  }) async {
    await _db.collection("offers").doc(offerId).update({
      "counterPrice": counterPrice,
      "counterNote": counterNote,
      "status": "countered",
      "counterAt": FieldValue.serverTimestamp(),
    });
  }

  // 🟢 YENİ: Yük sahibinin şoförden gelen teklifi (veya karşı teklifi) KABUL ETMESİ
  Future<void> acceptOfferByShipper({
    required String loadId,
    required String offerId,
    required String driverId,
    required String shipperId,
  }) async {
    String realShipperId = shipperId.trim();

    // Güvenlik: Shipper ID gelmediyse veritabanından kendimiz bulalım
    if (realShipperId.isEmpty) {
      final loadSnap = await _db.collection("loads").doc(loadId).get();
      final s = loadSnap.data()?["shipperId"];
      if (s is String && s.trim().isNotEmpty) {
        realShipperId = s.trim();
      }
    }

    if (realShipperId.isEmpty) {
      throw Exception("shipperId bulunamadı.");
    }

    final chatSvc = ChatService();
    final loadRef = _db.collection("loads").doc(loadId);
    final offerRef = _db.collection("offers").doc(offerId);
    final chatId = chatSvc.getChatId(loadId: loadId, driverId: driverId);
    final chatRef = _db.collection("chats").doc(chatId);

    // Aynı ilana ait diğer teklifleri bul
    final othersSnap = await _db.collection("offers").where("loadId", isEqualTo: loadId).get();

    final batch = _db.batch();

    // 1. İlanın durumunu eşleşti yap
    batch.update(loadRef, {
      "acceptedOfferId": offerId,
      "acceptedDriverId": driverId,
      "status": "matched",
      "chatId": chatId,
    });

    // 2. Kabul edilen teklifin durumunu güncelle
    batch.update(offerRef, {"status": "accepted"});

    // 3. Diğer şoförlerin tekliflerini otomatik olarak reddet
    for (final d in othersSnap.docs) {
      if (d.id == offerId) continue;
      batch.update(d.reference, {"status": "rejected"});
    }

    // 4. İki taraf için sohbet odasını hazırla/güncelle
    batch.set(chatRef, {
      "loadId": loadId,
      "shipperId": realShipperId,
      "driverId": driverId,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
      "lastMessage": null,
    }, SetOptions(merge: true));

    // Tüm bu işlemleri tek bir adımda (Transaction gibi) gerçekleştir
    await batch.commit();
  }

  // 1. Şoförün Karşı Teklifi Kabul Etmesi (Mevcut kodun)
  Future<void> acceptCounterOffer(Load load, Offer myOffer) async {
    await _db.runTransaction((tx) async {
      final loadRef = _db.collection("loads").doc(load.id);
      final offerRef = _db.collection("offers").doc(myOffer.id);

      final loadSnap = await tx.get(loadRef);
      if (!loadSnap.exists) throw Exception("İlan bulunamadı");

      final data = loadSnap.data()!;
      final status = (data["status"] ?? "open").toString();
      final acceptedOfferId = data["acceptedOfferId"];

      if (status != "open" && status != "matched") {
        throw Exception("Bu ilan artık uygun değil.");
      }
      if (acceptedOfferId != null && acceptedOfferId.toString().isNotEmpty) {
        throw Exception("Bu ilan başka bir şoförle eşleşmiş.");
      }

      tx.update(offerRef, {"status": "accepted"});
      tx.update(loadRef, {
        "status": "matched",
        "acceptedOfferId": myOffer.id,
        "acceptedDriverId": myOffer.driverId,
      });
    });

    final others = await _db.collection("offers").where("loadId", isEqualTo: load.id).get();
    final batch = _db.batch();
    for (final d in others.docs) {
      if (d.id == myOffer.id) continue;
      batch.update(d.reference, {"status": "rejected"});
    }
    await batch.commit();
  }

  // 2. Şoförün Karşı Teklifi Reddetmesi (Mevcut kodun)
  Future<void> rejectCounterOffer(Offer myOffer) async {
    await _db.collection("offers").doc(myOffer.id).update({
      "status": "driver_rejected_counter",
      "driverRejectedAt": FieldValue.serverTimestamp(),
    });
  }

  // 3. Süresi Geçen İlanı ve Tekliflerini Silme (Mevcut kodun)
  Future<void> deleteLoadWithOffers(String loadId) async {
    final offersSnap = await _db.collection("offers").where("loadId", isEqualTo: loadId).get();
    final batch = _db.batch();
    for (final d in offersSnap.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_db.collection("loads").doc(loadId));
    await batch.commit();
  }
}