enum PostMediaType {
  image,
  video,
  carousel,
  reel,
}

class FeedPost {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final bool isVerified;
  final PostMediaType mediaType;
  final List<String> mediaUrls; // For carousel, multiple URLs
  final String? caption;
  final List<String> hashtags;
  final DateTime createdAt;
  final int likes;
  final int comments;
  final int views; // For videos/reels
  final int shares;
  final bool isLiked;
  final bool isSaved;
  final bool isFollowed;
  final bool isTagged;
  final bool isShared;
  final String? sharedFrom;
  final bool isAd;
  final String? adTitle;
  final String? adCompanyId;
  final String? adCompanyName;

  FeedPost({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.isVerified = false,
    required this.mediaType,
    required this.mediaUrls,
    this.caption,
    this.hashtags = const [],
    required this.createdAt,
    this.likes = 0,
    this.comments = 0,
    this.views = 0,
    this.shares = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isFollowed = false,
    this.isTagged = false,
    this.isShared = false,
    this.sharedFrom,
    this.isAd = false,
    this.adTitle,
    this.adCompanyId,
    this.adCompanyName,
  });

  FeedPost copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    bool? isVerified,
    PostMediaType? mediaType,
    List<String>? mediaUrls,
    String? caption,
    List<String>? hashtags,
    DateTime? createdAt,
    int? likes,
    int? comments,
    int? views,
    int? shares,
    bool? isLiked,
    bool? isSaved,
    bool? isFollowed,
    bool? isTagged,
    bool? isShared,
    String? sharedFrom,
    bool? isAd,
    String? adTitle,
    String? adCompanyId,
    String? adCompanyName,
  }) {
    return FeedPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      isVerified: isVerified ?? this.isVerified,
      mediaType: mediaType ?? this.mediaType,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      caption: caption ?? this.caption,
      hashtags: hashtags ?? this.hashtags,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      views: views ?? this.views,
      shares: shares ?? this.shares,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isFollowed: isFollowed ?? this.isFollowed,
      isTagged: isTagged ?? this.isTagged,
      isShared: isShared ?? this.isShared,
      sharedFrom: sharedFrom ?? this.sharedFrom,
      isAd: isAd ?? this.isAd,
      adTitle: adTitle ?? this.adTitle,
      adCompanyId: adCompanyId ?? this.adCompanyId,
      adCompanyName: adCompanyName ?? this.adCompanyName,
    );
  }
}
