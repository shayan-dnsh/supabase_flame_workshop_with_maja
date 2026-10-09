import 'dart:async';

import 'package:flutter/material.dart';

import '../game/manloram_game.dart';
import '../game/scoreboard.dart';
import '../game/weapon.dart';
import '../game_config.dart';
import 'palette.dart';

class HudOverlay extends StatefulWidget {
  const HudOverlay({required this.game, super.key});

  final ManLoramGame game;

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> {
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
    final game = widget.game;
    final match = game.match;
    final me = game.me;
    final remaining = match?.remainingMs(DateTime.now().millisecondsSinceEpoch);
    final hud = IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<double>(
                    valueListenable: game.hpNotifier,
                    builder: (context, hp, _) => _HealthBar(hp: hp),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<Weapon>(
                    valueListenable: game.weaponNotifier,
                    builder: (context, weapon, _) => Row(
                      children: [
                        _WeaponChip(
                          hotkey: '1',
                          weapon: game.weapons.stone,
                          selected: !weapon.isAjor,
                          cooldown: _cooldownRatio(!weapon.isAjor),
                        ),
                        const SizedBox(width: 6),
                        _WeaponChip(
                          hotkey: '2',
                          weapon: game.weapons.ajor,
                          selected: weapon.isAjor,
                          cooldown: _cooldownRatio(weapon.isAjor),
                        ),
                        const SizedBox(width: 6),
                        _WeaponChip(
                          hotkey: 'F',
                          weapon: game.weapons.chub,
                          selected: false,
                          cooldown: _swingCooldownRatio(),
                        ),
                      ],
                    ),
                  ),
                  if (me != null && me.charging) ...[
                    const SizedBox(height: 8),
                    _PowerBar(power: me.power),
                  ],
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Panel(
                    padding: 8,
                    child: Text(
                      Palette.clock(remaining ?? 0),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: (remaining ?? 0) < 10000
                            ? const Color(0xFFE5533D)
                            : Palette.sand,
                      ),
                    ),
                  ),
                  _Tag(_roundLine()),
                  ValueListenableBuilder<String?>(
                    valueListenable: game.levelBanner,
                    builder: (context, banner, _) => banner == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 54),
                            child: Text(
                              banner,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Palette.saffron,
                                shadows: [
                                  Shadow(blurRadius: 8, color: Colors.black),
                                ],
                              ),
                            ),
                          ),
                  ),
                  ValueListenableBuilder(
                    valueListenable: game.saveStatus,
                    builder: (context, status, _) => switch (status) {
                      SaveStatus.practice => const _Tag('Practice, not saved'),
                      SaveStatus.unsaved => const _Tag(
                        'Offline match, not saved',
                      ),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: ValueListenableBuilder<List<PlayerTally>>(
                valueListenable: game.standings,
                builder: (context, standings, _) =>
                    _Standings(standings: standings, myId: game.myId),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: ValueListenableBuilder<List<FeedEntry>>(
                valueListenable: game.feed,
                builder: (context, feed, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in feed.reversed)
                      Text(
                        entry.text,
                        style: TextStyle(
                          fontSize: 12,
                          color: entry.mine ? Palette.saffron : Palette.sand,
                          shadows: const [
                            Shadow(blurRadius: 3, color: Colors.black),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: game.roundBanner,
              builder: (context, banner, _) => banner == null
                  ? const SizedBox.shrink()
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'KO!',
                            style: TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFE5533D),
                              shadows: [
                                Shadow(blurRadius: 12, color: Colors.black),
                              ],
                            ),
                          ),
                          Text(
                            '$banner: everyone back to full health. '
                            'The crowd gets meaner.',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Palette.sand,
                              shadows: [
                                Shadow(blurRadius: 6, color: Colors.black),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
    if (!(match?.isPractice ?? false)) {
      return hud;
    }
    return Stack(
      children: [
        hud,
        Align(
          alignment: const Alignment(0, -0.45),
          child: OutlinedButton.icon(
            onPressed: game.leavePractice,
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Leave practice'),
          ),
        ),
      ],
    );
  }

  /// Round, crowd level and, on a windy map, the wind.
  String _roundLine() {
    final game = widget.game;
    final wind = game.wind;
    final strength = wind.abs();
    final windText = strength < 1
        ? ''
        : '   Wind ${wind > 0 ? '>>>' : '<<<'} '
              '${strength > 1000
                  ? 'STORM'
                  : strength > 300
                  ? 'strong'
                  : 'light'}';
    return '${game.match?.arena.name ?? ''}   Round ${game.round}   '
        'Level ${game.crowdLevel}$windText';
  }

  double _swingCooldownRatio() {
    final me = widget.game.me;
    if (me == null || me.swingCooldownLeft <= 0) {
      return 0;
    }
    return (me.swingCooldownLeft / me.swingCooldownTotal).clamp(0.0, 1.0);
  }

  double _cooldownRatio(bool forSelected) {
    final me = widget.game.me;
    if (me == null || !forSelected || me.cooldownLeft <= 0) {
      return 0;
    }
    return (me.cooldownLeft / me.cooldownTotal).clamp(0.0, 1.0);
  }
}

class _HealthBar extends StatelessWidget {
  const _HealthBar({required this.hp});

  final double hp;

  @override
  Widget build(BuildContext context) {
    final ratio = (hp / GameConfig.maxHp).clamp(0.0, 1.0);
    return Panel(
      padding: 8,
      child: SizedBox(
        width: 190,
        child: Row(
          children: [
            Text(
              '${hp.ceil()}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 10,
                  backgroundColor: Colors.white12,
                  color: ratio > 0.35
                      ? const Color(0xFF7CC242)
                      : const Color(0xFFE5533D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeaponChip extends StatelessWidget {
  const _WeaponChip({
    required this.hotkey,
    required this.weapon,
    required this.selected,
    required this.cooldown,
  });

  final String hotkey;
  final Weapon weapon;
  final bool selected;
  final double cooldown;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xE6513522) : Palette.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? Palette.saffron : const Color(0x33E6A23C),
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$hotkey ${weapon.name}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            'head ${weapon.headPoints}',
            style: const TextStyle(fontSize: 11, color: Palette.muted),
          ),
          const SizedBox(height: 3),
          LinearProgressIndicator(
            value: 1 - cooldown,
            minHeight: 3,
            backgroundColor: Colors.white12,
            color: weapon.isAjor ? Palette.brick : Palette.sand,
          ),
        ],
      ),
    );
  }
}

class _PowerBar extends StatelessWidget {
  const _PowerBar({required this.power});

  final double power;

  @override
  Widget build(BuildContext context) {
    final ratio = ((power - GameConfig.minPower) / (1 - GameConfig.minPower))
        .clamp(0.0, 1.0);
    return SizedBox(
      width: 190,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: ratio,
          minHeight: 8,
          backgroundColor: Colors.white12,
          color: Color.lerp(Palette.saffron, Palette.brick, ratio),
        ),
      ),
    );
  }
}

class _Standings extends StatelessWidget {
  const _Standings({required this.standings, required this.myId});

  final List<PlayerTally> standings;
  final String myId;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: 10,
      child: SizedBox(
        width: 200,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < standings.length && i < 6; i++)
              Row(
                children: [
                  SizedBox(
                    width: 18,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(color: Palette.muted),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      standings[i].name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: standings[i].id == myId
                            ? FontWeight.w800
                            : FontWeight.w400,
                        color: standings[i].id == myId
                            ? Palette.saffron
                            : Palette.sand,
                      ),
                    ),
                  ),
                  Text(
                    '${standings[i].score}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Palette.sand,
          shadows: [Shadow(blurRadius: 3, color: Colors.black)],
        ),
      ),
    );
  }
}
