import 'dart:math';

import '../game_config.dart';

/// Decides when a jump leaves the ground. Jumping is how a player dodges a
/// throw, so it forgives being a little early (the press waits for the
/// landing) and a little late (a player who just walked off a ledge can
/// still jump from it).
class JumpWindow {
  double _buffered = 0;
  double _coyote = 0;

  /// The jump key was pressed.
  void press() {
    _buffered = GameConfig.jumpBufferSeconds;
  }

  /// Forgets a waiting press and the ground just left, for a drop through a
  /// ledge or a fresh spawn.
  void cancel() {
    _buffered = 0;
    _coyote = 0;
  }

  /// Advances by [dt] and says whether to jump now. [onGround] is whether
  /// the player stood on something last frame; [held] is a jump kept held,
  /// as with the stick pushed up, which hops again on every landing.
  bool update(double dt, {required bool onGround, required bool held}) {
    _coyote = onGround ? GameConfig.coyoteSeconds : max(0, _coyote - dt);
    final wanted = _buffered > 0 || held;
    _buffered = max(0, _buffered - dt);
    if (!wanted || _coyote <= 0) {
      return false;
    }
    cancel();
    return true;
  }
}
