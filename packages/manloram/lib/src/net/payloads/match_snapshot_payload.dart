import '../../game/scoreboard.dart';

/// The running match as one participant sees it, sent when someone drops in:
/// everyone learns the new participant, and the newcomer gets the scores.
class MatchSnapshotPayload {
  const MatchSnapshotPayload({
    required this.id,
    required this.hostId,
    required this.matchId,
    required this.seed,
    required this.startedAt,
    required this.participants,
    required this.tallies,
    required this.arenaId,
    required this.round,
  });

  factory MatchSnapshotPayload.fromJson(Map<String, dynamic> json) {
    return MatchSnapshotPayload(
      id: json['id'] as String,
      hostId: json['hostId'] as String,
      matchId: json['matchId'] as String?,
      seed: json['seed'] as int,
      startedAt: json['startedAt'] as int,
      participants: (json['participants'] as List<dynamic>).cast<String>(),
      tallies: [
        for (final tally in json['tallies'] as List<dynamic>)
          _tallyFromJson(tally as Map<String, dynamic>),
      ],
      arenaId: json['arenaId'] as String? ?? 'falak_ol_aflak',
      round: json['round'] as int? ?? 1,
    );
  }

  /// The participant who answered the join request.
  final String id;
  final String hostId;
  final String? matchId;
  final int seed;
  final int startedAt;
  final List<String> participants;
  final List<PlayerTally> tallies;
  final String arenaId;
  final int round;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hostId': hostId,
      'matchId': matchId,
      'seed': seed,
      'startedAt': startedAt,
      'participants': participants,
      'tallies': [for (final tally in tallies) _tallyToJson(tally)],
      'arenaId': arenaId,
      'round': round,
    };
  }

  static PlayerTally _tallyFromJson(Map<String, dynamic> json) {
    return PlayerTally(id: json['id'] as String, name: json['name'] as String)
      ..score = json['score'] as int
      ..knockouts = json['kos'] as int
      ..knockedOut = json['kod'] as int
      ..headshots = json['heads'] as int
      ..ajorHeadshots = json['ajor'] as int
      ..lastScoredAt = json['at'] as int?;
  }

  static Map<String, dynamic> _tallyToJson(PlayerTally tally) {
    return {
      'id': tally.id,
      'name': tally.name,
      'score': tally.score,
      'kos': tally.knockouts,
      'kod': tally.knockedOut,
      'heads': tally.headshots,
      'ajor': tally.ajorHeadshots,
      'at': tally.lastScoredAt,
    };
  }
}
