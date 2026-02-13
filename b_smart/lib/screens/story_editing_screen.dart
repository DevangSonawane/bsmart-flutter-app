import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../api/api.dart';
import '../config/api_config.dart';

class StoryEditingScreen extends StatefulWidget {
  final List<ImageProvider> media;
  const StoryEditingScreen({super.key, required this.media});

  @override
  State<StoryEditingScreen> createState() => _StoryEditingScreenState();
}

class _StoryEditingScreenState extends State<StoryEditingScreen> {
  int _currentIndex = 0;
  final List<_OverlayElement> _elements = [];
  bool _showTrash = false;
  _OverlayElement? _activeElement;
  String _textStyle = 'Classic';
  Color _currentColor = Colors.white;
  double _brushSize = 8.0;
  final List<_Stroke> _strokes = [];
  final List<_Stroke> _redo = [];
  bool _drawingMode = false;
  bool _textMode = false;
  bool _stickerMode = false;
  final GlobalKey _repaintKey = GlobalKey();
  bool _imageReady = false;
  bool _didPrecache = false;
  bool _imageError = false;

  @override
  void initState() {
    super.initState();
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrecache) {
      _didPrecache = true;
      _precacheCurrent();
    }
  }

  void _precacheCurrent() async {
    final img = widget.media[_currentIndex];
    try {
      await precacheImage(img, context, size: const Size(1080, 1920));
      if (mounted) {
        setState(() {
          _imageReady = true;
          _imageError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _imageReady = false;
          _imageError = true;
        });
      }
    }
  }

  void _addText() {
    setState(() {
      _textMode = true;
      _elements.add(_OverlayElement.text('Tap to edit', style: _textStyle, color: _currentColor));
    });
  }

  void _addSticker(String label) {
    setState(() {
      _elements.add(_OverlayElement.sticker(label));
      _stickerMode = false;
    });
  }

  void _startStroke(Offset pos) {
    if (!_drawingMode) return;
    setState(() {
      _strokes.add(_Stroke(color: _currentColor, size: _brushSize, points: [pos]));
      _redo.clear();
    });
  }

  void _appendStroke(Offset pos) {
    if (!_drawingMode || _strokes.isEmpty) return;
    setState(() {
      _strokes.last.points.add(pos);
    });
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() {
      _redo.add(_strokes.removeLast());
    });
  }

  void _redoStroke() {
    if (_redo.isEmpty) return;
    setState(() {
      _strokes.add(_redo.removeLast());
    });
  }

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to camera roll')));
  }

  void _crop() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Crop/Rotate coming soon')));
  }

  void _sendTo() async {
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _RecipientsSheet(),
    );
    if (selected != null && selected.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent to ${selected.length} recipients')));
    }
  }

  Future<void> _postYourStory() async {
    await _postToApi();
  }

  Future<void> _postCloseFriends() async {
    await _postToApi();
  }

  Future<void> _postToApi() async {
    try {
      if (!_imageReady) {
        _showError('Image is still loading');
        return;
      }
      if (_imageError) {
        _showError('Image failed to load. Please try again.');
        return;
      }
      if (!await _checkConnectivity()) {
        _showError('No internet connection. Please check your network.');
        return;
      }
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        _showError('Unable to capture story');
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                SizedBox(width: 16),
                Text('Posting story...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _showError('Failed to capture image');
        return;
      }
      final bytes = byteData.buffer.asUint8List();
      final upload = await _uploadWithRetry(bytes.toList(), 'story_${DateTime.now().millisecondsSinceEpoch}.png');
      String? url;
      if (upload is Map) {
        url = upload['fileUrl'] as String? ?? upload['url'] as String? ?? upload['file_url'] as String?;
        if (url == null && upload['data'] is Map) {
          final data = upload['data'] as Map;
          url = data['url'] as String? ?? data['fileUrl'] as String? ?? data['file_url'] as String?;
        }
      }
      if (url == null || url.isEmpty) {
        _showError('Upload failed: No URL returned');
        return;
      }
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        final baseUri = Uri.parse(ApiConfig.baseUrl);
        final origin = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
        if (!url.startsWith('/')) {
          url = '/$url';
        }
        url = '$origin$url';
      }
      final screenSize = MediaQuery.of(context).size;
      final payload = {
        'media': {
          'url': url,
          'type': 'image',
          'width': image.width,
          'height': image.height,
        },
        'transform': {'x': 0.5, 'y': 0.5, 'scale': 1.0, 'rotation': 0.0},
        'filter': {'name': 'none', 'intensity': 0},
        'texts': _elements
            .where((e) => e.type == _ElementType.text)
            .map((e) => {
                  'content': e.text ?? '',
                  'fontSize': 24,
                  'fontFamily': (e.style ?? 'classic').toLowerCase(),
                  'color': '#${(e.color ?? Colors.white).value.toRadixString(16).substring(2, 8).toUpperCase()}',
                  'align': 'center',
                  'x': e.position.dx / screenSize.width,
                  'y': e.position.dy / screenSize.height,
                })
            .toList(),
        'mentions': [],
      };
      final response = await StoriesApi().create([payload]).timeout(const Duration(seconds: 15));
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posted to story ✓')));
        Navigator.pop(context, true);
      }
    } on SocketException {
      _showError('No internet connection');
    } on TimeoutException {
      _showError('Request timed out. Please try again.');
    } catch (e) {
      String errorMessage = 'Failed to post story';
      if (e is ApiException) {
        errorMessage = e.message;
      }
      _showError(errorMessage);
    }
  }

  Future<Map<String, dynamic>> _uploadWithRetry(List<int> bytes, String filename, {int maxRetries = 3}) async {
    int attempts = 0;
    Exception? lastException;
    while (attempts < maxRetries) {
      try {
        attempts++;
        final upload = await UploadApi().uploadFileBytes(bytes: bytes, filename: filename).timeout(const Duration(seconds: 20));
        return upload;
      } catch (e) {
        lastException = e as Exception;
        if (attempts < maxRetries) {
          await Future.delayed(Duration(seconds: attempts * 2));
        }
      }
    }
    throw lastException ?? Exception('Upload failed after $maxRetries attempts');
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _postToApi,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentImage = widget.media[_currentIndex];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Edit Story'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'save', child: Text('Save to camera roll')),
              PopupMenuItem(value: 'settings', child: Text('Story settings')),
              PopupMenuItem(value: 'archive', child: Text('Archive')),
            ],
            onSelected: (v) {
              if (v == 'save') _save();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  onPanStart: (d) => _startStroke(d.localPosition),
                  onPanUpdate: (d) => _appendStroke(d.localPosition),
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: Stack(
                          children: [
                            RepaintBoundary(
                              key: _repaintKey,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: _imageError
                                        ? Container(
                                            color: Colors.black,
                                            child: const Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.error_outline, color: Colors.white, size: 48),
                                                  SizedBox(height: 16),
                                                  Text('Failed to load image', style: TextStyle(color: Colors.white)),
                                                ],
                                              ),
                                            ),
                                          )
                                        : Image(
                                            image: ResizeImage(currentImage, width: 1080, height: 1920),
                                            fit: BoxFit.cover,
                                            gaplessPlayback: true,
                                            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                              if (wasSynchronouslyLoaded || frame != null) return child;
                                              return Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  Container(color: Colors.black),
                                                  const Center(child: CircularProgressIndicator(color: Colors.white)),
                                                ],
                                              );
                                            },
                                          ),
                                  ),
                                  CustomPaint(painter: _DrawingPainter(_strokes)),
                                  ..._elements.map((e) => _ElementWidget(
                                        element: e,
                                        onChanged: (updated) {
                                          setState(() {
                                            final idx = _elements.indexOf(e);
                                            _elements[idx] = updated;
                                          });
                                        },
                                        onStartDrag: () => setState(() => _showTrash = true),
                                        onEndDrag: (pos) {
                                          setState(() => _showTrash = false);
                                          if (pos.dy > MediaQuery.of(context).size.height - 140) {
                                            setState(() {
                                              _elements.remove(e);
                                            });
                                          }
                                        },
                                        onTap: () {
                                          if (e.type == _ElementType.text) {
                                            _editText(e);
                                          }
                                        },
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 80,
                  bottom: 80,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          _ToolButton(icon: LucideIcons.type, label: 'Aa', onTap: _addText),
                          const SizedBox(height: 12),
                          _ToolButton(
                            icon: LucideIcons.pencil,
                            label: 'Pen',
                            onTap: () => setState(() {
                              _drawingMode = true;
                              _textMode = false;
                              _stickerMode = false;
                            }),
                          ),
                          const SizedBox(height: 12),
                          _ToolButton(
                            icon: LucideIcons.sticker,
                            label: 'Sticker',
                            onTap: () => setState(() {
                              _stickerMode = true;
                              _drawingMode = false;
                              _textMode = false;
                            }),
                          ),
                          const SizedBox(height: 12),
                          _ToolButton(icon: LucideIcons.download, label: 'Save', onTap: _save),
                          const SizedBox(height: 12),
                          _ToolButton(icon: LucideIcons.crop, label: 'Crop', onTap: _crop),
                        ],
                      ),
                      if (_drawingMode)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(onPressed: _undo, icon: const Icon(Icons.undo, color: Colors.white)),
                                  IconButton(onPressed: _redoStroke, icon: const Icon(Icons.redo, color: Colors.white)),
                                ],
                              ),
                              Slider(
                                value: _brushSize,
                                min: 2,
                                max: 24,
                                divisions: 22,
                                onChanged: (v) => setState(() => _brushSize = v),
                              ),
                              SizedBox(
                                height: 24,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    for (final c in [Colors.white, Colors.black, Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple])
                                      GestureDetector(
                                        onTap: () => setState(() => _currentColor = c),
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          margin: const EdgeInsets.symmetric(horizontal: 4),
                                          decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (_stickerMode)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 120,
                    child: Container(
                      height: 160,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black.withAlpha(140)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Search GIFs', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 100,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (final s in ['🔥', '😊', '🎉', '⭐', '💥', '💖', '😂'])
                                  GestureDetector(
                                    onTap: () => _addSticker(s),
                                    child: Container(
                                      width: 80,
                                      margin: const EdgeInsets.symmetric(horizontal: 6),
                                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
                                      child: Center(child: Text(s, style: const TextStyle(fontSize: 28))),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_showTrash)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 24,
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(color: Colors.redAccent.withAlpha(160), shape: BoxShape.circle),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _BottomBar(
            media: widget.media,
            currentIndex: _currentIndex,
            onSelect: (i) => setState(() => _currentIndex = i),
            onDelete: (i) {
              setState(() {
                widget.media.removeAt(i);
                if (_currentIndex >= widget.media.length) _currentIndex = math.max(0, widget.media.length - 1);
              });
            },
            onYourStory: _postYourStory,
            onCloseFriends: _postCloseFriends,
            onSendTo: _sendTo,
          ),
        ],
      ),
    );
  }

  Future<void> _editText(_OverlayElement e) async {
    final controller = TextEditingController(text: e.text);
    String style = e.style ?? 'Classic';
    Color color = e.color ?? Colors.white;
    final updated = await showModalBottomSheet<_OverlayElement>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Enter text'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final s in ['Classic', 'Modern', 'Neon', 'Typewriter', 'Strong'])
                      GestureDetector(
                        onTap: () => style = s,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
                          child: Text(s),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 24,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final c in [Colors.white, Colors.black, Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple])
                      GestureDetector(
                        onTap: () => color = c,
                        child: Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.black12)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, e.copyWith(text: controller.text, style: style, color: color)),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (updated != null) {
      setState(() {
        final idx = _elements.indexOf(e);
        _elements[idx] = updated;
      });
    }
  }
}

class _BottomBar extends StatelessWidget {
  final List<ImageProvider> media;
  final int currentIndex;
  final void Function(int index) onSelect;
  final void Function(int index) onDelete;
  final VoidCallback onYourStory;
  final VoidCallback onCloseFriends;
  final VoidCallback onSendTo;

  const _BottomBar({
    required this.media,
    required this.currentIndex,
    required this.onSelect,
    required this.onDelete,
    required this.onYourStory,
    required this.onCloseFriends,
    required this.onSendTo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (media.length > 1)
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: media.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 72,
                    margin: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () => onSelect(index),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image(image: media[index], fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -8,
                          top: -8,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => onDelete(index),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onYourStory,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  icon: const CircleAvatar(radius: 10, backgroundColor: Colors.white),
                  label: const Text('Your Story'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onCloseFriends,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white),
                  icon: const Icon(Icons.star),
                  label: const Text('Close Friends'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onSendTo,
                  child: const Text('Send To >'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ToolButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

enum _ElementType { text, sticker }

class _OverlayElement {
  final _ElementType type;
  final String? text;
  final String? style;
  final Color? color;
  final String? sticker;
  final Offset position;
  final double scale;
  final double rotation;
  _OverlayElement._({
    required this.type,
    this.text,
    this.style,
    this.color,
    this.sticker,
    required this.position,
    required this.scale,
    required this.rotation,
  });
  factory _OverlayElement.text(String text, {String style = 'Classic', Color color = Colors.white}) {
    return _OverlayElement._(type: _ElementType.text, text: text, style: style, color: color, position: const Offset(100, 100), scale: 1.0, rotation: 0.0);
  }
  factory _OverlayElement.sticker(String label) {
    return _OverlayElement._(type: _ElementType.sticker, sticker: label, position: const Offset(120, 120), scale: 1.0, rotation: 0.0);
  }
  _OverlayElement copyWith({String? text, String? style, Color? color, Offset? position, double? scale, double? rotation}) {
    return _OverlayElement._(
      type: type,
      text: text ?? this.text,
      style: style ?? this.style,
      color: color ?? this.color,
      sticker: sticker,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }
}

class _ElementWidget extends StatefulWidget {
  final _OverlayElement element;
  final void Function(_OverlayElement updated) onChanged;
  final VoidCallback onStartDrag;
  final void Function(Offset endPosition) onEndDrag;
  final VoidCallback onTap;
  const _ElementWidget({super.key, required this.element, required this.onChanged, required this.onStartDrag, required this.onEndDrag, required this.onTap});
  @override
  State<_ElementWidget> createState() => _ElementWidgetState();
}

class _ElementWidgetState extends State<_ElementWidget> {
  Offset _initialFocal = Offset.zero;
  double _initialScale = 1.0;
  double _initialRotation = 0.0;
  Offset _lastGlobalPos = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final e = widget.element;
    return Positioned(
      left: e.position.dx,
      top: e.position.dy,
      child: GestureDetector(
        onTap: widget.onTap,
        onScaleStart: (d) {
          widget.onStartDrag();
          _initialFocal = d.focalPoint;
          _initialScale = e.scale;
          _initialRotation = e.rotation;
          _lastGlobalPos = d.focalPoint;
        },
        onScaleUpdate: (d) {
          _lastGlobalPos = d.focalPoint;
          final isSingleFinger = d.pointerCount == 1;
          if (isSingleFinger && d.rotation.abs() < 0.001 && (d.scale - 1.0).abs() < 0.001) {
            final delta = d.focalPoint - _initialFocal;
            final updated = e.copyWith(position: e.position + delta);
            widget.onChanged(updated);
            _initialFocal = d.focalPoint;
          } else {
            final updated = e.copyWith(scale: _initialScale * d.scale, rotation: _initialRotation + d.rotation);
            widget.onChanged(updated);
          }
        },
        onScaleEnd: (d) => widget.onEndDrag(_lastGlobalPos),
        child: Transform.rotate(
          angle: e.rotation,
          child: Transform.scale(
            scale: e.scale,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: e.type == _ElementType.text ? Colors.black26 : Colors.transparent, borderRadius: BorderRadius.circular(8)),
              child: e.type == _ElementType.text
                  ? Text(e.text ?? '', style: TextStyle(color: e.color ?? Colors.white, fontSize: 24, fontWeight: FontWeight.w600))
                  : Text(e.sticker ?? '', style: const TextStyle(fontSize: 32)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stroke {
  final Color color;
  final double size;
  final List<Offset> points;
  _Stroke({required this.color, required this.size, required this.points});
}

class _DrawingPainter extends CustomPainter {
  final List<_Stroke> strokes;
  _DrawingPainter(this.strokes);
  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.size
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < s.points.length - 1; i++) {
        canvas.drawLine(s.points[i], s.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => oldDelegate.strokes != strokes;
}

class _RecipientsSheet extends StatefulWidget {
  const _RecipientsSheet();
  @override
  State<_RecipientsSheet> createState() => _RecipientsSheetState();
}

class _RecipientsSheetState extends State<_RecipientsSheet> {
  final List<Map<String, dynamic>> _followers = List.generate(20, (i) => {'id': 'u$i', 'name': 'User $i'});
  final Set<String> _selected = {};
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () {}, child: const Text('Close Friends')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () {}, child: const Text('Groups')),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _followers.length,
                itemBuilder: (_, i) {
                  final f = _followers[i];
                  final id = f['id'] as String;
                  final selected = _selected.contains(id);
                  return CheckboxListTile(
                    title: Text(f['name'] as String),
                    value: selected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(id);
                        } else {
                          _selected.remove(id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected.toList()),
                child: const Text('Send'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
