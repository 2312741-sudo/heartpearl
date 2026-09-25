import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../common/frosted_container.dart';

class CameraControls extends StatelessWidget {
  final VoidCallback onPickGallery;
  final VoidCallback onPointerDown;
  final VoidCallback onPointerUp;
  final VoidCallback onPointerCancel;
  final VoidCallback onFlipCamera;
  final bool isButtonPressed;
  final bool isRecording;
  final Animation<double> recordProgressAnimation;
  final bool isDark;

  const CameraControls({
    super.key,
    required this.onPickGallery,
    required this.onPointerDown,
    required this.onPointerUp,
    required this.onPointerCancel,
    required this.onFlipCamera,
    required this.isButtonPressed,
    required this.isRecording,
    required this.recordProgressAnimation,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceLg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Pick Media from Gallery
          GestureDetector(
            onTap: onPickGallery,
            child: FrostedContainer(
              borderRadius: AppDimens.radiusFull,
              padding: const EdgeInsets.all(14),
              backgroundColor: isDark
                  ? const Color(0x331E0D26)
                  : AppColors.lightSurface.withValues(alpha: 0.9),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : AppColors.lightBorder.withValues(alpha: 0.6),
                width: 1,
              ),
              child: Icon(
                LucideIcons.image,
                color: isDark
                    ? AppColors.white
                    : AppColors.lightTextPrimary,
                size: 24,
              ),
            ),
          ),

          // 2. Shutter Button (Tap: Photo, Press & Hold: Video)
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => onPointerDown(),
            onPointerUp: (_) => onPointerUp(),
            onPointerCancel: (_) => onPointerCancel(),
            child: AnimatedScale(
              scale: (isButtonPressed || isRecording) ? 0.92 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Progress Ring for Recording
                  SizedBox(
                    width: 86,
                    height: 86,
                    child: AnimatedBuilder(
                      animation: recordProgressAnimation,
                      builder: (context, child) {
                        return CircularProgressIndicator(
                          value: isRecording
                              ? recordProgressAnimation.value
                              : 0.0,
                          strokeWidth: 4,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primaryLight,
                          ),
                          backgroundColor: isRecording
                              ? (isDark
                                    ? Colors.white24
                                    : AppColors.lightBorder)
                              : Colors.transparent,
                        );
                      },
                    ),
                  ),

                  // Outer ring border
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (isRecording || isButtonPressed)
                            ? AppColors.primaryLight
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : AppColors.primary.withValues(alpha: 0.35)),
                        width: 3.5,
                      ),
                    ),
                  ),

                  // Inner Shutter Button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: isRecording ? 48 : 64,
                    height: isRecording ? 48 : 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: AppDimens.glowShadow(
                        AppColors.primary,
                        opacity: (isRecording || isButtonPressed) ? 0.8 : 0.4,
                      ),
                    ),
                    child: isRecording
                        ? Center(
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),

          // 3. Flip Camera Facing
          GestureDetector(
            onTap: onFlipCamera,
            child: FrostedContainer(
              borderRadius: AppDimens.radiusFull,
              padding: const EdgeInsets.all(14),
              backgroundColor: isDark
                  ? const Color(0x331E0D26)
                  : AppColors.lightSurface.withValues(alpha: 0.9),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : AppColors.lightBorder.withValues(alpha: 0.6),
                width: 1,
              ),
              child: Icon(
                LucideIcons.switchCamera,
                color: isDark
                    ? AppColors.white
                    : AppColors.lightTextPrimary,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
