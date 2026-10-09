import 'dart:math';
import 'dart:ui';

import 'package:flame/extensions.dart';

import 'ajor_painter.dart';
import 'body_geometry.dart';
import 'outfit.dart';
import 'weapon.dart';

/// Draws a Lor around the feet at (0, 0), in the game and in the lobby's
/// outfit picker alike. The player's colour is the outfit's accent.
class LorPainter {
  static const _skin = Color(0xFFE0AC69);
  static const _dark = Color(0xFF2B2522);
  static const _feltBrown = Color(0xFF5D4037);
  static const _feltBlack = Color(0xFF1F1B18);
  static const _sash = Color(0xFFF2E6D0);
  static const _gold = Color(0xFFE8C547);
  static const _wool = Color(0xFFEDE3CC);
  static const _feltCloak = Color(0xFF8B7355);
  static const _velvet = Color(0xFF3A1E3F);

  static void paint(
    Canvas canvas, {
    required Outfit outfit,
    required Color color,
    double aim = 0,
    bool charging = false,
    String weaponId = Weapon.stoneId,
    double walkPhase = 0,
    bool flashing = false,
    double alpha = 1,
    double? swing,
  }) {
    final facing = cos(aim) >= 0 ? 1.0 : -1.0;
    final paint = _Brush(alpha: alpha, flashing: flashing);
    final stride = sin(walkPhase) * 5;

    if (outfit == Outfit.golvani) {
      _feet(canvas, paint, stride);
      _skirt(canvas, paint, color);
    } else {
      _trousers(canvas, paint, stride);
    }
    if (swing == null) {
      _stickArm(canvas, paint, facing, _sleeve(outfit, color), null);
    }
    switch (outfit) {
      case Outfit.kolah:
        _tunic(canvas, paint, color);
      case Outfit.chogha:
        _chogha(canvas, paint, color);
      case Outfit.golvani:
        _coinVest(canvas, paint);
      case Outfit.kapenak:
        _kapenak(canvas, paint, color);
    }
    _head(canvas, paint, facing, moustache: outfit != Outfit.golvani);
    switch (outfit) {
      case Outfit.kolah || Outfit.kapenak:
        _roundFeltHat(canvas, paint);
      case Outfit.chogha:
        _bakhtiariHat(canvas, paint);
      case Outfit.golvani:
        _golvaniScarf(canvas, paint, color, facing);
    }
    if (swing != null) {
      _stickArm(canvas, paint, facing, _sleeve(outfit, color), swing);
    }
    _throwingArm(
      canvas,
      paint,
      aim: aim,
      facing: facing,
      charging: charging,
      weaponId: weaponId,
      sleeve: _sleeve(outfit, color),
    );
  }

  static Color _sleeve(Outfit outfit, Color color) => switch (outfit) {
    Outfit.chogha => _wool,
    Outfit.kapenak => _feltCloak,
    _ => _darker(color),
  };

  static void _trousers(Canvas canvas, _Brush paint, double stride) {
    final wide = paint.stroke(_dark, 7);
    canvas
      ..drawLine(const Offset(-4, -18), Offset(-5 + stride, -2), wide)
      ..drawLine(const Offset(4, -18), Offset(5 - stride, -2), wide);
    _feet(canvas, paint, stride);
  }

  static void _feet(Canvas canvas, _Brush paint, double stride) {
    final shoe = paint.fill(const Color(0xFF4E342E));
    canvas
      ..drawOval(Rect.fromLTWH(-9 + stride, -3, 8, 4), shoe)
      ..drawOval(Rect.fromLTWH(1 - stride, -3, 8, 4), shoe);
  }

  /// The other hand holds a chub, the Lor fighting stick: carried upright
  /// behind the back, and swung over the shoulder to the front when used.
  /// [swing] runs from 0 to 1 through a swing, null when at rest.
  static void _stickArm(
    Canvas canvas,
    _Brush paint,
    double facing,
    Color sleeve,
    double? swing,
  ) {
    // Angles for a player facing right, mirrored for one facing left.
    double mirror(double angle) => facing > 0 ? angle : pi - angle;
    final double arm;
    final double stick;
    if (swing == null) {
      arm = mirror(0.62 * pi);
      stick = mirror(-0.62 * pi);
    } else {
      final eased = 1 - pow(1 - swing.clamp(0.0, 1.0), 3);
      arm = mirror(-0.8 * pi + eased * pi);
      stick = arm;
    }
    const shoulder = Offset(0, -35);
    final hand = shoulder + Offset(cos(arm), sin(arm)) * 12;
    final along = Offset(cos(stick), sin(stick));
    canvas
      ..drawLine(
        hand - along * 6,
        hand + along * 28,
        paint.stroke(const Color(0xFF8D6E4A), 3.6),
      )
      ..drawLine(
        hand - along * 6,
        hand + along * 3,
        paint.stroke(const Color(0xFF5D4037), 4.2),
      )
      ..drawCircle(hand + along * 17, 1.6, paint.fill(const Color(0xFF6D4C35)))
      ..drawLine(shoulder, hand, paint.stroke(sleeve, 4))
      ..drawCircle(hand, 3, paint.fill(_skin));
  }

  static void _tunic(Canvas canvas, _Brush paint, Color color) {
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-11, -40, 22, 26),
          const Radius.circular(5),
        ),
        paint.fill(color),
      )
      ..drawRect(const Rect.fromLTWH(-11, -27, 22, 4), paint.fill(_sash));
  }

  /// White wool with dark vertical stripes, open over a coloured shirt.
  static void _chogha(Canvas canvas, _Brush paint, Color color) {
    canvas
      ..drawRect(const Rect.fromLTWH(-4, -40, 8, 22), paint.fill(color))
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-12, -40, 24, 30),
          const Radius.circular(4),
        ),
        paint.fill(_wool),
      );
    final stripe = paint.stroke(const Color(0xFF3E3A36), 1.6);
    for (final x in [-9.0, -5.0, 5.0, 9.0]) {
      canvas.drawLine(Offset(x, -38), Offset(x, -11), stripe);
    }
    final opening = Path()
      ..moveTo(-3, -40)
      ..lineTo(3, -40)
      ..lineTo(0, -30)
      ..close();
    canvas
      ..drawPath(opening, paint.fill(color))
      ..drawRect(const Rect.fromLTWH(-12, -26, 24, 3), paint.fill(color));
  }

  /// A dark velvet vest edged with gold coins.
  static void _coinVest(Canvas canvas, _Brush paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10, -40, 20, 17),
        const Radius.circular(5),
      ),
      paint.fill(_velvet),
    );
    final coin = paint.fill(_gold);
    for (var x = -8.0; x <= 8; x += 4) {
      canvas.drawCircle(Offset(x, -23), 1.6, coin);
    }
    canvas.drawCircle(const Offset(0, -33), 1.6, coin);
  }

  /// A long skirt in layers of the player's colour, gold at the hem.
  static void _skirt(Canvas canvas, _Brush paint, Color color) {
    final skirt = Path()
      ..moveTo(-10, -26)
      ..lineTo(10, -26)
      ..lineTo(15, -3)
      ..lineTo(-15, -3)
      ..close();
    canvas.drawPath(skirt, paint.fill(color));
    final light = Color.lerp(color, const Color(0xFFFFFFFF), 0.35)!;
    canvas
      ..drawRect(const Rect.fromLTWH(-12.5, -17, 25, 3), paint.fill(light))
      ..drawRect(const Rect.fromLTWH(-14.5, -6, 29, 3), paint.fill(_gold));
  }

  /// The stiff felt cloak, square at the shoulders.
  static void _kapenak(Canvas canvas, _Brush paint, Color color) {
    final cloak = Path()
      ..moveTo(-14, -40)
      ..lineTo(14, -40)
      ..lineTo(12, -9)
      ..lineTo(-12, -9)
      ..close();
    canvas
      ..drawPath(cloak, paint.fill(_feltCloak))
      ..drawPath(cloak, paint.stroke(const Color(0xFFB59C7A), 1.2))
      ..drawRect(const Rect.fromLTWH(-7, -41, 14, 4), paint.fill(color));
  }

  static void _head(
    Canvas canvas,
    _Brush paint,
    double facing, {
    required bool moustache,
  }) {
    final head = BodyGeometry.headCenter.toOffset();
    canvas
      ..drawCircle(
        head,
        BodyGeometry.headRadius,
        paint.fill(_skin, flash: true),
      )
      ..drawCircle(head + Offset(facing * 4, -1), 1.6, paint.fill(_dark));
    if (moustache) {
      canvas.drawLine(
        head + Offset(facing * 1, 4),
        head + Offset(facing * 6, 4),
        paint.stroke(_dark, 1.6),
      );
    }
  }

  static void _roundFeltHat(Canvas canvas, _Brush paint) {
    final head = BodyGeometry.headCenter.toOffset();
    canvas
      ..drawArc(
        Rect.fromCenter(
          center: head + const Offset(0, -4),
          width: 22,
          height: 18,
        ),
        pi,
        pi,
        true,
        paint.fill(_feltBrown),
      )
      ..drawLine(
        head + const Offset(-12, -4),
        head + const Offset(12, -4),
        paint.stroke(_feltBrown, 2.5),
      );
  }

  /// The tall black felt hat worn with the chogha.
  static void _bakhtiariHat(Canvas canvas, _Brush paint) {
    final head = BodyGeometry.headCenter.toOffset();
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(head.dx - 9, head.dy - 19, 18, 15),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      ),
      paint.fill(_feltBlack),
    );
  }

  /// A flowered silk scarf over the head, hanging down behind it.
  static void _golvaniScarf(
    Canvas canvas,
    _Brush paint,
    Color color,
    double facing,
  ) {
    final head = BodyGeometry.headCenter.toOffset();
    final back = -facing;
    final silk = paint.fill(Color.lerp(color, const Color(0xFF8E1B3A), 0.45)!);
    final drape = Path()
      ..moveTo(head.dx + back * 4, head.dy - 6)
      ..lineTo(head.dx + back * 13, head.dy - 3)
      ..lineTo(head.dx + back * 12, head.dy + 18)
      ..lineTo(head.dx + back * 3, head.dy + 14)
      ..close();
    canvas
      ..drawPath(drape, silk)
      ..drawArc(
        Rect.fromCircle(center: head + const Offset(0, -3), radius: 12),
        pi,
        pi,
        true,
        silk,
      );
    final flower = paint.fill(const Color(0xFFFFF1C1));
    for (final offset in [
      const Offset(-6, -8),
      const Offset(1, -11),
      const Offset(7, -7),
      Offset(back * 9, 8),
    ]) {
      canvas.drawCircle(head + offset, 1.3, flower);
    }
    canvas.drawLine(
      head + const Offset(-12, -3),
      head + const Offset(12, -3),
      paint.stroke(_gold, 1.4),
    );
  }

  static void _throwingArm(
    Canvas canvas,
    _Brush paint, {
    required double aim,
    required double facing,
    required bool charging,
    required String weaponId,
    required Color sleeve,
  }) {
    final shoulder = BodyGeometry.shoulder.toOffset();
    final reach = charging
        ? BodyGeometry.armLength - 4
        : BodyGeometry.armLength;
    final armAngle = charging ? aim - pi * 0.8 * facing : aim;
    final hand = shoulder + Offset(cos(armAngle), sin(armAngle)) * reach;
    canvas
      ..drawLine(shoulder, hand, paint.stroke(sleeve, 4))
      ..drawCircle(hand, 3, paint.fill(_skin));
    if (weaponId == Weapon.ajorId) {
      canvas
        ..save()
        ..translate(hand.dx, hand.dy)
        ..rotate(armAngle)
        ..translate(5, 0);
      AjorPainter.paint(canvas, scale: 0.55, alpha: paint.alpha);
      canvas.restore();
    } else {
      canvas.drawCircle(hand, 4.5, paint.fill(const Color(0xFF8D8D8D)));
    }
  }

  static Color _darker(Color color) =>
      Color.lerp(color, const Color(0xFF000000), 0.25)!;
}

class _Brush {
  const _Brush({required this.alpha, required this.flashing});

  final double alpha;
  final bool flashing;

  /// [flash] parts turn white for a moment when the player is hit.
  Paint fill(Color color, {bool flash = false}) => Paint()
    ..color = (flash && flashing ? const Color(0xFFFFFFFF) : color).withValues(
      alpha: alpha,
    );

  Paint stroke(Color color, double width) => Paint()
    ..color = color.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = width;
}
