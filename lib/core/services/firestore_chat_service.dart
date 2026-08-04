import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreChatService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Collection references ───────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> _messagesRef(int chatId) =>
      _db
          .collection('chats')
          .doc(chatId.toString())
          .collection('messages');

  static DocumentReference<Map<String, dynamic>> _userRef(int userId) =>
      _db.collection('users').doc(userId.toString());

  // ─── Stream: realtime message feed ───────────────────────────────────────

  /// Returns a realtime stream of messages for [chatId], ordered by timestamp.
  static Stream<QuerySnapshot<Map<String, dynamic>>> getMessagesStream(
      int chatId) {
    return _messagesRef(chatId)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // ─── Write: sync message after API send ──────────────────────────────────

  /// Writes a sent message to Firestore so the receiver sees it in realtime.
  /// Call this AFTER your backend API confirms the message was saved.
  static Future<void> syncMessageToFirestore({
    required int chatId,
    required int senderId,
    required int receiverId,
    required String message,
    String? createdAt, // ISO string from backend response
  }) async {
    try {
      await _messagesRef(chatId).add({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('🔥 FirestoreChatService.syncMessageToFirestore error: $e');
    }
  }

  // ─── Seed: load existing messages from backend into Firestore ────────────

  /// One-time seed: write all [messages] from backend API into Firestore
  /// so the stream has historical messages on first open.
  /// Skips if Firestore already has messages for this chat.
  static Future<void> seedMessagesIfEmpty({
    required int chatId,
    required List<dynamic> messages,
  }) async {
    try {
      final existing =
          await _messagesRef(chatId).limit(1).get();

      if (existing.docs.isNotEmpty) return; // already seeded

      final batch = _db.batch();

      for (final msg in messages) {
        final docRef = _messagesRef(chatId).doc();
        DateTime timestamp;
        try {
          timestamp = DateTime.parse(msg['created_at'] ?? '').toLocal();
        } catch (_) {
          timestamp = DateTime.now();
        }

        batch.set(docRef, {
          'sender_id': int.tryParse(msg['sender_id'].toString()) ?? 0,
          'receiver_id': int.tryParse(
                  (msg['receiver_id'] ?? msg['chat_id'] ?? 0).toString()) ??
              0,
          'message': msg['message']?.toString() ?? '',
          'timestamp': Timestamp.fromDate(timestamp),
          'created_at': msg['created_at']?.toString() ??
              DateTime.now().toIso8601String(),
        });
      }

      await batch.commit();
      debugPrint(
          '🔥 Firestore seeded ${messages.length} messages for chat $chatId');
    } catch (e) {
      debugPrint('🔥 FirestoreChatService.seedMessagesIfEmpty error: $e');
    }
  }

  // ─── FCM Token management ─────────────────────────────────────────────────

  /// Saves (or updates) the FCM token for [userId] in Firestore.
  /// Your backend can read this when sending push notifications.
  static Future<void> saveUserFcmToken({
    required int userId,
    required String token,
  }) async {
    try {
      await _userRef(userId).set(
        {
          'fcm_token': token,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint('🔥 FCM token saved for user $userId');
    } catch (e) {
      debugPrint('🔥 FirestoreChatService.saveUserFcmToken error: $e');
    }
  }

  /// Fetches the FCM token for [userId] from Firestore.
  static Future<String?> getUserFcmToken(int userId) async {
    try {
      final doc = await _userRef(userId).get();
      return doc.data()?['fcm_token'] as String?;
    } catch (e) {
      debugPrint('🔥 FirestoreChatService.getUserFcmToken error: $e');
      return null;
    }
  }
}
