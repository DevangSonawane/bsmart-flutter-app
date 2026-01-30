enum MediaType {
  image,
  video,
}

enum PrivacyLevel {
  public,
  followers,
  private,
}

class MediaItem {
  final String id;
  final MediaType type;
  final String? filePath;
  final String? thumbnailPath;
  final Duration? duration; // For videos
  final DateTime createdAt;

  MediaItem({
    required this.id,
    required this.type,
    this.filePath,
    this.thumbnailPath,
    this.duration,
    required this.createdAt,
  });
}

class PostDraft {
  final String id;
  final List<MediaItem> media;
  final String? caption;
  final List<String> hashtags;
  final List<String> taggedUsers;
  final PrivacyLevel privacy;
  final bool commentsEnabled;
  final String? location;
  final String? musicTrack;
  final double musicVolume;
  final Map<String, dynamic>? filters;
  final DateTime createdAt;

  PostDraft({
    required this.id,
    required this.media,
    this.caption,
    this.hashtags = const [],
    this.taggedUsers = const [],
    this.privacy = PrivacyLevel.public,
    this.commentsEnabled = true,
    this.location,
    this.musicTrack,
    this.musicVolume = 0.5,
    this.filters,
    required this.createdAt,
  });
}

class Filter {
  final String id;
  final String name;
  final String? previewIcon;

  Filter({
    required this.id,
    required this.name,
    this.previewIcon,
  });
}

class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String? coverArt;
  final Duration duration;

  MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.coverArt,
    required this.duration,
  });
}
