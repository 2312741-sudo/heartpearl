// ─────────────────────────────────────────────
//  Create Profile Screen
// ─────────────────────────────────────────────

import React, { useState, useMemo } from 'react';
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
import { useTranslation } from 'react-i18next';
import { auth, storage } from '../../services/firebase.config';
import { updateProfile } from 'firebase/auth';
import { ref, uploadBytesResumable, getDownloadURL } from 'firebase/storage';
import { updateUserDocument, isUsernameAvailable } from '../../services/auth.service';
import { useAppTheme, AppColors, Typography, Spacing, BorderRadius } from '../../constants/theme';

export default function CreateProfileScreen() {
  const { t } = useTranslation();
  const { colors } = useAppTheme();
  const styles = useMemo(() => createStyles(colors), [colors]);

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
      Alert.alert(t('profile.alert'), t('profile.err.noDisplayName'));
      return;
    }
    
    const cleanUsername = username.trim().toLowerCase();
    if (!cleanUsername) {
      Alert.alert(t('profile.alert'), t('profile.err.noUsername'));
      return;
    }

    if (cleanUsername.length < 3) {
      Alert.alert(t('profile.alert'), t('profile.err.shortUsername'));
      return;
    }

    const usernameRegex = /^[a-z0-9_.]+$/;
    if (!usernameRegex.test(cleanUsername)) {
      Alert.alert(t('profile.alert'), t('profile.err.invalidUsername'));
      return;
    }

    const user = auth.currentUser;
    if (!user) return;

    setLoading(true);
    try {
      const available = await isUsernameAvailable(cleanUsername);
      if (!available) {
        Alert.alert(t('auth.error'), t('profile.err.takenUsername'));
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
      Alert.alert(t('auth.error'), t('profile.err.saveFailed'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.container}>
        <Text style={styles.title}>{t('profile.createTitle')}</Text>
        <Text style={styles.subtitle}>
          {t('profile.createSub')}
        </Text>

        {/* Avatar Picker */}
        <Pressable style={styles.avatarContainer} onPress={pickAvatar}>
          {avatarUri ? (
            <Image source={{ uri: avatarUri }} style={styles.avatar} />
          ) : (
            <LinearGradient
              colors={colors.gradientPrimary}
              style={styles.avatarPlaceholder}
            >
              <Text style={styles.avatarEmoji}>👤</Text>
              <Text style={styles.avatarHint}>{t('profile.pickAvatar')}</Text>
            </LinearGradient>
          )}
          <View style={styles.avatarBadge}>
            <Text style={styles.avatarBadgeText}>✏️</Text>
          </View>
        </Pressable>

        {/* Name Input */}
        <View style={styles.inputGroup}>
          <Text style={styles.inputLabel}>{t('profile.displayName')}</Text>
          <View style={styles.inputWrapper}>
            <TextInput
              style={styles.input}
              placeholder={t('profile.displayNamePlaceholder')}
              placeholderTextColor={colors.textMuted}
              value={displayName}
              onChangeText={setDisplayName}
              selectionColor={colors.primary}
              maxLength={30}
            />
          </View>
        </View>

        {/* Username Input */}
        <View style={styles.inputGroup}>
          <Text style={styles.inputLabel}>{t('profile.username')}</Text>
          <View style={styles.inputWrapper}>
            <TextInput
              style={styles.input}
              placeholder={t('profile.usernamePlaceholder')}
              placeholderTextColor={colors.textMuted}
              value={username}
              onChangeText={(text) => {
                const cleaned = text.toLowerCase().replace(/[^a-z0-9_.]/g, '');
                setUsername(cleaned);
              }}
              selectionColor={colors.primary}
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
            colors={colors.gradientPrimary}
            style={styles.saveGradient}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 0 }}
          >
            {loading ? (
              <ActivityIndicator color={colors.textInverse} />
            ) : (
              <Text style={styles.saveText}>{t('profile.saveContinue')}</Text>
            )}
          </LinearGradient>
        </Pressable>
      </View>
    </SafeAreaView>
  );
}

const createStyles = (colors: AppColors) => StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  container: {
    flex: 1,
    paddingHorizontal: Spacing['2xl'],
    paddingTop: Spacing['3xl'],
    alignItems: 'center',
  },
  title: {
    fontFamily: Typography.fontFamily.extraBold,
    fontSize: Typography.fontSize['2xl'],
    color: colors.textPrimary,
    marginBottom: Spacing.sm,
    letterSpacing: -0.5,
  },
  subtitle: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.base,
    color: colors.textSecondary,
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
    borderColor: colors.primary,
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
    color: colors.textInverse,
    fontFamily: Typography.fontFamily.medium,
  },
  avatarBadge: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: colors.surface,
    borderWidth: 2,
    borderColor: colors.primary,
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
    color: colors.textSecondary,
  },
  inputWrapper: {
    backgroundColor: colors.surface,
    borderRadius: BorderRadius.lg,
    borderWidth: 1,
    borderColor: colors.border,
  },
  input: {
    paddingHorizontal: Spacing.base,
    paddingVertical: 14,
    fontSize: Typography.fontSize.base,
    color: colors.textPrimary,
    fontFamily: Typography.fontFamily.regular,
  },
  saveBtn: {
    width: '100%',
    borderRadius: BorderRadius.full,
    overflow: 'hidden',
    shadowColor: colors.primary,
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
    color: colors.textInverse,
  },
});
