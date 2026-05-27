// ─────────────────────────────────────────────
//  Create Profile Screen
// ─────────────────────────────────────────────

import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  Pressable,
  Alert,
  ActivityIndicator,
  Image,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import * as ImagePicker from 'expo-image-picker';
import { auth, storage } from '../../services/firebase.config';
import { updateProfile } from 'firebase/auth';
import { ref, uploadBytesResumable, getDownloadURL } from 'firebase/storage';
import { updateUserDocument, isUsernameAvailable } from '../../services/auth.service';
import { Colors, Typography, Spacing, BorderRadius } from '../../constants/theme';

export default function CreateProfileScreen() {
  const [displayName, setDisplayName] = useState('');
  const [username, setUsername] = useState('');
  const [loading, setLoading] = useState(false);
  const [avatarUri, setAvatarUri] = useState<string | null>(null);

  const pickAvatar = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.8,
    });
    if (!result.canceled) {
      setAvatarUri(result.assets[0].uri);
    }
  };

  const handleSave = async () => {
    if (!displayName.trim()) {
      Alert.alert('Thông báo', 'Vui lòng nhập tên hiển thị');
      return;
    }
    
    const cleanUsername = username.trim().toLowerCase();
    if (!cleanUsername) {
      Alert.alert('Thông báo', 'Vui lòng nhập username');
      return;
    }

    if (cleanUsername.length < 3) {
      Alert.alert('Thông báo', 'Username phải có ít nhất 3 ký tự');
      return;
    }

    const usernameRegex = /^[a-z0-9_.]+$/;
    if (!usernameRegex.test(cleanUsername)) {
      Alert.alert('Thông báo', 'Username chỉ chứa chữ thường, số, dấu gạch dưới (_) và dấu chấm (.)');
      return;
    }

    const user = auth.currentUser;
    if (!user) return;

    setLoading(true);
    try {
      const available = await isUsernameAvailable(cleanUsername);
      if (!available) {
        Alert.alert('Lỗi', 'Username này đã có người sử dụng. Vui lòng chọn tên khác!');
        setLoading(false);
        return;
      }

      let avatarUrl = user.photoURL || null;

      // Upload avatar nếu có
      if (avatarUri) {
        const response = await fetch(avatarUri);
        const blob = await response.blob();
        const avatarRef = ref(storage, `avatars/${user.uid}.jpg`);
        const task = uploadBytesResumable(avatarRef, blob);
        await new Promise<void>((resolve, reject) => {
          task.on('state_changed', undefined, reject, () => resolve());
        });
        avatarUrl = await getDownloadURL(avatarRef);
      }

      // Update Firebase Auth profile
      await updateProfile(user, {
        displayName: displayName.trim(),
        photoURL: avatarUrl,
      });

      // Update Firestore
      const updateData: any = {
        displayName: displayName.trim(),
        username: cleanUsername,
      };
      if (avatarUrl) {
        updateData.avatarUrl = avatarUrl;
      }
      await updateUserDocument(user.uid, updateData);

      // Navigation happens automatically via auth state change
    } catch (error) {
      Alert.alert('Lỗi', 'Không thể lưu profile. Thử lại nhé!');
    } finally {
      setLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.container}>
        <Text style={styles.title}>Tạo Profile 🎨</Text>
        <Text style={styles.subtitle}>
          Cho bạn bè biết đây là bạn!
        </Text>

        {/* Avatar Picker */}
        <Pressable style={styles.avatarContainer} onPress={pickAvatar}>
          {avatarUri ? (
            <Image source={{ uri: avatarUri }} style={styles.avatar} />
          ) : (
            <LinearGradient
              colors={Colors.gradientPrimary}
              style={styles.avatarPlaceholder}
            >
              <Text style={styles.avatarEmoji}>👤</Text>
              <Text style={styles.avatarHint}>Chọn ảnh</Text>
            </LinearGradient>
          )}
          <View style={styles.avatarBadge}>
            <Text style={styles.avatarBadgeText}>✏️</Text>
          </View>
        </Pressable>

        {/* Name Input */}
        <View style={styles.inputGroup}>
          <Text style={styles.inputLabel}>Tên hiển thị</Text>
          <View style={styles.inputWrapper}>
            <TextInput
              style={styles.input}
              placeholder="Tên của bạn"
              placeholderTextColor={Colors.textMuted}
              value={displayName}
              onChangeText={setDisplayName}
              selectionColor={Colors.primary}
              maxLength={30}
            />
          </View>
        </View>

        {/* Username Input */}
        <View style={styles.inputGroup}>
          <Text style={styles.inputLabel}>Username (viết liền, không dấu)</Text>
          <View style={styles.inputWrapper}>
            <TextInput
              style={styles.input}
              placeholder="username"
              placeholderTextColor={Colors.textMuted}
              value={username}
              onChangeText={(text) => {
                const cleaned = text.toLowerCase().replace(/[^a-z0-9_.]/g, '');
                setUsername(cleaned);
              }}
              selectionColor={Colors.primary}
              maxLength={20}
              autoCapitalize="none"
              autoCorrect={false}
            />
          </View>
        </View>

        {/* Save Button */}
        <Pressable
          style={({ pressed }) => [
            styles.saveBtn,
            pressed && { opacity: 0.85 },
          ]}
          onPress={handleSave}
          disabled={loading}
        >
          <LinearGradient
            colors={Colors.gradientPrimary}
            style={styles.saveGradient}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 0 }}
          >
            {loading ? (
              <ActivityIndicator color={Colors.textInverse} />
            ) : (
              <Text style={styles.saveText}>Lưu & Tiếp tục 🚀</Text>
            )}
          </LinearGradient>
        </Pressable>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: Colors.background },
  container: {
    flex: 1,
    paddingHorizontal: Spacing['2xl'],
    paddingTop: Spacing['3xl'],
    alignItems: 'center',
  },
  title: {
    fontFamily: Typography.fontFamily.extraBold,
    fontSize: Typography.fontSize['2xl'],
    color: Colors.textPrimary,
    marginBottom: Spacing.sm,
    letterSpacing: -0.5,
  },
  subtitle: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.base,
    color: Colors.textSecondary,
    marginBottom: Spacing['3xl'],
  },
  avatarContainer: {
    marginBottom: Spacing['2xl'],
    position: 'relative',
  },
  avatar: {
    width: 120,
    height: 120,
    borderRadius: 60,
    borderWidth: 3,
    borderColor: Colors.primary,
  },
  avatarPlaceholder: {
    width: 120,
    height: 120,
    borderRadius: 60,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 4,
  },
  avatarEmoji: { fontSize: 40 },
  avatarHint: {
    fontSize: Typography.fontSize.xs,
    color: Colors.textInverse,
    fontFamily: Typography.fontFamily.medium,
  },
  avatarBadge: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: Colors.surface,
    borderWidth: 2,
    borderColor: Colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarBadgeText: { fontSize: 14 },
  inputGroup: {
    width: '100%',
    gap: Spacing.sm,
    marginBottom: Spacing['2xl'],
  },
  inputLabel: {
    fontFamily: Typography.fontFamily.medium,
    fontSize: Typography.fontSize.sm,
    color: Colors.textSecondary,
  },
  inputWrapper: {
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.lg,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  input: {
    paddingHorizontal: Spacing.base,
    paddingVertical: 14,
    fontSize: Typography.fontSize.base,
    color: Colors.textPrimary,
    fontFamily: Typography.fontFamily.regular,
  },
  saveBtn: {
    width: '100%',
    borderRadius: BorderRadius.full,
    overflow: 'hidden',
    shadowColor: Colors.primary,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 8,
  },
  saveGradient: {
    paddingVertical: 16,
    alignItems: 'center',
  },
  saveText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.lg,
    color: Colors.textInverse,
  },
});
