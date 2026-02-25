import '../models/load.dart';
import '../models/vehicle.dart';

class MatchResult {
  final Load load;
  final int score;
  final List<String> reasons;

  MatchResult({required this.load, required this.score, required this.reasons});
}

class MatchService {
  /// V1 "AI" = kurallı skor sistemi (0-100)
  static MatchResult scoreLoad({
    required Load load,
    required Vehicle vehicle,
  }) {
    int score = 0;
    final reasons = <String>[];

    // 1) Rota uyumu (0-40)
    // Şimdilik basit: aynı şehir çifti -> yüksek puan
    // (sonra yakın şehir, otoyol sapma vb. ekleriz)
    final routeScore = 40; // v1: tüm yükler "rota adayı" kabul
    score += routeScore;
    reasons.add("Rota adayı (+$routeScore)");

    // 2) Kapasite uyumu (0-30)
    if (load.weightKg <= vehicle.capacityKg) {
      score += 30;
      reasons.add("Kapasite uygun (+30)");
    } else {
      reasons.add("Kapasite yetersiz (+0)");
    }

    // 3) Zaman uyumu (0-20)
    // V1: pickupDate bugünden sonraysa uygun say
    final now = DateTime.now();
    if (load.pickupDate.isAfter(DateTime(now.year, now.month, now.day))) {
      score += 20;
      reasons.add("Zaman uygun (+20)");
    } else {
      reasons.add("Zaman riskli (+0)");
    }

    // 4) Bonus (0-10) (V1: sabit 0)
    // V2: sürücü puanı, iptal oranı vb.
    // score += 0;

    // 0-100 arası sabitle
    if (score > 100) score = 100;
    if (score < 0) score = 0;

    return MatchResult(load: load, score: score, reasons: reasons);
  }

  static List<MatchResult> rankLoads({
    required List<Load> loads,
    required Vehicle vehicle,
  }) {
    final results = loads.map((l) => scoreLoad(load: l, vehicle: vehicle)).toList();
    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }
}
