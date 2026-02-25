import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoadService {
  final FirebaseFirestore db;
  LoadService({FirebaseFirestore? db}) : db = db ?? FirebaseFirestore.instance;

  Future<void> markDelivered({required String loadId}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("Oturum yok");

    final ref = db.collection("loads").doc(loadId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) throw Exception("İlan bulunamadı");

    if ((data["acceptedDriverId"] ?? "") != uid) {
      throw Exception("Bu işi bitirme yetkin yok");
    }

    final status = (data["status"] ?? "").toString();
    if (status == "done") return;

    await ref.update({
      "status": "delivered_pending",
      "deliveredAt": FieldValue.serverTimestamp(),
      "deliveredByDriverId": uid,
    });
  }

  Future<void> cancelJobByDriver({required String loadId}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("Oturum yok");

    final ref = db.collection("loads").doc(loadId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) throw Exception("İlan bulunamadı");

    if ((data["acceptedDriverId"] ?? "") != uid) {
      throw Exception("Bu işi iptal etme yetkin yok");
    }

    // 1) İşi tekrar open yap
    await ref.update({
      "status": "open",
      "acceptedOfferId": FieldValue.delete(),
      "acceptedDriverId": FieldValue.delete(),
    });

    // 2) O işe ait tüm teklifleri sil -> şoför(ler) tekrar sıfırdan teklif verebilsin
    final offers = await db.collection("offers").where("loadId", isEqualTo: loadId).get();
    final batch = db.batch();
    for (final d in offers.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }
}