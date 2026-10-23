// lib/utils/maps_ready_web.dart  (web)
//
// Reads window.google.maps. It is undefined when the
// <script src="https://maps.googleapis.com/maps/api/js?key=..."> tag is
// missing from web/index.html (or was blocked), and GoogleMap would crash with
// "TypeError: Cannot read properties of undefined (reading 'maps')".

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

bool googleMapsReady() {
  final google = globalContext['google'];
  if (google.isUndefinedOrNull) return false;
  final maps = (google as JSObject)['maps'];
  return !maps.isUndefinedOrNull;
}
