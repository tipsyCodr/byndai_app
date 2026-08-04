const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

/**
 * Triggered automatically whenever a new message is added to:
 *   chats/{chatId}/messages/{msgId}
 *
 * It reads the receiver's FCM token from Firestore and sends a push notification.
 */
exports.onNewChatMessage = onDocumentCreated(
  "chats/{chatId}/messages/{msgId}",
  async (event) => {
    try {
      const data = event.data.data();

      const receiverId = data.receiver_id?.toString();
      const senderId = data.sender_id?.toString();
      const messageText = data.message ?? "";
      const chatId = event.params.chatId;

      if (!receiverId || !senderId) {
        console.log("❌ Missing receiver_id or sender_id, skipping.");
        return;
      }

      // Don't notify yourself (shouldn't happen but just in case)
      if (receiverId === senderId) return;

      // 1. Get sender's name from Firestore (optional — fallback to "New Message")
      let senderName = "New Message";
      try {
        const senderDoc = await getFirestore().doc(`users/${senderId}`).get();
        if (senderDoc.exists) {
          senderName = senderDoc.data()?.name ?? senderName;
        }
      } catch (e) {
        console.log("⚠️ Could not fetch sender name:", e);
      }

      // 2. Get receiver's FCM token
      const receiverDoc = await getFirestore().doc(`users/${receiverId}`).get();
      if (!receiverDoc.exists) {
        console.log(`❌ Receiver user doc not found for userId: ${receiverId}`);
        return;
      }

      const fcmToken = receiverDoc.data()?.fcm_token;
      if (!fcmToken) {
        console.log(`❌ No FCM token for userId: ${receiverId}`);
        return;
      }

      // 3. Send the push notification
      const message = {
        token: fcmToken,
        notification: {
          title: senderName,
          body: messageText.length > 100
            ? messageText.substring(0, 97) + "..."
            : messageText,
        },
        data: {
          type: "chat",
          chat_id: chatId,
          sender_id: senderId,
          sender_name: senderName,
          receiver_id: receiverId,
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      const response = await getMessaging().send(message);
      console.log(`✅ Notification sent to user ${receiverId}:`, response);
    } catch (error) {
      console.error("❌ onNewChatMessage error:", error);
    }
  }
);
