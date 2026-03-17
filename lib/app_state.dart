import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  bool isLoggedIn = false;
  String role = ""; // "driver" | "shipper" | "admin"
  String displayName = "";
  bool isAdmin = false;
  
  // ✅ Dil seçeneği: "tr" | "en"
  String language = "tr";

  // Adminin o an hangi modda olduğunu belirler
  String adminViewRole = "shipper"; // "driver" | "shipper"

  void setRole(String newRole) {
    role = newRole;
    notifyListeners();
  }

  void setLanguage(String lang) {
    language = lang;
    notifyListeners();
  }

  void toggleAdminRole() {
    if (!isAdmin) return;
    adminViewRole = (adminViewRole == "shipper") ? "driver" : "shipper";
    notifyListeners();
  }

  void login({required String name, bool admin = false}) {
    displayName = name.trim().isEmpty ? "Kullanıcı" : name.trim();
    isLoggedIn = true;
    isAdmin = admin;
    if (admin) {
      role = "admin";
      adminViewRole = "shipper"; 
    }
    notifyListeners();
  }

  void logout() {
    isLoggedIn = false;
    displayName = "";
    role = "";
    isAdmin = false;
    notifyListeners();
  }
}

final appState = AppState();