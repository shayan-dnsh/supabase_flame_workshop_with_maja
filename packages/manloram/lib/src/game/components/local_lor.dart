import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import '../../game_config.dart';
import '../../net/net_events.dart';
import '../../net/payloads/player_state_payload.dart';
import '../arena_map.dart';
import '../../db/supabase_schema.g.dart';
import '../body_geometry.dart';
import '../game_phase.dart';
import '../jump_window.dart';
import '../manloram_game.dart';
import '../throw_physics.dart';
import '../touch_sticks.dart';
import '../weapon.dart';
import 'lor_character.dart';

class LocalLor extends LorCharacter
    with HasGameRef<ManLoramGame>, KeyboardHandler {
  LocalLor({
    required super.playerId,
    required super.playerName,
    required super.color,
    required super.outfit,
    required super.position,
  });

  bool _left = false;
  bool _right = false;

  /// Where the movement stick on a phone is pushed.
  MoveStick _stick = MoveStick.idle;
  final _jumps = JumpWindow();
  bool _onGround = true;
  double _dropTime = 0;

  double heldSeconds = 0;
  double cooldownLeft = 0;
  double cooldownTotal = 1;
  double _protectionLeft = GameConfig.spawnProtectionSeconds;
  double _slowSpeed = 1;
  double _slowLeft = 0;
  double swingCooldownLeft = 0;
  double swingCooldownTotal = 1;
  double _knock = 0;

  double _sinceSync = 0;
  double _sinceSend = 0;
  final _lastSent = Vector2.zero();
  double _lastSentAim = 0;
  int _lastSentFacing = 1;

  @override
  double get protectionLeft => _protectionLeft;

  Weapon get weapon => gameRef.weapons.byId(weaponId);

  double get power => ThrowPhysics.powerFor(heldSeconds);

  Vector2 get hand => BodyGeometry.handPosition(position, aim);

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _left =
        keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA);
    _right =
        keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD);
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.keyW ||
          key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.space) {
        _jumps.press();
      } else if (key == LogicalKeyboardKey.keyS ||
          key == LogicalKeyboardKey.arrowDown) {
        dropDown();
      } else if (key == LogicalKeyboardKey.keyF) {
        swing();
      } else if (key == LogicalKeyboardKey.digit1) {
        selectWeapon(Weapon.stoneId);
      } else if (key == LogicalKeyboardKey.digit2) {
        selectWeapon(Weapon.ajorId);
      } else if (key == LogicalKeyboardKey.keyQ) {
        switchWeapon();
      }
    }
    return true;
  }

  void jump() {
    _jumps.press();
  }

  /// Falls through the ledge underfoot, if standing on one.
  void dropDown() {
    if (gameRef.arena.isOnLedge(position, atMs: gameRef.nowMs)) {
      _dropTime = 0.25;
      _onGround = false;
      _jumps.cancel();
    }
  }

  /// Follows the movement stick. Pushing down drops once per push, not
  /// every frame the thumb stays there.
  set stick(MoveStick value) {
    if (value.drop && !_stick.drop) {
      dropDown();
    }
    _stick = value;
  }

  void switchWeapon() {
    selectWeapon(weaponId == Weapon.stoneId ? Weapon.ajorId : Weapon.stoneId);
  }

  void selectWeapon(String id) {
    weaponId = id;
    gameRef.weaponNotifier.value = weapon;
  }

  void aimAt(Vector2 target) {
    final from = position + BodyGeometry.shoulder;
    aim = atan2(target.y - from.y, target.x - from.x);
  }

  /// Whether a swing would happen now: playing, standing and rested.
  bool get canSwing =>
      !knockedOut &&
      !gameRef.roundBreak &&
      gameRef.phase.value == GamePhase.playing &&
      swingCooldownLeft <= 0;

  /// Swings the chub at whoever stands in front, up close.
  void swing() {
    if (!canSwing) {
      return;
    }
    swingLeft = Weapon.chubSwingSeconds;
    swingCooldownTotal = gameRef.weapons.chub.cooldownSeconds;
    swingCooldownLeft = swingCooldownTotal;
    gameRef.swingChub(this);
  }

  /// A chub hit pushes the player away from the swing.
  void knockBack(int direction) {
    _knock = direction * 360.0;
  }

  void beginCharge() {
    if (knockedOut || gameRef.roundBreak || cooldownLeft > 0 || charging) {
      return;
    }
    charging = true;
    heldSeconds = 0;
  }

  /// Lowers the arm without throwing.
  void cancelCharge() {
    charging = false;
    heldSeconds = 0;
  }

  void release() {
    if (!charging) {
      return;
    }
    charging = false;
    if (knockedOut ||
        gameRef.roundBreak ||
        gameRef.phase.value != GamePhase.playing) {
      return;
    }
    final current = weapon;
    gameRef.throwProjectile(
      weapon: current,
      origin: hand,
      velocity: ThrowPhysics.launchVelocity(aim, power, current.speed),
    );
    cooldownTotal = current.cooldownSeconds;
    cooldownLeft = cooldownTotal;
    heldSeconds = 0;
  }

  void takeHit(Weapon hitBy, BodyPart part) {
    hp = max(0, hp - hitBy.damageFor(part));
    final slow = hitBy.slowFor(part);
    _slowSpeed = _slowLeft > 0 ? min(_slowSpeed, slow.speed) : slow.speed;
    _slowLeft = max(_slowLeft, slow.seconds);
    dazed = true;
    flash();
    gameRef.hpNotifier.value = hp;
    if (hp <= 0) {
      knockedOut = true;
      charging = false;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _rideLedge(dt);
    if (gameRef.phase.value != GamePhase.playing) {
      velocity.setZero();
      _broadcastState(dt);
      return;
    }
    if (knockedOut || gameRef.roundBreak) {
      velocity.setZero();
      charging = false;
      _broadcastState(dt);
      return;
    }
    _protectionLeft = max(0, _protectionLeft - dt);
    _slowLeft = max(0, _slowLeft - dt);
    dazed = _slowLeft > 0;
    cooldownLeft = max(0, cooldownLeft - dt);
    swingCooldownLeft = max(0, swingCooldownLeft - dt);
    if (charging) {
      heldSeconds += dt;
    }
    _move(dt);
    gameRef.checkIncomingHits(this);
    _broadcastState(dt);
  }

  /// Standing on a sliding ledge carries the player along, also during the
  /// countdown and round breaks.
  void _rideLedge(double dt) {
    if (!_onGround || position.y >= ArenaMap.groundTop) {
      return;
    }
    final now = gameRef.nowMs;
    position.x += gameRef.arena.carry(
      position,
      fromMs: now - (dt * 1000).round(),
      toMs: now,
    );
  }

  void _move(double dt) {
    final direction = ((_right ? 1 : 0) - (_left ? 1 : 0) + _stick.direction)
        .clamp(-1, 1)
        .toInt();
    facing = BodyGeometry.facingFor(
      current: facing,
      walking: direction,
      attacking: charging || swingLeft > 0,
      aim: aim,
    );
    // Hurt players limp: slower after a hit, and a little slower the lower
    // their health.
    final limp = 0.8 + 0.2 * hp / GameConfig.maxHp;
    final slowed = _slowLeft > 0 ? _slowSpeed : 1.0;
    velocity.x = direction * GameConfig.moveSpeed * slowed * limp + _knock;
    _knock *= max(0, 1 - 7 * dt);
    if (_jumps.update(dt, onGround: _onGround, held: _stick.jump)) {
      velocity.y = -GameConfig.jumpSpeed * (_slowLeft > 0 ? 0.8 : 1);
      _onGround = false;
    }
    _dropTime = max(0, _dropTime - dt);

    final arena = gameRef.arena;
    final previousX = position.x;
    position.x = (position.x + velocity.x * dt).clamp(
      ArenaMap.minX,
      ArenaMap.maxX,
    );
    arena.pushOutOfBlocks(position, previousX);

    velocity.y += GameConfig.gravity * dt;
    final previousY = position.y;
    position.y += velocity.y * dt;
    if (velocity.y >= 0) {
      final landing = arena.landingY(
        previousY,
        position,
        ignoreLedges: _dropTime > 0,
        atMs: gameRef.nowMs,
      );
      if (landing != null) {
        position.y = landing;
        velocity.y = 0;
        _onGround = true;
        return;
      }
    }
    if (_onGround && !_standing()) {
      _onGround = false;
    }
  }

  bool _standing() => gameRef.arena.isStanding(position, atMs: gameRef.nowMs);

  /// Back to full health at [spawn] for the next round.
  void resetForRound(Vector2 spawn) {
    position.setFrom(spawn);
    facing = spawn.x < GameConfig.viewWidth / 2 ? 1 : -1;
    velocity.setZero();
    hp = GameConfig.maxHp;
    knockedOut = false;
    charging = false;
    dazed = false;
    _slowLeft = 0;
    _knock = 0;
    _onGround = true;
    _jumps.cancel();
    _protectionLeft = GameConfig.spawnProtectionSeconds;
    gameRef.hpNotifier.value = hp;
  }

  void _broadcastState(double dt) {
    _sinceSync += dt;
    _sinceSend += dt;
    if (_sinceSync < GameConfig.stateSyncInterval) {
      return;
    }
    _sinceSync = 0;
    final changed =
        position.distanceTo(_lastSent) > 0.5 ||
        (aim - _lastSentAim).abs() > 0.02 ||
        facing != _lastSentFacing;
    if (!changed && _sinceSend < GameConfig.keepaliveInterval) {
      return;
    }
    _sinceSend = 0;
    _lastSent.setFrom(position);
    _lastSentAim = aim;
    _lastSentFacing = facing;
    gameRef.net.send(
      NetEvent.state,
      PlayerStatePayload(
        id: playerId,
        x: position.x,
        y: position.y,
        vx: velocity.x,
        vy: velocity.y,
        aim: aim,
        facing: facing,
        hp: hp,
        knockedOut: knockedOut,
        charging: charging,
        weaponId: weaponId,
        dazed: dazed,
      ).toJson(),
    );
  }
}
