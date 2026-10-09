import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/painting.dart' show TextStyle, FontWeight;

import '../../game_config.dart';

/// "+100 AJOR HEADSHOT" rising from where a hit landed.
class FloatingText extends PositionComponent {
  FloatingText({
    required this.text,
    required this.color,
    required super.position,
    this.fontSize = 14,
  }) : super(priority: 30, anchor: Anchor.center);

  final String text;
  final Color color;
  final double fontSize;

  static const _lifetime = 1.1;
  static const _edgeMargin = 130.0;
  double _age = 0;

  @override
  void onLoad() {
    // Keep the label on screen when the hit lands near the arena's edge.
    position.x = position.x.clamp(
      _edgeMargin,
      GameConfig.viewWidth - _edgeMargin,
    );
  }

  @override
  void update(double dt) {
    _age += dt;
    position.y -= 38 * dt;
    if (_age >= _lifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final alpha = (1 - _age / _lifetime).clamp(0.0, 1.0);
    TextPaint(
      style: TextStyle(
        color: color.withValues(alpha: alpha),
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        shadows: [
          Shadow(
            blurRadius: 4,
            color: const Color(0xFF000000).withValues(alpha: alpha * 0.8),
          ),
        ],
      ),
    ).render(canvas, text, Vector2.zero(), anchor: Anchor.center);
  }
}

/// A puff of earth where a throw lands.
class Dust extends ParticleEmitterComponent {
  Dust({required Vector2 position, required bool heavy})
    : super(
        position: position,
        priority: 15,
        emitter: ParticleEmitter(
          maxParticles: heavy ? 18 : 10,
          bursts: [EmitterBurst(0, heavy ? 18 : 10)],
          lifespan: (0.5, 0.5),
          speed: (30, heavy ? 140 : 90),
          size: (2, heavy ? 5 : 3),
          opacityOverLife: ParticleCurve(0.9, 0),
          colorOverLife: ColorRamp.solid(
            heavy ? const Color(0xFFB5523B) : const Color(0xFFA48A6A),
          ),
        ),
        renderer: CircleParticleRenderer(),
      );
}

/// Cartoon blood where a stone or an Ajor lands: a spray that falls under
/// gravity, more of it for an Ajor or a headshot.
class BloodSplash extends ParticleEmitterComponent {
  BloodSplash({required Vector2 position, required bool heavy})
    : super(
        position: position,
        priority: 16,
        emitter: ParticleEmitter(
          maxParticles: heavy ? 26 : 12,
          bursts: [EmitterBurst(0, heavy ? 26 : 12)],
          lifespan: (0.45, 0.9),
          speed: (70, heavy ? 260 : 170),
          direction: -pi / 2,
          spread: pi * 1.3,
          gravity: Vector2(0, 900),
          size: (2.5, heavy ? 6 : 4),
          opacityOverLife: ParticleCurve(1, 0.2),
          colorOverLife: ColorRamp([
            const Color(0xFFD32F2F),
            const Color(0xFF7F0000),
          ]),
        ),
        renderer: CircleParticleRenderer(),
      );
}

/// A few drops left on the ground under the player, fading away.
class BloodStain extends PositionComponent {
  BloodStain({required super.position, required this.heavy})
    : super(priority: -5);

  final bool heavy;

  static const _lifetime = 4.0;
  static final _random = Random();
  late final _drops = [
    for (var i = 0; i < (heavy ? 5 : 3); i++)
      (
        Offset((_random.nextDouble() - 0.5) * 34, _random.nextDouble() * 2),
        3 + _random.nextDouble() * (heavy ? 6 : 4),
      ),
  ];
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= _lifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final alpha = (1 - _age / _lifetime).clamp(0.0, 1.0) * 0.8;
    final paint = Paint()
      ..color = const Color(0xFF8B0000).withValues(alpha: alpha);
    for (final (offset, width) in _drops) {
      canvas.drawOval(
        Rect.fromCenter(center: offset, width: width * 2, height: width * 0.7),
        paint,
      );
    }
  }
}
