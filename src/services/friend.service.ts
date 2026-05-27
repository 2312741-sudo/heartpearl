// ─────────────────────────────────────────────
//  Friend Service — Firestore
// ─────────────────────────────────────────────

import {
  collection,
  addDoc,
  query,
  where,
  onSnapshot,
  updateDoc,
  setDoc,
  doc,
  getDocs,
  serverTimestamp,
  arrayUnion,
  getDoc,
  Unsubscribe,
} from 'firebase/firestore';
import { db } from './firebase.config';
import { FriendRequest, User } from '../types';

// ── Search User ──────────────────────────────
export const searchUserByPhone = async (phone: string): Promise<User | null> => {
  const q = query(collection(db, 'users'), where('phone', '==', phone));
  const snapshot = await getDocs(q);
  if (snapshot.empty) return null;
  const d = snapshot.docs[0];
  return { uid: d.id, ...d.data() } as User;
};

export const searchUserByUsername = async (username: string): Promise<User[]> => {
  const cleanUsername = username.toLowerCase().trim();
  const q = query(
    collection(db, 'users'),
    where('username', '>=', cleanUsername),
    where('username', '<=', cleanUsername + '\uf8ff')
  );
  const snapshot = await getDocs(q);
  return snapshot.docs.map((d) => ({ uid: d.id, ...d.data() } as User));
};

export const searchUserByName = async (displayName: string): Promise<User[]> => {
  // Firestore không hỗ trợ LIKE query — dùng prefix search
  const q = query(
    collection(db, 'users'),
    where('displayName', '>=', displayName),
    where('displayName', '<=', displayName + '\uf8ff')
  );
  const snapshot = await getDocs(q);
  return snapshot.docs.map((d) => ({ uid: d.id, ...d.data() } as User));
};

// ── Friend Requests ───────────────────────────
export const sendFriendRequest = async (
  fromUid: string,
  toUid: string
): Promise<void> => {
  // Kiểm tra xem đã có request chưa
  const existing = query(
    collection(db, 'friendRequests'),
    where('from', '==', fromUid),
    where('to', '==', toUid),
    where('status', '==', 'pending')
  );
  const snap = await getDocs(existing);
  if (!snap.empty) return; // Đã gửi rồi

  await addDoc(collection(db, 'friendRequests'), {
    from: fromUid,
    to: toUid,
    status: 'pending',
    createdAt: serverTimestamp(),
  });
};

export const acceptFriendRequest = async (
  requestId: string,
  fromUid: string,
  toUid: string
): Promise<void> => {
  // Cập nhật status request
  await updateDoc(doc(db, 'friendRequests', requestId), {
    status: 'accepted',
  });

  // Thêm vào danh sách bạn bè của cả hai (dùng setDoc merge đề phòng document chưa được khởi tạo)
  await setDoc(doc(db, 'users', fromUid), {
    friends: arrayUnion(toUid),
  }, { merge: true });
  
  await setDoc(doc(db, 'users', toUid), {
    friends: arrayUnion(fromUid),
  }, { merge: true });
};

export const rejectFriendRequest = async (requestId: string): Promise<void> => {
  await updateDoc(doc(db, 'friendRequests', requestId), {
    status: 'rejected',
  });
};

// ── Real-time Friend Requests ─────────────────
export const subscribeToFriendRequests = (
  uid: string,
  callback: (requests: FriendRequest[]) => void
): Unsubscribe => {
  const q = query(
    collection(db, 'friendRequests'),
    where('to', '==', uid),
    where('status', '==', 'pending')
  );

  return onSnapshot(q, async (snapshot) => {
    const requests = await Promise.all(
      snapshot.docs.map(async (d) => {
        const data = d.data();
        const fromDoc = await getDoc(doc(db, 'users', data.from));
        return {
          id: d.id,
          ...data,
          fromUser: fromDoc.exists()
            ? { uid: fromDoc.id, ...fromDoc.data() }
            : undefined,
          createdAt: data.createdAt?.toDate() || new Date(),
        } as FriendRequest;
      })
    );
    callback(requests);
  });
};

// ── Get Friends List ──────────────────────────
export const getFriendsList = async (friendIds: string[]): Promise<User[]> => {
  if (friendIds.length === 0) return [];
  const friends = await Promise.all(
    friendIds.map(async (uid) => {
      const d = await getDoc(doc(db, 'users', uid));
      return d.exists() ? ({ uid: d.id, ...d.data() } as User) : null;
    })
  );
  return friends.filter(Boolean) as User[];
};
