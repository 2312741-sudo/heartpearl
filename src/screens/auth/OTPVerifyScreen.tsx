// ─────────────────────────────────────────────
//  OTP Verify Screen (placeholder — dùng sau
//  khi tích hợp Firebase Phone Auth đầy đủ)
// ─────────────────────────────────────────────

import React, { useMemo } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTranslation } from 'react-i18next';
import { useAppTheme, AppColors, Typography } from '../../constants/theme';

export default function OTPVerifyScreen() {
  const { t } = useTranslation();
  const { colors } = useAppTheme();
  const styles = useMemo(() => createStyles(colors), [colors]);

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.container}>
        <Text style={styles.text}>{t('otp.comingSoon')}</Text>
      </View>
    </SafeAreaView>
  );
}

const createStyles = (colors: AppColors) => StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  container: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  text: {
    color: colors.textPrimary,
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.base,
  },
});
