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

  Future<void> _hydrateAppStateFromFirestore(User user) async {
    // users/{uid} profilini oku ve appState'i doldur
    final data = await AuthService().getProfileByUid(user.uid);

    final role = (data['role'] ?? '').toString();
    final name = (data['name'] ?? 'Kullanıcı').toString();

    // Rol valid değilse güvenlik için logout
    if (role != 'driver' && role != 'shipper') {
      await AuthService().logout();
      appState.logout();
      return;
    }

    appState.setRole(role);
    appState.login(name: name);
    await NotificationService.syncTokenToUser();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LoadShare V1',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF7F7FB),

        appBarTheme: const AppBarTheme(
          centerTitle: false,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          // Auth beklerken
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snap.data;

          // Oturum yoksa
          if (user == null) {
            // RAM temiz
            if (appState.isLoggedIn) appState.logout();
            return const RoleSelectScreen();
          }

          // Oturum varsa -> profil çekip appState'i doldur
          return FutureBuilder<void>(
            future: _hydrateAppStateFromFirestore(user),
            builder: (context, fsnap) {
              if (fsnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              // AppState dolduysa
              if (!appState.isLoggedIn) {
                // Profil hatalı/eksikse rol seçime gönder
                return const RoleSelectScreen();
              }

              return const AppShell();
            },
          );
        },
      ),
    );
  }
}