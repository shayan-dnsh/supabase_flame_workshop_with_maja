# ManLoram

A side-view multiplayer throwing game set in Lorestan. People there are known
for throwing a stone exactly where they mean to, so the whole game is one
skill: aim, charge, release, and land it on the other player's head. A stone
does the job; an **Ajor** (a brick) to the head is the shot everyone wants.

Built with [Flame](https://flame-engine.org) and Supabase: Realtime Broadcast
and Presence carry the match, Postgres keeps profiles, scoring hits and the
leaderboard.

## User story

> As a player, I want to jump into a quick match with friends and out-throw
> them with stones and Ajor, so that my aim earns me a place on the
> leaderboard.

Acceptance criteria:

- I open the game, get a player name automatically, and can change my name,
  home city, colour and Lor outfit, or start over as a new player.
- I see who is online in my room and can start a match with one button.
- In a match I move, jump, aim with the mouse, hold to charge and release to
  throw. A head hit is worth more than a body hit, and an Ajor headshot is
  worth the most.
- A knockout ends the round: everyone is back to full health at their
  spawn after a short break, and points keep adding up for the whole match.
- Villagers at the sides throw stones and Ajor at everyone, harder every
  round, so I have to keep moving.
- I pick the map, or leave it on Random.
- As the room host (whoever has been in the room longest), I can remove a
  player who spoils the game.
- After two minutes the player with the most points wins, and my totals are
  saved to the leaderboard.
- Alone in the room, I can practise on a scarecrow without anything being
  saved, and a friend who arrives can start a match that pulls me in.
- I can play on a phone held sideways, with on-screen buttons.

## Gameplay

| | |
| --- | --- |
| Outfits | Kolah namadi (felt hat and sash), Chogha (striped Bakhtiari cloak), Golvani (flowered headscarf and coin vest), Kapenak (shepherd's felt cloak); cosmetic only |
| Maps | Falak-ol-Aflak Castle (classic ledges), Khorramabad Bazaar (a tower to lob over), Bisheh Waterfall (cliffs; water slows throws), Gahar Lake (wind bends throws) |
| Rounds | A knockout ends the round; everyone returns to full health at their spawn after 2.5 s |
| Levels | The level rises with every round and every 30 s (`--dart-define=LEVEL_SECONDS=8` to test faster), up to 6. Level 1 is calm; 2: villagers on the left throw stones; 3: the right side joins, with Ajor; 4: wind gusts bend every throw; 5: storm gusts can blow a throw back; then the crowd speeds up. Crowd hits only hurt: no points |
| Move | `A` `D` or arrow keys, jump with `W`, `Space` or arrow up, drop off a ledge with `S` or arrow down. A jump pressed just before landing, or just after walking off a ledge, still counts |
| Aim | Mouse; a short dotted arc shows the start of the throw |
| Throw | Hold the left mouse button to charge, release to throw. A ring at the hand fills with the charge and pulses when full. Held during a cooldown, the throw starts charging as soon as it can |
| Weapon | `1` stone, `2` Ajor, `Q` to switch; up close, `F` or right-click swings the chub (the Lor fighting stick) |
| Phone | Two floating sticks. Left thumb: slide to walk, push up to jump, down to drop off a ledge. Right thumb: push the way to throw, hold for power, lift to throw (slide back to the middle to cancel). Buttons above the right stick swap Stone/Ajor and swing the chub, which aims itself at the head of the nearest player in reach. Turn the phone sideways; the first tap goes fullscreen where the browser allows it (on iPhone, use Add to Home Screen) |
| Health | 100; knocked out at 0; 1.5 s of protection at every spawn |
| Hits | Blood splashes and drips; the hit player limps (a stone to the body a little, an Ajor to the head badly, up to 2.2 s) and sees stars. Low health slows a little too |
| Room host | The player in the room longest. Gets a remove button next to everyone else in the lobby; removed players are ignored by everyone, and only a fresh tab gets back in |
| Match | 2 minutes, most points wins |

| Weapon | Damage body / head | Points body / head | Feel |
| --- | --- | --- | --- |
| Stone | 15 / 30 | 10 / 25 | Fast, flat, short cooldown |
| Ajor | 40 / 80 | 15 / 100 | Slower, loopier arc, long cooldown |
| Chub | 20 / 40 | 20 / 50 | Up close only; swing upwards for the head; knocks back |

Damage, speed, cooldown and points come from the `weapons` table at startup,
so balance changes need no release. The game falls back to the values above
when the table cannot be read.

## How a match flows

1. Everyone in a room shares the Realtime channel `manloram-{room}`. Presence
   is the roster.
2. Start match: the starting player creates a `matches` row, joins it, and
   broadcasts `matchStart` with the match id, a start time 4 s ahead and the
   participants. Every participant inserts its own `match_players` row during
   the countdown.
3. At the start time the host calls `start_match`.
4. Positions and throws travel over Broadcast. The player who gets hit detects
   it, broadcasts `hit`, and calls `record_hit`, so nobody can award
   themselves points.
5. When the clock runs out every participant calls `finish_match`. It is
   idempotent; the first call ranks the players and adds their totals to
   `player_stats`, which feeds the `leaderboard` view.

With only one player in the room the match is practice: no database rows,
and a scarecrow to aim at.

## Run it

From the repository root:

```sh
dart pub get
supabase start
melos run manloram
```

Every browser tab is its own player, so open a second tab to play against
yourself. A reload keeps the player; closing the tab ends it. **New player**
in the lobby starts over as someone else.

### Play with friends on the same network

```sh
melos run manloram:lan
```

It builds the game, serves it to the network, and prints the link to share,
such as `http://192.168.1.20:8799` (or an IPv6 link on IPv6-only networks).
The game finds Supabase on the machine that served it, so friends need nothing
but the link. The lobby shows the link too.

The local stack uses Supabase's well-known development keys, so anyone on the
network can reach its database. Play on a network you trust, and stop
Supabase afterwards.

### Play over the internet

Live at **https://shayan-dnsh.github.io/manloram/**, against the hosted
Supabase project. To publish a new version, push any new migrations, then:

```sh
supabase db push
SUPABASE_URL=https://your-ref.supabase.co SUPABASE_KEY=sb_publishable_... \
  packages/manloram/tool/deploy_online.sh
```

The script builds the game and publishes it to the `shayan-dnsh/manloram`
repository, which holds only the built game and is served by GitHub Pages.

## Tests

```sh
cd packages/manloram
flutter test test/unit                 # physics, hits, scoring; no backend
supabase start && flutter test test/integration   # match flow on the local stack
```
