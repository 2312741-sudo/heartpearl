// ─────────────────────────────────────────────
//  Home Screen — Camera (Chụp ảnh + Quay video)
// ─────────────────────────────────────────────

import React, { useState, useRef, useEffect, useCallback, useMemo } from 'react';
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
  ScrollView,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import { CameraView, useCameraPermissions as useExpoCameraPermissions, useMicrophonePermissions as useExpoMicrophonePermissions } from 'expo-camera';
import { Skia, Paint, ImageFilter, BlendMode } from '@shopify/react-native-skia';
import { BEAUTY_FILTERS, FilterType } from '../../utils/filters';
import { Video, ResizeMode } from 'expo-av';
import * as VideoThumbnails from 'expo-video-thumbnails';
import Slider from '@react-native-community/slider';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { Camera as CameraIcon, Send, Sparkles, RefreshCcw, Zap, ZapOff, Check, X, Users, AlertCircle, Play, MessageCircle } from 'lucide-react-native';
import { useAuthStore } from '../../store/auth.store';
import { usePhotoStore } from '../../store/photo.store';
import { uploadPhoto, sendPhoto, uploadVideo } from '../../services/photo.service';
import { getFriendsList } from '../../services/friend.service';
import { useTranslation } from 'react-i18next';
import { useAppTheme, AppColors, Typography, Spacing, BorderRadius } from '../../constants/theme';
import { User } from '../../types';

let Camera: any = null;
let useCameraDevice: any = null;
let useCameraPermission: any = null;
let useMicrophonePermission: any = null;
let useSkiaFrameProcessor: any = null;
let useCameraDevices: any = null;

let isExpoGo = false;
try {
  const VisionCamera = require('react-native-vision-camera');
  Camera = VisionCamera.Camera;
  useCameraDevice = VisionCamera.useCameraDevice;
  useCameraPermission = VisionCamera.useCameraPermission;
  useMicrophonePermission = VisionCamera.useMicrophonePermission;
  useSkiaFrameProcessor = VisionCamera.useSkiaFrameProcessor;
  useCameraDevices = VisionCamera.useCameraDevices;
} catch (e) {
  isExpoGo = true;
}

const useMockPermission = () => {
  return { hasPermission: true, requestPermission: async () => true };
};
const useCameraPermissionHook = !isExpoGo && useCameraPermission ? useCameraPermission : useMockPermission;
const useMicrophonePermissionHook = !isExpoGo && useMicrophonePermission ? useMicrophonePermission : useMockPermission;
const useCameraDeviceHook = !isExpoGo && useCameraDevice ? useCameraDevice : (facing: any, options: any) => ({ minZoom: 1, maxZoom: 8 });
const useCameraDevicesHook = !isExpoGo && useCameraDevices ? useCameraDevices : () => [];
const useMockFrameProcessor = (cb: any, deps: any) => null;
const useSkiaFrameProcessorHook = !isExpoGo && useSkiaFrameProcessor ? useSkiaFrameProcessor : useMockFrameProcessor;

const { width, height } = Dimensions.get('window');

const MAX_VIDEO_DURATION = 15; // giây

export default function HomeScreen() {
  const navigation = useNavigation<any>();

  const frameProcessor = useSkiaFrameProcessorHook((frame: any) => {
    'worklet';
    frame.render();
    const paint = Skia.Paint();
  }, []);

  const { t } = useTranslation();
  const { colors, theme } = useAppTheme();
  const styles = useMemo(() => createStyles(colors), [colors]);

  const [expoCamPermission, requestExpoCamPermission] = useExpoCameraPermissions();
  const [expoMicPermission, requestExpoMicPermission] = useExpoMicrophonePermissions();

  const visionCamPermission = useCameraPermissionHook();
  const visionMicPermission = useMicrophonePermissionHook();

  const hasPermission = isExpoGo ? !!expoCamPermission?.granted : visionCamPermission.hasPermission;
  const permission = { granted: hasPermission };
  const hasMic = isExpoGo ? !!expoMicPermission?.granted : visionMicPermission.hasPermission;
  const micPermission = { granted: hasMic };

  const requestPermission = useCallback(async () => {
    if (isExpoGo) {
      const res = await requestExpoCamPermission();
      return !!res.granted;
    } else {
      return await visionCamPermission.requestPermission();
    }
  }, [expoCamPermission, requestExpoCamPermission, visionCamPermission]);

  const requestMicPermission = useCallback(async () => {
    if (isExpoGo) {
      const res = await requestExpoMicPermission();
      return !!res.granted;
    } else {
      return await visionMicPermission.requestPermission();
    }
  }, [expoMicPermission, requestExpoMicPermission, visionMicPermission]);

  const [facing, setFacing] = useState<'back' | 'front'>('back');
  const devices = useCameraDevicesHook();

  // Select the best multi-camera device that supports ultra-wide
  const device = useMemo(() => {
    if (isExpoGo) return null;
    if (facing === 'front') {
      return devices.find((d: any) => d.position === 'front');
    }
    const triple = devices.find((d: any) => d.position === 'back' && d.deviceType === 'triple-camera');
    if (triple) return triple;
    const dualWide = devices.find((d: any) => d.position === 'back' && d.deviceType === 'dual-wide-camera');
    if (dualWide) return dualWide;
    const dual = devices.find((d: any) => d.position === 'back' && d.deviceType === 'dual-camera');
    if (dual) return dual;
    return devices.find((d: any) => d.position === 'back') || null;
  }, [devices, facing]);

  const [selectedFilter, setSelectedFilter] = useState<FilterType>('normal');
  const [capturedImage, setCapturedImage] = useState<string | null>(null);
  const [capturedVideo, setCapturedVideo] = useState<string | null>(null);
  const [caption, setCaption] = useState('');
  const [friends, setFriends] = useState<User[]>([]);
  const [selectedFriends, setSelectedFriends] = useState<string[]>([]);
  const [showFriendPicker, setShowFriendPicker] = useState(false);

  // Camera controls
  const [flash, setFlash] = useState<'on' | 'off'>('off');
  const minZoom = device?.minZoom ?? 1;
  const maxZoom = Math.min(device?.maxZoom ?? 8, 8);
  const [zoom, setZoom] = useState(1.0);          // actual zoom factor, starts at 1.0x
  const [zoomDisplay, setZoomDisplay] = useState(1.0); // label hiển thị
  const zoomBaseRef = useRef(1.0);                // zoom khi bắt đầu pinch
  const lastPinchDistRef = useRef<number | null>(null);

  // Sync zoom when device changes
  useEffect(() => {
    if (device) {
      const initialZoom = (device.minZoom <= 1.0 && 1.0 <= device.maxZoom) ? 1.0 : device.minZoom;
      setZoom(initialZoom);
      setZoomDisplay(parseFloat(initialZoom.toFixed(1)));
    } else {
      setZoom(1.0);
      setZoomDisplay(1.0);
    }
  }, [device]);

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
          const currentPercent = (prev - minZoom) / (maxZoom - minZoom || 1);
          const nextPercent = Math.max(0, Math.min(1, currentPercent + delta));
          const nextZoom = minZoom + nextPercent * (maxZoom - minZoom);
          setZoomDisplay(parseFloat(nextZoom.toFixed(1)));
          return nextZoom;
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
  const recordDelayTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const cameraRef = useRef<any>(null);
  const expoCameraRef = useRef<any>(null);
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
    if (isRecordingRef.current) return;
    try {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
      animateCapture();
      if (isExpoGo) {
        if (expoCameraRef.current) {
          const photo = await expoCameraRef.current.takePictureAsync({
            quality: 0.85,
            skipProcessing: false,
          });
          if (photo) setCapturedImage(photo.uri);
        }
      } else {
        if (cameraRef.current) {
          const photo = await cameraRef.current.takePhoto({ flash: flash as 'on' | 'off' | 'auto' });
          if (photo) setCapturedImage('file://' + photo.path);
        }
      }
    } catch (err) {
      console.error(err);
      Alert.alert(t('home.err.title'), t('home.err.cannotCapture'));
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
    
    if (isExpoGo) {
      expoCameraRef.current?.stopRecording();
    } else {
      cameraRef.current?.stopRecording();
    }
    
    setIsRecording(false);
    setRecordProgress(0);
    // Nếu saveVideo=false thì xoá video sau khi recordAsync resolve
    if (!saveVideo) {
      setCapturedVideo(null);
    }
  }, [isExpoGo]);

  // ── Bắt đầu record ngay lập tức ────────────────────────────────
  const startRecordingImmediate = useCallback(async () => {
    if (isRecordingRef.current) return;

    if (!hasMic) {
      const result = await requestMicPermission();
      if (!result) {
        Alert.alert(t('home.err.micTitle'), t('home.err.micMsg'));
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
      if (isExpoGo) {
        if (expoCameraRef.current) {
          const promise = expoCameraRef.current.recordAsync({
            maxDuration: MAX_VIDEO_DURATION,
          });
          if (promise) {
            promise.then((video: any) => {
              if (!pressingRef.current) {
                setCapturedVideo(video.uri);
              }
            }).catch((err: any) => console.error(err));
          }
        }
      } else {
        if (cameraRef.current) {
          cameraRef.current.startRecording({
            flash: flash as 'on' | 'off',
            onRecordingFinished: (video: any) => {
              if (!pressingRef.current) {
                setCapturedVideo('file://' + video.path);
              }
            },
            onRecordingError: (error: any) => console.error(error)
          });
        }
      }
    } catch (err) {
      console.error(err);
    }
  }, [hasMic, requestMicPermission, stopRecordingInternal, isExpoGo, flash]);

  const handlePressIn = useCallback(() => {
    pressingRef.current = true;
    pressStartTimeRef.current = Date.now();
    recordDelayTimeoutRef.current = setTimeout(() => {
      if (pressingRef.current) {
        startRecordingImmediate();
      }
    }, 1000);
  }, [startRecordingImmediate]);

  // ── PressOut: tap ngắn (<1000ms) → hủy video, chụp ảnh ────────
  const handlePressOut = useCallback(() => {
    pressingRef.current = false;

    if (recordDelayTimeoutRef.current) {
      clearTimeout(recordDelayTimeoutRef.current);
      recordDelayTimeoutRef.current = null;
    }

    if (isRecordingRef.current) {
      // Giữ dài → dừng và lưu video
      stopRecordingInternal(true);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    } else {
      // Tap ngắn → chụp ảnh
      takePicture();
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
      Alert.alert(t('home.err.syncTitle'), t('home.err.syncMsg'));
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
          Alert.alert(t('home.err.fbTitle'), t('home.err.fbMsg') + error.message);
        }
      }
      return;
    }

    if (selectedFriends.length === 0) {
      Alert.alert(t('home.err.recipientTitle'), t('home.err.recipientMsg'));
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
        capturedVideo ? mediaUrl : undefined, // videoUrl
        facing === 'front', // isMirrored
        true // filter applied globally in HeartPearl
      );
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      setCapturedImage(null);
      setCapturedVideo(null);
      setCaption('');
      setSelectedFriends([]);
      Alert.alert(t('home.successTitle'), capturedVideo ? t('home.successVideo') : t('home.successPhoto'));
    } catch (error: any) {
      console.error('Lỗi gửi:', error);
      Alert.alert(t('home.err.title'), t('home.err.sendMsg') + (error.message || ''));
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
          <AlertCircle size={48} color={colors.pearl} strokeWidth={1.5} style={{ marginBottom: 16 }} />
          <Text style={styles.permissionTitle}>{t('home.camRequired')}</Text>
          <Text style={styles.permissionText}>
            {t('home.camReason')}
          </Text>
          <Pressable style={styles.permissionBtn} onPress={requestPermission}>
            <LinearGradient colors={colors.gradientPrimary} style={styles.permissionBtnGradient}>
              <Text style={styles.permissionBtnText}>{t('home.grantCam')}</Text>
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
            <Image 
              source={{ uri: capturedImage }} 
              style={[styles.preview, { transform: [{ scaleX: facing === 'front' ? -1 : 1 }] }]} 
            />
          ) : (
            <Video
              source={{ uri: capturedVideo! }}
              style={[styles.preview, { transform: [{ scaleX: facing === 'front' ? -1 : 1 }] }]}
              resizeMode={ResizeMode.COVER}
              shouldPlay
              isLooping
              useNativeControls={false}
            />
          )}

          {/* Fake Beauty Filter Overlay */}
          <View 
            style={[
              StyleSheet.absoluteFill, 
              { backgroundColor: 'rgba(255, 235, 225, 0.12)' }
            ]} 
            pointerEvents="none" 
          />

          {/* Gradient overlay */}
          <LinearGradient
            colors={colors.background === '#120716' ? ['rgba(0,0,0,0.5)', 'transparent', 'rgba(0,0,0,0.7)'] : ['rgba(255,255,255,0.7)', 'transparent', 'rgba(255,255,255,0.9)']}
            style={StyleSheet.absoluteFillObject}
            locations={[0, 0.4, 1]}
          />

          {/* Top — Cancel + badge */}
          <SafeAreaView style={styles.previewTop}>
            <Pressable style={styles.cancelBtn} onPress={handleCancelPreview}>
              <X size={24} color={colors.pearl} strokeWidth={1.5} />
            </Pressable>
            {capturedVideo && (
              <View style={styles.videoBadge}>
                <Play size={14} color={colors.pearl} strokeWidth={2} />
                <Text style={styles.videoBadgeText}>{t('home.video')}</Text>
              </View>
            )}
          </SafeAreaView>

          {/* Caption Input */}
          <View style={styles.captionContainer}>
            <TextInput
              style={styles.captionInput}
              placeholder={t('home.captionPlaceholder')}
              placeholderTextColor={colors.textMuted}
              value={caption}
              onChangeText={setCaption}
              maxLength={100}
              multiline
              selectionColor={colors.primary}
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
                  ? t('home.selectRecipient')
                  : `${selectedFriends.length} ${t('home.selected')}`}
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
                          ? t('home.deselectAll')
                          : t('home.selectAll')}
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
                          <Check size={20} color={colors.primary} strokeWidth={2} />
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
                colors={colors.gradientPrimary}
                style={styles.sendBtnGradient}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 0 }}
              >
                {isUploading ? (
                  <View style={styles.uploadingContainer}>
                    <ActivityIndicator color={colors.pearl} />
                    <Text style={styles.uploadingText}>
                      {Math.round(uploadProgress)}%
                    </Text>
                  </View>
                ) : (
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                    <Text style={styles.sendText}>{t('home.send')}</Text>
                    <Send size={18} color={colors.pearl} strokeWidth={2} />
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
      {isExpoGo ? (
        <CameraView
          style={styles.camera}
          facing={facing}
          flash={flash}
          zoom={minZoom === maxZoom ? 0 : (zoom - minZoom) / (maxZoom - minZoom || 1)}
          ref={expoCameraRef}
          mode={isRecording ? 'video' : 'picture'}
          mute={!hasMic}
        />
      ) : (
        (device != null) && <Camera
          device={device}
          isActive={!capturedImage && !capturedVideo}
          frameProcessor={frameProcessor}
          photo={true}
          video={true}
          audio={hasMic}
          ref={cameraRef}
          style={styles.camera}
          zoom={zoom}
          {...pinchResponder.panHandlers}
        />
      )}
      {selectedFilter !== 'normal' && (
        <View 
          style={[
            StyleSheet.absoluteFill, 
            { 
              backgroundColor: BEAUTY_FILTERS.find(f => f.id === selectedFilter)?.overlay?.color || 'transparent',
              opacity: BEAUTY_FILTERS.find(f => f.id === selectedFilter)?.overlay?.opacity || 0
            }
          ]} 
          pointerEvents="none" 
        />
      )}

      {/* Top Bar */}
      <SafeAreaView style={styles.topBar}>
        <View style={{ flexDirection: 'row', alignItems: 'baseline' }}>
          <Text style={[styles.appTitle, { color: colors.primaryLight }]}>Heart</Text>
          <Text style={[styles.appTitle, { color: colors.pearlTint }]}>Pearl</Text>
        </View>

        <View style={styles.topRightControls}>

          <Pressable
            style={[styles.controlBtn, { marginRight: 15 }]}
            onPress={() => navigation.navigate('ChatList')}
          >
            <MessageCircle color={colors.textPrimary} size={28} />
          </Pressable>

          {/* Flash toggle */}
          {!isRecording && (
            <Pressable
              style={styles.controlBtn}
              onPress={() => {
                const modes: ('on' | 'off')[] = ['off', 'on'];
                const next = modes[(modes.indexOf(flash as any) + 1) % modes.length];
                setFlash(next as 'on' | 'off');
                Haptics.selectionAsync();
              }}
            >
              <View>
                {flash === 'off' ? (
                  <ZapOff size={24} color={colors.pearl} strokeWidth={1.5} />
                ) : flash === 'on' ? (
                  <Zap size={24} color={colors.primaryLight} strokeWidth={1.5} />
                ) : (
                  <Zap size={24} color={colors.pearl} strokeWidth={1.5} />
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
          <Text style={styles.hintText}>{t('home.hint')}</Text>
        </View>
      )}

      {/* Vertical Zoom Slider */}
      {!isRecording && (
        <View style={styles.zoomSliderContainer}>
          <Slider
            style={{ width: 160, height: 40 }}
            minimumValue={0}
            maximumValue={1}
            value={(zoom - minZoom) / (maxZoom - minZoom || 1)}
            onValueChange={(val) => {
              const nextZoom = minZoom + val * (maxZoom - minZoom);
              setZoom(nextZoom);
              setZoomDisplay(parseFloat(nextZoom.toFixed(1)));
            }}
            minimumTrackTintColor={colors.primary}
            maximumTrackTintColor="rgba(255,255,255,0.3)"
            thumbTintColor={colors.white}
          />
        </View>
      )}

      {/* Filter Selector */}
      {!capturedImage && !capturedVideo && (
        <View style={{ position: 'absolute', bottom: 180, left: 0, right: 0, height: 60, zIndex: 50 }}>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 20, gap: 15, alignItems: 'center' }}>
            {BEAUTY_FILTERS.map(f => (
              <Pressable
                key={f.id}
                onPress={() => { setSelectedFilter(f.id); Haptics.selectionAsync(); }}
                style={{
                  paddingHorizontal: 16, paddingVertical: 8,
                  borderRadius: 20,
                  backgroundColor: selectedFilter === f.id ? colors.primary : 'rgba(0,0,0,0.5)',
                  borderWidth: 1, borderColor: selectedFilter === f.id ? colors.primary : 'rgba(255,255,255,0.3)'
                }}
              >
                <Text style={{ color: '#FFF', fontFamily: Typography.fontFamily.semiBold }}>{f.name}</Text>
              </Pressable>
            ))}
          </ScrollView>
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
          <RefreshCcw size={24} color={colors.pearl} strokeWidth={1.5} />
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
              <LinearGradient colors={colors.gradientPrimary} style={styles.captureInner} />
            )}
          </Pressable>
        </Animated.View>


      </View>

      {/* Bottom padding */}
      <View style={{ height: 32 }} />
    </View>
  );
}

const createStyles = (colors: AppColors) => StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.black,
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
    color: colors.textPrimary,
  },
  permissionText: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.base,
    color: colors.textSecondary,
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
    color: colors.textInverse,
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
    color: colors.white,
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
    borderColor: colors.white,
  },
  controlBtnText: {
    fontSize: 20,
    color: colors.white,
  },
  // Recording indicator
  recordingBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.background === '#120716' ? 'rgba(220,38,38,0.85)' : 'rgba(220,38,38,1)',
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: BorderRadius.full,
    gap: 6,
  },
  recordingDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: colors.white,
  },
  recordingText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.sm,
    color: colors.white,
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
    color: colors.white,
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
    right: 12,
    top: height * 0.35,
    width: 40,
    height: 180,
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 100,
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
    color: colors.white,
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
    borderColor: colors.white,
    shadowColor: colors.primary,
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
    color: colors.white,
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
    color: colors.white,
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
    color: colors.white,
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
    color: colors.white,
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
    color: colors.white,
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
    color: colors.primary,
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
    backgroundColor: `${colors.primary}30`,
  },
  friendAvatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  friendAvatarText: {
    color: colors.white,
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.base,
  },
  friendName: {
    flex: 1,
    color: colors.white,
    fontFamily: Typography.fontFamily.medium,
    fontSize: Typography.fontSize.base,
  },
  friendCheck: {
    color: colors.primary,
    fontSize: 18,
    fontWeight: 'bold',
  },
  noFriendsText: {
    color: colors.textMuted,
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
    shadowColor: colors.primary,
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
    color: colors.textInverse,
  },
  uploadingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  uploadingText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.base,
    color: colors.textInverse,
  },
});
