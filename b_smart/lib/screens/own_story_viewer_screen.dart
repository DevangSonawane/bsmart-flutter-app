import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/story_model.dart';
import 'package:image_picker/image_picker.dart';
import '../api/api.dart';
import '../api/api_exceptions.dart';

class OwnStoryViewerScreen extends StatefulWidget {
  final List<Story> stories;
  final String userName;
  const OwnStoryViewerScreen({super.key, required this.stories, required this.userName});

  @override
  State<OwnStoryViewerScreen> createState() => _OwnStoryViewerScreenState();
}

class _OwnStoryViewerScreenState extends State<OwnStoryViewerScreen> {
  late PageController _controller;
  int _index = 0;
  double _progress = 0.0;
  Timer? _timer;
  final List<Map<String, dynamic>> _viewers = List.generate(24, (i) => {'name': 'Viewer $i', 'time': DateTime.now().subtract(Duration(minutes: i))});
  double _dragStartX = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _progress = 0.0;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      setState(() => _progress += 0.01);
      if (_progress >= 1.0) {
        t.cancel();
        _next();
      }
    });
  }

  void _next() {
    if (_index < widget.stories.length - 1) {
      setState(() {
        _index++;
        _progress = 0.0;
      });
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      _start();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() {
        _index--;
        _progress = 0.0;
      });
      _controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      _start();
    } else {
      Navigator.pop(context);
    }
  }

  void _openViewers() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView.builder(
          itemCount: _viewers.length,
          itemBuilder: (_, i) {
            final v = _viewers[i];
            return ListTile(
              leading: CircleAvatar(child: Text(v['name'][0])),
              title: Text(v['name']),
              subtitle: Text('${(v['time'] as DateTime).hour}:${(v['time'] as DateTime).minute.toString().padLeft(2, '0')}'),
            );
          },
        ),
      ),
    );
  }

  void _openInsights() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scroll,
            children: [
              const Text('Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Total views: ${_viewers.length}'),
              const SizedBox(height: 12),
              const Text('Navigation summary:'),
              const Text('- Forwards: 12'),
              const Text('- Backs: 4'),
              const Text('- Exits: 2'),
              const SizedBox(height: 12),
              const Text('Viewers:'),
              ..._viewers.map((v) => ListTile(
                    leading: CircleAvatar(child: Text(v['name'][0])),
                    title: Text(v['name']),
                    subtitle: Text('Viewed at ${(v['time'] as DateTime).toLocal()}'),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _quickAddStory() async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Use Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: source, imageQuality: 85);
      if (xfile == null) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading...')));
      final bytes = await xfile.readAsBytes();
      final upload = await UploadApi().uploadFileBytes(bytes: bytes.toList(), filename: 'story.jpg');
      final url = (upload['fileUrl'] as String?) ??
          (upload['url'] as String?) ??
          (upload['file_url'] as String?) ??
          (upload['data'] is Map ? (upload['data']['url'] as String?) : null) ??
          '';
      if (url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed')));
        return;
      }
      final payload = {
        'media': {'url': url, 'type': 'image'},
        'transform': {'x': 0.5, 'y': 0.5, 'scale': 1, 'rotation': 0},
        'filter': {'name': 'none', 'intensity': 0},
        'texts': [],
        'mentions': [],
      };
      await StoriesApi().createFlexible([payload]);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posted to your story')));
    } catch (e) {
      final msg = e is ApiException ? e.message : 'Failed to add story';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onHorizontalDragStart: (details) {
          _dragStartX = details.globalPosition.dx;
        },
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 0 && _dragStartX < 24) {
            _quickAddStory();
            return;
          }
        },
        onTapDown: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.globalPosition.dx < w / 2) {
            _prev();
          } else {
            _next();
          }
        },
        onLongPressStart: (_) => _timer?.cancel(),
        onLongPressEnd: (_) => _start(),
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            Navigator.pop(context);
          } else {
            _openInsights();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(color: Colors.black),
            ),
            Center(
              child: Text(
                story.mediaType == StoryMediaType.image ? 'Image Story' : 'Video Story',
                style: const TextStyle(color: Colors.white54, fontSize: 24),
              ),
            ),
            Positioned(
              top: 40,
              left: 8,
              right: 8,
              child: Column(
                children: [
                  Row(
                    children: List.generate(
                      widget.stories.length,
                      (i) => Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(color: Colors.white.withAlpha(80), borderRadius: BorderRadius.circular(2)),
                          child: i == _index
                              ? FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _progress,
                                  child: Container(color: Colors.white),
                                )
                              : i < _index
                                  ? Container(color: Colors.white)
                                  : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(widget.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz, color: Colors.white)),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x, color: Colors.white)),
                    ],
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
                  TextButton(
                    onPressed: _openViewers,
                    child: Text('👁️ ${_viewers.length} viewers', style: const TextStyle(color: Colors.white)),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _quickAddStory,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    child: const Text('Add to Story'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
