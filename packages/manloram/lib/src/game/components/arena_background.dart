import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../game_config.dart';
import '../arena_map.dart';
import '../manloram_game.dart';

/// The scenery of one map, with its ground, ledges, walls and water.
class ArenaBackground extends PositionComponent with HasGameRef<ManLoramGame> {
  ArenaBackground(this.arena, {this.wind = 0}) : super(priority: -10);

  final ArenaMap arena;

  /// Drives the drifting snow on a windy map.
  final double wind;

  static const _width = GameConfig.viewWidth;
  static const _height = GameConfig.viewHeight;
  static const _groundTop = ArenaMap.groundTop;

  double _time = 0;

  bool get _isBazaar => arena.id == ArenaMap.khorramabadBazaar.id;
  bool get _isBisheh => arena.id == ArenaMap.bishehWaterfall.id;
  bool get _isGahar => arena.id == ArenaMap.gaharLake.id;

  @override
  void update(double dt) {
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    _sky(canvas);
    if (_isBazaar) {
      _bazaarSkyline(canvas);
    } else if (_isBisheh) {
      _bishehValley(canvas);
    } else if (_isGahar) {
      _gaharPeaks(canvas);
    } else {
      _falakScenery(canvas);
    }
    _ground(canvas);
    for (final block in arena.blocks) {
      _isBazaar ? _brickTower(canvas, block) : _cliff(canvas, block);
    }
    final water = arena.waterfall;
    if (water != null) {
      _waterfall(canvas, water);
    }
    for (final ledge in arena.ledgesAt(gameRef.nowMs)) {
      _ledge(canvas, ledge);
    }
    if (_isGahar) {
      _snowfall(canvas);
    }
  }

  void _sky(Canvas canvas) {
    final colors = _isGahar
        ? const [Color(0xFF9FC4E6), Color(0xFFE8F1F8)]
        : _isBazaar
        ? const [Color(0xFFE9A86A), Color(0xFFF8DDB0)]
        : _isBisheh
        ? const [Color(0xFF79BFE0), Color(0xFFD9F0E4)]
        : const [Color(0xFF7FB8E0), Color(0xFFF7DDB0)];
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _width, _height),
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          const Offset(0, _groundTop),
          colors,
        ),
    );
    final sun = _isBazaar ? const Offset(150, 110) : const Offset(820, 92);
    canvas
      ..drawCircle(sun, 52, Paint()..color = const Color(0x33FFE9A8))
      ..drawCircle(
        sun,
        34,
        Paint()
          ..color = _isBazaar
              ? const Color(0xFFFFC870)
              : const Color(0xFFFFE08A),
      );
    if (!_isGahar) {
      for (final (x, y, scale, speed) in const [
        (90.0, 70.0, 1.0, 9.0),
        (420.0, 120.0, 0.7, 6.0),
        (700.0, 55.0, 1.2, 11.0),
      ]) {
        final drifted = (x + _time * speed) % (_width + 160) - 80;
        _cloud(canvas, Offset(drifted, y), scale);
      }
    }
  }

  void _cloud(Canvas canvas, Offset at, double scale) {
    final paint = Paint()..color = const Color(0xDDFFFFFF);
    canvas
      ..drawOval(
        Rect.fromCenter(center: at, width: 90 * scale, height: 26 * scale),
        paint,
      )
      ..drawCircle(at + Offset(-14 * scale, -10 * scale), 16 * scale, paint)
      ..drawCircle(at + Offset(12 * scale, -13 * scale), 20 * scale, paint);
  }

  Path _ridge(List<Offset> points, double bottom) {
    final path = Path()..moveTo(0, bottom);
    for (final point in points) {
      path.lineTo(point.dx, point.dy);
    }
    return path
      ..lineTo(_width, bottom)
      ..close();
  }

  // Falak-ol-Aflak: the Zagros and the castle on its mound.

  void _falakScenery(Canvas canvas) {
    canvas.drawPath(
      _ridge(const [
        Offset(0, 330),
        Offset(70, 250),
        Offset(140, 290),
        Offset(230, 205),
        Offset(320, 280),
        Offset(410, 235),
        Offset(520, 300),
        Offset(610, 220),
        Offset(700, 275),
        Offset(800, 200),
        Offset(890, 265),
        Offset(_width, 240),
      ], 420),
      Paint()..color = const Color(0xFF9DA7C4),
    );
    final stone = Paint()..color = const Color(0xFFC9A577);
    final shade = Paint()..color = const Color(0xFFAE8A5E);
    canvas
      ..drawOval(const Rect.fromLTWH(300, 372, 360, 90), shade)
      ..drawRect(const Rect.fromLTWH(372, 322, 216, 64), stone);
    for (final x in [372.0, 426.0, 480.0, 534.0, 588.0]) {
      final top = x == 480 ? 288.0 : 306.0;
      final paint = x == 480 ? shade : stone;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x - 13, top, 26, 386 - top),
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
        ),
        paint,
      );
      for (var i = -1; i <= 1; i++) {
        canvas.drawRect(Rect.fromLTWH(x - 3 + i * 9, top - 6, 6, 6), paint);
      }
    }
    final window = Paint()..color = const Color(0xFF7A5F44);
    for (final x in [399.0, 453.0, 507.0, 561.0]) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x - 3, 340, 6, 12),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        window,
      );
    }
    _hills(canvas, const Color(0xFF94A36A));
  }

  void _hills(Canvas canvas, Color color) {
    final hills = Path()
      ..moveTo(0, 405)
      ..quadraticBezierTo(160, 360, 300, 395)
      ..quadraticBezierTo(480, 430, 660, 385)
      ..quadraticBezierTo(820, 350, _width, 400)
      ..lineTo(_width, _groundTop)
      ..lineTo(0, _groundTop)
      ..close();
    canvas.drawPath(hills, Paint()..color = color);
  }

  // Khorramabad Bazaar: flat roofs, domes and wind towers.

  void _bazaarSkyline(Canvas canvas) {
    canvas.drawPath(
      _ridge(const [
        Offset(0, 300),
        Offset(160, 240),
        Offset(330, 290),
        Offset(520, 230),
        Offset(720, 280),
        Offset(_width, 245),
      ], 420),
      Paint()..color = const Color(0xFFC79A7E),
    );
    final wall = Paint()..color = const Color(0xFFD9B48A);
    final shade = Paint()..color = const Color(0xFFBF9670);
    final random = Random(3);
    for (var x = -20.0; x < _width; x += 70 + random.nextDouble() * 40) {
      final height = 70 + random.nextDouble() * 70;
      final width = 60 + random.nextDouble() * 40;
      final top = _groundTop - height;
      canvas.drawRect(Rect.fromLTWH(x, top, width, height), wall);
      if (random.nextBool()) {
        canvas.drawArc(
          Rect.fromLTWH(x + width / 2 - 18, top - 18, 36, 36),
          pi,
          pi,
          true,
          shade,
        );
      } else {
        canvas
          ..drawRect(Rect.fromLTWH(x + 8, top - 34, 16, 34), shade)
          ..drawRect(
            Rect.fromLTWH(x + 10, top - 30, 12, 6),
            Paint()..color = const Color(0xFF8C6A4E),
          );
      }
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x + width / 2 - 6, top + 20, 12, 18),
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
        ),
        Paint()..color = const Color(0xFF8C6A4E),
      );
    }
  }

  void _brickTower(Canvas canvas, Rect block) {
    final brick = Paint()..color = const Color(0xFFB5683F);
    canvas.drawRect(block, brick);
    final mortar = Paint()
      ..color = const Color(0xFF8E4E2E)
      ..strokeWidth = 1;
    for (var y = block.top + 10; y < block.bottom; y += 10) {
      canvas.drawLine(Offset(block.left, y), Offset(block.right, y), mortar);
      final offset = ((y - block.top) ~/ 10).isEven ? 0.0 : 10.0;
      for (var x = block.left + offset; x < block.right; x += 20) {
        canvas.drawLine(Offset(x, y - 10), Offset(x, y), mortar);
      }
    }
    for (var x = block.left; x < block.right; x += 16) {
      canvas.drawRect(Rect.fromLTWH(x, block.top - 8, 9, 8), brick);
    }
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(block.center.dx - 12, block.top + 40, 24, 40),
        topLeft: const Radius.circular(12),
        topRight: const Radius.circular(12),
      ),
      Paint()..color = const Color(0xFF4A2E1E),
    );
  }

  // Bisheh: green slopes, cliffs and the falls.

  void _bishehValley(Canvas canvas) {
    canvas.drawPath(
      _ridge(const [
        Offset(0, 200),
        Offset(200, 140),
        Offset(380, 90),
        Offset(580, 90),
        Offset(760, 150),
        Offset(_width, 210),
      ], 420),
      Paint()..color = const Color(0xFF6E9C6A),
    );
    canvas.drawRect(
      const Rect.fromLTWH(380, 60, 200, 40),
      Paint()..color = const Color(0xFF5E7F5A),
    );
    _hills(canvas, const Color(0xFF7FAE62));
    canvas.drawOval(
      const Rect.fromLTWH(280, 440, 400, 50),
      Paint()..color = const Color(0xFF4FA3C7),
    );
  }

  void _cliff(Canvas canvas, Rect block) {
    canvas
      ..drawRect(block, Paint()..color = const Color(0xFF8A7B66))
      ..drawRect(
        Rect.fromLTWH(block.left, block.top, block.width, 8),
        Paint()..color = const Color(0xFF6E9C4A),
      );
    final crack = Paint()
      ..color = const Color(0xFF6F6252)
      ..strokeWidth = 2;
    for (var x = block.left + 30; x < block.right; x += 55) {
      canvas.drawLine(
        Offset(x, block.top + 20),
        Offset(x + 10, block.bottom - 10),
        crack,
      );
    }
  }

  void _waterfall(Canvas canvas, Rect water) {
    canvas
      ..save()
      ..clipRect(water)
      ..drawRect(water, Paint()..color = const Color(0xAA9ED8F0));
    final streak = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = 2;
    for (var i = 0; i < 6; i++) {
      final x = water.left + 6 + i * (water.width - 12) / 5;
      final offset = (_time * 260 + i * 37) % 60;
      for (var y = water.top - 60 + offset; y < water.bottom; y += 60) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 26), streak);
      }
    }
    canvas.restore();
    final mist = Paint()..color = const Color(0x88FFFFFF);
    for (var i = 0; i < 5; i++) {
      final wobble = sin(_time * 3 + i) * 4;
      canvas.drawCircle(
        Offset(water.left - 10 + i * 21 + wobble, water.bottom - 6),
        14,
        mist,
      );
    }
  }

  // Gahar Lake: snowy Oshtorankuh peaks and the turquoise lake.

  void _gaharPeaks(Canvas canvas) {
    final peaks = _ridge(const [
      Offset(0, 260),
      Offset(120, 150),
      Offset(260, 240),
      Offset(400, 110),
      Offset(540, 230),
      Offset(690, 130),
      Offset(830, 220),
      Offset(_width, 170),
    ], 420);
    canvas
      ..drawPath(peaks, Paint()..color = const Color(0xFF8E9DB5))
      ..save()
      ..clipPath(peaks);
    final snow = Paint()..color = const Color(0xFFF4F8FC);
    for (final (x, y) in const [
      (120.0, 150.0),
      (400.0, 110.0),
      (690.0, 130.0),
      (_width, 170.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x - 50, y + 45)
          ..lineTo(x, y)
          ..lineTo(x + 50, y + 45)
          ..close(),
        snow,
      );
    }
    canvas
      ..restore()
      ..drawRect(
        const Rect.fromLTWH(0, 395, _width, 75),
        Paint()..color = const Color(0xFF3FA8B5),
      );
  }

  void _snowfall(Canvas canvas) {
    final flake = Paint()..color = const Color(0xCCFFFFFF);
    final random = Random(9);
    for (var i = 0; i < 60; i++) {
      final baseX = random.nextDouble() * _width;
      final speed = 30 + random.nextDouble() * 40;
      final y = (random.nextDouble() * _height + _time * speed) % _height;
      final x = (baseX + _time * wind * 0.25) % _width;
      canvas.drawCircle(Offset(x, y), 1.5 + random.nextDouble() * 1.5, flake);
    }
  }

  // Shared ground and ledges.

  void _ground(Canvas canvas) {
    final earth = _isGahar
        ? const Color(0xFFE9EEF3)
        : _isBazaar
        ? const Color(0xFFB08A62)
        : const Color(0xFF7A5230);
    final top = _isGahar
        ? const Color(0xFFFFFFFF)
        : _isBazaar
        ? const Color(0xFFC9A37A)
        : const Color(0xFF6E8B3D);
    canvas
      ..drawRect(
        const Rect.fromLTWH(0, _groundTop, _width, _height - _groundTop),
        Paint()..color = earth,
      )
      ..drawRect(
        const Rect.fromLTWH(0, _groundTop, _width, 7),
        Paint()..color = top,
      );
    final pebble = Paint()
      ..color = Color.lerp(earth, const Color(0xFF000000), 0.15)!;
    for (var x = 24.0; x < _width; x += 71) {
      canvas.drawOval(
        Rect.fromLTWH(x, _groundTop + 22 + (x % 3) * 9, 10, 5),
        pebble,
      );
    }
  }

  void _ledge(Canvas canvas, Rect ledge) {
    final (body, top) = _isGahar
        ? (const Color(0xFFB9D3E3), const Color(0xFFFFFFFF))
        : _isBazaar
        ? (const Color(0xFF8C6A4E), const Color(0xFFB08A62))
        : (const Color(0xFF8C8577), const Color(0xFFB2AA98));
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          ledge.translate(0, 4),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0x55000000),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(ledge, const Radius.circular(4)),
        Paint()..color = body,
      )
      ..drawRect(
        Rect.fromLTWH(ledge.left + 3, ledge.top, ledge.width - 6, 4),
        Paint()..color = top,
      );
    final seam = Paint()
      ..color = Color.lerp(body, const Color(0xFF000000), 0.2)!
      ..strokeWidth = 1.5;
    for (var x = ledge.left + 30; x < ledge.right; x += 36) {
      canvas.drawLine(Offset(x, ledge.top + 5), Offset(x, ledge.bottom), seam);
    }
  }
}
