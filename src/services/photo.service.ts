// ─────────────────────────────────────────────
//  Photo Service — Firestore & Storage
// ─────────────────────────────────────────────

import {
  collection,
  addDoc,
  query,
  where,
  orderBy,
  onSnapshot,
  updateDoc,
  doc,
  serverTimestamp,
  Unsubscribe,
  getDocs,
  limit,
} from 'firebase/firestore';
import {
  ref,
  uploadBytesResumable,
  getDownloadURL,
} from 'firebase/storage';
import { db, storage } from './firebase.config';
import { Photo } from '../types';

// ── Upload Image ─────────────────────────────
export const uploadPhoto = async (
  uri: string,
  userId: string,
  onProgress?: (progress: number) => void
): Promise<string> => {
  const response = await fetch(uri);
  const blob = await response.blob();
  const fileName = `${Date.now()}.jpg`;
  const storageRef = ref(storage, `photos/${userId}/${fileName}`);

  return new Promise((resolve, reject) => {
    const uploadTask = uploadBytesResumable(storageRef, blob);

    uploadTask.on(
      'state_changed',
      (snapshot) => {
        const progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        onProgress?.(progress);
      },
      reject,
      async () => {
        const downloadURL = await getDownloadURL(uploadTask.snapshot.ref);
        resolve(downloadURL);
      }
    );
  });
};

// ── Upload Video ──────────────────────────────────
export const uploadVideo = async (
  uri: string,
  userId: string,
  onProgress?: (progress: number) => void
): Promise<string> => {
  const response = await fetch(uri);
  const blob = await response.blob();
  const fileName = `${Date.now()}.mp4`;
  const storageRef = ref(storage, `videos/${userId}/${fileName}`);

  return new Promise((resolve, reject) => {
    const uploadTask = uploadBytesResumable(storageRef, blob);

    uploadTask.on(
      'state_changed',
      (snapshot) => {
        const progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        onProgress?.(progress);
      },
      reject,
      async () => {
        const downloadURL = await getDownloadURL(uploadTask.snapshot.ref);
        resolve(downloadURL);
      }
    );
  });
};

// ── Send Photo / Video ──────────────────────────────
export const sendPhoto = async (
  senderId: string,
  recipientIds: string[],
  imageUrl: string,
  caption?: string,
  mediaType: 'photo' | 'video' = 'photo',
  videoUrl?: string
): Promise<string> => {
  const docRef = await addDoc(collection(db, 'photos'), {
    senderId,
    recipientIds,
    imageUrl,
    videoUrl: videoUrl || null,
    caption: caption || null,
    mediaType,
    createdAt: serverTimestamp(),
    reactions: {},
    seen: {},
  });
  return docRef.id;
};

// ── Real-time Inbox Listener ──────────────────
export const subscribeToInbox = (
  userId: string,
  callback: (photos: Photo[]) => void
): Unsubscribe => {
  const q = query(
    collection(db, 'photos'),
    where('recipientIds', 'array-contains', userId),
    orderBy('createdAt', 'desc'),
    limit(50)
  );

  return onSnapshot(q, (snapshot) => {
    const photos = snapshot.docs.map((d) => ({
      id: d.id,
      ...d.data(),
      createdAt: d.data().createdAt?.toDate() || new Date(),
    })) as Photo[];
    callback(photos);
  });
};

// ── Sent Photos ──────────────────────────────
export const subscribeToSentPhotos = (
  userId: string,
  callback: (photos: Photo[]) => void
): Unsubscribe => {
  const q = query(
    collection(db, 'photos'),
    where('senderId', '==', userId),
    orderBy('createdAt', 'desc'),
    limit(100)
  );

  return onSnapshot(q, (snapshot) => {
    const photos = snapshot.docs.map((d) => ({
      id: d.id,
      ...d.data(),
      createdAt: d.data().createdAt?.toDate() || new Date(),
    })) as Photo[];
    callback(photos);
  });
};

// ── React to Photo ───────────────────────────
export const reactToPhoto = async (
  photoId: string,
  userId: string,
  reactionImageUrl: string
): Promise<void> => {
  const photoRef = doc(db, 'photos', photoId);
  await updateDoc(photoRef, {
    [`reactions.${userId}`]: reactionImageUrl,
  });
};

// ── Mark as Seen ─────────────────────────────
export const markPhotoAsSeen = async (
  photoId: string,
  userId: string
): Promise<void> => {
  const photoRef = doc(db, 'photos', photoId);
  await updateDoc(photoRef, {
    [`seen.${userId}`]: true,
  });
};

// ── Text React to Photo ───────────────────────
export const textReactToPhoto = async (
  photoId: string,
  userId: string,
  message: string
): Promise<void> => {
  const photoRef = doc(db, 'photos', photoId);
  await updateDoc(photoRef, {
    [`textReactions.${userId}`]: message,
  });
};
