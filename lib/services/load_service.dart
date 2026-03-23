import 'package:supabase_flutter/supabase_flutter.dart';

class LoadService {
  final SupabaseClient db;
  LoadService({SupabaseClient? db}) : db = db ?? Supabase.instance.client;

  Future<void> markDelivered({required String loadId}) async {
    final uid = db.auth.currentUser?.id;
    if (uid == null) throw Exception("Oturum yok");

    final data = await db.from('loads').select().eq('id', loadId).maybeSingle();
    if (data == null) throw Exception("İlan bulunamadı");

    if ((data["acceptedDriverId"] ?? "") != uid) {
      throw Exception("Bu işi bitirme yetkin yok");
    }

    final status = (data["status"] ?? "").toString();
    if (status == "done") return;

    await db.from('loads').update({
      "status": "delivered_pending",
      "deliveredAt": DateTime.now().toUtc().toIso8601String(),
      "deliveredByDriverId": uid,
    }).eq('id', loadId);
  }

  Future<void> cancelJobByDriver({required String loadId}) async {
    final uid = db.auth.currentUser?.id;
    if (uid == null) throw Exception("Oturum yok");

    final data = await db.from('loads').select().eq('id', loadId).maybeSingle();
    if (data == null) throw Exception("İlan bulunamadı");

    if ((data["acceptedDriverId"] ?? "") != uid) {
      throw Exception("Bu işi iptal etme yetkin yok");
    }

    // 1) İşi tekrar open yap
    await db.from('loads').update({
      "status": "open",
      "acceptedOfferId": null,
      "acceptedDriverId": null,
    }).eq('id', loadId);

    // 2) O işe ait tüm teklifleri sil -> şoför(ler) tekrar sıfırdan teklif verebilsin
    await db.from('offers').delete().eq('loadId', loadId);
  }
}