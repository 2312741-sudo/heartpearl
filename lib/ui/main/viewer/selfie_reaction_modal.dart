import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/media_helper.dart';
import '../../common/frosted_container.dart';
import '../../common/gradient_button.dart';

class SelfieReactionModal extends StatefulWidget {
  const SelfieReactionModal({super.key});

  @override
  State<SelfieReactionModal> createState() => _SelfieReactionModalState();
}

class _SelfieReactionModalState extends State<SelfieReactionModal>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _currentCameraIndex = 0;
  bool _isFlashOn = false;
  bool _isScreenFlashing = false;
  bool _isCapturing = false;
  String? _capturedPath;

  late AnimationController _shutterAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shutterAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _initCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shutterAnim.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null && _cameras.isNotEmpty) {
        _initCameraController(_cameras[_currentCameraIndex]);
      }
    }
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      // Prefer front camera for selfie reaction
      final frontIdx = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _currentCameraIndex = frontIdx != -1 ? frontIdx : 0;
      await _initCameraController(_cameras[_currentCameraIndex]);
    } catch (_) {}
  }

  Future<void> _initCameraController(CameraDescription description) async {
    final prev = _controller;
    final newController = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = newController;
    await prev?.dispose();

    try {
      await newController.initialize();
      try {
        await newController.setFlashMode(FlashMode.off);
      } catch (_) {}
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2 || _controller == null) return;
    HapticHelper.light();
    if (_isFlashOn) {
      setState(() => _isFlashOn = false);
    }
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _initCameraController(_cameras[_currentCameraIndex]);
  }

  Future<void> _toggleFlash() async {
    HapticHelper.light();
    final nextFlash = !_isFlashOn;
    setState(() => _isFlashOn = nextFlash);
    final isFront = _controller?.description.lensDirection == CameraLensDirection.front;
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        if (isFront || !nextFlash) {
          await _controller!.setFlashMode(FlashMode.off);
        } else {
          await _controller!.setFlashMode(FlashMode.torch);
        }
      } catch (_) {}
    }
  }

  Future<void> _takeSelfie() async {
    if (_isCapturing || _controller == null || !_controller!.value.isInitialized) return;
    setState(() => _isCapturing = true);

    final isFront = _controller?.description.lensDirection == CameraLensDirection.front;

    try {
      HapticHelper.medium();
      _shutterAnim.forward().then((_) => _shutterAnim.reverse());

      // Strictly ensure native hardware flash is off when flash is off or for front camera
      if (!_isFlashOn || isFront) {
        try {
          if (_controller!.value.flashMode != FlashMode.off) {
            await _controller!.setFlashMode(FlashMode.off);
          }
        } catch (_) {}
      }

      // Retina screen flash in the dark
      if (_isFlashOn && isFront) {
        setState(() => _isScreenFlashing = true);
        await Future.delayed(const Duration(milliseconds: 180));
      }

      final xFile = await _controller!.takePicture();

      if (_isScreenFlashing) {
        setState(() => _isScreenFlashing = false);
      }

      // Exact HeartPearl main camera mirror algorithm
      String finalPath = xFile.path;
      if (isFront) {
        finalPath = await MediaHelper.mirrorFrontCameraPhoto(xFile.path);
      }

      if (mounted) {
        setState(() {
          _capturedPath = finalPath;
          _isCapturing = false;
        });
      }
    } catch (e) {
      debugPrint('Selfie error: $e');
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isScreenFlashing = false;
        });
      }
    }
  }

  void _retake() {
    HapticHelper.light();
    setState(() => _capturedPath = null);
  }

  void _sendReaction() {
    if (_capturedPath == null) return;
    HapticHelper.success();
    Navigator.of(context).pop(_capturedPath);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.modalDarkBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Top Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceLg,
                    vertical: AppDimens.spaceMd,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: FrostedContainer(
                          borderRadius: AppDimens.radiusFull,
                          padding: const EdgeInsets.all(10),
                          child: const Icon(LucideIcons.x, color: AppColors.white, size: 20),
                        ),
                      ),
                      Text(
                        _capturedPath == null ? 'Phản hồi bằng Selfie' : 'Xem lại ảnh Selfie',
                        style: AppTypography.h3(color: AppColors.white),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                const Spacer(),

                // Camera Viewfinder (Aspect ratio 1:1 or 3:4)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceXl),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: AppColors.primaryLight.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: _capturedPath != null
                            ? Image.file(
                                File(_capturedPath!),
                                fit: BoxFit.cover,
                              )
                            : (_controller != null && _controller!.value.isInitialized)
                                ? Builder(
                                    builder: (context) {
                                      final previewSize = _controller?.value.previewSize;
                                      final double previewW =
                                          previewSize != null ? previewSize.height : 720.0;
                                      final double previewH =
                                          previewSize != null ? previewSize.width : 1280.0;

                                      return FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: previewW,
                                          height: previewH,
                                          child: CameraPreview(_controller!),
                                        ),
                                      );
                                    },
                                  )
                                : const Center(
                                    child: CircularProgressIndicator(color: AppColors.primary),
                                  ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Bottom Controls
                if (_capturedPath == null)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppDimens.space2Xl,
                      right: AppDimens.space2Xl,
                      bottom: AppDimens.space2Xl,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Flash Button
                        GestureDetector(
                          onTap: _toggleFlash,
                          child: FrostedContainer(
                            borderRadius: AppDimens.radiusFull,
                            padding: const EdgeInsets.all(14),
                            backgroundColor: _isFlashOn
                                ? AppColors.warning.withValues(alpha: 0.3)
                                : AppColors.darkSurface.withValues(alpha: 0.6),
                            child: Icon(
                              _isFlashOn ? LucideIcons.zap : LucideIcons.zapOff,
                              color: _isFlashOn ? AppColors.warning : AppColors.white,
                              size: 22,
                            ),
                          ),
                        ),

                        // Shutter Button
                        GestureDetector(
                          onTap: _takeSelfie,
                          child: AnimatedBuilder(
                            animation: _shutterAnim,
                            builder: (context, child) {
                              final scale = 1.0 - (_shutterAnim.value * 0.1);
                              return Transform.scale(
                                scale: scale,
                                child: Container(
                                  width: 78,
                                  height: 78,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.pearl, width: 3.5),
                                  ),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: AppColors.primaryGradient,
                                    ),
                                    child: _isCapturing
                                        ? const Padding(
                                            padding: EdgeInsets.all(18),
                                            child: CircularProgressIndicator(
                                              color: AppColors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Icon(
                                            LucideIcons.camera,
                                            color: AppColors.white,
                                            size: 30,
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Flip Camera Button
                        GestureDetector(
                          onTap: _toggleCamera,
                          child: FrostedContainer(
                            borderRadius: AppDimens.radiusFull,
                            padding: const EdgeInsets.all(14),
                            child: const Icon(
                              LucideIcons.refreshCw,
                              color: AppColors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // Confirm / Retake Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceXl,
                      vertical: AppDimens.spaceXl,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _retake,
                            icon: const Icon(LucideIcons.rotateCcw, size: 18, color: Colors.white70),
                            label: const Text('Chụp lại', style: TextStyle(color: Colors.white70)),
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceMd),
                        Expanded(
                          flex: 2,
                          child: GradientButton(
                            text: 'Gửi Reaction',
                            icon: const Icon(LucideIcons.send, color: AppColors.white, size: 18),
                            onPressed: _sendReaction,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Retina screen flash overlay
          if (_isScreenFlashing)
            Positioned.fill(
              child: Container(
                color: AppColors.screenFlashWarm.withValues(alpha: 0.95),
              ),
            ),
        ],
      ),
    );
  }
}
