import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'public_profile_screen.dart';

class ChatsListScreen extends StatelessWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text("Oturum bulunamadı.")));
    }

    return Scaffold(
      backgroundColor: Colors.white, // 🟢 Tamamen temiz beyaz arka plan
      appBar: AppBar(
        title: const Text("Mesajlarım", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("chats")
            .where(Filter.or(
          Filter("shipperId", isEqualTo: uid),
          Filter("driverId", isEqualTo: uid),
        ))
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("Hata: ${snap.error}"));
          }

          final docs = (snap.data?.docs ?? []).toList();

          docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final timeA = dataA["updatedAt"] as Timestamp?;
            final timeB = dataB["updatedAt"] as Timestamp?;
            if (timeA == null && timeB == null) return 0;
            if (timeA == null) return 1;
            if (timeB == null) return -1;
            return timeB.compareTo(timeA);
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 50, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text("Henüz hiç mesajınız yok.", style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 10, bottom: 24),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final chatId = docs[index].id;
              final lastMessage = data["lastMessage"] ?? "Henüz mesaj yok";

              final isMeShipper = data["shipperId"] == uid;

              // 🟢 BOŞLUKLARI TEMİZLEYEREK GÜVENLİ HALE GETİRİYORUZ
              final rawLoadId = (data["loadId"] ?? "").toString().trim();
              final otherUserId = (isMeShipper ? data["driverId"] : data["shipperId"])?.toString().trim() ?? "";

              // 🟢 İŞTE HAYAT KURTARAN KALKAN BURASI! 🛡️
              // Eğer veritabanında eski/bozuk bir veri kalmışsa ve ID'ler boşsa,
              // uygulamayı çökertmek yerine o bozuk satırı ekranda tamamen gizliyoruz.
              if (otherUserId.isEmpty || rawLoadId.isEmpty) {
                return const SizedBox.shrink(); // Hiçbir şey çizmeden atla
              }

              // Eğer ID'ler dolu ve sağlamsa normal bir şekilde Firebase'e git
              return FutureBuilder<List<DocumentSnapshot>>(
                future: Future.wait([
                  FirebaseFirestore.instance.collection("users").doc(otherUserId).get(),
                  FirebaseFirestore.instance.collection("loads").doc(rawLoadId).get(),
                ]),
                builder: (context, snapshot) {

                  String otherUserName = "İsimsiz Kullanıcı";
                  String loadTitle = "Rota Bekleniyor...";

                  if (snapshot.hasData) {
                    final userDoc = snapshot.data![0];
                    final loadDoc = snapshot.data![1];

                    if (userDoc.exists) {
                      final userData = userDoc.data() as Map<String, dynamic>?;
                      if (userData != null && userData.containsKey("name")) {
                        otherUserName = userData["name"];
                      }
                    }

                    if (loadDoc.exists) {
                      final loadData = loadDoc.data() as Map<String, dynamic>?;
                      if (loadData != null) {
                        String originText = loadData["fromCity"] ?? "Bilinmiyor";
                        String destText = loadData["toCity"] ?? "Bilinmiyor";
                        loadTitle = "$originText ➔ $destText";
                      }
                    }
                  }

                  String firstLetter = otherUserName.isNotEmpty ? otherUserName.substring(0, 1).toUpperCase() : "?";

                  // 🟢 Profilindeki "Geçmiş İşler" ile BİREBİR Aynı Tasarım Stili
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200), // İnce zarif çerçeve
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatScreen(
                            chatId: chatId,
                            userName: otherUserName,
                            otherUserId: otherUserId, // 🟢 YENİ EKLENDİ
                          )),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            // 🟢 Profildeki gibi şık pastel kutulu Avatar
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: otherUserId)),
                                );
                              },
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: isMeShipper ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    firstLetter,
                                    style: TextStyle(
                                      color: isMeShipper ? Colors.blue.shade700 : Colors.orange.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // 🟢 Orta Kısım
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          otherUserName,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        loadTitle,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: lastMessage == "Henüz mesaj yok" ? Colors.grey.shade400 : Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 4),

                            // 🟢 YENİ EKLENEN: SOHBET SİLME BUTONU
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              tooltip: "Sohbeti Sil",
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text("Sohbeti Sil"),
                                    content: const Text("Bu mesajlaşmayı kalıcı olarak silmek istediğinize emin misiniz?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text("Vazgeç"),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text("Sil"),
                                      ),
                                    ],
                                  ),
                                );

                                if (ok == true) {
                                  try {
                                    // Firebase'den sohbet odasını sil
                                    await FirebaseFirestore.instance.collection("chats").doc(chatId).delete();

                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Sohbet başarıyla silindi ✅")),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Silme hatası: $e")),
                                    );
                                  }
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right, color: Colors.grey.shade300),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}