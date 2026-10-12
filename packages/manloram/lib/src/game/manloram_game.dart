import 'dart:async';
import 'dart:math';
import 'dart:ui' show Color, Offset;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../app/overlay_ids.dart';
import '../db/backend.dart';
import '../db/profile_service.dart';
import '../db/supabase_schema.g.dart';
import '../env.dart';
import '../game_config.dart';
import '../net/net_events.dart';
import '../net/net_service.dart';
import '../net/payloads/hit_payload.dart';
import '../net/payloads/join_request_payload.dart';
import '../net/payloads/kick_payload.dart';
import '../net/payloads/launch_payload.dart';
import '../net/payloads/lobby_presence.dart';
import '../net/payloads/match_snapshot_payload.dart';
import '../net/payloads/match_start_payload.dart';
import '../net/payloads/player_state_payload.dart';
import '../net/payloads/swing_payload.dart';
import 'arena_map.dart';
import 'body_geometry.dart';
import 'components/wind_streaks.dart';
import 'difficulty.dart';
import 'components/aim_guide.dart';
import 'components/arena_background.dart';
import 'components/effects.dart';
import 'components/local_lor.dart';
import 'components/projectile.dart';
import 'components/remote_lor.dart';
import 'components/scarecrow.dart';
import 'game_phase.dart';
import 'match_state.dart';
import 'outfit.dart';
import 'scoreboard.dart';
import 'weapon.dart';
import 'wind_gusts.dart';

enum SaveStatus { none, practice, unsaved, saving, saved, failed }

class FeedEntry {
  const FeedEntry({required this.text, required this.mine});

  final String text;
  final bool mine;
}

class ManLoramGame extends FlameGame with HasKeyboardHandlerComponents {
  ManLoramGame({
    required this.net,
    required this.myId,
    required this.backend,
    required Profile profile,
  }) : profile = ValueNotifier(profile),
       super(
         camera: CameraComponent.withFixedResolution(
           width: GameConfig.viewWidth,
           height: GameConfig.viewHeight,
         ),
       );

  static const _scarecrowId = 'scarecrow';
  static const _feedLength = 5;

  final NetService net;
  final String myId;
  final Backend? backend;
  final weapons = WeaponCatalog();
  final createdAt = DateTime.now();

  final phase = ValueNotifier<GamePhase>(GamePhase.lobby);
  final roster = ValueNotifier<List<LobbyPresence>>([]);
  final ValueNotifier<Profile> profile;
  final hpNotifier = ValueNotifier<double>(GameConfig.maxHp);
  final weaponNotifier = ValueNotifier<Weapon>(Weapon.stone);
  final standings = ValueNotifier<List<PlayerTally>>([]);
  final feed = ValueNotifier<List<FeedEntry>>([]);
  final saveStatus = ValueNotifier<SaveStatus>(SaveStatus.none);
  final leaderboardVersion = ValueNotifier<int>(0);

  MatchState? match;
  LocalLor? me;
  final remotes = <String, RemoteLor>{};
  final projectiles = <String, Projectile>{};
  final scoreboard = Scoreboard();

  /// The map on screen: the match's, or in the lobby the one picked.
  ArenaMap arena = ArenaMap.falakOlAflak;

  /// Sideways push on throws in this match, from the map and the seed.
  double get wind => (match?.wind ?? 0) + gust;

  /// The gust blowing now: from level 2, shared by every device.
  double get gust {
    final current = match;
    final gusts = _gusts;
    if (current == null || gusts == null || roundBreak) {
      return 0;
    }
    return gusts.at(elapsedMs: _now - current.startedAt, level: level);
  }

  WindGusts? _gusts;
  int _shownLevel = 1;

  /// Announces each new level for a few seconds.
  final levelBanner = ValueNotifier<String?>(null);
  int _levelBannerUntil = 0;

  /// The map picked in the lobby; null picks one at random per match.
  final selectedArenaId = ValueNotifier<String?>(null);

  /// Rounds end at every knockout: everyone returns to full health at
  /// their spawn after a short break.
  int round = 1;
  int? _roundResumesAt;
  final roundBanner = ValueNotifier<String?>(null);
  bool get roundBreak => _roundResumesAt != null;
  static const _roundBreakMs = 2500;

  int get level {
    final current = match;
    if (current == null) {
      return 1;
    }
    return Difficulty.level(round: round, elapsedMs: _now - current.startedAt);
  }

  ArenaBackground? _background;
  Scarecrow? _scarecrow;
  final _random = Random();
  final _pointer = Vector2(GameConfig.viewWidth / 2, 200);

  /// The aim set by the stick on a phone. It sticks after the thumb lifts,
  /// until the mouse moves, so the arm does not swing back to an old spot.
  double? _stickAim;

  /// The throw is held, by the aiming stick or the mouse button. Held
  /// through a cooldown, the countdown or a round break, it starts charging
  /// the moment a throw is allowed, so an early press is never lost.
  bool _throwHeld = false;
  int _projectileCounter = 0;
  bool _starting = false;
  bool _startCalled = false;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  /// The wall clock, which also slides the ledges back and forth.
  int get nowMs => _now;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    _showArena(arena);
    world.add(AimGuide());
    await _loadFromDatabase();
    net
      ..onPlayerState = _onPlayerState
      ..onLaunch = _onLaunch
      ..onHit = _onHit
      ..onMatchStart = _onMatchStart
      ..onJoinRequest = _onJoinRequest
      ..onMatchSnapshot = _onMatchSnapshot
      ..onKick = _onKick
      ..onSwing = _onSwing
      ..onRosterChanged = _onRosterChanged
      ..onPeerLeft = _onPeerLeft;
    await net.connect(_presence());
    overlays.add(OverlayIds.lobby);
  }

  Future<void> _loadFromDatabase() async {
    final db = backend;
    if (db == null) {
      return;
    }
    try {
      weapons.replaceWith(
        await db.weapons.load().timeout(const Duration(seconds: 5)),
      );
      weaponNotifier.value = weapons.stone;
    } on Exception catch (error) {
      debugPrint('Using built-in weapon tuning: $error');
    }
    try {
      final loaded = await db.profiles.loadOrCreate().timeout(
        const Duration(seconds: 5),
      );
      if (loaded != null) {
        profile.value = loaded;
      }
    } on Exception catch (error) {
      debugPrint('Could not load the profile: $error');
    }
  }

  // Lobby

  LobbyPresence _presence() {
    final me = profile.value;
    return LobbyPresence(
      id: myId,
      name: me.username,
      city: me.homeCity,
      colorIndex: me.colorIndex,
      outfit: me.outfit,
      phase: phase.value.name,
      startedAt: match?.startedAt,
      practising: match?.isPractice ?? false,
      joinedAt: _joinedAt,
      kicked: kicked.value.toList(),
    );
  }

  Future<void> pushPresence() => net.updatePresence(_presence());

  /// Saves the profile and returns an error for the player, or null.
  Future<String?> saveProfile(Profile updated) async {
    final previous = profile.value;
    profile.value = updated;
    final db = backend;
    String? error;
    if (db != null) {
      try {
        error = await db.profiles.save(updated);
      } on Exception {
        error = 'Could not save, check the connection';
      }
    }
    if (error != null) {
      profile.value = previous;
    }
    unawaited(pushPresence());
    return error;
  }

  static final _livePhases = {GamePhase.countdown.name, GamePhase.playing.name};

  /// The match other players in the room are playing, as one of its
  /// players announces it, if any.
  LobbyPresence? get _liveMatchMember {
    for (final member in roster.value) {
      final startedAt = member.startedAt;
      if (member.id != myId &&
          !member.practising &&
          startedAt != null &&
          _livePhases.contains(member.phase) &&
          startedAt + GameConfig.matchSeconds * 1000 > _now) {
        return member;
      }
    }
    return null;
  }

  /// When the match other players in the room are playing ends, if any.
  int? get liveMatchEndsAt {
    final startedAt = _liveMatchMember?.startedAt;
    return startedAt == null
        ? null
        : startedAt + GameConfig.matchSeconds * 1000;
  }

  /// Whether there is still time to drop into the live match.
  bool get canJoinLiveMatch {
    final endsAt = liveMatchEndsAt;
    return endsAt != null && endsAt - _now > _lastJoinMs;
  }

  static const _lastJoinMs = 10000;

  /// Waiting for a player of the live match to let this one in.
  final joining = ValueNotifier<bool>(false);

  /// Asks the players of the live match to let this player drop in. One of
  /// them answers with the match as it stands, scores included.
  void joinLiveMatch() {
    final startedAt = _liveMatchMember?.startedAt;
    if (phase.value != GamePhase.lobby || joining.value || startedAt == null) {
      return;
    }
    joining.value = true;
    net.send(
      NetEvent.joinRequest,
      JoinRequestPayload(id: myId, startedAt: startedAt).toJson(),
    );
    Future<void>.delayed(const Duration(seconds: 5), () {
      joining.value = false;
    });
  }

  void _onJoinRequest(JoinRequestPayload request) {
    if (kicked.value.contains(request.id)) {
      return;
    }
    final current = match;
    final live =
        phase.value == GamePhase.countdown || phase.value == GamePhase.playing;
    if (current == null ||
        !live ||
        current.isPractice ||
        current.startedAt != request.startedAt ||
        current.endsAt - _now < _lastJoinMs ||
        _snapshotResponder(current) != myId) {
      return;
    }
    if (!current.participants.contains(request.id)) {
      current.participants
        ..add(request.id)
        ..sort();
    }
    scoreboard.addPlayer(request.id, _nameOf(request.id));
    standings.value = scoreboard.ranked();
    net.send(
      NetEvent.matchSnapshot,
      MatchSnapshotPayload(
        id: myId,
        hostId: current.hostId,
        matchId: current.matchId,
        seed: current.seed,
        startedAt: current.startedAt,
        participants: current.participants,
        tallies: scoreboard.tallies.toList(),
        arenaId: current.arena.id,
        round: round,
      ).toJson(),
    );
  }

  /// The host answers join requests; if the host has left, the remaining
  /// participant with the lowest id does, so exactly one player answers.
  String _snapshotResponder(MatchState current) {
    final present = <String>{
      myId,
      for (final member in roster.value) member.id,
    };
    if (present.contains(current.hostId)) {
      return current.hostId;
    }
    return current.participants
        .where(present.contains)
        .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
  }

  void _onMatchSnapshot(MatchSnapshotPayload snapshot) {
    if (kicked.value.contains(snapshot.id)) {
      return;
    }
    final current = match;
    if (current != null && current.startedAt == snapshot.startedAt) {
      for (final id in snapshot.participants) {
        if (!current.participants.contains(id)) {
          current.participants.add(id);
          scoreboard.addPlayer(id, _nameOf(id));
        }
      }
      current.participants.sort();
      standings.value = scoreboard.ranked();
      return;
    }
    if (phase.value == GamePhase.lobby &&
        joining.value &&
        snapshot.participants.contains(myId)) {
      _dropIn(snapshot);
    }
  }

  void _dropIn(MatchSnapshotPayload snapshot) {
    joining.value = false;
    _clearArena();
    final next = MatchState(
      hostId: snapshot.hostId,
      matchId: snapshot.matchId,
      seed: snapshot.seed,
      startedAt: snapshot.startedAt,
      participants: List.of(snapshot.participants)..sort(),
      arena: ArenaMap.byId(snapshot.arenaId),
    );
    match = next;
    _startCalled = true;
    _beginMatchWorld(next, round: snapshot.round);
    scoreboard
      ..restore(snapshot.tallies)
      ..addPlayer(myId, profile.value.username);
    standings.value = scoreboard.ranked();
    feed.value = const [];
    saveStatus.value = next.isRecorded ? SaveStatus.none : SaveStatus.unsaved;

    final local = LocalLor(
      playerId: myId,
      playerName: _nameOf(myId),
      color: _colorOf(myId),
      outfit: _outfitOf(myId),
      position: pickRespawnPoint(),
    );
    me = local;
    world.add(local);
    hpNotifier.value = GameConfig.maxHp;
    weaponNotifier.value = weapons.stone;
    final matchId = next.matchId;
    if (next.isRecorded && matchId != null) {
      unawaited(_joinInDatabase(matchId));
    }
    _setPhase(_now < next.startedAt ? GamePhase.countdown : GamePhase.playing);
    unawaited(pushPresence());
  }

  List<String> get _lobbyIds {
    return <String>{
      myId,
      for (final member in roster.value)
        if (member.phase == GamePhase.lobby.name || member.practising)
          member.id,
    }.toList()..sort();
  }

  bool get wouldPractice => _lobbyIds.length < 2;

  Future<void> startMatch() async {
    if (phase.value != GamePhase.lobby || _starting) {
      return;
    }
    _starting = true;
    try {
      final ids = _lobbyIds;
      final seed = _random.nextInt(1 << 31);
      final picked = selectedArenaId.value;
      final chosen = picked == null
          ? ArenaMap.randomFor(seed)
          : ArenaMap.byId(picked);
      String? matchId;
      final db = backend;
      if (ids.length >= 2 && db != null) {
        try {
          matchId = await db.matches
              .createMatch(room: Env.room, arenaId: chosen.id)
              .timeout(const Duration(seconds: 5));
        } on Exception catch (error) {
          debugPrint('Playing this match unrecorded: $error');
        }
      }
      if (phase.value != GamePhase.lobby) {
        return;
      }
      final payload = MatchStartPayload(
        id: myId,
        matchId: matchId,
        seed: seed,
        startedAt: _now + GameConfig.countdownSeconds * 1000,
        participants: ids,
        arenaId: chosen.id,
      );
      if (ids.length >= 2) {
        net.send(NetEvent.matchStart, payload.toJson());
      }
      _applyMatchStart(payload);
    } finally {
      _starting = false;
    }
  }

  void _onMatchStart(MatchStartPayload payload) {
    if (kicked.value.contains(payload.id)) {
      return;
    }
    if (!payload.participants.contains(myId)) {
      return;
    }
    final current = match;
    if (phase.value == GamePhase.lobby || (current?.isPractice ?? false)) {
      // A friend's match takes over from practice straight away.
      _applyMatchStart(payload);
    } else if (phase.value == GamePhase.countdown &&
        current != null &&
        _outranks(payload, current)) {
      _applyMatchStart(payload);
    }
  }

  /// Two players pressing start at once: the earlier match wins everywhere.
  bool _outranks(MatchStartPayload payload, MatchState current) {
    if (payload.startedAt != current.startedAt) {
      return payload.startedAt < current.startedAt;
    }
    return payload.id.compareTo(current.hostId) < 0;
  }

  void _applyMatchStart(MatchStartPayload payload) {
    _clearArena();
    final next = MatchState(
      hostId: payload.id,
      matchId: payload.matchId,
      seed: payload.seed,
      startedAt: payload.startedAt,
      participants: List.of(payload.participants)..sort(),
      arena: ArenaMap.byId(payload.arenaId),
    );
    match = next;
    _startCalled = false;
    _beginMatchWorld(next, round: 1);
    scoreboard.reset({for (final id in next.participants) id: _nameOf(id)});
    standings.value = scoreboard.ranked();
    feed.value = const [];
    saveStatus.value = next.isPractice
        ? SaveStatus.practice
        : next.isRecorded
        ? SaveStatus.none
        : SaveStatus.unsaved;

    for (var i = 0; i < next.participants.length; i++) {
      final id = next.participants[i];
      final spawn = next.arena.spawnFor(i, atMs: _now);
      final side = spawn.x < GameConfig.viewWidth / 2 ? 1 : -1;
      final facingAim = side > 0 ? 0.0 : pi;
      if (id == myId) {
        final local =
            LocalLor(
                playerId: id,
                playerName: _nameOf(id),
                color: _colorOf(id),
                outfit: _outfitOf(id),
                position: spawn,
              )
              ..aim = facingAim
              ..facing = side;
        me = local;
        world.add(local);
      } else {
        final remote =
            RemoteLor(
                playerId: id,
                playerName: _nameOf(id),
                color: _colorOf(id),
                outfit: _outfitOf(id),
                position: spawn,
              )
              ..aim = facingAim
              ..facing = side;
        remotes[id] = remote;
        world.add(remote);
      }
    }
    if (next.isPractice) {
      final scarecrow = Scarecrow(
        position: Vector2(next.arena.scarecrowWalk.$2, ArenaMap.groundTop),
      );
      _scarecrow = scarecrow;
      world.add(scarecrow);
    }
    hpNotifier.value = GameConfig.maxHp;
    weaponNotifier.value = weapons.stone;
    final matchId = next.matchId;
    if (next.isRecorded && next.hostId != myId && matchId != null) {
      unawaited(_joinInDatabase(matchId));
    }
    _setPhase(GamePhase.countdown);
    unawaited(pushPresence());
  }

  /// Shows [map] behind the lobby or the match.
  void _showArena(ArenaMap map, {double wind = 0}) {
    _background?.removeFromParent();
    arena = map;
    final background = ArenaBackground(map, wind: wind);
    _background = background;
    world.add(background);
  }

  /// Picks the map for the next match this player starts; null is random.
  void selectArena(String? id) {
    selectedArenaId.value = id;
    if (phase.value == GamePhase.lobby && id != null) {
      _showArena(ArenaMap.byId(id));
    }
  }

  void _beginMatchWorld(MatchState next, {required int round}) {
    _showArena(next.arena, wind: next.wind);
    this.round = round;
    _roundResumesAt = null;
    roundBanner.value = null;
    _gusts = WindGusts(next.seed);
    _shownLevel = Difficulty.level(
      round: round,
      elapsedMs: _now - next.startedAt,
    );
    levelBanner.value = null;
    _streaks?.removeFromParent();
    final streaks = WindStreaks();
    _streaks = streaks;
    world.add(streaks);
  }

  WindStreaks? _streaks;

  void _announceLevel(int now) {
    final level = this.level;
    if (level > _shownLevel) {
      _shownLevel = level;
      levelBanner.value = Difficulty.announce(level);
      _levelBannerUntil = now + 3500;
    } else if (levelBanner.value != null && now >= _levelBannerUntil) {
      levelBanner.value = null;
    }
  }

  Future<void> _joinInDatabase(String matchId) async {
    try {
      await backend!.matches.join(matchId);
    } on Exception catch (error) {
      debugPrint('Could not join the match in the database: $error');
      saveStatus.value = SaveStatus.unsaved;
    }
  }

  Future<void> _startInDatabase(String matchId) async {
    try {
      await backend!.matches.start(matchId);
    } on Exception catch (error) {
      debugPrint('Could not start the match in the database: $error');
      saveStatus.value = SaveStatus.unsaved;
    }
  }

  // Playing

  @override
  void update(double dt) {
    super.update(dt);
    final current = match;
    if (current == null) {
      return;
    }
    final now = _now;
    if (phase.value == GamePhase.countdown && now >= current.startedAt) {
      _setPhase(GamePhase.playing);
      final matchId = current.matchId;
      if (current.isRecorded &&
          current.hostId == myId &&
          matchId != null &&
          !_startCalled) {
        _startCalled = true;
        unawaited(_startInDatabase(matchId));
      }
    }
    if (phase.value == GamePhase.playing) {
      final stickAim = _stickAim;
      if (stickAim == null) {
        me?.aimAt(_pointer);
      } else {
        me?.aim = stickAim;
      }
      if (_throwHeld) {
        me?.beginCharge();
      }
      if (now >= current.endsAt) {
        _endMatch(current);
        return;
      }
      final resumesAt = _roundResumesAt;
      if (resumesAt != null && now >= resumesAt) {
        _startNextRound(current);
      }
      _announceLevel(now);
    }
  }

  /// Someone was knocked out: the round ends for everyone.
  void _beginRoundBreak() {
    if (roundBreak || phase.value != GamePhase.playing) {
      return;
    }
    _roundResumesAt = _now + _roundBreakMs;
    for (final projectile in projectiles.values.toList()) {
      projectile.removeFromParent();
    }
    me?.charging = false;
    roundBanner.value = 'Round ${round + 1}';
  }

  void _startNextRound(MatchState current) {
    round++;
    _roundResumesAt = null;
    roundBanner.value = null;
    me?.resetForRound(
      current.arena.spawnFor(current.participants.indexOf(myId), atMs: _now),
    );
    for (final remote in remotes.values) {
      remote
        ..hp = GameConfig.maxHp
        ..knockedOut = false;
    }
  }

  void pointerMoved(Offset canvasPosition) {
    _stickAim = null;
    _pointer.setFrom(
      camera.globalToLocal(Vector2(canvasPosition.dx, canvasPosition.dy)),
    );
    me?.aimAt(_pointer);
  }

  /// The aiming stick is pushed towards [angle]: aim there and charge.
  void stickAimed(double angle) {
    _stickAim = angle;
    me?.aim = angle;
    _throwHeld = true;
    if (phase.value == GamePhase.playing) {
      me?.beginCharge();
    }
  }

  /// The aiming stick is let go: throw, or with [cancel] (slid back to the
  /// centre, or the touch was interrupted) lower the arm instead.
  void stickReleased({bool cancel = false}) {
    _throwHeld = false;
    if (cancel) {
      me?.cancelCharge();
    } else {
      me?.release();
    }
  }

  void pointerDown() {
    _throwHeld = true;
    if (phase.value == GamePhase.playing) {
      me?.beginCharge();
    }
  }

  void pointerUp() {
    _throwHeld = false;
    me?.release();
  }

  /// The Chub button on a phone. The right thumb is busy with the aiming
  /// stick, so the swing aims itself at the head of the nearest player in
  /// reach; with nobody in reach it goes the way the player last aimed.
  void touchSwing() {
    final lor = me;
    if (lor == null || !lor.canSwing) {
      return;
    }
    final scarecrow = _scarecrow;
    final aim = BodyGeometry.swingAimAt(lor.position, [
      for (final remote in remotes.values)
        if (!remote.knockedOut) remote.position,
      if (scarecrow != null) scarecrow.position,
    ], reach: Weapon.chubReach);
    if (aim != null) {
      _stickAim = aim;
      lor.aim = aim;
    }
    lor.swing();
  }

  void throwProjectile({
    required Weapon weapon,
    required Vector2 origin,
    required Vector2 velocity,
  }) {
    final projectileId = '$myId-${_projectileCounter++}';
    _spawnProjectile(
      projectileId: projectileId,
      ownerId: myId,
      weapon: weapon,
      origin: origin,
      velocity: velocity,
    );
    net.send(
      NetEvent.launch,
      LaunchPayload(
        id: myId,
        projectileId: projectileId,
        weaponId: weapon.id,
        x: origin.x,
        y: origin.y,
        vx: velocity.x,
        vy: velocity.y,
      ).toJson(),
    );
  }

  void _onLaunch(LaunchPayload payload) {
    if (kicked.value.contains(payload.id)) {
      return;
    }
    final current = match;
    if (current == null ||
        roundBreak ||
        !current.participants.contains(payload.id)) {
      return;
    }
    _spawnProjectile(
      projectileId: payload.projectileId,
      ownerId: payload.id,
      weapon: weapons.byId(payload.weaponId),
      origin: Vector2(payload.x, payload.y),
      velocity: Vector2(payload.vx, payload.vy),
    );
  }

  void _spawnProjectile({
    required String projectileId,
    required String ownerId,
    required Weapon weapon,
    required Vector2 origin,
    required Vector2 velocity,
  }) {
    final projectile = Projectile(
      projectileId: projectileId,
      ownerId: ownerId,
      weapon: weapon,
      position: origin,
      velocity: velocity,
    );
    projectiles[projectileId] = projectile;
    world.add(projectile);
  }

  /// Called by the local player every frame: it alone decides whether a
  /// throw from someone else hit it.
  void checkIncomingHits(LocalLor lor) {
    if (roundBreak) {
      return;
    }
    for (final projectile in projectiles.values.toList()) {
      if (projectile.ownerId == myId || projectile.spent) {
        continue;
      }
      final part = BodyGeometry.hitPart(
        feet: lor.position,
        from: projectile.previous,
        to: projectile.position,
        radius: projectile.radius,
      );
      if (part == null) {
        continue;
      }
      projectile
        ..spent = true
        ..removeFromParent();
      if (lor.protectionLeft > 0) {
        continue;
      }
      _onLocalHit(lor, projectile, part);
    }
  }

  void _onLocalHit(LocalLor lor, Projectile projectile, BodyPart part) {
    _registerHitOnMe(
      lor,
      attackerId: projectile.ownerId,
      weapon: projectile.weapon,
      part: part,
      hitId: projectile.projectileId,
      distance: projectile.position.distanceTo(projectile.origin),
    );
  }

  /// This player was hit, by a throw or a chub: take the damage, tell the
  /// others, and record it.
  void _registerHitOnMe(
    LocalLor lor, {
    required String attackerId,
    required Weapon weapon,
    required BodyPart part,
    required String hitId,
    required double distance,
  }) {
    final points = weapon.pointsFor(part);
    lor.takeHit(weapon, part);
    final knockout = lor.knockedOut;
    net.send(
      NetEvent.hit,
      HitPayload(
        id: myId,
        attackerId: attackerId,
        projectileId: hitId,
        weaponId: weapon.id,
        part: part,
        points: points,
        hp: lor.hp,
        knockout: knockout,
      ).toJson(),
    );
    _applyHit(
      attackerId: attackerId,
      victimId: myId,
      weapon: weapon,
      part: part,
      points: points,
      knockout: knockout,
      at: lor.position,
    );
    if (knockout) {
      _beginRoundBreak();
    }
    final current = match;
    final matchId = current?.matchId;
    if (current != null && current.isRecorded && matchId != null) {
      unawaited(
        backend!.matches
            .recordHit(
              matchId: matchId,
              attackerId: attackerId,
              weaponId: weapon.id,
              part: part,
              distance: distance,
              knockout: knockout,
            )
            .catchError((Object error) {
              debugPrint('Hit not recorded: $error');
            }),
      );
    }
  }

  /// The local player swings the chub: everyone in reach checks for
  /// themselves; the scarecrow is checked here.
  void swingChub(LocalLor lor) {
    final swingId = 'swing-$myId-${_projectileCounter++}';
    net.send(
      NetEvent.swing,
      SwingPayload(
        id: myId,
        swingId: swingId,
        x: lor.position.x,
        y: lor.position.y,
        aim: lor.aim,
      ).toJson(),
    );
    final scarecrow = _scarecrow;
    if (scarecrow == null) {
      return;
    }
    final part = BodyGeometry.swingHit(
      attackerFeet: lor.position,
      aim: lor.aim,
      victimFeet: scarecrow.position,
      reach: Weapon.chubReach,
    );
    if (part != null) {
      scarecrow.wobble();
      _applyHit(
        attackerId: myId,
        victimId: _scarecrowId,
        weapon: weapons.chub,
        part: part,
        points: weapons.chub.pointsFor(part),
        knockout: false,
        at: scarecrow.position,
      );
    }
  }

  void _onSwing(SwingPayload swing) {
    final current = match;
    if (kicked.value.contains(swing.id) ||
        current == null ||
        !current.participants.contains(swing.id)) {
      return;
    }
    remotes[swing.id]?.swingLeft = Weapon.chubSwingSeconds;
    final lor = me;
    if (lor == null ||
        lor.knockedOut ||
        lor.protectionLeft > 0 ||
        roundBreak ||
        phase.value != GamePhase.playing) {
      return;
    }
    final attackerFeet = Vector2(swing.x, swing.y);
    final part = BodyGeometry.swingHit(
      attackerFeet: attackerFeet,
      aim: swing.aim,
      victimFeet: lor.position,
      reach: Weapon.chubReach,
    );
    if (part == null) {
      return;
    }
    lor.knockBack(lor.position.x >= attackerFeet.x ? 1 : -1);
    _registerHitOnMe(
      lor,
      attackerId: swing.id,
      weapon: weapons.chub,
      part: part,
      hitId: swing.swingId,
      distance: (lor.position.x - attackerFeet.x).abs(),
    );
  }

  void checkScarecrowHits(Scarecrow scarecrow) {
    for (final projectile in projectiles.values.toList()) {
      if (projectile.ownerId != myId || projectile.spent) {
        continue;
      }
      final part = BodyGeometry.hitPart(
        feet: scarecrow.position,
        from: projectile.previous,
        to: projectile.position,
        radius: projectile.radius,
      );
      if (part == null) {
        continue;
      }
      projectile
        ..spent = true
        ..removeFromParent();
      scarecrow.wobble();
      _applyHit(
        attackerId: myId,
        victimId: _scarecrowId,
        weapon: projectile.weapon,
        part: part,
        points: projectile.weapon.pointsFor(part),
        knockout: false,
        at: scarecrow.position,
      );
    }
  }

  void _onHit(HitPayload payload) {
    if (kicked.value.contains(payload.id)) {
      return;
    }
    if (match == null) {
      return;
    }
    projectiles[payload.projectileId]
      ?..spent = true
      ..removeFromParent();
    final victim = remotes[payload.id];
    if (victim != null) {
      victim
        ..hp = payload.hp
        ..knockedOut = payload.knockout || victim.knockedOut
        ..flash();
    }
    _applyHit(
      attackerId: payload.attackerId,
      victimId: payload.id,
      weapon: weapons.byId(payload.weaponId),
      part: payload.part,
      points: payload.points,
      knockout: payload.knockout,
      at: victim?.position ?? Vector2(GameConfig.viewWidth / 2, 200),
    );
    if (payload.knockout) {
      _beginRoundBreak();
    }
  }

  void _applyHit({
    required String attackerId,
    required String victimId,
    required Weapon weapon,
    required BodyPart part,
    required int points,
    required bool knockout,
    required Vector2 at,
  }) {
    final head = part == BodyPart.head;
    if (victimId != _scarecrowId) {
      _splashBlood(at, head: head, heavy: weapon.isAjor);
    }
    scoreboard.recordHit(
      attackerId: attackerId,
      victimId: victimId,
      weaponId: weapon.id,
      part: part,
      points: points,
      knockout: knockout,
      atMs: _now,
    );
    standings.value = scoreboard.ranked();

    final label = head
        ? (weapon.isAjor ? 'AJOR HEADSHOT' : 'HEADSHOT')
        : weapon.name.toUpperCase();
    final mine = attackerId == myId;
    world.add(
      FloatingText(
        text: '+$points $label${knockout ? '  KO!' : ''}',
        color: head && weapon.isAjor
            ? const Color(0xFFFFD54F)
            : head
            ? const Color(0xFFFFA726)
            : const Color(0xFFFFFFFF),
        fontSize: mine ? 17 : 13,
        position: at + BodyGeometry.headCenter + Vector2(0, -40),
      ),
    );

    final attacker = _nameOf(attackerId);
    final victim = _nameOf(victimId);
    final how = head ? '${weapon.name} to the head' : weapon.name;
    final entry = FeedEntry(
      text:
          '$attacker hit $victim: $how +$points'
          '${knockout ? ', knocked out' : ''}',
      mine: mine || victimId == myId,
    );
    feed.value = [entry, ...feed.value].take(_feedLength).toList();
  }

  void _splashBlood(Vector2 feet, {required bool head, required bool heavy}) {
    world
      ..add(
        BloodSplash(
          position: feet + (head ? BodyGeometry.headCenter : Vector2(0, -24)),
          heavy: heavy || head,
        ),
      )
      ..add(BloodStain(position: feet.clone(), heavy: heavy));
  }

  /// A spawn point far from the other players, so nobody respawns into a
  /// waiting Ajor.
  Vector2 pickRespawnPoint() {
    final others = [for (final remote in remotes.values) remote.position];
    final candidates = [
      for (var i = 0; i < arena.spawns.length; i++)
        arena.spawnFor(i, atMs: _now),
    ]..shuffle(_random);
    if (others.isEmpty) {
      return candidates.first.clone();
    }
    double clearance(Vector2 point) =>
        others.map((other) => other.distanceTo(point)).reduce(min);
    candidates.sort((a, b) => clearance(b).compareTo(clearance(a)));
    return candidates[_random.nextInt(2)].clone();
  }

  void _onPlayerState(PlayerStatePayload payload) {
    if (kicked.value.contains(payload.id)) {
      return;
    }
    final current = match;
    if (current == null || !current.participants.contains(payload.id)) {
      return;
    }
    final remote = remotes.putIfAbsent(payload.id, () {
      final joined = RemoteLor(
        playerId: payload.id,
        playerName: _nameOf(payload.id),
        color: _colorOf(payload.id),
        outfit: _outfitOf(payload.id),
        position: Vector2(payload.x, payload.y),
      );
      world.add(joined);
      return joined;
    });
    remote.applyState(payload);
  }

  void _onRosterChanged(List<LobbyPresence> members) {
    // The host's list of removed players reaches players who arrive later.
    final host = _hostAmong(members);
    if (host != null && host.kicked.isNotEmpty) {
      kicked.value = {...kicked.value, ...host.kicked};
    }
    if (kicked.value.contains(myId) && host != null && host.id != myId) {
      _beRemoved(host.name);
      return;
    }
    roster.value = [
      for (final member in members)
        if (!kicked.value.contains(member.id)) member,
    ];
  }

  // Room host and removing players

  final _joinedAt = DateTime.now().millisecondsSinceEpoch;

  /// Players the room host removed. Everyone ignores their messages.
  final kicked = ValueNotifier<Set<String>>(<String>{});

  /// Who removed this player from the room, once that has happened.
  final removedBy = ValueNotifier<String?>(null);

  /// The player who has been in the room longest, among those not removed.
  LobbyPresence? _hostAmong(List<LobbyPresence> members) {
    // A window still running a version from before hosts existed reports no
    // join time; it cannot remove anyone, so it never becomes host.
    final candidates =
        [
          for (final member in members)
            if (!kicked.value.contains(member.id) && member.joinedAt > 0)
              member,
        ]..sort((a, b) {
          final byTime = a.joinedAt.compareTo(b.joinedAt);
          return byTime != 0 ? byTime : a.id.compareTo(b.id);
        });
    return candidates.isEmpty ? null : candidates.first;
  }

  String? get roomHostId => _hostAmong(roster.value)?.id;

  bool get isRoomHost => roomHostId == myId;

  /// The room host takes [id] out of the room and out of any match.
  void removePlayer(String id) {
    if (!isRoomHost || id == myId) {
      return;
    }
    kicked.value = {...kicked.value, id};
    net.send(NetEvent.kick, KickPayload(id: myId, targetId: id).toJson());
    _dropRemoved(id);
    unawaited(pushPresence());
  }

  void _onKick(KickPayload payload) {
    if (payload.id != roomHostId) {
      return;
    }
    if (payload.targetId == myId) {
      _beRemoved(_nameOf(payload.id));
      return;
    }
    kicked.value = {...kicked.value, payload.targetId};
    _dropRemoved(payload.targetId);
  }

  void _dropRemoved(String id) {
    remotes.remove(id)?.removeFromParent();
    match?.participants.remove(id);
    roster.value = [
      for (final member in roster.value)
        if (member.id != id) member,
    ];
  }

  /// Leaves the room for good in this tab: the channel closes, so the others
  /// see this player go.
  void _beRemoved(String byName) {
    if (removedBy.value != null) {
      return;
    }
    removedBy.value = byName;
    _clearArena();
    match = null;
    overlays.removeAll(const [
      OverlayIds.lobby,
      OverlayIds.countdown,
      OverlayIds.hud,
      OverlayIds.results,
    ]);
    unawaited(net.dispose());
  }

  void _onPeerLeft(String id) {
    remotes.remove(id)?.removeFromParent();
  }

  // Results

  void _endMatch(MatchState ended) {
    _setPhase(GamePhase.results);
    me?.charging = false;
    standings.value = scoreboard.ranked();
    final matchId = ended.matchId;
    if (ended.isRecorded &&
        matchId != null &&
        saveStatus.value != SaveStatus.unsaved) {
      saveStatus.value = SaveStatus.saving;
      Future<void>.delayed(GameConfig.finishDelay, () => _finish(matchId));
    }
    Future<void>.delayed(
      const Duration(seconds: GameConfig.resultsSeconds),
      () {
        if (match == ended && phase.value == GamePhase.results) {
          backToLobby();
        }
      },
    );
    unawaited(pushPresence());
  }

  Future<void> _finish(String matchId) async {
    try {
      await backend!.matches.finish(matchId);
      saveStatus.value = SaveStatus.saved;
    } on Exception catch (error) {
      debugPrint('Could not save the match: $error');
      saveStatus.value = SaveStatus.failed;
    }
    leaderboardVersion.value++;
  }

  /// Ends practice early and goes back to the lobby.
  void leavePractice() {
    if (!(match?.isPractice ?? false)) {
      return;
    }
    _setPhase(GamePhase.results);
    backToLobby();
  }

  void backToLobby() {
    if (phase.value != GamePhase.results) {
      return;
    }
    _clearArena();
    match = null;
    _showArena(ArenaMap.byId(selectedArenaId.value ?? arena.id));
    _setPhase(GamePhase.lobby);
    leaderboardVersion.value++;
    unawaited(pushPresence());
  }

  // Helpers

  LobbyPresence? _rosterMember(String id) {
    for (final member in roster.value) {
      if (member.id == id) {
        return member;
      }
    }
    return null;
  }

  String _nameOf(String id) {
    if (id == myId) {
      return profile.value.username;
    }
    if (id == _scarecrowId) {
      return 'the scarecrow';
    }
    return _rosterMember(id)?.name ?? scoreboard[id]?.name ?? 'Lor';
  }

  Outfit _outfitOf(String id) => id == myId
      ? profile.value.outfit
      : _rosterMember(id)?.outfit ?? Outfit.kolah;

  Color _colorOf(String id) {
    final index = id == myId
        ? profile.value.colorIndex
        : _rosterMember(id)?.colorIndex ?? 0;
    return GameConfig.playerColors[index % GameConfig.playerColors.length];
  }

  void _clearArena() {
    me?.removeFromParent();
    me = null;
    for (final remote in remotes.values) {
      remote.removeFromParent();
    }
    remotes.clear();
    for (final projectile in projectiles.values.toList()) {
      projectile.removeFromParent();
    }
    projectiles.clear();
    _scarecrow?.removeFromParent();
    _scarecrow = null;
    _streaks?.removeFromParent();
    _streaks = null;
    _gusts = null;
    levelBanner.value = null;
    _roundResumesAt = null;
    roundBanner.value = null;
  }

  void _setPhase(GamePhase next) {
    if (phase.value == next) {
      return;
    }
    phase.value = next;
    overlays
      ..removeAll(const [
        OverlayIds.lobby,
        OverlayIds.countdown,
        OverlayIds.hud,
        OverlayIds.results,
      ])
      ..add(switch (next) {
        GamePhase.lobby => OverlayIds.lobby,
        GamePhase.countdown => OverlayIds.countdown,
        GamePhase.playing => OverlayIds.hud,
        GamePhase.results => OverlayIds.results,
      });
  }
}
