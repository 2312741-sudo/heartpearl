import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
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
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;

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

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        // Default to back camera
        _selectedCameraIndex = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
        );
        if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;
        await _initCameraController(_cameras[_selectedCameraIndex]);
      }
    } catch (_) {}
  }

  Future<void> _initCameraController(CameraDescription description) async {
    final prevController = _controller;
    final newController = CameraController(
      description,
      ResolutionPreset.high,
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
      _currentZoom = _minZoom;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _toggleCameraFacing() async {
    if (_cameras.length < 2 || _isRecording) return;
    HapticHelper.selection();
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initCameraController(_cameras[_selectedCameraIndex]);
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
          _controller!.description.lensDirection == CameraLensDirection.front;

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
      final isFront =
          _controller!.description.lensDirection == CameraLensDirection.front;

      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordSeconds = 0;
          _isButtonPressed = false;
        });
      }
      HapticHelper.success();

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

    final isFrontCamera =
        _controller!.description.lensDirection == CameraLensDirection.front;
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
                      child: Transform.scale(
                        scaleX: isFrontCamera ? -1.0 : 1.0,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Beauty Filter Color Overlay
          if (_selectedFilter.overlayColor != Colors.transparent)
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

          // 4. Zoom Level Pill
          if (!_isRecording)
            Positioned(
              bottom: 275,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    HapticHelper.selection();
                    final nextZoom = _currentZoom >= 2.0 ? 1.0 : 2.0;
                    _controller!.setZoomLevel(nextZoom);
                    setState(() => _currentZoom = nextZoom);
                  },
                  child: FrostedContainer(
                    borderRadius: AppDimens.radiusFull,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      '${_currentZoom.toStringAsFixed(1)}x',
                      style: AppTypography.bold.copyWith(
                        color: AppColors.white,
                        fontSize: 13,
                      ),
                    ),
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
                        child: Text(
                          filter.name,
                          style: AppTypography.medium.copyWith(
                            color: AppColors.white,
                            fontSize: 13,
                          ),
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
                // Empty spacer for visual balance with flip button
                const SizedBox(width: 56),

                // Shutter Button (Tap: Photo, Press & Hold: Video - Anti-Stuck)
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

                // Flip Camera Facing
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
}
