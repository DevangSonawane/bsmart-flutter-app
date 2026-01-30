import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/story_model.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<StoryGroup> storyGroups;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    required this.storyGroups,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late PageController _pageController;
  late PageController _storyController;
  int _currentGroupIndex = 0;
  int _currentStoryIndex = 0;
  Timer? _autoPlayTimer;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _storyController = PageController();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    _storyController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _progress = 0.0;
    
    final currentGroup = widget.storyGroups[_currentGroupIndex];
    if (_currentStoryIndex >= currentGroup.stories.length) {
      _nextGroup();
      return;
    }

    _autoPlayTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _progress += 0.02; // 5 seconds per story
      });

      if (_progress >= 1.0) {
        timer.cancel();
        _nextStory();
      }
    });
  }

  void _nextStory() {
    final currentGroup = widget.storyGroups[_currentGroupIndex];
    if (_currentStoryIndex < currentGroup.stories.length - 1) {
      setState(() {
        _currentStoryIndex++;
        _progress = 0.0;
      });
      _storyController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startAutoPlay();
    } else {
      _nextGroup();
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
        _progress = 0.0;
      });
      _storyController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startAutoPlay();
    } else {
      _previousGroup();
    }
  }

  void _nextGroup() {
    if (_currentGroupIndex < widget.storyGroups.length - 1) {
      setState(() {
        _currentGroupIndex++;
        _currentStoryIndex = 0;
        _progress = 0.0;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _storyController.jumpToPage(0);
      _startAutoPlay();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previousGroup() {
    if (_currentGroupIndex > 0) {
      setState(() {
        _currentGroupIndex--;
        final previousGroup = widget.storyGroups[_currentGroupIndex];
        _currentStoryIndex = previousGroup.stories.length - 1;
        _progress = 0.0;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _storyController.jumpToPage(_currentStoryIndex);
      _startAutoPlay();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.storyGroups.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No stories available')),
      );
    }

    final currentGroup = widget.storyGroups[_currentGroupIndex];
    final currentStory = currentGroup.stories[_currentStoryIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 2) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            Navigator.of(context).pop();
          }
        },
        child: Stack(
          children: [
            // Story Content
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentGroupIndex = index;
                  _currentStoryIndex = 0;
                  _progress = 0.0;
                });
                _storyController.jumpToPage(0);
                _startAutoPlay();
              },
              itemCount: widget.storyGroups.length,
              itemBuilder: (context, groupIndex) {
                final group = widget.storyGroups[groupIndex];
                return PageView.builder(
                  controller: groupIndex == _currentGroupIndex
                      ? _storyController
                      : PageController(),
                  itemCount: group.stories.length,
                  itemBuilder: (context, storyIndex) {
                    final story = group.stories[storyIndex];
                    return _buildStoryContent(story);
                  },
                );
              },
            ),

            // Progress Bar
            Positioned(
              top: 40,
              left: 8,
              right: 8,
              child: Column(
                children: [
                  Row(
                    children: List.generate(
                      currentGroup.stories.length,
                      (index) => Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(1),
                          ),
                          child: index == _currentStoryIndex
                              ? FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _progress,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                )
                              : index < _currentStoryIndex
                                  ? Container(color: Colors.white)
                                  : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // User Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue,
                        child: Text(
                          currentGroup.userName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentGroup.userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _formatTimestamp(currentStory.createdAt),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(LucideIcons.x, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent(Story story) {
    final isImage = story.mediaType == StoryMediaType.image;
    final hasUrl = story.mediaUrl.isNotEmpty && (story.mediaUrl.startsWith('http://') || story.mediaUrl.startsWith('https://'));
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: isImage && hasUrl
          ? CachedNetworkImage(
              imageUrl: story.mediaUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (_, __, ___) => Center(child: Icon(LucideIcons.image, size: 100, color: Colors.white54)),
            )
          : Center(
              child: story.mediaType == StoryMediaType.video
                  ? Icon(LucideIcons.play, size: 100, color: Colors.white54)
                  : Icon(LucideIcons.image, size: 100, color: Colors.white54),
            ),
    );
  }

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
