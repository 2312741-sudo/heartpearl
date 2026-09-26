import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();

/**
 * Firestore trigger: fires when a friendRequests document is updated.
 * When a request transitions from 'pending' to 'accepted', atomically adds
 * each user to the other's `friends` list using Admin SDK.
 */
export const onFriendRequestAccepted = functions.firestore.onDocumentUpdated(
  'friendRequests/{requestId}',
  async (event) => {
    const requestId = event.params.requestId;
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    if (!before || !after) return;

    if (before['status'] === 'pending' && after['status'] === 'accepted') {
      const fromUid = after['from'] as string | undefined;
      const toUid = after['to'] as string | undefined;

      if (!fromUid || !toUid) {
        console.warn(
          `[onFriendRequestAccepted] Missing fromUid (${fromUid}) or toUid (${toUid}) on request ${requestId}`
        );
        return;
      }

      try {
        await db.runTransaction(async (transaction) => {
          const fromUserRef = db.collection('users').doc(fromUid);
          const toUserRef = db.collection('users').doc(toUid);

          transaction.set(
            fromUserRef,
            { friends: admin.firestore.FieldValue.arrayUnion(toUid) },
            { merge: true }
          );
          transaction.set(
            toUserRef,
            { friends: admin.firestore.FieldValue.arrayUnion(fromUid) },
            { merge: true }
          );
        });

        console.log(
          `[onFriendRequestAccepted] Successfully linked friendship: ${fromUid} <-> ${toUid} for request ${requestId}`
        );
      } catch (error) {
        console.error(
          `[onFriendRequestAccepted] Error linking friends for request ${requestId}:`,
          error
        );
      }
    }
  }
);
