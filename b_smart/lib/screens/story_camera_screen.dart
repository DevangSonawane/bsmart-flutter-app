import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../api/api.dart';
import '../models/media_model.dart';
import 'create_edit_preview_screen.dart';
import 'media_picker_screen.dart';
import 'story_editing_screen.dart';

class StoryCameraScreen extends StatefulWidget {
  const StoryCameraScreen({super.key});

  @override
  State<StoryCameraScreen> createState() => _StoryCameraScreenState();
}

class _StoryCameraScreenState extends State<StoryCameraScreen> {
  String _flashMode = 'off';
  bool _recording = false;
  double _recordProgress = 0.0;
  Timer? _recordTimer;
  String _mode = 'STORY';
  Offset? _focusPoint;
  double _exposure = 0.0;
  bool _showExposure = false;
  ImageProvider? _lastThumb;
  CameraController? _controller;
  bool _initializing = true;
  bool _permissionDenied = false;
  List<CameraDescription> _cameras = const [];
  bool _useFrontCamera = false;
  int? _countdownSeconds;
  bool _permanentlyDenied = false;


  @override
  void dispose() {
    _recordTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) {
        setState(() {
          _permissionDenied = true;
          _permanentlyDenied = camStatus.isPermanentlyDenied;
          _initializing = false;
        });
        return;
      }
      _cameras = await availableCameras();
      await _selectAndInitCamera(CameraLensDirection.back);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _permissionDenied = true;
      });
    }
  }

  Future<void> _selectAndInitCamera(CameraLensDirection desired) async {
    if (_cameras.isEmpty) _cameras = await availableCameras();
    final candidates = _cameras.where((c) => c.lensDirection == desired).toList();
    // Add other cameras as fallback if none match desired or init fails
    final others = _cameras.where((c) => c.lensDirection != desired).toList();
    for (final cam in [...candidates, ...others]) {
      final ok = await _tryInit(cam);
      if (ok) return;
    }
    // If all fail, mark denied to show UI
    if (mounted) {
      setState(() {
        _initializing = false;
        _permissionDenied = true;
      });
    }
  }

  Future<bool> _tryInit(CameraDescription cam) async {
    try {
      await _initControllerFor(cam, preferSilent: true);
      return true;
    } catch (_) {
      // final fallback inside _initControllerFor already tries different config
      return _controller != null && _controller!.value.isInitialized;
    }
  }

  Future<void> _initControllerFor(CameraDescription cam, {bool preferSilent = false}) async {
    try {
      final controller = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: !preferSilent,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      if (!mounted) return;
      setState(() {
        _controller?.dispose();
        _controller = controller;
        _initializing = false;
      });
    } catch (_) {
      // Fallback without audio (some devices deny mic or fail on front camera)
      try {
        final controller = CameraController(
          cam,
          ResolutionPreset.low,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        await controller.initialize();
        await controller.setFlashMode(FlashMode.off);
        if (!mounted) return;
        setState(() {
          _controller?.dispose();
          _controller = controller;
          _initializing = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _permissionDenied = true;
        });
      }
    }
  }

  void _toggleFlash() {
    if (_flashMode == 'off') {
      setState(() => _flashMode = 'on');
    } else if (_flashMode == 'on') {
      setState(() => _flashMode = 'auto');
    } else {
      setState(() => _flashMode = 'off');
    }
    _applyFlashMode();
  }

  void _applyFlashMode() {
    if (_controller == null) return;
    final mode = _flashMode == 'off'
        ? FlashMode.off
        : _flashMode == 'on'
            ? FlashMode.torch
            : FlashMode.auto;
    _controller!.setFlashMode(mode).catchError((_) {});
  }

  Future<void> _flipCamera() async {
    try {
      await _selectAndInitCamera(_useFrontCamera ? CameraLensDirection.back : CameraLensDirection.front);
      setState(() {
        _useFrontCamera = !_useFrontCamera;
      });
    } catch (_) {
      // ignore
    }
  }

  void _startRecording() {
    if (_recording) return;
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_countdownSeconds != null && _countdownSeconds! > 0) {
      int remaining = _countdownSeconds!;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => StatefulBuilder(
          builder: (ctx, setS) => Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
              child: Text('$remaining', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      );
      Timer.periodic(const Duration(seconds: 1), (t) {
        remaining--;
        if (remaining <= 0) {
          t.cancel();
          Navigator.of(context, rootNavigator: true).pop();
          _beginRecording();
        } else {
          // Dialog content updates implicitly by rebuilding; keep simple for now
        }
      });
    } else {
      _beginRecording();
    }
  }

  void _beginRecording() {
    setState(() {
      _recording = true;
      _recordProgress = 0.0;
    });
    final maxSeconds = _mode == 'REELS' ? 90 : 15;
    final tick = 1000 * maxSeconds;
    _recordTimer?.cancel();
    _controller!.startVideoRecording().catchError((_) {});
    _recordTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      setState(() {
        _recordProgress += 1.0 / (tick / 50.0);
      });
      if (_recordProgress >= 1.0) {
        t.cancel();
        _stopRecording();
      }
    });
  }

  void _stopRecording() {
    _recordTimer?.cancel();
    if (_controller != null && _controller!.value.isRecordingVideo) {
      _controller!.stopVideoRecording().then((xfile) async {
        try {
          if (_mode == 'POST') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CreateEditPreviewScreen(
                  media: MediaItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: MediaType.video,
                    filePath: xfile.path,
                    createdAt: DateTime.now(),
                    duration: const Duration(seconds: 15),
                  ),
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading video...')));
            final bytes = await File(xfile.path).readAsBytes();
            final upload = await UploadApi().uploadFileBytes(bytes: bytes, filename: 'story.mp4');
            final url = (upload['fileUrl'] as String?) ??
                (upload['url'] as String?) ??
                (upload['file_url'] as String?) ??
                (upload['data'] is Map ? (upload['data']['url'] as String?) : null) ??
                '';
            if (url.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed')));
            } else {
              await StoriesApi().create([
                {
                  'media': {'url': url, 'type': 'video'},
                  'transform': {'x': 0.5, 'y': 0.5, 'scale': 1, 'rotation': 0},
                  'filter': {'name': 'none', 'intensity': 0},
                  'texts': [],
                  'mentions': [],
                }
              ]);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posted video to your story')));
            }
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to post video')));
          }
        }
      }).catchError((_) {});
    }
    setState(() {
      _recording = false;
      _recordProgress = 0.0;
    });
  }

  Future<void> _capturePhoto() async {
    try {
      if (_controller == null || !_controller!.value.isInitialized) return;
      if (_controller!.value.isTakingPicture || _controller!.value.isRecordingVideo) return;
      if (_focusPoint != null) {
        final size = MediaQuery.of(context).size;
        final nx = _focusPoint!.dx / size.width;
        final ny = _focusPoint!.dy / size.height;
        await _controller!.setFocusPoint(Offset(nx, ny)).catchError((_) {});
      }
      await Future.delayed(const Duration(milliseconds: 120));
      XFile xfile;
      try {
        xfile = await _controller!.takePicture();
      } catch (_) {
        await _selectAndInitCamera(_useFrontCamera ? CameraLensDirection.front : CameraLensDirection.back);
        await Future.delayed(const Duration(milliseconds: 300));
        xfile = await _controller!.takePicture();
      }
      final imgProvider = FileImage(File(xfile.path));
      setState(() => _lastThumb = imgProvider);
      if (_mode == 'POST') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CreateEditPreviewScreen(
              media: MediaItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                type: MediaType.image,
                filePath: xfile.path,
                createdAt: DateTime.now(),
              ),
            ),
          ),
        );
      } else {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryEditingScreen(media: [imgProvider])));
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to capture')));
    }
  }

  void _openPicker() async {
    final selected = await Navigator.of(context).push<List<ImageProvider>>(
      MaterialPageRoute(builder: (_) => const MediaPickerScreen()),
    );
    if (selected != null && selected.isNotEmpty) {
      setState(() {
        _lastThumb = selected.last;
      });
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StoryEditingScreen(media: selected)),
      );
    }
  }

  void _openEffects() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip('Trending'),
                  _chip('New'),
                  _chip('Saved'),
                  _chip('Browse'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 10,
                itemBuilder: (_, i) => Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text('Effect ${i + 1}')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_initializing)
              const Center(child: CircularProgressIndicator(color: Colors.white))
            else if (_permissionDenied)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off, color: Colors.white70, size: 48),
                    const SizedBox(height: 12),
                    const Text('Camera permission required', style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            if (_permanentlyDenied) {
                              await openAppSettings();
                            } else {
                              setState(() {
                                _initializing = true;
                              });
                              await _initCamera();
                            }
                          },
                          child: Text(_permanentlyDenied ? 'Open Settings' : 'Grant Permission'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () async {
                            await openAppSettings();
                          },
                          child: const Text('Open Settings'),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              GestureDetector(
              onTapDown: (d) {
                setState(() {
                  _focusPoint = d.localPosition;
                  _showExposure = true;
                });
              },
              onPanUpdate: (d) {
                if (_showExposure) {
                  setState(() {
                    _exposure = (_exposure - d.delta.dy / 200).clamp(-1.0, 1.0);
                  });
                }
              },
              onPanEnd: (_) {
                if (_showExposure) {
                  setState(() {
                    _showExposure = false;
                  });
                }
              },
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: _controller != null && _controller!.value.isInitialized
                      ? CameraPreview(_controller!)
                      : Container(color: Colors.black),
                ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(LucideIcons.x, color: Colors.white)),
                    IconButton(onPressed: _toggleFlash, icon: Icon(_flashMode == 'off' ? LucideIcons.zapOff : _flashMode == 'on' ? LucideIcons.zap : LucideIcons.zap, color: Colors.white)),
                    const Spacer(),
                    IconButton(onPressed: _openEffects, icon: const Icon(LucideIcons.sparkles, color: Colors.white)),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 56,
              left: 0,
              right: 0,
              child: Center(
                child: IconButton(
                  onPressed: _flipCamera,
                  icon: const Icon(LucideIcons.refreshCw, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              bottom: 110,
              left: 24,
              right: 24,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() {
                      if (_countdownSeconds == null) {
                        _countdownSeconds = 3;
                      } else if (_countdownSeconds == 3) {
                        _countdownSeconds = 10;
                      } else {
                        _countdownSeconds = null;
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.timer, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(_countdownSeconds == null ? 'Off' : '${_countdownSeconds}s', style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _mode = 'STORY'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: _mode == 'STORY' ? Colors.white24 : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                            child: const Text('Story', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _mode = 'REELS'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: _mode == 'REELS' ? Colors.white24 : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                            child: const Text('Reels', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _mode = 'POST'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: _mode == 'POST' ? Colors.white24 : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                            child: const Text('Post', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_focusPoint != null)
              Positioned(
                left: _focusPoint!.dx - 30,
                top: _focusPoint!.dy - 30,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.yellow, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            if (_recording)
              Positioned(
                bottom: 132,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 80),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: _recordProgress,
                      color: Colors.red,
                      backgroundColor: Colors.white24,
                      minHeight: 4,
                    ),
                  ),
                ),
              ),
            if (_recording)
              Positioned(
                top: 16,
                left: 16,
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(
                      '${((_recordProgress) * (_mode == 'REELS' ? 90 : 15)).clamp(0, _mode == 'REELS' ? 90 : 15).toStringAsFixed(0)}s',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _openPicker,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: _lastThumb != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image(image: _lastThumb!, fit: BoxFit.cover),
                            )
                          : const Icon(LucideIcons.image, color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _capturePhoto,
                    onLongPressStart: (_) => (_mode == 'STORY' || _mode == 'REELS' || _mode == 'POST') ? _startRecording() : null,
                    onLongPressEnd: (_) {
                      if (_recording) _stopRecording();
                    },
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Container(
                          width: _recording ? 32 : 60,
                          height: _recording ? 32 : 60,
                          decoration: BoxDecoration(
                            color: _recording ? Colors.red : Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(onPressed: _openEffects, icon: const Icon(LucideIcons.sparkles, color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
