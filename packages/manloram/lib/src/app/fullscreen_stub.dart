import 'package:flutter/services.dart';

/// On an installed app: hide the system bars and keep the phone sideways.
Future<void> enterFullscreen() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}
