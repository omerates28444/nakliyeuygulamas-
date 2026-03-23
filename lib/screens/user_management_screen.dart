import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isEn = appState.language == "en";
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? "User Management" : "Kullanıcı Yönetimi"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection("users").orderBy("createdAt", descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Hata: ${snap.error}"));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return Center(child: Text(isEn ? "No users found." : "Kullanıcı bulunamadı."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final uid = docs[index].id;
              final name = data["name"] ?? "İsimsiz";
              final role = data["role"] ?? "user";
              final isVerified = data["isVerified"] ?? false;
              final email = data["email"] ?? "-";

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: role == "driver" ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    child: Icon(
                      role == "driver" ? Icons.local_shipping : Icons.person,
                      color: role == "driver" ? Colors.blue : Colors.orange,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (isVerified)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.verified, color: Colors.blue, size: 16),
                        ),
                    ],
                  ),
                  subtitle: Text("$email\nRole: ${role.toUpperCase()}"),
                  isThreeLine: true,
                  trailing: role == "driver" && !isVerified
                      ? FilledButton(
                          onPressed: () => _verifyUser(context, uid, name),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(isEn ? "Approve" : "Onayla"),
                        )
                      : (isVerified 
                          ? Text(isEn ? "Verified" : "Onaylı", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                          : null),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _verifyUser(BuildContext context, String uid, String name) async {
    try {
      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "isVerified": true,
        "verifiedAt": FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$name onaylandı ✅")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e")),
        );
      }
    }
  }
}