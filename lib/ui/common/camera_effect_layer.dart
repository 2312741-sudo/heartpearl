import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/utils/camera_filters.dart';
import '../../services/camera_effects_service.dart';

/// Lightweight GPU preview for the selected filter and beauty settings.
/// Final photos are rendered with the higher-quality, skin-masked pipeline.
class CameraEffectLayer extends StatelessWidget {
  final Widget child;
  final BeautyFilter filter;
  final double filterIntensity;
  final BeautySettings beauty;
  final bool showOriginal;

  const CameraEffectLayer({
    super.key,
    required this.child,
    required this.filter,
    required this.filterIntensity,
    required this.beauty,
    this.showOriginal = false,
  });

  @override
  Widget build(BuildContext context) {
    if (showOriginal) return child;

    Widget result = child;
    final filterColor = filter.colorFilterAt(filterIntensity);
    if (filterColor != null) {
      result = ColorFiltered(colorFilter: filterColor, child: result);
    }
    if (beauty.hasEffect) {
      result = ColorFiltered(
        colorFilter: ColorFilter.matrix(
          CameraEffectsService.previewBeautyMatrix(beauty),
        ),
        child: result,
      );
    }

    // Skin-smoothing: map overall*smoothing → subtle blur opacity.
    // sigma=2.8 is perceptible but not cartoonish. Clamp opacity to 0.18 max.
    final smoothing = beauty.enabled
        ? (beauty.smoothing * beauty.overall * 0.30).clamp(0.0, 0.18)
        : 0.0;
    final overlay = filter.overlayAt(filterIntensity);
    return Stack(
      fit: StackFit.expand,
      children: [
        result,
        if (smoothing > 0)
          IgnorePointer(
            child: Opacity(
              opacity: smoothing,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2.8, sigmaY: 2.8),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        if (overlay.a > 0) IgnorePointer(child: ColoredBox(color: overlay)),
      ],
    );
  }
}
