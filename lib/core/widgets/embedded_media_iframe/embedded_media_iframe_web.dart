// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final Set<String> _registeredIframeViews = {};

void focusIframe(String viewKey) {
  final viewType = 'elearning-iframe-$viewKey';
  final el = html.document.getElementById(viewType) as html.IFrameElement?;
  el?.focus();
}

Widget buildEmbeddedMediaIframe({
  required String url,
  required String viewKey,
  double? height,
}) {
  final viewType = 'elearning-iframe-$viewKey';

  if (!_registeredIframeViews.contains(viewType)) {
    _registeredIframeViews.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..id = viewType
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.borderRadius = '12px'
        ..style.pointerEvents = 'auto'
        ..style.touchAction = 'manipulation'
        ..allowFullscreen = true
        ..setAttribute('allow',
            'fullscreen; accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share');
      return iframe;
    });
  }

  // NOTE: Jangan gunakan ClipRRect atau BoxDecoration foreground di sini!
  // Pada Flutter Web (CanvasKit), ClipRRect membuat layer canvas di atas iframe
  // yang membajak/menelan semua event klik mouse dan sentuhan jari ke iframe.
  return SizedBox(
    width: double.infinity,
    height: height ?? 420,
    child: HtmlElementView(
      key: ValueKey(viewType),
      viewType: viewType,
    ),
  );
}
