import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// In a phone browser the address bar takes a large share of a sideways
/// screen. Going fullscreen gives it back, and then the screen can be held
/// sideways. Browsers only allow this right after a tap, and iPhone Safari
/// not at all (there, Add to Home Screen does the job), so a refusal just
/// leaves the page as it is.
Future<void> enterFullscreen() async {
  final document = web.document;
  if (!document.fullscreenEnabled || document.fullscreenElement != null) {
    return;
  }
  try {
    await document.documentElement?.requestFullscreen().toDart;
    await web.window.screen.orientation.lock('landscape').toDart;
  } catch (_) {
    // Not allowed here: play on in the browser window.
  }
}
