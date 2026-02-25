import 'dart:math';

class GeoService {
  static const Map<String, (double, double)> _cityLatLon = {
    "istanbul": (41.0082, 28.9784),
    "ankara": (39.9334, 32.8597),
    "izmir": (38.4237, 27.1428),
    "bursa": (40.1950, 29.0600),
    "antalya": (36.8969, 30.7133),
    "konya": (37.8746, 32.4932),
    "adana": (37.0000, 35.3213),
    "mersin": (36.8121, 34.6415),
    "gaziantep": (37.0662, 37.3833),
    "kayseri": (38.7225, 35.4875),
    "samsun": (41.2867, 36.3300),
    "trabzon": (41.0015, 39.7178),
    "diyarbakir": (37.9144, 40.2306),
    "eskisehir": (39.7767, 30.5206),
    "kocaeli": (40.8533, 29.8815),
    "sakarya": (40.7569, 30.3783),
    "tekirdag": (40.9780, 27.5110),
    "denizli": (37.7765, 29.0864),
    "manisa": (38.6191, 27.4289),
    "balikesir": (39.6484, 27.8826),
    "aydin": (37.8444, 27.8458),
    "mugla": (37.2153, 28.3636),
    "sivas": (39.7500, 37.0161),
    "erzurum": (39.9043, 41.2679),
    "van": (38.4942, 43.3830),
    "malatya": (38.3552, 38.3095),
    "sanliurfa": (37.1674, 38.7955),
    "hatay": (36.2020, 36.1613),
  };

  static String normalizeCity(String input) {
    var s = input.trim().toLowerCase();

    const map = {"ı": "i", "ş": "s", "ğ": "g", "ü": "u", "ö": "o", "ç": "c"};

    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      buf.write(map[ch] ?? ch);
    }

    s = buf.toString();
    s = s.replaceAll('\u0307', '');
    s = s.replaceAll(RegExp(r"\s+"), " ");
    return s;
  }

  static (double, double)? getLatLon(String city) {
    return _cityLatLon[normalizeCity(city)];
  }

  static double distanceKmBetweenCities(String a, String b) {
    final aa = getLatLon(a);
    final bb = getLatLon(b);
    if (aa == null || bb == null) return double.nan;
    return _haversineKm(aa.$1, aa.$2, bb.$1, bb.$2);
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = pow(sin(dLat / 2), 2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * pow(sin(dLon / 2), 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _degToRad(double deg) => deg * pi / 180.0;
}