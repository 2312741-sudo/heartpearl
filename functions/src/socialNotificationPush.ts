import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Firestore trigger: fires when a document is created in notifications/{notificationId}.
 * Sends an FCM push notification outside the app for friend requests, reactions, and moments.
 */
export const onNotificationCreated = functions.firestore.onDocumentCreated(
  'notifications/{notificationId}',
  async (event) => {
    const notificationId = event.params.notificationId;
    const data = event.data?.data();

    if (!data) return;

    // Chat messages are handled separately with full chat info by onChatMessageCreated
    const type = data['type'] as string | undefined;
    if (type === 'message') return;

    const userId = data['userId'] as string | undefined;
    const senderId = data['senderId'] as string | undefined;
    const title = (data['title'] as string | undefined) ?? 'HeartPearl';
    const body = (data['body'] as string | undefined) ?? '';
    const photoId = data['photoId'] as string | undefined;
    const requestId = data['requestId'] as string | undefined;

    if (!userId) return;

    try {
      // 1. Fetch recipient user document to get fcmToken
      const userDoc = await db.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      const userData = userDoc.data() ?? {};
      const blockedUsers = (userData['blockedUsers'] as string[] | undefined) ?? [];
      if (senderId && blockedUsers.includes(senderId)) {
        functions.logger.info(`[socialNotificationPush] sender ${senderId} is blocked by ${userId}`);
        return;
      }

      const fcmToken = userData['fcmToken'] as string | undefined;
      if (!fcmToken || fcmToken.trim().length === 0) {
        functions.logger.info(`[socialNotificationPush] user ${userId} has no fcmToken`);
        return;
      }

      // 2. Build FCM message
      const message: admin.messaging.Message = {
        token: fcmToken,
        notification: {
          title,
          body,
        },
        data: {
          type: type ?? 'general',
          notificationId,
          photoId: photoId ?? '',
          requestId: requestId ?? '',
          senderId: senderId ?? '',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'heartpearl_social',
            priority: 'high',
            sound: 'default',
            defaultSound: true,
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title,
                body,
              },
              sound: 'default',
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
        `[socialNotificationPush] Sent push for notification ${notificationId} to ${userId}: messageId=${response}`,
      );
    } catch (error) {
      functions.logger.error(`[socialNotificationPush] Error sending push for ${notificationId}:`, error);
    }
  },
);
