// ─────────────────────────────────────────────
//  Friends Screen
// ─────────────────────────────────────────────

import React, { useState, useEffect, useMemo, useCallback } from 'react';
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
import { useTranslation } from 'react-i18next';
import { useAppTheme, AppColors, Typography, Spacing, BorderRadius } from '../../constants/theme';
import { User, FriendRequest } from '../../types';
import { Users, Mailbox, Search, Check, X } from 'lucide-react-native';

type Tab = 'friends' | 'requests' | 'search';

export default function FriendsScreen() {
  const { t } = useTranslation();
  const { colors } = useAppTheme();
  const styles = useMemo(() => createStyles(colors), [colors]);
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
      Alert.alert(t('home.err.title'), t('friends.err.search'));
    } finally {
      setSearching(false);
    }
  };

  const handleSendRequest = async (toUid: string) => {
    if (!userProfile) return;
    try {
      await sendFriendRequest(userProfile.uid, toUid);
      Alert.alert(t('home.successTitle'), t('friends.success.reqSent'));
    } catch {
      Alert.alert(t('home.err.title'), t('friends.err.sendReq'));
    }
  };

  const handleAccept = async (req: FriendRequest) => {
    try {
      await acceptFriendRequest(req.id, req.from, req.to);
      Alert.alert(t('home.successTitle'), `${t('friends.success.accepted')} ${req.fromUser?.displayName}!`);
      // Cập nhật danh sách bạn bè ngay lập tức (Firestore subscription sẽ tự cập nhật userProfile)
      if (req.fromUser) {
        setFriends((prev) => {
          const exists = prev.find((f) => f.uid === req.from);
          if (exists) return prev;
          return [...prev, req.fromUser as User];
        });
      }
    } catch {
      Alert.alert(t('home.err.title'), t('friends.err.acceptReq'));
    }
  };

  const handleReject = async (reqId: string) => {
    try {
      await rejectFriendRequest(reqId);
    } catch {
      Alert.alert(t('home.err.title'), t('friends.err.rejectReq'));
    }
  };

  const tabs: { id: Tab; label: string; count?: number }[] = [
    { id: 'friends', label: t('friends.tab.friends'), count: friends.length },
    { id: 'requests', label: t('friends.tab.requests'), count: friendRequests.length },
    { id: 'search', label: t('friends.tab.search') },
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
        <LinearGradient colors={colors.gradientPrimary} style={StyleSheet.absoluteFillObject}>
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
        <Text style={styles.title}>{t('friends.title')}</Text>
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
              <Users size={48} color={colors.pearl} strokeWidth={1} style={{ marginBottom: 8 }} />
              <Text style={styles.emptyText}>{t('friends.empty.friendsTitle')}</Text>
              <Text style={styles.emptySubText}>{t('friends.empty.friendsSub')}</Text>
            </View>
          }
          renderItem={({ item }) => (
            <View style={styles.friendRow}>
              <UserAvatar user={item} />
              <View style={styles.friendInfo}>
                <Text style={styles.friendName}>{item.displayName}</Text>
                <Text style={styles.friendPhone}>@{item.username || 'user'}</Text>
              </View>
              <Check size={20} color={colors.success} strokeWidth={2} />
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
              <Mailbox size={48} color={colors.pearl} strokeWidth={1} style={{ marginBottom: 8 }} />
              <Text style={styles.emptyText}>{t('friends.empty.reqTitle')}</Text>
            </View>
          }
          renderItem={({ item }) => (
            <View style={styles.requestRow}>
              <UserAvatar user={item.fromUser || {}} />
              <View style={styles.friendInfo}>
                <Text style={styles.friendName}>
                  {item.fromUser?.displayName || t('friends.req.defaultUser')}
                </Text>
                <Text style={styles.friendPhone}>@{item.fromUser?.username || 'user'} {t('friends.req.wantsToFriend')}</Text>
              </View>
              <View style={styles.requestActions}>
                <Pressable
                  style={styles.acceptBtn}
                  onPress={() => handleAccept(item)}
                >
                  <Check size={16} color={colors.white} strokeWidth={3} />
                </Pressable>
                <Pressable
                  style={styles.rejectBtn}
                  onPress={() => handleReject(item.id)}
                >
                  <X size={16} color={colors.textSecondary} strokeWidth={2} />
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
              <Search size={16} color={colors.textMuted} strokeWidth={2} />
              <TextInput
                style={styles.searchInput}
                placeholder={t('friends.searchPlaceholder')}
                placeholderTextColor={colors.textMuted}
                value={searchQuery}
                onChangeText={(text) => {
                  const cleaned = text.toLowerCase().replace(/[^a-z0-9_.]/g, '');
                  setSearchQuery(cleaned);
                }}
                onSubmitEditing={handleSearch}
                returnKeyType="search"
                selectionColor={colors.primary}
              />
            </View>
            <Pressable style={styles.searchBtn} onPress={handleSearch}>
              {searching ? (
                <ActivityIndicator color={colors.white} size="small" />
              ) : (
                <LinearGradient
                  colors={colors.gradientPrimary}
                  style={StyleSheet.absoluteFillObject}
                />
              )}
              {!searching && <Text style={styles.searchBtnText}>{t('friends.searchBtn')}</Text>}
            </Pressable>
          </View>

          <FlatList
            data={searchResults}
            keyExtractor={(item) => item.uid}
            contentContainerStyle={styles.list}
            ListEmptyComponent={
              searchQuery ? null : (
                <View style={styles.empty}>
                  <Search size={48} color={colors.pearl} strokeWidth={1} style={{ marginBottom: 8 }} />
                  <Text style={styles.emptyText}>{t('friends.empty.searchTitle')}</Text>
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
                    colors={colors.gradientPrimary}
                    style={styles.addBtnGradient}
                  >
                    <Text style={styles.addBtnText}>{t('friends.addBtn')}</Text>
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

const createStyles = (colors: AppColors) => StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  header: {
    paddingHorizontal: Spacing['2xl'],
    paddingTop: Spacing.base,
    paddingBottom: Spacing.base,
  },
  title: {
    fontFamily: Typography.fontFamily.extraBold,
    fontSize: Typography.fontSize['2xl'],
    color: colors.textPrimary,
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
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.border,
    gap: 6,
  },
  tabActive: {
    backgroundColor: `${colors.primary}20`,
    borderColor: colors.primary,
  },
  tabText: {
    fontFamily: Typography.fontFamily.medium,
    fontSize: Typography.fontSize.sm,
    color: colors.textSecondary,
  },
  tabTextActive: {
    color: colors.primary,
    fontFamily: Typography.fontFamily.semiBold,
  },
  tabBadge: {
    backgroundColor: colors.primary,
    borderRadius: 10,
    width: 18,
    height: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tabBadgeText: {
    fontSize: 10,
    color: colors.white,
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
    borderBottomColor: colors.border,
    gap: Spacing.base,
  },
  requestRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: Spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
    gap: Spacing.base,
  },
  avatarContainer: {
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.surface,
  },
  avatarText: {
    color: colors.white,
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
    color: colors.textPrimary,
  },
  friendPhone: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.sm,
    color: colors.textMuted,
    marginTop: 2,
  },
  friendCheckmark: {
    fontSize: 20,
    color: colors.success,
  },
  requestActions: {
    flexDirection: 'row',
    gap: Spacing.sm,
  },
  acceptBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: colors.success,
    alignItems: 'center',
    justifyContent: 'center',
  },
  acceptBtnText: {
    color: colors.white,
    fontSize: 16,
    fontWeight: 'bold',
  },
  rejectBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: colors.surface,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: colors.border,
  },
  rejectBtnText: {
    color: colors.textSecondary,
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
    color: colors.textInverse,
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
    backgroundColor: colors.surface,
    borderRadius: BorderRadius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    paddingHorizontal: Spacing.base,
    gap: Spacing.sm,
  },
  searchInput: {
    flex: 1,
    paddingVertical: 12,
    fontSize: Typography.fontSize.base,
    color: colors.textPrimary,
    fontFamily: Typography.fontFamily.regular,
  },
  searchBtn: {
    width: 60,
    height: 48,
    borderRadius: BorderRadius.lg,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.primary,
  },
  searchBtnText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.sm,
    color: colors.white,
  },
  empty: {
    alignItems: 'center',
    paddingTop: Spacing['4xl'],
    gap: Spacing.base,
  },
  emptyText: {
    fontFamily: Typography.fontFamily.semiBold,
    fontSize: Typography.fontSize.lg,
    color: colors.textPrimary,
  },
  emptySubText: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.sm,
    color: colors.textMuted,
    textAlign: 'center',
  },
});
