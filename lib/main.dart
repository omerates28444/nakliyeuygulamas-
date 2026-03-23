import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'screens/role_select_screen.dart';
import 'screens/app_shell.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://nkafkqugrkaocpqbyxfc.supabase.co',
    anonKey: 'sb_publishable_cWS9qgD8XL3J0WhZmVZIrQ_mr5CukNU',
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<void> _hydrateAppStateFromFirestore(User user) async {
    // users tablosundan profilini oku ve appState'i doldur
    final data = await AuthService().getProfileByUid(user.id);

    final role = (data['role'] ?? '').toString();
    final name = (data['name'] ?? 'Kullanıcı').toString();

    // Rol valid değilse güvenlik için logout
    if (role != 'driver' && role != 'shipper' && role != 'admin') {
      await AuthService().logout();
      appState.logout();
      return;
    }

    appState.setRole(role);
    appState.login(name: name, admin: role == 'admin');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RoadMap',
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
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final authState = snap.data;
          final user = authState?.session?.user;

          if (user == null) {
            if (appState.isLoggedIn) appState.logout();
            return const RoleSelectScreen();
          }

          return FutureBuilder<void>(
            future: _hydrateAppStateFromFirestore(user),
            builder: (context, fsnap) {
              if (fsnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (!appState.isLoggedIn) {
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