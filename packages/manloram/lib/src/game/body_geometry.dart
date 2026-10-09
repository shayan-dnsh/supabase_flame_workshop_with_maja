import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../db/supabase_schema.g.dart';

/// The hit shapes of a character, relative to its feet.
class BodyGeometry {
  static final headCenter = Vector2(0, -50);
  static const headRadius = 10.0;
  static const body = Rect.fromLTWH(-11, -40, 22, 40);
  static final shoulder = Vector2(0, -35);
  static const armLength = 16.0;

  /// Where a throw at [aim] leaves the hand.
  static Vector2 handPosition(Vector2 feet, double aim) {
    return feet + shoulder + (Vector2(cos(aim), sin(aim))..scale(armLength));
  }

  /// The part a chub swung by a player at [attackerFeet], aiming at [aim],
  /// hits on a player at [victimFeet]. The swing sweeps the space in front
  /// of the attacker from head to knee; aiming upwards goes for the head.
  static BodyPart? swingHit({
    required Vector2 attackerFeet,
    required double aim,
    required Vector2 victimFeet,
    double reach = 60,
  }) {
    final facing = cos(aim) >= 0 ? 1.0 : -1.0;
    final left = facing > 0 ? attackerFeet.x : attackerFeet.x - reach;
    final sweep = Rect.fromLTWH(left, attackerFeet.y - 66, reach, 52);
    final head = victimFeet + headCenter;
    final headBox = Rect.fromCircle(
      center: Offset(head.x, head.y),
      radius: headRadius,
    );
    final bodyBox = body.shift(Offset(victimFeet.x, victimFeet.y));
    final hitsHead = sweep.overlaps(headBox);
    final hitsBody = sweep.overlaps(bodyBox);
    final aimsHigh = sin(aim) < -0.3;
    if (hitsHead && (aimsHigh || !hitsBody)) {
      return BodyPart.head;
    }
    return hitsBody ? BodyPart.body : null;
  }

  /// The part a projectile of [radius] hits while moving from [from] to [to],
  /// checking the head first so a head graze counts as a headshot. The path
  /// is sampled every few pixels so fast throws cannot tunnel through.
  static BodyPart? hitPart({
    required Vector2 feet,
    required Vector2 from,
    required Vector2 to,
    required double radius,
  }) {
    final steps = max(1, (from.distanceTo(to) / 4).ceil());
    final head = feet + headCenter;
    final bodyRect = body.shift(Offset(feet.x, feet.y));
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final x = from.x + (to.x - from.x) * t;
      final y = from.y + (to.y - from.y) * t;
      final dx = x - head.x;
      final dy = y - head.y;
      if (dx * dx + dy * dy <= pow(headRadius + radius, 2)) {
        return BodyPart.head;
      }
      final nearestX = x.clamp(bodyRect.left, bodyRect.right);
      final nearestY = y.clamp(bodyRect.top, bodyRect.bottom);
      final bx = x - nearestX;
      final by = y - nearestY;
      if (bx * bx + by * by <= radius * radius) {
        return BodyPart.body;
      }
    }
    return null;
  }
}
