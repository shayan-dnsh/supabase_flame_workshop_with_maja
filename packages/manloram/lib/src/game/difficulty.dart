import 'dart:math';

import 'package:flame/components.dart';

import '../game_config.dart';
import 'wind_gusts.dart';

enum CrowdSide { left, right }

/// The match gets harder step by step. The level climbs with every round,
/// and every 30 seconds without a knockout, and each level adds something:
///
/// 1. Calm, just the players.
/// 2. Villagers on the left throw stones.
/// 3. The right side joins, and they throw Ajor too.
/// 4. Wind gusts bend every throw.
/// 5. Storm gusts can blow a throw back; the crowd keeps speeding up.
class CrowdDifficulty {
  /// Knockouts by the crowd also start new rounds, so the level is capped
  /// where the crowd is fierce but can still be dodged.
  static const maxLevel = 6;

  static int level({required int round, required int elapsedMs}) => min(
    maxLevel,
    round + max(0, elapsedMs) ~/ (GameConfig.levelEverySeconds * 1000),
  );

  static Set<CrowdSide> sides(int level) => switch (level) {
    <= 1 => const {},
    2 => const {CrowdSide.left},
    _ => const {CrowdSide.left, CrowdSide.right},
  };

  /// Seconds between throws once the crowd is in: about 3 at first, a bit
  /// over one at the top.
  static double intervalSeconds(int level) => max(1.2, 3.3 - 0.4 * (level - 1));

  /// Chance that a throw is an Ajor: none until the right side joins.
  static double ajorChance(int level) =>
      level < 3 ? 0 : min(0.5, 0.15 + 0.07 * (level - 3));

  /// How far, in pixels, a throw may land from the target's chest.
  static double aimError(int level) => max(30, 90 - 11 * (level - 1));

  /// What the new level brings, for the banner that announces it.
  static String announce(int level) => switch (level) {
    2 => 'Level 2: villagers on the left start throwing!',
    3 => 'Level 3: the right side joins, with Ajor!',
    WindGusts.gustsFromLevel => 'Level 4: wind gusts bend every throw!',
    WindGusts.stormsFromLevel =>
      'Level 5: storms can blow a throw back at you!',
    _ => 'Level $level: the crowd throws faster!',
  };

  /// Launch velocity that lands a throw from [from] on [to] after [seconds],
  /// against gravity and the [wind] blowing now.
  static Vector2 launchToHit(
    Vector2 from,
    Vector2 to,
    double seconds, {
    double wind = 0,
  }) {
    return Vector2(
      (to.x - from.x - 0.5 * wind * seconds * seconds) / seconds,
      (to.y - from.y - 0.5 * GameConfig.gravity * seconds * seconds) / seconds,
    );
  }
}
