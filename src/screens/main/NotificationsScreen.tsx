import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { collection, query, where, orderBy, onSnapshot, writeBatch } from 'firebase/firestore';
import { db } from '../../services/firebase.config';
import { useAuthStore } from '../../store/auth.store';
import { useAppTheme, Typography, Spacing } from '../../constants/theme';
import { Bell } from 'lucide-react-native';
import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';
import 'dayjs/locale/vi';

dayjs.extend(relativeTime);
dayjs.locale('vi');

export default function NotificationsScreen() {
  const { userProfile } = useAuthStore();
  const { colors } = useAppTheme();
  const [notifications, setNotifications] = useState<any[]>([]);

  useEffect(() => {
    if (!userProfile?.uid) return;

    const q = query(
      collection(db, 'notifications'),
      where('userId', '==', userProfile.uid),
      orderBy('createdAt', 'desc')
    );

    const unsubscribe = onSnapshot(q, (snapshot) => {
      const notifs = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
        createdAt: doc.data().createdAt?.toDate() || new Date(),
      }));
      setNotifications(notifs);

      // Mark all as read
      const unreadDocs = snapshot.docs.filter(d => !d.data().read);
      if (unreadDocs.length > 0) {
        try {
          const batch = writeBatch(db);
          unreadDocs.forEach(d => {
            batch.update(d.ref, { read: true });
          });
          batch.commit();
        } catch (e) {
          console.error("Cannot mark notifications as read:", e);
        }
      }
    });

    return unsubscribe;
  }, [userProfile?.uid]);

  const renderItem = ({ item }: { item: any }) => {
    return (
      <View style={[styles.item, { borderBottomColor: colors.border, backgroundColor: item.read ? colors.background : colors.surface }]}>
        <View style={styles.iconContainer}>
          <Bell color={colors.primary} size={24} />
        </View>
        <View style={styles.content}>
          <Text style={[styles.title, { color: colors.textPrimary }]} numberOfLines={1}>
            {item.title}
          </Text>
          <Text style={[styles.body, { color: colors.textMuted }]} numberOfLines={2}>
            {item.body}
          </Text>
          <Text style={[styles.time, { color: colors.textMuted }]}>
            {dayjs(item.createdAt).fromNow()}
          </Text>
        </View>
      </View>
    );
  };

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['top', 'bottom']}>
      {/* Header */}
      <View style={[styles.header, { borderBottomColor: colors.border }]}>
        <Text style={[styles.headerTitle, { color: colors.textPrimary }]}>Thông báo</Text>
      </View>

      {/* List */}
      <FlatList
        data={notifications}
        keyExtractor={item => item.id}
        renderItem={renderItem}
        contentContainerStyle={styles.listContent}
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Bell size={48} color={colors.textMuted} strokeWidth={1.5} style={{ marginBottom: 16 }} />
            <Text style={[styles.emptyText, { color: colors.textMuted }]}>Bạn chưa có thông báo nào</Text>
          </View>
        }
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.base,
    paddingVertical: 12,
    borderBottomWidth: 1,
  },
  backBtn: { padding: 8, marginRight: 8 },
  headerTitle: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.xl,
  },
  listContent: { paddingBottom: Spacing.xl },
  item: {
    flexDirection: 'row',
    paddingHorizontal: Spacing.base,
    paddingVertical: 16,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  iconContainer: {
    marginRight: 16,
    justifyContent: 'center',
  },
  content: { flex: 1, justifyContent: 'center' },
  title: {
    fontFamily: Typography.fontFamily.semiBold,
    fontSize: Typography.fontSize.base,
    marginBottom: 4,
  },
  body: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.sm,
    marginBottom: 8,
  },
  time: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.xs,
  },
  emptyContainer: {
    padding: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyText: {
    fontFamily: Typography.fontFamily.medium,
    fontSize: Typography.fontSize.base,
  }
});
