import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  bool isLoggedIn = false;
  String role = ""; // "driver" | "shipper"
  String displayName = "";

  void setRole(String newRole) {
    role = newRole;
    notifyListeners();
  }

  void login({required String name}) {
    displayName = name.trim().isEmpty ? "Kullanıcı" : name.trim();
    isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    isLoggedIn = false;
    displayName = "";
    role = "";
    notifyListeners();
  }
}

final appState = AppState();