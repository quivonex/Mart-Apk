// lib/services/nearby_places_service.dart
//
// Google Places "Nearby Search" through the QNX backend (the Google API key
// stays on the server – it is NOT stored in the app).
// The API needs the login token: `Authorization: Bearer <access token>`
// AND an active Nearby subscription (see nearby_subscription_service.dart).
//
//   POST admin_profile/places/nearby/  {lat, lng, radius(METERS), keyword}
//   200 -> {status:true | "OK", results:[{place_id, name, vicinity, rating, user_ratings_total,
//           geometry{location{lat,lng}}, opening_hours{open_now}, international_phone_number,
//           business_status, types, …}], next_page_token}
//   200 -> {status:false, message:"Keyword is required."}     (validation)
//   401 -> {message:"Session expired."}                        (token removed → login)
//   403 -> {subscription_required:true, message:"No active subscription found…"}
//          (token kept → user buys a plan from the Subscription button)
//
// The backend fetches up to 3 Google pages (≈2 s pause between pages), keeps
// rating ≥ 3.5 and sorts by rating – so a search can take a few seconds.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart' show Color;
import 'package:http/http.dart' as http;
import 'api_urls.dart';
import '../utils/shared_preferences_helper.dart';
import 'nearby_subscription_service.dart';

class NearbyPlace {
  final String placeId;
  final String name;
  final String address;
  final double rating;
  final int ratingsTotal;
  final double lat;
  final double lng;
  final bool? openNow;
  final String phone;
  final String businessStatus;
  final List<String> types;
  final String iconUrl;
  final Color iconBg;

  /// False when geometry.location is missing → listed, but not shown on the map.
  final bool hasLocation;

  /// Distance from the search point in km (set by the service, -1 = unknown).
  double distanceKm;

  NearbyPlace({
    required this.placeId,
    required this.name,
    required this.address,
    required this.rating,
    required this.ratingsTotal,
    required this.lat,
    required this.lng,
    required this.openNow,
    required this.phone,
    required this.businessStatus,
    required this.types,
    required this.iconUrl,
    required this.iconBg,
    this.hasLocation = true,
    this.distanceKm = 0,
  });

  /// Rows without place_id are listed but cannot be opened.
  bool get canOpen => placeId.isNotEmpty;

  bool get isOperational => businessStatus.toUpperCase() == 'OPERATIONAL';

  factory NearbyPlace.fromJson(Map<String, dynamic> j) {
    final loc = (j['geometry'] is Map && j['geometry']['location'] is Map)
        ? Map<String, dynamic>.from(j['geometry']['location'])
        : const <String, dynamic>{};
    final hours = j['opening_hours'] is Map ? Map<String, dynamic>.from(j['opening_hours']) : null;
    Color bg = const Color(0xFF6366F1);
    final hex = '${j['icon_background_color'] ?? ''}'.replaceAll('#', '');
    if (hex.length == 6) {
      final v = int.tryParse('FF$hex', radix: 16);
      if (v != null) bg = Color(v);
    }
    final lat = (loc['lat'] as num?)?.toDouble();
    final lng = (loc['lng'] as num?)?.toDouble();
    final name = '${j['name'] ?? ''}'.trim();
    return NearbyPlace(
      placeId: '${j['place_id'] ?? ''}',
      name: name.isEmpty ? 'Unnamed place' : name,
      address: '${j['vicinity'] ?? j['formatted_address'] ?? ''}',
      rating: (j['rating'] as num?)?.toDouble() ?? 0,
      ratingsTotal: (j['user_ratings_total'] as num?)?.toInt() ?? 0,
      lat: lat ?? 0,
      lng: lng ?? 0,
      hasLocation: lat != null && lng != null,
      openNow: hours?['open_now'] is bool ? hours!['open_now'] as bool : null,
      phone: '${j['international_phone_number'] ?? j['formatted_phone_number'] ?? ''}',
      businessStatus: '${j['business_status'] ?? ''}',
      types: [for (final t in (j['types'] as List? ?? const [])) '$t'],
      iconUrl: '${j['icon'] ?? ''}',
      iconBg: bg,
    );
  }

  /// Opens this exact place in Google Maps (app or browser).
  Uri get mapsUri => Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=${Uri.encodeComponent(placeId)}');

  /// Turn-by-turn directions in Google Maps.
  Uri get directionsUri => Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=${Uri.encodeComponent(placeId)}');

  /// Digits for wa.me (e.g. 919876543210). Empty when the place has no phone.
  String get whatsappNumber {
    var d = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
    if (d.length == 10) d = '91$d';
    return d.length >= 11 ? d : '';
  }

  /// "Moving company" style label from Google types (skips generic ones).
  String get category {
    const skip = {'point_of_interest', 'establishment', 'store', 'premise'};
    final t = types.firstWhere((e) => !skip.contains(e), orElse: () => '');
    if (t.isEmpty) return '';
    final s = t.replaceAll('_', ' ');
    return s[0].toUpperCase() + s.substring(1);
  }
}

class NearbyResult {
  final bool ok;
  final String message;
  final List<NearbyPlace> places;

  /// 401 – session expired, token removed, user must log in again.
  final bool needsLogin;

  /// 403 subscription_required – user must buy a plan (token kept).
  final bool needsSubscription;

  /// Current plan from the backend (searches left etc.), when sent.
  final NearbyActiveSub? plan;
  const NearbyResult(this.ok, this.message, this.places,
      {this.needsLogin = false, this.needsSubscription = false, this.plan});
}

class NearbyPlacesService {
  static double _km(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static Future<NearbyResult> search({
    required double lat,
    required double lng,
    required String keyword,
    int radiusMeters = 10000,
  }) async {
    final token = await SharedPreferencesHelper.getAccessToken();
    if (token == null || token.isEmpty) {
      return const NearbyResult(false, 'Please log in to search nearby places.', [], needsLogin: true);
    }
    final q = keyword.trim();
    if (q.isEmpty) return const NearbyResult(false, 'Keyword is required.', []);
    try {
      final res = await http
          .post(
        Uri.parse(ApiUrls.nearbyPlacesUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'lat': double.parse(lat.clamp(-90.0, 90.0).toStringAsFixed(6)),
          'lng': double.parse(lng.clamp(-180.0, 180.0).toStringAsFixed(6)),
          'radius': radiusMeters.clamp(5000, 50000), // METERS (5–50 km)
          'keyword': q,
        }),
      )
          .timeout(const Duration(seconds: 45));

      Map<String, dynamic> j = {};
      bool parsed = true;
      try {
        final d = jsonDecode(res.body);
        if (d is Map) j = Map<String, dynamic>.from(d);
      } catch (_) {
        parsed = false;
      }
      String msg(String fallback) {
        final m = j['message'] ?? j['error_message'] ?? j['detail'];
        final t = m == null ? '' : '$m'.trim();
        return t.isEmpty ? fallback : t;
      }

      // 401 → session expired: remove token, ask to log in again.
      if (res.statusCode == 401) {
        await SharedPreferencesHelper.clearAll();
        return NearbyResult(false, msg('Your session has expired. Please log in again.'), const [],
            needsLogin: true);
      }
      // 403 → no active subscription: keep the token, show the plans.
      if (res.statusCode == 403) {
        if (j['subscription_required'] == true || j.isEmpty || '${j['message'] ?? ''}'.toLowerCase().contains('subscri')) {
          // Limit used up → the backend sends the plan (remaining 0): save it so the
          // plans screen lets the user buy a new one. No plan at all → forget it.
          NearbyActiveSub? plan;
          if (j['subscription'] is Map) {
            plan = await NearbySubscriptionStore.syncFromServer(Map<String, dynamic>.from(j['subscription']));
          } else {
            await NearbySubscriptionStore.serverSaysNone();
          }
          return NearbyResult(false, msg('No active subscription found. Please purchase a plan.'), const [],
              needsSubscription: true, plan: plan);
        }
        return NearbyResult(false, msg('You are not allowed to use Nearby Search.'), const []);
      }
      if (!parsed) {
        return NearbyResult(false, 'Server error (${res.statusCode}). Please try again.', const []);
      }

      // Option A {status:true} or Option B Google style {status:"OK" | "ZERO_RESULTS"}.
      final st = j['status'];
      final okStatus = st == true || st == 'OK' || st == 'ZERO_RESULTS' || (st == null && j['results'] is List);
      if (res.statusCode < 200 || res.statusCode >= 300 || !okStatus) {
        return NearbyResult(false, msg('Search failed (${res.statusCode}).'), const []);
      }

      final seen = <String>{};
      final places = <NearbyPlace>[];
      for (final e in (j['results'] as List? ?? const []).whereType<Map>()) {
        final p = NearbyPlace.fromJson(Map<String, dynamic>.from(e));
        if (p.placeId.isNotEmpty && !seen.add(p.placeId)) continue; // dedupe
        p.distanceKm = p.hasLocation ? _km(lat, lng, p.lat, p.lng) : -1;
        places.add(p);
      }
      NearbyActiveSub? plan;
      if (j['subscription'] is Map) {
        plan = await NearbySubscriptionStore.syncFromServer(Map<String, dynamic>.from(j['subscription']));
      }
      return NearbyResult(true, '', places, plan: plan);
    } on TimeoutException {
      return const NearbyResult(false, 'The search took too long. Try a smaller radius.', []);
    } catch (e) {
      final s = e.toString();
      return NearbyResult(
        false,
        s.contains('SocketException') || s.contains('ClientException')
            ? 'Could not reach the server.'
            : 'Something went wrong: $s',
        const [],
      );
    }
  }
}
