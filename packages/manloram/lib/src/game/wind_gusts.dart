import 'dart:math';

import '../game_config.dart';

/// One gust: blows from [startMs] to [endMs] after the match starts, with a
/// strength that rises and falls smoothly. [storm] gusts are strong enough
/// to turn a throw around.
class Gust {
  const Gust({
    required this.startMs,
    required this.endMs,
    required this.strength,
    required this.storm,
  });

  final int startMs;
  final int endMs;

  /// Signed push in px/s² at the gust's peak; positive blows right.
  final double strength;
  final bool storm;

  double at(int elapsedMs) {
    if (elapsedMs < startMs || elapsedMs > endMs) {
      return 0;
    }
    final progress = (elapsedMs - startMs) / (endMs - startMs);
    return strength * sin(pi * progress);
  }
}

/// The gusts of one match, worked out from its seed so every device feels
/// the same wind. Gusts blow from difficulty level 2; from level 3 some are
/// storms that can blow a throw back at whoever threw it.
class WindGusts {
  WindGusts(int seed) : _gusts = _schedule(seed);

  static const gustsFromLevel = 2;
  static const stormsFromLevel = 3;

  final List<Gust> _gusts;

  static List<Gust> _schedule(int seed) {
    final random = Random(seed ^ 0x9e3779b9);
    final gusts = <Gust>[];
    var at = 4000;
    final total = (GameConfig.matchSeconds + 10) * 1000;
    while (at < total) {
      final duration = 2500 + random.nextInt(2500);
      final direction = random.nextBool() ? 1.0 : -1.0;
      final storm = random.nextDouble() < 0.4;
      final strength = storm
          ? 1100 + random.nextDouble() * 500
          : 300 + random.nextDouble() * 300;
      gusts.add(
        Gust(
          startMs: at,
          endMs: at + duration,
          strength: direction * strength,
          storm: storm,
        ),
      );
      at += duration + 5000 + random.nextInt(6000);
    }
    return gusts;
  }

  /// The gust blowing [elapsedMs] into the match at difficulty [level].
  /// Below level 3 a storm blows as an ordinary strong gust.
  double at({required int elapsedMs, required int level}) {
    if (level < gustsFromLevel) {
      return 0;
    }
    for (final gust in _gusts) {
      if (elapsedMs < gust.startMs) {
        return 0;
      }
      if (elapsedMs <= gust.endMs) {
        final push = gust.at(elapsedMs);
        if (gust.storm && level < stormsFromLevel) {
          return push.sign * min(push.abs(), 600);
        }
        return push;
      }
    }
    return 0;
  }
}
