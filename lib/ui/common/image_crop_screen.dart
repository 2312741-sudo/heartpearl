import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/haptic_helper.dart';

enum CropStyle {
  rectangle,
  circle,
}

enum AspectRatioPreset {
  ratio3x4('3:4', 3 / 4),
  ratio1x1('1:1', 1.0),
  ratio9x16('9:16', 9 / 16),
  original('Gốc', null);

  final String label;
  final double? ratio;
  const AspectRatioPreset(this.label, this.ratio);
}

class ImageCropScreen extends StatefulWidget {
  final File imageFile;
  final CropStyle cropStyle;
  final double? initialAspectRatio;
  final String? title;

  const ImageCropScreen({
    super.key,
    required this.imageFile,
    this.cropStyle = CropStyle.rectangle,
    this.initialAspectRatio,
    this.title,
  });

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final TransformationController _transformController = TransformationController();
  
  double? _imageNaturalWidth;
  double? _imageNaturalHeight;
  int _quarterTurns = 0;
  bool _isProcessing = false;
  late AspectRatioPreset _selectedPreset;

  @override
  void initState() {
    super.initState();
    _initPreset();
    _loadImageDimensions();
  }

  void _initPreset() {
    if (widget.cropStyle == CropStyle.circle) {
      _selectedPreset = AspectRatioPreset.ratio1x1;
    } else if (widget.initialAspectRatio != null) {
      if ((widget.initialAspectRatio! - (3 / 4)).abs() < 0.05) {
        _selectedPreset = AspectRatioPreset.ratio3x4;
      } else if ((widget.initialAspectRatio! - 1.0).abs() < 0.05) {
        _selectedPreset = AspectRatioPreset.ratio1x1;
      } else if ((widget.initialAspectRatio! - (9 / 16)).abs() < 0.05) {
        _selectedPreset = AspectRatioPreset.ratio9x16;
      } else {
        _selectedPreset = AspectRatioPreset.ratio3x4;
      }
    } else {
      _selectedPreset = AspectRatioPreset.ratio3x4;
    }
  }

  void _loadImageDimensions() {
    final image = Image.file(widget.imageFile);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo info, bool _) {
          if (!mounted) return;
          setState(() {
            _imageNaturalWidth = info.image.width.toDouble();
            _imageNaturalHeight = info.image.height.toDouble();
          });
        },
        onError: (dynamic exception, StackTrace? stackTrace) {
          debugPrint('ImageCropScreen: Error loading image dimensions: $exception');
        },
      ),
    );
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _rotateClockwise() {
    HapticHelper.selection();
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _transformController.value = Matrix4.identity();
    });
  }

  void _resetTransform() {
    HapticHelper.light();
    setState(() {
      _quarterTurns = 0;
      _transformController.value = Matrix4.identity();
    });
  }

  void _handleDoubleTap(TapDownDetails details, Rect cropRect, double layoutW, double layoutH, Size viewportSize) {
    HapticHelper.light();
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    if (currentScale > 1.2) {
      setState(() {
        _transformController.value = Matrix4.identity();
      });
    } else {
      final tapPos = details.localPosition;
      final targetScale = 2.0;
      final translationX = (viewportSize.width / 2 - tapPos.dx) * (targetScale - 1);
      final translationY = (viewportSize.height / 2 - tapPos.dy) * (targetScale - 1);

      final matrix = Matrix4.diagonal3Values(targetScale, targetScale, 1.0)
        ..setTranslationRaw(translationX, translationY, 0.0);

      setState(() {
        _transformController.value = matrix;
      });
    }
  }

  double _getEffectiveAspectRatio() {
    if (widget.cropStyle == CropStyle.circle) return 1.0;
    if (_selectedPreset.ratio != null) return _selectedPreset.ratio!;
    if (_imageNaturalWidth != null && _imageNaturalHeight != null && _imageNaturalHeight! > 0) {
      final isRotated = _quarterTurns % 2 == 1;
      final w = isRotated ? _imageNaturalHeight! : _imageNaturalWidth!;
      final h = isRotated ? _imageNaturalWidth! : _imageNaturalHeight!;
      return (w / h).clamp(0.2, 5.0);
    }
    return 3 / 4;
  }

  Rect _calculateCropRect(Size viewportSize, double cropAspect) {
    const margin = 24.0;
    final maxW = viewportSize.width - (margin * 2);
    final maxH = viewportSize.height - (margin * 2);

    double cropW, cropH;
    if (maxW / maxH > cropAspect) {
      cropH = maxH;
      cropW = cropH * cropAspect;
    } else {
      cropW = maxW;
      cropH = cropW / cropAspect;
    }

    return Rect.fromCenter(
      center: Offset(viewportSize.width / 2, viewportSize.height / 2),
      width: cropW,
      height: cropH,
    );
  }

  Future<void> _performCrop(Rect cropRect, double layoutW, double layoutH, Size viewportSize) async {
    if (_isProcessing) return;
    HapticHelper.medium();
    setState(() => _isProcessing = true);

    try {
      final matrix = _transformController.value;
      final scale = matrix.getMaxScaleOnAxis();
      final tx = matrix.storage[12];
      final ty = matrix.storage[13];

      final childOriginX = (viewportSize.width - layoutW) / 2;
      final childOriginY = (viewportSize.height - layoutH) / 2;

      // Map cropRect coordinates to child image coordinate space
      final pxLeft = (cropRect.left - tx) / scale - childOriginX;
      final pxTop = (cropRect.top - ty) / scale - childOriginY;
      final pxRight = (cropRect.right - tx) / scale - childOriginX;
      final pxBottom = (cropRect.bottom - ty) / scale - childOriginY;

      final fracLeft = (pxLeft / layoutW).clamp(0.0, 1.0);
      final fracTop = (pxTop / layoutH).clamp(0.0, 1.0);
      final fracRight = (pxRight / layoutW).clamp(0.0, 1.0);
      final fracBottom = (pxBottom / layoutH).clamp(0.0, 1.0);

      final fracW = (fracRight - fracLeft).clamp(0.01, 1.0);
      final fracH = (fracBottom - fracTop).clamp(0.01, 1.0);

      final params = <String, dynamic>{
        'sourcePath': widget.imageFile.path,
        'quarterTurns': _quarterTurns,
        'fracLeft': fracLeft,
        'fracTop': fracTop,
        'fracWidth': fracW,
        'fracHeight': fracH,
      };

      String? croppedPath;
      try {
        croppedPath = await compute(_cropImageWorker, params);
      } catch (isolateErr) {
        debugPrint('compute isolate failed, falling back to direct crop: $isolateErr');
        croppedPath = _cropImageWorker(params);
      }

      if (!mounted) return;
      if (croppedPath != null) {
        final resultFile = File(croppedPath);
        HapticHelper.success();
        Navigator.of(context).pop(resultFile);
      } else {
        throw StateError('Cắt ảnh thất bại');
      }
    } catch (e) {
      debugPrint('Error cropping image: $e');
      if (mounted) {
        HapticHelper.heavy();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cắt ảnh: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ??
        (widget.cropStyle == CropStyle.circle
            ? 'Cắt ảnh đại diện'
            : 'Cắt & Thu phóng ảnh');

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(title),

            // Main Interactive Crop Area
            Expanded(
              child: _imageNaturalWidth == null || _imageNaturalHeight == null
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final viewportSize = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        final cropAspect = _getEffectiveAspectRatio();
                        final cropRect = _calculateCropRect(viewportSize, cropAspect);

                        // Image dimensions after rotation
                        final isRotated = _quarterTurns % 2 == 1;
                        final effectiveW = isRotated
                            ? _imageNaturalHeight!
                            : _imageNaturalWidth!;
                        final effectiveH = isRotated
                            ? _imageNaturalWidth!
                            : _imageNaturalHeight!;

                        // Scale base layout so image at scale 1.0 covers the crop frame
                        final scaleW = cropRect.width / effectiveW;
                        final scaleH = cropRect.height / effectiveH;
                        final baseCoverScale = math.max(scaleW, scaleH);

                        final layoutW = effectiveW * baseCoverScale;
                        final layoutH = effectiveH * baseCoverScale;

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // Interactive viewer with pan and pinch-to-zoom
                            GestureDetector(
                              onDoubleTapDown: (details) => _handleDoubleTap(
                                details,
                                cropRect,
                                layoutW,
                                layoutH,
                                viewportSize,
                              ),
                              child: InteractiveViewer(
                                transformationController: _transformController,
                                minScale: 0.8,
                                maxScale: 5.0,
                                boundaryMargin: const EdgeInsets.all(double.infinity),
                                clipBehavior: Clip.none,
                                child: Center(
                                  child: SizedBox(
                                    width: layoutW,
                                    height: layoutH,
                                    child: RotatedBox(
                                      quarterTurns: _quarterTurns,
                                      child: Image.file(
                                        widget.imageFile,
                                        fit: BoxFit.fill,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Semi-transparent cutout mask overlay
                            IgnorePointer(
                              child: CustomPaint(
                                size: viewportSize,
                                painter: _CropOverlayPainter(
                                  cropRect: cropRect,
                                  cropStyle: widget.cropStyle,
                                ),
                              ),
                            ),

                            // Hidden tap trigger for crop
                            Positioned(
                              top: 0,
                              left: 0,
                              width: 0,
                              height: 0,
                              child: _CropTrigger(
                                onCrop: () => _performCrop(
                                  cropRect,
                                  layoutW,
                                  layoutH,
                                  viewportSize,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),

            // Bottom Controls Bar
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Cancel Button
          IconButton(
            onPressed: () {
              HapticHelper.light();
              Navigator.of(context).pop();
            },
            icon: const Icon(LucideIcons.x, color: Colors.white, size: 24),
            tooltip: 'Hủy',
          ),

          // Title
          Text(
            title,
            style: AppTypography.h3(color: Colors.white),
          ),

          // Done / Crop Action Button
          _isProcessing
              ? const SizedBox(
                  width: 38,
                  height: 38,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                    ),
                  ),
                  onPressed: () {
                    // Trigger perform crop via event
                    _cropTriggerKey.currentState?.triggerCrop();
                  },
                  icon: const Icon(LucideIcons.check, size: 18),
                  label: const Text(
                    'Xong',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFF140D1B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Aspect Ratio Presets (only for rectangle style)
          if (widget.cropStyle == CropStyle.rectangle) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: AspectRatioPreset.values.map((preset) {
                  final isSelected = _selectedPreset == preset;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(preset.label),
                      selected: isSelected,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          HapticHelper.selection();
                          setState(() {
                            _selectedPreset = preset;
                            _transformController.value = Matrix4.identity();
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Toolbar Buttons: Rotate & Reset
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: _rotateClockwise,
                icon: const Icon(LucideIcons.rotateCw, color: Colors.white, size: 18),
                label: const Text(
                  'Xoay 90°',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              Container(width: 1, height: 20, color: Colors.white24),
              TextButton.icon(
                onPressed: _resetTransform,
                icon: const Icon(LucideIcons.rotateCcw, color: Colors.white70, size: 18),
                label: const Text(
                  'Đặt lại',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Global key to allow TopBar button to trigger crop with the latest layout constraints
final GlobalKey<_CropTriggerState> _cropTriggerKey = GlobalKey<_CropTriggerState>();

class _CropTrigger extends StatefulWidget {
  final VoidCallback onCrop;

  _CropTrigger({required this.onCrop}) : super(key: _cropTriggerKey);

  @override
  State<_CropTrigger> createState() => _CropTriggerState();
}

class _CropTriggerState extends State<_CropTrigger> {
  void triggerCrop() {
    widget.onCrop();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Custom painter that draws the darkened vignette around the crop frame
/// and draws crisp studio corner guides & rule-of-thirds grid lines.
class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final CropStyle cropStyle;

  _CropOverlayPainter({
    required this.cropRect,
    required this.cropStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;

    // 1. Darkened outer mask using Path with even-odd fill
    final maskPath = Path()..addRect(fullRect);
    if (cropStyle == CropStyle.circle) {
      maskPath.addOval(cropRect);
    } else {
      maskPath.addRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(12)));
    }
    maskPath.fillType = PathFillType.evenOdd;

    final dimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;
    canvas.drawPath(maskPath, dimPaint);

    // 2. Rule of thirds grid lines inside the crop window
    canvas.save();
    if (cropStyle == CropStyle.circle) {
      canvas.clipPath(Path()..addOval(cropRect));
    } else {
      canvas.clipPath(
        Path()..addRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(12))),
      );
    }

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final w3 = cropRect.width / 3;
    final h3 = cropRect.height / 3;

    // Vertical grid lines
    canvas.drawLine(
      Offset(cropRect.left + w3, cropRect.top),
      Offset(cropRect.left + w3, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + w3 * 2, cropRect.top),
      Offset(cropRect.left + w3 * 2, cropRect.bottom),
      gridPaint,
    );

    // Horizontal grid lines
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + h3),
      Offset(cropRect.right, cropRect.top + h3),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + h3 * 2),
      Offset(cropRect.right, cropRect.top + h3 * 2),
      gridPaint,
    );

    canvas.restore();

    // 3. Crisp frame border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (cropStyle == CropStyle.circle) {
      canvas.drawOval(cropRect, borderPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(cropRect, const Radius.circular(12)),
        borderPaint,
      );

      // 4. Professional Studio Corner Brackets
      final cornerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      const cornerLen = 18.0;

      // Top-Left Corner
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + cornerLen),
        Offset(cropRect.left, cropRect.top),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top),
        Offset(cropRect.left + cornerLen, cropRect.top),
        cornerPaint,
      );

      // Top-Right Corner
      canvas.drawLine(
        Offset(cropRect.right - cornerLen, cropRect.top),
        Offset(cropRect.right, cropRect.top),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(cropRect.right, cropRect.top),
        Offset(cropRect.right, cropRect.top + cornerLen),
        cornerPaint,
      );

      // Bottom-Left Corner
      canvas.drawLine(
        Offset(cropRect.left, cropRect.bottom - cornerLen),
        Offset(cropRect.left, cropRect.bottom),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.bottom),
        Offset(cropRect.left + cornerLen, cropRect.bottom),
        cornerPaint,
      );

      // Bottom-Right Corner
      canvas.drawLine(
        Offset(cropRect.right - cornerLen, cropRect.bottom),
        Offset(cropRect.right, cropRect.bottom),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(cropRect.right, cropRect.bottom - cornerLen),
        Offset(cropRect.right, cropRect.bottom),
        cornerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect || oldDelegate.cropStyle != cropStyle;
  }
}

/// Top-level worker function for image cropping in a background isolate.
/// Placed outside classes to guarantee no closure state, widget references,
/// or UI bindings are captured across isolate SendPort boundaries.
String? _cropImageWorker(Map<String, dynamic> params) {
  try {
    final sourcePath = params['sourcePath'] as String;
    final quarterTurns = params['quarterTurns'] as int;
    final fracLeft = params['fracLeft'] as double;
    final fracTop = params['fracTop'] as double;
    final fracWidth = params['fracWidth'] as double;
    final fracHeight = params['fracHeight'] as double;

    final file = File(sourcePath);
    if (!file.existsSync()) return null;

    final bytes = file.readAsBytesSync();
    var image = img.decodeImage(bytes);
    if (image == null) return null;

    // 1. Bake EXIF orientation
    image = img.bakeOrientation(image);

    // 2. Rotate if quarter turns applied
    if (quarterTurns != 0) {
      image = img.copyRotate(image, angle: quarterTurns * 90);
    }

    // 3. Compute pixel coordinates within the rotated image
    final imgW = image.width;
    final imgH = image.height;

    final pixelX = (fracLeft * imgW).round().clamp(0, imgW - 1);
    final pixelY = (fracTop * imgH).round().clamp(0, imgH - 1);
    final pixelW = (fracWidth * imgW).round().clamp(1, imgW - pixelX);
    final pixelH = (fracHeight * imgH).round().clamp(1, imgH - pixelY);

    // 4. Perform crop
    final cropped = img.copyCrop(
      image,
      x: pixelX,
      y: pixelY,
      width: pixelW,
      height: pixelH,
    );

    // 5. Encode as high-quality JPEG (92%)
    final encodedBytes = img.encodeJpg(cropped, quality: 92);

    // 6. Write to temporary file
    final tempDir = Directory.systemTemp;
    final outputPath = '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outputFile = File(outputPath);
    outputFile.writeAsBytesSync(encodedBytes);

    return outputPath;
  } catch (e) {
    debugPrint('Crop worker error: $e');
    return null;
  }
}
