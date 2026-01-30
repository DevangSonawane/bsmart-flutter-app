import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:b_smart/core/lucide_local.dart';
import '../theme/design_tokens.dart';

class PromoteScreen extends StatefulWidget {
  const PromoteScreen({Key? key}) : super(key: key);

  @override
  State<PromoteScreen> createState() => _PromoteScreenState();
}

class _PromoteScreenState extends State<PromoteScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isMuted = true;
  final Map<int, VideoPlayerController> _controllers = {};

  /// Height reserved for the floating bottom nav (match BottomNav: 8 + 64 + 8 padding).
  static const double kBottomNavHeight = 5;

  final List<Map<String, dynamic>> promotes = [
    {
      'id': 'p1',
      'username': 'business_growth',
      'videoUrl': 'https://assets.mixkit.co/videos/preview/mixkit-working-on-a-new-project-4240-large.mp4',
      'likes': '1.2k',
      'comments': '34',
      'description': 'Boost your business with our new tools! 🚀 #growth #business',
      'brandName': 'Growth Tools Inc.',
      'rating': 4.5,
      'products': [
        {'id': 1, 'image': 'https://images.unsplash.com/photo-1556742049-0cfed4f7a07d?w=400&h=300&fit=crop', 'title': 'Product A'},
        {'id': 2, 'image': 'https://images.unsplash.com/photo-1556740758-90de374c12ad?w=400&h=300&fit=crop', 'title': 'Product B'},
      ],
    },
    {
      'id': 'p2',
      'username': 'marketing_pro',
      'videoUrl': 'https://assets.mixkit.co/videos/preview/mixkit-discussion-of-a-marketing-project-4248-large.mp4',
      'likes': '850',
      'comments': '22',
      'description': 'Marketing strategies that work. 📈 #marketing #tips',
      'brandName': 'MarketMaster',
      'rating': 4.2,
      'products': [
        {'id': 1, 'image': 'https://images.unsplash.com/photo-1533750516457-a7f992034fec?w=400&h=300&fit=crop', 'title': 'Tool X'},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _initControllerForIndex(0);
  }

  Future<void> _initControllerForIndex(int index) async {
    if (index < 0 || index >= promotes.length) return;
    if (_controllers.containsKey(index)) return;
    final url = promotes[index]['videoUrl'] as String?;
    if (url == null || url.isEmpty) return;
    final controller = VideoPlayerController.network(url);
    _controllers[index] = controller;
    await controller.initialize();
    controller.setLooping(true);
    if (mounted && _currentIndex == index) controller.play();
    setState(() {});
  }

  void _disposeFarControllers(int keepIndex) {
    final keys = List<int>.from(_controllers.keys);
    for (final k in keys) {
      if ((k - keepIndex).abs() > 1) {
        try {
          _controllers[k]?.pause();
          _controllers[k]?.dispose();
        } catch (_) {}
        _controllers.remove(k);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _controllers.values) {
      try {
        c.pause();
        c.dispose();
      } catch (_) {}
    }
    _controllers.clear();
    super.dispose();
  }

  void _onPageChanged(int idx) {
    setState(() {
      _currentIndex = idx;
    });
    _initControllerForIndex(idx);
    _disposeFarControllers(idx);
    final c = _controllers[idx];
    if (c != null) {
      if (c.value.isInitialized) {
        if (!_isMuted) c.setVolume(1.0);
        c.play();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemCount: promotes.length,
        itemBuilder: (context, index) {
          final item = promotes[index];
          final products = (item['products'] as List<dynamic>?) ?? [];
          final controller = _controllers[index];
          return Stack(
            children: [
              // Video
              Positioned.fill(
                child: controller != null && controller.value.isInitialized
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: controller.value.size.width,
                          height: controller.value.size.height,
                          child: VideoPlayer(controller),
                        ),
                      )
                    : Container(color: Colors.black, child: const Center(child: CircularProgressIndicator(color: Colors.white54))),
              ),
              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                ),
              ),
              // Top right: mute/unmute only
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 12,
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: Icon(_isMuted ? LucideIcons.volumeX.localLucide : LucideIcons.volume2.localLucide, color: Colors.white, size: 28),
                    onPressed: () {
                      setState(() {
                        _isMuted = !_isMuted;
                        final c = _controllers[_currentIndex];
                        if (c != null) c.setVolume(_isMuted ? 0.0 : 1.0);
                      });
                    },
                  ),
                ),
              ),
              // Right side: like, comment, share, three dots — with clear gap below mute, positioned lower
              Positioned(
                right: 8,
                top: MediaQuery.of(context).padding.top + 8 + 48 + 44,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RightAction(icon: LucideIcons.heart.localLucide, label: (item['likes'] as String?) ?? '0', onTap: () {}),
                    const SizedBox(height: 4),
                    _RightAction(icon: LucideIcons.messageCircle.localLucide, label: (item['comments'] as String?) ?? '0', onTap: () {}),
                    const SizedBox(height: 4),
                    _RightAction(icon: LucideIcons.send.localLucide, label: null, onTap: () {}),
                    const SizedBox(height: 4),
                    _RightAction(icon: LucideIcons.ellipsis.localLucide, label: null, onTap: () {}),
                  ],
                ),
              ),
              // Bottom: gradient strip + content (match React: px-4 pb-2 pt-10, gradient from-black/90 via-black/40 to-transparent)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: EdgeInsets.only(bottom: kBottomNavHeight),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                          Colors.black.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 40, 56, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand row: purple icon + name
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: DesignTokens.instaPurple,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                ((item['brandName'] as String?) ?? 'G')[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (item['brandName'] as String?) ?? (item['username'] as String? ?? ''),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text('Sponsored', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                                      Text(' • ', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                                      Icon(LucideIcons.star.localLucide, color: Colors.amber, size: 14),
                                      Text(' ${item['rating']} ', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                                      Text(' • ', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                                      Text('FREE', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Description
                        Text(
                          (item['description'] as String?) ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 14),
                        // View Products (transparent / outline button)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
_showFeaturedProductsSheet(context, products);
                            },
                            icon: Icon(LucideIcons.shoppingBag.localLucide, color: Colors.white, size: 20),
                            label: const Text('View Products', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Install button (dark grey/black)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[900],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: const Text('Install', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFeaturedProductsSheet(BuildContext context, List<dynamic> products) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Text('Featured Products', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: Icon(LucideIcons.x.localLucide, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final prod = products[i] as Map<String, dynamic>;
                  return Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: CachedNetworkImage(
                            imageUrl: (prod['image'] as String?) ?? '',
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Center(child: Icon(LucideIcons.image.localLucide, color: Colors.white54)),
                            errorWidget: (_, __, ___) => Center(child: Icon(LucideIcons.imageOff.localLucide, color: Colors.white54)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(
                            (prod['title'] as String?) ?? 'Product',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ).then((_) => setState(() {}));
  }
}

class _RightAction extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  const _RightAction({required this.icon, this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: Icon(icon, color: Colors.white, size: 28),
          onPressed: onTap,
        ),
        if (label != null)
          Text(label!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
