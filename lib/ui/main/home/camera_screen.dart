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
import '../../../core/utils/media_helper.dart';
import '../../common/frosted_container.dart';
import '../chat/chat_list_screen.dart';
import '../map/map_screen.dart';
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
  bool _isScreenFlashing = false;

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
  late AnimationController _flipAnimController;
  bool _isFlippingCamera = false;
  bool _isSwitchingCamera = false;
  bool _isTransitioningLens = false;
  Future<void>? _pendingDispose;
  CameraDescription? _currentCameraDescription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shutterAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _flipAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
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
    _flipAnimController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      // Free native camera session only when truly paused in background
      final c = _controller;
      _controller = null;
      if (c != null) {
        _pendingDispose = c.dispose();
      }
    } else if (state == AppLifecycleState.resumed) {
      // When resuming from background, widget tap, or unlock: wait for any pending dispose to finish
      if (_pendingDispose != null) {
        try {
          await _pendingDispose;
        } catch (_) {}
        _pendingDispose = null;
      }
      if (_controller == null || !_controller!.value.isInitialized) {
        final targetCamera = _currentCameraDescription ?? _mainBackCamera;
        await _switchCamera(targetCamera);
      }
    }
  }

  // Camera Getters
  List<CameraDescription> get _backCameras =>
      _cameras.where((c) => c.lensDirection == CameraLensDirection.back).toList();

  List<CameraDescription> get _frontCameras =>
      _cameras.where((c) => c.lensDirection == CameraLensDirection.front).toList();

  CameraDescription get _frontCamera {
    if (_frontCameras.isNotEmpty) return _frontCameras.first;
    return _cameras.first;
  }

  CameraDescription get _mainBackCamera {
    final back = _backCameras;
    if (back.isEmpty) return _cameras.first;

    // 1. Explicit lensType == wide
    final explicitWide = back.where((c) => c.lensType == CameraLensType.wide).firstOrNull;
    if (explicitWide != null) return explicitWide;

    // 2. Hardware discovery order on iPhone Pro: [0: Telephoto, 1: UltraWide, 2: Wide]
    if (back.length >= 3) {
      return back[2];
    }

    // 3. Dual camera setup: [0: UltraWide, 1: Wide]
    if (back.length == 2) {
      return back.last;
    }

    return back.first;
  }

  CameraDescription? get _ultraWideCamera {
    final back = _backCameras;
    if (back.length < 2) return null;

    // 1. Explicit lensType == ultraWide
    final explicitUltra = back.where((c) => c.lensType == CameraLensType.ultraWide).firstOrNull;
    if (explicitUltra != null) return explicitUltra;

    // 2. Name check
    final nameUltra = back.where((c) {
      final name = c.name.toLowerCase();
      return name.contains('ultra') || name.contains('0.5');
    }).firstOrNull;
    if (nameUltra != null && nameUltra != _mainBackCamera) return nameUltra;

    // 3. Hardware discovery order on iPhone Pro: [0: Telephoto, 1: UltraWide, 2: Wide]
    if (back.length >= 3) {
      return back[1]; // Ultra-Wide is index 1
    }

    // 4. Dual camera setup: [0: UltraWide, 1: Wide]
    if (back.length == 2) {
      return back.first; // Ultra-Wide is index 0
    }

    return null;
  }

  CameraDescription? get _telephotoCamera {
    final back = _backCameras;
    if (back.length < 3) return null;

    // 1. Explicit lensType == telephoto
    final explicitTele = back.where((c) => c.lensType == CameraLensType.telephoto).firstOrNull;
    if (explicitTele != null) return explicitTele;

    // 2. On 3-camera setup: index 0 is telephoto
    return back[0];
  }

  bool get _hasUltraWide {
    if (_controller == null) return false;
    final isBack =
        _controller!.description.lensDirection == CameraLensDirection.back;
    if (isBack) {
      return _ultraWideCamera != null || _minZoom <= 0.7;
    } else {
      return _minZoom < 0.95;
    }
  }

  bool get _hasTelephoto {
    if (_controller == null) return false;
    final isBack =
        _controller!.description.lensDirection == CameraLensDirection.back;
    return isBack && (_telephotoCamera != null || _maxZoom >= 3.0);
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        final initialCamera = _mainBackCamera;
        await _switchCamera(initialCamera);
      }
    } catch (e) {
      debugPrint('Error init availableCameras: $e');
    }
  }

  Future<void> _switchCamera(CameraDescription targetCamera) async {
    if (_isSwitchingCamera) return;
    _isSwitchingCamera = true;
    _currentCameraDescription = targetCamera;

    if (mounted) {
      setState(() => _isTransitioningLens = true);
    }

    // 1. Cleanly dispose previous controller FIRST to prevent iOS AVCaptureSession collisions
    final oldController = _controller;
    if (oldController != null) {
      try {
        await oldController.dispose();
      } catch (e) {
        debugPrint('Error disposing old controller: $e');
      }
    }

    // 2. Initialize new controller
    final newController = CameraController(
      targetCamera,
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await newController.initialize();
      _minZoom = await newController.getMinZoomLevel();
      final deviceMaxZoom = await newController.getMaxZoomLevel();
      _maxZoom = deviceMaxZoom.clamp(1.0, 5.0);

      final isFront = targetCamera.lensDirection == CameraLensDirection.front;
      // On front camera: default to wide selfie (_minZoom, e.g. 0.7x) to avoid zoomed-in face
      final initialZoom = isFront ? _minZoom : (_minZoom < 1.0 ? 1.0 : _minZoom);
      try {
        await newController.setZoomLevel(initialZoom);
      } catch (_) {}

      if (targetCamera == _ultraWideCamera) {
        _currentZoom = 0.5;
      } else {
        _currentZoom = initialZoom;
      }

      // Explicitly configure flashMode right after initialization.
      // Native iOS and Android default to FlashMode.auto which causes
      // the camera to flash automatically when taking photos in low light!
      try {
        if (!_isFlashOn || isFront) {
          await newController.setFlashMode(FlashMode.off);
        } else {
          await newController.setFlashMode(FlashMode.torch);
        }
      } catch (_) {
        try {
          await newController.setFlashMode(FlashMode.off);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _controller = newController;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
      try {
        await newController.dispose();
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() => _isTransitioningLens = false);
      }
      _isSwitchingCamera = false;
    }
  }

  // Toggle Camera Facing strictly between Front and Back with smooth 3D flip animation
  void _toggleCameraFacing() async {
    if (_cameras.length < 2 || _isRecording || _isStartingRecording || _isSwitchingCamera || _isFlippingCamera) return;
    HapticHelper.selection();

    final isCurrentlyFront =
        _controller?.description.lensDirection == CameraLensDirection.front;
    if (!isCurrentlyFront && _isFlashOn) {
      try {
        await _controller?.setFlashMode(FlashMode.off);
      } catch (_) {}
    }

    if (_isFlashOn) {
      setState(() => _isFlashOn = false);
    }

    final targetCamera = isCurrentlyFront ? _mainBackCamera : _frontCamera;

    if (mounted) {
      setState(() => _isFlippingCamera = true);
      _flipAnimController.forward(from: 0.0);
    }

    await _switchCamera(targetCamera);

    if (mounted) {
      if (_flipAnimController.isAnimating) {
        await _flipAnimController.forward();
      }
      _flipAnimController.reset();
      setState(() => _isFlippingCamera = false);
    }
  }

  // Set Zoom Level with support for .5, 1x, 2x, 3x
  Future<void> _setZoom(double targetZoom) async {
    if (_controller == null || !_controller!.value.isInitialized || _isSwitchingCamera) return;

    final isBack =
        _controller!.description.lensDirection == CameraLensDirection.back;

    if (!isBack) {
      // Front camera wide/standard toggle: direct zoom without camera switch
      final target = targetZoom <= 0.85 ? _minZoom : 1.0;
      try {
        await _controller!.setZoomLevel(target);
        setState(() => _currentZoom = target);
      } catch (_) {}
      return;
    }

    // Back Camera Zoom Logic
    if (targetZoom <= 0.7) {
      // Ultra-Wide (.5)
      if (_ultraWideCamera != null) {
        if (_controller!.description != _ultraWideCamera) {
          await _switchCamera(_ultraWideCamera!);
        }
        setState(() => _currentZoom = 0.5);
      } else if (_minZoom <= 0.7) {
        try {
          await _controller!.setZoomLevel(_minZoom);
        } catch (_) {}
        setState(() => _currentZoom = 0.5);
      }
      return;
    }

    // Standard 1x, 2x, 3x:
    // If currently on Ultra-Wide, switch back to main back camera first
    if (_controller!.description != _mainBackCamera) {
      await _switchCamera(_mainBackCamera);
    }

    // Direct hardware/digital zoom on main camera (smooth, zero tear-down, no black screen)
    final clampedZoom = targetZoom.clamp(_minZoom, _maxZoom);
    try {
      await _controller!.setZoomLevel(clampedZoom);
      setState(() => _currentZoom = clampedZoom);
    } catch (e) {
      debugPrint('Set zoom level error: $e');
    }
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
    final isFront =
        _controller?.description.lensDirection == CameraLensDirection.front;

    if (isFront) {
      // Front camera Retina Screen Flash toggle
      setState(() => _isFlashOn = nextFlash);
      try {
        await _controller!.setFlashMode(FlashMode.off);
      } catch (_) {}
      return;
    }

    // Back camera hardware torch / flash
    try {
      await _controller!.setFlashMode(
        nextFlash ? FlashMode.torch : FlashMode.off,
      );
      setState(() => _isFlashOn = nextFlash);
    } catch (_) {
      try {
        await _controller!.setFlashMode(
          nextFlash ? FlashMode.always : FlashMode.off,
        );
        setState(() => _isFlashOn = nextFlash);
      } catch (_) {
        setState(() => _isFlashOn = nextFlash);
      }
    }
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
    final isFront =
        _controller?.description.lensDirection == CameraLensDirection.front;

    try {
      HapticHelper.medium();
      _shutterAnimController
          .forward()
          .then((_) => _shutterAnimController.reverse());

      // Strictly ensure native camera flash mode is off when flash is off or for front camera
      if (!_isFlashOn || isFront) {
        try {
          if (_controller!.value.flashMode != FlashMode.off) {
            await _controller!.setFlashMode(FlashMode.off);
          }
        } catch (_) {}
      }

      // Retina Screen Flash for front camera selfie in the dark
      if (_isFlashOn && isFront) {
        setState(() => _isScreenFlashing = true);
        await Future.delayed(const Duration(milliseconds: 180));
      }

      final xFile = await _controller!.takePicture();

      if (_isScreenFlashing) {
        setState(() => _isScreenFlashing = false);
      }

      // Mirror front camera photo file on disk so saved image matches live mirror preview 100%
      String finalPath = xFile.path;
      if (isFront) {
        finalPath = await MediaHelper.mirrorFrontCameraPhoto(xFile.path);
      }

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PreviewScreen(
              filePath: finalPath,
              isVideo: false,
              isMirrored: false,
              filter: _selectedFilter,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Take picture error: $e');
      if (_isScreenFlashing && mounted) {
        setState(() => _isScreenFlashing = false);
      }
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

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PreviewScreen(
              filePath: xFile.path,
              isVideo: true,
              isMirrored: false,
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navBarClearance = 80.0 + bottomInset + 16.0;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // 1. Top App Bar Controls
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceLg,
                vertical: AppDimens.spaceSm,
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

                  // Actions: Map, Messages & Flash
                  Row(
                    children: [
                      // Map icon
                      GestureDetector(
                        onTap: () {
                          HapticHelper.selection();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const MapScreen(),
                            ),
                          );
                        },
                        child: FrostedContainer(
                          borderRadius: AppDimens.radiusFull,
                          padding: const EdgeInsets.all(10),
                          child: const Icon(
                            LucideIcons.mapPin,
                            color: AppColors.white,
                            size: 22,
                          ),
                        ),
                      ),

                      const SizedBox(width: AppDimens.spaceMd),

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

            const SizedBox(height: 4),

            // 2. Camera Viewfinder (Native 3:4 aspect ratio with rounded corners)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                        ),
                        child: AnimatedBuilder(
                          animation: _flipAnimController,
                          builder: (context, child) {
                            final angle = _flipAnimController.value * 3.141592653589793;
                            final isBackHalf = _flipAnimController.value > 0.5;
                            return Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateY(angle),
                              child: isBackHalf
                                  ? Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.identity()
                                        ..rotateY(3.141592653589793),
                                      child: child,
                                    )
                                  : child,
                            );
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // 2.1 Viewfinder with Pinch-to-zoom
                              if (_controller != null && _controller!.value.isInitialized)
                                GestureDetector(
                                  onScaleStart: (details) {
                                    _baseScale = _currentZoom;
                                  },
                                  onScaleUpdate: (details) {
                                    final newZoom = (_baseScale * details.scale)
                                        .clamp(_minZoom, _maxZoom);
                                    _controller!.setZoomLevel(newZoom);
                                    setState(() => _currentZoom = newZoom);
                                  },
                                  child: Builder(
                                    builder: (context) {
                                      final previewSize = _controller?.value.previewSize;
                                      final double previewW =
                                          previewSize != null ? previewSize.height : 720.0;
                                      final double previewH =
                                          previewSize != null ? previewSize.width : 1280.0;

                                      return FittedBox(
                                        fit: BoxFit.cover,
                                        clipBehavior: Clip.hardEdge,
                                        child: SizedBox(
                                          width: previewW,
                                          height: previewH,
                                          child: _selectedFilter.colorFilter != null
                                              ? ColorFiltered(
                                                  colorFilter:
                                                      _selectedFilter.colorFilter!,
                                                  child: CameraPreview(_controller!),
                                                )
                                              : CameraPreview(_controller!),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              else
                                const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                    strokeWidth: 2.5,
                                  ),
                                ),

                              // 2.2 Lens Switch Smooth Transition Blur (during .5 <-> 1x)
                              if (_isTransitioningLens && !_isFlippingCamera)
                                Positioned.fill(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                    child: Container(
                                      color: Colors.black.withValues(alpha: 0.3),
                                    ),
                                  ),
                                ),

                            // 2.2 TikTok Skin-Smoothing & Blemish Softening Diffusion Layer
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
                                        color: _selectedFilter.overlayColor !=
                                                Colors.transparent
                                            ? _selectedFilter.overlayColor
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // 2.3 Beauty Filter Color Overlay
                            if (_selectedFilter.blurSigma == 0 &&
                                _selectedFilter.overlayColor != Colors.transparent)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    color: _selectedFilter.overlayColor,
                                  ),
                                ),
                              ),

                            // 2.4 Zoom / Lens Selector (.5 | 1x | 2x | 3x) inside Viewfinder
                            if (!_isRecording)
                              Positioned(
                                bottom: 14,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: FrostedContainer(
                                    borderRadius: AppDimens.radiusFull,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    backgroundColor: const Color(0x66000000),
                                    child: Builder(
                                      builder: (context) {
                                        final isFront = _controller
                                                ?.description.lensDirection ==
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
                                              isSelected: _currentZoom > 0.7 &&
                                                  _currentZoom < 1.8,
                                              onTap: () => _setZoom(1.0),
                                            ),
                                            _buildZoomOption(
                                              label: '2x',
                                              isSelected: _currentZoom >= 1.8 &&
                                                  _currentZoom < 2.8,
                                              onTap: () => _setZoom(2.0),
                                            ),
                                            if (_hasTelephoto)
                                              _buildZoomOption(
                                                label: '3x',
                                                isSelected: _currentZoom >= 2.8,
                                                onTap: () => _setZoom(3.0),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 3. Beauty Filter Selector (TikTok filters)
            if (!_isRecording)
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceLg,
                  ),
                  itemCount: BeautyFilter.all.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: AppDimens.spaceMd),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        backgroundColor: isSelected
                            ? AppColors.primary.withValues(alpha: 0.85)
                            : const Color(0x4D1E0D26),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryLight
                              : Colors.white24,
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

            const SizedBox(height: 12),

            // 4. Bottom Shutter & Controls (positioned above bottom navigation bar)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceLg,
              ),
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

            // Bottom clearance for floating MainScaffold bottom nav bar
            SizedBox(height: navBarClearance),
          ],
        ),
      ),

      // Screen Flash Overlay for front camera
      if (_isScreenFlashing)
        Positioned.fill(
          child: Container(
            color: const Color(0xFFFFFBEA),
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
