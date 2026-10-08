// lib/widgets/auto_image_carousel.dart
//
// Photo carousel for property / ReMart cards:
//   * changes photo automatically (only when there is more than one)
//   * "1/2" counter, ‹ › arrows, dots
//   * [bottomInset] keeps arrows and dots above an overlay panel at the bottom
//   * each carousel starts at a slightly different time so a grid of cards
//     doesn't flip all at once

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class AutoImageCarousel extends StatefulWidget {
  final List<String> images;
  final Duration interval;
  final double bottomInset;
  final bool showArrows;
  final IconData placeholderIcon;
  final VoidCallback? onTap;

  const AutoImageCarousel({
    super.key,
    required this.images,
    this.interval = const Duration(milliseconds: 3500),
    this.bottomInset = 0,
    this.showArrows = true,
    this.placeholderIcon = Icons.image_outlined,
    this.onTap,
  });

  @override
  State<AutoImageCarousel> createState() => _AutoImageCarouselState();
}

class _AutoImageCarouselState extends State<AutoImageCarousel> {
  static final _rnd = Random();
  final _page = PageController();
  Timer? _timer;
  Timer? _startDelay;
  int _index = 0;

  int get _count => widget.images.length;

  @override
  void initState() {
    super.initState();
    // Stagger the first tick (0–1.5 s) so neighbouring cards differ.
    _startDelay = Timer(Duration(milliseconds: _rnd.nextInt(1500)), _start);
  }

  @override
  void didUpdateWidget(covariant AutoImageCarousel old) {
    super.didUpdateWidget(old);
    if (old.images.length != widget.images.length) {
      _index = 0;
      if (_page.hasClients) _page.jumpToPage(0);
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    if (!mounted || _count < 2) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || !_page.hasClients) return;
      _page.animateToPage((_index + 1) % _count,
          duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }

  void _go(int dir) {
    if (!_page.hasClients || _count < 2) return;
    _page.animateToPage((_index + dir + _count) % _count,
        duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    _start(); // restart the timer after a manual change
  }

  @override
  void dispose() {
    _startDelay?.cancel();
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFE9EEF5),
    alignment: Alignment.center,
    child: Icon(widget.placeholderIcon, size: 44, color: const Color(0xFFB6C2D3)),
  );

  @override
  Widget build(BuildContext context) {
    if (_count == 0) {
      return GestureDetector(onTap: widget.onTap, child: _placeholder());
    }

    return LayoutBuilder(builder: (context, c) {
      final arrowsTop = (c.maxHeight - widget.bottomInset) / 2 - 18;
      return Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<ScrollStartNotification>(
              onNotification: (n) {
                if (n.dragDetails != null) _start(); // user swiped: reset timer
                return false;
              },
              child: PageView.builder(
                controller: _page,
                itemCount: _count,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: widget.onTap,
                  child: Image.network(
                    widget.images[i],
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, p) => p == null ? child : _placeholder(),
                    errorBuilder: (_, __, ___) => _placeholder(),
                  ),
                ),
              ),
            ),
          ),
          if (_count > 1) ...[
            // counter
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${_index + 1} / $_count',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
            if (widget.showArrows) ...[
              Positioned(left: 8, top: arrowsTop, child: _arrow(Icons.chevron_left_rounded, -1)),
              Positioned(right: 8, top: arrowsTop, child: _arrow(Icons.chevron_right_rounded, 1)),
            ],
            // dots
            Positioned(
              left: 0,
              right: 0,
              bottom: widget.bottomInset + 8,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < _count; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: i == _index ? 8 : 6,
                          height: i == _index ? 8 : 6,
                          decoration: BoxDecoration(
                            color: i == _index ? Colors.white : Colors.white60,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _arrow(IconData icon, int dir) => Material(
    color: Colors.black.withValues(alpha: 0.4),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: () => _go(dir),
      child: SizedBox(width: 36, height: 36, child: Icon(icon, color: Colors.white, size: 24)),
    ),
  );
}