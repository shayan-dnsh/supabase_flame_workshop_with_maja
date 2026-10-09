import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../game_config.dart';
import '../manloram_game.dart';

/// White streaks rushing across the arena while a gust blows: more and
/// faster the stronger it is, so a storm is seen coming.
class WindStreaks extends Component with HasGameRef<ManLoramGame> {
  WindStreaks() : super(priority: 18);

  final _random = Random();
  final _streaks = <({Offset at, double length, double phase})>[];
  final _speeds = <double>[];
  double _gust = 0;
  double _spawnDebt = 0;

  @override
  void update(double dt) {
    _gust = gameRef.gust;
    final strength = _gust.abs();
    final direction = _gust.sign;
    for (var i = _streaks.length - 1; i >= 0; i--) {
      final streak = _streaks[i];
      final moved = streak.at.translate(direction * _speeds[i] * dt, 0);
      if (moved.dx < -80 || moved.dx > GameConfig.viewWidth + 80) {
        _streaks.removeAt(i);
        _speeds.removeAt(i);
      } else {
        _streaks[i] = (at: moved, length: streak.length, phase: streak.phase);
      }
    }
    if (strength < 40) {
      return;
    }
    _spawnDebt += dt * strength / 18;
    while (_spawnDebt >= 1) {
      _spawnDebt -= 1;
      final startX = direction > 0 ? -60.0 : GameConfig.viewWidth + 60;
      _streaks.add((
        at: Offset(startX, 30 + _random.nextDouble() * 430),
        length: 30 + _random.nextDouble() * (strength / 12),
        phase: _random.nextDouble() * pi * 2,
      ));
      _speeds.add(350 + strength * 0.7 + _random.nextDouble() * 120);
    }
  }

  @override
  void render(Canvas canvas) {
    if (_streaks.isEmpty) {
      return;
    }
    final alpha = (0.25 + _gust.abs() / 2000).clamp(0.25, 0.7);
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final streak in _streaks) {
      final wobble = sin(streak.at.dx / 40 + streak.phase) * 3;
      canvas.drawPath(
        Path()
          ..moveTo(streak.at.dx, streak.at.dy)
          ..quadraticBezierTo(
            streak.at.dx - _gust.sign * streak.length / 2,
            streak.at.dy + wobble,
            streak.at.dx - _gust.sign * streak.length,
            streak.at.dy,
          ),
        paint,
      );
    }
  }
}
