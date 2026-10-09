import 'arena_map.dart';
import '../game_config.dart';

class MatchState {
  MatchState({
    required this.hostId,
    required this.matchId,
    required this.seed,
    required this.startedAt,
    required this.participants,
    required this.arena,
  });

  final String hostId;
  final String? matchId;
  final int seed;
  final int startedAt;
  final List<String> participants;
  final ArenaMap arena;

  /// Mountain wind on this map in this match, the same on every device.
  double get wind => arena.windFor(seed);

  int get endsAt => startedAt + GameConfig.matchSeconds * 1000;

  /// Alone in the room: a scarecrow to aim at and nothing saved.
  bool get isPractice => participants.length < 2;

  bool get isRecorded => matchId != null && !isPractice;

  int remainingMs(int nowMs) => (endsAt - nowMs).clamp(0, 1 << 31);
}
