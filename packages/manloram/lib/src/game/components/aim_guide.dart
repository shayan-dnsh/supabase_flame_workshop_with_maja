import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../manloram_game.dart';
import '../throw_physics.dart';

/// While charging, dots trace the first part of the arc. The rest is up to
/// the thrower's eye. A ring at the hand fills with the charge and pulses
/// once it is full, since holding longer adds nothing.
class AimGuide extends Component with HasGameRef<ManLoramGame> {
  AimGuide() : super(priority: 20);

  static const _ringRadius = 9.0;
  static const _full = Color(0xFFE6A23C);

  double _time = 0;

  @override
  void update(double dt) {
    _time += dt;
  }

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

    final hand = me.hand.toOffset();
    final charge = ThrowPhysics.chargeFor(me.heldSeconds);
    if (charge < 1) {
      canvas.drawArc(
        Rect.fromCircle(center: hand, radius: _ringRadius),
        -pi / 2,
        2 * pi * charge,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85),
      );
      return;
    }
    final pulse = sin(_time * 14).abs();
    canvas.drawCircle(
      hand,
      _ringRadius + 3 * pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _full.withValues(alpha: 0.6 + 0.4 * pulse),
    );
  }
}
