import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/media_model.dart';
import '../services/supabase_service.dart';
import '../api/upload_api.dart';
import '../api/reels_api.dart';
import '../config/api_config.dart';
import '../utils/current_user.dart';

class CreateReelDetailsScreen extends StatefulWidget {
  final MediaItem media;
  final String? selectedFilter;
  final String? selectedMusic;
  final double musicVolume;
  final Duration? trimStart;
  final Duration? trimEnd;

  const CreateReelDetailsScreen({
    Key? key,
    required this.media,
    this.selectedFilter,
    this.selectedMusic,
    this.musicVolume = 0.5,
    this.trimStart,
    this.trimEnd,
  }) : super(key: key);

  @override
  State<CreateReelDetailsScreen> createState() => _CreateReelDetailsScreenState();
}

class _CreateReelDetailsScreenState extends State<CreateReelDetailsScreen> {
  final SupabaseService _svc = SupabaseService();
  final TextEditingController _captionCtl = TextEditingController();

  String _location = '';
  bool _hideLikes = false;
  bool _turnOffCommenting = false;
  bool _advancedOpen = false;
  bool _showEmojiPicker = false;
  bool _isSubmitting = false;
  Map<String, dynamic>? _currentUserProfile;

  VideoPlayerController? _videoController;
  Future<void>? _videoInit;

  static const _popularEmojis = [
    '😂',
    '😮',
    '😍',
    '😢',
    '👏',
    '🔥',
    '🎉',
    '💯',
    '❤️',
    '🤣',
    '🥰',
    '😘',
    '😭',
    '😊'
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProfile();
    final media = widget.media;
    if (media.type == MediaType.video && media.filePath != null) {
      final controller = VideoPlayerController.file(File(media.filePath!));
      _videoController = controller;
      _videoInit = controller.initialize().then((_) {
        if (!mounted) return;
        controller.setLooping(true);
        controller.play();
        setState(() {});
      });
    }
  }

  Future<Map<String, dynamic>?> _uploadThumbnailForVideo({
    required String videoPath,
    required int startMs,
    required int endMs,
  }) async {
    try {
      final durationMs = endMs > startMs ? endMs - startMs : (endMs > 0 ? endMs : startMs);
      final midOffset = durationMs > 0 ? durationMs ~/ 2 : 0;
      final captureMs = startMs + midOffset;
      final bytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        timeMs: captureMs,
        quality: 85,
      );
      if (bytes == null || bytes.isEmpty) return null;
      final filename = 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final res = await UploadApi().uploadThumbnailBytes(bytes: bytes, filename: filename);
      final rawThumbs = res['thumbnails'];
      List<String>? urls;
      if (rawThumbs is List) {
        urls = rawThumbs.map((e) => e.toString()).toList();
      } else if (rawThumbs is String) {
        urls = [rawThumbs];
      }
      if (urls == null || urls.isEmpty) return null;
      return {
        'urls': urls,
        'timeMs': captureMs,
      };
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _captionCtl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserProfile() async {
    final uid = await CurrentUser.id;
    if (uid == null) return;
    final profile = await _svc.getUserById(uid);
    if (mounted) setState(() => _currentUserProfile = profile);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final userId = await CurrentUser.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to share.')),
        );
      }
      return;
    }
    final filePath = widget.media.filePath;
    if (filePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing media file')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found');
      }
      final bytes = await file.readAsBytes();
      final ext = filePath.split('.').last;
      final filename = '$userId/${DateTime.now().millisecondsSinceEpoch}_reel.$ext';
      final uploaded = await UploadApi().uploadFileBytes(bytes: bytes, filename: filename);
      final serverFileName = (uploaded['fileName'] ?? uploaded['filename'] ?? filename).toString();
      String? fileUrl = uploaded['fileUrl']?.toString();
      if (fileUrl != null && fileUrl.isNotEmpty) {
        fileUrl = fileUrl.replaceAll('\\', '/');
        final isAbs = fileUrl.startsWith('http://') || fileUrl.startsWith('https://');
        if (!isAbs) {
          final base = ApiConfig.baseUrl;
          final baseUri = Uri.parse(base);
          final origin =
              '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
          if (!fileUrl.startsWith('/')) {
            if (fileUrl.startsWith('uploads/') || fileUrl.contains('/')) {
              fileUrl = '/$fileUrl';
            } else {
              fileUrl = '/uploads/$fileUrl';
            }
          }
          fileUrl = '$origin$fileUrl';
        } else if (fileUrl.startsWith('http://')) {
          try {
            final parsed = Uri.parse(fileUrl);
            fileUrl = Uri(
              scheme: 'https',
              host: parsed.host,
              port: parsed.hasPort ? parsed.port : null,
              path: parsed.path,
              query: parsed.query,
            ).toString();
          } catch (_) {}
        }
      }

      // Build media payload matching web client's reel structure as closely as possible.
      final Duration videoDuration =
          widget.media.duration ?? widget.trimEnd ?? const Duration(seconds: 0);
      final Duration start = widget.trimStart ?? Duration.zero;
      final Duration end =
          widget.trimEnd != null && widget.trimEnd! > start ? widget.trimEnd! : videoDuration;
      final int startMs = start.inMilliseconds;
      final int endMs = end.inMilliseconds;
      final int totalMs = videoDuration.inMilliseconds;
      final int finalLenMs = endMs > startMs ? (endMs - startMs) : totalMs;

      final thumbMeta = await _uploadThumbnailForVideo(
        videoPath: filePath,
        startMs: startMs,
        endMs: endMs,
      );

      final mediaItem = <String, dynamic>{
        'fileName': serverFileName,
        'type': 'video',
        if (fileUrl != null && fileUrl.isNotEmpty) 'fileUrl': fileUrl,
        // Timing information (ms, mirroring JS payload which uses numeric values)
        'timing': {
          'start': startMs,
          'end': endMs,
        },
        'videoLength': totalMs,
        'totalLenght': totalMs,
        'finalLength-start': startMs,
        'finallength-end': endMs,
        'finalLength': finalLenMs,
        'finallength': finalLenMs,
        if (thumbMeta != null && thumbMeta['urls'] != null) 'thumbnail': thumbMeta['urls'],
        if (thumbMeta != null && thumbMeta['timeMs'] != null) 'thumbail-time': thumbMeta['timeMs'],
        if (widget.selectedMusic != null) 'musicId': widget.selectedMusic,
        if (widget.selectedMusic != null) 'musicVolume': widget.musicVolume,
      };

      final created = await ReelsApi().createReel(
        media: [mediaItem],
        caption: _captionCtl.text.trim().isEmpty ? null : _captionCtl.text.trim(),
        location: _location.isEmpty ? null : _location,
        tags: const [],
        peopleTags: const [],
        hideLikesCount: _hideLikes,
        turnOffCommenting: _turnOffCommenting,
      );

      if (created.isNotEmpty && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reel shared successfully!')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create reel.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final isVideo = media.type == MediaType.video;

    Widget previewChild;
    if (media.filePath != null && isVideo) {
      final controller = _videoController;
      if (controller == null) {
        previewChild =
            Icon(LucideIcons.video, size: 100, color: Colors.grey[600]);
      } else {
        previewChild = FutureBuilder<void>(
          future: _videoInit,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                !controller.value.isInitialized) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            return FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            );
          },
        );
      }
    } else if (media.filePath != null && !isVideo) {
      previewChild = Image.file(
        File(media.filePath!),
        fit: BoxFit.cover,
      );
    } else {
      previewChild = Icon(
        isVideo ? LucideIcons.video : LucideIcons.image,
        size: 100,
        color: Colors.grey[600],
      );
    }

    final previewSection = Container(
      color: Colors.black,
      child: Center(child: previewChild),
    );

    final sharePanel = Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.transparent,
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _currentUserProfile != null &&
                            _currentUserProfile!['avatar_url'] != null &&
                            (_currentUserProfile!['avatar_url'] as String)
                                .isNotEmpty
                        ? NetworkImage(
                            _currentUserProfile!['avatar_url'] as String)
                        : null,
                    child: _currentUserProfile == null ||
                            _currentUserProfile!['avatar_url'] == null ||
                            (_currentUserProfile!['avatar_url'] as String)
                                .isEmpty
                        ? Text(
                            _currentUserProfile != null
                                ? ((_currentUserProfile!['username'] ??
                                            _currentUserProfile!['full_name'] ??
                                            'U') as String)
                                        .isNotEmpty
                                    ? ((_currentUserProfile!['username'] ??
                                                _currentUserProfile![
                                                    'full_name'] ??
                                                'U') as String)
                                            .substring(0, 1)
                                            .toUpperCase()
                                    : 'U'
                                : 'U',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  (_currentUserProfile?['username'] as String?) ?? 'User',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _captionCtl,
                  maxLines: 6,
                  maxLength: 2200,
                  decoration: const InputDecoration(
                    hintText: 'Write a caption...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    counterText: '',
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(LucideIcons.smile,
                          color: Colors.grey[600], size: 22),
                      onPressed: () =>
                          setState(() => _showEmojiPicker = !_showEmojiPicker),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _captionCtl,
                      builder: (_, value, __) => Text(
                        '${value.text.length}/2,200',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
                if (_showEmojiPicker)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Most popular',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _popularEmojis
                              .map(
                                (e) => InkWell(
                                  onTap: () {
                                    _captionCtl.text = _captionCtl.text + e;
                                    setState(() {});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Text(e,
                                        style:
                                            const TextStyle(fontSize: 22)),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading:
                Icon(LucideIcons.userPlus, size: 22, color: Colors.grey[700]),
            title: const Text('Add Tag', style: TextStyle(fontSize: 14)),
          ),
          InkWell(
            onTap: () => setState(() => _advancedOpen = !_advancedOpen),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Advanced Settings',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  Icon(
                    _advancedOpen
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_advancedOpen) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Hide like and view counts on this reel',
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Only you will see the total number of likes and views. You can change this later in the ... menu.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _hideLikes,
                        onChanged: (v) =>
                            setState(() => _hideLikes = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Turn off commenting',
                                style: TextStyle(fontSize: 14)),
                            SizedBox(height: 4),
                            Text(
                              'You can change this later in the ... menu at the top of your reel.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _turnOffCommenting,
                        onChanged: (v) =>
                            setState(() => _turnOffCommenting = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('New Reel', style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Share',
                    style: TextStyle(
                      color: Color(0xFF0095F6),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final useColumn = constraints.maxWidth < 600;
          final borderedPanel = Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                left: useColumn
                    ? BorderSide.none
                    : BorderSide(color: Theme.of(context).dividerColor),
                top: useColumn
                    ? BorderSide(color: Theme.of(context).dividerColor)
                    : BorderSide.none,
              ),
            ),
            child: sharePanel,
          );
          if (useColumn) {
            return Column(
              children: [
                Expanded(flex: 2, child: previewSection),
                SizedBox(
                  height: 320,
                  child: borderedPanel,
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: previewSection),
              SizedBox(
                width: 420,
                child: borderedPanel,
              ),
            ],
          );
        },
      ),
    );
  }
}
