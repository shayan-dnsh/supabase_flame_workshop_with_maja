import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/game_phase.dart';
import '../game/manloram_game.dart';
import '../game/touch_sticks.dart';
import '../game/weapon.dart';
import '../game_config.dart';
import 'palette.dart';

/// On-screen controls for phones: two floating sticks, the layout most
/// phone shooters use. The left thumb lands anywhere on the left half to
/// walk, jump and drop; the right thumb lands anywhere on the right half,
/// pushes the way it wants to throw, holds for power and lifts to throw.
///
/// They cover the whole screen in real pixels, not the 960 x 540 arena, so
/// they stay thumb-sized on a small phone and can use the bars beside the
/// arena on a long one. The top band is left free for the HUD.
class TouchControls extends StatefulWidget {
  const TouchControls({required this.game, super.key});

  final ManLoramGame game;

  @override
  State<TouchControls> createState() => _TouchControlsState();
}

class _TouchControlsState extends State<TouchControls> {
  /// Share of the screen height above the sticks, where the health bar,
  /// standings and the Leave practice button are.
  static const _hudBand = 0.38;

  /// Whether the aiming thumb is outside the dead zone, so lifting throws.
  bool _aiming = false;

  ManLoramGame get game => widget.game;

  void _aimMoved(double x, double y) {
    final angle = AimStick.angle(x, y);
    if (angle != null) {
      _aiming = true;
      game.stickAimed(angle);
    } else if (_aiming) {
      _aiming = false;
      game.stickReleased(cancel: true);
    }
  }

  void _aimReleased({required bool cancelled}) {
    if (_aiming) {
      game.stickReleased(cancel: cancelled);
    }
    _aiming = false;
  }

  StickGauge _aimGauge() {
    final me = game.me;
    if (me == null) {
      return const (charge: 0, cooldown: 0);
    }
    return (
      charge: me.charging
          ? (me.heldSeconds / GameConfig.chargeSeconds).clamp(0.0, 1.0)
          : 0.0,
      cooldown: me.cooldownLeft > 0
          ? (me.cooldownLeft / me.cooldownTotal).clamp(0.0, 1.0)
          : 0.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GamePhase>(
      valueListenable: game.phase,
      builder: (context, phase, _) {
        if (phase != GamePhase.countdown && phase != GamePhase.playing) {
          return const SizedBox.shrink();
        }
        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final top = constraints.maxHeight * _hudBand;
              final half = constraints.maxWidth / 2;
              return Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: top,
                    bottom: 0,
                    width: half,
                    child: _Stick(
                      label: 'Move  ·  up to jump',
                      homeOnRight: false,
                      onMoved: (x, y) => game.me?.stick = MoveStick.at(x, y),
                      onReleased: ({required cancelled}) =>
                          game.me?.stick = MoveStick.idle,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: top,
                    bottom: 0,
                    width: half,
                    child: _Stick(
                      label: 'Aim  ·  hold  ·  lift to throw',
                      homeOnRight: true,
                      onMoved: _aimMoved,
                      onReleased: _aimReleased,
                      gauge: _aimGauge,
                    ),
                  ),
                  // Above the aiming half, so a press never aims or throws.
                  Positioned(
                    right: 12,
                    top: top,
                    child: Row(
                      children: [
                        ValueListenableBuilder<Weapon>(
                          valueListenable: game.weaponNotifier,
                          builder: (context, weapon, _) => _TapButton(
                            label: weapon.isAjor ? 'Ajor' : 'Stone',
                            icon: Icons.swap_horiz_rounded,
                            color: weapon.isAjor ? Palette.brick : null,
                            onTap: () => game.me?.switchWeapon(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _TapButton(
                          label: 'Chub',
                          icon: Icons.sports_hockey_rounded,
                          onTap: () => game.me?.swing(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// How full the throw's charge and cooldown are, from 0 to 1.
typedef StickGauge = ({double charge, double cooldown});

/// A floating stick: it centres wherever the thumb lands in its area, and a
/// faint copy rests in the bottom corner to show where it is. [onMoved]
/// gets the thumb's position from -1 to 1 across the stick.
class _Stick extends StatefulWidget {
  const _Stick({
    required this.label,
    required this.homeOnRight,
    required this.onMoved,
    required this.onReleased,
    this.gauge,
  });

  final String label;
  final bool homeOnRight;
  final void Function(double x, double y) onMoved;
  final void Function({required bool cancelled}) onReleased;
  final StickGauge Function()? gauge;

  @override
  State<_Stick> createState() => _StickState();
}

class _StickState extends State<_Stick> with SingleTickerProviderStateMixin {
  static const _radius = GameConfig.stickRadius;

  /// Redraws the gauge while the stick is held.
  late final Ticker _ticker = createTicker((_) => setState(() {}));

  /// Only the first finger in the area drives the stick.
  int? _pointer;
  Offset? _base;
  Offset _knob = Offset.zero;

  void _down(PointerDownEvent event) {
    if (_pointer != null) {
      return;
    }
    setState(() {
      _pointer = event.pointer;
      _base = event.localPosition;
      _knob = Offset.zero;
    });
    widget.onMoved(0, 0);
    if (widget.gauge != null) {
      _ticker.start();
    }
  }

  void _move(PointerMoveEvent event) {
    final base = _base;
    if (event.pointer != _pointer || base == null) {
      return;
    }
    var delta = event.localPosition - base;
    var newBase = base;
    // A thumb that slides past the rim drags the stick along, so it never
    // has to find the centre again to turn around.
    if (delta.distance > _radius) {
      newBase = event.localPosition - delta / delta.distance * _radius;
      delta = event.localPosition - newBase;
    }
    setState(() {
      _base = newBase;
      _knob = delta / _radius;
    });
    widget.onMoved(_knob.dx, _knob.dy);
  }

  void _up(PointerEvent event, {required bool cancelled}) {
    if (event.pointer != _pointer) {
      return;
    }
    _ticker.stop();
    setState(() {
      _pointer = null;
      _base = null;
      _knob = Offset.zero;
    });
    widget.onReleased(cancelled: cancelled);
  }

  @override
  void dispose() {
    if (_pointer != null) {
      widget.onReleased(cancelled: true);
    }
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final home = Offset(
          widget.homeOnRight
              ? constraints.maxWidth - _radius - 28
              : _radius + 28,
          constraints.maxHeight - _radius - 22,
        );
        final base = _base;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: (event) => _up(event, cancelled: false),
          onPointerCancel: (event) => _up(event, cancelled: true),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _StickPainter(
                    center: base ?? home,
                    knob: _knob,
                    active: base != null,
                    gauge: base == null ? null : widget.gauge?.call(),
                  ),
                ),
              ),
              if (base == null)
                Positioned(
                  left: home.dx - 110,
                  width: 220,
                  top: home.dy + _radius + 2,
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Palette.sand.withValues(alpha: 0.7),
                      shadows: const [Shadow(blurRadius: 3)],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StickPainter extends CustomPainter {
  _StickPainter({
    required this.center,
    required this.knob,
    required this.active,
    required this.gauge,
  });

  final Offset center;
  final Offset knob;
  final bool active;
  final StickGauge? gauge;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = GameConfig.stickRadius;
    canvas
      ..drawCircle(
        center,
        radius,
        Paint()..color = Palette.night.withValues(alpha: active ? 0.45 : 0.25),
      )
      ..drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Palette.saffron.withValues(alpha: active ? 0.9 : 0.4),
      )
      ..drawCircle(
        center + knob * radius,
        radius * 0.42,
        Paint()..color = Palette.sand.withValues(alpha: active ? 0.85 : 0.35),
      );
    final current = gauge;
    if (current == null) {
      return;
    }
    final ring = Rect.fromCircle(center: center, radius: radius + 7);
    if (current.cooldown > 0) {
      canvas.drawArc(
        ring,
        -pi / 2,
        2 * pi * current.cooldown,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = Palette.muted.withValues(alpha: 0.8),
      );
    } else if (current.charge > 0) {
      canvas.drawArc(
        ring,
        -pi / 2,
        2 * pi * current.charge,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = Palette.saffron,
      );
    }
  }

  @override
  bool shouldRepaint(_StickPainter old) => true;
}

class _TapButton extends StatefulWidget {
  const _TapButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  static const size = 58.0;

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  State<_TapButton> createState() => _TapButtonState();
}

class _TapButtonState extends State<_TapButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        setState(() => _pressed = true);
        widget.onTap();
      },
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: _Disc(
        size: _TapButton.size,
        pressed: _pressed,
        color: widget.color,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: _TapButton.size * 0.4),
            Text(
              widget.label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({
    required this.size,
    required this.pressed,
    required this.child,
    this.color,
  });

  final double size;
  final bool pressed;
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (color ?? Palette.night).withValues(alpha: pressed ? 0.85 : 0.5),
        border: Border.all(
          color: Palette.saffron.withValues(alpha: pressed ? 1 : 0.6),
          width: 2,
        ),
      ),
      child: IconTheme(
        data: const IconThemeData(color: Palette.sand),
        child: DefaultTextStyle(
          style: const TextStyle(color: Palette.sand),
          child: Center(child: child),
        ),
      ),
    );
  }
}
