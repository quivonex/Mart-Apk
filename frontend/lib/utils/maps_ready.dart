// lib/utils/maps_ready.dart
//
// googleMapsReady(): true when the Google Maps JavaScript API is loaded.
// Mobile (Android / iOS) always returns true; web checks window.google.maps.

export 'maps_ready_stub.dart' if (dart.library.js_interop) 'maps_ready_web.dart';
