import 'package:flutter/material.dart';

enum FilterCategory {
  natural('Natural', '🌿'),
  koreanBeauty('Korean', '🌸'),
  filmVintage('Film', '🎞️'),
  editorial('Editorial', '◼️'),
  dreamy('Dreamy', '☁️'),
  travelLifestyle('Travel', '🌅'),
  night('Night', '🌙'),
  monochrome('Mono', '🖤');

  final String label;
  final String icon;
  const FilterCategory(this.label, this.icon);
}

enum BeautyFilterType {
  normal,
  pearlNatural,
  freshSkin,
  cleanLight,
  milkGlow,
  rosySeoul,
  softPeach,
  warmFilm,
  fadedMemory,
  retroGrain,
  cleanEditorial,
  coolFashion,
  highContrast,
  softBloom,
  dreamyPastel,
  angelGlow,
  goldenHour,
  oceanBlue,
  forestMood,
  nightPearl,
  neonCity,
  lowLightWarm,
  monoLuxe,
  silverFilm,
  deepNoir,
}

class FilterTuning {
  final double brightness;
  final double contrast;
  final double saturation;
  final double warmth;
  final double tint;
  final double fade;

  const FilterTuning({
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.warmth = 0,
    this.tint = 0,
    this.fade = 0,
  });

  List<double> get matrix {
    const lr = 0.213;
    const lg = 0.715;
    const lb = 0.072;
    final inverseSaturation = 1 - saturation;
    // Boost gains so color temperature (warmth) and tint are clearly visible
    final redGain = 1 + warmth * 0.20 + tint * 0.10;
    final greenGain = 1 - tint * 0.08;
    final blueGain = 1 - warmth * 0.20 + tint * 0.06;
    // Bias scaling: brightness and fade visibly shift values in 0-255 scale
    final bias = brightness * 60 + 128 * (1 - contrast) + fade * 24;

    return [
      (lr * inverseSaturation + saturation) * contrast * redGain,
      lg * inverseSaturation * contrast * redGain,
      lb * inverseSaturation * contrast * redGain,
      0,
      bias + warmth * 8,
      lr * inverseSaturation * contrast * greenGain,
      (lg * inverseSaturation + saturation) * contrast * greenGain,
      lb * inverseSaturation * contrast * greenGain,
      0,
      bias,
      lr * inverseSaturation * contrast * blueGain,
      lg * inverseSaturation * contrast * blueGain,
      (lb * inverseSaturation + saturation) * contrast * blueGain,
      0,
      bias - warmth * 8,
      0,
      0,
      0,
      1,
      0,
    ];
  }
}

class BeautyFilter {
  static const List<double> identityMatrix = [
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  final BeautyFilterType type;
  final String name;
  final String icon;
  final FilterCategory? category;
  final FilterTuning tuning;
  final Color overlayColor;
  final double defaultIntensity;
  final List<Color> thumbnailColors;

  const BeautyFilter({
    required this.type,
    required this.name,
    required this.icon,
    required this.tuning,
    required this.thumbnailColors,
    this.category,
    this.overlayColor = Colors.transparent,
    this.defaultIntensity = 0.65,
  });

  String get id => type.name;
  bool get isOriginal => type == BeautyFilterType.normal;
  List<double> get matrix => tuning.matrix;

  /// Compatibility with older call sites. New UI should use [colorFilterAt].
  ColorFilter? get colorFilter => colorFilterAt(defaultIntensity);
  double get blurSigma => 0;
  double get blurOpacity => 0;

  List<double> matrixAt(double intensity) {
    final amount = intensity.clamp(0.0, 1.0);
    final target = matrix;
    return List<double>.generate(
      20,
      (index) =>
          identityMatrix[index] +
          (target[index] - identityMatrix[index]) * amount,
      growable: false,
    );
  }

  ColorFilter? colorFilterAt(double intensity) {
    if (isOriginal || intensity <= 0) return null;
    return ColorFilter.matrix(matrixAt(intensity));
  }

  Color overlayAt(double intensity) => overlayColor == Colors.transparent
      ? Colors.transparent
      : overlayColor.withValues(
          alpha: overlayColor.a * intensity.clamp(0.0, 1.0),
        );

  static BeautyFilter byId(String? id) =>
      all.firstWhere((filter) => filter.id == id, orElse: () => all.first);

  static List<BeautyFilter> inCategory(FilterCategory category) => all
      .where((filter) => filter.category == category)
      .toList(growable: false);

  static const List<BeautyFilter> all = [
    BeautyFilter(
      type: BeautyFilterType.normal,
      name: 'Gốc',
      icon: '◉',
      tuning: FilterTuning(),
      thumbnailColors: [Color(0xFF444444), Color(0xFF999999)],
      defaultIntensity: 0,
    ),

    BeautyFilter(
      type: BeautyFilterType.pearlNatural,
      name: 'Pearl Natural',
      icon: '🫧',
      category: FilterCategory.natural,
      tuning: FilterTuning(
        brightness: .05,
        contrast: 1.025,
        saturation: 1.02,
        warmth: .08,
      ),
      thumbnailColors: [Color(0xFFFFE5DD), Color(0xFFD8E8E2)],
      defaultIntensity: .52,
    ),
    BeautyFilter(
      type: BeautyFilterType.freshSkin,
      name: 'Fresh Skin',
      icon: '🍃',
      category: FilterCategory.natural,
      tuning: FilterTuning(
        brightness: .06,
        contrast: 1.015,
        saturation: 1.035,
        warmth: .04,
        tint: -.04,
      ),
      thumbnailColors: [Color(0xFFFFE8D8), Color(0xFFCDE7D7)],
      defaultIntensity: .58,
    ),
    BeautyFilter(
      type: BeautyFilterType.cleanLight,
      name: 'Clean Light',
      icon: '🤍',
      category: FilterCategory.natural,
      tuning: FilterTuning(brightness: .14, contrast: 1.01, saturation: .98),
      thumbnailColors: [Color(0xFFFFF2E8), Color(0xFFDDE8F4)],
      defaultIntensity: .48,
    ),

    BeautyFilter(
      type: BeautyFilterType.milkGlow,
      name: 'Milk Glow',
      icon: '🥛',
      category: FilterCategory.koreanBeauty,
      tuning: FilterTuning(
        brightness: .16,
        contrast: .98,
        saturation: .96,
        warmth: .04,
      ),
      overlayColor: Color(0x0CFFF8F2),
      thumbnailColors: [Color(0xFFFFF7F1), Color(0xFFE8E5F2)],
      defaultIntensity: .55,
    ),
    BeautyFilter(
      type: BeautyFilterType.rosySeoul,
      name: 'Rosy Seoul',
      icon: '🌷',
      category: FilterCategory.koreanBeauty,
      tuning: FilterTuning(
        brightness: .08,
        contrast: 1.01,
        saturation: 1.06,
        warmth: .08,
        tint: .18,
      ),
      overlayColor: Color(0x0EFFB5C7),
      thumbnailColors: [Color(0xFFFFC9D2), Color(0xFFFFEAE3)],
      defaultIntensity: .52,
    ),
    BeautyFilter(
      type: BeautyFilterType.softPeach,
      name: 'Soft Peach',
      icon: '🍑',
      category: FilterCategory.koreanBeauty,
      tuning: FilterTuning(
        brightness: .07,
        contrast: 1.015,
        saturation: 1.04,
        warmth: .2,
      ),
      overlayColor: Color(0x0CFFC19E),
      thumbnailColors: [Color(0xFFFFB895), Color(0xFFFFE1D0)],
      defaultIntensity: .56,
    ),

    BeautyFilter(
      type: BeautyFilterType.warmFilm,
      name: 'Warm Film',
      icon: '🎞️',
      category: FilterCategory.filmVintage,
      tuning: FilterTuning(contrast: 1.06, saturation: .93, warmth: .34),
      overlayColor: Color(0x0EB37A45),
      thumbnailColors: [Color(0xFFB97B4E), Color(0xFFE4C49A)],
      defaultIntensity: .68,
    ),
    BeautyFilter(
      type: BeautyFilterType.fadedMemory,
      name: 'Faded Memory',
      icon: '📜',
      category: FilterCategory.filmVintage,
      tuning: FilterTuning(
        brightness: .04,
        contrast: .86,
        saturation: .78,
        warmth: .2,
        fade: .25,
      ),
      overlayColor: Color(0x0CE8D6B9),
      thumbnailColors: [Color(0xFF9A816B), Color(0xFFD8C7AB)],
      defaultIntensity: .7,
    ),
    BeautyFilter(
      type: BeautyFilterType.retroGrain,
      name: 'Retro Grain',
      icon: '📻',
      category: FilterCategory.filmVintage,
      tuning: FilterTuning(contrast: 1.1, saturation: .88, warmth: .3),
      overlayColor: Color(0x0F8B5A35),
      thumbnailColors: [Color(0xFF6F4632), Color(0xFFC18C5D)],
      defaultIntensity: .72,
    ),

    BeautyFilter(
      type: BeautyFilterType.cleanEditorial,
      name: 'Clean Editorial',
      icon: '▫️',
      category: FilterCategory.editorial,
      tuning: FilterTuning(contrast: 1.075, saturation: .93),
      thumbnailColors: [Color(0xFFDADADA), Color(0xFF777777)],
      defaultIntensity: .62,
    ),
    BeautyFilter(
      type: BeautyFilterType.coolFashion,
      name: 'Cool Fashion',
      icon: '🧊',
      category: FilterCategory.editorial,
      tuning: FilterTuning(
        contrast: 1.055,
        saturation: .95,
        warmth: -.26,
        tint: .06,
      ),
      overlayColor: Color(0x0C7EB8FF),
      thumbnailColors: [Color(0xFF7993B3), Color(0xFFD2E1F2)],
      defaultIntensity: .64,
    ),
    BeautyFilter(
      type: BeautyFilterType.highContrast,
      name: 'High Contrast',
      icon: '◆',
      category: FilterCategory.editorial,
      tuning: FilterTuning(contrast: 1.16, saturation: 1.02),
      thumbnailColors: [Color(0xFF242424), Color(0xFFF1F1F1)],
      defaultIntensity: .66,
    ),

    BeautyFilter(
      type: BeautyFilterType.softBloom,
      name: 'Soft Bloom',
      icon: '🌼',
      category: FilterCategory.dreamy,
      tuning: FilterTuning(
        brightness: .12,
        contrast: .93,
        saturation: .98,
        warmth: .1,
        fade: .14,
      ),
      overlayColor: Color(0x0FFFF3E6),
      thumbnailColors: [Color(0xFFFFE7C7), Color(0xFFFFF6EE)],
      defaultIntensity: .62,
    ),
    BeautyFilter(
      type: BeautyFilterType.dreamyPastel,
      name: 'Dreamy Pastel',
      icon: '🔮',
      category: FilterCategory.dreamy,
      tuning: FilterTuning(
        brightness: .08,
        contrast: .94,
        saturation: .9,
        warmth: -.08,
        tint: .18,
        fade: .18,
      ),
      overlayColor: Color(0x10D8C6FF),
      thumbnailColors: [Color(0xFFB8A5DE), Color(0xFFF5D8EE)],
      defaultIntensity: .67,
    ),
    BeautyFilter(
      type: BeautyFilterType.angelGlow,
      name: 'Angel Glow',
      icon: '🪽',
      category: FilterCategory.dreamy,
      tuning: FilterTuning(
        brightness: .18,
        contrast: .92,
        saturation: .96,
        tint: .08,
        fade: .12,
      ),
      overlayColor: Color(0x0FFFE9F8),
      thumbnailColors: [Color(0xFFFFEAF6), Color(0xFFE4EFFF)],
      defaultIntensity: .58,
    ),

    BeautyFilter(
      type: BeautyFilterType.goldenHour,
      name: 'Golden Hour',
      icon: '☀️',
      category: FilterCategory.travelLifestyle,
      tuning: FilterTuning(contrast: 1.06, saturation: 1.08, warmth: .5),
      overlayColor: Color(0x10FFB45D),
      thumbnailColors: [Color(0xFFFF9838), Color(0xFFFFD08A)],
      defaultIntensity: .64,
    ),
    BeautyFilter(
      type: BeautyFilterType.oceanBlue,
      name: 'Ocean Blue',
      icon: '🌊',
      category: FilterCategory.travelLifestyle,
      tuning: FilterTuning(
        contrast: 1.04,
        saturation: 1.1,
        warmth: -.38,
        tint: -.08,
      ),
      overlayColor: Color(0x0B168DCC),
      thumbnailColors: [Color(0xFF167AA4), Color(0xFF87D7E9)],
      defaultIntensity: .63,
    ),
    BeautyFilter(
      type: BeautyFilterType.forestMood,
      name: 'Forest Mood',
      icon: '🌲',
      category: FilterCategory.travelLifestyle,
      tuning: FilterTuning(
        contrast: 1.04,
        saturation: .96,
        warmth: -.04,
        tint: -.28,
      ),
      overlayColor: Color(0x0C315C3B),
      thumbnailColors: [Color(0xFF315A3A), Color(0xFF9EBC7C)],
      defaultIntensity: .66,
    ),

    BeautyFilter(
      type: BeautyFilterType.nightPearl,
      name: 'Night Pearl',
      icon: '🌙',
      category: FilterCategory.night,
      tuning: FilterTuning(
        brightness: .14,
        contrast: 1.04,
        saturation: 1.02,
        warmth: -.24,
        tint: .12,
      ),
      overlayColor: Color(0x0B6E70FF),
      thumbnailColors: [Color(0xFF202342), Color(0xFF777CB5)],
      defaultIntensity: .56,
    ),
    BeautyFilter(
      type: BeautyFilterType.neonCity,
      name: 'Neon City',
      icon: '🌃',
      category: FilterCategory.night,
      tuning: FilterTuning(
        contrast: 1.12,
        saturation: 1.18,
        warmth: -.2,
        tint: .36,
      ),
      overlayColor: Color(0x0CFD2BC1),
      thumbnailColors: [Color(0xFF3A146D), Color(0xFFEB2CA6)],
      defaultIntensity: .72,
    ),
    BeautyFilter(
      type: BeautyFilterType.lowLightWarm,
      name: 'Low-light Warm',
      icon: '🕯️',
      category: FilterCategory.night,
      tuning: FilterTuning(
        brightness: .22,
        contrast: 1.015,
        saturation: .95,
        warmth: .34,
      ),
      overlayColor: Color(0x0DFF9C50),
      thumbnailColors: [Color(0xFF5F3928), Color(0xFFD59053)],
      defaultIntensity: .58,
    ),

    BeautyFilter(
      type: BeautyFilterType.monoLuxe,
      name: 'Mono Luxe',
      icon: '🖤',
      category: FilterCategory.monochrome,
      tuning: FilterTuning(contrast: 1.08, saturation: 0),
      thumbnailColors: [Color(0xFF151515), Color(0xFFB9B9B9)],
      defaultIntensity: 1,
    ),
    BeautyFilter(
      type: BeautyFilterType.silverFilm,
      name: 'Silver Film',
      icon: '🩶',
      category: FilterCategory.monochrome,
      tuning: FilterTuning(
        brightness: .1,
        contrast: .94,
        saturation: 0,
        warmth: -.12,
        fade: .12,
      ),
      overlayColor: Color(0x0A9EB7CC),
      thumbnailColors: [Color(0xFF60676E), Color(0xFFD8DFE4)],
      defaultIntensity: 1,
    ),
    BeautyFilter(
      type: BeautyFilterType.deepNoir,
      name: 'Deep Noir',
      icon: '♠️',
      category: FilterCategory.monochrome,
      tuning: FilterTuning(brightness: -.08, contrast: 1.22, saturation: 0),
      thumbnailColors: [Color(0xFF050505), Color(0xFF696969)],
      defaultIntensity: 1,
    ),
  ];
}

class BeautySettings {
  final bool enabled;
  final double overall;
  final double smoothing;
  final double toneEvenness;
  final double blemishReduction;
  final double brightness;
  final double vitality;
  final double highlightReduction;

  const BeautySettings({
    this.enabled = true,
    this.overall = .52,
    this.smoothing = .48,
    this.toneEvenness = .32,
    this.blemishReduction = .28,
    this.brightness = .22,
    this.vitality = .26,
    this.highlightReduction = .22,
  });

  static const off = BeautySettings(enabled: false, overall: 0);
  bool get hasEffect => enabled && overall > 0;

  BeautySettings copyWith({
    bool? enabled,
    double? overall,
    double? smoothing,
    double? toneEvenness,
    double? blemishReduction,
    double? brightness,
    double? vitality,
    double? highlightReduction,
  }) => BeautySettings(
    enabled: enabled ?? this.enabled,
    overall: overall ?? this.overall,
    smoothing: smoothing ?? this.smoothing,
    toneEvenness: toneEvenness ?? this.toneEvenness,
    blemishReduction: blemishReduction ?? this.blemishReduction,
    brightness: brightness ?? this.brightness,
    vitality: vitality ?? this.vitality,
    highlightReduction: highlightReduction ?? this.highlightReduction,
  );

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'overall': overall,
    'smoothing': smoothing,
    'toneEvenness': toneEvenness,
    'blemishReduction': blemishReduction,
    'brightness': brightness,
    'vitality': vitality,
    'highlightReduction': highlightReduction,
  };

  factory BeautySettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const BeautySettings();
    double read(String key, double fallback) =>
        ((map[key] as num?)?.toDouble() ?? fallback).clamp(0, 1);
    return BeautySettings(
      enabled: map['enabled'] as bool? ?? true,
      overall: read('overall', .52),
      smoothing: read('smoothing', .48),
      toneEvenness: read('toneEvenness', .32),
      blemishReduction: read('blemishReduction', .28),
      brightness: read('brightness', .22),
      vitality: read('vitality', .26),
      highlightReduction: read('highlightReduction', .22),
    );
  }
}
