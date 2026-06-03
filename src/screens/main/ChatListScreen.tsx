import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  Image,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { collection, query, where, orderBy, onSnapshot } from 'firebase/firestore';
import { db } from '../../services/firebase.config';
import { useAuthStore } from '../../store/auth.store';
import { useAppTheme, Typography, Spacing } from '../../constants/theme';
import { useNavigation } from '@react-navigation/native';
import { ChevronLeft, Bell } from 'lucide-react-native';
import { useUnreadData } from '../../hooks/useUnreadData';
import dayjs from 'dayjs';

export default function ChatListScreen() {
  const { userProfile } = useAuthStore();
  const { colors } = useAppTheme();
  const navigation = useNavigation<any>();
  const [chats, setChats] = useState<any[]>([]);
  const { unreadNotifications } = useUnreadData();

  useEffect(() => {
    if (!userProfile?.uid) return;

    const q = query(
      collection(db, 'chats'),
      where('participants', 'array-contains', userProfile.uid),
      orderBy('updatedAt', 'desc')
    );

    const unsubscribe = onSnapshot(q, (snapshot) => {
      const chatList = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
        updatedAt: doc.data().updatedAt?.toDate() || new Date(),
      }));
      setChats(chatList);
    });

    return unsubscribe;
  }, [userProfile?.uid]);

  const renderItem = ({ item }: { item: any }) => {
    // Tìm friendId
    const friendId = item.participants.find((id: string) => id !== userProfile?.uid);
    const friendInfo = item.participantsInfo?.[friendId] || { name: 'Người dùng', avatar: '' };
    const myUnreadCount = item.unreadCount?.[userProfile!.uid] || 0;
    
    return (
      <Pressable 
        style={[styles.chatItem, { borderBottomColor: colors.border }]}
        onPress={() => navigation.navigate('Chat', { friendId, friendName: friendInfo.name, friendAvatar: friendInfo.avatar })}
      >
        <Image 
          source={{ uri: friendInfo.avatar || 'https://via.placeholder.com/50' }} 
          style={styles.avatar} 
        />
        <View style={styles.chatInfo}>
          <Text style={[styles.name, { color: colors.textPrimary }]} numberOfLines={1}>
            {friendInfo.name}
          </Text>
          <Text style={[styles.lastMessage, { color: colors.textMuted }]} numberOfLines={1}>
            {item.lastMessage}
          </Text>
        </View>
        <View style={{ alignItems: 'flex-end' }}>
          <Text style={[styles.time, { color: colors.textMuted }]}>
            {dayjs(item.updatedAt).format('HH:mm')}
          </Text>
          {myUnreadCount > 0 && (
            <View style={styles.unreadBadge}>
              <Text style={styles.unreadText}>{myUnreadCount > 99 ? '99+' : myUnreadCount}</Text>
            </View>
          )}
        </View>
      </Pressable>
    );
  };

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['top', 'bottom']}>
      {/* Header */}
      <View style={[styles.header, { borderBottomColor: colors.border, justifyContent: 'space-between' }]}>
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          <Pressable style={styles.backBtn} onPress={() => navigation.goBack()}>
            <ChevronLeft color={colors.textPrimary} size={24} />
          </Pressable>
          <Text style={[styles.headerTitle, { color: colors.textPrimary }]}>Tin nhắn</Text>
        </View>

        <Pressable 
          style={styles.bellBtn} 
          onPress={() => navigation.navigate('Notifications')}
        >
          <Bell color={colors.textPrimary} size={24} />
          {unreadNotifications > 0 && (
            <View style={styles.headerBadge}>
              <Text style={styles.headerBadgeText}>
                {unreadNotifications > 99 ? '99+' : unreadNotifications}
              </Text>
            </View>
          )}
        </Pressable>
      </View>

      {/* List */}
      <FlatList
        data={chats}
        keyExtractor={item => item.id}
        renderItem={renderItem}
        contentContainerStyle={styles.listContent}
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Text style={[styles.emptyText, { color: colors.textMuted }]}>Bạn chưa có cuộc trò chuyện nào</Text>
          </View>
        }
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.base,
    paddingVertical: 12,
    borderBottomWidth: 1,
  },
  backBtn: {
    padding: 8,
    marginRight: 8,
  },
  headerTitle: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.xl,
  },
  listContent: {
    paddingBottom: Spacing.xl,
  },
  chatItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.base,
    paddingVertical: 14,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  avatar: {
    width: 50,
    height: 50,
    borderRadius: 25,
    marginRight: 14,
  },
  chatInfo: {
    flex: 1,
    justifyContent: 'center',
  },
  name: {
    fontFamily: Typography.fontFamily.semiBold,
    fontSize: Typography.fontSize.base,
    marginBottom: 4,
  },
  lastMessage: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.sm,
  },
  time: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.xs,
    marginLeft: 10,
  },
  emptyContainer: {
    padding: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyText: {
    fontFamily: Typography.fontFamily.medium,
    fontSize: Typography.fontSize.base,
  },
  unreadBadge: {
    backgroundColor: '#FF3B30',
    minWidth: 20,
    height: 20,
    borderRadius: 10,
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 6,
    paddingHorizontal: 4,
  },
  unreadText: {
    color: '#FFF',
    fontSize: 12,
    fontFamily: Typography.fontFamily.bold,
  },
  bellBtn: {
    padding: 8,
    position: 'relative',
  },
  headerBadge: {
    position: 'absolute',
    top: 4,
    right: 4,
    backgroundColor: '#FF3B30',
    minWidth: 16,
    height: 16,
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 3,
  },
  headerBadgeText: {
    color: '#FFF',
    fontSize: 10,
    fontFamily: Typography.fontFamily.bold,
  }
});
