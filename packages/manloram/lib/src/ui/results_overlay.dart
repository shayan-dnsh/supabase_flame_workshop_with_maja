import 'package:flutter/material.dart';

import '../game/manloram_game.dart';
import '../game/scoreboard.dart';
import 'palette.dart';

class ResultsOverlay extends StatelessWidget {
  const ResultsOverlay({required this.game, super.key});

  final ManLoramGame game;

  @override
  Widget build(BuildContext context) {
    final standings = game.standings.value;
    final winner = standings.isEmpty || standings.first.score == 0
        ? null
        : standings.first;
    final practice = game.match?.isPractice ?? false;
    final title = practice
        ? 'Practice over: ${standings.isEmpty ? 0 : standings.first.score} points'
        : winner == null
        ? 'Nobody scored. A draw.'
        : winner.id == game.myId
        ? 'You win! The best arm in Lorestan.'
        : '${winner.name} wins!';
    return ColoredBox(
      color: const Color(0x991E140D),
      child: Center(
        child: SizedBox(
          width: 560,
          child: Panel(
            padding: 22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Palette.saffron,
                  ),
                ),
                const SizedBox(height: 16),
                _ResultsTable(standings: standings, myId: game.myId),
                const SizedBox(height: 16),
                ValueListenableBuilder<SaveStatus>(
                  valueListenable: game.saveStatus,
                  builder: (context, status, _) => Text(switch (status) {
                    SaveStatus.saving => 'Saving to the leaderboard...',
                    SaveStatus.saved => 'Saved to the leaderboard.',
                    SaveStatus.failed => 'Could not save this match.',
                    SaveStatus.practice => 'Practice is not saved.',
                    SaveStatus.unsaved => 'This match was not recorded.',
                    SaveStatus.none => '',
                  }, style: const TextStyle(color: Palette.muted)),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: game.backToLobby,
                  child: const Text('Back to the lobby'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultsTable extends StatelessWidget {
  const _ResultsTable({required this.standings, required this.myId});

  final List<PlayerTally> standings;
  final String myId;

  @override
  Widget build(BuildContext context) {
    const header = TextStyle(color: Palette.muted, fontSize: 12);
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(28),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(64),
        3: FixedColumnWidth(64),
        4: FixedColumnWidth(54),
        5: FixedColumnWidth(44),
      },
      children: [
        const TableRow(
          children: [
            Text('', style: header),
            Text('Player', style: header),
            Text('Points', style: header),
            Text('Heads', style: header),
            Text('Ajor', style: header),
            Text('KOs', style: header),
          ],
        ),
        for (var i = 0; i < standings.length; i++)
          TableRow(
            children: [
              Text('${i + 1}'),
              Text(
                standings[i].id == myId
                    ? '${standings[i].name} (you)'
                    : standings[i].name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: standings[i].id == myId
                      ? FontWeight.w800
                      : FontWeight.w400,
                ),
              ),
              Text(
                '${standings[i].score}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text('${standings[i].headshots}'),
              Text('${standings[i].ajorHeadshots}'),
              Text('${standings[i].knockouts}'),
            ],
          ),
      ],
    );
  }
}
