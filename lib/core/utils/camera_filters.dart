import 'package:flutter/material.dart';

enum BeautyFilterType {
  normal,
  softGlow,
  pearlSkin,
  rosyBlush,
}

class BeautyFilter {
  final BeautyFilterType type;
  final String name;
  final ColorFilter? colorFilter;
  final Color overlayColor;

  const BeautyFilter({
    required this.type,
    required this.name,
    this.colorFilter,
    this.overlayColor = Colors.transparent,
  });

  static const List<BeautyFilter> all = [
    BeautyFilter(
      type: BeautyFilterType.normal,
      name: 'Gốc',
      colorFilter: null,
      overlayColor: Colors.transparent,
    ),
    BeautyFilter(
      type: BeautyFilterType.softGlow,
      name: 'Soft Glow',
      colorFilter: ColorFilter.matrix([
        1.05, 0.02, 0.02, 0, 15,
        0, 1.00, 0, 0, 10,
        0, 0, 0.92, 0, 10,
        0, 0, 0, 1, 0,
      ]),
      overlayColor: Color(0x1AFFB0C8),
    ),
    BeautyFilter(
      type: BeautyFilterType.pearlSkin,
      name: 'Pearl Skin',
      colorFilter: ColorFilter.matrix([
        1.05, 0, 0.04, 0, 20,
        0, 1.00, 0.02, 0, 15,
        0.02, 0.02, 1.05, 0, 12,
        0, 0, 0, 1, 0,
      ]),
      overlayColor: Color(0x1FE8D8FF),
    ),
    BeautyFilter(
      type: BeautyFilterType.rosyBlush,
      name: 'Rosy Blush',
      colorFilter: ColorFilter.matrix([
        1.10, 0.02, 0, 0, 12,
        0.02, 0.98, 0.02, 0, 5,
        0, 0, 0.90, 0, 5,
        0, 0, 0, 1, 0,
      ]),
      overlayColor: Color(0x1FFF80A0),
    ),
  ];
}
