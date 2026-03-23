import 'package:flutter/material.dart';
import '../app_state.dart';
import 'osm_map_home_screen.dart';
import 'admin_dashboard_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Uygulamadan çıkılsın mı?"),
            content: const Text("Çıkmak istiyor musun?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Hayır"),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Evet, çık"),
              ),
            ],
          ),
        );

        if (ok == true) {
          // ignore: use_build_context_synchronously
          Navigator.of(context).pop();
        }
      },
      child: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          // ✅ Adminse direkt Dashboard'a, değilse Haritaya
          if (appState.isAdmin) {
            return const AdminDashboardScreen();
          }
          return const OsmMapHomeScreen();
        },
      ),
    );
  }
}