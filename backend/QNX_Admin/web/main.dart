// 📍 File: battery_regeneration_system/web/main.dart

import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:google_maps_flutter_web/google_maps_flutter_web.dart';
import 'package:battery_regeneration_system/main.dart' as app;
import 'package:universal_html/html.dart' as html;

void main() {
  // ✅ Use path URL strategy (for web routing)
  usePathUrlStrategy();

  // ✅ Google Maps Web Plugin Register करा
  // हे web वर Google Maps काम करण्यासाठी necessary आहे
  try {
    // Web Google Maps Factory register करा
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      'google-maps-iframe',
          (int viewId) {
        final html.IFrameElement iframe = html.IFrameElement()
          ..width = '100%'
          ..height = '100%'
          ..style.border = 'none'
          ..src = 'about:blank';
        return iframe;
      },
    );
    print('✅ Google Maps Web Plugin registered successfully!');
  } catch (e) {
    print('❌ Error registering Google Maps Web Plugin: $e');
  }

  // ✅ App run करा
  app.main();
}