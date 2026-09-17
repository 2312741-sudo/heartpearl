import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_typography.dart';
import '../../core/l10n/app_strings.dart';
import '../../providers/settings_provider.dart';
import '../common/gradient_button.dart';
import 'login_screen.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D0410), Color(0xFF1E0D26), Color(0xFF120716)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Glowing background orb
          Positioned(
            top: size.height * 0.15,
            left: size.width * 0.5 - 150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
          ),

          // Floating Demo Cards
          Positioned(
            top: size.height * 0.08,
            left: size.width * 0.08,
            child: _buildFloatingCard('🌅', -0.2),
          ).animate().fadeIn(duration: 600.ms, delay: 100.ms).scale(),

          Positioned(
            top: size.height * 0.12,
            right: size.width * 0.08,
            child: _buildFloatingCard('🎉', 0.15),
          ).animate().fadeIn(duration: 600.ms, delay: 250.ms).scale(),

          Positioned(
            top: size.height * 0.28,
            left: size.width * 0.15,
            child: _buildFloatingCard('😄', 0.08),
          ).animate().fadeIn(duration: 600.ms, delay: 400.ms).scale(),

          Positioned(
            top: size.height * 0.32,
            right: size.width * 0.12,
            child: _buildFloatingCard('🌸', -0.12),
          ).animate().fadeIn(duration: 600.ms, delay: 550.ms).scale(),

          // Bottom Content
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceXl,
                AppDimens.space2Xl,
                AppDimens.spaceXl,
                AppDimens.space3Xl,
              ),
              decoration: BoxDecoration(
                color: AppColors.darkBackground.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDimens.radius2Xl),
                  topRight: Radius.circular(AppDimens.radius2Xl),
                ),
                border: Border(
                  top: BorderSide(color: AppColors.darkBorder.withValues(alpha: 0.5)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: AppDimens.glowShadow(AppColors.primary, opacity: 0.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ).animate().scale(delay: 200.ms, duration: 400.ms),

                  const SizedBox(height: AppDimens.spaceBase),

                  // Brand name
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Heart',
                        style: AppTypography.h1(color: AppColors.primaryLight),
                      ),
                      Text(
                        'Pearl',
                        style: AppTypography.h1(color: AppColors.pearl),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppDimens.spaceSm),

                  // Tagline
                  Text(
                    AppStrings.tr('welcome_tagline', lang: lang),
                    textAlign: TextAlign.center,
                    style: AppTypography.body(
                      color: AppColors.darkTextSecondary.withValues(alpha: 0.8),
                    ),
                  ),

                  const SizedBox(height: AppDimens.space2Xl),

                  // CTA Button
                  GradientButton(
                    text: AppStrings.tr('welcome_get_started', lang: lang),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: AppDimens.spaceBase),

                  // Terms notice
                  Text(
                    AppStrings.tr('welcome_terms', lang: lang),
                    textAlign: TextAlign.center,
                    style: AppTypography.caption(
                      color: AppColors.darkTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOut),
        ],
      ),
    );
  }

  Widget _buildFloatingCard(String emoji, double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 130,
        height: 155,
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
          border: Border.all(color: AppColors.darkBorderLight, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 48)),
        ),
      ),
    );
  }
}
