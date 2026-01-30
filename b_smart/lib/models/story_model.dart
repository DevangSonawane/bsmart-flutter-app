class Story {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String mediaUrl;
  final StoryMediaType mediaType;
  final DateTime createdAt;
  final int views;
  final bool isViewed;

  Story({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    this.views = 0,
    this.isViewed = false,
  });
}

enum StoryMediaType {
  image,
  video,
}

class StoryGroup {
  final String userId;
  final String userName;
  final String? userAvatar;
  final bool isOnline;
  final List<Story> stories;

  StoryGroup({
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.isOnline = false,
    required this.stories,
  });
}
