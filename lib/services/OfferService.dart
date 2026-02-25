import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/load.dart';
import '../models/offer.dart';

class OfferService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Şoförün Karşı Teklifi Kabul Etmesi
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

    // Diğer teklifleri reddet
    final others = await _db.collection("offers").where("loadId", isEqualTo: load.id).get();
    final batch = _db.batch();
    for (final d in others.docs) {
      if (d.id == myOffer.id) continue;
      batch.update(d.reference, {"status": "rejected"});
    }
    await batch.commit();
  }

  // 2. Şoförün Karşı Teklifi Reddetmesi
  Future<void> rejectCounterOffer(Offer myOffer) async {
    await _db.collection("offers").doc(myOffer.id).update({
      "status": "driver_rejected_counter",
      "driverRejectedAt": FieldValue.serverTimestamp(),
    });
  }

  // 3. Süresi Geçen İlanı ve Tekliflerini Silme
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