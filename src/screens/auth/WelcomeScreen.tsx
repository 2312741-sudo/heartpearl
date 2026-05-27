// ─────────────────────────────────────────────
//  Welcome Screen
// ─────────────────────────────────────────────

import React, { useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  Dimensions,
  Animated,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { LinearGradient } from 'expo-linear-gradient';
import { AuthStackParamList } from '../../types';
import { Colors, Typography, Spacing, BorderRadius } from '../../constants/theme';

const { width, height } = Dimensions.get('window');

type Props = {
  navigation: NativeStackNavigationProp<AuthStackParamList, 'Welcome'>;
};

// Floating photo placeholder cards
const DEMO_CARDS = [
  { top: height * 0.08, left: width * 0.05, rotate: '-12deg', delay: 0 },
  { top: height * 0.12, left: width * 0.55, rotate: '8deg', delay: 150 },
  { top: height * 0.28, left: width * 0.15, rotate: '5deg', delay: 300 },
  { top: height * 0.32, left: width * 0.6, rotate: '-7deg', delay: 450 },
];

const CARD_EMOJIS = ['🌅', '🎉', '😄', '🌸'];

export default function WelcomeScreen({ navigation }: Props) {
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const slideAnim = useRef(new Animated.Value(40)).current;
  const cardAnims = DEMO_CARDS.map(() => ({
    opacity: useRef(new Animated.Value(0)).current,
    scale: useRef(new Animated.Value(0.7)).current,
  }));

  useEffect(() => {
    // Animate cards in sequence
    const cardAnimations = cardAnims.map((anim, i) =>
      Animated.parallel([
        Animated.timing(anim.opacity, {
          toValue: 1,
          duration: 600,
          delay: 200 + DEMO_CARDS[i].delay,
          useNativeDriver: true,
        }),
        Animated.spring(anim.scale, {
          toValue: 1,
          delay: 200 + DEMO_CARDS[i].delay,
          useNativeDriver: true,
        }),
      ])
    );

    // Animate bottom content
    Animated.parallel([
      ...cardAnimations,
      Animated.timing(fadeAnim, {
        toValue: 1,
        duration: 800,
        delay: 600,
        useNativeDriver: true,
      }),
      Animated.timing(slideAnim, {
        toValue: 0,
        duration: 800,
        delay: 600,
        useNativeDriver: true,
      }),
    ]).start();
  }, []);

  return (
    <View style={styles.container}>
      <LinearGradient
        colors={['#0A0A0F', '#13131A', '#1A1020']}
        style={StyleSheet.absoluteFillObject}
      />

      {/* Glow orb */}
      <View style={styles.glowOrb} />

      {/* Floating Demo Cards */}
      {DEMO_CARDS.map((card, i) => (
        <Animated.View
          key={i}
          style={[
            styles.demoCard,
            {
              top: card.top,
              left: card.left,
              transform: [
                { rotate: card.rotate },
                { scale: cardAnims[i].scale },
              ],
              opacity: cardAnims[i].opacity,
            },
          ]}
        >
          <LinearGradient
            colors={[Colors.surface, Colors.surfaceLight]}
            style={styles.demoCardInner}
          >
            <Text style={styles.demoCardEmoji}>{CARD_EMOJIS[i]}</Text>
          </LinearGradient>
        </Animated.View>
      ))}

      {/* Bottom Content */}
      <Animated.View
        style={[
          styles.bottomContent,
          { opacity: fadeAnim, transform: [{ translateY: slideAnim }] },
        ]}
      >
        {/* Logo */}
        <View style={styles.logoContainer}>
          <LinearGradient
            colors={Colors.gradientPrimary}
            style={styles.logoBadge}
          >
            <Text style={styles.logoEmoji}>📸</Text>
          </LinearGradient>
        </View>

        <Text style={styles.appName}>HeartPearl</Text>
        <Text style={styles.tagline}>
          Chia sẻ khoảnh khắc{'\n'}với những người thân yêu 💛
        </Text>

        {/* CTA Button */}
        <Pressable
          style={({ pressed }) => [styles.ctaButton, pressed && styles.ctaButtonPressed]}
          onPress={() => navigation.navigate('PhoneLogin')}
        >
          <LinearGradient
            colors={Colors.gradientPrimary}
            style={styles.ctaGradient}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 0 }}
          >
            <Text style={styles.ctaText}>Bắt đầu ngay</Text>
          </LinearGradient>
        </Pressable>

        <Text style={styles.termsText}>
          Bằng cách tiếp tục, bạn đồng ý với{' '}
          <Text style={styles.termsLink}>Điều khoản dịch vụ</Text> và{' '}
          <Text style={styles.termsLink}>Chính sách bảo mật</Text> của chúng tôi.
        </Text>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  glowOrb: {
    position: 'absolute',
    width: 300,
    height: 300,
    borderRadius: 150,
    backgroundColor: Colors.primary,
    opacity: 0.08,
    top: height * 0.2,
    left: width * 0.5 - 150,
    // Note: Use blur via expo-blur for proper glow effect
  },
  demoCard: {
    position: 'absolute',
    width: 130,
    height: 160,
    borderRadius: 20,
    overflow: 'hidden',
    shadowColor: Colors.primary,
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.3,
    shadowRadius: 12,
    elevation: 10,
  },
  demoCardInner: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: Colors.border,
    borderRadius: 20,
  },
  demoCardEmoji: {
    fontSize: 48,
  },
  bottomContent: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    paddingHorizontal: Spacing['2xl'],
    paddingBottom: 48,
    paddingTop: 32,
    backgroundColor: 'rgba(10,10,15,0.95)',
    borderTopLeftRadius: 32,
    borderTopRightRadius: 32,
    borderTopWidth: 1,
    borderColor: Colors.border,
    alignItems: 'center',
  },
  logoContainer: {
    marginBottom: Spacing.base,
  },
  logoBadge: {
    width: 64,
    height: 64,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  logoEmoji: {
    fontSize: 32,
  },
  appName: {
    fontFamily: Typography.fontFamily.extraBold,
    fontSize: Typography.fontSize['3xl'],
    color: Colors.textPrimary,
    marginBottom: Spacing.sm,
    letterSpacing: -1,
  },
  tagline: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.base,
    color: Colors.textSecondary,
    textAlign: 'center',
    lineHeight: 24,
    marginBottom: Spacing['2xl'],
  },
  ctaButton: {
    width: '100%',
    borderRadius: BorderRadius.full,
    overflow: 'hidden',
    marginBottom: Spacing.lg,
    shadowColor: Colors.primary,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.5,
    shadowRadius: 16,
    elevation: 10,
  },
  ctaButtonPressed: {
    opacity: 0.85,
    transform: [{ scale: 0.98 }],
  },
  ctaGradient: {
    paddingVertical: 16,
    alignItems: 'center',
  },
  ctaText: {
    fontFamily: Typography.fontFamily.bold,
    fontSize: Typography.fontSize.lg,
    color: Colors.textInverse,
    letterSpacing: 0.3,
  },
  termsText: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.xs,
    color: Colors.textMuted,
    textAlign: 'center',
    lineHeight: 18,
  },
  termsLink: {
    color: Colors.primary,
    fontFamily: Typography.fontFamily.medium,
  },
});
