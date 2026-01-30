import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:b_smart/core/lucide_local.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as p;
import '../services/supabase_service.dart';

/// Single media item in the create-post flow (select → crop → edit → share).
class _CreatePostMediaItem {
  String sourcePath;
  String? croppedPath; // after crop step (images only)
  bool isVideo;
  double aspect;
  String filter;
  Map<String, int> adjustments;

  _CreatePostMediaItem({
    required this.sourcePath,
    this.croppedPath,
    required this.isVideo,
    this.aspect = 1.0,
    this.filter = 'Original',
    Map<String, int>? adjustments,
  }) : adjustments = adjustments ?? {
    'brightness': 0, 'contrast': 0, 'saturate': 0,
    'sepia': 0, 'opacity': 0, 'vignette': 0,
  };

  String get displayPath => (isVideo ? sourcePath : (croppedPath ?? sourcePath));
}

/// Tag on the post (x, y as percentage; user map from Supabase).
class _PostTag {
  final String id;
  final double x, y;
  final Map<String, dynamic> user;

  _PostTag({required this.id, required this.x, required this.y, required this.user});
}

// Filter names matching React CreatePostModal
const _filterNames = [
  'Original', 'Clarendon', 'Gingham', 'Moon', 'Lark', 'Reyes', 'Juno',
  'Slumber', 'Crema', 'Ludwig', 'Aden', 'Perpetua',
];

// Adjustments matching React (property name, label, min, max)
const _adjustments = [
  ('brightness', 'Brightness', -100, 100),
  ('contrast', 'Contrast', -100, 100),
  ('saturate', 'Saturation', -100, 100),
  ('sepia', 'Temperature', -100, 100),
  ('opacity', 'Fade', 0, 100),
  ('vignette', 'Vignette', 0, 100),
];

const _popularEmojis = ['😂', '😮', '😍', '😢', '👏', '🔥', '🎉', '💯', '❤️', '🤣', '🥰', '😘', '😭', '😊'];

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final ImagePicker _picker = ImagePicker();
  final SupabaseService _svc = SupabaseService();
  final TextEditingController _captionCtl = TextEditingController();

  String _step = 'select'; // select | crop | edit | share
  List<_CreatePostMediaItem> _media = [];
  int _currentIndex = 0;

  // Share step
  String _location = '';
  bool _hideLikes = false;
  bool _turnOffCommenting = false;
  bool _advancedOpen = false;
  bool _showEmojiPicker = false;
  final List<_PostTag> _tags = [];
  bool _showTagSearch = false;
  double _tagX = 0, _tagY = 0;
  List<Map<String, dynamic>> _tagSearchResults = [];
  bool _isSearchingUsers = false;
  bool _isSubmitting = false;

  // Edit step tab
  String _editTab = 'filters';

  @override
  void dispose() {
    _captionCtl.dispose();
    super.dispose();
  }

  _CreatePostMediaItem? get _currentMedia =>
      _media.isEmpty ? null : _media[_currentIndex.clamp(0, _media.length - 1)];

  Future<void> _pickMedia() async {
    final files = await _picker.pickMultipleMedia();
    if (files.isEmpty) return;
    final newItems = <_CreatePostMediaItem>[];
    for (final x in files) {
      final path = x.path;
      final isVideo = path.toLowerCase().contains('.mp4') ||
          path.toLowerCase().contains('.mov') ||
          (x.mimeType?.startsWith('video/') ?? false);
      newItems.add(_CreatePostMediaItem(sourcePath: path, isVideo: isVideo));
    }
    setState(() {
      if (_step == 'select') {
        _media = newItems;
        _currentIndex = 0;
        _step = 'crop';
      } else {
        _media.addAll(newItems);
        _currentIndex = _media.length - 1;
      }
    });
  }

  Future<void> _cropCurrent() async {
    final item = _currentMedia;
    if (item == null || item.isVideo) {
      setState(() {
        _advanceFromCrop((nextIndex, nextStep) {
          _currentIndex = nextIndex;
          if (nextStep != null) _step = nextStep;
        });
      });
      return;
    }
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: item.sourcePath,
        aspectRatio: item.aspect > 0 && item.aspect < 0.9
            ? const CropAspectRatio(ratioX: 4, ratioY: 5)
            : item.aspect >= 1.7
                ? const CropAspectRatio(ratioX: 16, ratioY: 9)
                : item.aspect == 1.0
                    ? const CropAspectRatio(ratioX: 1, ratioY: 1)
                    : null,
        uiSettings: [
          AndroidUiSettings(toolbarTitle: 'Crop', lockAspectRatio: item.aspect > 0 && item.aspect != 4/5 && item.aspect != 16/9),
          IOSUiSettings(title: 'Crop'),
        ],
      );
      if (cropped != null && mounted) {
        setState(() {
          _media[_currentIndex].croppedPath = cropped.path;
          _advanceFromCrop((nextIndex, nextStep) {
            _currentIndex = nextIndex;
            if (nextStep != null) _step = nextStep;
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _advanceFromCrop((nextIndex, nextStep) {
            _currentIndex = nextIndex;
            if (nextStep != null) _step = nextStep;
          });
        });
      }
    }
  }

  /// Returns (nextIndex, nextStep). If nextStep is non-null, transition to that step with index 0.
  void _advanceFromCrop(void Function(int index, String? step) apply) {
    if (_currentIndex < _media.length - 1) {
      apply(_currentIndex + 1, null);
    } else {
      apply(0, 'edit');
    }
  }

  void _back() {
    if (_step == 'share') {
      setState(() => _step = 'edit');
    } else if (_step == 'edit') {
      setState(() => _step = 'crop');
    } else if (_step == 'crop') {
      setState(() {
        _step = 'select';
        _media = [];
        _currentIndex = 0;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  void _next() {
    if (_step == 'crop') {
      _cropCurrent();
    } else if (_step == 'edit') {
      setState(() => _step = 'share');
    } else if (_step == 'share') {
      _submit();
    }
  }

  void _setAspect(double a) {
    final item = _currentMedia;
    if (item != null) setState(() => item.aspect = a);
  }

  void _applyFilter(String name) {
    final item = _currentMedia;
    if (item != null) setState(() => item.filter = name);
  }

  void _updateAdjustment(String key, int value) {
    final item = _currentMedia;
    if (item != null) setState(() => item.adjustments[key] = value);
  }

  void _onImageTapForTag(TapDownDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final local = box.globalToLocal(details.globalPosition);
    setState(() {
      _tagX = (local.dx / size.width).clamp(0.0, 1.0) * 100;
      _tagY = (local.dy / size.height).clamp(0.0, 1.0) * 100;
      _showTagSearch = true;
      _searchTagUsers('');
    });
  }

  Future<void> _searchTagUsers(String query) async {
    setState(() => _isSearchingUsers = true);
    final list = await _svc.searchUsersByUsername(query, limit: 20);
    if (mounted) setState(() {
      _tagSearchResults = list;
      _isSearchingUsers = false;
    });
  }

  void _addTag(Map<String, dynamic> user) {
    setState(() {
      _tags.add(_PostTag(
        id: '${DateTime.now().millisecondsSinceEpoch}_${user['id']}',
        x: _tagX,
        y: _tagY,
        user: user,
      ));
      _showTagSearch = false;
    });
  }

  void _removeTag(String id) {
    setState(() => _tags.removeWhere((t) => t.id == id));
  }

  Future<void> _submit() async {
    if (_isSubmitting || _media.isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to share.')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final processedMedia = <Map<String, dynamic>>[];
      for (final item in _media) {
        final path = item.isVideo ? item.sourcePath : (item.croppedPath ?? item.sourcePath);
        final file = File(path);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        final ext = p.extension(path).replaceFirst('.', '');
        final filename = '${user.id}/${DateTime.now().millisecondsSinceEpoch}_${item.hashCode % 100000}.$ext';
        final uploaded = await _svc.uploadFile('post_images', filename, Uint8List.fromList(bytes));
        if (uploaded == null) throw Exception('Upload failed');
        processedMedia.add({
          'image': uploaded,
          'ratio': item.aspect,
          'zoom': 1.0,
          'filter': item.filter,
          'adjustments': item.adjustments,
        });
      }
      if (processedMedia.isEmpty) throw Exception('No media to upload');

      final tagsPayload = _tags.map((t) => {
        'x': t.x,
        'y': t.y,
        'user': t.user,
      }).toList();

      final postData = {
        'user_id': user.id,
        'caption': _captionCtl.text.trim(),
        'location': _location.isEmpty ? null : _location,
        'media': processedMedia,
        'tags': tagsPayload,
        'hide_likes_count': _hideLikes,
        'turn_off_commenting': _turnOffCommenting,
      };
      final ok = await _svc.createPost(postData);
      if (ok && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post shared successfully!')));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create post.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelect = _step == 'select';
    return Scaffold(
      backgroundColor: isSelect ? Colors.white : const Color(0xFFF0F0F0),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft.localLucide, color: Colors.black87),
          onPressed: _back,
        ),
        title: Text(
          isSelect ? 'Create new post' : _step == 'crop' ? 'Crop' : _step == 'edit' ? 'Edit' : 'Create new post',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
        ),
        centerTitle: true,
        actions: [
          if (!isSelect)
            TextButton(
              onPressed: (_step == 'share' && _isSubmitting) ? null : _next,
              child: Text(
                _step == 'share' ? (_isSubmitting ? 'Sharing...' : 'Share') : 'Next',
                style: TextStyle(
                  color: (_step == 'share' && _isSubmitting) ? Colors.grey : const Color(0xFF0095F6),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: isSelect ? _buildSelect() : _step == 'crop' ? _buildCrop() : _step == 'edit' ? _buildEdit() : _buildShare(),
      ),
    );
  }

  Widget _buildSelect() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.image.localLucide, size: 56, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Icon(LucideIcons.video.localLucide, size: 56, color: Colors.grey[700]),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Drag photos and videos here',
              style: TextStyle(fontSize: 20, color: Colors.grey[800], fontWeight: FontWeight.w300),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _pickMedia,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0095F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Select From Computer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrop() {
    final item = _currentMedia;
    if (item == null) return const SizedBox();
    return Stack(
      children: [
        Center(
          child: item.isVideo
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.video.localLucide, size: 80, color: Colors.grey[600]),
                    const SizedBox(height: 8),
                    Text('Video (no crop)', style: TextStyle(color: Colors.grey[600])),
                  ],
                )
              : Image.file(File(item.sourcePath), fit: BoxFit.contain),
        ),
        // Aspect ratio buttons
        Positioned(
          left: 16,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _aspectButton('Original', 0.0, () => _setAspect(0)),
              _aspectButton('1:1', 1.0, () => _setAspect(1)),
              _aspectButton('4:5', 4/5, () => _setAspect(4/5)),
              _aspectButton('16:9', 16/9, () => _setAspect(16/9)),
            ],
          ),
        ),
        if (_media.length > 1) ...[
          if (_currentIndex > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(LucideIcons.chevronLeft.localLucide, color: Colors.white, size: 32),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  onPressed: () => setState(() => _currentIndex--),
                ),
              ),
            ),
          if (_currentIndex < _media.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(LucideIcons.chevronRight.localLucide, color: Colors.white, size: 32),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  onPressed: () => setState(() => _currentIndex++),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _aspectButton(String label, double current, VoidCallback onTap) {
    final isSelected = (_currentMedia?.aspect ?? -1) == current;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? Colors.white : Colors.black54,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }

  Widget _buildEdit() {
    final item = _currentMedia;
    if (item == null) return const SizedBox();
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              item.isVideo
                  ? Icon(LucideIcons.video.localLucide, size: 100, color: Colors.grey[600])
                  : _applyFilterToImage(File(item.displayPath), item),
              if (_media.length > 1) ...[
                if (_currentIndex > 0)
                  Positioned(
                    left: 8,
                    child: IconButton(
                      icon: Icon(LucideIcons.chevronLeft.localLucide, color: Colors.black87),
                      style: IconButton.styleFrom(backgroundColor: Colors.white70),
                      onPressed: () => setState(() => _currentIndex--),
                    ),
                  ),
                if (_currentIndex < _media.length - 1)
                  Positioned(
                    right: 8,
                    child: IconButton(
                      icon: Icon(LucideIcons.chevronRight.localLucide, color: Colors.black87),
                      style: IconButton.styleFrom(backgroundColor: Colors.white70),
                      onPressed: () => setState(() => _currentIndex++),
                    ),
                  ),
              ],
            ],
          ),
        ),
        Container(
          width: 1,
          color: Colors.grey[200],
        ),
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _editTab = 'filters'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _editTab == 'filters' ? Colors.black : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'Filters',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _editTab == 'filters' ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _editTab = 'adjustments'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _editTab == 'adjustments' ? Colors.black : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'Adjustments',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _editTab == 'adjustments' ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _editTab == 'filters'
                        ? Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _filterNames.map((name) {
                              final selected = item.filter == name;
                              return InkWell(
                                onTap: () => _applyFilter(name),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: selected ? const Color(0xFF0095F6) : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: item.isVideo
                                            ? Icon(LucideIcons.video.localLucide, size: 32)
                                            : Image.file(File(item.displayPath), fit: BoxFit.cover),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                        color: selected ? const Color(0xFF0095F6) : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _adjustments.map((adj) {
                              final key = adj.$1;
                              final label = adj.$2;
                              final min = adj.$3;
                              final max = adj.$4;
                              final value = item.adjustments[key] ?? 0;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                        Text('$value', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                      ],
                                    ),
                                    Slider(
                                      value: value.toDouble(),
                                      min: min.toDouble(),
                                      max: max.toDouble(),
                                      onChanged: (v) => _updateAdjustment(key, v.round()),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _applyFilterToImage(File file, _CreatePostMediaItem item) {
    // Approximate filter with ColorFilter (brightness/contrast/saturation via matrix)
    double b = (item.adjustments['brightness'] ?? 0) / 100 + 1;
    double c = (item.adjustments['contrast'] ?? 0) / 100 + 1;
    double s = (item.adjustments['saturate'] ?? 0) / 100 + 1;
    final matrix = _buildFilterMatrix(brightness: b, contrast: c, saturation: s);
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: Image.file(file, fit: BoxFit.contain),
    );
  }

  List<double> _buildFilterMatrix({double brightness = 1, double contrast = 1, double saturation = 1}) {
    // Simplified 4x5 matrix: brightness scales, contrast and saturation approximated
    final b = brightness;
    final c = contrast;
    final s = saturation;
    final invSat = 1 - s;
    final r = 0.2126 * invSat;
    final g = 0.7152 * invSat;
    final b_ = 0.0722 * invSat;
    return [
      (r + s) * c * b, g * c * b, b_ * c * b, 0, 0,
      r * c * b, (g + s) * c * b, b_ * c * b, 0, 0,
      r * c * b, g * c * b, (b_ + s) * c * b, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  Widget _buildShare() {
    final item = _currentMedia;
    if (item == null) return const SizedBox();
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTapDown: _onImageTapForTag,
                child: item.isVideo
                    ? Icon(LucideIcons.video.localLucide, size: 100, color: Colors.grey[600])
                    : _applyFilterToImage(File(item.displayPath), item),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Tap photo to tag people', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ),
              ..._tags.map((t) => Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment(t.x / 50 - 1, t.y / 50 - 1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (t.user['username'] as String?) ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            GestureDetector(
                              onTap: () => _removeTag(t.id),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Icon(LucideIcons.x.localLucide, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
              if (_showTagSearch) _buildTagSearchOverlay(),
              if (_media.length > 1) ...[
                if (_currentIndex > 0)
                  Positioned(
                    left: 8,
                    child: IconButton(
                      icon: Icon(LucideIcons.chevronLeft.localLucide, color: Colors.black87),
                      style: IconButton.styleFrom(backgroundColor: Colors.white70),
                      onPressed: () => setState(() => _currentIndex--),
                    ),
                  ),
                if (_currentIndex < _media.length - 1)
                  Positioned(
                    right: 8,
                    child: IconButton(
                      icon: Icon(LucideIcons.chevronRight.localLucide, color: Colors.black87),
                      style: IconButton.styleFrom(backgroundColor: Colors.white70),
                      onPressed: () => setState(() => _currentIndex++),
                    ),
                  ),
              ],
            ],
          ),
        ),
        Container(width: 1, color: Colors.grey[200]),
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 8),
                TextField(
                  controller: _captionCtl,
                  maxLines: 5,
                  maxLength: 2200,
                  decoration: const InputDecoration(
                    hintText: 'Write a caption...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(LucideIcons.smile.localLucide, color: Colors.grey),
                      onPressed: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _captionCtl,
                      builder: (_, value, __) => Text('${value.text.length}/2,200', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ),
                  ],
                ),
                if (_showEmojiPicker)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(8)),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: _popularEmojis.map((e) => InkWell(
                        onTap: () {
                          _captionCtl.text = _captionCtl.text + e;
                          setState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(e, style: const TextStyle(fontSize: 22)),
                        ),
                      )).toList(),
                    ),
                  ),
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(LucideIcons.userPlus.localLucide, size: 22),
                  title: const Text('Add Tag', style: TextStyle(fontSize: 14)),
                ),
                InkWell(
                  onTap: () => setState(() => _advancedOpen = !_advancedOpen),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Advanced Settings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        Icon(_advancedOpen ? LucideIcons.chevronUp.localLucide : LucideIcons.chevronDown.localLucide, color: Colors.grey[600]),
                      ],
                    ),
                  ),
                ),
                if (_advancedOpen) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hide like and view counts on this post', style: TextStyle(fontSize: 14)),
                    value: _hideLikes,
                    onChanged: (v) => setState(() => _hideLikes = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Turn off commenting', style: TextStyle(fontSize: 14)),
                    value: _turnOffCommenting,
                    onChanged: (v) => setState(() => _turnOffCommenting = v),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagSearchOverlay() {
    return Positioned(
      left: 24,
      right: 24,
      top: 24,
      bottom: 24,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tag People', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  IconButton(
                    icon: Icon(LucideIcons.x.localLucide, size: 20),
                    onPressed: () => setState(() => _showTagSearch = false),
                  ),
                ],
              ),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search user',
                  prefixIcon: Icon(LucideIcons.search.localLucide, size: 20),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => _searchTagUsers(v),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: _isSearchingUsers
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _tagSearchResults.isEmpty
                        ? const Center(child: Text('No users found', style: TextStyle(fontSize: 12, color: Colors.grey)))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _tagSearchResults.length,
                            itemBuilder: (_, i) {
                              final u = _tagSearchResults[i];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  backgroundImage: u['avatar_url'] != null && (u['avatar_url'] as String).isNotEmpty
                                      ? NetworkImage(u['avatar_url'] as String)
                                      : null,
                                  child: u['avatar_url'] == null || (u['avatar_url'] as String).isEmpty
                                      ? Icon(LucideIcons.user.localLucide)
                                      : null,
                                ),
                                title: Text((u['username'] as String?) ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                subtitle: Text((u['full_name'] as String?) ?? '', style: const TextStyle(fontSize: 12)),
                                onTap: () => _addTag(u),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
