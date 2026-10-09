import 'dart:math';

import 'package:flame/components.dart';

import '../game_config.dart';

class ThrowPhysics {
  /// How full the charge is after holding the throw for [heldSeconds], from
  /// 0 to 1. At 1 holding longer adds nothing, so the game shows it.
  static double chargeFor(double heldSeconds) {
    return (heldSeconds / GameConfig.chargeSeconds).clamp(0.0, 1.0);
  }

  /// Launch power after holding the throw for [heldSeconds]: a tap still
  /// throws, a full charge takes [GameConfig.chargeSeconds].
  static double powerFor(double heldSeconds) {
    return GameConfig.minPower +
        (1 - GameConfig.minPower) * chargeFor(heldSeconds);
  }

  static Vector2 launchVelocity(double aim, double power, double speed) {
    return Vector2(cos(aim), sin(aim))..scale(speed * power);
  }

  /// Where a throw is after [seconds]; [wind] pushes it sideways in px/s².
  static Vector2 positionAt(
    Vector2 start,
    Vector2 velocity,
    double seconds, {
    double wind = 0,
  }) {
    return Vector2(
      start.x + velocity.x * seconds + 0.5 * wind * seconds * seconds,
      start.y +
          velocity.y * seconds +
          0.5 * GameConfig.gravity * seconds * seconds,
    );
  }

  /// Points along the start of the arc, for the aiming guide.
  static List<Vector2> preview(
    Vector2 start,
    Vector2 velocity, {
    double seconds = GameConfig.aimPreviewSeconds,
    int steps = 9,
    double wind = 0,
  }) {
    return [
      for (var i = 1; i <= steps; i++)
        positionAt(start, velocity, seconds * i / steps, wind: wind),
    ];
  }
}
