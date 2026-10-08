// lib/screens/product_reels_screen.dart
//
// "Live Reels & Demos" full-screen player: vertical swipe between product
// videos (Product.videos from product/approved-list/), tap to pause/play,
// product info + Enquiry / Cart at the bottom.

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../constants/design_tokens.dart';
import '../models/product_model.dart';
import '../utils/cart_helper.dart';
import 'product_enquiry_screen.dart';

class ReelItem {
  final Product product;
  final String videoUrl;
  const ReelItem(this.product, this.videoUrl);
}

/// One reel per product video.
List<ReelItem> buildReels(List<Product> products) => [
  for (final p in products)
    for (final v in p.videos) ReelItem(p, v),
];

class ProductReelsScreen extends StatefulWidget {
  final List<ReelItem> reels;
  final int initialIndex;

  const ProductReelsScreen({super.key, required this.reels, this.initialIndex = 0});

  @override
  State<ProductReelsScreen> createState() => _ProductReelsScreenState();
}

class _ProductReelsScreenState extends State<ProductReelsScreen> {
  late final PageController _page = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            scrollDirection: Axis.vertical,
            itemCount: widget.reels.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _ReelPage(item: widget.reels[i], active: i == _index),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                  Text('Live Reels & Demos',
                      style: DT.text(size: 16, weight: FontWeight.w700, color: Colors.white)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('${_index + 1}/${widget.reels.length}',
                        style: DT.text(size: 12, weight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelPage extends StatefulWidget {
  final ReelItem item;
  final bool active;
  const _ReelPage({required this.item, required this.active});

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  VideoPlayerController? _c;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _init();
  }

  @override
  void didUpdateWidget(covariant _ReelPage old) {
    super.didUpdateWidget(old);
    if (widget.active && _c == null) {
      _init();
    } else if (widget.active) {
      _c?.play();
    } else {
      _c?.pause();
    }
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.item.videoUrl));
    _c = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      if (!mounted) return;
      setState(() {});
      if (widget.active) c.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  void _toggle() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    // setState must not return a Future, so play/pause happens outside it.
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.item.product;
    final c = _c;
    final ready = c != null && c.value.isInitialized;

    return GestureDetector(
      onTap: _toggle,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ready)
            Center(
              child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
            )
          else
            Stack(
              fit: StackFit.expand,
              children: [
                if (p.thumbnail.isNotEmpty)
                  Opacity(
                    opacity: 0.5,
                    child: Image.network(p.thumbnail,
                        fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                  ),
                Center(
                  child: _failed
                      ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 40),
                      const SizedBox(height: 8),
                      Text('Video could not be played',
                          style: DT.text(size: 13, color: Colors.white70)),
                    ],
                  )
                      : const CircularProgressIndicator(color: Colors.white),
                ),
              ],
            ),
          if (ready && !c.value.isPlaying)
            const Center(
              child: CircleAvatar(
                radius: 34,
                backgroundColor: Colors.black45,
                child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 44),
              ),
            ),
          // bottom info
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  16, 40, 16, 16 + MediaQuery.of(context).padding.bottom),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ready)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: VideoProgressIndicator(
                        c,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ),
                  Text(p.categoryName.toUpperCase(),
                      style: DT.text(
                          size: 11, weight: FontWeight.w700, color: Colors.white70, letterSpacing: 0.6)),
                  const SizedBox(height: 4),
                  Text(p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 18, weight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('₹${p.finalPrice}',
                      style: DT.text(size: 16, weight: FontWeight.w800, color: const Color(0xFFFFD54F))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ProductEnquiryScreen(product: p)),
                          ),
                          icon: const Icon(Icons.mail_outline_rounded, size: 18),
                          label: Text('Enquiry',
                              style: DT.text(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70),
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => CartHelper.addToCart(context: context, product: p),
                          icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                          label: Text('Cart',
                              style: DT.text(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D6BF3),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}