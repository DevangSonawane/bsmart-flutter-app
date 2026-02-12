import 'package:meta/meta.dart';
import '../models/feed_post_model.dart';

@immutable
class FeedState {
  final List<FeedPost> posts;
  final bool isLoading;

  const FeedState({
    this.posts = const [],
    this.isLoading = false,
  });

  factory FeedState.initial() => const FeedState();

  FeedState copyWith({
    List<FeedPost>? posts,
    bool? isLoading,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
