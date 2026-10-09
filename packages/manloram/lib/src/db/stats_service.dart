// The typed table access API is still experimental.
// ignore_for_file: experimental_member_use

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_schema.g.dart';

enum LeaderboardSort { points, ajorHeadshots }

class StatsService {
  StatsService(this._client);

  final SupabaseClient _client;

  Future<List<LeaderboardRow>> top({
    LeaderboardSort sort = LeaderboardSort.points,
    int limit = 8,
  }) {
    return _client
        .table(Leaderboard.table)
        .select()
        .order(switch (sort) {
          LeaderboardSort.points => Leaderboard.totalScore.desc(),
          LeaderboardSort.ajorHeadshots => Leaderboard.ajorHeadshots.desc(),
        })
        .order(Leaderboard.wins.desc())
        .limit(limit);
  }
}
