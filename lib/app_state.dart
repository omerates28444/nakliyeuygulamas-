import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  bool isLoggedIn = false;
  String role = ""; // "driver" | "shipper"
  String displayName = "";

  // 🟢 YENİ EKLENEN: Şoförün araç kapasitesi
  int? capacityKg;

  void setRole(String newRole) {
    role = newRole;
    notifyListeners();
  }

  // 🟢 YENİ EKLENEN: Kapasiteyi ayarlama fonksiyonu
  void setCapacity(int capacity) {
    capacityKg = capacity;
    notifyListeners();
  }

  void login({required String name, int? capacity}) {
    displayName = name.trim().isEmpty ? "Kullanıcı" : name.trim();
    isLoggedIn = true;
    capacityKg = capacity; // Login olurken kapasite de set edilebilir
    notifyListeners();
  }

  void logout() {
    isLoggedIn = false;
    displayName = "";
    role = "";
    capacityKg = null; // 🟢 Çıkış yapınca kapasiteyi de sıfırla
    notifyListeners();
  }
}

final appState = AppState();