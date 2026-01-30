import 'package:flutter/material.dart';
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
  final List<MediaItem> _selectedMedia = [];
  List<MediaItem> _galleryMedia = [];

  @override
  void initState() {
    super.initState();
    _loadGalleryMedia();
  }

  void _loadGalleryMedia() {
    // Simulate gallery media
    final now = DateTime.now();
    setState(() {
      _galleryMedia = [
        MediaItem(
          id: 'gallery-1',
          type: MediaType.image,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        MediaItem(
          id: 'gallery-2',
          type: MediaType.video,
          duration: const Duration(seconds: 30),
          createdAt: now.subtract(const Duration(days: 2)),
        ),
        MediaItem(
          id: 'gallery-3',
          type: MediaType.image,
          createdAt: now.subtract(const Duration(days: 3)),
        ),
        MediaItem(
          id: 'gallery-4',
          type: MediaType.video,
          duration: const Duration(seconds: 45),
          createdAt: now.subtract(const Duration(days: 4)),
        ),
        MediaItem(
          id: 'gallery-5',
          type: MediaType.image,
          createdAt: now.subtract(const Duration(days: 5)),
        ),
        MediaItem(
          id: 'gallery-6',
          type: MediaType.image,
          createdAt: now.subtract(const Duration(days: 6)),
        ),
      ];
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
                const Text(
                  'Select Media',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
            child: GridView.builder(
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
