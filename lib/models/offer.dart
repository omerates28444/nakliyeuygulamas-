import 'package:cloud_firestore/cloud_firestore.dart';

class Offer {
  final String id;
  final String loadId;
  final String driverId;
  final String driverName;
  final int price;
  final String note;
  final String status; // sent | countered | accepted | rejected | driver_rejected_counter
  final int? counterPrice;
  final String? counterNote;

  Offer({
    required this.id,
    required this.loadId,
    required this.driverId,
    required this.driverName,
    required this.price,
    required this.note,
    required this.status,
    this.counterPrice,
    this.counterNote,
  });

  factory Offer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return Offer(
      id: doc.id,
      loadId: (data["loadId"] ?? "").toString(),
      driverId: (data["driverId"] ?? "").toString(),
      driverName: (data["driverName"] ?? "").toString(),
      price: (data["price"] is int) ? data["price"] as int : int.tryParse("${data["price"]}") ?? 0,
      note: (data["note"] ?? "").toString(),
      status: (data["status"] ?? "sent").toString(),
      counterPrice: (data["counterPrice"] == null)
          ? null
          : ((data["counterPrice"] is int)
          ? data["counterPrice"] as int
          : int.tryParse("${data["counterPrice"]}")),
      counterNote: data["counterNote"]?.toString(),
    );
  }

  // 🟢 YENİ EKLENEN: Veritabanına yazmak için toMap fonksiyonu
  Map<String, dynamic> toMap() {
    return {
      'loadId': loadId,
      'driverId': driverId,
      'driverName': driverName,
      'price': price,
      'note': note,
      'status': status,
      if (counterPrice != null) 'counterPrice': counterPrice,
      if (counterNote != null) 'counterNote': counterNote,
    };
  }

  // 🟢 YENİ EKLENEN: Mevcut objeyi kopyalayıp sadece belli alanlarını değiştirmek için
  Offer copyWith({
    String? id,
    String? loadId,
    String? driverId,
    String? driverName,
    int? price,
    String? note,
    String? status,
    int? counterPrice,
    String? counterNote,
  }) {
    return Offer(
      id: id ?? this.id,
      loadId: loadId ?? this.loadId,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      price: price ?? this.price,
      note: note ?? this.note,
      status: status ?? this.status,
      counterPrice: counterPrice ?? this.counterPrice,
      counterNote: counterNote ?? this.counterNote,
    );
  }
}