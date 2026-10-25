// lib/screens/property_video_screen.dart
//
// QNX Mart › Real Estate › Property video tour.
//
//   • Plays PropertyDetail.videos (video_s3_key URLs) with video_player
//     (works on Android, iOS and web).
//   • Playlist when the property has more than one video.
//   • If a video cannot be played in-app, "Open in browser" uses url_launcher.
//
// Open it from anywhere:
//   PropertyVideoScreen.openForSlug(context, slug: p.slug, title: p.displayTitle);
//   Navigator.push(context, MaterialPageRoute(builder: (_) =>
//       PropertyVideoScreen(videos: detail.videos, title: detail.title)));

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../constants/design_tokens.dart';
import '../models/property_model.dart';
import '../services/real_estate_service.dart';
import 'package:qnx_mart/l10n/app_language.dart';
// ── QNX MART logo colours (private to this screen) ──────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions
const _kBrand = Color(0xFF093C71);
const _kBrandDark = Color(0xFF062A50);
const _kBrandLight = Color(0xFF1E5A9C);
const _kRed = Color(0xFFC62828);
const _kHeader = LinearGradient(
  colors: [_kBrandDark, _kBrand, _kBrandLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class _V {
  static const ink = Color(0xFF04111F);
  static const panel = Color(0xFF0B1E33);
  static const panelLine = Color(0xFF1C3552);
  static const brand = Color(0xFF093C71);
  static const violet = Color(0xFF1E5A9C);
  static const orange = Color(0xFFF7931E);
  static const muted = Color(0xFF9DB0C6);
}

class PropertyVideoScreen extends StatefulWidget {
  final List<PropertyVideo> videos;
  final String title;
  final String? subtitle;
  final int initialIndex;

  const PropertyVideoScreen({
    super.key,
    required this.videos,
    required this.title,
    this.subtitle,
    this.initialIndex = 0,
  });

  /// Loads the property detail (videos live there) and opens the player.
  /// Shows a friendly message when the property has no video yet.
  static Future<void> openForSlug(
      BuildContext context, {
        required String slug,
        required String title,
        String? subtitle,
      }) async {
    if (slug.isEmpty) return;
    final nav = Navigator.of(context);
    final rootNav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
    final r = await RealEstateService.getPropertyDetail(slug);
    rootNav.pop();
    final videos = r.data?.videos
        .where((v) => v.videoS3Key.trim().isNotEmpty)
        .toList() ??
        const <PropertyVideo>[];
    if (!r.isSuccess || r.data == null) {
      messenger.showSnackBar(SnackBar(
        content: Text(r.message ?? tr('Could not load the video')),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (videos.isEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text(tr('No video tour has been uploaded for this property yet.')),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    nav.push(MaterialPageRoute(
      builder: (_) => PropertyVideoScreen(
        videos: videos,
        title: tr(title),
        subtitle: trN(subtitle),
      ),
    ));
  }

  @override
  State<PropertyVideoScreen> createState() => _PropertyVideoScreenState();
}

class _PropertyVideoScreenState extends State<PropertyVideoScreen> {
  VideoPlayerController? _ctrl;
  late int _index;
  bool _loading = true;
  String? _error;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _index = widget.videos.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.videos.length - 1);
    _load(_index);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _ctrl?.removeListener(_tick);
    _ctrl?.dispose();
    super.dispose();
  }

  String get _url =>
      widget.videos.isEmpty ? '' : widget.videos[_index].videoS3Key.trim();

  Future<void> _load(int i) async {
    _hideTimer?.cancel();
    final old = _ctrl;
    old?.removeListener(_tick);
    setState(() {
      _index = i;
      _loading = true;
      _error = null;
      _ctrl = null;
      _showControls = true;
    });
    await old?.dispose();
    if (widget.videos.isEmpty) {
      setState(() {
        _loading = false;
        _error = tr('No video available.');
      });
      return;
    }
    final uri = Uri.tryParse(_url);
    if (uri == null || !uri.hasScheme) {
      setState(() {
        _loading = false;
        _error = tr('This video link is not valid.');
      });
      return;
    }
    final c = VideoPlayerController.networkUrl(uri);
    try {
      await c.initialize().timeout(const Duration(seconds: 40));
      if (!mounted || _index != i) {
        await c.dispose();
        return;
      }
      c.addListener(_tick);
      await c.play();
      setState(() {
        _ctrl = c;
        _loading = false;
      });
      _scheduleHide();
    } catch (_) {
      await c.dispose();
      if (!mounted || _index != i) return;
      setState(() {
        _loading = false;
        _error = tr('This video could not be played here.');
      });
    }
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_ctrl?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  void _togglePlay() {
    final c = _ctrl;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
      _hideTimer?.cancel();
      setState(() => _showControls = true);
    } else {
      if (c.value.position >= c.value.duration &&
          c.value.duration > Duration.zero) {
        c.seekTo(Duration.zero);
      }
      c.play();
      _scheduleHide();
    }
  }

  void _seekBy(int seconds) {
    final c = _ctrl;
    if (c == null) return;
    var target = c.value.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > c.value.duration) target = c.value.duration;
    c.seekTo(target);
    _scheduleHide();
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(_url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Could not open the video link'))),
      );
    }
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _videoName(int i) {
    final t = widget.videos[i].title.trim();
    return t.isNotEmpty ? t : tr('Video tour {0}', [i + 1]);
  }

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _V.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: _kHeader)),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trData(widget.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DT.text(
                    size: 15.5, weight: FontWeight.w700, color: Colors.white)),
            Text(
                widget.subtitle?.isNotEmpty == true
                    ? widget.subtitle!
                    : tr('Video tour'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DT.text(size: 11.5, color: const Color(0xCCFFFFFF))),
          ],
        ),
        actions: [
          if (_url.isNotEmpty)
            IconButton(
              tooltip: tr('Open in browser'),
              onPressed: _openExternally,
              icon: const Icon(Icons.open_in_new_rounded),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _player(),
            Expanded(child: _details()),
          ],
        ),
      ),
    );
  }

  Widget _player() {
    final c = _ctrl;
    final ratio = (c != null && c.value.isInitialized && c.value.aspectRatio > 0)
        ? c.value.aspectRatio
        : 16 / 9;
    final screenH = MediaQuery.of(context).size.height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenH * 0.6),
      child: AspectRatio(
        aspectRatio: ratio < 0.8 ? 0.8 : ratio,
        child: Container(
          color: Colors.black,
          child: _loading
              ? const Center(
            child: CircularProgressIndicator(color: _V.brand),
          )
              : _error != null
              ? _errorView()
              : c == null
              ? const SizedBox.shrink()
              : _surface(c),
        ),
      ),
    );
  }

  Widget _surface(VideoPlayerController c) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _showControls = !_showControls);
        if (_showControls) _scheduleHide();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio:
              c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9,
              child: VideoPlayer(c),
            ),
          ),
          if (c.value.isBuffering)
            const Center(
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5),
            ),
          AnimatedOpacity(
            opacity: _showControls ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_showControls,
              child: _controls(c),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls(VideoPlayerController c) {
    final v = c.value;
    final total = v.duration.inMilliseconds.toDouble();
    final pos = v.position.inMilliseconds
        .clamp(0, total <= 0 ? 0 : total.toInt())
        .toDouble();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x55000000), Color(0x00000000), Color(0xAA000000)],
          stops: [0, 0.45, 1],
        ),
      ),
      child: Column(
        children: [
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _roundBtn(Icons.replay_10_rounded, () => _seekBy(-10), 44),
              const SizedBox(width: 22),
              _roundBtn(
                v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                _togglePlay,
                62,
                filled: true,
              ),
              const SizedBox(width: 22),
              _roundBtn(Icons.forward_10_rounded, () => _seekBy(10), 44),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 4),
            child: Row(
              children: [
                Text(tr(_fmt(v.position)),
                    style: DT.text(
                        size: 11, weight: FontWeight.w600, color: Colors.white)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: _V.orange,
                      inactiveTrackColor: const Color(0x55FFFFFF),
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: pos,
                      min: 0,
                      max: total <= 0 ? 1 : total,
                      onChanged: total <= 0
                          ? null
                          : (x) {
                        c.seekTo(Duration(milliseconds: x.toInt()));
                        _scheduleHide();
                      },
                    ),
                  ),
                ),
                Text(tr(_fmt(v.duration)),
                    style: DT.text(
                        size: 11, weight: FontWeight.w600, color: Colors.white)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: v.volume == 0 ? tr('Unmute') : tr('Mute'),
                  onPressed: () => c.setVolume(v.volume == 0 ? 1 : 0),
                  icon: Icon(
                    v.volume == 0
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap, double size,
      {bool filled = false}) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? _kBrand : const Color(0x33FFFFFF),
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.52),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0x22C62828),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_off_rounded,
                  color: Color(0xFFFCA5A5), size: 28),
            ),
            const SizedBox(height: 12),
            Text(_error ?? tr('Something went wrong'),
                textAlign: TextAlign.center,
                style: DT.text(
                    size: 13.5, weight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _load(_index),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(tr('Retry')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x66FFFFFF)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (_url.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _openExternally,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text(tr('Open in browser')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBrand, // buttons: only #093C71
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _details() {
    final many = widget.videos.length > 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_V.brand, _V.violet]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_fill_rounded,
                      size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(tr('VIDEO TOUR'),
                      style: DT.text(
                          size: 9.5,
                          weight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8)),
                ],
              ),
            ),
            const Spacer(),
            if (many)
              Text('${_index + 1} of ${widget.videos.length}',
                  style: DT.text(
                      size: 11.5, weight: FontWeight.w600, color: _V.muted)),
          ],
        ),
        const SizedBox(height: 10),
        if (widget.videos.isNotEmpty)
          Text(tr(_videoName(_index)),
              style: DT.text(
                  size: 17, weight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 4),
        Text(tr('Tap the video to show or hide controls.'),
            style: DT.text(size: 12, color: _V.muted)),
        if (many) ...[
          const SizedBox(height: 20),
          Text(tr('All videos'),
              style: DT.text(
                  size: 13, weight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 10),
          for (var i = 0; i < widget.videos.length; i++) ...[
            _playlistTile(i),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _playlistTile(int i) {
    final active = i == _index;
    return Material(
      color: active ? const Color(0xFF062A50) : _V.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: active ? null : () => _load(i),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? _V.brand : _V.panelLine),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF062A50), Color(0xFF093C71)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  active
                      ? Icons.graphic_eq_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(tr(_videoName(i)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(
                        size: 13,
                        weight: FontWeight.w700,
                        color: active ? Colors.white : const Color(0xFFC9DBEE))),
              ),
              if (active)
                Text(tr('Playing'),
                    style: DT.text(
                        size: 11, weight: FontWeight.w700, color: _V.orange)),
            ],
          ),
        ),
      ),
    );
  }
}
