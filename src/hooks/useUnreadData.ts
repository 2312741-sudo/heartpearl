import { useState, useEffect } from 'react';
import { collection, query, where, onSnapshot } from 'firebase/firestore';
import { db } from '../services/firebase.config';
import { useAuthStore } from '../store/auth.store';

export function useUnreadData() {
  const { userProfile } = useAuthStore();
  const [unreadChats, setUnreadChats] = useState(0);
  const [unreadNotifications, setUnreadNotifications] = useState(0);

  useEffect(() => {
    if (!userProfile?.uid) return;
    const uid = userProfile.uid;

    // 1. Listen to unread chats
    const qChats = query(
      collection(db, 'chats'),
      where('participants', 'array-contains', uid)
    );
    
    const unsubscribeChats = onSnapshot(qChats, (snapshot) => {
      let totalUnread = 0;
      snapshot.forEach(doc => {
        const data = doc.data();
        if (data.unreadCount && typeof data.unreadCount[uid] === 'number') {
          totalUnread += data.unreadCount[uid];
        }
      });
      setUnreadChats(totalUnread);
    });

    // 2. Listen to unread notifications
    const qNotifs = query(
      collection(db, 'notifications'),
      where('userId', '==', uid),
      where('read', '==', false)
    );

    const unsubscribeNotifs = onSnapshot(qNotifs, (snapshot) => {
      setUnreadNotifications(snapshot.docs.length);
    });

    return () => {
      unsubscribeChats();
      unsubscribeNotifs();
    };
  }, [userProfile?.uid]);

  return { unreadChats, unreadNotifications, totalUnread: unreadChats + unreadNotifications };
}
