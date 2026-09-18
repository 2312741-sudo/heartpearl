import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/** Haversine distance in metres between two lat/lng points */
function haversineMetres(
  lat1: number, lng1: number,
  lat2: number, lng2: number,
): number {
  const R = 6_371_000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Firestore trigger: fires when a userLocations document is updated.
 * If the owner moved >= 100 m, sends a silent push to every allowed viewer
 * so their iOS WidgetKit refreshes immediately.
 */
export const onLocationChanged = functions.firestore.onDocumentUpdated(
  'userLocations/{uid}',
  async (event) => {
    const uid = event.params.uid;
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    if (!before || !after) return;
    if (after['isSharing'] !== true) return;

    const geoAfter = after['geo'] as admin.firestore.GeoPoint | undefined;
    const geoBefore = before['geo'] as admin.firestore.GeoPoint | undefined;

    if (!geoAfter) return;

    const movedMetres = geoBefore
      ? haversineMetres(
          geoBefore.latitude, geoBefore.longitude,
          geoAfter.latitude, geoAfter.longitude,
        )
      : 999;

    if (movedMetres < 100) return;

    const allowedViewers = after['allowedViewers'] as string[] | undefined;
    let viewerUids: string[] = allowedViewers ?? [];

    if (viewerUids.length === 0) {
      try {
        const userDoc = await db.collection('users').doc(uid).get();
        const friends = userDoc.data()?.['friends'] as string[] | undefined;
        viewerUids = friends ?? [];
      } catch { return; }
    }

    if (viewerUids.length === 0) return;

    const tokenResults = await Promise.allSettled(
      viewerUids.map(async (viewerUid) => {
        const doc = await db.collection('users').doc(viewerUid).get();
        return (doc.data()?.['fcmToken'] as string | undefined) ?? null;
      }),
    );

    const tokens = tokenResults
      .filter((r): r is PromiseFulfilledResult<string | null> => r.status === 'fulfilled')
      .map((r) => r.value)
      .filter((t): t is string => !!t && t.length > 0);

    if (tokens.length === 0) return;

    const message: admin.messaging.MulticastMessage = {
      tokens,
      data: {
        type: 'location_widget_update',
        uid,
        lat: String(geoAfter.latitude),
        lng: String(geoAfter.longitude),
        movedMetres: String(Math.round(movedMetres)),
      },
      apns: {
        payload: { aps: { contentAvailable: true } },
        headers: {
          'apns-priority': '5',
          'apns-push-type': 'background',
        },
      },
      android: {
        priority: 'normal',
        data: { type: 'location_widget_update', uid },
      },
    };

    try {
      const result = await messaging.sendEachForMulticast(message);
      functions.logger.info(
        `[locationWidgetPush] uid=${uid} moved=${Math.round(movedMetres)}m ` +
        `tokens=${tokens.length} ok=${result.successCount} fail=${result.failureCount}`,
      );
    } catch (err) {
      functions.logger.error('[locationWidgetPush] error', err);
    }
  },
);
