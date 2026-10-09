import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manloram/src/db/match_service.dart';
import 'package:manloram/src/db/profile_service.dart';
import 'package:manloram/src/db/supabase_schema.g.dart';
import 'package:manloram/src/game/arena_map.dart';
import 'package:manloram/src/game/body_geometry.dart';
import 'package:manloram/src/game/crowd_difficulty.dart';
import 'package:manloram/src/game/wind_gusts.dart';
import 'package:manloram/src/game/outfit.dart';
import 'package:manloram/src/game/scoreboard.dart';
import 'package:manloram/src/game/throw_physics.dart';
import 'package:manloram/src/game/touch_sticks.dart';
import 'package:manloram/src/game/weapon.dart';
import 'package:manloram/src/game_config.dart';
import 'package:manloram/src/net/payloads/lobby_presence.dart';
import 'package:manloram/src/net/payloads/match_snapshot_payload.dart';

void main() {
  group('Touch sticks', () {
    test('the movement stick walks, jumps and drops past its thresholds', () {
      final resting = MoveStick.at(0.1, 0.1);
      expect(resting.direction, 0);
      expect(resting.jump, isFalse);
      expect(resting.drop, isFalse);

      expect(MoveStick.at(-0.8, 0).direction, -1);
      expect(MoveStick.at(0.8, 0).direction, 1);
      expect(MoveStick.at(0, -0.9).jump, isTrue);
      expect(MoveStick.at(0, 0.9).drop, isTrue);
    });

    test('walking with a slightly raised thumb does not hop', () {
      final stick = MoveStick.at(cos(-pi / 8), sin(-pi / 8));
      expect(stick.direction, 1);
      expect(stick.jump, isFalse);
    });

    test('a diagonal push walks and jumps at once', () {
      final stick = MoveStick.at(cos(-pi / 4), sin(-pi / 4));
      expect(stick.direction, 1);
      expect(stick.jump, isTrue);
    });

    test('the aiming stick throws the way it is pushed', () {
      expect(AimStick.angle(0.05, 0.05), isNull);
      expect(AimStick.angle(1, 0), closeTo(0, 1e-9));
      expect(AimStick.angle(0, -1), closeTo(-pi / 2, 1e-9));
      expect(AimStick.angle(-0.7, -0.7), closeTo(-3 * pi / 4, 1e-9));
    });
  });

  group('ThrowPhysics', () {
    test('a tap throws at minimum power, a full charge at full power', () {
      expect(ThrowPhysics.powerFor(0), GameConfig.minPower);
      expect(ThrowPhysics.powerFor(GameConfig.chargeSeconds), 1);
      expect(ThrowPhysics.powerFor(10), 1);
      expect(
        ThrowPhysics.powerFor(GameConfig.chargeSeconds / 2),
        closeTo((GameConfig.minPower + 1) / 2, 1e-9),
      );
    });

    test('launch speed scales with power and follows the aim', () {
      final velocity = ThrowPhysics.launchVelocity(-pi / 2, 0.5, 1000);
      expect(velocity.x, closeTo(0, 1e-9));
      expect(velocity.y, closeTo(-500, 1e-9));
    });

    test('gravity pulls the arc down', () {
      final start = Vector2(100, 400);
      final velocity = Vector2(300, -600);
      final position = ThrowPhysics.positionAt(start, velocity, 1);
      expect(position.x, 400);
      expect(position.y, 400 - 600 + GameConfig.gravity / 2);
    });

    test('a full-power stone crosses most of the arena', () {
      final velocity = ThrowPhysics.launchVelocity(
        -pi / 4,
        1,
        Weapon.stone.speed,
      );
      final range = velocity.length * velocity.length / GameConfig.gravity;
      expect(range, greaterThan(GameConfig.viewWidth * 0.75));
    });
  });

  group('BodyGeometry.hitPart', () {
    final feet = Vector2(500, ArenaMap.groundTop);
    final head = feet + BodyGeometry.headCenter;

    test('a throw through the head is a headshot', () {
      expect(
        BodyGeometry.hitPart(
          feet: feet,
          from: head - Vector2(30, 0),
          to: head + Vector2(30, 0),
          radius: 5,
        ),
        BodyPart.head,
      );
    });

    test('a throw through the chest hits the body', () {
      expect(
        BodyGeometry.hitPart(
          feet: feet,
          from: feet + Vector2(-40, -25),
          to: feet + Vector2(40, -25),
          radius: 5,
        ),
        BodyPart.body,
      );
    });

    test('a throw over the hat misses', () {
      expect(
        BodyGeometry.hitPart(
          feet: feet,
          from: head + Vector2(-40, -30),
          to: head + Vector2(40, -30),
          radius: 5,
        ),
        isNull,
      );
    });

    test('a fast Ajor cannot tunnel through the head in one frame', () {
      final frameDistance = Weapon.ajor.speed / 30;
      expect(
        BodyGeometry.hitPart(
          feet: feet,
          from: head - Vector2(frameDistance / 2, 0),
          to: head + Vector2(frameDistance / 2, 0),
          radius: 7,
        ),
        BodyPart.head,
      );
    });

    test('the head is checked before the body it touches', () {
      expect(
        BodyGeometry.hitPart(
          feet: feet,
          from: head + Vector2(0, -40),
          to: feet + Vector2(0, -20),
          radius: 5,
        ),
        BodyPart.head,
      );
    });
  });

  group('ArenaMap', () {
    const arena = ArenaMap.falakOlAflak;
    final ledge = arena.ledges.first;

    test('falling onto a ledge lands on top of it', () {
      expect(
        arena.landingY(
          ledge.top - 4,
          Vector2(ledge.center.dx, ledge.top + 3),
          ignoreLedges: false,
        ),
        ledge.top,
      );
    });

    test('jumping up through a ledge does not land on it', () {
      expect(
        arena.landingY(
          ledge.top + 10,
          Vector2(ledge.center.dx, ledge.top + 3),
          ignoreLedges: false,
        ),
        isNull,
      );
    });

    test('dropping down ignores the ledge but not the ground', () {
      expect(
        arena.landingY(
          ledge.top - 4,
          Vector2(ledge.center.dx, ledge.top + 3),
          ignoreLedges: true,
        ),
        isNull,
      );
      expect(
        arena.landingY(
          ArenaMap.groundTop - 5,
          Vector2(10, ArenaMap.groundTop + 2),
          ignoreLedges: true,
        ),
        ArenaMap.groundTop,
      );
    });

    test('every spawn on every map stands on something', () {
      for (final map in ArenaMap.all) {
        for (var i = 0; i < map.spawns.length; i++) {
          final spawn = map.spawnFor(i);
          expect(map.isStanding(spawn), isTrue, reason: '${map.id} $spawn');
          expect(
            map.isSolid(spawn - Vector2(0, 30)),
            isFalse,
            reason: '${map.id} $spawn is inside a wall',
          );
        }
      }
    });

    test('the bazaar tower blocks walking and holds players on top', () {
      const bazaar = ArenaMap.khorramabadBazaar;
      final tower = bazaar.blocks.single;
      final feet = Vector2(tower.left + 3, ArenaMap.groundTop);
      bazaar.pushOutOfBlocks(feet, tower.left - 20);
      expect(feet.x, lessThanOrEqualTo(tower.left - 11));
      expect(
        bazaar.landingY(
          tower.top - 3,
          Vector2(tower.center.dx, tower.top + 4),
          ignoreLedges: true,
        ),
        tower.top,
        reason: 'dropping does not fall through a tower',
      );
      expect(bazaar.isSolid(Vector2(tower.center.dx, tower.top + 20)), isTrue);
    });

    test('the crowd stands on the Bisheh cliffs', () {
      const bisheh = ArenaMap.bishehWaterfall;
      expect(bisheh.surfaceAt(24), bisheh.blocks.first.top);
      expect(bisheh.surfaceAt(480), ArenaMap.groundTop);
    });

    test('wind blows only at Gahar Lake, the same for the same seed', () {
      expect(ArenaMap.falakOlAflak.windFor(42), 0);
      final wind = ArenaMap.gaharLake.windFor(42);
      expect(wind.abs(), inInclusiveRange(120, 300));
      expect(ArenaMap.gaharLake.windFor(42), wind);
      expect(ArenaMap.randomFor(7).id, ArenaMap.randomFor(7).id);
    });
  });

  group('CrowdDifficulty', () {
    test('every round makes the crowd throw faster, heavier and truer', () {
      for (var level = 1; level < CrowdDifficulty.maxLevel; level++) {
        expect(
          CrowdDifficulty.intervalSeconds(level + 1),
          lessThanOrEqualTo(CrowdDifficulty.intervalSeconds(level)),
        );
        expect(
          CrowdDifficulty.ajorChance(level + 1),
          greaterThanOrEqualTo(CrowdDifficulty.ajorChance(level)),
        );
        expect(
          CrowdDifficulty.aimError(level + 1),
          lessThanOrEqualTo(CrowdDifficulty.aimError(level)),
        );
      }
      expect(CrowdDifficulty.level(round: 1, elapsedMs: 0), 1);
      expect(CrowdDifficulty.level(round: 3, elapsedMs: 0), 3);
      expect(CrowdDifficulty.level(round: 1, elapsedMs: 65000), 3);
      expect(
        CrowdDifficulty.level(round: 20, elapsedMs: 0),
        CrowdDifficulty.maxLevel,
      );
    });

    test('a crowd throw lands where it was aimed, wind included', () {
      final from = Vector2(24, 430);
      final to = Vector2(600, 440);
      const seconds = 0.9;
      const wind = -200.0;
      final velocity = CrowdDifficulty.launchToHit(
        from,
        to,
        seconds,
        wind: wind,
      );
      final landed = ThrowPhysics.positionAt(
        from,
        velocity,
        seconds,
        wind: wind,
      );
      expect(landed.x, closeTo(to.x, 1e-3));
      expect(landed.y, closeTo(to.y, 1e-3));
    });
  });

  group('Weapon', () {
    test('an Ajor headshot is worth 100 and double damage', () {
      expect(Weapon.ajor.pointsFor(BodyPart.head), 100);
      expect(Weapon.ajor.pointsFor(BodyPart.body), 15);
      expect(
        Weapon.ajor.damageFor(BodyPart.head),
        Weapon.ajor.damage * GameConfig.headDamageMultiplier,
      );
    });

    test(
      'the catalog takes tuning from the database and keeps unknowns out',
      () {
        final catalog = WeaponCatalog()
          ..replaceWith([
            const Weapon(
              id: Weapon.ajorId,
              name: 'Ajor',
              damage: 50,
              speed: 900,
              cooldownMs: 1000,
              bodyPoints: 20,
              headPoints: 120,
            ),
            const Weapon(
              id: 'slingshot',
              name: 'Slingshot',
              damage: 1,
              speed: 1,
              cooldownMs: 1,
              bodyPoints: 1,
              headPoints: 1,
            ),
          ]);
        expect(catalog.ajor.headPoints, 120);
        expect(catalog.byId('slingshot').id, Weapon.stoneId);
      },
    );
  });

  group('Scoreboard', () {
    test('counts points, headshots, Ajor headshots and knockouts', () {
      final board = Scoreboard()..reset({'a': 'Ali', 'b': 'Bahram'});
      board
        ..recordHit(
          attackerId: 'a',
          victimId: 'b',
          weaponId: Weapon.ajorId,
          part: BodyPart.head,
          points: 100,
          knockout: true,
          atMs: 1,
        )
        ..recordHit(
          attackerId: 'b',
          victimId: 'a',
          weaponId: Weapon.stoneId,
          part: BodyPart.head,
          points: 25,
          knockout: false,
          atMs: 2,
        );
      final a = board['a']!;
      expect(a.score, 100);
      expect(a.headshots, 1);
      expect(a.ajorHeadshots, 1);
      expect(a.knockouts, 1);
      expect(board['b']!.knockedOut, 1);
      expect(board['b']!.ajorHeadshots, 0);
      expect(board.ranked().map((tally) => tally.id), ['a', 'b']);
    });

    test('ties go to fewer knockouts taken, then the earlier scorer', () {
      final board = Scoreboard()
        ..reset({'a': 'Ali', 'b': 'Bahram', 'c': 'Cyrus'});
      void hit(String attacker, String victim, int at, {bool ko = false}) {
        board.recordHit(
          attackerId: attacker,
          victimId: victim,
          weaponId: Weapon.stoneId,
          part: BodyPart.body,
          points: 10,
          knockout: ko,
          atMs: at,
        );
      }

      hit('b', 'a', 1, ko: true);
      hit('a', 'c', 2);
      hit('c', 'b', 3);
      expect(board.ranked().map((tally) => tally.id), ['b', 'c', 'a']);
    });
  });

  test('match codes satisfy the database check for any room name', () {
    final random = Random(1);
    final pattern = RegExp(r'^[A-Z0-9]{4,8}$');
    for (final room in ['main', 'a', 'Team-Lorestan 2026', '', 'xy']) {
      final code = MatchService.matchCode(room, random);
      expect(pattern.hasMatch(code), isTrue, reason: '$room -> $code');
      expect(code, hasLength(8));
    }
  });

  group('Profile skin', () {
    test('stores outfit and colour together and reads them back', () {
      const profile = Profile(
        id: 'a',
        username: 'Lor-1234',
        homeCity: 'Khorramabad',
        colorIndex: 3,
        outfit: Outfit.chogha,
      );
      expect(profile.skin, 'chogha:3');
      expect(Profile.parseSkin(profile.skin), (Outfit.chogha, 3));
    });

    test('profiles saved before outfits get the felt hat', () {
      expect(Profile.parseSkin('5'), (Outfit.kolah, 5));
      expect(Profile.parseSkin(null), (Outfit.kolah, 0));
      expect(Profile.parseSkin('crown:2'), (Outfit.kolah, 2));
    });
  });

  test('a match snapshot carries the scores to a player who drops in', () {
    final tally = PlayerTally(id: 'a', name: 'Ali')
      ..score = 125
      ..knockouts = 1
      ..headshots = 2
      ..ajorHeadshots = 1
      ..lastScoredAt = 42;
    final snapshot = MatchSnapshotPayload(
      id: 'a',
      hostId: 'a',
      matchId: 'm',
      seed: 7,
      startedAt: 1000,
      participants: const ['a', 'b', 'c'],
      tallies: [tally],
      arenaId: 'gahar_lake',
      round: 3,
    );
    final copy = MatchSnapshotPayload.fromJson(snapshot.toJson());
    expect(copy.participants, ['a', 'b', 'c']);
    expect(copy.tallies.single.score, 125);
    expect(copy.tallies.single.ajorHeadshots, 1);
    expect(copy.tallies.single.lastScoredAt, 42);
    expect(copy.arenaId, 'gahar_lake');
    expect(copy.round, 3);
  });

  test('heavier hits slow a player down more and for longer', () {
    final stoneBody = Weapon.stone.slowFor(BodyPart.body);
    final stoneHead = Weapon.stone.slowFor(BodyPart.head);
    final ajorBody = Weapon.ajor.slowFor(BodyPart.body);
    final ajorHead = Weapon.ajor.slowFor(BodyPart.head);
    expect(stoneHead.speed, lessThan(stoneBody.speed));
    expect(ajorBody.speed, lessThan(stoneBody.speed));
    expect(ajorHead.speed, lessThan(ajorBody.speed));
    expect(ajorHead.seconds, greaterThan(stoneBody.seconds));
  });

  test('presence carries the join time and the removed players', () {
    const presence = LobbyPresence(
      id: 'host',
      name: 'Ali',
      city: 'Dorud',
      colorIndex: 2,
      phase: 'lobby',
      joinedAt: 1234,
      kicked: ['troll'],
    );
    final copy = LobbyPresence.fromJson(presence.toJson());
    expect(copy.joinedAt, 1234);
    expect(copy.kicked, ['troll']);
    final old = LobbyPresence.fromJson({
      'id': 'a',
      'name': 'A',
      'color': 0,
      'phase': 'lobby',
    });
    expect(old.kicked, isEmpty, reason: 'older clients send no list');
  });

  group('step-by-step difficulty', () {
    test('the crowd joins side by side, Ajor only once both sides throw', () {
      expect(CrowdDifficulty.sides(1), isEmpty);
      expect(CrowdDifficulty.sides(2), {CrowdSide.left});
      expect(CrowdDifficulty.sides(3), {CrowdSide.left, CrowdSide.right});
      expect(CrowdDifficulty.ajorChance(2), 0);
      expect(CrowdDifficulty.ajorChance(3), greaterThan(0));
      expect(CrowdDifficulty.announce(4), contains('wind'));
      expect(CrowdDifficulty.announce(5), contains('back'));
    });

    test('gusts blow only from level 4, the same for the same seed', () {
      final a = WindGusts(99);
      final b = WindGusts(99);
      var blew = false;
      for (var ms = 0; ms < 120000; ms += 250) {
        expect(a.at(elapsedMs: ms, level: 3), 0);
        final push = a.at(elapsedMs: ms, level: 6);
        expect(push, b.at(elapsedMs: ms, level: 6));
        blew = blew || push != 0;
      }
      expect(blew, isTrue);
    });

    test('a storm can blow a throw back at whoever threw it', () {
      final gusts = WindGusts(7);
      var strongest = 0.0;
      for (var ms = 0; ms < 120000; ms += 100) {
        final push = gusts.at(elapsedMs: ms, level: 5).abs();
        if (push > strongest) {
          strongest = push;
        }
        expect(
          gusts.at(elapsedMs: ms, level: 4).abs(),
          lessThanOrEqualTo(600),
          reason: 'storms are tamed before level 5',
        );
      }
      expect(strongest, greaterThan(1000));
      // A gentle Ajor lob thrown right into a storm from the left.
      final start = Vector2(400, 400);
      final velocity = Vector2(300, -500);
      final landed = ThrowPhysics.positionAt(
        start,
        velocity,
        0.7,
        wind: -strongest,
      );
      expect(landed.x, lessThan(start.x), reason: 'it came back');
    });
  });

  group('chub', () {
    final attacker = Vector2(300, ArenaMap.groundTop);

    test('hits someone right in front, not someone behind or far away', () {
      expect(
        BodyGeometry.swingHit(
          attackerFeet: attacker,
          aim: 0,
          victimFeet: attacker + Vector2(40, 0),
        ),
        BodyPart.body,
      );
      expect(
        BodyGeometry.swingHit(
          attackerFeet: attacker,
          aim: 0,
          victimFeet: attacker - Vector2(40, 0),
        ),
        isNull,
      );
      expect(
        BodyGeometry.swingHit(
          attackerFeet: attacker,
          aim: 0,
          victimFeet: attacker + Vector2(120, 0),
        ),
        isNull,
      );
    });

    test('swinging upwards goes for the head', () {
      expect(
        BodyGeometry.swingHit(
          attackerFeet: attacker,
          aim: -0.8,
          victimFeet: attacker + Vector2(40, 0),
        ),
        BodyPart.head,
      );
    });

    test('the catalog knows the chub and its slowdown', () {
      final chub = WeaponCatalog().byId(Weapon.chubId);
      expect(chub.isChub, isTrue);
      expect(chub.pointsFor(BodyPart.head), 50);
      expect(chub.slowFor(BodyPart.head).speed, lessThan(1));
    });
  });
}
