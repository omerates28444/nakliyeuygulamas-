import 'package:latlong2/latlong.dart';

class AppData {
  /// 🔸 Geçici DEMO koordinatlar
  /// Firestore'a her yük için lat/lng eklediğimizde bunu da kaldıracağız.
  ///
  /// Not: Şu an OsmMapHomeScreen'de pin basmak için
  /// load.id -> jobPoints[load.id] eşleşmesi kullanılıyor.
  static final Map<String, LatLng> jobPoints = {
    // İstersen şimdilik örnek bırakabilirsin:
    // "L1": LatLng(41.015, 28.979),
    // "L2": LatLng(40.802, 29.430),
  };
}