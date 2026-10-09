import '../db/supabase_schema.g.dart';
import 'weapon.dart';

class PlayerTally {
  PlayerTally({required this.id, required this.name});

  final String id;
  String name;
  int score = 0;
  int knockouts = 0;
  int knockedOut = 0;
  int headshots = 0;
  int ajorHeadshots = 0;
  int? lastScoredAt;
}

/// The live match score, kept by every client from the hit events. The
/// database ranks the same way in `finish_match`, so both agree.
class Scoreboard {
  final _tallies = <String, PlayerTally>{};

  void reset(Map<String, String> namesById) {
    _tallies
      ..clear()
      ..addAll({
        for (final entry in namesById.entries)
          entry.key: PlayerTally(id: entry.key, name: entry.value),
      });
  }

  /// Takes over the scores of a match already under way.
  void restore(Iterable<PlayerTally> tallies) {
    _tallies
      ..clear()
      ..addAll({for (final tally in tallies) tally.id: tally});
  }

  void addPlayer(String id, String name) {
    _tallies.putIfAbsent(id, () => PlayerTally(id: id, name: name));
  }

  Iterable<PlayerTally> get tallies => _tallies.values;

  PlayerTally? operator [](String id) => _tallies[id];

  void recordHit({
    required String attackerId,
    required String victimId,
    required String weaponId,
    required BodyPart part,
    required int points,
    required bool knockout,
    required int atMs,
  }) {
    final attacker = _tallies.putIfAbsent(
      attackerId,
      () => PlayerTally(id: attackerId, name: 'Lor'),
    );
    attacker
      ..score += points
      ..lastScoredAt = atMs;
    if (part == BodyPart.head) {
      attacker.headshots++;
      if (weaponId == Weapon.ajorId) {
        attacker.ajorHeadshots++;
      }
    }
    if (knockout) {
      attacker.knockouts++;
      _tallies[victimId]?.knockedOut++;
    }
  }

  /// Most points first, then fewer knockouts taken, then whoever reached
  /// their score earlier.
  List<PlayerTally> ranked() {
    return _tallies.values.toList()..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) {
        return byScore;
      }
      final byKnockedOut = a.knockedOut.compareTo(b.knockedOut);
      if (byKnockedOut != 0) {
        return byKnockedOut;
      }
      final aAt = a.lastScoredAt ?? 1 << 62;
      final bAt = b.lastScoredAt ?? 1 << 62;
      return aAt.compareTo(bAt);
    });
  }
}
