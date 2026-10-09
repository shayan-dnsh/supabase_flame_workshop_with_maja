import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_config.dart';

/// A one-screen arena in world coordinates: (0, 0) is the top left of the
/// 960 x 540 view and y grows downwards. Every map is a real place in
/// Lorestan with one twist of its own.
class ArenaMap {
  const ArenaMap({
    required this.id,
    required this.name,
    required this.twist,
    required this.ledges,
    required this.spawns,
    this.blocks = const [],
    this.waterfall,
    this.windy = false,
    this.scarecrowWalk = (600, 910),
  });

  /// Matches `public.arenas.id`.
  final String id;
  final String name;

  /// What makes the map play differently, shown in the lobby.
  final String twist;

  /// Platforms players land on from above and drop through with the down
  /// key; throws hit them from any side.
  final List<Rect> ledges;

  /// Solid ground-standing walls, cliffs and towers: players cannot walk
  /// through them and stand on top; throws stop on them.
  final List<Rect> blocks;

  /// Falling water: a throw passing through it loses speed once.
  final Rect? waterfall;

  /// Mountain wind pushes every throw sideways, the same way on every
  /// device because it comes from the match seed.
  final bool windy;

  /// Feet positions, handed out in participant order.
  final List<Offset> spawns;

  /// Where the practice scarecrow paces, on open ground.
  final (double, double) scarecrowWalk;

  static const groundTop = 470.0;
  static const minX = 14.0;
  static const maxX = GameConfig.viewWidth - 14;
  static const _halfWidth = 11.0;

  static const falakOlAflak = ArenaMap(
    id: 'falak_ol_aflak',
    name: 'Falak-ol-Aflak Castle',
    twist: 'The classic: three stone ledges under the castle.',
    ledges: [
      Rect.fromLTWH(130, 350, 180, 16),
      Rect.fromLTWH(390, 255, 180, 16),
      Rect.fromLTWH(650, 350, 180, 16),
    ],
    spawns: [
      Offset(115, groundTop),
      Offset(845, groundTop),
      Offset(220, 350),
      Offset(740, 350),
      Offset(480, 255),
      Offset(330, groundTop),
      Offset(630, groundTop),
      Offset(480, groundTop),
    ],
  );

  static const khorramabadBazaar = ArenaMap(
    id: 'khorramabad_bazaar',
    name: 'Khorramabad Bazaar',
    twist: 'A brick tower splits the bazaar: lob over it or take the roofs.',
    blocks: [Rect.fromLTWH(440, 250, 80, groundTop - 250)],
    ledges: [
      Rect.fromLTWH(80, 360, 170, 16),
      Rect.fromLTWH(250, 280, 110, 16),
      Rect.fromLTWH(600, 280, 110, 16),
      Rect.fromLTWH(710, 360, 170, 16),
    ],
    spawns: [
      Offset(115, groundTop),
      Offset(845, groundTop),
      Offset(165, 360),
      Offset(795, 360),
      Offset(305, 280),
      Offset(655, 280),
      Offset(340, groundTop),
      Offset(620, groundTop),
    ],
  );

  static const bishehWaterfall = ArenaMap(
    id: 'bisheh_waterfall',
    name: 'Bisheh Waterfall',
    twist: 'Two cliffs and the falls between them: water slows any throw.',
    blocks: [
      Rect.fromLTWH(0, 380, 250, groundTop - 380),
      Rect.fromLTWH(710, 380, 250, groundTop - 380),
    ],
    ledges: [
      Rect.fromLTWH(290, 290, 120, 16),
      Rect.fromLTWH(550, 290, 120, 16),
      Rect.fromLTWH(410, 190, 140, 16),
    ],
    waterfall: Rect.fromLTWH(448, 0, 64, groundTop),
    scarecrowWalk: (530, 690),
    spawns: [
      Offset(115, 380),
      Offset(845, 380),
      Offset(350, 290),
      Offset(610, 290),
      Offset(330, groundTop),
      Offset(630, groundTop),
      Offset(160, 380),
      Offset(800, 380),
    ],
  );

  static const gaharLake = ArenaMap(
    id: 'gahar_lake',
    name: 'Gahar Lake',
    twist: 'Snow on the Oshtorankuh: the wind bends every throw.',
    windy: true,
    ledges: [
      Rect.fromLTWH(50, 330, 160, 16),
      Rect.fromLTWH(330, 380, 300, 16),
      Rect.fromLTWH(400, 270, 160, 16),
      Rect.fromLTWH(750, 330, 160, 16),
    ],
    spawns: [
      Offset(115, groundTop),
      Offset(845, groundTop),
      Offset(130, 330),
      Offset(830, 330),
      Offset(480, 270),
      Offset(380, 380),
      Offset(580, 380),
      Offset(300, groundTop),
    ],
  );

  static const all = [
    falakOlAflak,
    khorramabadBazaar,
    bishehWaterfall,
    gaharLake,
  ];

  static ArenaMap byId(String? id) =>
      all.firstWhere((map) => map.id == id, orElse: () => falakOlAflak);

  /// The same map for everyone in a match picked at random.
  static ArenaMap randomFor(int seed) => all[Random(seed).nextInt(all.length)];

  /// Sideways push on throws in px/s², from -300 to 300 and never a dead
  /// calm on a windy map.
  double windFor(int seed) {
    if (!windy) {
      return 0;
    }
    final random = Random(seed ^ 0x5eed);
    final strength = 120 + random.nextDouble() * 180;
    return random.nextBool() ? strength : -strength;
  }

  Vector2 spawnFor(int index) {
    final spawn = spawns[index % spawns.length];
    return Vector2(spawn.dx, spawn.dy);
  }

  /// The ground or block top at [x], where the crowd stands.
  double surfaceAt(double x) {
    var top = groundTop;
    for (final block in blocks) {
      if (x >= block.left && x <= block.right && block.top < top) {
        top = block.top;
      }
    }
    return top;
  }

  bool isSolid(Vector2 point) {
    if (point.y >= groundTop) {
      return true;
    }
    final offset = Offset(point.x, point.y);
    return ledges.any((ledge) => ledge.contains(offset)) ||
        blocks.any((block) => block.contains(offset));
  }

  bool isOutOfBounds(Vector2 point) =>
      point.x < -60 || point.x > GameConfig.viewWidth + 60 || point.y > 600;

  /// The surface a falling player lands on when the feet move from
  /// [previousY] to [position], or null when they keep falling. Block tops
  /// are always solid; ledges are skipped while dropping through them.
  double? landingY(
    double previousY,
    Vector2 position, {
    required bool ignoreLedges,
  }) {
    if (position.y >= groundTop) {
      return groundTop;
    }
    for (final top in [...blocks, if (!ignoreLedges) ...ledges]) {
      final crossedTop = previousY <= top.top && position.y >= top.top;
      final above = position.x >= top.left - 6 && position.x <= top.right + 6;
      if (crossedTop && above) {
        return top.top;
      }
    }
    return null;
  }

  /// Standing on a ledge, which the down key can drop through.
  bool isOnLedge(Vector2 feet) => _standsOn(ledges, feet);

  /// Standing on anything, so walking off an edge starts a fall.
  bool isStanding(Vector2 feet) =>
      feet.y >= groundTop || _standsOn(ledges, feet) || _standsOn(blocks, feet);

  bool _standsOn(List<Rect> surfaces, Vector2 feet) => surfaces.any(
    (surface) =>
        (feet.y - surface.top).abs() < 0.5 &&
        feet.x >= surface.left - 6 &&
        feet.x <= surface.right + 6,
  );

  /// Pushes a player out of any block they walked into, back to the side
  /// they came from.
  void pushOutOfBlocks(Vector2 feet, double previousX) {
    for (final block in blocks) {
      final beside = feet.y > block.top + 0.5;
      final overlaps =
          feet.x + _halfWidth > block.left && feet.x - _halfWidth < block.right;
      if (beside && overlaps) {
        feet.x = previousX <= block.center.dx
            ? block.left - _halfWidth
            : block.right + _halfWidth;
      }
    }
  }
}
