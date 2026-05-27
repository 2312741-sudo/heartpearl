// ─────────────────────────────────────────────
//  Profile Screen — Đầy đủ chức năng + Scrollable
// ─────────────────────────────────────────────

import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  Image,
  Alert,
  Modal,
  TextInput,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  Switch,
  TouchableWithoutFeedback,
  Keyboard,
  Dimensions,
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import * as ImagePicker from 'expo-image-picker';
import * as Haptics from 'expo-haptics';
import { updateProfile } from 'firebase/auth';
import { ref, uploadBytesResumable, getDownloadURL } from 'firebase/storage';
import { collection, query, where, getDocs, orderBy, limit } from 'firebase/firestore';
import { auth, storage, db } from '../../services/firebase.config';
import { signOutUser, updateUserDocument, isUsernameAvailable } from '../../services/auth.service';
import { useAuthStore } from '../../store/auth.store';
import { Colors, Typography, Spacing, BorderRadius } from '../../constants/theme';
import { Settings, Edit2, Bell, Lock, Palette, HelpCircle, FileText, LogOut, Camera, X, ChevronRight, Users } from 'lucide-react-native';

const { width } = Dimensions.get('window');

type ProfileSection = 'main' | 'edit' | 'settings' | 'privacy';

export default function ProfileScreen() {
  const insets = useSafeAreaInsets();
  const { userProfile, firebaseUser } = useAuthStore();

  // ── Stats ─────────────────────────────────────
  const [sentCount, setSentCount] = useState(0);
  const [receivedCount, setReceivedCount] = useState(0);
  const [reactionsGiven, setReactionsGiven] = useState(0);

  // ── Edit state ────────────────────────────────
  const [modalSection, setModalSection] = useState<ProfileSection>('main');
  const [editDisplayName, setEditDisplayName] = useState('');
  const [editUsername, setEditUsername] = useState('');
  const [editAvatarUri, setEditAvatarUri] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [uploadAvatarProgress, setUploadAvatarProgress] = useState(0);

  // ── Settings state ────────────────────────────
  const [notifNew, setNotifNew] = useState(true);
  const [notifReaction, setNotifReaction] = useState(true);
  const [notifFriend, setNotifFriend] = useState(true);

  // ── Load stats ────────────────────────────────
  const loadStats = useCallback(async () => {
    if (!userProfile?.uid) return;
    try {
      const [sentSnap, receivedSnap] = await Promise.all([
        getDocs(query(
          collection(db, 'photos'),
          where('senderId', '==', userProfile.uid),
          orderBy('createdAt', 'desc'),
          limit(500)
        )),
        getDocs(query(
          collection(db, 'photos'),
          where('recipientIds', 'array-contains', userProfile.uid),
          limit(500)
        )),
      ]);
      setSentCount(sentSnap.size);
      setReceivedCount(receivedSnap.size);

      // Đếm reactions đã nhận
      let reactions = 0;
      sentSnap.docs.forEach(d => {
        const data = d.data();
        reactions += Object.keys(data.reactions || {}).length;
        reactions += Object.keys(data.textReactions || {}).length;
      });
      setReactionsGiven(reactions);
    } catch {
      // silent
    }
  }, [userProfile?.uid]);

  useEffect(() => { loadStats(); }, [loadStats]);

  // ── Handlers ──────────────────────────────────
  const handleSignOut = () => {
    Alert.alert('Đăng xuất', 'Bạn chắc chắn muốn đăng xuất?', [
      { text: 'Hủy', style: 'cancel' },
      { text: 'Đăng xuất', style: 'destructive', onPress: () => signOutUser() },
    ]);
  };

  const pickAvatar = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.85,
    });
    if (!result.canceled) {
      setEditAvatarUri(result.assets[0].uri);
      Haptics.selectionAsync();
    }
  };

  const openEdit = () => {
    setEditDisplayName(userProfile?.displayName || '');
    setEditUsername(userProfile?.username || '');
    setEditAvatarUri(null);
    setUploadAvatarProgress(0);
    setModalSection('edit');
    Haptics.selectionAsync();
  };

  const handleSaveProfile = async () => {
    if (!editDisplayName.trim()) {
      Alert.alert('Thiếu thông tin', 'Vui lòng nhập tên hiển thị');
      return;
    }
    const cleanUsername = editUsername.trim().toLowerCase();
    if (!cleanUsername || cleanUsername.length < 3) {
      Alert.alert('Username không hợp lệ', 'Username phải có ít nhất 3 ký tự');
      return;
    }
    if (!/^[a-z0-9_.]+$/.test(cleanUsername)) {
      Alert.alert('Username không hợp lệ', 'Chỉ dùng chữ thường, số, dấu gạch dưới (_) và dấu chấm (.)');
      return;
    }

    const currentUser = auth.currentUser;
    if (!currentUser) return;

    setLoading(true);
    try {
      if (cleanUsername !== userProfile?.username) {
        const available = await isUsernameAvailable(cleanUsername);
        if (!available) {
          Alert.alert('Đã tồn tại', 'Username này đã có người dùng. Thử tên khác nhé!');
          setLoading(false);
          return;
        }
      }

      let avatarUrl = userProfile?.avatarUrl || null;
      if (editAvatarUri) {
        const response = await fetch(editAvatarUri);
        const blob = await response.blob();
        const avatarRef = ref(storage, `avatars/${currentUser.uid}.jpg`);
        const task = uploadBytesResumable(avatarRef, blob);
        await new Promise<void>((resolve, reject) => {
          task.on('state_changed',
            (snap) => setUploadAvatarProgress(snap.bytesTransferred / snap.totalBytes * 100),
            reject,
            () => resolve()
          );
        });
        avatarUrl = await getDownloadURL(avatarRef);
      }

      await updateProfile(currentUser, { displayName: editDisplayName.trim(), photoURL: avatarUrl });

      const updateData: Record<string, string> = {
        displayName: editDisplayName.trim(),
        username: cleanUsername,
      };
      if (avatarUrl) updateData.avatarUrl = avatarUrl;
      await updateUserDocument(currentUser.uid, updateData);

      useAuthStore.getState().setUserProfile({
        ...userProfile!,
        uid: currentUser.uid,
        displayName: editDisplayName.trim(),
        username: cleanUsername,
        avatarUrl: avatarUrl || userProfile?.avatarUrl,
        friends: userProfile?.friends || [],
        createdAt: userProfile?.createdAt || new Date(),
      });

      Alert.alert('✅', 'Đã cập nhật profile!');
      setModalSection('main');
    } catch (error: unknown) {
      Alert.alert('Lỗi', error instanceof Error ? error.message : 'Không thể cập nhật');
    } finally {
      setLoading(false);
    }
  };

  // ── Avatar component ──────────────────────────
  const AvatarDisplay = ({ size = 90, pressable = false }: { size?: number; pressable?: boolean }) => {
    const avatarUrl = editAvatarUri || userProfile?.avatarUrl;
    const Component = pressable ? Pressable : View;
    return (
      <Component onPress={pressable ? pickAvatar : undefined} style={{ position: 'relative' }}>
        <View style={[styles.avatarRing, { width: size + 6, height: size + 6, borderRadius: (size + 6) / 2 }]}>
          {avatarUrl ? (
            <Image source={{ uri: avatarUrl }} style={[styles.avatarImg, { width: size, height: size, borderRadius: size / 2 }]} />
          ) : (
            <LinearGradient colors={Colors.gradientPrimary} style={[styles.avatarImg, { width: size, height: size, borderRadius: size / 2, alignItems: 'center', justifyContent: 'center' }]}>
              <Text style={[styles.avatarInitial, { fontSize: size * 0.38 }]}>
                {userProfile?.displayName?.charAt(0).toUpperCase() || '?'}
              </Text>
            </LinearGradient>
          )}
        </View>
        {pressable && (
          <View style={styles.cameraEditBadge}>
            <Camera size={14} color={Colors.pearl} strokeWidth={2} />
          </View>
        )}
        <View style={styles.onlineDot} />
      </Component>
    );
  };

  // ─────────────────────────────────────────────
  // RENDER MAIN CONTENT
  // ─────────────────────────────────────────────
  return (
    <View style={[styles.root, { paddingTop: insets.top }]}>
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={[styles.scrollContent, { paddingBottom: insets.bottom + 100 }]}
        keyboardShouldPersistTaps="handled"
      >
        <View style={styles.header}>
          <Text style={styles.headerTitle}>Profile</Text>
          <Pressable
            style={styles.settingsBtn}
            onPress={() => { setModalSection('settings'); Haptics.selectionAsync(); }}
          >
            <Settings size={22} color={Colors.pearl} strokeWidth={1.5} />
          </Pressable>
        </View>

        {/* ── Profile Hero Card ── */}
        <LinearGradient
          colors={[Colors.surfaceLight, Colors.surface]}
          style={styles.heroCard}
        >
          <AvatarDisplay size={90} />
          <Text style={styles.displayName}>
            {userProfile?.displayName || firebaseUser?.displayName || 'Người dùng'}
          </Text>
          {userProfile?.username && (
            <Text style={styles.username}>@{userProfile.username}</Text>
          )}
          <Text style={styles.email}>
            {userProfile?.email || firebaseUser?.email || ''}
          </Text>

          {/* Stats row */}
          <View style={styles.statsRow}>
            <View style={styles.statItem}>
              <Text style={styles.statValue}>{userProfile?.friends?.length || 0}</Text>
              <Text style={styles.statLabel}>Bạn bè</Text>
            </View>
            <View style={styles.statDivider} />
            <View style={styles.statItem}>
              <Text style={styles.statValue}>{sentCount}</Text>
              <Text style={styles.statLabel}>Đã gửi</Text>
            </View>
            <View style={styles.statDivider} />
            <View style={styles.statItem}>
              <Text style={styles.statValue}>{reactionsGiven}</Text>
              <Text style={styles.statLabel}>Reactions</Text>
            </View>
          </View>

          {/* Edit profile button */}
          <Pressable
            style={({ pressed }) => [styles.editProfileBtn, pressed && { opacity: 0.8, transform: [{ scale: 0.98 }] }]}
            onPress={openEdit}
          >
            <Edit2 size={16} color={Colors.primaryLight} strokeWidth={2} />
            <Text style={styles.editProfileBtnText}>Edit Profile</Text>
          </Pressable>
        </LinearGradient>

        {/* ── Username share card ── */}
        <View style={styles.sectionCard}>
          <View style={styles.shareRow}>
            <View>
              <Text style={styles.shareTitle}>Chia sẻ tài khoản</Text>
              <Text style={styles.shareSubtitle}>Bạn bè tìm bạn qua username</Text>
            </View>
            <Pressable
              style={styles.shareTag}
              onPress={() => {
                Haptics.selectionAsync();
                Alert.alert('Username của bạn', `@${userProfile?.username || '(chưa đặt)'}`, [{ text: 'OK' }]);
              }}
            >
              <Text style={styles.shareTagText}>@{userProfile?.username || '...'}</Text>
            </Pressable>
          </View>
        </View>

        {/* ── Menu list ── */}
        <View style={styles.sectionCard}>
          {[
            { icon: <Edit2 size={22} color={Colors.primaryLight} strokeWidth={1.5} />, label: 'Edit Profile', desc: 'Name, username, avatar', onPress: openEdit },
            { icon: <Bell size={22} color={Colors.primaryLight} strokeWidth={1.5} />, label: 'Notifications', desc: 'Manage alerts', onPress: () => { setModalSection('settings'); Haptics.selectionAsync(); } },
            { icon: <Lock size={22} color={Colors.primaryLight} strokeWidth={1.5} />, label: 'Privacy', desc: 'Control who sees you', onPress: () => { setModalSection('privacy'); Haptics.selectionAsync(); } },
            { icon: <Palette size={22} color={Colors.primaryLight} strokeWidth={1.5} />, label: 'Appearance', desc: 'Dark/Light mode', onPress: () => Alert.alert('Coming Soon', 'Feature in development') },
            { icon: <HelpCircle size={22} color={Colors.primaryLight} strokeWidth={1.5} />, label: 'Help & Feedback', desc: 'Send us suggestions', onPress: () => Alert.alert('Feedback', 'Email: support@tamchau.app') },
            { icon: <FileText size={22} color={Colors.primaryLight} strokeWidth={1.5} />, label: 'Terms of Use', desc: '', onPress: () => Alert.alert('Terms', 'Will open browser') },
          ].map((item, i, arr) => (
            <Pressable
              key={i}
              style={({ pressed }) => [
                styles.menuRow,
                i < arr.length - 1 && styles.menuRowBorder,
                pressed && { backgroundColor: Colors.surfaceLight },
              ]}
              onPress={item.onPress}
            >
              <View style={styles.menuIconWrap}>{item.icon}</View>
              <View style={styles.menuLabelCol}>
                <Text style={styles.menuLabel}>{item.label}</Text>
                {!!item.desc && <Text style={styles.menuDesc}>{item.desc}</Text>}
              </View>
              <ChevronRight size={20} color={Colors.textMuted} strokeWidth={1.5} />
            </Pressable>
          ))}
        </View>

        {/* ── Received media preview ── */}
        {receivedCount > 0 && (
          <View style={styles.sectionCard}>
            <Text style={styles.sectionTitle}>📥 Đã nhận ({receivedCount})</Text>
            <Text style={styles.sectionSubtitle}>Vào Inbox để xem hình bạn bè đã gửi cho bạn</Text>
          </View>
        )}

        {/* ── Sign Out ── */}
        <Pressable
          style={({ pressed }) => [styles.signOutBtn, pressed && { opacity: 0.8 }]}
          onPress={handleSignOut}
        >
          <LogOut size={18} color={Colors.error} strokeWidth={2} />
          <Text style={styles.signOutText}>Log Out</Text>
        </Pressable>

        {/* App version */}
        <Text style={styles.versionText}>Tâm Châu v1.0.0</Text>
      </ScrollView>

      {/* ════════════════════════════════════════
          EDIT PROFILE MODAL
      ════════════════════════════════════════ */}
      <Modal
        visible={modalSection === 'edit'}
        animationType="slide"
        transparent
        onRequestClose={() => !loading && setModalSection('main')}
      >
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          style={{ flex: 1 }}
        >
          <TouchableWithoutFeedback onPress={Keyboard.dismiss}>
            <View style={styles.modalOverlay}>
              <View style={styles.modalSheet}>
                <View style={styles.modalHandle} />
                {/* Header */}
                <View style={styles.modalHeader}>
                  <Text style={styles.modalTitle}>Edit Profile</Text>
                  <Pressable
                    onPress={() => !loading && setModalSection('main')}
                    style={styles.modalCloseBtn}
                    hitSlop={12}
                  >
                    <X size={20} color={Colors.textMuted} strokeWidth={2} />
                  </Pressable>
                </View>

                <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.modalBody}>
                  {/* Avatar editor */}
                  <AvatarDisplay size={100} pressable />
                  {uploadAvatarProgress > 0 && uploadAvatarProgress < 100 && (
                    <View style={styles.progressWrap}>
                      <View style={[styles.progressFill, { width: `${uploadAvatarProgress}%` }]} />
                    </View>
                  )}

                  {/* Display name */}
                  <View style={styles.inputGroup}>
                    <Text style={styles.inputLabel}>Tên hiển thị</Text>
                    <View style={styles.inputWrapper}>
                      <TextInput
                        style={styles.textInput}
                        placeholder="Tên của bạn"
                        placeholderTextColor={Colors.textMuted}
                        value={editDisplayName}
                        onChangeText={setEditDisplayName}
                        selectionColor={Colors.primary}
                        maxLength={30}
                      />
                    </View>
                  </View>

                  {/* Username */}
                  <View style={styles.inputGroup}>
                    <Text style={styles.inputLabel}>Username</Text>
                    <View style={styles.inputWrapper}>
                      <Text style={styles.inputPrefix}>@</Text>
                      <TextInput
                        style={[styles.textInput, { flex: 1 }]}
                        placeholder="username"
                        placeholderTextColor={Colors.textMuted}
                        value={editUsername}
                        onChangeText={(t) => setEditUsername(t.toLowerCase().replace(/[^a-z0-9_.]/g, ''))}
                        selectionColor={Colors.primary}
                        maxLength={20}
                        autoCapitalize="none"
                        autoCorrect={false}
                      />
                    </View>
                    <Text style={styles.inputHint}>Viết liền, không dấu, 3–20 ký tự</Text>
                  </View>

                  {/* Buttons */}
                  <View style={styles.modalBtnRow}>
                    <Pressable
                      style={[styles.modalBtn, styles.cancelBtn]}
                      onPress={() => !loading && setModalSection('main')}
                      disabled={loading}
                    >
                      <Text style={styles.cancelBtnText}>Hủy</Text>
                    </Pressable>
                    <Pressable style={styles.modalBtn} onPress={handleSaveProfile} disabled={loading}>
                      <LinearGradient
                        colors={Colors.gradientPrimary}
                        style={styles.saveBtnGrad}
                        start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }}
                      >
                        {loading
                          ? <ActivityIndicator color={Colors.textInverse} />
                          : <Text style={styles.saveBtnText}>Lưu thay đổi</Text>
                        }
                      </LinearGradient>
                    </Pressable>
                  </View>
                </ScrollView>
              </View>
            </View>
          </TouchableWithoutFeedback>
        </KeyboardAvoidingView>
      </Modal>

      {/* ════════════════════════════════════════
          SETTINGS MODAL
      ════════════════════════════════════════ */}
      <Modal
        visible={modalSection === 'settings'}
        animationType="slide"
        transparent
        onRequestClose={() => setModalSection('main')}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalSheet}>
            <View style={styles.modalHandle} />
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Notification Settings</Text>
              <Pressable onPress={() => setModalSection('main')} style={styles.modalCloseBtn} hitSlop={12}>
                <X size={20} color={Colors.textMuted} strokeWidth={2} />
              </Pressable>
            </View>
            <ScrollView contentContainerStyle={styles.modalBody}>
              {[
                { label: 'Ảnh/video mới từ bạn bè', desc: 'Thông báo khi nhận được media', value: notifNew, onChange: setNotifNew },
                { label: 'Reactions', desc: 'Khi bạn bè react lên ảnh của bạn', value: notifReaction, onChange: setNotifReaction },
                { label: 'Lời mời kết bạn', desc: 'Khi có người muốn kết bạn', value: notifFriend, onChange: setNotifFriend },
              ].map((item, i) => (
                <View key={i} style={[styles.settingRow, i > 0 && styles.settingRowBorder]}>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.settingLabel}>{item.label}</Text>
                    <Text style={styles.settingDesc}>{item.desc}</Text>
                  </View>
                  <Switch
                    value={item.value}
                    onValueChange={(v) => { item.onChange(v); Haptics.selectionAsync(); }}
                    trackColor={{ false: Colors.border, true: Colors.primary }}
                    thumbColor={Colors.white}
                  />
                </View>
              ))}
              <Pressable style={styles.closeModalBtn} onPress={() => setModalSection('main')}>
                <Text style={styles.closeModalText}>Xong</Text>
              </Pressable>
            </ScrollView>
          </View>
        </View>
      </Modal>

      {/* ════════════════════════════════════════
          PRIVACY MODAL
      ════════════════════════════════════════ */}
      <Modal
        visible={modalSection === 'privacy'}
        animationType="slide"
        transparent
        onRequestClose={() => setModalSection('main')}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalSheet}>
            <View style={styles.modalHandle} />
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Privacy</Text>
              <Pressable onPress={() => setModalSection('main')} style={styles.modalCloseBtn} hitSlop={12}>
                <X size={20} color={Colors.textMuted} strokeWidth={2} />
              </Pressable>
            </View>
            <ScrollView contentContainerStyle={styles.modalBody}>
              <Text style={styles.privacyText}>
                Tâm Châu chỉ chia sẻ ảnh/video của bạn với những người bạn bè bạn đã chọn.
              </Text>
              {[
                { icon: <Users size={24} color={Colors.primary} />, title: 'Friends Only', desc: 'Only approved friends receive your photos.' },
                { icon: <Lock size={24} color={Colors.primary} />, title: 'Encrypted', desc: 'Your data is secured by Firebase Security Rules.' },
              ].map((item, i) => (
                <View key={i} style={styles.privacyItem}>
                  <View style={styles.privacyItemEmoji}>{item.icon}</View>
                  <View>
                    <Text style={styles.privacyItemTitle}>{item.title}</Text>
                    <Text style={styles.privacyItemDesc}>{item.desc}</Text>
                  </View>
                </View>
              ))}
              <Pressable style={styles.closeModalBtn} onPress={() => setModalSection('main')}>
                <Text style={styles.closeModalText}>Đóng</Text>
              </Pressable>
            </ScrollView>
          </View>
        </View>
      </Modal>
    </View>
  );
}

// ─────────────────────────────────────────────
// Styles
// ─────────────────────────────────────────────
const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: Colors.background },
  scrollContent: {
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.base,
    gap: Spacing.base,
  },

  // Header
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 4,
  },
  headerTitle: {
    fontFamily: Typography.fontFamily.extraBold,
    fontSize: Typography.fontSize['2xl'],
    color: Colors.textPrimary,
    letterSpacing: -0.5,
  },
  settingsBtn: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: Colors.surface,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: Colors.border,
  },

  // Hero card
  heroCard: {
    borderRadius: BorderRadius.xl,
    borderWidth: 1,
    borderColor: Colors.border,
    padding: Spacing['2xl'],
    alignItems: 'center',
    gap: Spacing.sm,
  },
  avatarRing: {
    padding: 3,
    borderRadius: 999,
    borderWidth: 2.5,
    borderColor: Colors.primary,
    marginBottom: 4,
  },
  avatarImg: {},
  avatarInitial: {
    fontFamily: Typography.fontFamily.extraBold,
    color: Colors.white,
  },
  onlineDot: {
    position: 'absolute',
    bottom: 4,
    right: 4,
    width: 14,
    height: 14,
    borderRadius: 7,
    backgroundColor: Colors.success,
    borderWidth: 2,
    borderColor: Colors.surface,
  },
  cameraEditBadge: {
    position: 'absolute',
    bottom: 2,
    right: 2,
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: Colors.surface,
    borderWidth: 2,
    borderColor: Colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  displayName: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.xl,
    color: Colors.textPrimary,
  },
  username: {
    fontFamily: Typography.fontFamily.medium,
    fontSize: Typography.fontSize.base,
    color: Colors.primary,
  },
  email: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.sm,
    color: Colors.textMuted,
    marginBottom: Spacing.sm,
  },
  statsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    width: '100%',
    borderTopWidth: 1,
    borderTopColor: Colors.border,
    paddingTop: Spacing.base,
    marginTop: 4,
  },
  statItem: { flex: 1, alignItems: 'center' },
  statValue: {
    fontFamily: Typography.fontFamily.extraBold,
    fontSize: Typography.fontSize.xl,
    color: Colors.textPrimary,
  },
  statLabel: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.xs,
    color: Colors.textMuted,
    marginTop: 2,
  },
  statDivider: { width: 1, height: 32, backgroundColor: Colors.border },
  editProfileBtn: {
    marginTop: Spacing.sm,
    paddingHorizontal: Spacing.xl,
    paddingVertical: 10,
    borderRadius: BorderRadius.full,
    borderWidth: 1,
    borderColor: Colors.primaryLight,
    backgroundColor: 'transparent',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  editProfileBtnText: {
    fontFamily: Typography.fontFamily.semiBold,
    fontSize: Typography.fontSize.sm,
    color: Colors.primaryLight,
  },

  // Share card
  sectionCard: {
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.xl,
    borderWidth: 1,
    borderColor: Colors.border,
    overflow: 'hidden',
  },
  sectionTitle: {
    fontFamily: Typography.fontFamily.semiBold,
    fontSize: Typography.fontSize.base,
    color: Colors.textPrimary,
    paddingHorizontal: Spacing.base,
    paddingTop: Spacing.base,
  },
  sectionSubtitle: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.sm,
    color: Colors.textMuted,
    paddingHorizontal: Spacing.base,
    paddingBottom: Spacing.base,
  },
  shareRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.base,
    paddingVertical: Spacing.base,
    gap: Spacing.base,
  },
  shareTitle: {
    fontFamily: Typography.fontFamily.semiBold,
    fontSize: Typography.fontSize.base,
    color: Colors.textPrimary,
  },
  shareSubtitle: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.xs,
    color: Colors.textMuted,
    marginTop: 2,
  },
  shareTag: {
    backgroundColor: `${Colors.primary}15`,
    borderRadius: BorderRadius.full,
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderWidth: 1.5,
    borderColor: `${Colors.primary}40`,
  },
  shareTagText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.sm,
    color: Colors.primary,
  },

  // Menu
  menuRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.base,
    paddingVertical: 14,
    gap: 14,
  },
  menuEmoji: { width: 32, alignItems: 'center', justifyContent: 'center' },
  menuIconWrap: { width: 32, alignItems: 'center', justifyContent: 'center' },
  menuLabelCol: { flex: 1 },
  menuLabel: {
    fontFamily: Typography.fontFamily.medium,
    fontSize: Typography.fontSize.base,
    color: Colors.textPrimary,
  },
  menuDesc: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.xs,
    color: Colors.textMuted,
    marginTop: 1,
  },
  menuArrow: { fontSize: 20, color: Colors.textMuted },

  signOutBtn: {
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.xl,
    borderWidth: 1,
    borderColor: `${Colors.error}60`,
    paddingVertical: Spacing.base,
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 8,
  },
  signOutText: {
    fontFamily: Typography.fontFamily.semiBold,
    fontSize: Typography.fontSize.base,
    color: Colors.error,
  },
  versionText: {
    textAlign: 'center',
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.xs,
    color: Colors.textMuted,
    paddingTop: 4,
  },

  // Modals
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.55)',
    justifyContent: 'flex-end',
  },
  modalSheet: {
    backgroundColor: Colors.background,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    borderTopWidth: 1,
    borderTopColor: Colors.border,
    paddingTop: 12,
    maxHeight: '92%',
  },
  modalHandle: {
    width: 36, height: 4, borderRadius: 2,
    backgroundColor: Colors.border,
    alignSelf: 'center',
    marginBottom: Spacing.base,
  },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing['2xl'],
    paddingBottom: Spacing.base,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  modalTitle: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.lg,
    color: Colors.textPrimary,
  },
  modalCloseBtn: {
    width: 32, height: 32, borderRadius: 16,
    backgroundColor: Colors.surface,
    borderWidth: 1,
    borderColor: Colors.border,
    alignItems: 'center',
    justifyContent: 'center',
  },
  modalCloseText: { color: Colors.textMuted, fontSize: 14, fontWeight: 'bold' },
  modalBody: {
    paddingHorizontal: Spacing['2xl'],
    paddingTop: Spacing.lg,
    paddingBottom: Spacing['3xl'],
    alignItems: 'center',
    gap: Spacing.base,
  },

  // Edit form
  progressWrap: {
    width: '100%',
    height: 4,
    backgroundColor: Colors.border,
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressFill: { height: 4, backgroundColor: Colors.primary },
  inputGroup: { width: '100%', gap: 6 },
  inputLabel: {
    fontFamily: Typography.fontFamily.medium,
    fontSize: Typography.fontSize.sm,
    color: Colors.textSecondary,
  },
  inputWrapper: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.lg,
    borderWidth: 1,
    borderColor: Colors.border,
    paddingHorizontal: Spacing.base,
  },
  inputPrefix: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.base,
    color: Colors.primary,
    marginRight: 4,
  },
  textInput: {
    paddingVertical: 13,
    fontSize: Typography.fontSize.base,
    color: Colors.textPrimary,
    fontFamily: Typography.fontFamily.regular,
    flex: 1,
  },
  inputHint: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.xs,
    color: Colors.textMuted,
  },
  modalBtnRow: {
    flexDirection: 'row',
    width: '100%',
    gap: Spacing.sm,
    marginTop: Spacing.sm,
  },
  modalBtn: { flex: 1, borderRadius: BorderRadius.full, overflow: 'hidden', height: 52 },
  cancelBtn: {
    backgroundColor: Colors.surface,
    borderWidth: 1,
    borderColor: Colors.border,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cancelBtnText: {
    fontFamily: Typography.fontFamily.semiBold,
    fontSize: Typography.fontSize.base,
    color: Colors.textSecondary,
  },
  saveBtnGrad: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  saveBtnText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.base,
    color: Colors.textInverse,
  },

  // Settings
  settingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    width: '100%',
    gap: 12,
  },
  settingRowBorder: { borderTopWidth: 1, borderTopColor: Colors.border },
  settingLabel: {
    fontFamily: Typography.fontFamily.medium,
    fontSize: Typography.fontSize.base,
    color: Colors.textPrimary,
  },
  settingDesc: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.xs,
    color: Colors.textMuted,
    marginTop: 1,
  },
  closeModalBtn: {
    marginTop: Spacing.lg,
    width: '100%',
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.full,
    borderWidth: 1,
    borderColor: Colors.border,
    paddingVertical: 14,
    alignItems: 'center',
  },
  closeModalText: {
    fontFamily: Typography.fontFamily.semiBold,
    fontSize: Typography.fontSize.base,
    color: Colors.textPrimary,
  },

  // Privacy
  privacyText: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.base,
    color: Colors.textSecondary,
    lineHeight: 22,
    textAlign: 'center',
    marginBottom: Spacing.base,
    width: '100%',
  },
  privacyItem: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 14,
    width: '100%',
    paddingVertical: 12,
    borderTopWidth: 1,
    borderTopColor: Colors.border,
  },
  privacyItemEmoji: { fontSize: 24, width: 32, textAlign: 'center', marginTop: 2 },
  privacyItemTitle: {
    fontFamily: Typography.fontFamily.semiBold,
    fontSize: Typography.fontSize.base,
    color: Colors.textPrimary,
  },
  privacyItemDesc: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.sm,
    color: Colors.textMuted,
    marginTop: 2,
  },
});
