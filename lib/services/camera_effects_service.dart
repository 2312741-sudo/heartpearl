import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/camera_filters.dart';

class CameraEffectsSelection {
  final BeautyFilter filter;
  final double filterIntensity;
  final BeautySettings beauty;

  const CameraEffectsSelection({
    required this.filter,
    required this.filterIntensity,
    required this.beauty,
  });

  factory CameraEffectsSelection.defaults() {
    final filter = BeautyFilter.all.first;
    return CameraEffectsSelection(
      filter: filter,
      filterIntensity: filter.defaultIntensity,
      beauty: const BeautySettings(),
    );
  }
}

class CameraEffectsService {
  static const _filterKey = 'camera_filter_id';
  static const _filterIntensityKey = 'camera_filter_intensity';
  static const _beautyKey = 'camera_beauty_settings';

  Future<CameraEffectsSelection> loadSelection() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final filter = BeautyFilter.byId(preferences.getString(_filterKey));
      final storedIntensity = preferences.getDouble(_filterIntensityKey);
      final beautyJson = preferences.getString(_beautyKey);
      Map<String, dynamic>? beautyMap;
      if (beautyJson != null) {
        final decoded = jsonDecode(beautyJson);
        if (decoded is Map) beautyMap = Map<String, dynamic>.from(decoded);
      }
      return CameraEffectsSelection(
        filter: filter,
        filterIntensity: (storedIntensity ?? filter.defaultIntensity).clamp(
          0,
          1,
        ),
        beauty: BeautySettings.fromMap(beautyMap),
      );
    } catch (error) {
      debugPrint('Camera effects preferences load failed: $error');
      return CameraEffectsSelection.defaults();
    }
  }

  Future<void> saveSelection(CameraEffectsSelection selection) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await Future.wait([
        preferences.setString(_filterKey, selection.filter.id),
        preferences.setDouble(
          _filterIntensityKey,
          selection.filterIntensity.clamp(0, 1),
        ),
        preferences.setString(_beautyKey, jsonEncode(selection.beauty.toMap())),
      ]);
    } catch (error) {
      debugPrint('Camera effects preferences save failed: $error');
    }
  }

  /// Renders the same color matrix as the preview and applies an on-device,
  /// soft skin-color mask. The mask is intentionally conservative: pixels
  /// outside plausible skin chroma are never smoothed or brightened.
  Future<File> renderPhoto({
    required File source,
    required BeautyFilter filter,
    required double filterIntensity,
    required BeautySettings beauty,
  }) async {
    if ((!beauty.hasEffect) && (filter.isOriginal || filterIntensity <= 0)) {
      return source;
    }

    final request = <String, dynamic>{
      'path': source.path,
      'matrix': filter.matrixAt(filterIntensity),
      'overlay': <num>[
        filter.overlayColor.r * 255,
        filter.overlayColor.g * 255,
        filter.overlayColor.b * 255,
        filter.overlayColor.a * filterIntensity,
      ],
      'beauty': beauty.toMap(),
    };
    try {
      final outputPath = await Isolate.run(() => _renderPhoto(request));
      if (outputPath != null) {
        final output = File(outputPath);
        if (await output.exists() && await output.length() > 0) return output;
      }
    } catch (error) {
      debugPrint('Camera photo effects render failed: $error');
    }
    return source;
  }

  static List<double> previewBeautyMatrix(BeautySettings settings) {
    if (!settings.hasEffect) return BeautyFilter.identityMatrix;
    final overall = settings.overall;
    final brightness = settings.brightness * overall * 8;
    final saturation = 1 + settings.vitality * overall * .12;
    final inverse = 1 - saturation;
    const lr = .213;
    const lg = .715;
    const lb = .072;
    return [
      lr * inverse + saturation,
      lg * inverse,
      lb * inverse,
      0,
      brightness,
      lr * inverse,
      lg * inverse + saturation,
      lb * inverse,
      0,
      brightness,
      lr * inverse,
      lg * inverse,
      lb * inverse + saturation,
      0,
      brightness,
      0,
      0,
      0,
      1,
      0,
    ];
  }
}

String? _renderPhoto(Map<String, dynamic> request) {
  final path = request['path'] as String;
  final file = File(path);
  if (!file.existsSync()) return null;
  var source = img.decodeImage(file.readAsBytesSync());
  if (source == null) return null;
  source = img.bakeOrientation(source);

  const maxDimension = 1600;
  if (source.width > maxDimension || source.height > maxDimension) {
    source = source.width >= source.height
        ? img.copyResize(
            source,
            width: maxDimension,
            interpolation: img.Interpolation.cubic,
          )
        : img.copyResize(
            source,
            height: maxDimension,
            interpolation: img.Interpolation.cubic,
          );
  }

  final matrix = (request['matrix'] as List).cast<num>();
  final overlay = (request['overlay'] as List).cast<num>();
  final beauty = Map<String, dynamic>.from(request['beauty'] as Map);
  final beautyEnabled = beauty['enabled'] == true;
  final overall = _unit(beauty['overall']);
  final smoothing = _unit(beauty['smoothing']) * overall;
  final tone = _unit(beauty['toneEvenness']) * overall;
  final blemish = _unit(beauty['blemishReduction']) * overall;
  final brighten = _unit(beauty['brightness']) * overall;
  final vitality = _unit(beauty['vitality']) * overall;
  final highlights = _unit(beauty['highlightReduction']) * overall;

  img.Image? softened;
  img.Image? skinMask;
  if (beautyEnabled && overall > 0) {
    final radius = (1 + (smoothing + blemish) * 5).round().clamp(1, 5);
    softened = img.gaussianBlur(img.Image.from(source), radius: radius);
    skinMask = img.Image(
      width: source.width,
      height: source.height,
      numChannels: 4,
    );
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        final probability = _skinProbability(
          pixel.r.toDouble(),
          pixel.g.toDouble(),
          pixel.b.toDouble(),
        );
        final value = (probability * 255).round();
        skinMask.setPixelRgba(x, y, value, value, value, 255);
      }
    }
    skinMask = img.gaussianBlur(skinMask, radius: 2);
  }

  final output = img.Image.from(source);
  final overlayAlpha = overlay[3].toDouble().clamp(0, 1);
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final original = source.getPixel(x, y);
      var red = original.r.toDouble();
      var green = original.g.toDouble();
      var blue = original.b.toDouble();

      if (softened != null && skinMask != null) {
        final mask = skinMask.getPixel(x, y).r.toDouble() / 255;
        if (mask > .03) {
          final soft = softened.getPixel(x, y);
          final textureBlend = ((smoothing * .28) + (blemish * .18)) * mask;
          red += (soft.r.toDouble() - red) * textureBlend;
          green += (soft.g.toDouble() - green) * textureBlend;
          blue += (soft.b.toDouble() - blue) * textureBlend;

          final toneBlend = tone * .16 * mask;
          red += (soft.r.toDouble() - red) * toneBlend;
          green += (soft.g.toDouble() - green) * toneBlend;
          blue += (soft.b.toDouble() - blue) * toneBlend;

          final luminance = .213 * red + .715 * green + .072 * blue;
          final lift = brighten * 9 * mask;
          red += lift;
          green += lift;
          blue += lift;
          final vitalityAmount = vitality * .16 * mask;
          red = luminance + (red - luminance) * (1 + vitalityAmount);
          green = luminance + (green - luminance) * (1 + vitalityAmount);
          blue = luminance + (blue - luminance) * (1 + vitalityAmount);
          if (luminance > 185) {
            final reduction = highlights * mask * (luminance - 185) / 70;
            red -= reduction * 10;
            green -= reduction * 10;
            blue -= reduction * 10;
          }
        }
      }

      final matrixRed =
          red * matrix[0] + green * matrix[1] + blue * matrix[2] + matrix[4];
      final matrixGreen =
          red * matrix[5] + green * matrix[6] + blue * matrix[7] + matrix[9];
      final matrixBlue =
          red * matrix[10] +
          green * matrix[11] +
          blue * matrix[12] +
          matrix[14];
      red = matrixRed;
      green = matrixGreen;
      blue = matrixBlue;

      if (overlayAlpha > 0) {
        red += (overlay[0].toDouble() - red) * overlayAlpha;
        green += (overlay[1].toDouble() - green) * overlayAlpha;
        blue += (overlay[2].toDouble() - blue) * overlayAlpha;
      }
      output.setPixelRgba(
        x,
        y,
        red.clamp(0, 255),
        green.clamp(0, 255),
        blue.clamp(0, 255),
        original.a,
      );
    }
  }

  final outputPath =
      '${file.parent.path}/effects_${DateTime.now().microsecondsSinceEpoch}.jpg';
  File(outputPath).writeAsBytesSync(img.encodeJpg(output, quality: 90));
  return outputPath;
}

double _unit(dynamic value) => ((value as num?)?.toDouble() ?? 0).clamp(0, 1);

double _skinProbability(double red, double green, double blue) {
  final y = .299 * red + .587 * green + .114 * blue;
  final cb = 128 - .168736 * red - .331264 * green + .5 * blue;
  final cr = 128 + .5 * red - .418688 * green - .081312 * blue;
  if (y < 28 || cr < 126 || cr > 186 || cb < 72 || cb > 145) return 0;
  final chromaDistance = math.sqrt(
    math.pow((cr - 154) / 32, 2) + math.pow((cb - 108) / 34, 2),
  );
  final probability = (1 - chromaDistance).clamp(0, 1).toDouble();
  final channelGuard = red > blue * .72 && green > blue * .62 ? 1.0 : .35;
  return probability * channelGuard;
}
