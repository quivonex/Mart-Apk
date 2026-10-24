// lib/services/remart_edit_service.dart
//
// QNX ReMart › edit my listing
//
//   POST olx/listings/update/   (multipart, Bearer token, owner only)
//     listing_id*            + any of: title, description, price, is_negotiable,
//     condition (new|like_new|good|fair|used), seller_type (individual|business),
//     city, area, address, pincode, latitude, longitude,
//     attributes (JSON string), status, category_id, subcategory_id
//     delete_image_ids       JSON list "[12,13]"
//     images                 new files (first image becomes primary if none left)
//   -> {success, message, data:{id, …, images:[{id, image_s3_key, image_url, is_primary, sort_order}]}}
//
// "Load for edit" sends only listing_id: the backend saves nothing new and
// returns the full listing with ready image URLs (olx/my-listings/ gives only
// image_s3_key, so this is how the edit screen gets the photos).
//
// RemartImageBase learns the S3 base URL from any response that has both
// image_s3_key and image_url, so "My items" thumbnails work from the key alone.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_urls.dart';
import 'qnx_api.dart';

class RemartEditImage {
  final int id;
  final String url;
  final bool primary;
  const RemartEditImage(this.id, this.url, this.primary);
}

class RemartEditData {
  final int id;
  final String title;
  final String description;
  final double price;
  final bool negotiable;
  final String condition;
  final String sellerType;
  final String city;
  final String area;
  final String address;
  final String pincode;
  final String status;
  final String categoryName;
  final String subcategoryName;
  final Map<String, dynamic> attributes;
  final List<RemartEditImage> images;

  const RemartEditData({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.negotiable,
    required this.condition,
    required this.sellerType,
    required this.city,
    required this.area,
    required this.address,
    required this.pincode,
    required this.status,
    required this.categoryName,
    required this.subcategoryName,
    required this.attributes,
    required this.images,
  });

  factory RemartEditData.fromJson(Map<String, dynamic> j) {
    final imgs = <RemartEditImage>[];
    for (final m in (j['images'] as List? ?? const []).whereType<Map>()) {
      final key = qStr(m['image_s3_key']);
      var url = qStr(m['image_url']);
      if (key.isNotEmpty && url.startsWith('http')) RemartImageBase.learn(key, url);
      if (!url.startsWith('http')) url = RemartImageBase.url(key) ?? '';
      final id = qInt(m['id']);
      if (id != null && url.isNotEmpty) imgs.add(RemartEditImage(id, url, m['is_primary'] == true));
    }
    imgs.sort((a, b) => (b.primary ? 1 : 0) - (a.primary ? 1 : 0));
    return RemartEditData(
      id: qInt(j['id']) ?? 0,
      title: qStr(j['title']),
      description: qStr(j['description']),
      price: qDbl(j['price']),
      negotiable: qBool(j['is_negotiable']),
      condition: qStr(j['condition']),
      sellerType: qStr(j['seller_type']),
      city: qStr(j['city']),
      area: qStr(j['area']),
      address: qStr(j['address']),
      pincode: qStr(j['pincode']),
      status: qStr(j['status']),
      categoryName: qStr(j['category_name']),
      subcategoryName: qStr(j['subcategory_name']),
      attributes: j['attributes'] is Map ? Map<String, dynamic>.from(j['attributes']) : <String, dynamic>{},
      images: imgs,
    );
  }
}

class RemartEditResult<T> {
  final bool ok;
  final T? data;
  final String message;
  final bool needsLogin;
  const RemartEditResult(this.ok, this.data, this.message, {this.needsLogin = false});
}

class RemartEditService {
  RemartEditService._();

  /// Current values of my listing (sends only listing_id → nothing changes).
  static Future<RemartEditResult<RemartEditData>> load(int listingId) async {
    final r = await QnxApi.multipart(ApiUrls.remartListingUpdateUrl, {'listing_id': '$listingId'}, const []);
    if (!r.ok) {
      return RemartEditResult(false, null, r.error('Could not load this item.'), needsLogin: r.authFailed);
    }
    return RemartEditResult(true, RemartEditData.fromJson(r.dataMap), '');
  }

  /// Saves changed fields. Only non-null values are sent.
  static Future<RemartEditResult<RemartEditData>> update({
    required int listingId,
    String? title,
    String? description,
    double? price,
    bool? negotiable,
    String? condition,
    String? sellerType,
    String? city,
    String? area,
    String? address,
    String? pincode,
    Map<String, dynamic>? attributes,
    String? status,
    List<int> deleteImageIds = const [],
    List<QnxFile> newImages = const [],
  }) async {
    String? price0;
    if (price != null) {
      price0 = price == price.roundToDouble() ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
    }
    final fields = <String, String?>{
      'listing_id': '$listingId',
      'title': title,
      'description': description,
      'price': price0,
      'is_negotiable': negotiable == null ? null : (negotiable ? 'true' : 'false'),
      'condition': condition,
      'seller_type': sellerType,
      'city': city,
      'area': area,
      'address': address,
      'pincode': pincode,
      'attributes': attributes == null ? null : _json(attributes),
      'status': status,
      'delete_image_ids': deleteImageIds.isEmpty ? null : '[${deleteImageIds.join(',')}]',
    };
    final files = [for (final f in newImages) QnxFile('images', f.name, f.bytes)];
    final r = await QnxApi.multipart(ApiUrls.remartListingUpdateUrl, fields, files);
    if (!r.ok) {
      return RemartEditResult(false, null, r.error('Could not save your changes.'), needsLogin: r.authFailed);
    }
    final msg = qStr(r.map['message']);
    return RemartEditResult(
      true,
      RemartEditData.fromJson(r.dataMap),
      msg.isEmpty ? 'Item updated.' : msg,
    );
  }

  /// "Mark as sold" shortcut.
  static Future<RemartEditResult<RemartEditData>> markSold(int listingId) =>
      update(listingId: listingId, status: 'sold');

  static String _json(Map<String, dynamic> m) => jsonEncode(m);
}

/// S3 base for ReMart images ("https://bucket.s3.region.amazonaws.com/").
class RemartImageBase {
  RemartImageBase._();

  static const _prefKey = 'remart_image_base';
  static String? _base;
  static bool _loaded = false;

  static String? get value {
    if (_base != null && _base!.isNotEmpty) return _base;
    final cfg = ApiUrls.s3BaseUrl;
    if (cfg.startsWith('http') && !cfg.contains('YOUR_BUCKET')) {
      return cfg.endsWith('/') ? cfg : '$cfg/';
    }
    return null;
  }

  /// Full URL for an S3 key, or null when the base is not known yet.
  static String? url(String key) {
    if (key.isEmpty) return null;
    if (key.startsWith('http')) return key;
    final b = value;
    if (b == null) return null;
    return '$b${key.startsWith('/') ? key.substring(1) : key}';
  }

  /// Remember the base from a (key, url) pair.
  static void learn(String key, String url) {
    if (key.isEmpty || !url.endsWith(key)) return;
    final b = url.substring(0, url.length - key.length);
    if (!b.startsWith('http') || b == _base) return;
    _base = b;
    SharedPreferences.getInstance().then((p) => p.setString(_prefKey, b)).catchError((_) => false);
  }

  /// Loads the saved base; if still unknown, reads one public listing page
  /// (olx/listings/ returns both key and url) to learn it.
  static Future<void> ensure() async {
    if (!_loaded) {
      _loaded = true;
      try {
        final p = await SharedPreferences.getInstance();
        final s = p.getString(_prefKey);
        if (s != null && s.startsWith('http')) _base = s;
      } catch (_) {}
    }
    if (value != null) return;
    final r = await QnxApi.post('${ApiUrls.baseUrl}/olx/listings/', const {}, auth: QnxAuth.none);
    for (final l in r.list) {
      for (final m in (l['images'] as List? ?? const []).whereType<Map>()) {
        final key = qStr(m['image_s3_key']);
        final u = qStr(m['image_url']);
        if (key.isNotEmpty && u.startsWith('http')) {
          learn(key, u);
          return;
        }
      }
    }
  }
}
