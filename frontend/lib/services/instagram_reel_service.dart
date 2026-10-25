// lib/services/instagram_reel_service.dart
//
// Instagram reels shown on home
//   POST accounts/instagram-reel/list-all/   {}   (public, active reels)
//   POST accounts/instagram-reel/list/       {}   (login – only my own reels)
//   -> {success, data:[{id, reel_link, title, is_active, created_at}]}

import 'api_urls.dart';
import 'qnx_api.dart';
import 'package:qnx_mart/l10n/app_language.dart';

class InstagramReel {
  final int id;
  final String link;
  final String title;
  final bool active;
  final DateTime? createdAt;

  const InstagramReel({
    required this.id,
    required this.link,
    required this.title,
    required this.active,
    required this.createdAt,
  });

  factory InstagramReel.fromJson(Map<String, dynamic> j) => InstagramReel(
        id: qInt(j['id']) ?? 0,
        link: qStr(j['reel_link'] ?? j['link'] ?? j['url']),
        title: qStr(j['title']),
        active: j['is_active'] == null ? true : qBool(j['is_active']),
        createdAt: qDate(j['created_at']),
      );

  /// Instagram account / short code shown when there is no title.
  String get shortLabel {
    final u = Uri.tryParse(link);
    if (u == null) return tr('Instagram reel');
    final parts = u.pathSegments.where((s) => s.isNotEmpty).toList();
    final i = parts.indexWhere((s) => s == 'reel' || s == 'reels' || s == 'p');
    if (i > 0) return '@${parts[i - 1]}';
    return tr('Instagram reel');
  }
}

class InstagramReelService {
  InstagramReelService._();

  /// All active reels (home). Errors → empty list (section hides itself).
  static Future<List<InstagramReel>> all() => _load(ApiUrls.instagramReelsAllUrl, QnxAuth.none);

  /// Only my own reels (needs login).
  static Future<List<InstagramReel>> mine() => _load(ApiUrls.instagramReelsUrl, QnxAuth.required);

  static Future<List<InstagramReel>> _load(String url, QnxAuth auth) async {
    final r = await QnxApi.post(url, const {}, auth: auth);
    if (!r.ok) return const [];
    return r.list
        .map(InstagramReel.fromJson)
        .where((e) => e.active && e.link.startsWith('http'))
        .toList();
  }
}
