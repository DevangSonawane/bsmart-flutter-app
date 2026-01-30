import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/feed_post_model.dart';

class PostsGrid extends StatelessWidget {
  final List<FeedPost> posts;
  final void Function(FeedPost) onTap;

  const PostsGrid({Key? key, required this.posts, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(child: Text('No posts yet'));
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final p = posts[index];
        final thumb = p.mediaUrls.isNotEmpty ? p.mediaUrls.first : null;
        return GestureDetector(
          onTap: () => onTap(p),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              color: Colors.grey[200],
              child: thumb != null
                  ? CachedNetworkImage(
                      imageUrl: thumb,
                      fit: BoxFit.cover,
                      placeholder: (ctx, url) => Container(color: Colors.grey[300]),
                      errorWidget: (ctx, url, err) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

