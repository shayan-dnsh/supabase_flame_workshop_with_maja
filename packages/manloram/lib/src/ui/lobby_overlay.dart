import 'dart:async';

import 'package:flutter/material.dart';

import '../db/profile_service.dart';
import '../db/stats_service.dart';
import '../db/supabase_schema.g.dart';
import '../game/arena_map.dart';
import '../game/lor_painter.dart';
import '../game/manloram_game.dart';
import '../game/outfit.dart';
import '../env.dart';
import '../game_config.dart';
import '../net/payloads/lobby_presence.dart';
import 'palette.dart';

class LobbyOverlay extends StatefulWidget {
  const LobbyOverlay({
    required this.game,
    this.onNewPlayer,
    this.phone = false,
    super.key,
  });

  final ManLoramGame game;

  /// Played on a touch screen: the instructions open on the phone tab.
  final bool phone;

  /// Starts over as a brand new player; null while a switch is under way.
  final Future<void> Function()? onNewPlayer;

  @override
  State<LobbyOverlay> createState() => _LobbyOverlayState();
}

class _LobbyOverlayState extends State<LobbyOverlay> {
  late final TextEditingController _name;
  late String _shownName;
  Timer? _clock;
  String? _saveMessage;
  bool _saving = false;

  ManLoramGame get game => widget.game;

  @override
  void initState() {
    super.initState();
    _shownName = game.profile.value.username;
    _name = TextEditingController(text: _shownName);
    game.profile.addListener(_syncName);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  /// Follows the saved name unless the player is in the middle of typing a
  /// new one.
  void _syncName() {
    final saved = game.profile.value.username;
    if (_name.text == _shownName) {
      _name.text = saved;
    }
    _shownName = saved;
    setState(() {});
  }

  @override
  void dispose() {
    game.profile.removeListener(_syncName);
    _clock?.cancel();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save(Profile updated) async {
    setState(() {
      _saving = true;
      _saveMessage = null;
    });
    final error = await game.saveProfile(updated);
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      _saveMessage = error ?? 'Saved';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x991E140D),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 11, child: _playerColumn(context)),
            const SizedBox(width: 20),
            Expanded(flex: 9, child: _roomColumn()),
          ],
        ),
      ),
    );
  }

  Widget _playerColumn(BuildContext context) {
    final profile = game.profile.value;
    final liveEndsAt = game.liveMatchEndsAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ManLoram',
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: Palette.saffron,
            letterSpacing: 1,
          ),
        ),
        const Text(
          'Throw true. Aim for the head. An Ajor to the head is worth 100.',
          style: TextStyle(color: Palette.muted),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _name,
                      // The lobby is scaled down on a phone, so the name is
                      // typed in a dialog at the real screen size.
                      readOnly: widget.phone,
                      onTap: widget.phone ? _editNameInDialog : null,
                      maxLength: 24,
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        counterText: '',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (value) =>
                          _save(profile.copyWith(username: value.trim())),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: profile.homeCity,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final city in GameConfig.homeCities)
                        DropdownMenuItem(value: city, child: Text(city)),
                    ],
                    onChanged: (city) =>
                        _save(profile.copyWith(homeCity: city)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final outfit in Outfit.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _OutfitTile(
                        outfit: outfit,
                        color:
                            GameConfig.playerColors[profile.colorIndex %
                                GameConfig.playerColors.length],
                        selected: outfit == profile.outfit,
                        onTap: () => _save(profile.copyWith(outfit: outfit)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < GameConfig.playerColors.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Swatch(
                        color: GameConfig.playerColors[i],
                        selected: i == profile.colorIndex,
                        onTap: () => _save(profile.copyWith(colorIndex: i)),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => _save(
                            profile.copyWith(username: _name.text.trim()),
                          ),
                    child: const Text('Save'),
                  ),
                  TextButton.icon(
                    onPressed: widget.onNewPlayer,
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('New player'),
                  ),
                ],
              ),
              if (_saveMessage != null)
                Text(
                  _saveMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _saveMessage == 'Saved'
                        ? const Color(0xFF7CC242)
                        : const Color(0xFFE5533D),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<List<LobbyPresence>>(
          valueListenable: game.roster,
          builder: (context, _, _) => ValueListenableBuilder<bool>(
            valueListenable: game.joining,
            builder: (context, joining, _) => _startRow(liveEndsAt, joining),
          ),
        ),
        const Spacer(),
        _Controls(phoneFirst: widget.phone),
      ],
    );
  }

  /// Name editing on a phone, readable above the keyboard.
  Future<void> _editNameInDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(initial: _name.text),
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || !mounted) {
      return;
    }
    _name.text = trimmed;
    await _save(game.profile.value.copyWith(username: trimmed));
  }

  Future<void> _confirmRemove(LobbyPresence member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${member.name}?'),
        content: const Text(
          'They leave the room and any match they are in, and everyone here '
          'ignores them from now on. Their leaderboard entry stays.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE5533D),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      game.removePlayer(member.id);
    }
  }

  /// Start a match, practise alone, or drop into the match already on.
  Widget _startRow(int? liveEndsAt, bool joining) {
    final practice = game.wouldPractice;
    final now = DateTime.now().millisecondsSinceEpoch;
    final VoidCallback? onPressed;
    final IconData icon;
    final String label;
    final String hint;
    if (liveEndsAt != null) {
      final canJoin = game.canJoinLiveMatch && !joining;
      onPressed = canJoin ? game.joinLiveMatch : null;
      icon = Icons.login_rounded;
      label = joining ? 'Joining...' : 'Join match';
      hint = game.canJoinLiveMatch
          ? 'A match is on, ${Palette.clock(liveEndsAt - now)} left. '
                'Jump in, the score so far stays.'
          : 'The match is about to end. Start the next one in a moment.';
    } else {
      onPressed = game.startMatch;
      icon = practice ? Icons.adjust : Icons.sports_kabaddi;
      label = practice ? 'Practice' : 'Start match';
      hint = practice
          ? 'Alone in the room: warm up on the scarecrow. Nothing is saved.'
          : 'Everyone in the lobby joins. Two minutes, most points wins.';
    }
    return Row(
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            hint,
            style: const TextStyle(color: Palette.muted, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _roomColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          child: ValueListenableBuilder<List<LobbyPresence>>(
            valueListenable: game.roster,
            builder: (context, roster, _) {
              final hostId = game.roomHostId;
              final members = List.of(roster)
                ..sort((a, b) => a.name.compareTo(b.name));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Heading('In this room'),
                  _ConnectionWarning(game: game),
                  if (_inviteLink case final link?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: SelectableText(
                        'Invite friends: $link',
                        style: const TextStyle(
                          color: Palette.saffron,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  for (final member in members.take(6))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 16,
                            color:
                                GameConfig.playerColors[member.colorIndex %
                                    GameConfig.playerColors.length],
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              member.id == game.myId
                                  ? '${member.name} (you)'
                                  : member.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (member.id == hostId)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Text(
                                'host',
                                style: TextStyle(
                                  color: Palette.saffron,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          Text(
                            member.phase == 'lobby'
                                ? member.city
                                : 'in a match',
                            style: const TextStyle(
                              color: Palette.muted,
                              fontSize: 12,
                            ),
                          ),
                          if (game.isRoomHost && member.id != game.myId)
                            SizedBox(
                              width: 26,
                              height: 22,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 16,
                                tooltip: 'Remove from the room',
                                color: const Color(0xFFE5533D),
                                icon: const Icon(Icons.person_remove_rounded),
                                onPressed: () => _confirmRemove(member),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _MapPicker(game: game),
        const SizedBox(height: 10),
        Expanded(child: _LeaderboardPanel(game: game)),
      ],
    );
  }
}

/// The page's own address when it was opened through the network, so
/// friends can open the same link. Null on localhost, which only works on
/// this machine.
String? get _inviteLink {
  final host = Uri.base.host;
  if (!Uri.base.scheme.startsWith('http') ||
      host.isEmpty ||
      host == 'localhost' ||
      host == '127.0.0.1') {
    return null;
  }
  // The full address, path included, so a hosted copy under a folder such
  // as /manloram/ shares a link that works.
  return Uri.base
      .replace(query: '', fragment: '')
      .toString()
      .replaceAll(RegExp(r'[?#]+$'), '');
}

/// Says so when this device cannot reach the game server, typically a
/// friend's phone that is blocked from the host's Supabase.
class _ConnectionWarning extends StatelessWidget {
  const _ConnectionWarning({required this.game});

  final ManLoramGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: game.net.connected,
      builder: (context, connected, _) {
        final settling =
            DateTime.now().difference(game.createdAt) <
            const Duration(seconds: 5);
        if (game.backend != null && (connected || settling)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Cannot reach the game server at ${Env.supabaseUrl}. Other '
            'players will not see you. Check that the host is running '
            'Supabase and that this device is on the same network.',
            style: const TextStyle(color: Color(0xFFE5533D), fontSize: 12),
          ),
        );
      },
    );
  }
}

/// The map for the next match this player starts, or Random.
class _MapPicker extends StatelessWidget {
  const _MapPicker({required this.game});

  final ManLoramGame game;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: 12,
      child: ValueListenableBuilder<String?>(
        valueListenable: game.selectedArenaId,
        builder: (context, selected, _) {
          final picked = selected == null ? null : ArenaMap.byId(selected);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Heading('Map'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _mapChip(
                    'Random',
                    selected == null,
                    () => game.selectArena(null),
                  ),
                  for (final map in ArenaMap.all)
                    _mapChip(
                      map.name,
                      selected == map.id,
                      () => game.selectArena(map.id),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                picked?.twist ?? 'A different map every match.',
                style: const TextStyle(color: Palette.muted, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _mapChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onTap(),
    );
  }
}

class _LeaderboardPanel extends StatefulWidget {
  const _LeaderboardPanel({required this.game});

  final ManLoramGame game;

  @override
  State<_LeaderboardPanel> createState() => _LeaderboardPanelState();
}

class _LeaderboardPanelState extends State<_LeaderboardPanel> {
  var _sort = LeaderboardSort.points;
  Future<List<LeaderboardRow>>? _rows;

  @override
  void initState() {
    super.initState();
    widget.game.leaderboardVersion.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    widget.game.leaderboardVersion.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    final backend = widget.game.backend;
    setState(() {
      _rows = backend?.stats.top(sort: _sort);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Heading('Leaderboard'),
              const Spacer(),
              SegmentedButton<LeaderboardSort>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(
                    value: LeaderboardSort.points,
                    label: Text('Points'),
                  ),
                  ButtonSegment(
                    value: LeaderboardSort.ajorHeadshots,
                    label: Text('Ajor masters'),
                  ),
                ],
                selected: {_sort},
                onSelectionChanged: (selection) {
                  _sort = selection.first;
                  _reload();
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: FutureBuilder<List<LeaderboardRow>>(
              future: _rows,
              builder: (context, snapshot) {
                if (_rows == null) {
                  return const _Note(
                    'Offline: the leaderboard needs a '
                    'connection.',
                  );
                }
                if (snapshot.hasError) {
                  return const _Note('Could not load the leaderboard.');
                }
                final rows = snapshot.data;
                if (rows == null) {
                  return const _Note('Loading...');
                }
                if (rows.isEmpty) {
                  return const _Note('No matches played yet. Be the first.');
                }
                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (var i = 0; i < rows.length; i++)
                      _LeaderboardRowView(
                        rank: i + 1,
                        row: rows[i],
                        sort: _sort,
                        isMe: rows[i].playerId == widget.game.myId,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRowView extends StatelessWidget {
  const _LeaderboardRowView({
    required this.rank,
    required this.row,
    required this.sort,
    required this.isMe,
  });

  final int rank;
  final LeaderboardRow row;
  final LeaderboardSort sort;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final value = sort == LeaderboardSort.points
        ? '${row.totalScore ?? 0} pts'
        : '${row.ajorHeadshots ?? 0} Ajor';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: TextStyle(
                color: rank == 1 ? Palette.saffron : Palette.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${row.username ?? 'Lor'}'
              '${row.homeCity == null ? '' : ', ${row.homeCity}'}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isMe ? FontWeight.w700 : FontWeight.w400,
                color: isMe ? Palette.saffron : Palette.sand,
              ),
            ),
          ),
          Text(
            '${row.wins ?? 0} wins  ',
            style: const TextStyle(color: Palette.muted, fontSize: 12),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Types the player's name at the real screen size, so it stays readable
/// above a phone keyboard. Pops with the new name, or null on cancel.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scrollable: sideways, the keyboard leaves only a strip of screen.
    return AlertDialog(
      scrollable: true,
      content: TextField(
        controller: _field,
        autofocus: true,
        maxLength: 24,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Your name',
          counterText: '',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _field.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// How to play, for a laptop or a phone; opens on the one in use.
class _Controls extends StatefulWidget {
  const _Controls({required this.phoneFirst});

  final bool phoneFirst;

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  late bool _phone = widget.phoneFirst;

  static const _crowd =
      'Each level adds more: villagers left, then right, then wind and storms.';

  static const _laptop = [
    'Move with A and D, jump with W or Space, drop off a ledge with S.',
    'Aim with the mouse. Hold the button to charge, let go to throw.',
    '1 Stone  2 Ajor (100 for a headshot)  Q switch.  Up close: F or '
        'right-click swings the chub.',
  ];

  static const _mobile = [
    'Left thumb anywhere on the left: slide to walk, up to jump, down to '
        'drop off a ledge.',
    'Right thumb anywhere on the right: push the way to throw, hold for '
        'power, lift to throw. Slide back to the middle to cancel.',
    'Stone/Ajor swaps weapons; Chub swings at whoever is closest.',
  ];

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Palette.muted, fontSize: 12.5);
    return Panel(
      padding: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Heading('How to play'),
              const Spacer(),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.laptop_rounded, size: 16),
                    label: Text('Laptop'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.smartphone_rounded, size: 16),
                    label: Text('Phone'),
                  ),
                ],
                selected: {_phone},
                onSelectionChanged: (selection) =>
                    setState(() => _phone = selection.first),
              ),
            ],
          ),
          for (final line in _phone ? _mobile : _laptop)
            Text(line, style: style),
          const Text(_crowd, style: style),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: Palette.saffron,
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: Palette.muted));
  }
}

class _OutfitTile extends StatelessWidget {
  const _OutfitTile({
    required this.outfit,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Outfit outfit;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: outfit.description,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 92,
          padding: const EdgeInsets.only(top: 4, bottom: 3),
          decoration: BoxDecoration(
            color: selected ? const Color(0x33E6A23C) : const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? Palette.saffron : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                width: 40,
                height: 58,
                child: CustomPaint(
                  painter: _OutfitPreview(outfit: outfit, color: color),
                ),
              ),
              Text(
                outfit.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? Palette.saffron : Palette.sand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutfitPreview extends CustomPainter {
  const _OutfitPreview({required this.outfit, required this.color});

  final Outfit outfit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const scale = 0.82;
    canvas
      ..translate(size.width / 2, size.height)
      ..scale(scale);
    LorPainter.paint(canvas, outfit: outfit, color: color, aim: -0.5);
  }

  @override
  bool shouldRepaint(_OutfitPreview old) =>
      old.outfit != outfit || old.color != color;
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Palette.sand : Colors.transparent,
            width: 2.5,
          ),
        ),
      ),
    );
  }
}
