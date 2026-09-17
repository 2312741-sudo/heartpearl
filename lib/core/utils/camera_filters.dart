import 'package:flutter/material.dart';

enum BeautyFilterType {
  normal,
  smoothSkin,     // TikTok Cà Mụn & Mịn Da
  babyRosy,       // Trắng Hồng Da Em Bé
  pearlPorcelain, // Trắng Sáng Ngọc Trai (Tone-up)
  goldenHour,     // Nắng Ấm / Sunkissed
  dreamyPastel,   // Mơ Màng Y2K / Pastel
}

class BeautyFilter {
  final BeautyFilterType type;
  final String name;
  final String icon;
  final ColorFilter? colorFilter;
  final Color overlayColor;
  final double blurSigma;    // Skin smoothing Gaussian diffusion (cà mịn da)
  final double blurOpacity;  // Độ đậm nhạt của lớp khuếch tán

  const BeautyFilter({
    required this.type,
    required this.name,
    required this.icon,
    this.colorFilter,
    this.overlayColor = Colors.transparent,
    this.blurSigma = 0.0,
    this.blurOpacity = 0.0,
  });

  static const List<BeautyFilter> all = [
    // 1. Gốc
    BeautyFilter(
      type: BeautyFilterType.normal,
      name: 'Gốc',
      icon: '🌿',
      colorFilter: null,
      overlayColor: Colors.transparent,
      blurSigma: 0.0,
      blurOpacity: 0.0,
    ),

    // 2. TikTok Cà Mụn (Smooth Skin Diffusion + Blemish Softening Matrix)
    BeautyFilter(
      type: BeautyFilterType.smoothSkin,
      name: 'Cà Mụn',
      icon: '✨',
      colorFilter: ColorFilter.matrix([
        1.05, 0.03, 0.02, 0, 18,
        0.02, 1.03, 0.02, 0, 16,
        0.01, 0.02, 1.00, 0, 14,
        0,    0,    0,    1, 0,
      ]),
      overlayColor: Color(0x26FFEBE8), // Peach soft light
      blurSigma: 2.2,                 // Khuếch tán làm mờ lỗ chân lông & vết thâm
      blurOpacity: 0.32,
    ),

    // 3. Trắng Hồng (Baby Face)
    BeautyFilter(
      type: BeautyFilterType.babyRosy,
      name: 'Trắng Hồng',
      icon: '🌸',
      colorFilter: ColorFilter.matrix([
        1.08, 0.02, 0.00, 0, 22,
        0.00, 1.02, 0.02, 0, 12,
        0.01, 0.01, 0.98, 0, 10,
        0,    0,    0,    1, 0,
      ]),
      overlayColor: Color(0x28FFBFD4),
      blurSigma: 1.8,
      blurOpacity: 0.28,
    ),

    // 4. Trắng Sáng Ngọc Trai (Tone-Up Porcelain)
    BeautyFilter(
      type: BeautyFilterType.pearlPorcelain,
      name: 'Ngọc Trai',
      icon: '💎',
      colorFilter: ColorFilter.matrix([
        1.06, 0.00, 0.02, 0, 24,
        0.00, 1.04, 0.02, 0, 22,
        0.02, 0.02, 1.08, 0, 26,
        0,    0,    0,    1, 0,
      ]),
      overlayColor: Color(0x20E5ECFF),
      blurSigma: 1.5,
      blurOpacity: 0.25,
    ),

    // 5. Nắng Ấm (Golden Hour Glow)
    BeautyFilter(
      type: BeautyFilterType.goldenHour,
      name: 'Nắng Ấm',
      icon: '☀️',
      colorFilter: ColorFilter.matrix([
        1.10, 0.04, 0.00, 0, 18,
        0.02, 1.05, 0.00, 0, 14,
        0.00, 0.02, 0.92, 0, 6,
        0,    0,    0,    1, 0,
      ]),
      overlayColor: Color(0x22FFE2B3),
      blurSigma: 1.6,
      blurOpacity: 0.26,
    ),

    // 6. Mơ Màng (Dreamy Y2K)
    BeautyFilter(
      type: BeautyFilterType.dreamyPastel,
      name: 'Mơ Màng',
      icon: '🔮',
      colorFilter: ColorFilter.matrix([
        1.05, 0.02, 0.04, 0, 16,
        0.01, 1.00, 0.03, 0, 12,
        0.04, 0.02, 1.08, 0, 18,
        0,    0,    0,    1, 0,
      ]),
      overlayColor: Color(0x26EAD6FF),
      blurSigma: 2.6,
      blurOpacity: 0.35,
    ),
  ];
}
