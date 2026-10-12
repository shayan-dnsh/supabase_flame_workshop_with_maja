import 'dart:math';

import '../game_config.dart';
import 'wind_gusts.dart';

/// The match gets harder step by step. The level climbs with every round,
/// and every 30 seconds without a knockout, and each level adds something:
///
/// 1. Calm, just the players.
/// 2. Wind gusts bend every throw.
/// 3. Storm gusts can blow a throw back.
class Difficulty {
  static const maxLevel = WindGusts.stormsFromLevel;

  static int level({required int round, required int elapsedMs}) => min(
    maxLevel,
    round + max(0, elapsedMs) ~/ (GameConfig.levelEverySeconds * 1000),
  );

  /// What the new level brings, for the banner that announces it.
  static String announce(int level) => switch (level) {
    WindGusts.gustsFromLevel => 'Level $level: wind gusts bend every throw!',
    _ => 'Level $level: storms can blow a throw back at you!',
  };
}
