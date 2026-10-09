import 'dart:ui';

/// A fired-clay Iranian brick seen slightly from above: a clay-red face, a
/// lighter top, a dark side for depth, pores, chipped corners and crumbs of
/// old mortar. Drawn centred on (0, 0), 22 x 12 at scale 1.
class AjorPainter {
  static const _face = Color(0xFFB4532A);
  static const _top = Color(0xFFCF7446);
  static const _side = Color(0xFF85391B);
  static const _outline = Color(0xFF5E2812);
  static const _pore = Color(0xFF8C3D1C);
  static const _mortar = Color(0xFFE2D5BF);

  // A face with two chipped corners, so it does not read as a plain box.
  static final _facePath = Path()
    ..moveTo(-11, -3)
    ..lineTo(8, -3)
    ..lineTo(9, -1.5)
    ..lineTo(9, 6)
    ..lineTo(-9.5, 6)
    ..lineTo(-11, 4.5)
    ..close();

  static final _topPath = Path()
    ..moveTo(-11, -3)
    ..lineTo(-8, -6)
    ..lineTo(11, -6)
    ..lineTo(8, -3)
    ..close();

  static final _sidePath = Path()
    ..moveTo(8, -3)
    ..lineTo(11, -6)
    ..lineTo(11, 3)
    ..lineTo(9, 6)
    ..lineTo(9, -1.5)
    ..close();

  static const _pores = [
    Offset(-7, 0.5),
    Offset(-3, 3.5),
    Offset(1, -0.5),
    Offset(4.5, 2.5),
    Offset(-5, 4.2),
    Offset(6.5, 0),
  ];

  static void paint(Canvas canvas, {double scale = 1, double alpha = 1}) {
    Paint fill(Color color) => Paint()..color = color.withValues(alpha: alpha);
    canvas
      ..save()
      ..scale(scale)
      ..drawPath(_sidePath, fill(_side))
      ..drawPath(_topPath, fill(_top))
      ..drawPath(_facePath, fill(_face));
    for (final pore in _pores) {
      canvas.drawCircle(pore, 0.7, fill(_pore));
    }
    canvas
      ..drawRect(const Rect.fromLTWH(-6, -5.6, 5, 1.6), fill(_mortar))
      ..drawCircle(const Offset(5, -4.6), 0.9, fill(_mortar))
      ..drawPath(
        Path()
          ..addPath(_facePath, Offset.zero)
          ..addPath(_topPath, Offset.zero)
          ..addPath(_sidePath, Offset.zero),
        Paint()
          ..color = _outline.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      )
      ..restore();
  }
}
