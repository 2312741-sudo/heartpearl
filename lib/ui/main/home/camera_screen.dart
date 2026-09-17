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

  // Video Recording State
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  static const int maxVideoDuration = 15;

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

  // Take Picture
  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isRecording) {
      return;
    }

    try {
      HapticHelper.medium();
      _shutterAnimController.forward().then((_) => _shutterAnimController.reverse());
      final xFile = await _controller!.takePicture();

      final isFront = _controller!.description.lensDirection == CameraLensDirection.front;

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
    } catch (_) {}
  }

  // Start Video Recording
  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized || _isRecording) {
      return;
    }

    try {
      HapticHelper.heavy();
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_recordSeconds >= maxVideoDuration) {
          _stopRecording();
        } else {
          setState(() => _recordSeconds++);
        }
      });
    } catch (_) {}
  }

  // Stop Video Recording
  Future<void> _stopRecording() async {
    if (!_isRecording || _controller == null) return;
    _recordTimer?.cancel();
    _recordTimer = null;

    try {
      final xFile = await _controller!.stopVideoRecording();
      final isFront = _controller!.description.lensDirection == CameraLensDirection.front;

      setState(() => _isRecording = false);
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
    } catch (_) {
      setState(() => _isRecording = false);
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

                // Shutter Button (Tap: Photo, Long Press: Video)
                GestureDetector(
                  onTap: _takePicture,
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressEnd: (_) => _stopRecording(),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer Progress Circle for Recording
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
                          backgroundColor: Colors.white24,
                        ),
                      ),

                      // Inner Shutter Button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: _isRecording ? 60 : 72,
                        height: _isRecording ? 60 : 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                          boxShadow: AppDimens.glowShadow(
                            AppColors.primary,
                            opacity: _isRecording ? 0.7 : 0.4,
                          ),
                        ),
                        child: _isRecording
                            ? Center(
                                child: Text(
                                  '${maxVideoDuration - _recordSeconds}s',
                                  style: AppTypography.bold.copyWith(
                                    color: AppColors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
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
