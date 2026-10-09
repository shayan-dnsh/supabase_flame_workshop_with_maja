import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../body_geometry.dart';
import '../manloram_game.dart';

/// The practice target: a scarecrow pacing the right side of the arena,
/// with the same head and body as a player.
class Scarecrow extends PositionComponent with HasGameRef<ManLoramGame> {
  Scarecrow({required super.position}) : super(priority: 9);

  static const _speed = 45.0;

  double _direction = -1;
  double _wobble = 0;

  @override
  void update(double dt) {
    final (minX, maxX) = gameRef.arena.scarecrowWalk;
    position.x += _direction * _speed * dt;
    if (position.x < minX || position.x > maxX) {
      _direction = -_direction;
      position.x = position.x.clamp(minX, maxX);
    }
    _wobble = max(0, _wobble - dt);
    gameRef.checkScarecrowHits(this);
  }

  void wobble() {
    _wobble = 0.4;
  }

  @override
  void render(Canvas canvas) {
    canvas
      ..save()
      ..rotate(sin(_wobble * 30) * _wobble * 0.5);
    final wood = Paint()
      ..color = const Color(0xFF6D4C2F)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final straw = Paint()..color = const Color(0xFFD9B44A);
    canvas
      ..drawLine(Offset.zero, const Offset(0, -44), wood)
      ..drawLine(const Offset(-20, -34), const Offset(20, -34), wood)
      ..drawRRect(
        RRect.fromRectAndRadius(
          BodyGeometry.body.deflate(1).translate(0, -1),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0xFF9C7A54),
      );
    for (final dx in [-20.0, 20.0]) {
      canvas.drawCircle(Offset(dx, -34), 4, straw);
    }
    final head = BodyGeometry.headCenter.toOffset();
    canvas
      ..drawCircle(
        head,
        BodyGeometry.headRadius,
        Paint()..color = const Color(0xFFCBB089),
      )
      ..drawCircle(
        head + const Offset(-3.5, -1),
        1.5,
        Paint()..color = const Color(0xFF3B2F2F),
      )
      ..drawCircle(
        head + const Offset(3.5, -1),
        1.5,
        Paint()..color = const Color(0xFF3B2F2F),
      )
      ..drawArc(
        Rect.fromCenter(
          center: head + const Offset(0, -5),
          width: 30,
          height: 14,
        ),
        pi,
        pi,
        true,
        straw,
      );
    canvas.restore();
  }
}
