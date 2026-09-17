import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/camera_filters.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../providers/chat_provider.dart';
import '../../common/app_badge.dart';
import '../../common/frosted_container.dart';
import '../chat/chat_list_screen.dart';
import 'preview_screen.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  List<CameraDescription> _cameras = [];
  CameraController? _controller;

  // Zoom & Flash
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 4.0;
  double _baseScale = 1.0;
  bool _isFlashOn = false;

  // Beauty Filter
  BeautyFilter _selectedFilter = BeautyFilter.all.first;

  // Video & Photo State
  bool _isRecording = false;
  bool _isStartingRecording = false;
  bool _stopRequestedWhileStarting = false;
  bool _isProcessing = false;
  bool _isButtonPressed = false;
  DateTime? _pressStartTime;
  Timer? _longPressTimer;
  Timer? _recordTimer;
  int _recordSeconds = 0;
  static const int maxVideoDuration = 15;
  static const Duration _longPressThreshold = Duration(milliseconds: 320);

  late AnimationController _shutterAnimController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shutterAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _initCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _longPressTimer?.cancel();
    _recordTimer?.cancel();
    _controller?.dispose();
    _shutterAnimController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCameraController(cameraController.description);
    }
  }

  // Camera Getters
  CameraDescription get _frontCamera {
    return _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );
  }

  CameraDescription get _mainBackCamera {
    return _cameras.firstWhere(
      (c) =>
          c.lensDirection == CameraLensDirection.back &&
          (c.lensType == CameraLensType.wide ||
              c.lensType == CameraLensType.unknown),
      orElse: () => _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      ),
    );
  }

  CameraDescription? get _ultraWideCamera {
    for (final c in _cameras) {
      if (c.lensDirection == CameraLensDirection.back) {
        if (c.lensType == CameraLensType.ultraWide ||
            c.name.toLowerCase().contains('ultra') ||
            c.name.toLowerCase().contains('0.5')) {
          return c;
        }
      }
    }
    final backCameras =
        _cameras.where((c) => c.lensDirection == CameraLensDirection.back).toList();
    if (backCameras.length >= 2) {
      return backCameras.firstWhere(
        (c) => c.lensType == CameraLensType.ultraWide,
        orElse: () => backCameras.last,
      );
    }
    return null;
  }

  bool get _hasUltraWide {
    if (_controller == null) return false;
    final isBack =
        _controller!.description.lensDirection == CameraLensDirection.back;
    if (isBack) {
      return _minZoom <= 0.7 || _ultraWideCamera != null;
    } else {
      return _minZoom < 0.95;
    }
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        final initialCamera = _mainBackCamera;
        await _initCameraController(initialCamera);
      }
    } catch (_) {}
  }

  Future<void> _initCameraController(CameraDescription description) async {
    final prevController = _controller;
    final newController = CameraController(
      description,
      ResolutionPreset.veryHigh,
      enableAudio: true,
    );

    await prevController?.dispose();

    if (mounted) {
      setState(() {
        _controller = newController;
      });
    }

    try {
      await newController.initialize();
      _minZoom = await newController.getMinZoomLevel();
      final deviceMaxZoom = await newController.getMaxZoomLevel();
      _maxZoom = deviceMaxZoom.clamp(1.0, 4.0);

      final isFront = description.lensDirection == CameraLensDirection.front;
      // On front camera: default to wide selfie (_minZoom, e.g. 0.7x) to avoid zoomed-in face
      final initialZoom = isFront ? _minZoom : (_minZoom < 1.0 ? 1.0 : _minZoom);
      try {
        await newController.setZoomLevel(initialZoom);
      } catch (_) {}
      _currentZoom = initialZoom;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  // Toggle Camera Facing strictly between Front and Back
  void _toggleCameraFacing() async {
    if (_cameras.length < 2 || _isRecording || _isStartingRecording) return;
    HapticHelper.selection();

    final isCurrentlyFront =
        _controller?.description.lensDirection == CameraLensDirection.front;
    final targetCamera = isCurrentlyFront ? _mainBackCamera : _frontCamera;

    await _initCameraController(targetCamera);
  }

  // Set Zoom Level with support for 0.5x / 0.7x Ultra-Wide and Selfie Wide lens
  Future<void> _setZoom(double targetZoom) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final isBack =
        _controller!.description.lensDirection == CameraLensDirection.back;

    if (!isBack) {
      // Front camera wide/standard toggle
      final target = targetZoom <= 0.85 ? _minZoom : 1.0;
      try {
        await _controller!.setZoomLevel(target);
        setState(() => _currentZoom = target);
      } catch (_) {}
      return;
    }

    if (targetZoom <= 0.7 && isBack) {
      if (_minZoom <= 0.7) {
        await _controller!.setZoomLevel(_minZoom);
        setState(() => _currentZoom = 0.5);
      } else if (_ultraWideCamera != null) {
        if (_controller!.description != _ultraWideCamera) {
          await _initCameraController(_ultraWideCamera!);
        }
        setState(() => _currentZoom = 0.5);
      }
      return;
    }

    // If currently on ultra-wide camera and selecting 1x or 2x:
    if (_ultraWideCamera != null &&
        _controller!.description == _ultraWideCamera) {
      await _initCameraController(_mainBackCamera);
    }

    final clampedZoom = targetZoom.clamp(_minZoom, _maxZoom);
    try {
      await _controller!.setZoomLevel(clampedZoom);
      setState(() => _currentZoom = clampedZoom);
    } catch (_) {}
  }

  // Pick Media (photo/video) from Gallery
  Future<void> _pickMediaFromGallery() async {
    if (_isProcessing || _isRecording || _isStartingRecording) return;
    HapticHelper.selection();
    _isProcessing = true;

    try {
      final xFile = await _imagePicker.pickMedia(imageQuality: 92);
      if (xFile != null && mounted) {
        final pathLower = xFile.path.toLowerCase();
        final isVideo = pathLower.endsWith('.mp4') ||
            pathLower.endsWith('.mov') ||
            pathLower.endsWith('.avi') ||
            pathLower.endsWith('.m4v');

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PreviewScreen(
              filePath: xFile.path,
              isVideo: isVideo,
              isMirrored: false,
              filter: _selectedFilter,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Pick gallery error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    HapticHelper.selection();
    final nextFlash = !_isFlashOn;
    try {
      await _controller!.setFlashMode(
        nextFlash ? FlashMode.torch : FlashMode.off,
      );
      setState(() => _isFlashOn = nextFlash);
    } catch (_) {}
  }

  // Unified Pointer Gestures (Anti-stuck, zero lag)
  void _handlePointerDown() {
    if (_isProcessing || _isRecording || _isStartingRecording) return;
    if (_controller == null || !_controller!.value.isInitialized) return;

    _pressStartTime = DateTime.now();
    _isButtonPressed = true;
    _stopRequestedWhileStarting = false;
    HapticHelper.selection();
    setState(() {});

    _longPressTimer?.cancel();
    _longPressTimer = Timer(_longPressThreshold, () {
      if (_isButtonPressed && mounted) {
        _handleStartRecording();
      }
    });
  }

  void _handlePointerUp() {
    if (!_isButtonPressed && !_isRecording && !_isStartingRecording) return;

    _isButtonPressed = false;
    setState(() {});

    if (_longPressTimer?.isActive ?? false) {
      // Finger lifted before threshold -> TAP (Take Photo)
      _longPressTimer?.cancel();
      _longPressTimer = null;
      _takePicture();
    } else if (_isStartingRecording) {
      // User lifted while native video hardware was still spinning up
      _stopRequestedWhileStarting = true;
    } else if (_isRecording) {
      // User was recording video and released -> Stop recording
      _handleStopRecording();
    }
  }

  void _handlePointerCancel() {
    _handlePointerUp();
  }

  // Take Picture
  Future<void> _takePicture() async {
    if (_isProcessing ||
        _isRecording ||
        _isStartingRecording ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }
    _isProcessing = true;

    try {
      HapticHelper.medium();
      _shutterAnimController
          .forward()
          .then((_) => _shutterAnimController.reverse());
      final xFile = await _controller!.takePicture();
      final isFront =
          _controller?.description.lensDirection == CameraLensDirection.front;

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PreviewScreen(
              filePath: xFile.path,
              isVideo: false,
              isMirrored: isFront,
              filter: _selectedFilter,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Take picture error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // Start Video Recording with Hardware Mutex
  Future<void> _handleStartRecording() async {
    if (_isRecording || _isStartingRecording || _isProcessing) return;
    if (_controller == null || !_controller!.value.isInitialized) return;

    _isStartingRecording = true;
    _stopRequestedWhileStarting = false;

    try {
      HapticHelper.heavy();
      await _controller!.startVideoRecording();

      if (!mounted) return;

      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });

      // If user released finger during the await of startVideoRecording:
      if (_stopRequestedWhileStarting || !_isButtonPressed) {
        await _handleStopRecording();
        return;
      }

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_recordSeconds >= maxVideoDuration) {
          _handleStopRecording();
        } else {
          setState(() => _recordSeconds++);
        }
      });
    } catch (e) {
      debugPrint('Start video error: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
    } finally {
      _isStartingRecording = false;
    }
  }

  // Stop Video Recording safely
  Future<void> _handleStopRecording() async {
    if (!_isRecording && !_isStartingRecording) return;

    if (_isStartingRecording) {
      _stopRequestedWhileStarting = true;
      return;
    }

    if (_isProcessing) return;
    _isProcessing = true;

    _recordTimer?.cancel();
    _recordTimer = null;

    try {
      // Ensure at least 600ms of recording to avoid corrupt 0-byte video
      final elapsed = _pressStartTime != null
          ? DateTime.now().difference(_pressStartTime!).inMilliseconds
          : 1000;
      if (elapsed < 600) {
        await Future.delayed(Duration(milliseconds: 600 - elapsed));
      }

      final xFile = await _controller!.stopVideoRecording();

      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordSeconds = 0;
          _isButtonPressed = false;
        });
      }
      HapticHelper.success();

      final isFront =
          _controller?.description.lensDirection == CameraLensDirection.front;

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PreviewScreen(
              filePath: xFile.path,
              isVideo: true,
              isMirrored: isFront,
              filter: _selectedFilter,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Stop video error: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordSeconds = 0;
          _isButtonPressed = false;
        });
      }
    } finally {
      _isProcessing = false;
      _isStartingRecording = false;
      _stopRequestedWhileStarting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadChats = ref.watch(totalUnreadChatsProvider);
    final size = MediaQuery.of(context).size;

    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(
        color: AppColors.black,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final previewSize = _controller!.value.previewSize;
    final double previewW = previewSize != null ? previewSize.height : size.width;
    final double previewH = previewSize != null ? previewSize.width : size.height;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full-screen Camera Viewfinder with Pinch-to-zoom
          Positioned.fill(
            child: GestureDetector(
              onScaleStart: (details) {
                _baseScale = _currentZoom;
              },
              onScaleUpdate: (details) {
                final newZoom = (_baseScale * details.scale)
                    .clamp(_minZoom, _maxZoom);
                _controller!.setZoomLevel(newZoom);
                setState(() => _currentZoom = newZoom);
              },
              child: ClipRect(
                child: OverflowBox(
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: previewW,
                      height: previewH,
                      child: _selectedFilter.colorFilter != null
                          ? ColorFiltered(
                              colorFilter: _selectedFilter.colorFilter!,
                              child: CameraPreview(_controller!),
                            )
                          : CameraPreview(_controller!),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. TikTok Skin-Smoothing & Blemish Softening Diffusion Layer
          if (_selectedFilter.blurSigma > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: _selectedFilter.blurOpacity,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: _selectedFilter.blurSigma,
                      sigmaY: _selectedFilter.blurSigma,
                    ),
                    child: Container(
                      color: _selectedFilter.overlayColor != Colors.transparent
                          ? _selectedFilter.overlayColor
                          : Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),

          // 3. Beauty Filter Color Overlay (for filters with pure color wash)
          if (_selectedFilter.blurSigma == 0 &&
              _selectedFilter.overlayColor != Colors.transparent)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: _selectedFilter.overlayColor),
              ),
            ),

          // 3. Top App Bar Controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceLg,
                  vertical: AppDimens.spaceMd,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Logo + Title
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            width: 28,
                            height: 28,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Heart',
                          style: AppTypography.h2(color: AppColors.primaryLight),
                        ),
                        Text(
                          'Pearl',
                          style: AppTypography.h2(color: AppColors.pearl),
                        ),
                      ],
                    ),

                    // Actions: Messages & Flash
                    Row(
                      children: [
                        // Chat icon with unread badge
                        GestureDetector(
                          onTap: () {
                            HapticHelper.selection();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const ChatListScreen(),
                              ),
                            );
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              FrostedContainer(
                                borderRadius: AppDimens.radiusFull,
                                padding: const EdgeInsets.all(10),
                                child: const Icon(
                                  LucideIcons.messageCircle,
                                  color: AppColors.white,
                                  size: 22,
                                ),
                              ),
                              if (unreadChats > 0)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: AppBadge(count: unreadChats),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(width: AppDimens.spaceMd),

                        // Flash Toggle
                        GestureDetector(
                          onTap: _toggleFlash,
                          child: FrostedContainer(
                            borderRadius: AppDimens.radiusFull,
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              _isFlashOn ? LucideIcons.zap : LucideIcons.zapOff,
                              color: _isFlashOn ? AppColors.warning : AppColors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Zoom / Lens Selector (.5 | 1x | 2x)
          if (!_isRecording)
            Positioned(
              bottom: 275,
              left: 0,
              right: 0,
              child: Center(
                child: FrostedContainer(
                  borderRadius: AppDimens.radiusFull,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  backgroundColor: const Color(0x66000000),
                  child: Builder(
                    builder: (context) {
                      final isFront = _controller?.description.lensDirection ==
                          CameraLensDirection.front;
                      if (isFront) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_minZoom < 0.95)
                              _buildZoomOption(
                                label: _minZoom <= 0.6 ? '.5' : '.7',
                                isSelected: _currentZoom <= 0.85,
                                onTap: () => _setZoom(_minZoom),
                              ),
                            _buildZoomOption(
                              label: '1x',
                              isSelected: _currentZoom > 0.85,
                              onTap: () => _setZoom(1.0),
                            ),
                          ],
                        );
                      }
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_hasUltraWide)
                            _buildZoomOption(
                              label: '.5',
                              isSelected: _currentZoom <= 0.7,
                              onTap: () => _setZoom(0.5),
                            ),
                          _buildZoomOption(
                            label: '1x',
                            isSelected: _currentZoom > 0.7 && _currentZoom < 1.8,
                            onTap: () => _setZoom(1.0),
                          ),
                          _buildZoomOption(
                            label: '2x',
                            isSelected: _currentZoom >= 1.8,
                            onTap: () => _setZoom(2.0),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

          // 5. Beauty Filter Selector
          if (!_isRecording)
            Positioned(
              bottom: 215,
              left: 0,
              right: 0,
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
                itemCount: BeautyFilter.all.length,
                separatorBuilder: (context, index) => const SizedBox(width: AppDimens.spaceMd),
                itemBuilder: (context, index) {
                  final filter = BeautyFilter.all[index];
                  final isSelected = filter.type == _selectedFilter.type;

                  return GestureDetector(
                    onTap: () {
                      HapticHelper.selection();
                      setState(() => _selectedFilter = filter);
                    },
                    child: FrostedContainer(
                      borderRadius: AppDimens.radiusFull,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      backgroundColor: isSelected
                          ? AppColors.primary.withValues(alpha: 0.85)
                          : const Color(0x4D1E0D26),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryLight : Colors.white24,
                        width: isSelected ? 1.5 : 1,
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              filter.icon,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              filter.name,
                              style: AppTypography.medium.copyWith(
                                color: AppColors.white,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // 6. Bottom Shutter & Controls (positioned above bottom navigation bar)
          Positioned(
            bottom: 115,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Pick Media from Gallery
                GestureDetector(
                  onTap: _pickMediaFromGallery,
                  child: FrostedContainer(
                    borderRadius: AppDimens.radiusFull,
                    padding: const EdgeInsets.all(14),
                    child: const Icon(
                      LucideIcons.image,
                      color: AppColors.white,
                      size: 24,
                    ),
                  ),
                ),

                // 2. Shutter Button (Tap: Photo, Press & Hold: Video - Anti-Stuck)
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) => _handlePointerDown(),
                  onPointerUp: (_) => _handlePointerUp(),
                  onPointerCancel: (_) => _handlePointerCancel(),
                  child: AnimatedScale(
                    scale: (_isButtonPressed || _isRecording) ? 0.92 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOutCubic,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Progress Ring for Recording
                        SizedBox(
                          width: 86,
                          height: 86,
                          child: CircularProgressIndicator(
                            value: _isRecording
                                ? (_recordSeconds / maxVideoDuration)
                                : 0.0,
                            strokeWidth: 4,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primaryLight,
                            ),
                            backgroundColor:
                                _isRecording ? Colors.white24 : Colors.transparent,
                          ),
                        ),

                        // Outer ring border
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (_isRecording || _isButtonPressed)
                                  ? AppColors.primaryLight
                                  : Colors.white.withValues(alpha: 0.8),
                              width: 3.5,
                            ),
                          ),
                        ),

                        // Inner Shutter Button
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: _isRecording ? 48 : 64,
                          height: _isRecording ? 48 : 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                            boxShadow: AppDimens.glowShadow(
                              AppColors.primary,
                              opacity: (_isRecording || _isButtonPressed)
                                  ? 0.8
                                  : 0.4,
                            ),
                          ),
                          child: _isRecording
                              ? Center(
                                  child: Text(
                                    '${maxVideoDuration - _recordSeconds}s',
                                    style: AppTypography.bold.copyWith(
                                      color: AppColors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Flip Camera Facing (Front <-> Back only)
                GestureDetector(
                  onTap: _toggleCameraFacing,
                  child: FrostedContainer(
                    borderRadius: AppDimens.radiusFull,
                    padding: const EdgeInsets.all(14),
                    child: const Icon(
                      LucideIcons.switchCamera,
                      color: AppColors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticHelper.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.85)
              : Colors.transparent,
        ),
        child: Text(
          label,
          style: AppTypography.bold.copyWith(
            color: isSelected ? AppColors.white : Colors.white70,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
