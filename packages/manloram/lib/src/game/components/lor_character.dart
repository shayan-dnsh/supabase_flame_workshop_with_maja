import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextStyle, FontWeight;

import '../../game_config.dart';
import '../body_geometry.dart';
import '../lor_painter.dart';
import '../outfit.dart';
import '../weapon.dart';

/// A player drawn around its feet at [position], in the Lor outfit they
/// picked, with a throwing arm that follows the aim.
abstract class LorCharacter extends PositionComponent {
  LorCharacter({
    required this.playerId,
    required this.playerName,
    required this.color,
    required this.outfit,
    required super.position,
  }) : super(priority: 10);

  final String playerId;
  final String playerName;
  final Color color;
  final Outfit outfit;

  double hp = GameConfig.maxHp;
  double aim = 0;
  bool knockedOut = false;

  /// Slowed by a recent hit: limps and sees stars.
  bool dazed = false;

  /// Seconds left in a chub swing, for the animation.
  double swingLeft = 0;
  bool charging = false;
  String weaponId = Weapon.stoneId;
  final velocity = Vector2.zero();

  double _flashTime = 0;
  double _walkPhase = 0;
  double _blinkTime = 0;

  /// Which way the body faces, 1 right or -1 left. It follows walking,
  /// not the aim; see [BodyGeometry.facingFor].
  int facing = 1;

  /// Seconds of spawn protection left; the character blinks meanwhile.
  double get protectionLeft => 0;

  static final _namePaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 11,
      fontWeight: FontWeight.w600,
      shadows: [Shadow(blurRadius: 3, color: Color(0xCC000000))],
    ),
  );

  void flash() {
    _flashTime = 0.15;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flashTime > 0) {
      _flashTime -= dt;
    }
    if (swingLeft > 0) {
      swingLeft = max(0, swingLeft - dt);
    }
    _blinkTime += dt;
    if (velocity.x.abs() > 1 && velocity.y.abs() < 1) {
      _walkPhase += dt * 14 * min(1, velocity.x.abs() / GameConfig.moveSpeed);
    } else {
      _walkPhase = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    final blinkingOut = protectionLeft > 0 && (_blinkTime * 10).floor().isOdd;
    if (knockedOut) {
      canvas
        ..save()
        ..rotate(-facing * pi / 2);
      _drawBody(canvas, alpha: 0.55);
      canvas.restore();
      return;
    }
    _drawBody(canvas, alpha: blinkingOut ? 0.35 : 1);
    _drawTag(canvas);
  }

  void _drawBody(Canvas canvas, {required double alpha}) {
    LorPainter.paint(
      canvas,
      outfit: outfit,
      color: color,
      aim: aim,
      facing: facing.toDouble(),
      charging: charging,
      weaponId: weaponId,
      walkPhase: _walkPhase,
      flashing: _flashTime > 0,
      alpha: alpha,
      swing: swingLeft > 0 ? 1 - swingLeft / Weapon.chubSwingSeconds : null,
    );
  }

  void _drawStars(Canvas canvas) {
    final star = Paint()..color = const Color(0xFFFFD54F);
    for (var i = 0; i < 3; i++) {
      final angle = _blinkTime * 5 + i * 2 * pi / 3;
      final center = Offset(cos(angle) * 13, -66 + sin(angle) * 4);
      final path = Path();
      for (var p = 0; p < 10; p++) {
        final radius = p.isEven ? 3.6 : 1.5;
        final a = -pi / 2 + p * pi / 5;
        final point = center + Offset(cos(a) * radius, sin(a) * radius);
        p == 0
            ? path.moveTo(point.dx, point.dy)
            : path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path..close(), star);
    }
  }

  void _drawTag(Canvas canvas) {
    if (dazed) {
      _drawStars(canvas);
    }
    _namePaint.render(
      canvas,
      playerName,
      Vector2(0, -84),
      anchor: Anchor.bottomCenter,
    );
    final ratio = (hp / GameConfig.maxHp).clamp(0.0, 1.0);
    const barWidth = 32.0;
    canvas
      ..drawRect(
        const Rect.fromLTWH(-barWidth / 2, -80, barWidth, 4),
        Paint()..color = const Color(0x66000000),
      )
      ..drawRect(
        Rect.fromLTWH(-barWidth / 2, -80, barWidth * ratio, 4),
        Paint()
          ..color = ratio > 0.35
              ? const Color(0xFF7CC242)
              : const Color(0xFFE5533D),
      );
  }
}
