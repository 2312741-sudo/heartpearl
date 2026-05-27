// ─────────────────────────────────────────────
//  Inbox Screen — Realtime Photo Feed
// ─────────────────────────────────────────────

import React, { useEffect, useState, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  Image,
  Dimensions,
  Animated,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';
import 'dayjs/locale/vi';
import { subscribeToInbox, markPhotoAsSeen } from '../../services/photo.service';
import { useAuthStore } from '../../store/auth.store';
import { usePhotoStore } from '../../store/photo.store';
import { Colors, Typography, Spacing, BorderRadius } from '../../constants/theme';
import { Photo, RootStackParamList } from '../../types';
import { Mailbox, Play, Sparkles } from 'lucide-react-native';

dayjs.extend(relativeTime);
dayjs.locale('vi');

const { width } = Dimensions.get('window');
const CARD_SIZE = (width - Spacing['2xl'] * 2 - Spacing.base) / 2;

type NavProp = NativeStackNavigationProp<RootStackParamList>;

function PhotoCard({ photo, userId }: { photo: Photo; userId: string }) {
  const navigation = useNavigation<NavProp>();
  const scaleAnim = useRef(new Animated.Value(0.95)).current;
  const isNew = !photo.seen?.[userId];

  useEffect(() => {
    Animated.spring(scaleAnim, {
      toValue: 1,
      useNativeDriver: true,
      delay: 100,
    }).start();
  }, []);

  const handlePress = () => {
    markPhotoAsSeen(photo.id, userId);
    navigation.navigate('PhotoViewer', { photo });
  };

  return (
    <Animated.View style={{ transform: [{ scale: scaleAnim }] }}>
      <Pressable
        style={({ pressed }) => [
          styles.card,
          pressed && { opacity: 0.9 },
        ]}
        onPress={handlePress}
      >
        <Image 
          source={{ uri: photo.imageUrl }} 
          style={[styles.cardImage, photo.isMirrored && { transform: [{ scaleX: -1 }] }]} 
        />
        {photo.filter && (
          <View 
            style={[
              StyleSheet.absoluteFill, 
              { backgroundColor: 'rgba(255, 235, 225, 0.12)', borderRadius: 14 }
            ]} 
            pointerEvents="none" 
          />
        )}

        {/* Gradient overlay */}
        <LinearGradient
          colors={['transparent', 'rgba(0,0,0,0.75)']}
          style={styles.cardGradient}
        />

        {/* New badge */}
        {isNew && (
          <View style={styles.newBadge}>
            <LinearGradient
              colors={Colors.gradientPrimary}
              style={styles.newBadgeGradient}
            >
              <Text style={styles.newBadgeText}>Mới</Text>
            </LinearGradient>
          </View>
        )}

        {/* Video badge */}
        {photo.mediaType === 'video' && (
          <View style={styles.videoBadge}>
            <Play size={14} color={Colors.pearl} strokeWidth={2} />
          </View>
        )}

        {/* Card footer */}
        <View style={styles.cardFooter}>
          <Text style={styles.senderName} numberOfLines={1}>
            {photo.senderUser?.displayName || 'Bạn bè'}
          </Text>
          <Text style={styles.timeText}>
            {dayjs(photo.createdAt).fromNow()}
          </Text>
        </View>

        {/* Reactions */}
        {Object.keys(photo.reactions || {}).length > 0 && (
          <View style={styles.reactionsRow}>
            {Object.values(photo.reactions)
              .slice(0, 3)
              .map((uri, i) => (
                <Image
                  key={i}
                  source={{ uri }}
                  style={[styles.reactionThumb, { marginLeft: i > 0 ? -8 : 0 }]}
                />
              ))}
          </View>
        )}

        {/* Caption */}
        {photo.caption && (
          <View style={styles.captionBubble}>
            <Text style={styles.captionText} numberOfLines={2}>
              {photo.caption}
            </Text>
          </View>
        )}
      </Pressable>
    </Animated.View>
  );
}

export default function InboxScreen() {
  const { userProfile } = useAuthStore();
  const { inbox, setInbox } = usePhotoStore();

  useEffect(() => {
    if (!userProfile) return;
    const unsubscribe = subscribeToInbox(userProfile.uid, setInbox);
    return unsubscribe;
  }, [userProfile]);

  const newCount = inbox.filter((p) => !p.seen?.[userProfile?.uid || '']).length;

  return (
    <SafeAreaView style={styles.safe}>
      {/* Header */}
      <View style={styles.header}>
        <View>
          <Text style={styles.headerTitle}>Inbox</Text>
          {newCount > 0 && (
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 2 }}>
              <Text style={styles.headerSubtitle}>
                {newCount} ảnh mới từ bạn bè
              </Text>
              <Sparkles size={14} color={Colors.primaryLight} strokeWidth={2} />
            </View>
          )}
        </View>
        <View style={styles.headerRight}>
          {newCount > 0 && (
            <View style={styles.countBadge}>
              <Text style={styles.countBadgeText}>{newCount}</Text>
            </View>
          )}
        </View>
      </View>

      {/* Photo Grid */}
      {inbox.length === 0 ? (
        <View style={styles.emptyContainer}>
          <Mailbox size={64} color={Colors.pearl} strokeWidth={1} style={{ marginBottom: 16 }} />
          <Text style={styles.emptyTitle}>Chưa có ảnh nào</Text>
          <Text style={styles.emptySubtitle}>
            Khi bạn bè gửi ảnh, chúng sẽ xuất hiện ở đây nhé!
          </Text>
        </View>
      ) : (
        <FlatList
          data={inbox}
          keyExtractor={(item) => item.id}
          numColumns={2}
          contentContainerStyle={styles.grid}
          columnWrapperStyle={styles.gridRow}
          showsVerticalScrollIndicator={false}
          renderItem={({ item }) => (
            <PhotoCard
              photo={item}
              userId={userProfile?.uid || ''}
            />
          )}
        />
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing['2xl'],
    paddingTop: Spacing.base,
    paddingBottom: Spacing.lg,
  },
  headerTitle: {
    fontFamily: Typography.fontFamily.extraBold,
    fontSize: Typography.fontSize['2xl'],
    color: Colors.textPrimary,
    letterSpacing: -0.5,
  },
  headerSubtitle: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.sm,
    color: Colors.textSecondary,
    marginTop: 2,
  },
  headerRight: {
    alignItems: 'flex-end',
    paddingTop: 4,
  },
  countBadge: {
    backgroundColor: Colors.primary,
    borderRadius: BorderRadius.full,
    paddingHorizontal: 10,
    paddingVertical: 3,
    minWidth: 28,
    alignItems: 'center',
  },
  countBadgeText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.sm,
    color: Colors.white,
  },
  grid: {
    paddingHorizontal: Spacing['2xl'],
    paddingBottom: Spacing['3xl'],
  },
  gridRow: {
    gap: Spacing.base,
    marginBottom: Spacing.base,
  },
  card: {
    width: CARD_SIZE,
    height: CARD_SIZE * 1.25,
    borderRadius: 20,
    backgroundColor: Colors.surface,
    borderWidth: 1,
    borderColor: Colors.border,
    padding: 4,
  },
  cardImage: {
    width: '100%',
    height: '100%',
    position: 'absolute',
    top: 4,
    left: 4,
    borderRadius: 14,
    resizeMode: 'cover',
  },
  cardGradient: {
    position: 'absolute',
    bottom: 4,
    left: 4,
    right: 4,
    height: '60%',
    borderBottomLeftRadius: 14,
    borderBottomRightRadius: 14,
  },
  newBadge: {
    position: 'absolute',
    top: 10,
    right: 10,
    borderRadius: BorderRadius.full,
    overflow: 'hidden',
  },
  newBadgeGradient: {
    paddingHorizontal: 8,
    paddingVertical: 3,
  },
  newBadgeText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.xs,
    color: Colors.textInverse,
  },
  videoBadge: {
    position: 'absolute',
    top: 10,
    left: 10,
    backgroundColor: 'rgba(0,0,0,0.6)',
    borderRadius: BorderRadius.full,
    paddingHorizontal: 6,
    paddingVertical: 3,
  },
  videoBadgeText: {
    fontSize: 14,
  },
  cardFooter: {
    position: 'absolute',
    bottom: 10,
    left: 10,
    right: 10,
  },
  senderName: {
    fontFamily: Typography.fontFamily.semiBold,
    fontSize: Typography.fontSize.sm,
    color: Colors.white,
  },
  timeText: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.xs,
    color: 'rgba(255,255,255,0.7)',
    marginTop: 2,
  },
  reactionsRow: {
    position: 'absolute',
    top: 10,
    left: 10,
    flexDirection: 'row',
  },
  reactionThumb: {
    width: 24,
    height: 24,
    borderRadius: 12,
    borderWidth: 1.5,
    borderColor: Colors.white,
  },
  captionBubble: {
    position: 'absolute',
    bottom: 42,
    left: 8,
    right: 8,
    backgroundColor: 'rgba(0,0,0,0.5)',
    borderRadius: BorderRadius.sm,
    paddingHorizontal: 6,
    paddingVertical: 4,
  },
  captionText: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: 10,
    color: Colors.white,
  },
  // Empty
  emptyContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.base,
    paddingHorizontal: Spacing['3xl'],
  },
  emptyTitle: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.xl,
    color: Colors.textPrimary,
  },
  emptySubtitle: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.base,
    color: Colors.textSecondary,
    textAlign: 'center',
    lineHeight: 22,
  },
});
