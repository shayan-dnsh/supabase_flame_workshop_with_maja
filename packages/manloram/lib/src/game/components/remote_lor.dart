import 'dart:math';

import 'package:flame/extensions.dart';

import '../../game_config.dart';
import '../../net/payloads/player_state_payload.dart';
import 'lor_character.dart';

class RemoteLor extends LorCharacter {
  RemoteLor({
    required super.playerId,
    required super.playerName,
    required super.color,
    required super.outfit,
    required Vector2 position,
  }) : _target = position.clone(),
       super(position: position);

  final Vector2 _target;

  void applyState(PlayerStatePayload state) {
    _target.setValues(state.x, state.y);
    velocity.setValues(state.vx, state.vy);
    aim = state.aim;
    hp = state.hp;
    knockedOut = state.knockedOut;
    charging = state.charging;
    weaponId = state.weaponId;
    dazed = state.dazed;
    if (position.distanceTo(_target) > GameConfig.remoteTeleportDistance) {
      position.setFrom(_target);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (knockedOut) {
      position.setFrom(_target);
      return;
    }
    final step = Vector2(velocity.x * dt, 0);
    _target.add(step);
    position.add(step);
    final factor = min(1.0, dt * GameConfig.remoteLerpFactorPerSecond);
    position.add((_target - position)..scale(factor));
  }
}
