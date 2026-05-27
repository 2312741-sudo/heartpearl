// ─────────────────────────────────────────────
//  Firebase Configuration
//  Thay thế các giá trị bên dưới bằng config
//  từ Firebase Console của bạn
// ─────────────────────────────────────────────

import { initializeApp, getApps, getApp, FirebaseApp } from 'firebase/app';
// @ts-ignore
import { initializeAuth, getReactNativePersistence, getAuth, Auth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { getStorage } from 'firebase/storage';
import AsyncStorage from '@react-native-async-storage/async-storage';

// TODO: Thay thế bằng config từ Firebase Console của bạn
// https://console.firebase.google.com → Project Settings → Your apps → SDK setup
const firebaseConfig = {
  apiKey: "AIzaSyDgny9xP_riIlp-w80zn0q5VR7ix8SYwdE",
  authDomain: "tamchau-865f3.firebaseapp.com",
  databaseURL: "https://tamchau-865f3-default-rtdb.firebaseio.com",
  projectId: "tamchau-865f3",
  storageBucket: "tamchau-865f3.firebasestorage.app",
  messagingSenderId: "592218033486",
  appId: "1:592218033486:web:b83446b376d092f160a21f",
};

// Tránh khởi tạo nhiều lần (hot reload)
let app: FirebaseApp;
let auth: Auth;

if (getApps().length === 0) {
  app = initializeApp(firebaseConfig);
  auth = initializeAuth(app, {
    persistence: getReactNativePersistence(AsyncStorage)
  });
} else {
  app = getApp();
  auth = getAuth(app);
}

export { auth };
export const db = getFirestore(app);
export const storage = getStorage(app);

export default app;
