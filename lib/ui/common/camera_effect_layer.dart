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

    final smoothing = beauty.enabled
        ? (beauty.smoothing * beauty.overall * 0.12).clamp(0.0, 0.10)
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
                filter: ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        if (overlay.a > 0) IgnorePointer(child: ColoredBox(color: overlay)),
      ],
    );
  }
}
