import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String role,
    required String phone,
    required String city,
    Map<String, dynamic>? extra,
  }) async {
    final res = await _supabase.auth.signUp(
      email: email.trim(),
      password: password.trim(),
    );

    final user = res.user;
    if (user == null) {
      throw Exception("Kayıt işlemi başarısız.");
    }
    
    final uid = user.id;

    await _supabase.from('users').insert({
      'id': uid,
      'name': name.trim(),
      'role': role,
      'email': email.trim(),
      'phone': phone.trim(),
      'city': city.trim(),
      'extra': extra ?? {},
    });
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = res.user;
    if (user == null) {
      throw Exception("Giriş işlemi başarısız.");
    }

    final uid = user.id;

    final data = await _supabase.from('users').select().eq('id', uid).maybeSingle();

    if (data == null) {
      throw Exception("Supabase'de kullanıcı profili bulunamadı: users/$uid");
    }

    return data;
  }

  Future<Map<String, dynamic>> getProfileByUid(String uid) async {
    final data = await _supabase.from('users').select().eq('id', uid).maybeSingle();
    
    if (data == null) {
      throw Exception("Supabase'de kullanıcı profili bulunamadı: users/$uid");
    }
    return data;
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
}