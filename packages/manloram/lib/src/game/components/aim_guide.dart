import 'dart:ui';

import 'package:flame/components.dart';

import '../manloram_game.dart';
import '../throw_physics.dart';

/// While charging, dots trace the first part of the arc. The rest is up to
/// the thrower's eye.
class AimGuide extends Component with HasGameRef<ManLoramGame> {
  AimGuide() : super(priority: 20);

  @override
  void render(Canvas canvas) {
    final me = gameRef.me;
    if (me == null || !me.charging || me.knockedOut) {
      return;
    }
    final velocity = ThrowPhysics.launchVelocity(
      me.aim,
      me.power,
      me.weapon.speed,
    );
    final points = ThrowPhysics.preview(me.hand, velocity, wind: gameRef.wind);
    for (var i = 0; i < points.length; i++) {
      final alpha = 0.9 - i * 0.08;
      canvas.drawCircle(
        points[i].toOffset(),
        2.6,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
      );
    }
  }
}
