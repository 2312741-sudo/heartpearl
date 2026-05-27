// ─────────────────────────────────────────────
//  History Screen — Photo Grid by Date
// ─────────────────────────────────────────────

import React, { useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Image,
  Pressable,
  Dimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import dayjs from 'dayjs';
import { subscribeToSentPhotos } from '../../services/photo.service';
import { useAuthStore } from '../../store/auth.store';
import { usePhotoStore } from '../../store/photo.store';
import { Colors, Typography, Spacing, BorderRadius } from '../../constants/theme';
import { Photo, RootStackParamList } from '../../types';
import { CalendarHeart, Heart } from 'lucide-react-native';

const { width } = Dimensions.get('window');
const THUMB_SIZE = (width - Spacing['2xl'] * 2 - Spacing.sm * 2) / 3;

type NavProp = NativeStackNavigationProp<RootStackParamList>;

export default function HistoryScreen() {
  const { userProfile } = useAuthStore();
  const { sentPhotos, setSentPhotos } = usePhotoStore();
  const navigation = useNavigation<NavProp>();

  useEffect(() => {
    if (!userProfile) return;
    const unsubscribe = subscribeToSentPhotos(userProfile.uid, setSentPhotos);
    return unsubscribe;
  }, [userProfile]);

  // Group by date
  const grouped = sentPhotos.reduce<Record<string, Photo[]>>((acc, photo) => {
    const date = dayjs(photo.createdAt).format('DD/MM/YYYY');
    if (!acc[date]) acc[date] = [];
    acc[date].push(photo);
    return acc;
  }, {});

  const sections = Object.entries(grouped).map(([date, photos]) => ({
    date,
    photos,
  }));

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.header}>
        <Text style={styles.title}>Lịch sử</Text>
        <Text style={styles.subtitle}>{sentPhotos.length} ảnh đã gửi</Text>
      </View>

      {sections.length === 0 ? (
        <View style={styles.empty}>
          <CalendarHeart size={64} color={Colors.pearl} strokeWidth={1} style={{ marginBottom: 16 }} />
          <Text style={styles.emptyTitle}>Chưa có ảnh nào</Text>
          <Text style={styles.emptySubtitle}>
            Các ảnh bạn đã gửi sẽ xuất hiện ở đây
          </Text>
        </View>
      ) : (
        <FlatList
          data={sections}
          keyExtractor={(item) => item.date}
          contentContainerStyle={styles.content}
          showsVerticalScrollIndicator={false}
          renderItem={({ item }) => (
            <View style={styles.section}>
              <Text style={styles.sectionDate}>{item.date}</Text>
              <View style={styles.photoGrid}>
                {item.photos.map((photo) => (
                  <Pressable
                    key={photo.id}
                    style={({ pressed }) => [
                      styles.thumb,
                      pressed && { opacity: 0.85 },
                    ]}
                    onPress={() => navigation.navigate('PhotoViewer', { photo })}
                  >
                    <Image 
                      source={{ uri: photo.imageUrl }} 
                      style={[styles.thumbImage, photo.isMirrored && { transform: [{ scaleX: -1 }] }]} 
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
                    {Object.keys(photo.reactions || {}).length > 0 && (
                      <View style={styles.reactionIndicator}>
                        <Heart size={10} color={Colors.primary} fill={Colors.primary} />
                        <Text style={styles.reactionIndicatorText}>
                          {Object.keys(photo.reactions).length}
                        </Text>
                      </View>
                    )}
                  </Pressable>
                ))}
              </View>
            </View>
          )}
        />
      )}
    </SafeAreaView>
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
  subtitle: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.sm,
    color: Colors.textSecondary,
    marginTop: 2,
  },
  content: {
    paddingHorizontal: Spacing['2xl'],
    paddingBottom: Spacing['3xl'],
  },
  section: {
    marginBottom: Spacing['2xl'],
  },
  sectionDate: {
    fontFamily: Typography.fontFamily.semiBold,
    fontSize: Typography.fontSize.sm,
    color: Colors.textSecondary,
    marginBottom: Spacing.md,
    textTransform: 'uppercase',
    letterSpacing: 0.8,
  },
  photoGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.sm,
  },
  thumb: {
    width: THUMB_SIZE,
    height: THUMB_SIZE,
    borderRadius: 20,
    backgroundColor: Colors.surface,
    borderWidth: 1,
    borderColor: Colors.border,
    padding: 4,
  },
  thumbImage: {
    width: '100%',
    height: '100%',
    resizeMode: 'cover',
    borderRadius: 14,
  },
  reactionIndicator: {
    position: 'absolute',
    bottom: 8,
    right: 8,
    backgroundColor: Colors.surface,
    borderColor: Colors.border,
    borderWidth: 1,
    borderRadius: BorderRadius.full,
    paddingHorizontal: 6,
    paddingVertical: 4,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  reactionIndicatorText: {
    fontSize: 10,
    color: Colors.pearl,
    fontFamily: Typography.fontFamily.semiBold,
  },
  empty: {
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
  },
});
