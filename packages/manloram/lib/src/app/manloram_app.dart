import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/backend.dart';
import '../db/profile_service.dart';
import '../game/game_phase.dart';
import '../game/manloram_game.dart';
import '../game_config.dart';
import '../net/net_service.dart';
import '../ui/countdown_overlay.dart';
import '../ui/hud_overlay.dart';
import '../ui/lobby_overlay.dart';
import '../ui/palette.dart';
import '../ui/results_overlay.dart';
import '../ui/touch_controls.dart';
import 'fullscreen.dart';
import 'overlay_ids.dart';
import 'session.dart';

class ManLoramApp extends StatefulWidget {
  const ManLoramApp({super.key});

  @override
  State<ManLoramApp> createState() => _ManLoramAppState();
}

class _ManLoramAppState extends State<ManLoramApp> {
  late ManLoramGame game;
  final _focusNode = FocusNode();

  static final _isPhone =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// On-screen controls: on from the start on phones and tablets, and as
  /// soon as anyone touches the screen elsewhere.
  final _touchMode = ValueNotifier<bool>(_isPhone);
  bool _switching = false;

  /// Asked once, at the first tap, and again at each new match in case the
  /// player left fullscreen in between.
  bool _fullscreenAsked = false;

  @override
  void initState() {
    super.initState();
    game = _createGame();
  }

  ManLoramGame _createGame() {
    final client = Supabase.instance.client;
    final random = Random();
    final userId = client.auth.currentUser?.id;
    final myId =
        userId ??
        [for (var i = 0; i < 16; i++) random.nextInt(16).toRadixString(16)]
            .join();
    final created = ManLoramGame(
      net: NetService(myId: myId),
      myId: myId,
      backend: userId == null ? null : Backend(client),
      profile: Profile(
        id: myId,
        username: 'Lor-${1000 + random.nextInt(9000)}',
        homeCity: GameConfig.homeCities.first,
        colorIndex: random.nextInt(GameConfig.playerColors.length),
      ),
    )..phase.addListener(_focusGameWhenPlaying);
    return created;
  }

  /// Leaves the room as the current player and comes back as a new one.
  Future<void> _newPlayer() async {
    if (_switching) {
      return;
    }
    setState(() => _switching = true);
    final previous = game;
    previous.phase.removeListener(_focusGameWhenPlaying);
    await previous.net.dispose();
    await switchToNewPlayer();
    if (!mounted) {
      return;
    }
    setState(() {
      game = _createGame();
      _switching = false;
    });
  }

  void _focusGameWhenPlaying() {
    if (game.phase.value != GamePhase.lobby) {
      _focusNode.requestFocus();
    }
    if (game.phase.value == GamePhase.countdown) {
      _fullscreenAsked = false;
    }
  }

  /// Browsers allow fullscreen only from a tap, and count a touch as a tap
  /// when the finger lifts, not when it lands.
  void _maybeFullscreen(PointerUpEvent event) {
    if (!_isPhone ||
        _fullscreenAsked ||
        event.kind != PointerDeviceKind.touch) {
      return;
    }
    _fullscreenAsked = true;
    unawaited(enterFullscreen());
  }

  @override
  void dispose() {
    game.phase.removeListener(_focusGameWhenPlaying);
    _focusNode.dispose();
    _touchMode.dispose();
    super.dispose();
  }

  /// Overlays are laid out at the game's 960 x 540 and scaled with it, so
  /// the interface lines up with the arena at any window size.
  static Widget _scaled(Widget overlay) {
    return SizedBox.expand(
      child: FittedBox(
        child: SizedBox(
          width: GameConfig.viewWidth,
          height: GameConfig.viewHeight,
          child: overlay,
        ),
      ),
    );
  }

  /// Mouse button that aims and throws. Touches are left to the on-screen
  /// sticks: aiming at the spot under a finger hides the target.
  int? _aimPointer;

  void _onArenaDown(PointerDownEvent event) {
    if (_aimPointer != null || event.kind == PointerDeviceKind.touch) {
      return;
    }
    if (event.buttons & kSecondaryButton != 0) {
      game.me?.swing();
      return;
    }
    if (event.buttons & kPrimaryButton == 0) {
      return;
    }
    _aimPointer = event.pointer;
    game
      ..pointerMoved(event.localPosition)
      ..pointerDown();
  }

  void _onArenaMove(PointerEvent event) {
    if (event is PointerHoverEvent || event.pointer == _aimPointer) {
      game.pointerMoved(event.localPosition);
    }
  }

  void _onArenaUp(PointerEvent event) {
    if (event.pointer != _aimPointer) {
      return;
    }
    _aimPointer = null;
    game.pointerUp();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.touch) {
          _touchMode.value = true;
        }
      },
      onPointerUp: _maybeFullscreen,
      child: MaterialApp(
        title: 'ManLoram',
        debugShowCheckedModeBanner: false,
        theme: Palette.theme,
        home: Scaffold(
          backgroundColor: Palette.night,
          body: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Center(child: _arena()),
                // Over the whole screen, not just the arena, so the sticks
                // keep their size and can use the bars beside the arena.
                ListenableBuilder(
                  listenable: Listenable.merge([_touchMode, game.removedBy]),
                  builder: (context, _) =>
                      _touchMode.value && game.removedBy.value == null
                      ? TouchControls(key: ObjectKey(game), game: game)
                      : const SizedBox.shrink(),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _touchMode,
                  builder: (context, touch, _) =>
                      touch && constraints.maxHeight > constraints.maxWidth
                      ? const _TurnSideways()
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _arena() {
    return AspectRatio(
      aspectRatio: GameConfig.viewWidth / GameConfig.viewHeight,
      child: Stack(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.precise,
            child: Listener(
              onPointerHover: _onArenaMove,
              onPointerMove: _onArenaMove,
              onPointerDown: _onArenaDown,
              onPointerUp: _onArenaUp,
              onPointerCancel: _onArenaUp,
              child: GameWidget<ManLoramGame>(
                key: ObjectKey(game),
                game: game,
                focusNode: _focusNode,
                overlayBuilderMap: {
                  OverlayIds.lobby: (context, game) => _scaled(
                    LobbyOverlay(
                      game: game,
                      onNewPlayer: _switching ? null : _newPlayer,
                      phone: _touchMode.value,
                    ),
                  ),
                  OverlayIds.countdown: (context, game) =>
                      _scaled(CountdownOverlay(game: game)),
                  OverlayIds.hud: (context, game) =>
                      _scaled(HudOverlay(game: game)),
                  OverlayIds.results: (context, game) =>
                      _scaled(ResultsOverlay(game: game)),
                },
              ),
            ),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: game.removedBy,
            builder: (context, by, _) =>
                by == null ? const SizedBox.shrink() : _Removed(by: by),
          ),
        ],
      ),
    );
  }
}

class _Removed extends StatelessWidget {
  const _Removed({required this.by});

  final String by;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xF21E140D),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_off_rounded,
                size: 56,
                color: Palette.saffron,
              ),
              const SizedBox(height: 16),
              Text(
                '$by, the room host, removed you from this room.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, color: Palette.sand),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TurnSideways extends StatelessWidget {
  const _TurnSideways();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xF21E140D),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.screen_rotation_rounded,
                size: 64,
                color: Palette.saffron,
              ),
              SizedBox(height: 16),
              Text(
                'Turn your phone sideways to play ManLoram.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Palette.sand),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
