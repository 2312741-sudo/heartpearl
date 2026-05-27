// ─────────────────────────────────────────────
//  Auth Service — Firebase Authentication
// ─────────────────────────────────────────────

import {
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
  PhoneAuthProvider,
  signInWithCredential,
  updateProfile,
  User as FirebaseUser,
} from 'firebase/auth';
import {
  doc,
  setDoc,
  getDoc,
  updateDoc,
  serverTimestamp,
  collection,
  query,
  where,
  getDocs,
  onSnapshot,
  Unsubscribe,
} from 'firebase/firestore';
import { auth, db } from './firebase.config';
import { User } from '../types';

// ── Check Username Availability ──────────────
export const isUsernameAvailable = async (username: string): Promise<boolean> => {
  if (!username) return false;
  const q = query(
    collection(db, 'users'),
    where('username', '==', username.toLowerCase().trim())
  );
  const snapshot = await getDocs(q);
  return snapshot.empty;
};

// ── Auth State Observer ──────────────────────
export const onAuthStateChange = (callback: (user: FirebaseUser | null) => void) => {
  return onAuthStateChanged(auth, callback);
};

// ── Phone Auth ───────────────────────────────
// Lưu ý: Phone Auth cần reCAPTCHA — dùng expo-firebase-recaptcha
// hoặc chuyển sang Google Sign-In cho development

// ── Email/Password Auth (dev fallback) ───────
export const signUpWithEmail = async (
  email: string,
  password: string,
  displayName: string
): Promise<FirebaseUser> => {
  const { user } = await createUserWithEmailAndPassword(auth, email, password);
  await updateProfile(user, { displayName });
  await createUserDocument(user, { displayName });
  return user;
};

export const signInWithEmail = async (
  email: string,
  password: string
): Promise<FirebaseUser> => {
  const { user } = await signInWithEmailAndPassword(auth, email, password);
  return user;
};

export const signOutUser = async (): Promise<void> => {
  await signOut(auth);
};

// ── Firestore User Document ──────────────────
export const createUserDocument = async (
  firebaseUser: FirebaseUser,
  additionalData?: Partial<User>
): Promise<void> => {
  const userRef = doc(db, 'users', firebaseUser.uid);
  const snapshot = await getDoc(userRef);

  if (!snapshot.exists()) {
    const defaultUsername = firebaseUser.email 
      ? firebaseUser.email.split('@')[0] + '_' + Math.floor(100 + Math.random() * 900)
      : 'user_' + firebaseUser.uid.substring(0, 5);

    await setDoc(userRef, {
      uid: firebaseUser.uid,
      displayName: firebaseUser.displayName || additionalData?.displayName || 'Người dùng',
      username: additionalData?.username || defaultUsername.toLowerCase(),
      phone: firebaseUser.phoneNumber || null,
      email: firebaseUser.email || null,
      avatarUrl: firebaseUser.photoURL || null,
      friends: [],
      fcmToken: null,
      createdAt: serverTimestamp(),
      ...additionalData,
    });
  }
};

export const getUserDocument = async (uid: string): Promise<User | null> => {
  const userRef = doc(db, 'users', uid);
  const snapshot = await getDoc(userRef);
  if (snapshot.exists()) {
    return { uid: snapshot.id, ...snapshot.data() } as unknown as User;
  }
  return null;
};

export const subscribeToUserProfile = (
  uid: string,
  callback: (profile: User | null) => void
): Unsubscribe => {
  const userRef = doc(db, 'users', uid);
  return onSnapshot(userRef, (docSnap) => {
    if (docSnap.exists()) {
      callback({ uid: docSnap.id, ...docSnap.data() } as unknown as User);
    } else {
      callback(null);
    }
  });
};

export const updateUserDocument = async (
  uid: string,
  data: Partial<User>
): Promise<void> => {
  const userRef = doc(db, 'users', uid);
  await setDoc(userRef, data, { merge: true });
};

export const updateFCMToken = async (uid: string, token: string): Promise<void> => {
  await updateUserDocument(uid, { fcmToken: token });
};
