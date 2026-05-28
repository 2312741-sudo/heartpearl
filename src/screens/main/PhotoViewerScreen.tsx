// ─────────────────────────────────────────────
//  Photo Viewer Screen — Full Screen + React
// ─────────────────────────────────────────────

import React, { useRef, useState, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Image,
  Pressable,
  Dimensions,
  Alert,
  Animated,
  Modal,
  TextInput,
  Keyboard,
  KeyboardAvoidingView,
  TouchableWithoutFeedback,
  ScrollView,
  ActivityIndicator,
  Platform,
} from 'react-native';
import { Video, ResizeMode } from 'expo-av';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp, useNavigation, useRoute } from '@react-navigation/native';
import * as ImagePicker from 'expo-image-picker';
import * as Haptics from 'expo-haptics';
import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';
import 'dayjs/locale/vi';
import { RootStackParamList } from '../../types';
import { reactToPhoto, textReactToPhoto } from '../../services/photo.service';
import { uploadPhoto } from '../../services/photo.service';
import { useAuthStore } from '../../store/auth.store';
import { useTranslation } from 'react-i18next';
import { useAppTheme, AppColors, Typography, Spacing, BorderRadius } from '../../constants/theme';
import { collection, addDoc, setDoc, doc, serverTimestamp } from 'firebase/firestore';
import { db } from '../../services/firebase.config';
import { getUserDocument } from '../../services/auth.service';

dayjs.extend(relativeTime);
dayjs.locale('vi');

const { width, height } = Dimensions.get('window');

type NavProp = NativeStackNavigationProp<RootStackParamList, 'PhotoViewer'>;
type RoutePropType = RouteProp<RootStackParamList, 'PhotoViewer'>;

type ReactionMode = 'none' | 'selfie' | 'text';

// Các emoji gợi ý nhanh
const QUICK_MESSAGES = ['❤️', '😍', '🔥', '😂', '🥺', '👏', 'Đẹp quá!', 'Thích!', 'Haha'];

export default function PhotoViewerScreen() {
  const { t } = useTranslation();
  const { colors } = useAppTheme();
  const styles = useMemo(() => createStyles(colors), [colors]);
  const navigation = useNavigation<NavProp>();
  const route = useRoute<RoutePropType>();
  const { photo } = route.params;
  const { userProfile } = useAuthStore();

  const [isReacting, setIsReacting] = useState(false);
  const [reactionMode, setReactionMode] = useState<ReactionMode>('none');
  const [textMessage, setTextMessage] = useState('');
  const [selectedReactionUrl, setSelectedReactionUrl] = useState<string | null>(null);
  const [selectedTextReaction, setSelectedTextReaction] = useState<string | null>(null);
  const reactScaleAnim = useRef(new Animated.Value(1)).current;

  // ── Selfie Reaction ──────────────────────────
  const handleSelfieReact = async () => {
    const result = await ImagePicker.launchCameraAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.7,
      cameraType: ImagePicker.CameraType.front,
    });

    if (result.canceled || !userProfile) return;

    setIsReacting(true);
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);

    try {
      const reactionUrl = await uploadPhoto(result.assets[0].uri, userProfile.uid);
      await reactToPhoto(photo.id, userProfile.uid, reactionUrl);

      // Sync to chat room
      if (photo.senderId && userProfile.uid !== photo.senderId) {
        const chatId = [userProfile.uid, photo.senderId].sort().join('_');
        
        await addDoc(collection(db, `chats/${chatId}/messages`), {
          text: t('photo.react.selfieReactText', { defaultValue: 'Đã phản hồi bằng một ảnh selfie' }),
          photoUrl: reactionUrl,
          senderId: userProfile.uid,
          type: 'reaction',
          createdAt: serverTimestamp(),
        });

        let friendName = photo.senderUser?.displayName || 'Bạn bè';
        let friendAvatar = photo.senderUser?.avatarUrl || '';

        if (!photo.senderUser?.displayName) {
          try {
            const docData = await getUserDocument(photo.senderId);
            if (docData) {
              friendName = docData.displayName || 'Bạn bè';
              friendAvatar = docData.avatarUrl || '';
            }
          } catch (err) {
            console.warn('Failed to fetch sender profile for selfie react sync:', err);
          }
        }

        const finalFriendName = friendName || 'Bạn bè';
        const finalFriendAvatar = friendAvatar || '';
        const myName = userProfile.displayName || 'Người dùng';
        const myAvatar = userProfile.avatarUrl || '';

        await setDoc(doc(db, `chats/${chatId}`), {
          participants: [userProfile.uid, photo.senderId],
          participantsInfo: {
            [userProfile.uid]: { name: myName, avatar: myAvatar },
            [photo.senderId]: { name: finalFriendName, avatar: finalFriendAvatar }
          },
          lastMessage: `📷 ${t('photo.react.selfieReactText', { defaultValue: 'Đã phản hồi bằng một ảnh selfie' })}`,
          updatedAt: serverTimestamp(),
        }, { merge: true });
      }

      Animated.sequence([
        Animated.spring(reactScaleAnim, { toValue: 1.3, useNativeDriver: true }),
        Animated.spring(reactScaleAnim, { toValue: 1, useNativeDriver: true }),
      ]).start();

      setReactionMode('none');
      Alert.alert('✅', t('photo.react.selfieSuccess'));
    } catch (err) {
      console.error('Selfie reaction sync error:', err);
      Alert.alert(t('home.err.title'), t('photo.react.errSend'));
    } finally {
      setIsReacting(false);
    }
  };

  // ── Text Reaction ────────────────────────────
  const handleTextReact = async (message: string) => {
    if (!message.trim() || !userProfile) return;
    setIsReacting(true);
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    try {
      const trimmedMessage = message.trim();
      await textReactToPhoto(photo.id, userProfile.uid, trimmedMessage);

      // Sync to chat room
      if (photo.senderId && userProfile.uid !== photo.senderId) {
        const chatId = [userProfile.uid, photo.senderId].sort().join('_');
        
        await addDoc(collection(db, `chats/${chatId}/messages`), {
          text: trimmedMessage,
          senderId: userProfile.uid,
          type: 'text',
          createdAt: serverTimestamp(),
        });

        let friendName = photo.senderUser?.displayName || 'Bạn bè';
        let friendAvatar = photo.senderUser?.avatarUrl || '';

        if (!photo.senderUser?.displayName) {
          try {
            const docData = await getUserDocument(photo.senderId);
            if (docData) {
              friendName = docData.displayName || 'Bạn bè';
              friendAvatar = docData.avatarUrl || '';
            }
          } catch (err) {
            console.warn('Failed to fetch sender profile for text react sync:', err);
          }
        }

        const finalFriendName = friendName || 'Bạn bè';
        const finalFriendAvatar = friendAvatar || '';
        const myName = userProfile.displayName || 'Người dùng';
        const myAvatar = userProfile.avatarUrl || '';

        await setDoc(doc(db, `chats/${chatId}`), {
          participants: [userProfile.uid, photo.senderId],
          participantsInfo: {
            [userProfile.uid]: { name: myName, avatar: myAvatar },
            [photo.senderId]: { name: finalFriendName, avatar: finalFriendAvatar }
          },
          lastMessage: trimmedMessage,
          updatedAt: serverTimestamp(),
        }, { merge: true });
      }

      Animated.sequence([
        Animated.spring(reactScaleAnim, { toValue: 1.2, useNativeDriver: true }),
        Animated.spring(reactScaleAnim, { toValue: 1, useNativeDriver: true }),
      ]).start();
      setReactionMode('none');
      setTextMessage('');
      Alert.alert('✅', t('photo.react.msgSuccess'));
    } catch (err) {
      console.error('Text reaction sync error:', err);
      Alert.alert(t('home.err.title'), t('photo.react.errSend'));
    } finally {
      setIsReacting(false);
    }
  };

  const [isPlaying, setIsPlaying] = useState(true);

  const myReaction = photo.reactions?.[userProfile?.uid || ''];
  const myTextReaction = photo.textReactions?.[userProfile?.uid || ''];
  const reactionEntries = Object.entries(photo.reactions || {});
  const textReactionEntries = Object.entries(photo.textReactions || {});
  const isVideo = photo.mediaType === 'video';

  return (
    <View style={styles.container}>
      {/* Full screen media */}
      {isVideo ? (
        <Pressable style={StyleSheet.absoluteFillObject} onPress={() => setIsPlaying(p => !p)}>
          <Video
            source={{ uri: photo.videoUrl || photo.imageUrl }}
            style={[styles.image, photo.isMirrored && { transform: [{ scaleX: -1 }] }]}
            posterSource={{ uri: photo.imageUrl }}
            posterStyle={{ resizeMode: 'cover' }}
            resizeMode={ResizeMode.COVER}
            shouldPlay={isPlaying}
            isLooping
            useNativeControls={false}
          />
          {!isPlaying && (
            <View style={styles.pauseOverlay}>
              <Text style={styles.pauseIcon}>▶️</Text>
            </View>
          )}
        </Pressable>
      ) : (
        <Image 
          source={{ uri: photo.imageUrl }} 
          style={[styles.image, photo.isMirrored && { transform: [{ scaleX: -1 }] }]} 
        />
      )}

      {/* Fake Beauty Filter Overlay */}
      {photo.filter && (
        <View 
          style={[
            StyleSheet.absoluteFill, 
            { backgroundColor: 'rgba(255, 235, 225, 0.12)' }
          ]} 
          pointerEvents="none" 
        />
      )}

      {/* Dark gradient overlay */}
      <LinearGradient
        colors={['rgba(0,0,0,0.6)', 'transparent', 'rgba(0,0,0,0.85)']}
        style={StyleSheet.absoluteFillObject}
        locations={[0, 0.35, 1]}
      />

      {/* Top Bar */}
      <SafeAreaView style={styles.topBar}>
        <Pressable style={styles.closeBtn} onPress={() => navigation.goBack()}>
          <Text style={styles.closeBtnText}>✕</Text>
        </Pressable>

        <View style={styles.senderInfo}>
          <View style={styles.senderAvatar}>
            <Text style={styles.senderAvatarText}>
              {photo.senderUser?.displayName?.charAt(0).toUpperCase() || '?'}
            </Text>
          </View>
          <View>
            <Text style={styles.senderName}>
              {photo.senderUser?.displayName || t('inbox.defaultSender')}
            </Text>
            <Text style={styles.sendTime}>
              {dayjs(photo.createdAt).fromNow()}
            </Text>
          </View>
        </View>
      </SafeAreaView>

      {/* Caption */}
      {photo.caption && (
        <View style={styles.captionContainer}>
          <Text style={styles.captionText}>{photo.caption}</Text>
        </View>
      )}

      {/* Selfie Reactions Row */}
      {reactionEntries.length > 0 && (
        <View style={styles.reactionsContainer}>
          {reactionEntries.slice(0, 5).map(([uid, uri]) => (
            <Pressable
              key={uid}
              style={styles.reactionItem}
              onPress={() => {
                setSelectedReactionUrl(uri);
                Haptics.selectionAsync();
              }}
            >
              <Image source={{ uri }} style={styles.reactionImage} />
            </Pressable>
          ))}
        </View>
      )}

      {/* Text Reactions Bubbles */}
      {textReactionEntries.length > 0 && (
        <View style={styles.textReactionsContainer}>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.textReactionsScroll}
          >
            {textReactionEntries.map(([uid, msg]) => (
              <Pressable
                key={uid}
                style={styles.textReactionBubble}
                onPress={() => {
                  setSelectedTextReaction(msg);
                  Haptics.selectionAsync();
                }}
              >
                <Text style={styles.textReactionText} numberOfLines={2}>
                  {msg}
                </Text>
              </Pressable>
            ))}
          </ScrollView>
        </View>
      )}

      {/* Bottom Actions */}
      <View style={styles.bottomActions}>
        {/* My selfie reaction preview */}
        {myReaction && (
          <Animated.View
            style={[styles.myReaction, { transform: [{ scale: reactScaleAnim }] }]}
          >
            <Pressable
              onPress={() => {
                setSelectedReactionUrl(myReaction);
                Haptics.selectionAsync();
              }}
            >
              <Image source={{ uri: myReaction }} style={styles.myReactionImage} />
            </Pressable>
          </Animated.View>
        )}

        {/* My text reaction preview */}
        {myTextReaction && !myReaction && (
          <Animated.View style={[styles.myTextReaction, { transform: [{ scale: reactScaleAnim }] }]}>
            <Text style={styles.myTextReactionText} numberOfLines={2}>{myTextReaction}</Text>
          </Animated.View>
        )}

        {/* React buttons row */}
        <View style={styles.reactBtnsRow}>
          {/* Selfie reaction button */}
          <Pressable
            style={({ pressed }) => [
              styles.reactBtnHalf,
              pressed && { opacity: 0.85, transform: [{ scale: 0.96 }] },
              isReacting && styles.reactBtnLoading,
            ]}
            onPress={handleSelfieReact}
            disabled={isReacting}
          >
            <LinearGradient
              colors={colors.gradientPrimary}
              style={styles.reactBtnGradient}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 0 }}
            >
              {isReacting && reactionMode !== 'text' ? (
                <ActivityIndicator color={colors.textInverse} size="small" />
              ) : (
                <Text style={styles.reactBtnText}>
                  {myReaction ? t('photo.react.changeSelfie') : t('photo.react.selfie')}
                </Text>
              )}
            </LinearGradient>
          </Pressable>

          {/* Text reaction button */}
          <Pressable
            style={({ pressed }) => [
              styles.reactBtnHalf,
              styles.reactBtnMessage,
              pressed && { opacity: 0.85, transform: [{ scale: 0.96 }] },
            ]}
            onPress={() => {
              setReactionMode('text');
              Haptics.selectionAsync();
            }}
            disabled={isReacting}
          >
            <Text style={styles.reactBtnMessageText}>
              {myTextReaction ? t('photo.react.changeMessage') : t('photo.react.message')}
            </Text>
          </Pressable>
        </View>
      </View>

      {/* ── Text Reaction Modal ── */}
      <Modal
        visible={reactionMode === 'text'}
        transparent
        animationType="slide"
        onRequestClose={() => setReactionMode('none')}
      >
        <KeyboardAvoidingView
          style={{ flex: 1 }}
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          keyboardVerticalOffset={0}
        >
          <TouchableWithoutFeedback onPress={() => { Keyboard.dismiss(); setReactionMode('none'); }}>
            <View style={styles.textModalOverlay}>
              <TouchableWithoutFeedback onPress={(e) => e.stopPropagation()}>
                <View style={styles.textModalContent}>
                  <View style={styles.textModalHandle} />
                  <Text style={styles.textModalTitle}>{t('photo.react.sendMsg')}</Text>

                  {/* Quick messages — luôn hiện trước bàn phím */}
                  <ScrollView
                    horizontal
                    showsHorizontalScrollIndicator={false}
                    style={styles.quickRow}
                    contentContainerStyle={styles.quickRowContent}
                    keyboardShouldPersistTaps="always"
                  >
                    {QUICK_MESSAGES.map((msg) => (
                      <Pressable
                        key={msg}
                        style={({ pressed }) => [
                          styles.quickChip,
                          pressed && { opacity: 0.7, transform: [{ scale: 0.95 }] },
                        ]}
                        onPress={() => {
                          Keyboard.dismiss();
                          handleTextReact(msg);
                        }}
                      >
                        <Text style={styles.quickChipText}>{msg}</Text>
                      </Pressable>
                    ))}
                  </ScrollView>

                  {/* Custom input */}
                  <View style={styles.textInputRow}>
                    <TextInput
                      style={styles.textInput}
                      placeholder={t('photo.react.msgPlaceholder')}
                      placeholderTextColor={colors.textMuted}
                      value={textMessage}
                      onChangeText={setTextMessage}
                      maxLength={120}
                      returnKeyType="send"
                      onSubmitEditing={() => handleTextReact(textMessage)}
                      selectionColor={colors.primary}
                    />
                    <Pressable
                      style={[
                        styles.sendMsgBtn,
                        (!textMessage.trim() || isReacting) && { opacity: 0.4 },
                      ]}
                      onPress={() => handleTextReact(textMessage)}
                      disabled={!textMessage.trim() || isReacting}
                    >
                      {isReacting ? (
                        <ActivityIndicator color={colors.white} size="small" />
                      ) : (
                        <LinearGradient
                          colors={colors.gradientPrimary}
                          style={StyleSheet.absoluteFillObject}
                          start={{ x: 0, y: 0 }}
                          end={{ x: 1, y: 0 }}
                        />
                      )}
                      {!isReacting && <Text style={styles.sendMsgBtnText}>{t('home.send')}</Text>}
                    </Pressable>
                  </View>

                  <Pressable
                    style={styles.cancelTextBtn}
                    onPress={() => { setReactionMode('none'); setTextMessage(''); }}
                  >
                    <Text style={styles.cancelTextBtnText}>{t('common.cancel')}</Text>
                  </Pressable>
                </View>
              </TouchableWithoutFeedback>
            </View>
          </TouchableWithoutFeedback>
        </KeyboardAvoidingView>
      </Modal>

      {/* ── Large Selfie Reaction Viewer Modal ── */}
      <Modal
        visible={!!selectedReactionUrl}
        transparent
        animationType="fade"
        onRequestClose={() => setSelectedReactionUrl(null)}
      >
        <Pressable
          style={styles.modalOverlay}
          onPress={() => setSelectedReactionUrl(null)}
        >
          <View style={styles.modalContent}>
            {selectedReactionUrl && (
              <Image
                source={{ uri: selectedReactionUrl }}
                style={styles.largeReactionImage}
              />
            )}
            <Text style={styles.modalCloseHint}>{t('photo.react.closeHint1')}</Text>
          </View>
        </Pressable>
      </Modal>

      {/* ── Large Text Reaction Modal ── */}
      <Modal
        visible={!!selectedTextReaction}
        transparent
        animationType="fade"
        onRequestClose={() => setSelectedTextReaction(null)}
      >
        <Pressable
          style={styles.modalOverlay}
          onPress={() => setSelectedTextReaction(null)}
        >
          <View style={styles.textReactionModal}>
            <Text style={styles.textReactionModalEmoji}>💬</Text>
            <Text style={styles.textReactionModalText}>{selectedTextReaction}</Text>
            <Text style={styles.modalCloseHint}>{t('photo.react.closeHint2')}</Text>
          </View>
        </Pressable>
      </Modal>
    </View>
  );
}

const createStyles = (colors: AppColors) => StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.black,
  },
  image: {
    ...StyleSheet.absoluteFillObject,
    resizeMode: 'cover',
  },
  pauseOverlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(0,0,0,0.3)',
  },
  pauseIcon: { fontSize: 60 },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing['2xl'],
    paddingTop: 8,
    gap: Spacing.base,
  },
  closeBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(0,0,0,0.5)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  closeBtnText: {
    color: colors.white,
    fontSize: 18,
    fontWeight: 'bold',
  },
  senderInfo: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.md,
  },
  senderAvatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: colors.white,
  },
  senderAvatarText: {
    color: colors.white,
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.base,
  },
  senderName: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.base,
    color: colors.white,
  },
  sendTime: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.sm,
    color: 'rgba(255,255,255,0.7)',
  },
  captionContainer: {
    position: 'absolute',
    bottom: 210,
    left: Spacing['2xl'],
    right: Spacing['2xl'],
    backgroundColor: 'rgba(0,0,0,0.5)',
    borderRadius: BorderRadius.lg,
    padding: Spacing.base,
  },
  captionText: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.base,
    color: colors.white,
    textAlign: 'center',
    lineHeight: 22,
  },
  // Selfie reactions
  reactionsContainer: {
    position: 'absolute',
    bottom: 170,
    left: Spacing['2xl'],
    flexDirection: 'row',
  },
  reactionItem: {
    marginRight: 6,
    borderRadius: BorderRadius.full,
    overflow: 'hidden',
    borderWidth: 2,
    borderColor: colors.white,
  },
  reactionImage: {
    width: 44,
    height: 44,
    borderRadius: 22,
  },
  // Text reactions
  textReactionsContainer: {
    position: 'absolute',
    bottom: 220,
    left: 0,
    right: 0,
  },
  textReactionsScroll: {
    paddingHorizontal: Spacing['2xl'],
    gap: Spacing.sm,
  },
  textReactionBubble: {
    backgroundColor: 'rgba(255,255,255,0.18)',
    borderRadius: BorderRadius.xl,
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.3)',
    maxWidth: 180,
  },
  textReactionText: {
    fontFamily: Typography.fontFamily.medium,
    fontSize: Typography.fontSize.sm,
    color: colors.white,
  },
  // Bottom actions
  bottomActions: {
    position: 'absolute',
    bottom: 40,
    left: Spacing['2xl'],
    right: Spacing['2xl'],
    gap: Spacing.md,
    alignItems: 'center',
  },
  myReaction: {
    borderRadius: BorderRadius.full,
    overflow: 'hidden',
    borderWidth: 3,
    borderColor: colors.primary,
    shadowColor: colors.primary,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.7,
    shadowRadius: 10,
    elevation: 8,
  },
  myReactionImage: {
    width: 64,
    height: 64,
    borderRadius: 32,
  },
  myTextReaction: {
    backgroundColor: `${colors.primary}30`,
    borderRadius: BorderRadius.xl,
    borderWidth: 2,
    borderColor: colors.primary,
    paddingHorizontal: 16,
    paddingVertical: 10,
    maxWidth: width * 0.7,
  },
  myTextReactionText: {
    fontFamily: Typography.fontFamily.semiBold,
    fontSize: Typography.fontSize.base,
    color: colors.white,
    textAlign: 'center',
  },
  reactBtnsRow: {
    flexDirection: 'row',
    gap: Spacing.sm,
    width: '100%',
  },
  reactBtnHalf: {
    flex: 1,
    borderRadius: BorderRadius.full,
    overflow: 'hidden',
    shadowColor: colors.primary,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 10,
    elevation: 8,
  },
  reactBtnMessage: {
    backgroundColor: 'rgba(255,255,255,0.15)',
    borderWidth: 1.5,
    borderColor: 'rgba(255,255,255,0.4)',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 14,
  },
  reactBtnLoading: { opacity: 0.7 },
  reactBtnGradient: {
    paddingVertical: 14,
    alignItems: 'center',
  },
  reactBtnText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.base,
    color: colors.textInverse,
  },
  reactBtnMessageText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.base,
    color: colors.white,
  },
  // Text modal
  textModalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'flex-end',
  },
  textModalContent: {
    backgroundColor: colors.surface,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    paddingTop: 12,
    paddingBottom: 36,
    paddingHorizontal: Spacing['2xl'],
    gap: Spacing.base,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
  textModalHandle: {
    width: 36,
    height: 4,
    borderRadius: 2,
    backgroundColor: colors.border,
    alignSelf: 'center',
    marginBottom: 4,
  },
  textModalTitle: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.lg,
    color: colors.textPrimary,
    textAlign: 'center',
    marginBottom: 4,
  },
  quickRow: { flexGrow: 0 },
  quickRowContent: {
    gap: Spacing.sm,
    paddingVertical: 4,
  },
  quickChip: {
    backgroundColor: `${colors.primary}20`,
    borderRadius: BorderRadius.full,
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderWidth: 1.5,
    borderColor: `${colors.primary}50`,
  },
  quickChipText: {
    fontFamily: Typography.fontFamily.medium,
    fontSize: Typography.fontSize.base,
    color: colors.primary,
  },
  textInputRow: {
    flexDirection: 'row',
    gap: Spacing.sm,
    alignItems: 'flex-end',
  },
  textInput: {
    flex: 1,
    backgroundColor: colors.background,
    borderRadius: BorderRadius.lg,
    paddingHorizontal: Spacing.base,
    paddingVertical: 12,
    color: colors.textPrimary,
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.base,
    borderWidth: 1,
    borderColor: colors.border,
    maxHeight: 100,
  },
  sendMsgBtn: {
    width: 52,
    height: 52,
    borderRadius: 26,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.primary,
  },
  sendMsgBtnText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.sm,
    color: colors.white,
  },
  cancelTextBtn: {
    alignItems: 'center',
    paddingVertical: 8,
  },
  cancelTextBtnText: {
    fontFamily: Typography.fontFamily.medium,
    fontSize: Typography.fontSize.base,
    color: colors.textMuted,
  },
  // Selfie large view modal
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.88)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    width: width * 0.85,
    height: width * 0.85,
    borderRadius: BorderRadius.xl,
    overflow: 'hidden',
    borderWidth: 3,
    borderColor: colors.white,
    position: 'relative',
  },
  largeReactionImage: {
    width: '100%',
    height: '100%',
    resizeMode: 'cover',
  },
  modalCloseHint: {
    position: 'absolute',
    bottom: -40,
    alignSelf: 'center',
    color: 'rgba(255,255,255,0.65)',
    fontFamily: Typography.fontFamily.medium,
    fontSize: Typography.fontSize.sm,
  },
  // Text reaction large modal
  textReactionModal: {
    backgroundColor: colors.surface,
    borderRadius: BorderRadius['2xl'],
    padding: Spacing['3xl'],
    marginHorizontal: Spacing['2xl'],
    alignItems: 'center',
    gap: Spacing.base,
    borderWidth: 1,
    borderColor: colors.border,
  },
  textReactionModalEmoji: { fontSize: 40 },
  textReactionModalText: {
    fontFamily: Typography.fontFamily.semiBold,
    fontSize: Typography.fontSize.xl,
    color: colors.textPrimary,
    textAlign: 'center',
    lineHeight: 28,
  },
});
