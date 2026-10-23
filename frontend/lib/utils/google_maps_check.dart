// lib/utils/google_maps_check.dart
//
// googleMapsLoaded() – true when the Google Maps SDK can be used.
//   • Android / iOS → always true
//   • Web           → true only when window.google.maps exists
//                     (Maps <script> tag present in web/index.html)

export 'google_maps_check_stub.dart' if (dart.library.js_interop) 'google_maps_check_web.dart';
