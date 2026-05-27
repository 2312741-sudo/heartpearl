// ─────────────────────────────────────────────
//  Friends Screen
// ─────────────────────────────────────────────

import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  Pressable,
  FlatList,
  Alert,
  ActivityIndicator,
  Image,
  Keyboard,
  TouchableWithoutFeedback,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import {
  searchUserByUsername,
  sendFriendRequest,
  subscribeToFriendRequests,
  acceptFriendRequest,
  rejectFriendRequest,
  getFriendsList,
} from '../../services/friend.service';
import { useAuthStore } from '../../store/auth.store';
import { Colors, Typography, Spacing, BorderRadius } from '../../constants/theme';
import { User, FriendRequest } from '../../types';

type Tab = 'friends' | 'requests' | 'search';

export default function FriendsScreen() {
  const { userProfile } = useAuthStore();
  const [activeTab, setActiveTab] = useState<Tab>('friends');
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<User[]>([]);
  const [friendRequests, setFriendRequests] = useState<FriendRequest[]>([]);
  const [friends, setFriends] = useState<User[]>([]);
  const [searching, setSearching] = useState(false);

  // Hàm load danh sách bạn bè
  const loadFriends = useCallback(async (friendIds: string[]) => {
    if (!friendIds?.length) {
      setFriends([]);
      return;
    }
    const list = await getFriendsList(friendIds);
    setFriends(list);
  }, []);

  // Load friends & friend requests
  // dùng JSON.stringify để deep-watch mảng friends
  useEffect(() => {
    if (!userProfile) return;

    // Real-time friend requests
    const unsubReqs = subscribeToFriendRequests(userProfile.uid, setFriendRequests);

    // Load friends list
    loadFriends(userProfile.friends || []);

    return unsubReqs;
  }, [userProfile?.uid, JSON.stringify(userProfile?.friends)]);

  const handleSearch = async () => {
    if (!searchQuery.trim()) return;
    setSearching(true);
    try {
      const results = await searchUserByUsername(searchQuery.trim());
      setSearchResults(results.filter((u) => u.uid !== userProfile?.uid));
    } catch {
      Alert.alert('Lỗi', 'Không thể tìm kiếm');
    } finally {
      setSearching(false);
    }
  };

  const handleSendRequest = async (toUid: string) => {
    if (!userProfile) return;
    try {
      await sendFriendRequest(userProfile.uid, toUid);
      Alert.alert('✅', 'Đã gửi lời mời kết bạn!');
    } catch {
      Alert.alert('Lỗi', 'Không thể gửi lời mời');
    }
  };

  const handleAccept = async (req: FriendRequest) => {
    try {
      await acceptFriendRequest(req.id, req.from, req.to);
      Alert.alert('✅', `Đã kết bạn với ${req.fromUser?.displayName}!`);
      // Cập nhật danh sách bạn bè ngay lập tức (Firestore subscription sẽ tự cập nhật userProfile)
      if (req.fromUser) {
        setFriends((prev) => {
          const exists = prev.find((f) => f.uid === req.from);
          if (exists) return prev;
          return [...prev, req.fromUser as User];
        });
      }
    } catch {
      Alert.alert('Lỗi', 'Không thể chấp nhận lời mời');
    }
  };

  const handleReject = async (reqId: string) => {
    try {
      await rejectFriendRequest(reqId);
    } catch {
      Alert.alert('Lỗi', 'Không thể từ chối');
    }
  };

  const tabs: { id: Tab; label: string; count?: number }[] = [
    { id: 'friends', label: 'Bạn bè', count: friends.length },
    { id: 'requests', label: 'Lời mời', count: friendRequests.length },
    { id: 'search', label: 'Tìm kiếm' },
  ];

  const UserAvatar = ({ user, size = 44 }: { user: Partial<User>; size?: number }) => (
    <View
      style={[
        styles.avatarContainer,
        { width: size, height: size, borderRadius: size / 2 },
      ]}
    >
      {user.avatarUrl ? (
        <Image
          source={{ uri: user.avatarUrl }}
          style={{ width: size, height: size, borderRadius: size / 2 }}
        />
      ) : (
        <LinearGradient colors={Colors.gradientPrimary} style={StyleSheet.absoluteFillObject}>
          <Text style={[styles.avatarText, { fontSize: size * 0.4 }]}>
            {user.displayName?.charAt(0).toUpperCase() || '?'}
          </Text>
        </LinearGradient>
      )}
    </View>
  );

  return (
    <TouchableWithoutFeedback onPress={Keyboard.dismiss}>
    <SafeAreaView style={styles.safe}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Bạn bè</Text>
      </View>

      {/* Tabs */}
      <View style={styles.tabsContainer}>
        {tabs.map((tab) => (
          <Pressable
            key={tab.id}
            style={[styles.tab, activeTab === tab.id && styles.tabActive]}
            onPress={() => setActiveTab(tab.id)}
          >
            <Text
              style={[styles.tabText, activeTab === tab.id && styles.tabTextActive]}
            >
              {tab.label}
            </Text>
            {tab.count !== undefined && tab.count > 0 && (
              <View style={styles.tabBadge}>
                <Text style={styles.tabBadgeText}>{tab.count}</Text>
              </View>
            )}
          </Pressable>
        ))}
      </View>

      {/* Content */}
      {activeTab === 'friends' && (
        <FlatList
          data={friends}
          keyExtractor={(item) => item.uid}
          contentContainerStyle={styles.list}
          ListEmptyComponent={
            <View style={styles.empty}>
              <Text style={styles.emptyEmoji}>👥</Text>
              <Text style={styles.emptyText}>Chưa có bạn bè nào</Text>
              <Text style={styles.emptySubText}>Tìm kiếm bạn bè ở tab "Tìm kiếm"</Text>
            </View>
          }
          renderItem={({ item }) => (
            <View style={styles.friendRow}>
              <UserAvatar user={item} />
              <View style={styles.friendInfo}>
                <Text style={styles.friendName}>{item.displayName}</Text>
                <Text style={styles.friendPhone}>@{item.username || 'user'}</Text>
              </View>
              <Text style={styles.friendCheckmark}>✓</Text>
            </View>
          )}
        />
      )}

      {activeTab === 'requests' && (
        <FlatList
          data={friendRequests}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.list}
          ListEmptyComponent={
            <View style={styles.empty}>
              <Text style={styles.emptyEmoji}>📬</Text>
              <Text style={styles.emptyText}>Không có lời mời nào</Text>
            </View>
          }
          renderItem={({ item }) => (
            <View style={styles.requestRow}>
              <UserAvatar user={item.fromUser || {}} />
              <View style={styles.friendInfo}>
                <Text style={styles.friendName}>
                  {item.fromUser?.displayName || 'Người dùng'}
                </Text>
                <Text style={styles.friendPhone}>@{item.fromUser?.username || 'user'} muốn kết bạn</Text>
              </View>
              <View style={styles.requestActions}>
                <Pressable
                  style={styles.acceptBtn}
                  onPress={() => handleAccept(item)}
                >
                  <Text style={styles.acceptBtnText}>✓</Text>
                </Pressable>
                <Pressable
                  style={styles.rejectBtn}
                  onPress={() => handleReject(item.id)}
                >
                  <Text style={styles.rejectBtnText}>✕</Text>
                </Pressable>
              </View>
            </View>
          )}
        />
      )}

      {activeTab === 'search' && (
        <View style={styles.searchContainer}>
          <View style={styles.searchInputRow}>
            <View style={styles.searchInputWrapper}>
              <Text style={styles.searchIcon}>🔍</Text>
              <TextInput
                style={styles.searchInput}
                placeholder="Tìm theo username..."
                placeholderTextColor={Colors.textMuted}
                value={searchQuery}
                onChangeText={(text) => {
                  const cleaned = text.toLowerCase().replace(/[^a-z0-9_.]/g, '');
                  setSearchQuery(cleaned);
                }}
                onSubmitEditing={handleSearch}
                returnKeyType="search"
                selectionColor={Colors.primary}
              />
            </View>
            <Pressable style={styles.searchBtn} onPress={handleSearch}>
              {searching ? (
                <ActivityIndicator color={Colors.white} size="small" />
              ) : (
                <LinearGradient
                  colors={Colors.gradientPrimary}
                  style={StyleSheet.absoluteFillObject}
                />
              )}
              {!searching && <Text style={styles.searchBtnText}>Tìm</Text>}
            </Pressable>
          </View>

          <FlatList
            data={searchResults}
            keyExtractor={(item) => item.uid}
            contentContainerStyle={styles.list}
            ListEmptyComponent={
              searchQuery ? null : (
                <View style={styles.empty}>
                  <Text style={styles.emptyEmoji}>🔍</Text>
                  <Text style={styles.emptyText}>Nhập username để tìm bạn bè</Text>
                </View>
              )
            }
            renderItem={({ item }) => (
              <View style={styles.friendRow}>
                <UserAvatar user={item} />
                <View style={styles.friendInfo}>
                  <Text style={styles.friendName}>{item.displayName}</Text>
                  <Text style={styles.friendPhone}>@{item.username || 'user'}</Text>
                </View>
                <Pressable
                  style={styles.addBtn}
                  onPress={() => handleSendRequest(item.uid)}
                >
                  <LinearGradient
                    colors={Colors.gradientPrimary}
                    style={styles.addBtnGradient}
                  >
                    <Text style={styles.addBtnText}>+ Kết bạn</Text>
                  </LinearGradient>
                </Pressable>
              </View>
            )}
          />
        </View>
      )}
    </SafeAreaView>
    </TouchableWithoutFeedback>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: Colors.background },
  header: {
    paddingHorizontal: Spacing['2xl'],
    paddingTop: Spacing.base,
    paddingBottom: Spacing.base,
  },
  title: {
    fontFamily: Typography.fontFamily.extraBold,
    fontSize: Typography.fontSize['2xl'],
    color: Colors.textPrimary,
    letterSpacing: -0.5,
  },
  tabsContainer: {
    flexDirection: 'row',
    paddingHorizontal: Spacing['2xl'],
    gap: Spacing.sm,
    marginBottom: Spacing.base,
  },
  tab: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.base,
    paddingVertical: 8,
    borderRadius: BorderRadius.full,
    backgroundColor: Colors.surface,
    borderWidth: 1,
    borderColor: Colors.border,
    gap: 6,
  },
  tabActive: {
    backgroundColor: `${Colors.primary}20`,
    borderColor: Colors.primary,
  },
  tabText: {
    fontFamily: Typography.fontFamily.medium,
    fontSize: Typography.fontSize.sm,
    color: Colors.textSecondary,
  },
  tabTextActive: {
    color: Colors.primary,
    fontFamily: Typography.fontFamily.semiBold,
  },
  tabBadge: {
    backgroundColor: Colors.primary,
    borderRadius: 10,
    width: 18,
    height: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tabBadgeText: {
    fontSize: 10,
    color: Colors.white,
    fontFamily: Typography.fontFamily.bold,
  },
  list: {
    paddingHorizontal: Spacing['2xl'],
    paddingBottom: Spacing['3xl'],
  },
  friendRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: Spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
    gap: Spacing.base,
  },
  requestRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: Spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
    gap: Spacing.base,
  },
  avatarContainer: {
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.surface,
  },
  avatarText: {
    color: Colors.white,
    fontFamily: Typography.fontFamily.bold,
    textAlign: 'center',
    textAlignVertical: 'center',
    lineHeight: 44,
    width: '100%',
  },
  friendInfo: {
    flex: 1,
  },
  friendName: {
    fontFamily: Typography.fontFamily.semiBold,
    fontSize: Typography.fontSize.base,
    color: Colors.textPrimary,
  },
  friendPhone: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.sm,
    color: Colors.textMuted,
    marginTop: 2,
  },
  friendCheckmark: {
    fontSize: 20,
    color: Colors.success,
  },
  requestActions: {
    flexDirection: 'row',
    gap: Spacing.sm,
  },
  acceptBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: Colors.success,
    alignItems: 'center',
    justifyContent: 'center',
  },
  acceptBtnText: {
    color: Colors.white,
    fontSize: 16,
    fontWeight: 'bold',
  },
  rejectBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: Colors.surface,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: Colors.border,
  },
  rejectBtnText: {
    color: Colors.textSecondary,
    fontSize: 16,
  },
  addBtn: {
    borderRadius: BorderRadius.full,
    overflow: 'hidden',
  },
  addBtnGradient: {
    paddingHorizontal: 14,
    paddingVertical: 8,
  },
  addBtnText: {
    fontFamily: Typography.fontFamily.semiBold,
    fontSize: Typography.fontSize.sm,
    color: Colors.textInverse,
  },
  searchContainer: {
    flex: 1,
  },
  searchInputRow: {
    flexDirection: 'row',
    paddingHorizontal: Spacing['2xl'],
    gap: Spacing.sm,
    marginBottom: Spacing.base,
  },
  searchInputWrapper: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.lg,
    borderWidth: 1,
    borderColor: Colors.border,
    paddingHorizontal: Spacing.base,
    gap: Spacing.sm,
  },
  searchIcon: { fontSize: 16 },
  searchInput: {
    flex: 1,
    paddingVertical: 12,
    fontSize: Typography.fontSize.base,
    color: Colors.textPrimary,
    fontFamily: Typography.fontFamily.regular,
  },
  searchBtn: {
    width: 60,
    height: 48,
    borderRadius: BorderRadius.lg,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.primary,
  },
  searchBtnText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.sm,
    color: Colors.white,
  },
  empty: {
    alignItems: 'center',
    paddingTop: Spacing['4xl'],
    gap: Spacing.base,
  },
  emptyEmoji: { fontSize: 48 },
  emptyText: {
    fontFamily: Typography.fontFamily.semiBold,
    fontSize: Typography.fontSize.lg,
    color: Colors.textPrimary,
  },
  emptySubText: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.sm,
    color: Colors.textMuted,
    textAlign: 'center',
  },
});
