import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';

class ChatsListScreen extends StatelessWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text("Oturum bulunamadı.")));
    }

    return Scaffold(
        appBar: AppBar(
          title: const Text("Mesajlarım"),
        ),
        body: StreamBuilder<QuerySnapshot>(
        // Filter.or ile hem şoför hem de yük sahibi olduğumuz sohbetleri çekiyoruz
        // (Sıralamayı .orderBy ile yapmıyoruz ki Firebase Index hatası vermesin)
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

    // Firestore'dan gelen veriyi List'e çeviriyoruz
    final docs = (snap.data?.docs ?? []).toList();

    // Firebase Index hatasından kaçmak için sıralamayı Dart tarafında (telefonda) yapıyoruz
    docs.sort((a, b) {
    final dataA = a.data() as Map<String, dynamic>;
    final dataB = b.data() as Map<String, dynamic>;
    final timeA = dataA["updatedAt"] as Timestamp?;
    final timeB = dataB["updatedAt"] as Timestamp?;
    if (timeA == null && timeB == null) return 0;
    if (timeA == null) return 1;
    if (timeB == null) return -1;
    return timeB.compareTo(timeA); // En yeni mesaj en üstte
    });

    if (docs.isEmpty) {
    return const Center(child: Text("Henüz hiç mesajınız yok."));
    }

    return ListView.builder(
    itemCount: docs.length,
    itemBuilder: (context, index) {
    final data = docs[index].data() as Map<String, dynamic>;
    final chatId = docs[index].id;
    final lastMessage = data["lastMessage"] ?? "Mesaj gönderilmedi";

    // Rolümüzü belirliyoruz
    final isMeShipper = data["shipperId"] == uid;

    // Karmaşık ID'yi kısaltıp daha güzel bir İlan Numarası (Örn: #PH4SV) yapalım
    final rawLoadId = data["loadId"] ?? "Bilinmiyor";
    final shortLoadId = rawLoadId.length > 5 ? rawLoadId.substring(0, 5).toUpperCase() : rawLoadId;

    // Karşı tarafın ID'sini buluyoruz
    final otherUserId = isMeShipper ? data["driverId"] : data["shipperId"];

    // Karşı tarafın adını 'users' tablosundan anlık çekiyoruz
    return FutureBuilder<DocumentSnapshot>(
    future: FirebaseFirestore.instance.collection("users").doc(otherUserId).get(),
    builder: (context, userSnap) {

    // Varsayılan isim (Yüklenirken veya kullanıcı silinmişse bu yazar)
    String otherUserName = isMeShipper ? "Şoför (Yükleniyor...)" : "Yük Sahibi (Yükleniyor...)";

    if (userSnap.hasData && userSnap.data!.exists) {
    final userData = userSnap.data!.data() as Map<String, dynamic>?;
    if (userData != null && userData.containsKey("name")) {
    otherUserName = userData["name"];
    }
    }

    // İsmin baş harfini güvenli bir şekilde alıyoruz (İsim boşsa "?" koyar)
    String firstLetter = otherUserName.isNotEmpty
    ? otherUserName.substring(0, 1).toUpperCase()
        : "?";

    return Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    elevation: 1,
    shape: RoundedRectangleBorder(
    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
    borderRadius: BorderRadius.circular(16),
    ),
    child: InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)),
    );
    },
    child: Padding(
    padding: const EdgeInsets.all(12.0),
    child: Row(
    children: [
    // Sol Taraftaki İkon (Avatar) - İsmin baş harfi
    CircleAvatar(
    radius: 26,
    backgroundColor: isMeShipper
    ? Colors.blue.withOpacity(0.1)
        : Colors.orange.withOpacity(0.1),
    child: Text(
    firstLetter,
    style: TextStyle(
    color: isMeShipper ? Colors.blue : Colors.orange,
    fontWeight: FontWeight.bold,
    fontSize: 20,
    ),
    ),
    ),
    const SizedBox(width: 16),

    // Orta Kısım (Başlık ve Mesaj)
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
    // İsim (Çok uzunsa ekrandan taşmasın diye Expanded ve ellipsis kullanıldı)
    Expanded(
    child: Text(
    otherUserName,
    style: const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 16,
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    ),
    ),
    const SizedBox(width: 8),
    // Kısa İlan Numarası
    Text(
    "#$shortLoadId",
    style: TextStyle(
    fontSize: 12,
    color: Colors.grey.shade500,
    fontWeight: FontWeight.w600,
    ),
    ),
    ],
    ),
    const SizedBox(height: 6),
    // Son Mesaj Metni
    Text(
    lastMessage,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
    fontSize: 14,
    color: lastMessage == "Mesaj gönderilmedi"
    ? Colors.grey.shade400
        : Colors.black87,
    fontStyle: lastMessage == "Mesaj gönderilmedi"
    ? FontStyle.italic
        : FontStyle.normal,
    ),
    ),
    ],
    ),
    ),

    // Sağ Ok İkonu
      const SizedBox(width: 8),
      Icon(Icons.chevron_right, color: Colors.grey.shade400),
    ],
    ), // Row bitişi
    ), // Padding bitişi
    ), // InkWell bitişi
    ); // Card bitişi
    }, // FutureBuilder builder bitişi
    ); // FutureBuilder bitişi
    }, // ListView itemBuilder bitişi
    ); // return ListView.builder bitişi
    }, // StreamBuilder builder bitişi
        ), // StreamBuilder gövde bitişi
    ); // return Scaffold bitişi
  } // build metodu bitişi
} // ChatsListScreen sınıfı bitişi