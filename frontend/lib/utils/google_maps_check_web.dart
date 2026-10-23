// lib/utils/google_maps_check_web.dart  (web)

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

bool googleMapsLoaded() {
  try {
    final google = globalContext['google'];
    if (google.isUndefinedOrNull) return false;
    final maps = (google as JSObject)['maps'];
    return !maps.isUndefinedOrNull;
  } catch (_) {
    return false;
  }
}
