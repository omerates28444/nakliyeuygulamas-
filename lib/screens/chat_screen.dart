import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String userName;
  final String? otherUserId;

  const ChatScreen({
    super.key,
    required this.chatId,
    this.otherUserId,
    this.userName = "Sohbet",
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _msgController = TextEditingController();
  final uid = FirebaseAuth.instance.currentUser?.uid;

  // 🟢 AKILLI SİSTEM DEĞİŞKENLERİ
  String? _resolvedOtherUserId;
  String _resolvedUserName = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setStatus(true);

    // Başlangıçta widget'tan gelenleri al
    _resolvedOtherUserId = widget.otherUserId;
    _resolvedUserName = widget.userName;

    // 🟢 EĞER ID GELMEDİYSE (Haritadan girildiyse), KENDİ KENDİNE BUL!
    if (_resolvedOtherUserId == null) {
      _resolvedUserName = "Yükleniyor...";
      _fetchMissingDetails();
    }
  }

  // 🟢 AKILLI BULUCU FONKSİYON
  Future<void> _fetchMissingDetails() async {
    if (uid == null) return;
    try {
      // 1. Önce bu sohbet odasına bak (Kim kiminle konuşuyor?)
      final chatSnap = await FirebaseFirestore.instance.collection("chats").doc(widget.chatId).get();
      if (chatSnap.exists) {
        final data = chatSnap.data()!;
        final shipperId = data["shipperId"];
        final driverId = data["driverId"];

        // Karşı tarafın kim olduğunu hesapla (Ben shipper isem o driver'dır)
        final calculatedOtherId = (uid == shipperId) ? driverId : shipperId;

        // 2. Şimdi gidip o kişinin adını bul
        final userSnap = await FirebaseFirestore.instance.collection("users").doc(calculatedOtherId).get();
        if (userSnap.exists && mounted) {
          setState(() {
            _resolvedOtherUserId = calculatedOtherId;
            _resolvedUserName = userSnap.data()?["name"] ?? "Kullanıcı";
          });
        }
      }
    } catch (e) {
      debugPrint("Eksik detaylar bulunamadı: $e");
      if (mounted) setState(() => _resolvedUserName = "Sohbet");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setStatus(false);
    _msgController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setStatus(true);
    } else {
      _setStatus(false);
    }
  }

  Future<void> _setStatus(bool isOnline) async {
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "isOnline": isOnline,
        "lastSeen": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Durum güncellenemedi: $e");
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || uid == null) return;

    _msgController.clear();

    try {
      await FirebaseFirestore.instance
          .collection("chats")
          .doc(widget.chatId)
          .collection("messages")
          .add({
        "text": text,
        "senderId": uid,
        "createdAt": FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection("chats").doc(widget.chatId).update({
        "lastMessage": text,
        "updatedAt": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Mesaj gönderme hatası: $e");
    }
  }

  String _formatLastSeen(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final now = DateTime.now();
    final dt = timestamp.toDate();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return "Az önce görüldü";

    if (now.day == dt.day && now.month == dt.month && now.year == dt.year) {
      return "Bugün ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
    if (now.difference(dt).inDays == 1 && now.day != dt.day) {
      return "Dün ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) return const Scaffold(body: Center(child: Text("Oturum bulunamadı.")));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        // 🟢 ARTIK AKILLI DEĞİŞKENLERİ (_resolvedOtherUserId) KULLANIYORUZ
        title: _resolvedOtherUserId == null
            ? Text(_resolvedUserName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87))
            : StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection("users").doc(_resolvedOtherUserId).snapshots(),
          builder: (context, snap) {
            String statusText = "";
            Color statusColor = Colors.grey.shade500;
            bool isOnline = false;

            if (snap.hasData && snap.data!.exists) {
              final data = snap.data!.data() as Map<String, dynamic>? ?? {};
              isOnline = data["isOnline"] == true;
              final lastSeen = data["lastSeen"] as Timestamp?;

              if (isOnline) {
                statusText = "Çevrimiçi";
                statusColor = Colors.green;
              } else if (lastSeen != null) {
                statusText = "Son görülme: ${_formatLastSeen(lastSeen)}";
              } else {
                statusText = "Durum bilinmiyor";
                statusColor = Colors.grey.shade400;
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _resolvedUserName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87),
                ),
                if (statusText.isNotEmpty)
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: isOnline ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
              ],
            );
          },
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("chats")
                  .doc(widget.chatId)
                  .collection("messages")
                  .orderBy("createdAt", descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Text("İlk mesajı siz gönderin!", style: TextStyle(color: Colors.grey.shade400)),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data["senderId"] == uid;
                    final text = data["text"] ?? "";

                    String timeStr = "";
                    final createdAt = data["createdAt"] as Timestamp?;
                    if (createdAt != null) {
                      final dt = createdAt.toDate();
                      timeStr = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                    }

                    return _buildMessageBubble(isMe, text, timeStr, context);
                  },
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.transparent),
                    ),
                    child: TextField(
                      controller: _msgController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: "Mesaj yazın...",
                        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(bool isMe, String text, String timeStr, BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).colorScheme.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          border: isMe ? null : Border.all(color: Colors.grey.shade200),
          boxShadow: isMe ? [] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}