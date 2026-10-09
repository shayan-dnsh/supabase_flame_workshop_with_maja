import 'dart:math';

import '../game_config.dart';

/// What the movement stick on a phone asks for. [x] and [y] are where the
/// thumb is, from -1 to 1 across the stick, with y growing downwards.
/// Sideways walks, up jumps (and keeps hopping while held), down drops off
/// a ledge: one thumb does what A, D, W and S do on a keyboard.
class MoveStick {
  const MoveStick._({
    required this.direction,
    required this.jump,
    required this.drop,
  });

  factory MoveStick.at(double x, double y) {
    const walk = GameConfig.stickWalkThreshold;
    return MoveStick._(
      direction: x > walk
          ? 1
          : x < -walk
          ? -1
          : 0,
      jump: y < -GameConfig.stickJumpThreshold,
      drop: y > GameConfig.stickDropThreshold,
    );
  }

  static const idle = MoveStick._(direction: 0, jump: false, drop: false);

  /// -1 walks left, 1 walks right.
  final int direction;
  final bool jump;
  final bool drop;
}

/// The aiming stick on a phone: the direction the thumb pushes is the
/// direction of the throw, so the finger never covers the target. Near the
/// centre it means nothing, which lets a player cancel a throw by sliding
/// back before lifting.
class AimStick {
  /// The throw's angle for a thumb at [x], [y], or null inside the dead zone.
  static double? angle(double x, double y) {
    if (x * x + y * y <
        GameConfig.stickAimDeadZone * GameConfig.stickAimDeadZone) {
      return null;
    }
    return atan2(y, x);
  }
}
