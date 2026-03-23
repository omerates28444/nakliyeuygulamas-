
class Load {
  final String id;
  final String fromCity;
  final String toCity;
  final DateTime pickupDate;
  final int weightKg;
  final String priceType; // "fixed" | "offer"
  final int? fixedPrice;
  final String status; // "open" | "matched" | "done"
  final double? fromLat;
  final double? fromLng;

  // ✅ yeni alanlar
  final String? shipperId;
  final String? shipperName;
  final String? acceptedOfferId;
  final String? acceptedDriverId;

  Load({
    required this.id,
    required this.fromCity,
    required this.toCity,
    required this.pickupDate,
    required this.weightKg,
    required this.priceType,
    this.fixedPrice,
    this.status = "open",
    this.fromLat,
    this.fromLng,
    this.shipperId,
    this.shipperName,
    this.acceptedOfferId,
    this.acceptedDriverId,
  });

  // ✅ Supabase Map -> Load
  factory Load.fromMap(Map<String, dynamic> d) {
    return Load(
      id: d['id'].toString(),
      fromLat: (d['fromLat'] as num?)?.toDouble(),
      fromLng: (d['fromLng'] as num?)?.toDouble(),
      fromCity: (d['fromCity'] ?? '').toString(),
      toCity: (d['toCity'] ?? '').toString(),
      pickupDate: d['pickupDate'] != null ? DateTime.parse(d['pickupDate'].toString()) : DateTime.now(),
      weightKg: (d['weightKg'] as num?)?.toInt() ?? 0,
      priceType: (d['priceType'] ?? 'offer').toString(),
      fixedPrice: d['fixedPrice'] == null ? null : (d['fixedPrice'] as num).toInt(),
      status: (d['status'] ?? 'open').toString(),
      shipperId: d['shipperId']?.toString(),
      shipperName: d['shipperName']?.toString(),
      acceptedOfferId: d['acceptedOfferId']?.toString(),
      acceptedDriverId: d['acceptedDriverId']?.toString(),
    );
  }

  // ✅ Load -> Map
  Map<String, dynamic> toMap() {
    return {
      'fromLat': fromLat,
      'fromLng': fromLng,
      'fromCity': fromCity,
      'toCity': toCity,
      'pickupDate': pickupDate.toUtc().toIso8601String(),
      'weightKg': weightKg,
      'priceType': priceType,
      'fixedPrice': fixedPrice,
      'status': status,
      'shipperId': shipperId,
      'shipperName': shipperName,
      'acceptedOfferId': acceptedOfferId,
      'acceptedDriverId': acceptedDriverId,
    };
  }

  Load copyWith({
    String? id,
    String? fromCity,
    String? toCity,
    DateTime? pickupDate,
    int? weightKg,
    String? priceType,
    int? fixedPrice,
    String? status,
    String? shipperId,
    String? shipperName,
    String? acceptedOfferId,
    String? acceptedDriverId,
  }) {
    return Load(
      id: id ?? this.id,
      fromCity: fromCity ?? this.fromCity,
      toCity: toCity ?? this.toCity,
      pickupDate: pickupDate ?? this.pickupDate,
      weightKg: weightKg ?? this.weightKg,
      priceType: priceType ?? this.priceType,
      fixedPrice: fixedPrice ?? this.fixedPrice,
      status: status ?? this.status,
      shipperId: shipperId ?? this.shipperId,
      shipperName: shipperName ?? this.shipperName,
      acceptedOfferId: acceptedOfferId ?? this.acceptedOfferId,
      acceptedDriverId: acceptedDriverId ?? this.acceptedDriverId,
    );
  }
}