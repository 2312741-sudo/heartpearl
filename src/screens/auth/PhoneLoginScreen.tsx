// ─────────────────────────────────────────────
//  Phone Login Screen
// ─────────────────────────────────────────────

import React, { useState, useRef, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  Pressable,
  Keyboard,
  KeyboardAvoidingView,
  Platform,
  Alert,
  ActivityIndicator,
  Animated,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { LinearGradient } from 'expo-linear-gradient';
import { useTranslation } from 'react-i18next';
import { AuthStackParamList } from '../../types';
import { useAppTheme, AppColors, Typography, Spacing, BorderRadius } from '../../constants/theme';
import { signInWithEmail, signUpWithEmail } from '../../services/auth.service';
import { useAuthStore } from '../../store/auth.store';

type Props = {
  navigation: NativeStackNavigationProp<AuthStackParamList, 'PhoneLogin'>;
};

export default function PhoneLoginScreen({ navigation }: Props) {
  const { t } = useTranslation();
  const { colors } = useAppTheme();
  const styles = useMemo(() => createStyles(colors), [colors]);

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isSignUp, setIsSignUp] = useState(false);
  const [loading, setLoading] = useState(false);
  const shakeAnim = useRef(new Animated.Value(0)).current;

  const shake = () => {
    Animated.sequence([
      Animated.timing(shakeAnim, { toValue: 10, duration: 80, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: -10, duration: 80, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: 6, duration: 80, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: -6, duration: 80, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: 0, duration: 80, useNativeDriver: true }),
    ]).start();
  };

  const handleSubmit = async () => {
    if (!email.trim() || !password.trim()) {
      shake();
      return;
    }
    Keyboard.dismiss();
    setLoading(true);
    try {
      if (isSignUp) {
        await signUpWithEmail(email.trim(), password, 'Người dùng');
        navigation.navigate('CreateProfile');
      } else {
        await signInWithEmail(email.trim(), password);
        // Auth state change will handle navigation automatically
      }
    } catch (error: any) {
      shake();
      const msg =
        error.code === 'auth/user-not-found'
          ? t('auth.error.userNotFound')
          : error.code === 'auth/wrong-password'
          ? t('auth.error.wrongPassword')
          : error.code === 'auth/email-already-in-use'
          ? t('auth.error.emailInUse')
          : error.code === 'auth/weak-password'
          ? t('auth.error.weakPassword')
          : t('auth.error.default');
      Alert.alert(t('auth.error'), msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.safe}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.container}
      >
        {/* Header */}
        <View style={styles.header}>
          <Pressable style={styles.backBtn} onPress={() => navigation.goBack()}>
            <Text style={styles.backText}>←</Text>
          </Pressable>
        </View>

        <View style={styles.content}>
          {/* Title */}
          <View style={styles.titleSection}>
            <LinearGradient
              colors={colors.gradientPrimary}
              style={styles.iconBadge}
            >
              <Text style={styles.iconEmoji}>
                {isSignUp ? '✨' : '👋'}
              </Text>
            </LinearGradient>
            <Text style={styles.title}>
              {isSignUp ? t('login.titleUp') : t('login.titleIn')}
            </Text>
            <Text style={styles.subtitle}>
              {isSignUp ? t('login.subUp') : t('login.subIn')}
            </Text>
          </View>

          {/* Form */}
          <Animated.View
            style={[styles.form, { transform: [{ translateX: shakeAnim }] }]}
          >
            <View style={styles.inputGroup}>
              <Text style={styles.inputLabel}>{t('login.email')}</Text>
              <View style={styles.inputWrapper}>
                <TextInput
                  style={styles.input}
                  placeholder="email@example.com"
                  placeholderTextColor={colors.textMuted}
                  value={email}
                  onChangeText={setEmail}
                  keyboardType="email-address"
                  autoCapitalize="none"
                  autoCorrect={false}
                  selectionColor={colors.primary}
                />
              </View>
            </View>

            <View style={styles.inputGroup}>
              <Text style={styles.inputLabel}>{t('login.password')}</Text>
              <View style={styles.inputWrapper}>
                <TextInput
                  style={styles.input}
                  placeholder={t('login.passwordMin')}
                  placeholderTextColor={colors.textMuted}
                  value={password}
                  onChangeText={setPassword}
                  secureTextEntry
                  selectionColor={colors.primary}
                />
              </View>
            </View>
          </Animated.View>

          {/* Submit Button */}
          <Pressable
            style={({ pressed }) => [
              styles.submitBtn,
              pressed && { opacity: 0.85, transform: [{ scale: 0.98 }] },
              (!email || !password) && styles.submitBtnDisabled,
            ]}
            onPress={handleSubmit}
            disabled={loading}
          >
            <LinearGradient
              colors={colors.gradientPrimary}
              style={styles.submitGradient}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 0 }}
            >
              {loading ? (
                <ActivityIndicator color={colors.textInverse} />
              ) : (
                <Text style={styles.submitText}>
                  {isSignUp ? t('login.btnUp') : t('login.btnIn')}
                </Text>
              )}
            </LinearGradient>
          </Pressable>

          {/* Toggle sign up / sign in */}
          <Pressable
            style={styles.toggleBtn}
            onPress={() => setIsSignUp(!isSignUp)}
          >
            <Text style={styles.toggleText}>
              {isSignUp ? t('login.toggleUp') : t('login.toggleIn')}
              <Text style={styles.toggleLink}>
                {isSignUp ? t('login.toggleLinkUp') : t('login.toggleLinkIn')}
              </Text>
            </Text>
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const createStyles = (colors: AppColors) => StyleSheet.create({
  safe: {
    flex: 1,
    backgroundColor: colors.background,
  },
  container: {
    flex: 1,
  },
  header: {
    paddingHorizontal: Spacing['2xl'],
    paddingTop: Spacing.base,
  },
  backBtn: {
    width: 40,
    height: 40,
    borderRadius: 12,
    backgroundColor: colors.surface,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: colors.border,
  },
  backText: {
    fontSize: 20,
    color: colors.textPrimary,
  },
  content: {
    flex: 1,
    paddingHorizontal: Spacing['2xl'],
    paddingTop: Spacing['2xl'],
  },
  titleSection: {
    marginBottom: Spacing['3xl'],
  },
  iconBadge: {
    width: 56,
    height: 56,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: Spacing.base,
  },
  iconEmoji: {
    fontSize: 28,
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
    lineHeight: 22,
  },
  form: {
    gap: Spacing.lg,
    marginBottom: Spacing['2xl'],
  },
  inputGroup: {
    gap: Spacing.sm,
  },
  inputLabel: {
    fontFamily: Typography.fontFamily.medium,
    fontSize: Typography.fontSize.sm,
    color: colors.textSecondary,
    letterSpacing: 0.3,
  },
  inputWrapper: {
    backgroundColor: colors.surface,
    borderRadius: BorderRadius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    overflow: 'hidden',
  },
  input: {
    paddingHorizontal: Spacing.base,
    paddingVertical: 14,
    fontSize: Typography.fontSize.base,
    color: colors.textPrimary,
    fontFamily: Typography.fontFamily.regular,
  },
  submitBtn: {
    borderRadius: BorderRadius.full,
    overflow: 'hidden',
    marginBottom: Spacing.lg,
    shadowColor: colors.primary,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 8,
  },
  submitBtnDisabled: {
    opacity: 0.6,
  },
  submitGradient: {
    paddingVertical: 16,
    alignItems: 'center',
  },
  submitText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.lg,
    color: colors.textInverse,
  },
  toggleBtn: {
    alignItems: 'center',
    paddingVertical: Spacing.md,
  },
  toggleText: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.sm,
    color: colors.textSecondary,
  },
  toggleLink: {
    color: colors.primary,
    fontFamily: Typography.fontFamily.semiBold,
  },
});
