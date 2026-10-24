// lib/services/property_edit_service.dart
//
// Real estate › edit my property
//   POST real_estate/property-update/   (multipart)
//     property_id*  + any of: title, description, city, area, address, landmark,
//     pincode, total_area, plot_area, is_negotiable, is_under_construction,
//     ready_to_move, possession_date (YYYY-MM-DD), completion_percentage,
//     rera_number, google_location_url, property_website_url
//     delete_image_ids  JSON list "[3,4]"     images  new files
//   -> {success, message, property_id, data:{PropertyDetail}}
//
// Current values come from RealEstateService.getPropertyDetail(slug).
// Only plain fields are edited here (flat types / floors / price slabs stay
// as they are). Token is sent so the backend can check the owner once it
// adds authentication.

import 'api_urls.dart';
import 'qnx_api.dart';

class PropertyEditResult {
  final bool ok;
  final String message;
  final bool needsLogin;
  const PropertyEditResult(this.ok, this.message, {this.needsLogin = false});
}

class PropertyEditService {
  PropertyEditService._();

  static Future<PropertyEditResult> update({
    required int propertyId,
    required Map<String, String?> fields,
    List<int> deleteImageIds = const [],
    List<QnxFile> newImages = const [],
  }) async {
    final body = <String, String?>{
      'property_id': '$propertyId',
      ...fields,
      'delete_image_ids': deleteImageIds.isEmpty ? null : '[${deleteImageIds.join(',')}]',
    };
    final files = [for (final f in newImages) QnxFile('images', f.name, f.bytes)];
    final r = await QnxApi.multipart(ApiUrls.propertyUpdateUrl, body, files);
    if (!r.ok) {
      return PropertyEditResult(false, r.error('Could not save your changes.'), needsLogin: r.authFailed);
    }
    final msg = qStr(r.map['message']);
    return PropertyEditResult(true, msg.isEmpty ? 'Property updated.' : msg);
  }
}
