import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final List<MediaItem> _selectedMedia = [];
  List<MediaItem> _galleryMedia = [];

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
          duration: type == MediaType.video ? const Duration(seconds: 15) : null, // Approx duration as we can't easily get it without video_player
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

  void _loadGalleryMedia() {
    // Gallery media is now handled by system picker
    setState(() {
      _galleryMedia = [];
    });
  }

  void _toggleMediaSelection(MediaItem media) {
    setState(() {
      if (_selectedMedia.any((m) => m.id == media.id)) {
        _selectedMedia.removeWhere((m) => m.id == media.id);
      } else {
        _selectedMedia.add(media);
      }
    });
  }

  void _proceedToEdit() {
    if (_selectedMedia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one media item')),
      );
      return;
    }

    // Validate media
    for (final media in _selectedMedia) {
      if (!_createService.validateMedia(media)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video must be 60 seconds or less')),
        );
        return;
      }
    }

    // Navigate to edit screen with first media (for carousel, would handle all)
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateEditPreviewScreen(
          media: _selectedMedia.first,
          selectedFilter: null,
        ),
      ),
    );
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
                if (_selectedMedia.isNotEmpty)
                  ElevatedButton(
                    onPressed: _proceedToEdit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: Text('Next (${_selectedMedia.length})'),
                  ),
              ],
            ),
          ),

          // Gallery Grid
          Expanded(
            child: _galleryMedia.isEmpty 
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
              itemCount: _galleryMedia.length,
              itemBuilder: (context, index) {
                final media = _galleryMedia[index];
                final isSelected = _selectedMedia.any((m) => m.id == media.id);

                return GestureDetector(
                  onTap: () => _toggleMediaSelection(media),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: Colors.grey[800],
                        child: media.type == MediaType.video
                            ? const Icon(Icons.videocam, color: Colors.white54)
                            : const Icon(Icons.image, color: Colors.white54),
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
                      if (media.type == MediaType.video)
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
                              '${media.duration?.inSeconds ?? 0}s',
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
