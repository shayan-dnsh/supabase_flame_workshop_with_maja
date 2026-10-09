// Integration test against a running local Supabase stack.
// Start it first with `supabase start` from the repository root.

// The typed table access API is still experimental.
// ignore_for_file: experimental_member_use

import 'package:flutter_test/flutter_test.dart';
import 'package:manloram/src/db/match_service.dart';
import 'package:manloram/src/db/profile_service.dart';
import 'package:manloram/src/db/stats_service.dart';
import 'package:manloram/src/db/supabase_schema.g.dart';
import 'package:manloram/src/db/weapon_service.dart';
import 'package:manloram/src/game/weapon.dart';
import 'package:supabase/supabase.dart';

const _url = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'http://127.0.0.1:54621',
);
const _key = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
);

void main() {
  late SupabaseClient clientA;
  late SupabaseClient clientB;
  late String idA;
  late String idB;

  setUpAll(() async {
    SupabaseClient client() => SupabaseClient(
      _url,
      _key,
      authOptions: AuthClientOptions(asyncStorage: MemoryAuthAsyncStorage()),
    );
    clientA = client();
    clientB = client();
    await clientA.auth.signInAnonymously();
    await clientB.auth.signInAnonymously();
    idA = clientA.auth.currentUser!.id;
    idB = clientB.auth.currentUser!.id;
    // Players need a profile before they can join a match.
    await ProfileService(clientA).loadOrCreate();
    await ProfileService(clientB).loadOrCreate();
  });

  tearDownAll(() async {
    await clientA.dispose();
    await clientB.dispose();
  });

  test('weapons load with the side-view tuning', () async {
    final weapons = await WeaponService(clientA).load();
    final ajor = weapons.singleWhere((weapon) => weapon.id == Weapon.ajorId);
    expect(ajor.headPoints, 100);
    final chub = weapons.singleWhere((weapon) => weapon.id == Weapon.chubId);
    expect(chub.headPoints, 50);
    expect(ajor.speed, Weapon.ajor.speed);
  });

  test('first launch creates a profile, and names stay unique', () async {
    final profileA = (await ProfileService(clientA).loadOrCreate())!;
    final profileB = (await ProfileService(clientB).loadOrCreate())!;
    expect(profileA.username, startsWith('Lor-'));
    expect(
      (await ProfileService(clientA).loadOrCreate())!.username,
      profileA.username,
    );

    final renamed = profileA.copyWith(username: 'Ajor-${idA.substring(0, 6)}');
    expect(await ProfileService(clientA).save(renamed), isNull);
    expect(
      await ProfileService(clientB)
          .save(profileB.copyWith(username: renamed.username)),
      'That name is taken',
    );
  });

  test(
    'a two-player match scores an Ajor headshot onto the leaderboard',
    () async {
      final matchesA = MatchService(clientA);
      final matchesB = MatchService(clientB);

      final matchId = await matchesA.createMatch(room: 'it');
      await matchesB.join(matchId);
      await expectLater(matchesB.start(matchId), throwsA(isA<Exception>()));
      await matchesA.start(matchId);

      // The thrower cannot report its own hit as the victim.
      await expectLater(
        matchesA.recordHit(
          matchId: matchId,
          attackerId: idA,
          weaponId: Weapon.ajorId,
          part: BodyPart.head,
          distance: 300,
          knockout: false,
        ),
        throwsA(isA<Exception>()),
      );

      // B was hit by A's Ajor, in the head, and B reports it.
      await matchesB.recordHit(
        matchId: matchId,
        attackerId: idA,
        weaponId: Weapon.ajorId,
        part: BodyPart.head,
        distance: 300,
        knockout: true,
      );

      expect(await matchesA.finish(matchId), idA);
      expect(
        await matchesB.finish(matchId),
        idA,
        reason: 'finish is idempotent',
      );

      final players = await clientA
          .table(MatchPlayers.table)
          .select()
          .where(MatchPlayers.matchId.eq(matchId))
          .order(MatchPlayers.placement);
      expect(players.map((row) => row.playerId), [idA, idB]);
      expect(players.first.score, 100);
      expect(players.first.ajorHeadshots, 1);
      expect(players.last.deaths, 1);

      final board = await StatsService(clientA).top(limit: 200);
      final rowA = board.singleWhere((row) => row.playerId == idA);
      expect(rowA.totalScore, 100);
      expect(rowA.wins, 1);
      expect(rowA.ajorHeadshots, 1);
      expect(rowA.matchesPlayed, 1);
    },
  );

  test('a third player can drop into a match that already started', () async {
    final clientC = SupabaseClient(
      _url,
      _key,
      authOptions: AuthClientOptions(asyncStorage: MemoryAuthAsyncStorage()),
    );
    addTearDown(clientC.dispose);
    await clientC.auth.signInAnonymously();
    await ProfileService(clientC).loadOrCreate();

    final matchId = await MatchService(clientA).createMatch(room: 'it');
    await MatchService(clientB).join(matchId);
    await MatchService(clientA).start(matchId);

    await MatchService(clientC).join(matchId);
    await MatchService(clientC).recordHit(
      matchId: matchId,
      attackerId: idA,
      weaponId: Weapon.stoneId,
      part: BodyPart.body,
      distance: 120,
      knockout: false,
    );
    expect(await MatchService(clientA).finish(matchId), idA);
  });
}
