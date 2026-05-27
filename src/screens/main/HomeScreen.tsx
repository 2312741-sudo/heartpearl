// ─────────────────────────────────────────────
//  Home Screen — Camera (Chụp ảnh + Quay video)
// ─────────────────────────────────────────────

import React, { useState, useRef, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  Dimensions,
  Image,
  Alert,
  TextInput,
  Animated,
  ActivityIndicator,
  Keyboard,
  TouchableWithoutFeedback,
  PanResponder,
  FlatList,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { CameraView, CameraType, FlashMode, useCameraPermissions, useMicrophonePermissions } from 'expo-camera';
import { Video, ResizeMode } from 'expo-av';
import * as VideoThumbnails from 'expo-video-thumbnails';
import Slider from '@react-native-community/slider';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { Camera as CameraIcon, Send, Sparkles, RefreshCcw, Zap, ZapOff, Check, X, Users, AlertCircle, Play } from 'lucide-react-native';
import { useAuthStore } from '../../store/auth.store';
import { usePhotoStore } from '../../store/photo.store';
import { uploadPhoto, sendPhoto, uploadVideo } from '../../services/photo.service';
import { getFriendsList } from '../../services/friend.service';
import { Colors, Typography, Spacing, BorderRadius } from '../../constants/theme';
import { User } from '../../types';

const { width, height } = Dimensions.get('window');

const MAX_VIDEO_DURATION = 15; // giây

export default function HomeScreen() {
  const [permission, requestPermission] = useCameraPermissions();
  const [micPermission, requestMicPermission] = useMicrophonePermissions();
  const [facing, setFacing] = useState<CameraType>('back');
  const [capturedImage, setCapturedImage] = useState<string | null>(null);
  const [capturedVideo, setCapturedVideo] = useState<string | null>(null);
  const [caption, setCaption] = useState('');
  const [friends, setFriends] = useState<User[]>([]);
  const [selectedFriends, setSelectedFriends] = useState<string[]>([]);
  const [showFriendPicker, setShowFriendPicker] = useState(false);

  // Camera controls
  const [flash, setFlash] = useState<FlashMode>('off');
  const [zoom, setZoom] = useState(0);          // 0 = 1x, 0.5 = 2x...
  const [zoomDisplay, setZoomDisplay] = useState(1.0); // label hiển thị
  const zoomBaseRef = useRef(0);                // zoom khi bắt đầu pinch
  const lastPinchDistRef = useRef<number | null>(null);

  // Pinch-to-zoom PanResponder
  const pinchResponder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: (_, gs) => gs.numberActiveTouches === 2,
      onMoveShouldSetPanResponder: (_, gs) => gs.numberActiveTouches === 2,
      onPanResponderGrant: () => {
        lastPinchDistRef.current = null;
        zoomBaseRef.current = zoom;
      },
      onPanResponderMove: (evt) => {
        const touches = evt.nativeEvent.touches;
        if (touches.length < 2) return;
        const dx = touches[0].pageX - touches[1].pageX;
        const dy = touches[0].pageY - touches[1].pageY;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (lastPinchDistRef.current === null) {
          lastPinchDistRef.current = dist;
          return;
        }
        const delta = (dist - lastPinchDistRef.current) / 300;
        lastPinchDistRef.current = dist;
        setZoom(prev => {
          const next = Math.max(0, Math.min(1, prev + delta));
          setZoomDisplay(parseFloat((1 + next * 4).toFixed(1)));
          return next;
        });
      },
      onPanResponderRelease: () => { lastPinchDistRef.current = null; },
    })
  ).current;

  // Video recording
  const [isRecording, setIsRecording] = useState(false);
  const isRecordingRef = useRef(false);
  const pressingRef = useRef(false);       // đồng hồ bận quấn tỏ khi PressIn
  const pressStartTimeRef = useRef(0);    // thời điểm bắt đầu giữ
  const videoStartedRef = useRef(false);  // recordAsync đã bắt đầu chưa
  const [recordProgress, setRecordProgress] = useState(0);
  const recordTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const recordStartTime = useRef<number>(0);
  const captureRingAnim = useRef(new Animated.Value(0)).current;

  const cameraRef = useRef<CameraView>(null);
  const captureScale = useRef(new Animated.Value(1)).current;
  const { userProfile, firebaseUser } = useAuthStore();
  const { isUploading, uploadProgress, setUploading, setUploadProgress } = usePhotoStore();

  // Load friends — deep-watch mảng friends
  useEffect(() => {
    if (userProfile?.friends?.length) {
      getFriendsList(userProfile.friends).then(setFriends);
    } else {
      setFriends([]);
    }
  }, [userProfile?.uid, JSON.stringify(userProfile?.friends)]);

  // ── Capture animation ──────────────────────
  const animateCapture = () => {
    Animated.sequence([
      Animated.timing(captureScale, { toValue: 0.88, duration: 100, useNativeDriver: true }),
      Animated.spring(captureScale, { toValue: 1, useNativeDriver: true }),
    ]).start();
  };

  // ── Chụp ảnh ──────────────────────────────
  const takePicture = async () => {
    if (!cameraRef.current || isRecordingRef.current) return;
    try {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
      animateCapture();
      const photo = await cameraRef.current.takePictureAsync({ quality: 0.85 });
      if (photo) setCapturedImage(photo.uri);
    } catch {
      Alert.alert('Lỗi', 'Không thể chụp ảnh');
    }
  };

  // ── Dừng record (không stale closure) ─────────────────────────
  const stopRecordingInternal = useCallback((saveVideo = true) => {
    if (!isRecordingRef.current) return;
    isRecordingRef.current = false;
    if (recordTimerRef.current) {
      clearInterval(recordTimerRef.current);
      recordTimerRef.current = null;
    }
    captureRingAnim.stopAnimation();
    Animated.timing(captureRingAnim, { toValue: 0, duration: 150, useNativeDriver: true }).start();
    cameraRef.current?.stopRecording();
    setIsRecording(false);
    setRecordProgress(0);
    // Nếu saveVideo=false thì xoá video sau khi recordAsync resolve
    if (!saveVideo) {
      setCapturedVideo(null);
    }
  }, []);

  // ── Bắt đầu record ngay lập tức ────────────────────────────────
  const startRecordingImmediate = useCallback(async () => {
    if (!cameraRef.current || isRecordingRef.current) return;

    if (!micPermission?.granted) {
      const result = await requestMicPermission();
      if (!result.granted) {
        Alert.alert('Cần quyền Microphone', 'Cấp quyền mic để quay video');
        return;
      }
    }

    isRecordingRef.current = true;
    setIsRecording(true);
    setRecordProgress(0);
    recordStartTime.current = Date.now();
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);

    Animated.loop(
      Animated.sequence([
        Animated.timing(captureRingAnim, { toValue: 1, duration: 500, useNativeDriver: true }),
        Animated.timing(captureRingAnim, { toValue: 0.5, duration: 500, useNativeDriver: true }),
      ])
    ).start();

    recordTimerRef.current = setInterval(() => {
      const elapsed = (Date.now() - recordStartTime.current) / 1000;
      setRecordProgress(Math.min(elapsed / MAX_VIDEO_DURATION, 1));
      if (elapsed >= MAX_VIDEO_DURATION) stopRecordingInternal(true);
    }, 80);

    try {
      const video = await cameraRef.current.recordAsync({ maxDuration: MAX_VIDEO_DURATION });
      // recordAsync resolve sau khi stopRecording được gọi
      // Chỉ set video nếu isRecordingRef đã false (nghĩa là đã stop đúng cách)
      if (video?.uri && !pressingRef.current) {
        setCapturedVideo(video.uri);
      }
    } catch {
      // Bị hủy bình thường
    }
  }, [micPermission, stopRecordingInternal]);

  // ── PressIn: bắt đầu record ngay, lưu thời gian ───────────────
  const handlePressIn = useCallback(() => {
    pressingRef.current = true;
    pressStartTimeRef.current = Date.now();
    startRecordingImmediate();
  }, [startRecordingImmediate]);

  // ── PressOut: tap ngắn (<350ms) → hủy video, chụp ảnh ────────
  const handlePressOut = useCallback(() => {
    pressingRef.current = false;
    const holdMs = Date.now() - pressStartTimeRef.current;

    if (holdMs < 350) {
      // Tap ngắn → hủy video (không lưu), chụp ảnh
      isRecordingRef.current = false;
      if (recordTimerRef.current) { clearInterval(recordTimerRef.current); recordTimerRef.current = null; }
      captureRingAnim.stopAnimation();
      Animated.timing(captureRingAnim, { toValue: 0, duration: 100, useNativeDriver: true }).start();
      cameraRef.current?.stopRecording();
      setIsRecording(false);
      setRecordProgress(0);
      // Chờ camera ổn định rồi chụp ảnh
      setTimeout(() => {
        if (!isRecordingRef.current) takePicture();
      }, 120);
    } else {
      // Giữ dài → dừng và lưu video
      stopRecordingInternal(true);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    }
  }, [stopRecordingInternal]);

  const toggleFacing = () => {
    Haptics.selectionAsync();
    setFacing((prev) => (prev === 'back' ? 'front' : 'back'));
  };

  const toggleFriend = (uid: string) => {
    setSelectedFriends((prev) =>
      prev.includes(uid) ? prev.filter((id) => id !== uid) : [...prev, uid]
    );
    Haptics.selectionAsync();
  };

  // ── Gửi ảnh/video ──────────────────────────
  const handleSend = async () => {
    const media = capturedImage || capturedVideo;
    if (!media) return;

    let currentProfile = userProfile;
    if (!currentProfile) {
      Alert.alert('Đang đồng bộ', 'Hệ thống đang tải thông tin, vui lòng đợi vài giây rồi gửi lại!');
      const { getUserDocument, createUserDocument } = require('../../services/auth.service');
      if (firebaseUser?.uid) {
        try {
          let docData = await getUserDocument(firebaseUser.uid);
          if (!docData) {
            await createUserDocument(firebaseUser, { displayName: firebaseUser.displayName || 'Người dùng' });
            docData = await getUserDocument(firebaseUser.uid);
          }
          if (docData) useAuthStore.getState().setUserProfile(docData);
        } catch (error: any) {
          Alert.alert('Lỗi Firebase', 'Vui lòng kiểm tra lại Firebase Rules: ' + error.message);
        }
      }
      return;
    }

    if (selectedFriends.length === 0) {
      Alert.alert('Chọn người nhận', 'Chọn ít nhất 1 người bạn để gửi!');
      return;
    }

    setUploading(true);
    try {
      let mediaUrl: string;
      let thumbUrl: string | undefined;

      if (capturedVideo) {
        mediaUrl = await uploadVideo(capturedVideo, currentProfile.uid, (p) => setUploadProgress(p));
        try {
          // Tạo thumbnail lập tức để xem nhanh
          const { uri } = await VideoThumbnails.getThumbnailAsync(capturedVideo, { time: 500, quality: 0.5 });
          thumbUrl = await uploadPhoto(uri, currentProfile.uid, () => {});
        } catch (e) {
          console.warn("Lỗi tạo thumbnail:", e);
        }
      } else {
        mediaUrl = await uploadPhoto(capturedImage!, currentProfile.uid, (p) => setUploadProgress(p));
        thumbUrl = mediaUrl; // Dùng ảnh làm thumbnail
      }

      await sendPhoto(
        currentProfile.uid,
        selectedFriends,
        thumbUrl || mediaUrl, // imageUrl
        caption || undefined,
        capturedVideo ? 'video' : 'photo',
        capturedVideo ? mediaUrl : undefined // videoUrl
      );
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      setCapturedImage(null);
      setCapturedVideo(null);
      setCaption('');
      setSelectedFriends([]);
      Alert.alert('✅ Đã gửi!', capturedVideo ? 'Video của bạn đã được gửi!' : 'Ảnh của bạn đã được gửi thành công!');
    } catch (error: any) {
      console.error('Lỗi gửi:', error);
      Alert.alert('Lỗi', 'Không thể gửi: ' + (error.message || 'Thử lại nhé!'));
    } finally {
      setUploading(false);
      setUploadProgress(0);
    }
  };

  // ── Hủy preview ────────────────────────────
  const handleCancelPreview = () => {
    setCapturedImage(null);
    setCapturedVideo(null);
    setCaption('');
    setSelectedFriends([]);
    setShowFriendPicker(false);
  };

  // ── Permission not granted ─────────────────
  if (!permission) return <View style={styles.container} />;

  if (!permission.granted) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.permissionContainer}>
          <AlertCircle size={48} color={Colors.pearl} strokeWidth={1.5} style={{ marginBottom: 16 }} />
          <Text style={styles.permissionTitle}>Camera Access Required</Text>
          <Text style={styles.permissionText}>
            HeartPearl needs camera access to capture moments between us.
          </Text>
          <Pressable style={styles.permissionBtn} onPress={requestPermission}>
            <LinearGradient colors={Colors.gradientPrimary} style={styles.permissionBtnGradient}>
              <Text style={styles.permissionBtnText}>Cấp quyền Camera</Text>
            </LinearGradient>
          </Pressable>
        </View>
      </SafeAreaView>
    );
  }

  // ── Preview (ảnh hoặc video) ───────────────
  if (capturedImage || capturedVideo) {
    return (
      <TouchableWithoutFeedback onPress={() => { Keyboard.dismiss(); setShowFriendPicker(false); }}>
        <View style={styles.container}>
          {capturedImage ? (
            <Image source={{ uri: capturedImage }} style={styles.preview} />
          ) : (
            <Video
              source={{ uri: capturedVideo! }}
              style={styles.preview}
              resizeMode={ResizeMode.COVER}
              shouldPlay
              isLooping
              useNativeControls={false}
            />
          )}

          {/* Gradient overlay */}
          <LinearGradient
            colors={['rgba(0,0,0,0.5)', 'transparent', 'rgba(0,0,0,0.7)']}
            style={StyleSheet.absoluteFillObject}
            locations={[0, 0.4, 1]}
          />

          {/* Top — Cancel + badge */}
          <SafeAreaView style={styles.previewTop}>
            <Pressable style={styles.cancelBtn} onPress={handleCancelPreview}>
              <X size={24} color={Colors.pearl} strokeWidth={1.5} />
            </Pressable>
            {capturedVideo && (
              <View style={styles.videoBadge}>
                <Play size={14} color={Colors.pearl} strokeWidth={2} />
                <Text style={styles.videoBadgeText}>VIDEO</Text>
              </View>
            )}
          </SafeAreaView>

          {/* Caption Input */}
          <View style={styles.captionContainer}>
            <TextInput
              style={styles.captionInput}
              placeholder="Add a sweet note..."
              placeholderTextColor={Colors.textMuted}
              value={caption}
              onChangeText={setCaption}
              maxLength={100}
              multiline
              selectionColor={Colors.primary}
            />
          </View>

          {/* Friend Picker */}
          <View style={styles.friendPickerContainer}>
            <Pressable
              style={styles.friendPickerToggle}
              onPress={() => {
                Keyboard.dismiss();
                setShowFriendPicker(!showFriendPicker);
              }}
            >
              <Text style={styles.friendPickerLabel}>
                {selectedFriends.length === 0
                  ? 'Select recipient'
                  : `${selectedFriends.length} selected`}
              </Text>
            </Pressable>

            {showFriendPicker && (
              <View style={styles.friendList}>
                {friends.length === 0 ? (
                  <Text style={styles.noFriendsText}>
                    No friends yet. Add them in the profile tab.
                  </Text>
                ) : (
                  <>
                    <Pressable
                      style={styles.selectAllBtn}
                      onPress={() => {
                        const allSelected = selectedFriends.length === friends.length;
                        setSelectedFriends(allSelected ? [] : friends.map((f) => f.uid));
                        Haptics.selectionAsync();
                      }}
                    >
                      <Text style={styles.selectAllText}>
                        {selectedFriends.length === friends.length
                          ? 'Deselect all'
                          : 'Select all'}
                      </Text>
                    </Pressable>

                    {friends.map((friend) => (
                      <Pressable
                        key={friend.uid}
                        style={[
                          styles.friendItem,
                          selectedFriends.includes(friend.uid) && styles.friendItemSelected,
                        ]}
                        onPress={() => toggleFriend(friend.uid)}
                      >
                        <View style={styles.friendAvatar}>
                          <Text style={styles.friendAvatarText}>
                            {friend.displayName?.charAt(0).toUpperCase() || '?'}
                          </Text>
                        </View>
                        <Text style={styles.friendName}>{friend.displayName}</Text>
                        {selectedFriends.includes(friend.uid) && (
                          <Check size={20} color={Colors.primary} strokeWidth={2} />
                        )}
                      </Pressable>
                    ))}
                  </>
                )}
              </View>
            )}
          </View>

          {/* Send Button */}
          <View style={styles.sendContainer}>
            <Pressable
              style={({ pressed }) => [
                styles.sendBtn,
                pressed && { opacity: 0.85, transform: [{ scale: 0.97 }] },
              ]}
              onPress={handleSend}
              disabled={isUploading}
            >
              <LinearGradient
                colors={Colors.gradientPrimary}
                style={styles.sendBtnGradient}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 0 }}
              >
                {isUploading ? (
                  <View style={styles.uploadingContainer}>
                    <ActivityIndicator color={Colors.pearl} />
                    <Text style={styles.uploadingText}>
                      {Math.round(uploadProgress)}%
                    </Text>
                  </View>
                ) : (
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                    <Text style={styles.sendText}>Send</Text>
                    <Send size={18} color={Colors.pearl} strokeWidth={2} />
                  </View>
                )}
              </LinearGradient>
            </Pressable>
          </View>
        </View>
      </TouchableWithoutFeedback>
    );
  }

  // ── Live Camera ──────────────────────────────────
  return (
    <View style={styles.container}>
      <CameraView
        ref={cameraRef}
        style={styles.camera}
        facing={facing}
        mode="video"
        flash={flash}
        zoom={zoom}
        mirror={false}
        {...pinchResponder.panHandlers}
      />
      {/* Fake Beauty Filter Overlay: Lớp phủ nhẹ giúp sáng da, hồng hào */}
      <View 
        style={[
          StyleSheet.absoluteFill, 
          { backgroundColor: 'rgba(255, 235, 225, 0.12)' }
        ]} 
        pointerEvents="none" 
      />

      {/* Top Bar */}
      <SafeAreaView style={styles.topBar}>
        <View style={{ flexDirection: 'row', alignItems: 'baseline' }}>
          <Text style={[styles.appTitle, { color: Colors.primaryLight }]}>Heart</Text>
          <Text style={[styles.appTitle, { color: Colors.pearlTint }]}>Pearl</Text>
        </View>

        <View style={styles.topRightControls}>
          {/* Flash toggle */}
          {!isRecording && (
            <Pressable
              style={styles.controlBtn}
              onPress={() => {
                const modes: FlashMode[] = ['off', 'on', 'auto'];
                const next = modes[(modes.indexOf(flash) + 1) % modes.length];
                setFlash(next);
                Haptics.selectionAsync();
              }}
            >
              <View>
                {flash === 'off' ? (
                  <ZapOff size={24} color={Colors.pearl} strokeWidth={1.5} />
                ) : flash === 'on' ? (
                  <Zap size={24} color={Colors.primaryLight} strokeWidth={1.5} />
                ) : (
                  <Zap size={24} color={Colors.pearl} strokeWidth={1.5} />
                )}
              </View>
            </Pressable>
          )}

          {/* Recording badge */}
          {isRecording && (
            <View style={styles.recordingBadge}>
              <Animated.View style={[styles.recordingDot, { opacity: captureRingAnim }]} />
              <Text style={styles.recordingText}>
                {Math.ceil(MAX_VIDEO_DURATION * (1 - recordProgress))}s
              </Text>
            </View>
          )}
        </View>
      </SafeAreaView>

      {/* Video progress bar */}
      {isRecording && (
        <View style={styles.progressBarContainer}>
          <View style={[styles.progressBar, { width: `${recordProgress * 100}%` }]} />
        </View>
      )}

      {/* Zoom indicator */}
      {zoom > 0.02 && !isRecording && (
        <View style={styles.zoomIndicator}>
          <Text style={styles.zoomText}>{zoomDisplay}x</Text>
        </View>
      )}

      {/* Hint text */}
      {!isRecording && zoom <= 0.02 && (
        <View style={styles.hintContainer}>
          <Text style={styles.hintText}>Nhấn để chụp · Giữ để quay · Pinch để zoom</Text>
        </View>
      )}

      {/* Vertical Zoom Slider */}
      {!isRecording && (
        <View style={styles.zoomSliderContainer}>
          <Slider
            style={{ width: 160, height: 40 }}
            minimumValue={0}
            maximumValue={1}
            value={zoom}
            onValueChange={(val) => {
              setZoom(val);
              setZoomDisplay(parseFloat((1 + val * 4).toFixed(1)));
            }}
            minimumTrackTintColor={Colors.primary}
            maximumTrackTintColor="rgba(255,255,255,0.3)"
            thumbTintColor={Colors.white}
          />
        </View>
      )}



      {/* Bottom Controls */}
      <View style={styles.bottomControls}>
        {/* Flip Button */}
        <Pressable
          style={[styles.controlBtn, isRecording && { opacity: 0.3 }]}
          onPress={toggleFacing}
          disabled={isRecording}
        >
          <RefreshCcw size={24} color={Colors.pearl} strokeWidth={1.5} />
        </Pressable>

        {/* Capture / Record Button */}
        <Animated.View style={{ transform: [{ scale: captureScale }] }}>
          <Pressable
            style={[
              styles.captureOuter,
              isRecording && styles.captureOuterRecording,
            ]}
            onPressIn={handlePressIn}
            onPressOut={handlePressOut}
            delayLongPress={300}
          >
            {isRecording ? (
              <Animated.View
                style={[
                  styles.captureInnerRecording,
                  {
                    opacity: captureRingAnim.interpolate({
                      inputRange: [0, 1],
                      outputRange: [0.6, 1],
                    }),
                  },
                ]}
              />
            ) : (
              <LinearGradient colors={Colors.gradientPrimary} style={styles.captureInner} />
            )}
          </Pressable>
        </Animated.View>


      </View>

      {/* Bottom padding */}
      <View style={{ height: 32 }} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.black,
  },
  camera: {
    flex: 1,
  },
  // Permission
  permissionContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: Spacing['3xl'],
    gap: Spacing.base,
  },
  permissionEmoji: { fontSize: 64 },
  permissionTitle: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.xl,
    color: Colors.textPrimary,
  },
  permissionText: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.base,
    color: Colors.textSecondary,
    textAlign: 'center',
    lineHeight: 22,
  },
  permissionBtn: {
    borderRadius: BorderRadius.full,
    overflow: 'hidden',
    marginTop: Spacing.base,
    width: '100%',
  },
  permissionBtnGradient: {
    paddingVertical: 14,
    alignItems: 'center',
  },
  permissionBtnText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.base,
    color: Colors.textInverse,
  },
  // Top Bar
  topBar: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.xl,
    paddingTop: 16,
    paddingBottom: 8,
  },
  appTitle: {
    fontFamily: Typography.fontFamily.extraBold,
    fontSize: Typography.fontSize.xl,
    color: Colors.white,
    letterSpacing: -0.5,
    textShadowColor: 'rgba(0,0,0,0.5)',
    textShadowOffset: { width: 0, height: 1 },
    textShadowRadius: 3,
  },
  topRightControls: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  controlBtn: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: 'rgba(0,0,0,0.45)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
  },
  controlBtnActive: {
    backgroundColor: 'rgba(255,255,255,0.2)',
    borderColor: Colors.white,
  },
  controlBtnText: {
    fontSize: 20,
    color: Colors.white,
  },
  // Recording indicator
  recordingBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(220,38,38,0.85)',
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: BorderRadius.full,
    gap: 6,
  },
  recordingDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: Colors.white,
  },
  recordingText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.sm,
    color: Colors.white,
  },
  // Progress bar
  progressBarContainer: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 3,
    backgroundColor: 'rgba(255,255,255,0.2)',
  },
  progressBar: {
    height: 3,
    backgroundColor: '#ef4444',
  },
  // Zoom indicator
  zoomIndicator: {
    position: 'absolute',
    bottom: 148,
    alignSelf: 'center',
    backgroundColor: 'rgba(0,0,0,0.55)',
    paddingHorizontal: 14,
    paddingVertical: 5,
    borderRadius: BorderRadius.full,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.3)',
  },
  zoomText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.sm,
    color: Colors.white,
  },
  // Hint
  hintContainer: {
    position: 'absolute',
    bottom: 148,
    left: 0,
    right: 0,
    alignItems: 'center',
  },
  hintText: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.xs,
    color: 'rgba(255,255,255,0.65)',
    letterSpacing: 0.3,
  },
  // Zoom Slider
  zoomSliderContainer: {
    position: 'absolute',
    right: -40,
    top: '50%',
    transform: [{ rotate: '-90deg' }, { translateY: -20 }],
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 10,
  },
  // Filter Picker
  filterPickerContainer: {
    position: 'absolute',
    bottom: 110,
    left: 0,
    right: 0,
    height: 90,
  },
  filterListContent: {
    paddingHorizontal: Spacing['2xl'],
    gap: Spacing.md,
  },
  filterItem: {
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
  },
  filterItemActive: {
    transform: [{ scale: 1.05 }],
  },
  filterPreview: {
    width: 56,
    height: 56,
    borderRadius: 28,
    borderWidth: 2,
    borderColor: 'rgba(255,255,255,0.3)',
  },
  filterText: {
    fontFamily: Typography.fontFamily.medium,
    fontSize: 10,
    color: Colors.white,
    textShadowColor: 'rgba(0,0,0,0.8)',
    textShadowOffset: { width: 0, height: 1 },
    textShadowRadius: 2,
  },
  // Bottom Controls
  bottomControls: {
    position: 'absolute',
    bottom: 48,
    left: 0,
    right: 0,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-around',
    paddingHorizontal: Spacing['2xl'],
  },
  flipBtn: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: 'rgba(0,0,0,0.4)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  spacerBtn: { width: 48, height: 48 },
  flipEmoji: { fontSize: 22 },
  captureOuter: {
    width: 80,
    height: 80,
    borderRadius: 40,
    padding: 4,
    borderWidth: 3,
    borderColor: Colors.white,
    shadowColor: Colors.primary,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.8,
    shadowRadius: 12,
    elevation: 10,
  },
  captureOuterRecording: {
    borderColor: '#ef4444',
    shadowColor: '#ef4444',
  },
  captureInner: {
    flex: 1,
    borderRadius: 36,
  },
  captureInnerRecording: {
    flex: 1,
    borderRadius: 8,
    backgroundColor: '#ef4444',
  },
  // Preview
  preview: {
    ...StyleSheet.absoluteFillObject,
    resizeMode: 'cover',
  },
  videoPreviewPlaceholder: {
    flex: 1,
    backgroundColor: '#111',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 12,
  },
  videoPreviewIcon: { fontSize: 64 },
  videoPreviewText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.xl,
    color: Colors.white,
  },
  videoPreviewSub: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.sm,
    color: 'rgba(255,255,255,0.6)',
  },
  previewTop: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.base,
    gap: Spacing.md,
  },
  cancelBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(0,0,0,0.5)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  cancelText: {
    color: Colors.white,
    fontSize: 18,
    fontWeight: 'bold',
  },
  videoBadge: {
    backgroundColor: 'rgba(220,38,38,0.85)',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: BorderRadius.full,
  },
  videoBadgeText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.xs,
    color: Colors.white,
  },
  captionContainer: {
    position: 'absolute',
    bottom: 220,
    left: Spacing['2xl'],
    right: Spacing['2xl'],
  },
  captionInput: {
    backgroundColor: 'rgba(0,0,0,0.45)',
    borderRadius: BorderRadius.lg,
    paddingHorizontal: Spacing.base,
    paddingVertical: Spacing.md,
    color: Colors.white,
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.base,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
  },
  friendPickerContainer: {
    position: 'absolute',
    bottom: 140,
    left: Spacing['2xl'],
    right: Spacing['2xl'],
  },
  friendPickerToggle: {
    backgroundColor: 'rgba(0,0,0,0.5)',
    borderRadius: BorderRadius.lg,
    paddingHorizontal: Spacing.base,
    paddingVertical: Spacing.md,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
  },
  friendPickerLabel: {
    color: Colors.white,
    fontFamily: Typography.fontFamily.medium,
    fontSize: Typography.fontSize.base,
  },
  friendList: {
    backgroundColor: 'rgba(0,0,0,0.85)',
    borderRadius: BorderRadius.lg,
    marginTop: Spacing.sm,
    paddingVertical: Spacing.sm,
    maxHeight: 200,
  },
  selectAllBtn: {
    paddingHorizontal: Spacing.base,
    paddingVertical: Spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.15)',
    marginHorizontal: Spacing.sm,
    marginBottom: Spacing.sm,
    alignItems: 'center',
  },
  selectAllText: {
    color: Colors.primary,
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.sm,
  },
  friendItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.base,
    paddingVertical: Spacing.md,
    gap: Spacing.md,
    borderRadius: BorderRadius.md,
    marginHorizontal: Spacing.sm,
  },
  friendItemSelected: {
    backgroundColor: `${Colors.primary}30`,
  },
  friendAvatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: Colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  friendAvatarText: {
    color: Colors.white,
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.base,
  },
  friendName: {
    flex: 1,
    color: Colors.white,
    fontFamily: Typography.fontFamily.medium,
    fontSize: Typography.fontSize.base,
  },
  friendCheck: {
    color: Colors.primary,
    fontSize: 18,
    fontWeight: 'bold',
  },
  noFriendsText: {
    color: Colors.textMuted,
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.sm,
    textAlign: 'center',
    padding: Spacing.base,
  },
  sendContainer: {
    position: 'absolute',
    bottom: 56,
    left: Spacing['2xl'],
    right: Spacing['2xl'],
  },
  sendBtn: {
    borderRadius: BorderRadius.full,
    overflow: 'hidden',
    shadowColor: Colors.primary,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.5,
    shadowRadius: 16,
    elevation: 10,
  },
  sendBtnGradient: {
    paddingVertical: 16,
    alignItems: 'center',
  },
  sendText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.lg,
    color: Colors.textInverse,
  },
  uploadingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  uploadingText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.base,
    color: Colors.textInverse,
  },
});
