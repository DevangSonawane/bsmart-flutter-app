import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_model.dart';
import 'create_post_screen.dart';
import 'create_upload_screen.dart';

class StoryCameraScreen extends StatefulWidget {
  const StoryCameraScreen({super.key});

  @override
  State<StoryCameraScreen> createState() => _StoryCameraScreenState();
}

class _StoryCameraScreenState extends State<StoryCameraScreen> with WidgetsBindingObserver {
  FlashMode _flashMode = FlashMode.off;
  bool _recording = false;
  UploadMode _mode = UploadMode.story;
  CameraController? _controller;
  bool _initializing = true;
  bool _permissionDenied = false;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _isSwitchingCamera = false;
  final List<AssetEntity> _recentAssets = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _loadRecentMedia();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _controller = null;
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
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameraController(_currentCameraIndex);
    }
  }

  Future<void> _initCamera() async {
    try {
      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) {
        if (mounted) {
          setState(() {
            _permissionDenied = true;
            _initializing = false;
          });
        }
        return;
      }

      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (mounted) {
          setState(() {
            _permissionDenied = true;
            _initializing = false;
          });
        }
        return;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _initializing = false;
          });
        }
        return;
      }

      await _initializeCameraController(_currentCameraIndex);

      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _permissionDenied = true;
      });
    }
  }

  Future<void> _initializeCameraController(int cameraIndex) async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }

    if (cameraIndex >= _cameras.length) {
      return;
    }

    final controller = CameraController(
      _cameras[cameraIndex],
      ResolutionPreset.max,  // Changed to max for best quality
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
      if (mounted) {
        setState(() {
          _controller = controller;
        });
      } else {
        await controller.dispose();
      }
    } catch (_) {
      await controller.dispose();
    }
  }

  void _toggleFlash() {
    setState(() {
      if (_flashMode == FlashMode.off) {
        _flashMode = FlashMode.auto;
      } else if (_flashMode == FlashMode.auto) {
        _flashMode = FlashMode.always;
      } else {
        _flashMode = FlashMode.off;
      }
    });
    _applyFlashMode();
  }

  void _applyFlashMode() {
    if (_controller == null) return;
    _controller!.setFlashMode(_flashMode).catchError((_) {});
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      return;
    }
    if (_isSwitchingCamera) {
      return;
    }

    setState(() {
      _isSwitchingCamera = true;
    });

    try {
      _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
      await _initializeCameraController(_currentCameraIndex);
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
        });
      }
    }
  }

  Future<void> _loadRecentMedia() async {
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth) {
        return;
      }

      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        filterOption: FilterOptionGroup(
          orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
        ),
      );

      if (albums.isEmpty) {
        return;
      }

      final recentAlbum = albums.first;
      final List<AssetEntity> media = await recentAlbum.getAssetListPaged(
        page: 0,
        size: 15,
      );

      if (!mounted) return;

      setState(() {
        _recentAssets
          ..clear()
          ..addAll(media);
      });
    } catch (_) {}
  }

  Future<void> _onCapturePressed() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture || _controller!.value.isRecordingVideo) return;
    try {
      final xfile = await _controller!.takePicture();
      await _navigateToEditor(File(xfile.path), MediaType.image);
    } catch (_) {}
  }

  Future<void> _onRecordStart() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isRecordingVideo) return;
    try {
      await _controller!.startVideoRecording();
      setState(() {
        _recording = true;
      });
    } catch (_) {}
  }

  Future<void> _onRecordEnd() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) {
      if (_recording) {
        setState(() {
          _recording = false;
        });
      }
      return;
    }
    try {
      final xfile = await _controller!.stopVideoRecording();
      setState(() {
        _recording = false;
      });
      await _navigateToEditor(File(xfile.path), MediaType.video);
    } catch (_) {
      setState(() {
        _recording = false;
      });
    }
  }

  Future<void> _onThumbnailTap(AssetEntity asset) async {
    final file = await asset.originFile;
    if (file == null) return;
    final type = asset.type == AssetType.video ? MediaType.video : MediaType.image;
    await _navigateToEditor(file, type);
  }

  Future<void> _navigateToEditor(File file, MediaType type) async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(
          initialMedia: MediaItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: type,
            filePath: file.path,
            createdAt: DateTime.now(),
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton({IconData? icon, Widget? child}) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: child ??
              Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
        ),
      ),
    );
  }

  Widget _buildMediaCarousel() {
    if (_recentAssets.isEmpty) {
      return const SizedBox(height: 80);
    }
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0),
            Colors.transparent,
          ],
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _recentAssets.length,
        itemBuilder: (context, index) {
          final asset = _recentAssets[index];
          return Padding(
            padding: EdgeInsets.only(right: index < _recentAssets.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => _onThumbnailTap(asset),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FutureBuilder<Uint8List?>(
                  future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done || snapshot.data == null) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[900],
                      );
                    }
                    return Image.memory(
                      snapshot.data!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCaptureControls() {
    return GestureDetector(
      onTap: _onCapturePressed,
      onLongPressStart: (_) => _onRecordStart(),
      onLongPressEnd: (_) => _onRecordEnd(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: _recording ? 32 : 68,
            height: _recording ? 32 : 68,
            decoration: BoxDecoration(
              color: _recording ? const Color(0xFFED4956) : Colors.white,
              borderRadius: BorderRadius.circular(_recording ? 8 : 34),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTabs() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () async {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CreateUploadScreen(),
                  ),
                );
              },
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  color: _mode == UploadMode.post ? Colors.white : Colors.white54,
                  fontWeight: _mode == UploadMode.post ? FontWeight.bold : FontWeight.w500,
                  letterSpacing: 1.2,
                ),
                child: const Text('POST'),
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () {
                setState(() {
                  _mode = UploadMode.story;
                });
              },
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  color: _mode == UploadMode.story ? Colors.white : Colors.white54,
                  fontWeight: _mode == UploadMode.story ? FontWeight.bold : FontWeight.w500,
                  letterSpacing: 1.2,
                ),
                child: const Text('STORY'),
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () {
                setState(() {
                  _mode = UploadMode.reel;
                });
              },
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  color: _mode == UploadMode.reel ? Colors.white : Colors.white54,
                  fontWeight: _mode == UploadMode.reel ? FontWeight.bold : FontWeight.w500,
                  letterSpacing: 1.2,
                ),
                child: const Text('REEL'),
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () {
                setState(() {
                  _mode = UploadMode.live;
                });
              },
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  color: _mode == UploadMode.live ? Colors.white : Colors.white54,
                  fontWeight: _mode == UploadMode.live ? FontWeight.bold : FontWeight.w500,
                  letterSpacing: 1.2,
                ),
                child: const Text('LIVE'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Fill screen completely like Instagram - crops slightly but no black bars
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.previewSize!.height,
          height: _controller!.value.previewSize!.width,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_permissionDenied) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white70, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Camera permission required',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await openAppSettings();
                },
                child: const Text(
                  'Open Settings',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildCameraPreview(),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.white),
                      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    ),
                    IconButton(
                      icon: Icon(
                        _flashMode == FlashMode.off ? LucideIcons.zapOff : LucideIcons.zap,
                        color: Colors.white,
                      ),
                      onPressed: _toggleFlash,
                    ),
                    Row(
                      children: [
                        if (_cameras.length > 1)
                          IconButton(
                            icon: _isSwitchingCamera
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(LucideIcons.refreshCw, color: Colors.white),
                            onPressed: _isSwitchingCamera ? null : _switchCamera,
                          ),
                        IconButton(
                          icon: const Icon(LucideIcons.settings, color: Colors.white),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 120,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToolButton(
                  child: const Text(
                    'Aa',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildToolButton(icon: LucideIcons.infinity),
                const SizedBox(height: 24),
                _buildToolButton(icon: LucideIcons.grid3x3),
                const SizedBox(height: 24),
                _buildToolButton(icon: LucideIcons.smile),
                const SizedBox(height: 24),
                _buildToolButton(icon: LucideIcons.chevronDown),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMediaCarousel(),
                  const SizedBox(height: 20),
                  _buildCaptureControls(),
                  const SizedBox(height: 20),
                  _buildModeTabs(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}