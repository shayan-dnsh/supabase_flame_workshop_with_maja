import 'dart:async';

import 'package:flutter/material.dart';

import '../game/manloram_game.dart';
import 'palette.dart';

class CountdownOverlay extends StatefulWidget {
  const CountdownOverlay({required this.game, super.key});

  final ManLoramGame game;

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.game.match;
    final remainingMs =
        (match?.startedAt ?? 0) - DateTime.now().millisecondsSinceEpoch;
    final seconds = (remainingMs / 1000).ceil().clamp(0, 9);
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              seconds > 0 ? '$seconds' : 'Throw!',
              style: const TextStyle(
                fontSize: 110,
                fontWeight: FontWeight.w900,
                color: Palette.sand,
                shadows: [Shadow(blurRadius: 18, color: Palette.brick)],
              ),
            ),
            Text(
              match?.isPractice ?? false
                  ? 'Practice on the scarecrow'
                  : 'Aim for the head',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Palette.saffron,
                shadows: [Shadow(blurRadius: 8, color: Colors.black)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
