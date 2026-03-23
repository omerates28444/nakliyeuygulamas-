
class Offer {
  final String id;
  final String loadId;

  final String driverId;
  final String driverName;

  final int price;
  final String note;

  final String status; // sent | countered | accepted | rejected

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

  factory Offer.fromMap(Map<String, dynamic> data) {
    return Offer(
      id: data['id'].toString(),
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
}