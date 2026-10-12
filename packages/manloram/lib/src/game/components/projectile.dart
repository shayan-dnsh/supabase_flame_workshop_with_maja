import 'dart:ui';

import 'package:flame/components.dart';

import '../../game_config.dart';
import '../ajor_painter.dart';
import '../manloram_game.dart';
import '../weapon.dart';
import 'effects.dart';

/// A thrown stone or Ajor. Every client flies its own copy from the launch
/// event; only the player it hits decides that it hit.
class Projectile extends PositionComponent with HasGameRef<ManLoramGame> {
  Projectile({
    required this.projectileId,
    required this.ownerId,
    required this.weapon,
    required Vector2 position,
    required this.velocity,
  }) : previous = position.clone(),
       origin = position.clone(),
       super(position: position, priority: 12);

  final Vector2 origin;
  final String projectileId;
  final String ownerId;
  final Weapon weapon;
  final Vector2 velocity;

  /// Where the projectile was one frame ago, so hits are tested along the
  /// whole path it travelled.
  final Vector2 previous;
  bool spent = false;
  bool _throughWater = false;
  double _age = 0;

  double get radius => weapon.isAjor ? 7 : 5;

  @override
  void update(double dt) {
    _age += dt;
    previous.setFrom(position);
    final arena = gameRef.arena;
    velocity
      ..y += GameConfig.gravity * dt
      ..x += gameRef.wind * dt;
    position.add(velocity * dt);
    final water = arena.waterfall;
    if (!_throughWater &&
        water != null &&
        water.contains(Offset(position.x, position.y))) {
      _throughWater = true;
      velocity.x *= 0.55;
    }
    if (arena.isSolid(position, atMs: gameRef.nowMs)) {
      parent?.add(Dust(position: position.clone(), heavy: weapon.isAjor));
      removeFromParent();
    } else if (arena.isOutOfBounds(position) ||
        _age > GameConfig.projectileTtl) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (weapon.isAjor) {
      // An Ajor tumbles end over end as it flies.
      canvas
        ..save()
        ..rotate(_age * 7);
      AjorPainter.paint(canvas, scale: 0.9);
      canvas.restore();
      return;
    }
    canvas
      ..drawCircle(Offset.zero, 5, Paint()..color = const Color(0xFF7D7D7D))
      ..drawCircle(
        const Offset(-1.5, -1.5),
        2,
        Paint()..color = const Color(0xFFB0B0B0),
      );
  }

  @override
  void onRemove() {
    gameRef.projectiles.remove(projectileId);
    super.onRemove();
  }
}
