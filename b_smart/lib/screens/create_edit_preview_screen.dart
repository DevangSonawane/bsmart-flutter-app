import 'package:flutter/material.dart';
import '../models/media_model.dart';
import '../services/create_service.dart';
import 'create_post_details_screen.dart';

class CreateEditPreviewScreen extends StatefulWidget {
  final MediaItem media;
  final String? selectedFilter;

  const CreateEditPreviewScreen({
    super.key,
    required this.media,
    this.selectedFilter,
  });

  @override
  State<CreateEditPreviewScreen> createState() => _CreateEditPreviewScreenState();
}

class _CreateEditPreviewScreenState extends State<CreateEditPreviewScreen> {
  final CreateService _createService = CreateService();
  String? _selectedFilter;
  String? _selectedMusic;
  double _musicVolume = 0.5;
  bool _showTrimControls = false;
  bool _showMusicControls = false;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.selectedFilter;
  }

  void _proceedToPostDetails() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreatePostDetailsScreen(
          media: widget.media,
          selectedFilter: _selectedFilter,
          selectedMusic: _selectedMusic,
          musicVolume: _musicVolume,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Edit', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _proceedToPostDetails,
            child: const Text(
              'Next',
              style: TextStyle(color: Colors.blue, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Media Preview
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.grey[900],
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Media placeholder
                  widget.media.type == MediaType.video
                      ? const Icon(Icons.play_circle_outline, size: 100, color: Colors.white54)
                      : const Icon(Icons.image, size: 100, color: Colors.white54),
                  
                  // Filter overlay indicator
                  if (_selectedFilter != null && _selectedFilter != 'none')
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Filter: $_selectedFilter',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Edit Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black,
            child: Column(
              children: [
                // Trim Controls (for videos)
                if (widget.media.type == MediaType.video && _showTrimControls)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Trim Video', style: TextStyle(color: Colors.white)),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _showTrimControls = false;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Video timeline placeholder
                        Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'Video Timeline',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.skip_previous, color: Colors.white),
                              label: const Text('Start', style: TextStyle(color: Colors.white)),
                              onPressed: () {},
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.skip_next, color: Colors.white),
                              label: const Text('End', style: TextStyle(color: Colors.white)),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Music Controls
                if (_showMusicControls)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Music', style: TextStyle(color: Colors.white)),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _showMusicControls = false;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_selectedMusic != null)
                          Text(
                            'Selected: $_selectedMusic',
                            style: const TextStyle(color: Colors.white54),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.volume_down, color: Colors.white),
                            Expanded(
                              child: Slider(
                                value: _musicVolume,
                                onChanged: (value) {
                                  setState(() {
                                    _musicVolume = value;
                                  });
                                },
                                activeColor: Colors.blue,
                              ),
                            ),
                            const Icon(Icons.volume_up, color: Colors.white),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Edit Options
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildEditOption(
                      icon: Icons.filter_alt,
                      label: 'Filters',
                      onTap: () => _showFilterOptions(),
                    ),
                    if (widget.media.type == MediaType.video)
                      _buildEditOption(
                        icon: Icons.content_cut,
                        label: 'Trim',
                        onTap: () {
                          setState(() {
                            _showTrimControls = !_showTrimControls;
                            _showMusicControls = false;
                          });
                        },
                      ),
                    _buildEditOption(
                      icon: Icons.music_note,
                      label: 'Music',
                      onTap: () {
                        setState(() {
                          _showMusicControls = !_showMusicControls;
                          _showTrimControls = false;
                        });
                      },
                    ),
                    _buildEditOption(
                      icon: Icons.auto_awesome,
                      label: 'AI',
                      onTap: () => _showAIOptions(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions() {
    final filters = _createService.getFilters();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Filter',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                itemBuilder: (context, index) {
                  final filter = filters[index];
                  final isSelected = _selectedFilter == filter.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = filter.id;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[800],
                              border: Border.all(
                                color: isSelected ? Colors.blue : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                filter.name[0],
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            filter.name,
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAIOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'AI Enhancements',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                _buildAIOption('Background Removal', Icons.auto_fix_high),
                _buildAIOption('Face Enhancement', Icons.face),
                _buildAIOption('Auto Crop', Icons.crop),
                _buildAIOption('Stabilize', Icons.video_stable),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIOption(String label, IconData icon) {
    return ElevatedButton.icon(
      onPressed: () async {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Processing $label...')),
        );
        
        // Simulate AI processing
        await Future.delayed(const Duration(seconds: 2));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label applied successfully')),
          );
        }
      },
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }
}
