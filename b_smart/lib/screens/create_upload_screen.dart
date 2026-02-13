import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_model.dart';
import '../services/create_service.dart';
import 'create_edit_preview_screen.dart';

class CreateUploadScreen extends StatefulWidget {
  const CreateUploadScreen({super.key});

  @override
  State<CreateUploadScreen> createState() => _CreateUploadScreenState();
}

class _CreateUploadScreenState extends State<CreateUploadScreen> {
  final CreateService _createService = CreateService();
  final ImagePicker _picker = ImagePicker();
  final List<AssetEntity> _assets = [];
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadGalleryMedia();
  }

  Future<void> _pickFromGallery() async {
    await _pickMedia(MediaType.image);
  }

  Future<void> _pickVideoFromGallery() async {
    await _pickMedia(MediaType.video);
  }

  Future<void> _pickMedia(MediaType type) async {
    try {
      final XFile? file;
      if (type == MediaType.image) {
        file = await _picker.pickImage(source: ImageSource.gallery);
      } else {
        file = await _picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(seconds: 60),
        );
      }

      if (file != null) {
        final media = MediaItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: type,
          filePath: file.path,
          createdAt: DateTime.now(),
          duration: type == MediaType.video ? const Duration(seconds: 15) : null,
        );
        
        if (!mounted) return;
        
        // Validate media
        if (!_createService.validateMedia(media)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid media file')),
          );
          return;
        }

        // Navigate directly to edit screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CreateEditPreviewScreen(
              media: media,
              selectedFilter: null,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _loadGalleryMedia() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gallery permission denied')),
        );
      }
      return;
    }
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: FilterOptionGroup(
        orders: [OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );
    if (paths.isEmpty) {
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final AssetPathEntity recent = paths.first;
    final List<AssetEntity> assets = await recent.getAssetListPaged(page: 0, size: 120);
    if (mounted) {
      setState(() {
        _assets
          ..clear()
          ..addAll(assets);
      });
    }
  }

  void _toggleMediaSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _proceedToEdit() {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one media item')),
      );
      return;
    }

    final AssetEntity first = _assets.firstWhere((a) => _selectedIds.contains(a.id));
    first.originFile.then((file) {
      if (file == null) return;
      final media = MediaItem(
        id: first.id,
        type: first.type == AssetType.video ? MediaType.video : MediaType.image,
        filePath: file.path,
        createdAt: first.createDateTime,
        duration: first.type == AssetType.video ? Duration(seconds: first.duration) : null,
      );
      if (!_createService.validateMedia(media)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video must be 60 seconds or less')),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CreateEditPreviewScreen(
            media: media,
            selectedFilter: null,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
          Navigator.of(context).pop();
        }
      },
      child: Column(
        children: [
          // Header Actions
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Select Media',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate, color: Colors.blue),
                      tooltip: 'Pick Image',
                      onPressed: _pickFromGallery,
                    ),
                    IconButton(
                      icon: const Icon(Icons.video_library, color: Colors.blue),
                      tooltip: 'Pick Video',
                      onPressed: _pickVideoFromGallery,
                    ),
                  ],
                ),
                if (_selectedIds.isNotEmpty)
                  ElevatedButton(
                    onPressed: _proceedToEdit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: Text('Next (${_selectedIds.length})'),
                  ),
              ],
            ),
          ),

          // Gallery Grid
          Expanded(
            child: _assets.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.image_search, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No media found',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.photo),
                            onPressed: _pickFromGallery,
                            label: const Text('Pick Image'),
                          ),
                          const SizedBox(width: 16),
                          TextButton.icon(
                            icon: const Icon(Icons.videocam),
                            onPressed: _pickVideoFromGallery,
                            label: const Text('Pick Video'),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _assets.length,
              itemBuilder: (context, index) {
                final asset = _assets[index];
                final isSelected = _selectedIds.contains(asset.id);

                return GestureDetector(
                  onTap: () => _toggleMediaSelection(asset.id),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: Colors.grey[800],
                        child: FutureBuilder<Uint8List?>(
                          future: asset.thumbnailDataWithSize(const ThumbnailSize(300, 300)),
                          builder: (context, snap) {
                            if (snap.connectionState != ConnectionState.done || snap.data == null) {
                              return const Center(child: Icon(Icons.image, color: Colors.white54));
                            }
                            return Image.memory(snap.data!, fit: BoxFit.cover);
                          },
                        ),
                      ),
                      if (isSelected)
                        Container(
                          color: Colors.blue.withValues(alpha: 0.5),
                          child: const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      if (asset.type == AssetType.video)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${asset.duration}s',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
