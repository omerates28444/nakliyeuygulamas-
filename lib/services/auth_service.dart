import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String role,
    required String phone,
    required String city,
    Map<String, dynamic>? extra,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final uid = cred.user!.uid;

    await _db.collection('users').doc(uid).set({
      'name': name.trim(),
      'role': role,
      'email': email.trim(),
      'phone': phone.trim(),
      'city': city.trim(),
      'extra': extra ?? {},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final uid = cred.user!.uid;

    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data();

    if (data == null) {
      throw Exception("Firestore'da kullanıcı profili bulunamadı: users/$uid");
    }

    return data;
  }

  // ✅ YENİ: UID ile profil çek (app açılışında otomatik login için)
  Future<Map<String, dynamic>> getProfileByUid(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data();
    if (data == null) {
      throw Exception("Firestore'da kullanıcı profili bulunamadı: users/$uid");
    }
    return data;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}