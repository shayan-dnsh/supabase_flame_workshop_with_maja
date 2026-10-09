import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../game_config.dart';
import '../crowd_difficulty.dart';
import '../lor_painter.dart';
import '../manloram_game.dart';
import '../outfit.dart';
import '../weapon.dart';

/// Villagers lining both sides of the arena, throwing at the players. One
/// player's game picks the throws and broadcasts them like any other
/// launch, so everyone sees the same ones.
class Crowd extends Component with HasGameRef<ManLoramGame> {
  Crowd() : super(priority: 5);

  static const idPrefix = 'crowd-';
  static const _scale = 0.85;

  static bool isCrowd(String id) => id.startsWith(idPrefix);

  static final _members = [
    (x: 24.0, outfit: Outfit.chogha, color: 6),
    (x: 56.0, outfit: Outfit.golvani, color: 1),
    (x: GameConfig.viewWidth - 56, outfit: Outfit.kapenak, color: 4),
    (x: GameConfig.viewWidth - 24, outfit: Outfit.kolah, color: 0),
  ];

  static List<String> get ids => [
    for (var i = 0; i < _members.length; i++) '$idPrefix$i',
  ];

  static CrowdSide _sideOf(int index) =>
      _members[index].x < GameConfig.viewWidth / 2
      ? CrowdSide.left
      : CrowdSide.right;

  /// The villagers on [sides], the ones throwing at this level.
  static List<String> idsFor(Set<CrowdSide> sides) => [
    for (var i = 0; i < _members.length; i++)
      if (sides.contains(_sideOf(i))) '$idPrefix$i',
  ];

  final _throwPose = <String, double>{};
  final _weapons = <String, String>{};

  int _index(String id) => int.parse(id.substring(idPrefix.length));

  Vector2 _feet(String id) {
    final x = _members[_index(id)].x;
    return Vector2(x, gameRef.arena.surfaceAt(x));
  }

  double _aimOf(String id) =>
      _feet(id).x < GameConfig.viewWidth / 2 ? -0.6 : -pi + 0.6;

  /// Where a throw leaves this villager's hand.
  Vector2 throwOrigin(String id) {
    final feet = _feet(id);
    final facing = feet.x < GameConfig.viewWidth / 2 ? 1 : -1;
    return feet + Vector2(facing * 12.0, -40) * _scale;
  }

  /// Plays the wind-up when this villager's throw arrives.
  void animateThrow(String id, String weaponId) {
    _throwPose[id] = 0.35;
    _weapons[id] = weaponId;
  }

  @override
  void update(double dt) {
    for (final id in _throwPose.keys.toList()) {
      final left = _throwPose[id]! - dt;
      if (left <= 0) {
        _throwPose.remove(id);
      } else {
        _throwPose[id] = left;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final active = CrowdDifficulty.sides(gameRef.crowdLevel);
    for (final id in ids) {
      // Villagers wait, faded, until their side joins in.
      final waiting = !active.contains(_sideOf(_index(id)));
      final member = _members[_index(id)];
      final feet = _feet(id);
      final pose = _throwPose[id] ?? 0;
      canvas
        ..save()
        ..translate(feet.x, feet.y)
        ..scale(_scale);
      LorPainter.paint(
        canvas,
        outfit: member.outfit,
        color: GameConfig.playerColors[member.color],
        aim: _aimOf(id),
        charging: pose > 0.15,
        weaponId: _weapons[id] ?? Weapon.stoneId,
        alpha: waiting ? 0.35 : 0.92,
      );
      canvas.restore();
    }
  }
}
