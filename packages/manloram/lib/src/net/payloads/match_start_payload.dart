class MatchStartPayload {
  const MatchStartPayload({
    required this.id,
    required this.matchId,
    required this.seed,
    required this.startedAt,
    required this.participants,
    required this.arenaId,
  });

  factory MatchStartPayload.fromJson(Map<String, dynamic> json) {
    return MatchStartPayload(
      id: json['id'] as String,
      matchId: json['matchId'] as String?,
      seed: json['seed'] as int,
      startedAt: json['startedAt'] as int,
      participants: (json['participants'] as List<dynamic>).cast<String>(),
      arenaId: json['arenaId'] as String? ?? 'falak_ol_aflak',
    );
  }

  /// The host, who created the database match and calls `start_match`.
  final String id;

  /// Null when the match could not be saved; it is then played unrecorded.
  final String? matchId;
  final int seed;
  final int startedAt;
  final List<String> participants;
  final String arenaId;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'matchId': matchId,
      'seed': seed,
      'startedAt': startedAt,
      'participants': participants,
      'arenaId': arenaId,
    };
  }
}
