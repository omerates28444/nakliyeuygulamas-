import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_state.dart';
import 'screens/role_select_screen.dart';
import 'screens/app_shell.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 🟢 ÇÖZÜM 1: appState değiştiğinde tüm uygulamanın haberi olması için ListenableBuilder ekledik.
    return ListenableBuilder(
      listenable: appState,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'LogiMap', // 🟢 Marka adını LogiMap olarak düzelttik

          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.indigo,
            scaffoldBackgroundColor: const Color(0xFFF7F7FB),
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              titleTextStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            dividerTheme: const DividerThemeData(thickness: 1),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),

          // 🟢 ÇÖZÜM 2: Doğrudan StreamBuilder/FutureBuilder kullanmak yerine AuthGate widget'ına yönlendirdik
          home: const AuthGate(),
        );
      },
    );
  }
}

// 🟢 ÇÖZÜM 2 DETAY: Stateful yapı sayesinde Future(veri çekme) işlemini sadece 1 KERE yapıyoruz (Maliyet Optimizasyonu)
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<void>? _profileFuture;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    // Oturum durumunu dinliyoruz
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          if (user != null) {
            // Kullanıcı giriş yaptıysa Firestore'dan bilgileri çek (YALNIZCA 1 KEZ)
            _profileFuture = _hydrateAppStateFromFirestore(user);
          } else {
            // Kullanıcı çıkış yaptıysa state'i sıfırla
            _profileFuture = null;
            if (appState.isLoggedIn) appState.logout();
          }
        });
      }
    });
  }

  Future<void> _hydrateAppStateFromFirestore(User user) async {
    try {
      final data = await AuthService().getProfileByUid(user.uid);

      final role = (data['role'] ?? '').toString();
      final name = (data['name'] ?? 'Kullanıcı').toString();

      if (role != 'driver' && role != 'shipper') {
        await AuthService().logout();
        appState.logout();
        return;
      }

      int? capacity;
      if (role == 'driver' && data['extra'] != null) {
        capacity = (data['extra']['capacityKg'] as num?)?.toInt();
      }

      appState.setRole(role);
      appState.login(name: name, capacity: capacity);

    } catch (e) {
      debugPrint("🔥 OTOMATİK GİRİŞ HATASI: $e");
      await AuthService().logout();
      appState.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Durum: Hiç giriş yapılmamış
    if (_currentUser == null) {
      return const RoleSelectScreen();
    }

    // 2. Durum: Giriş yapılmış ama Firestore'dan profil bekleniyor
    return FutureBuilder<void>(
      future: _profileFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 3. Durum: Profil çekilirken hata oluştuysa veya rol atanamadıysa
        if (snap.hasError || !appState.isLoggedIn) {
          return const RoleSelectScreen();
        }

        // 4. Durum: Her şey başarılı, ana harita ekranına (AppShell) yönlendir
        return const AppShell();
      },
    );
  }
}