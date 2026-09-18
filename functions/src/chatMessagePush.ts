import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Firestore trigger: fires when a new message is added to chats/{chatId}/messages/{messageId}.
 * Sends a high-priority FCM push notification to the recipient so they receive outside-app alerts.
 */
export const onChatMessageCreated = functions.firestore.onDocumentCreated(
  'chats/{chatId}/messages/{messageId}',
  async (event) => {
    const chatId = event.params.chatId;
    const messageId = event.params.messageId;
    const messageData = event.data?.data();

    if (!messageData) return;

    const senderId = messageData['senderId'] as string | undefined;
    const text = (messageData['text'] as string | undefined) ?? '';
    const photoUrl = messageData['photoUrl'] as string | undefined;

    if (!senderId) return;

    try {
      // 1. Fetch chat document to get participants and sender info
      const chatDoc = await db.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;

      const chatData = chatDoc.data() ?? {};
      const participants = (chatData['participants'] as string[] | undefined) ?? [];
      const recipientId = participants.find((id) => id !== senderId);

      if (!recipientId) return;

      const participantsInfo = (chatData['participantsInfo'] as Record<string, any> | undefined) ?? {};
      const senderInfo = participantsInfo[senderId] ?? {};
      const senderName = (senderInfo['name'] as string | undefined) ?? 'Bạn bè';
      const senderAvatar = (senderInfo['avatar'] as string | undefined) ?? '';

      // 2. Fetch recipient user document to get fcmToken and check blocked users
      const recipientDoc = await db.collection('users').doc(recipientId).get();
      if (!recipientDoc.exists) return;

      const recipientData = recipientDoc.data() ?? {};
      const blockedUsers = (recipientData['blockedUsers'] as string[] | undefined) ?? [];
      if (blockedUsers.includes(senderId)) {
        functions.logger.info(`[chatMessagePush] sender ${senderId} is blocked by ${recipientId}`);
        return;
      }

      const fcmToken = recipientData['fcmToken'] as string | undefined;
      if (!fcmToken || fcmToken.trim().length === 0) {
        functions.logger.info(`[chatMessagePush] recipient ${recipientId} has no fcmToken`);
        return;
      }

      // Calculate unread count for badge
      const unreadMap = (chatData['unreadCount'] as Record<string, number> | undefined) ?? {};
      const currentUnread = unreadMap[recipientId] ?? 1;

      const notificationBody = photoUrl
        ? '📷 [Hình ảnh]'
        : text.trim().length > 0
        ? text.trim()
        : 'Đã gửi một tin nhắn';

      // 3. Build FCM Push Notification payload
      const message: admin.messaging.Message = {
        token: fcmToken,
        notification: {
          title: senderName,
          body: notificationBody,
        },
        data: {
          type: 'chat_message',
          chatId: chatId,
          senderId: senderId,
          friendName: senderName,
          friendAvatar: senderAvatar,
          messageId: messageId,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'heartpearl_messages',
            priority: 'high',
            sound: 'default',
            defaultSound: true,
            defaultVibrateTimings: true,
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: senderName,
                body: notificationBody,
              },
              sound: 'default',
              badge: currentUnread,
              category: 'MESSAGE',
            },
          },
          headers: {
            'apns-priority': '10',
            'apns-push-type': 'alert',
          },
        },
      };

      const response = await messaging.send(message);
      functions.logger.info(
        `[chatMessagePush] Sent push notification for chat ${chatId} from ${senderId} to ${recipientId}: messageId=${response}`,
      );
    } catch (error) {
      functions.logger.error(`[chatMessagePush] Error sending push for chat ${chatId}:`, error);
    }
  },
);
