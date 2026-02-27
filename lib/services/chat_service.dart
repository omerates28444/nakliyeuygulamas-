import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;

  String chatIdForLoad(String loadId) => "load_$loadId";

  Future<void> ensureChat({
    required String loadId,
    required String shipperId,
    required String driverId,
  }) async {
    final chatId = chatIdForLoad(loadId);

    await _db.collection("chats").doc(chatId).set({
      "loadId": loadId,
      "shipperId": shipperId,
      "driverId": driverId,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
      "lastMessage": null,
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> messages(String chatId) {
    return _db
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  Future<void> send({
    required String chatId,
    required String fromUserId,
    required String text,
  }) async {
    final t = text.trim();
    if (t.isEmpty) return;

    final chatRef = _db.collection("chats").doc(chatId);
    final msgRef = chatRef.collection("messages").doc();

    await _db.runTransaction((tx) async {
      tx.set(msgRef, {
        "fromUserId": fromUserId,
        "text": t,
        "createdAt": FieldValue.serverTimestamp(),
      });

      tx.set(chatRef, {
        "updatedAt": FieldValue.serverTimestamp(),
        "lastMessage": t,
      }, SetOptions(merge: true));
    });
  }
}