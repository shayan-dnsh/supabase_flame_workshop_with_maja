// The typed table access API is still experimental.
// ignore_for_file: experimental_member_use

import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_schema.g.dart';

/// The database side of a match. Every write that touches points goes
/// through the security definer functions of migration 0002.
class MatchService {
  MatchService(this._client);

  static const _uniqueViolation = '23505';
  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final SupabaseClient _client;
  final _random = Random();

  String get _userId => _client.auth.currentUser!.id;

  /// Creates a lobby match for [room], joins it, and returns its id.
  Future<String> createMatch({
    required String room,
    String arenaId = 'falak_ol_aflak',
  }) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final match = await _client
            .table(Matches.table)
            .insert(
              MatchesInsert(
                arenaId: arenaId,
                hostId: _userId,
                roomCode: matchCode(room, _random),
              ),
            )
            .select()
            .single();
        await join(match.id);
        return match.id;
      } on PostgrestApiException catch (error) {
        if (error.errorCode != _uniqueViolation || attempt >= 2) {
          rethrow;
        }
      }
    }
  }

  /// A code such as `MAIN7K2Q`: up to four characters of the room, so the
  /// match is recognisable, and four random ones, so a match left behind in
  /// the room never blocks the next one.
  static String matchCode(String room, Random random) {
    final prefix = room
        .toUpperCase()
        .replaceAll(RegExp('[^A-Z0-9]'), '')
        .padRight(4, 'X')
        .substring(0, 4);
    final suffix = [
      for (var i = 0; i < 4; i++)
        _codeAlphabet[random.nextInt(_codeAlphabet.length)],
    ].join();
    return '$prefix$suffix';
  }

  Future<void> join(String matchId) async {
    await _client
        .table(MatchPlayers.table)
        .insert(MatchPlayersInsert(matchId: matchId, playerId: _userId));
  }

  Future<void> start(String matchId) async {
    await _client.rpc<dynamic>('start_match', params: {'p_match_id': matchId});
  }

  /// Called by the player who was hit, never by the thrower.
  Future<void> recordHit({
    required String matchId,
    required String attackerId,
    required String weaponId,
    required BodyPart part,
    required double distance,
    required bool knockout,
  }) async {
    await _client.rpc<dynamic>(
      'record_hit',
      params: {
        'p_match_id': matchId,
        'p_attacker_id': attackerId,
        'p_weapon_id': weaponId,
        'p_body_part': part.wireName,
        'p_distance': distance,
        'p_is_kill': knockout,
      },
    );
  }

  /// Ranks the match and saves everyone's totals. Safe to call from every
  /// participant: only the first call counts. Returns the winner's id.
  Future<String?> finish(String matchId) async {
    final winnerId = await _client.rpc<dynamic>(
      'finish_match',
      params: {'p_match_id': matchId},
    );
    return winnerId as String?;
  }
}
