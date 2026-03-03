import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PublicProfileScreen extends StatelessWidget {
  final String userId; // Görüntülenecek kişinin ID'si

  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kullanıcı Profili", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🟢 1. KULLANICI BİLGİLERİ VE PUAN KARTI
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection("users").doc(userId).snapshots(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final d = userSnap.data?.data() as Map<String, dynamic>? ?? {};

              String displayName = "İsimsiz Kullanıcı";
              if (d["name"] != null && d["name"].toString().trim().isNotEmpty) {
                displayName = d["name"].toString();
              }

              final avg = (d["ratingAvg"] is num) ? (d["ratingAvg"] as num).toDouble() : 5.0;
              final cnt = (d["ratingCount"] is int) ? d["ratingCount"] as int : 0;
              final firstLetter = displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : "?";

              // Araç tipi varsa gösterelim (Şoförse)
              String vehicleInfo = "";
              if (d["extra"] != null && d["extra"] is Map) {
                vehicleInfo = d["extra"]["vehicleType"] ?? "";
              }

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                      Theme.of(context).colorScheme.primary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Text(
                        firstLetter,
                        style: TextStyle(
                          fontSize: 32,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          if (vehicleInfo.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Araç: $vehicleInfo",
                              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  "${avg.toStringAsFixed(1)} ($cnt Puan)",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text("Değerlendirmeler & Yorumlar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),

          // 🟢 2. YORUMLAR LİSTESİ (YENİ EKLENEN KISIM)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection("ratings").where("toUserId", isEqualTo: userId).snapshots(),
            builder: (context, ratingSnap) {
              if (ratingSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final ratingDocs = ratingSnap.data?.docs.toList() ?? [];

              // Yorumları yeniden eskiye sıralayalım
              ratingDocs.sort((a, b) {
                final ta = (a.data() as Map<String, dynamic>)["createdAt"] as Timestamp? ?? Timestamp.now();
                final tb = (b.data() as Map<String, dynamic>)["createdAt"] as Timestamp? ?? Timestamp.now();
                return tb.compareTo(ta);
              });

              if (ratingDocs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
                  child: Text("Henüz bir yorum yapılmamış.", style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                );
              }

              return Column(
                children: ratingDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final stars = data["stars"] ?? 5;
                  final note = data["note"] ?? "";

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ...List.generate(5, (i) => Icon(
                                i < stars ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 20,
                              )),
                              const Spacer(),
                              // Eğer istersen buraya tarihi de yazdırabilirsin
                            ],
                          ),
                          if (note.toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                                "❝ $note ❞",
                                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade800, fontSize: 14)
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text("Tamamladığı İşler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),

          // 🟢 3. GEÇMİŞ İŞLER LİSTESİ (SADECE "DONE" OLANLAR)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("loads")
                .where(Filter.or(
              Filter("shipperId", isEqualTo: userId),
              Filter("acceptedDriverId", isEqualTo: userId),
            ))
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Center(child: Text("Hata: ${snap.error}"));
              }

              final allDocs = snap.data?.docs ?? [];

              final doneJobs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data["status"] == "done";
              }).toList();

              doneJobs.sort((a, b) {
                final dataA = a.data() as Map<String, dynamic>;
                final dataB = b.data() as Map<String, dynamic>;
                final timeA = dataA["doneAt"] as Timestamp? ?? dataA["createdAt"] as Timestamp?;
                final timeB = dataB["doneAt"] as Timestamp? ?? dataB["createdAt"] as Timestamp?;
                if (timeA == null && timeB == null) return 0;
                if (timeA == null) return 1;
                if (timeB == null) return -1;
                return timeB.compareTo(timeA);
              });

              if (doneJobs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16)
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.history_toggle_off, size: 50, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text("Kullanıcının henüz tamamlanmış bir işi yok.", style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                );
              }

              return Column(
                children: doneJobs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final isDriver = data["acceptedDriverId"] == userId; // Bu kişi bu işte şoför müydü?

                  final fromCity = data["fromCity"] ?? "Bilinmiyor";
                  final toCity = data["toCity"] ?? "Bilinmiyor";
                  final weight = data["weightKg"] ?? "0";

                  String dateStr = "";
                  final doneAt = data["doneAt"] as Timestamp?;
                  if (doneAt != null) {
                    final dt = doneAt.toDate();
                    dateStr = "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}";
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: isDriver ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                        child: Icon(
                          isDriver ? Icons.local_shipping : Icons.outbox,
                          color: isDriver ? Colors.orange : Colors.blue,
                        ),
                      ),
                      title: Text("$fromCity ➔ $toCity", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          isDriver ? "Yük Taşıdı • $weight kg" : "Yük Gönderdi • $weight kg",
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "Tamamlandı",
                              style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (dateStr.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          ]
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}