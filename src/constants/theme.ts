// ─────────────────────────────────────────────
//  Locket Clone — Design Tokens
// ─────────────────────────────────────────────

export const Colors = {
  // Brand (HeartPearl)
  primary: '#C42E5C',         // rose — main brand color
  primaryLight: '#E55080',    // rose light — hover states, highlights
  primaryDark: '#9C2549',     // for pressed states
  secondary: '#FF80A0',       // blush — secondary accents
  soft: '#FFD0DD',            // soft pink
  pearl: '#FFFFFF',           // pearl white
  pearlTint: '#F6EEFF',       // pearl lavender

  // Background
  background: '#120716',      // deep berry
  surface: '#1E0D26',         // slightly lighter surface/cards
  surfaceLight: '#281335',
  card: '#1E0D26',

  // Text
  textPrimary: '#FFFFFF',
  textSecondary: '#F6EEFF',   // 85% opacity pearl lavender
  textMuted: '#6A3555',       // muted rose — secondary text
  textInverse: '#120716',

  // UI
  border: '#3A1535',          // subtle border
  borderLight: '#4F1E48',
  overlay: 'rgba(18, 7, 22, 0.7)',
  overlayLight: 'rgba(18, 7, 22, 0.4)',

  // Status
  success: '#2ECC71',
  error: '#E74C3C',
  warning: '#F39C12',
  info: '#3498DB',

  // Gradients
  gradientPrimary: ['#C42E5C', '#E55080'] as const,
  gradientDark: ['#120716', '#1E0D26'] as const,
  gradientCard: ['rgba(196, 46, 92, 0.15)', 'rgba(196, 46, 92, 0.05)'] as const,

  transparent: 'transparent',
  white: '#FFFFFF',
  black: '#000000',
};

export const Typography = {
  fontFamily: {
    regular: 'Inter_400Regular',
    medium: 'Inter_500Medium',
    semiBold: 'Inter_600SemiBold',
    bold: 'Inter_700Bold',
    extraBold: 'Inter_800ExtraBold',
  },
  fontSize: {
    xs: 11,
    sm: 13,
    md: 15,
    base: 16,
    lg: 18,
    xl: 22,
    '2xl': 26,
    '3xl': 32,
    '4xl': 40,
    '5xl': 48,
  },
  lineHeight: {
    tight: 1.2,
    normal: 1.5,
    relaxed: 1.8,
  },
  letterSpacing: {
    label: 0.3,
  }
};

export const Spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  base: 16,
  lg: 20,
  xl: 24,
  '2xl': 32,
  '3xl': 40,
  '4xl': 48,
  '5xl': 64,
};

export const BorderRadius = {
  sm: 8,
  md: 12,
  lg: 14,
  xl: 20,
  '2xl': 32,
  full: 9999,
};

export const Shadows = {
  sm: {
    shadowColor: Colors.primaryLight,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.15,
    shadowRadius: 10,
    elevation: 3,
  },
  md: {
    shadowColor: Colors.primaryLight,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.20,
    shadowRadius: 15,
    elevation: 6,
  },
  lg: {
    shadowColor: Colors.primaryLight,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.30,
    shadowRadius: 20,
    elevation: 12,
  },
  glow: {
    shadowColor: Colors.primary,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.2, // 20% opacity glow as per Vibe Rules
    shadowRadius: 20,
    elevation: 10,
  },
};
