import 'package:flutter/material.dart';
import '../models/media_model.dart';
import '../models/content_moderation_model.dart';
import '../services/create_service.dart';
import '../services/content_moderation_service.dart';
import 'content_moderation_dialog.dart';

class CreatePostDetailsScreen extends StatefulWidget {
  final MediaItem media;
  final String? selectedFilter;
  final String? selectedMusic;
  final double musicVolume;

  const CreatePostDetailsScreen({
    super.key,
    required this.media,
    this.selectedFilter,
    this.selectedMusic,
    this.musicVolume = 0.5,
  });

  @override
  State<CreatePostDetailsScreen> createState() => _CreatePostDetailsScreenState();
}

class _CreatePostDetailsScreenState extends State<CreatePostDetailsScreen> {
  final CreateService _createService = CreateService();
  final ContentModerationService _moderationService = ContentModerationService();
  final _captionController = TextEditingController();
  final _hashtagController = TextEditingController();
  
  PrivacyLevel _privacy = PrivacyLevel.public;
  bool _commentsEnabled = true;
  String? _location;
  final List<String> _taggedUsers = [];
  final List<String> _hashtags = [];
  String? _suggestedCaption;
  List<String> _suggestedHashtags = [];
  final bool _isSponsored = false; // Can be set from UI if needed

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  void _loadSuggestions() {
    // Get AI suggestions
    _suggestedCaption = _createService.suggestCaption(widget.media);
    _suggestedHashtags = _createService.suggestHashtags(widget.media);
    
    if (_suggestedCaption != null) {
      _captionController.text = _suggestedCaption!;
    }
  }

  void _addHashtag() {
    final text = _hashtagController.text.trim();
    if (text.isNotEmpty && !text.startsWith('#')) {
      _hashtagController.text = '#$text';
    }
    if (_hashtagController.text.isNotEmpty) {
      setState(() {
        _hashtags.add(_hashtagController.text.trim());
        _hashtagController.clear();
      });
    }
  }

  void _removeHashtag(String hashtag) {
    setState(() {
      _hashtags.remove(hashtag);
    });
  }

  void _tagUser(String username) {
    if (!_taggedUsers.contains(username)) {
      setState(() {
        _taggedUsers.add(username);
      });
    }
  }

  void _removeTaggedUser(String username) {
    setState(() {
      _taggedUsers.remove(username);
    });
  }

  Future<void> _handlePost() async {
    if (_captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a caption')),
      );
      return;
    }

    // Check if user can post (strike system)
    if (!_moderationService.canUserPost('user-1')) {
      final strikes = _moderationService.getUserStrikes('user-1');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Posting Restricted'),
          content: Text(
            'You have ${strikes?.policyStrikes ?? 0} policy violations. '
            'Posting is restricted. Please contact support if you believe this is an error.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Show moderation check dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Run content moderation check
    final moderationResult = await _moderationService.moderateMedia(
      media: widget.media,
      caption: _captionController.text.trim(),
      hashtags: _hashtags,
      isSponsored: _isSponsored,
    );

    if (mounted) {
      Navigator.of(context).pop(); // Close loading

      // Handle moderation result
      if (moderationResult.isBlocked) {
        // Add strike
        _moderationService.addStrike('user-1', 'sexual_content');
        
        // Show block dialog
        showDialog(
          context: context,
          builder: (context) => ContentModerationDialog(
            result: moderationResult,
            onAppeal: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Appeal submitted. We will review your case.')),
              );
            },
          ),
        );
        return;
      }

      if (moderationResult.isRestricted || moderationResult.hasRestrictions) {
        // Show restriction warning but allow posting
        showDialog(
          context: context,
          builder: (context) => ContentModerationDialog(
            result: moderationResult,
            onDismiss: () {
              _proceedWithPosting(moderationResult);
            },
          ),
        );
        return;
      }

      // Content is safe, proceed with posting
      _proceedWithPosting(moderationResult);
    }
  }

  void _proceedWithPosting(ContentModerationResult moderationResult) {
    // Show posting dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Simulate posting
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        Navigator.of(context).popUntil((route) => route.isFirst); // Go back to home
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              moderationResult.hasRestrictions
                  ? 'Post published with restrictions'
                  : 'Post published successfully!',
            ),
            backgroundColor: moderationResult.hasRestrictions ? Colors.orange : Colors.green,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Post Details', style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: _handlePost,
            child: const Text(
              'Post',
              style: TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Media Preview
            Container(
              height: 300,
              width: double.infinity,
              color: Colors.grey[300],
              child: widget.media.type == MediaType.video
                  ? const Icon(Icons.play_circle_outline, size: 80, color: Colors.grey)
                  : const Icon(Icons.image, size: 80, color: Colors.grey),
            ),

            // Caption
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Caption',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _captionController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Write a caption...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  if (_suggestedCaption != null)
                    TextButton.icon(
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Use AI suggestion'),
                      onPressed: () {
                        _captionController.text = _suggestedCaption!;
                      },
                    ),
                ],
              ),
            ),

            // Hashtags
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hashtags',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hashtagController,
                          decoration: InputDecoration(
                            hintText: '#hashtag',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          onSubmitted: (_) => _addHashtag(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addHashtag,
                      ),
                    ],
                  ),
                  if (_suggestedHashtags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestedHashtags.map((tag) {
                        return Chip(
                          label: Text('#$tag'),
                          onDeleted: () {
                            setState(() {
                              _hashtags.add('#$tag');
                            });
                          },
                          deleteIcon: const Icon(Icons.add, size: 16),
                        );
                      }).toList(),
                    ),
                  ],
                  if (_hashtags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _hashtags.map((tag) {
                        return Chip(
                          label: Text(tag),
                          onDeleted: () => _removeHashtag(tag),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(),

            // Tag Friends
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Tag Friends'),
              subtitle: Text(_taggedUsers.isEmpty ? 'No one tagged' : _taggedUsers.join(', ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showTagFriendsDialog(),
            ),

            const Divider(),

            // Privacy
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Privacy'),
              subtitle: Text(_privacy.name.toUpperCase()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPrivacyDialog(),
            ),

            const Divider(),

            // Comments
            SwitchListTile(
              secondary: const Icon(Icons.comment_outlined),
              title: const Text('Enable Comments'),
              value: _commentsEnabled,
              onChanged: (value) {
                setState(() {
                  _commentsEnabled = value;
                });
              },
            ),

            const Divider(),

            // Location
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Add Location'),
              subtitle: Text(_location ?? 'No location'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLocationDialog(),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showTagFriendsDialog() {
    final users = _createService.getUsersForTagging();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tag Friends'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final isTagged = _taggedUsers.contains(user);
              return CheckboxListTile(
                title: Text(user),
                value: isTagged,
                onChanged: (value) {
                  if (value == true) {
                    _tagUser(user);
                  } else {
                    _removeTaggedUser(user);
                  }
                  Navigator.pop(context);
                  setState(() {});
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy'),
        content: RadioGroup<PrivacyLevel>(
          groupValue: _privacy,
          onChanged: (value) {
            setState(() {
              _privacy = value!;
            });
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<PrivacyLevel>(
                title: const Text('Public'),
                subtitle: const Text('Anyone can see this post'),
                value: PrivacyLevel.public,
              ),
              RadioListTile<PrivacyLevel>(
                title: const Text('Followers'),
                subtitle: const Text('Only your followers can see this'),
                value: PrivacyLevel.followers,
              ),
              RadioListTile<PrivacyLevel>(
                title: const Text('Private'),
                subtitle: const Text('Only you can see this'),
                value: PrivacyLevel.private,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Location'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Search location...',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) {
            setState(() {
              _location = value;
            });
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _location = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Remove'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
