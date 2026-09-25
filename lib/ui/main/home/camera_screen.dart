import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import '../../../providers/friends_provider.dart';
import '../../../providers/notifications_provider.dart';
import '../../../services/camera_effects_service.dart';
import '../../common/app_badge.dart';
import '../../common/camera_effect_layer.dart';
import '../../../core/utils/media_helper.dart';
import '../../common/frosted_container.dart';
import '../../common/image_crop_screen.dart';
import '../chat/chat_list_screen.dart';
import '../friends/friends_screen.dart';
import '../notifications/notifications_screen.dart';
import 'preview_screen.dart';
import 'widgets/camera_controls.dart';
import 'widgets/camera_filter_bar.dart';

class CameraScreen extends ConsumerStatefulWidget {
  final bool isActive;
  final int cameraTrigger;

  const CameraScreen({
    super.key,
    this.isActive = true,
    this.cameraTrigger = 0,
  });

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
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
  double _filterIntensity = 0;
  BeautySettings _beauty = const BeautySettings();
  FilterCategory _selectedCategory = FilterCategory.natural;
  bool _showOriginal = false;
  final CameraEffectsService _effectsService = CameraEffectsService();
  Timer? _effectsSaveTimer;

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
  late AnimationController _recordProgressController;
  late AnimationController _recPulseController;
  bool _isFlippingCamera = false;
  bool _isSwitchingCamera = false;
  bool _isTransitioningLens = false;
  Future<void>? _pendingDispose;
  CameraDescription? _currentCameraDescription;
  final GlobalKey _viewfinderKey = GlobalKey();
  ui.Image? _frozenFrame;

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
    _recordProgressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: maxVideoDuration),
    );
    _recordProgressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && _isRecording) {
        _handleStopRecording();
      }
    });
    _recPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _loadEffects();
    _initCameras();
  }

  @override
  void didUpdateWidget(CameraScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      // Switched back to camera tab -> restore live 60fps preview!
      _resumeCamera();
    } else if (oldWidget.isActive && !widget.isActive) {
      // Switched away to another tab (e.g. Map) -> pause camera to save battery & GPU!
      _pauseCamera();
    } else if (widget.isActive && widget.cameraTrigger != oldWidget.cameraTrigger) {
      // Widget on home screen was tapped while app is running -> guarantee fresh 60fps camera!
      _ensureFreshCamera(forceRestart: true);
    }
  }

  Future<void> _loadEffects() async {
    final selection = await _effectsService.loadSelection();
    if (!mounted) return;
    setState(() {
      _selectedFilter = selection.filter;
      _filterIntensity = selection.filterIntensity;
      _beauty = selection.beauty;
      _selectedCategory = selection.filter.category ?? FilterCategory.natural;
    });
  }

  void _saveEffectsSoon() {
    _effectsSaveTimer?.cancel();
    _effectsSaveTimer = Timer(const Duration(milliseconds: 250), () {
      _effectsService.saveSelection(
        CameraEffectsSelection(
          filter: _selectedFilter,
          filterIntensity: _filterIntensity,
          beauty: _beauty,
        ),
      );
    });
  }

  void _selectFilter(BeautyFilter filter) {
    HapticHelper.selection();
    setState(() {
      _selectedFilter = filter;
      _filterIntensity = filter.defaultIntensity;
      if (filter.category != null) _selectedCategory = filter.category!;
    });
    _saveEffectsSoon();
  }

  void _resetEffects() {
    setState(() {
      _selectedFilter = BeautyFilter.all.first;
      _filterIntensity = 0;
      _beauty = const BeautySettings();
      _selectedCategory = FilterCategory.natural;
    });
    _saveEffectsSoon();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _longPressTimer?.cancel();
    _recordTimer?.cancel();
    _effectsSaveTimer?.cancel();
    _frozenFrame?.dispose();
    _frozenFrame = null;
    _controller?.dispose();
    _shutterAnimController.dispose();
    _flipAnimController.dispose();
    _recordProgressController.dispose();
    _recPulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Free native camera session whenever leaving foreground
      _pauseCamera();
    } else if (state == AppLifecycleState.resumed) {
      // When resuming from background, widget tap, or unlock: restore fresh camera session
      if (widget.isActive) {
        _resumeCamera();
      }
    }
  }

  Future<void> _captureSnapshot() async {
    try {
      final boundary = _viewfinderKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null && boundary.hasSize) {
        final snapshot = await boundary.toImage(pixelRatio: 1.0);
        final oldFrame = _frozenFrame;
        _frozenFrame = snapshot;
        oldFrame?.dispose();
      }
    } catch (_) {}
  }

  Future<void> _pauseCamera() async {
    if (_controller == null && _pendingDispose == null) return;
    await _captureSnapshot();
    final c = _controller;
    _controller = null;
    if (mounted) setState(() {});
    if (c != null) {
      try {
        await c.pausePreview();
      } catch (_) {}
      _pendingDispose = c.dispose();
    }
  }

  Future<void> _resumeCamera() async {
    if (_pendingDispose != null) {
      try {
        await _pendingDispose;
      } catch (_) {}
      _pendingDispose = null;
    }
    await _ensureFreshCamera(forceRestart: true);
  }

  Future<void> _ensureFreshCamera({bool forceRestart = false}) async {
    if (_isSwitchingCamera) return;
    if (forceRestart || _controller == null || !_controller!.value.isInitialized) {
      final targetCamera = _currentCameraDescription ?? _mainBackCamera;
      await _switchCamera(targetCamera);
    }
  }

  // Camera Getters
  List<CameraDescription> get _backCameras => _cameras
      .where((c) => c.lensDirection == CameraLensDirection.back)
      .toList();

  List<CameraDescription> get _frontCameras => _cameras
      .where((c) => c.lensDirection == CameraLensDirection.front)
      .toList();

  CameraDescription get _frontCamera {
    if (_frontCameras.isNotEmpty) return _frontCameras.first;
    return _cameras.first;
  }

  CameraDescription get _mainBackCamera {
    final back = _backCameras;
    if (back.isEmpty) return _cameras.first;

    // 1. Explicit lensType == wide
    final explicitWide = back
        .where((c) => c.lensType == CameraLensType.wide)
        .firstOrNull;
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
    final explicitUltra = back
        .where((c) => c.lensType == CameraLensType.ultraWide)
        .firstOrNull;
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
    final explicitTele = back
        .where((c) => c.lensType == CameraLensType.telephoto)
        .firstOrNull;
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

    // 1. Capture snapshot of current viewfinder before unmounting old controller
    await _captureSnapshot();

    final oldController = _controller;
    if (mounted) {
      setState(() {
        _isTransitioningLens = true;
        // Unmount old controller so dead texture is NEVER rendered (eliminates gray screen!)
        _controller = null;
      });
    }

    // 2. Cleanly dispose previous controller
    if (oldController != null) {
      try {
        await oldController.dispose();
      } catch (e) {
        debugPrint('Error disposing old controller: $e');
      }
    }

    // 3. Initialize new controller
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
      final initialZoom = isFront
          ? _minZoom
          : (_minZoom < 1.0 ? 1.0 : _minZoom);
      try {
        await newController.setZoomLevel(initialZoom);
      } catch (_) {}

      if (targetCamera == _ultraWideCamera) {
        _currentZoom = 0.5;
      } else {
        _currentZoom = initialZoom;
      }

      // Explicitly configure flashMode right after initialization.
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

      if (!mounted || !widget.isActive) {
        await newController.dispose();
        _isSwitchingCamera = false;
        if (mounted) {
          setState(() => _isTransitioningLens = false);
        }
        return;
      }

      if (mounted) {
        setState(() {
          _controller = newController;
          _isTransitioningLens = false;
        });

        // Let the new camera preview paint a frame before clearing the frozen frame
        Future.delayed(const Duration(milliseconds: 140), () {
          if (mounted) {
            final oldFrame = _frozenFrame;
            setState(() => _frozenFrame = null);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              oldFrame?.dispose();
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
      try {
        await newController.dispose();
      } catch (_) {}
      if (mounted) {
        setState(() => _isTransitioningLens = false);
      }
    } finally {
      _isSwitchingCamera = false;
    }
  }

  // Toggle Camera Facing strictly between Front and Back with smooth 3D flip animation
  void _toggleCameraFacing() async {
    if (_cameras.length < 2 ||
        _isRecording ||
        _isStartingRecording ||
        _isSwitchingCamera ||
        _isFlippingCamera) {
      return;
    }
    HapticHelper.selection();

    final isCurrentlyFront =
        (_controller?.description.lensDirection ??
                _currentCameraDescription?.lensDirection) ==
            CameraLensDirection.front;
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
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isSwitchingCamera) {
      return;
    }

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
      final xFile = await _imagePicker.pickMedia(imageQuality: 95);
      if (xFile != null && mounted) {
        final pathLower = xFile.path.toLowerCase();
        final isVideo =
            pathLower.endsWith('.mp4') ||
            pathLower.endsWith('.mov') ||
            pathLower.endsWith('.avi') ||
            pathLower.endsWith('.m4v');

        if (isVideo) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PreviewScreen(
                filePath: xFile.path,
                isVideo: true,
                isMirrored: false,
                filter: _selectedFilter,
                filterIntensity: _filterIntensity,
                beauty: _beauty,
              ),
            ),
          );
        } else {
          // Open Zoom & Crop screen with 3:4 default aspect ratio
          final cropped = await Navigator.of(context).push<File>(
            MaterialPageRoute(
              builder: (_) => ImageCropScreen(
                imageFile: File(xFile.path),
                cropStyle: CropStyle.rectangle,
                initialAspectRatio: 3 / 4,
                title: 'Chỉnh sửa ảnh',
              ),
            ),
          );

          if (cropped != null && mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PreviewScreen(
                  filePath: cropped.path,
                  isVideo: false,
                  isMirrored: false,
                  filter: _selectedFilter,
                  filterIntensity: _filterIntensity,
                  beauty: _beauty,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Pick gallery error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      } else {
        _isProcessing = false;
      }
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
      _shutterAnimController.forward().then(
        (_) => _shutterAnimController.reverse(),
      );

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
              filterIntensity: _filterIntensity,
              beauty: _beauty,
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

      _recordProgressController.reset();
      _recordProgressController.forward();
      _recPulseController.repeat(reverse: true);

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
      _recordProgressController.stop();
      _recordProgressController.reset();
      _recPulseController.stop();
      _recPulseController.reset();
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
    _recordProgressController.stop();
    _recordProgressController.reset();
    _recPulseController.stop();
    _recPulseController.reset();

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
              filterIntensity: _filterIntensity,
              beauty: _beauty,
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
    final unreadRequests = ref.watch(friendRequestsProvider).value?.length ?? 0;
    final unreadNotifications = ref.watch(unreadNotificationsCountProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navBarClearance = 74.0 + bottomInset;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.black : AppColors.lightBackground,
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
                            style: AppTypography.h2(
                              color: AppColors.primaryLight,
                            ),
                          ),
                          Text(
                            'Pearl',
                            style: AppTypography.h2(
                              color: isDark
                                  ? AppColors.pearl
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),

                      // Actions: Friends, Notifications, Messages & Flash
                      Row(
                        children: [
                          // 1. Friends button with friend requests badge
                          GestureDetector(
                            onTap: () {
                              HapticHelper.selection();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const FriendsScreen(),
                                ),
                              );
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                FrostedContainer(
                                  borderRadius: AppDimens.radiusFull,
                                  padding: const EdgeInsets.all(9),
                                  backgroundColor: isDark
                                      ? const Color(0x331E0D26)
                                      : AppColors.lightSurface.withValues(
                                          alpha: 0.9,
                                        ),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.12)
                                        : AppColors.lightBorder.withValues(
                                            alpha: 0.6,
                                          ),
                                    width: 1,
                                  ),
                                  child: Icon(
                                    LucideIcons.users,
                                    color: isDark
                                        ? AppColors.white
                                        : AppColors.lightTextPrimary,
                                    size: 20,
                                  ),
                                ),
                                if (unreadRequests > 0)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: AppBadge(count: unreadRequests),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(width: AppDimens.spaceSm),

                          // 2. Notifications bell with unread count badge
                          GestureDetector(
                            onTap: () {
                              HapticHelper.selection();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationsScreen(),
                                ),
                              );
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                FrostedContainer(
                                  borderRadius: AppDimens.radiusFull,
                                  padding: const EdgeInsets.all(9),
                                  backgroundColor: isDark
                                      ? const Color(0x331E0D26)
                                      : AppColors.lightSurface.withValues(
                                          alpha: 0.9,
                                        ),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.12)
                                        : AppColors.lightBorder.withValues(
                                            alpha: 0.6,
                                          ),
                                    width: 1,
                                  ),
                                  child: Icon(
                                    LucideIcons.bell,
                                    color: isDark
                                        ? AppColors.white
                                        : AppColors.lightTextPrimary,
                                    size: 20,
                                  ),
                                ),
                                if (unreadNotifications > 0)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: AppBadge(count: unreadNotifications),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(width: AppDimens.spaceSm),

                          // 3. Chat icon with unread badge
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
                                  padding: const EdgeInsets.all(9),
                                  backgroundColor: isDark
                                      ? const Color(0x331E0D26)
                                      : AppColors.lightSurface.withValues(
                                          alpha: 0.9,
                                        ),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.12)
                                        : AppColors.lightBorder.withValues(
                                            alpha: 0.6,
                                          ),
                                    width: 1,
                                  ),
                                  child: Icon(
                                    LucideIcons.messageCircle,
                                    color: isDark
                                        ? AppColors.white
                                        : AppColors.lightTextPrimary,
                                    size: 20,
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

                          const SizedBox(width: AppDimens.spaceSm),

                          // 4. Flash Toggle
                          GestureDetector(
                            onTap: _toggleFlash,
                            child: FrostedContainer(
                              borderRadius: AppDimens.radiusFull,
                              padding: const EdgeInsets.all(9),
                              backgroundColor: isDark
                                  ? const Color(0x331E0D26)
                                  : AppColors.lightSurface.withValues(
                                      alpha: 0.9,
                                    ),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : AppColors.lightBorder.withValues(
                                        alpha: 0.6,
                                      ),
                                width: 1,
                              ),
                              child: Icon(
                                _isFlashOn
                                    ? LucideIcons.zap
                                    : LucideIcons.zapOff,
                                color: _isFlashOn
                                    ? AppColors.warning
                                    : (isDark
                                          ? AppColors.white
                                          : AppColors.lightTextPrimary),
                                size: 20,
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
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : AppColors.lightBorder,
                                width: 1.5,
                              ),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.08,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: AnimatedBuilder(
                              animation: _flipAnimController,
                              builder: (context, child) {
                                final angle =
                                    _flipAnimController.value *
                                    3.141592653589793;
                                final isBackHalf =
                                    _flipAnimController.value > 0.5;
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
                                  // 2.0 Frozen Snapshot during transitions (held underneath to prevent any gray/black blink)
                                  if (_frozenFrame != null)
                                    Positioned.fill(
                                      child: RawImage(
                                        image: _frozenFrame,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.center,
                                      ),
                                    ),

                                  // 2.1 Viewfinder with Pinch-to-zoom & Long-press to compare original
                                  if (_controller != null &&
                                      _controller!.value.isInitialized)
                                    RepaintBoundary(
                                      key: _viewfinderKey,
                                      child: GestureDetector(
                                        onScaleStart: (details) {
                                          _baseScale = _currentZoom;
                                        },
                                        onScaleUpdate: (details) {
                                          final newZoom =
                                              (_baseScale * details.scale).clamp(
                                                _minZoom,
                                                _maxZoom,
                                              );
                                          _controller!.setZoomLevel(newZoom);
                                          setState(() => _currentZoom = newZoom);
                                        },
                                        onLongPressStart: (_) {
                                          HapticHelper.light();
                                          setState(() => _showOriginal = true);
                                        },
                                        onLongPressEnd: (_) {
                                          setState(() => _showOriginal = false);
                                        },
                                        child: Builder(
                                          builder: (context) {
                                            final previewSize =
                                                _controller?.value.previewSize;
                                            final double previewW =
                                                previewSize != null
                                                ? previewSize.height
                                                : 720.0;
                                            final double previewH =
                                                previewSize != null
                                                ? previewSize.width
                                                : 1280.0;

                                            return FittedBox(
                                              fit: BoxFit.cover,
                                              clipBehavior: Clip.hardEdge,
                                              child: SizedBox(
                                                width: previewW,
                                                height: previewH,
                                                child: CameraEffectLayer(
                                                  filter: _selectedFilter,
                                                  filterIntensity:
                                                      _filterIntensity,
                                                  beauty: _beauty,
                                                  showOriginal: _showOriginal,
                                                  child: CameraPreview(
                                                    _controller!,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    )
                                  else if (_frozenFrame == null)
                                    Container(
                                      color: Colors.black,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.primary,
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                    ),

                                  // 2.2 Lens Switch Smooth Transition Blur (during .5 <-> 1x)
                                  if (_isTransitioningLens &&
                                      !_isFlippingCamera)
                                    Positioned.fill(
                                      child: BackdropFilter(
                                         filter: ui.ImageFilter.blur(
                                          sigmaX: 12,
                                          sigmaY: 12,
                                        ),
                                        child: Container(
                                          color: Colors.black.withValues(
                                            alpha: 0.15,
                                          ),
                                        ),
                                      ),
                                    ),

                                  // 2.3 Original Image Comparison Pill
                                  if (_showOriginal)
                                    Positioned(
                                      top: 14,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.75,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: Colors.white30,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                LucideIcons.eye,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Đang xem ảnh gốc',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
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
                                          backgroundColor: const Color(
                                            0x66000000,
                                          ),
                                          child: Builder(
                                            builder: (context) {
                                              final isFront =
                                                  _controller
                                                      ?.description
                                                      .lensDirection ==
                                                  CameraLensDirection.front;
                                              if (isFront) {
                                                return Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (_minZoom < 0.95)
                                                      _buildZoomOption(
                                                        label: _minZoom <= 0.6
                                                            ? '.5'
                                                            : '.7',
                                                        isSelected:
                                                            _currentZoom <=
                                                            0.85,
                                                        onTap: () =>
                                                            _setZoom(_minZoom),
                                                      ),
                                                    _buildZoomOption(
                                                      label: '1x',
                                                      isSelected:
                                                          _currentZoom > 0.85,
                                                      onTap: () =>
                                                          _setZoom(1.0),
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
                                                      isSelected:
                                                          _currentZoom <= 0.7,
                                                      onTap: () =>
                                                          _setZoom(0.5),
                                                    ),
                                                  _buildZoomOption(
                                                    label: '1x',
                                                    isSelected:
                                                        _currentZoom > 0.7 &&
                                                        _currentZoom < 1.8,
                                                    onTap: () => _setZoom(1.0),
                                                  ),
                                                  _buildZoomOption(
                                                    label: '2x',
                                                    isSelected:
                                                        _currentZoom >= 1.8 &&
                                                        _currentZoom < 2.8,
                                                    onTap: () => _setZoom(2.0),
                                                  ),
                                                  if (_hasTelephoto)
                                                    _buildZoomOption(
                                                      label: '3x',
                                                      isSelected:
                                                          _currentZoom >= 2.8,
                                                      onTap: () =>
                                                          _setZoom(3.0),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),

                                    // 2.5 Dynamic Video Recording HUD: Shrinking Laser Progress Line & Island Countdown
                                    if (_isRecording) _buildRecordingHUD(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // 3. Multi-Category Filter Carousel, Intensity Slider & Beauty Controls
                CameraFilterBar(
                  selectedFilter: _selectedFilter,
                  selectedCategory: _selectedCategory,
                  filterIntensity: _filterIntensity,
                  beauty: _beauty,
                  isDark: isDark,
                  isRecording: _isRecording,
                  onSelectFilter: _selectFilter,
                  onSelectCategory: (cat) =>
                      setState(() => _selectedCategory = cat),
                  onIntensityChanged: (val) {
                    setState(() => _filterIntensity = val);
                    _saveEffectsSoon();
                  },
                  onReset: _resetEffects,
                  onOpenBeauty: () => _showBeautySettingsSheet(isDark),
                ),

                const SizedBox(height: 6),

                // 4. Bottom Shutter & Controls (positioned above bottom navigation bar)
                CameraControls(
                  onPickGallery: _pickMediaFromGallery,
                  onPointerDown: _handlePointerDown,
                  onPointerUp: _handlePointerUp,
                  onPointerCancel: _handlePointerCancel,
                  onFlipCamera: _toggleCameraFacing,
                  isButtonPressed: _isButtonPressed,
                  isRecording: _isRecording,
                  recordProgressAnimation: _recordProgressController,
                  isDark: isDark,
                ),

                // Bottom clearance for floating MainScaffold bottom nav bar
                SizedBox(height: navBarClearance),
              ],
            ),
          ),

          // Screen Flash Overlay for front camera
          if (_isScreenFlashing)
            Positioned.fill(child: Container(color: AppColors.screenFlash)),
        ],
      ),
    );
  }

  void _showBeautySettingsSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final textColor = isDark
                ? AppColors.white
                : AppColors.lightTextPrimary;
            final subTextColor = isDark
                ? Colors.white70
                : AppColors.lightTextSecondary;

            Widget buildSliderRow({
              required String label,
              required double value,
              required ValueChanged<double> onChanged,
            }) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.5,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: isDark
                              ? Colors.white24
                              : AppColors.lightBorder,
                          thumbColor: AppColors.primary,
                        ),
                        child: Slider(
                          value: value,
                          min: 0.0,
                          max: 1.0,
                          onChanged: _beauty.enabled
                              ? (v) {
                                  setSheetState(() {
                                    onChanged(v);
                                  });
                                  setState(() {});
                                  _saveEffectsSoon();
                                }
                              : null,
                        ),
                      ),
                    ),
                    Container(
                      width: 36,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${(value * 100).round()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: subTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1E26)
                    : AppColors.lightSurface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Title & Master Switch
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.sparkles,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Làm đẹp da tự nhiên',
                              style: AppTypography.h3(color: textColor),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                HapticHelper.light();
                                setSheetState(() {
                                  _beauty = const BeautySettings();
                                });
                                setState(() {});
                                _saveEffectsSoon();
                              },
                              child: Text(
                                'Mặc định',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              value: _beauty.enabled,
                              activeTrackColor: AppColors.primary,
                              onChanged: (val) {
                                HapticHelper.selection();
                                setSheetState(() {
                                  _beauty = _beauty.copyWith(enabled: val);
                                });
                                setState(() {});
                                _saveEffectsSoon();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Divider(height: 16),

                    // Sliders
                    buildSliderRow(
                      label: 'Tổng thể (Overall)',
                      value: _beauty.overall,
                      onChanged: (v) => _beauty = _beauty.copyWith(overall: v),
                    ),
                    buildSliderRow(
                      label: 'Làm mịn da',
                      value: _beauty.smoothing,
                      onChanged: (v) =>
                          _beauty = _beauty.copyWith(smoothing: v),
                    ),
                    buildSliderRow(
                      label: 'Đều màu da',
                      value: _beauty.toneEvenness,
                      onChanged: (v) =>
                          _beauty = _beauty.copyWith(toneEvenness: v),
                    ),
                    buildSliderRow(
                      label: 'Giảm khuyết điểm',
                      value: _beauty.blemishReduction,
                      onChanged: (v) =>
                          _beauty = _beauty.copyWith(blemishReduction: v),
                    ),
                    buildSliderRow(
                      label: 'Sáng da tự nhiên',
                      value: _beauty.brightness,
                      onChanged: (v) =>
                          _beauty = _beauty.copyWith(brightness: v),
                    ),
                    buildSliderRow(
                      label: 'Tươi tắn & Sức sống',
                      value: _beauty.vitality,
                      onChanged: (v) => _beauty = _beauty.copyWith(vitality: v),
                    ),
                    buildSliderRow(
                      label: 'Giảm bóng dầu / Cháy',
                      value: _beauty.highlightReduction,
                      onChanged: (v) =>
                          _beauty = _beauty.copyWith(highlightReduction: v),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

  /// Dynamic Video Recording HUD: Shrinking Laser Progress Line & Island Countdown
  Widget _buildRecordingHUD() {
    return Positioned(
      top: 14,
      left: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Shrinking Laser Progress Line (from 100% width down to 0% width)
          AnimatedBuilder(
            animation: _recordProgressController,
            builder: (context, child) {
              final remainingFraction = (1.0 - _recordProgressController.value)
                  .clamp(0.0, 1.0);
              final isUrgent = remainingFraction <= (3.0 / maxVideoDuration);

              return Container(
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final lineWidth = constraints.maxWidth * remainingFraction;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Shrinking neon bar
                        Container(
                          width: lineWidth,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: LinearGradient(
                              colors: isUrgent
                                  ? const [
                                      Color(0xFFFF1744),
                                      Color(0xFFFF5252),
                                      Color(0xFFFF8A80),
                                    ]
                                  : const [
                                      AppColors.primary,
                                      AppColors.primaryLight,
                                      Color(0xFFFF9EBA),
                                    ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isUrgent
                                            ? const Color(0xFFFF1744)
                                            : AppColors.primaryLight)
                                        .withValues(alpha: 0.7),
                                blurRadius: 6,
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                        ),

                        // Glowing Pearl Tip at the leading edge of shrinking line
                        if (lineWidth > 6)
                          Positioned(
                            left: lineWidth - 5,
                            top: -2.5,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: isUrgent
                                        ? const Color(0xFFFF1744)
                                        : AppColors.primaryLight,
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                  const BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // 2. Dynamic Recording Island HUD
          AnimatedBuilder(
            animation: Listenable.merge([
              _recordProgressController,
              _recPulseController,
            ]),
            builder: (context, child) {
              final remainingSec =
                  (maxVideoDuration * (1.0 - _recordProgressController.value))
                      .ceil()
                      .clamp(0, maxVideoDuration);
              final isUrgent = remainingSec <= 3;
              final pulseVal = _recPulseController.value;

              return Center(
                child: FrostedContainer(
                  borderRadius: AppDimens.radiusFull,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  backgroundColor: const Color(0x80000000),
                  border: Border.all(
                    color: isUrgent
                        ? Color.lerp(
                            const Color(0xFFFF1744),
                            Colors.white,
                            pulseVal * 0.6,
                          )!
                        : Colors.white.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🔴 Pulsing REC Dot
                      Transform.scale(
                        scale: 0.85 + (pulseVal * 0.3),
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFF1744),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF1744)
                                    .withValues(alpha: 0.85),
                                blurRadius: 5 + (pulseVal * 5),
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // REC label
                      const Text(
                        'REC',
                        style: TextStyle(
                          color: Color(0xFFFF5252),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Divider
                      Container(width: 1, height: 12, color: Colors.white24),
                      const SizedBox(width: 8),

                      // Countdown text
                      Text(
                        '${remainingSec}s',
                        style: AppTypography.bold.copyWith(
                          color: isUrgent
                              ? const Color(0xFFFF5252)
                              : AppColors.white,
                          fontSize: 14,
                          letterSpacing: 0.5,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
