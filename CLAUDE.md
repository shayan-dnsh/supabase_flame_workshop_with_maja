# CLAUDE.md

Workshop monorepo: real-time multiplayer 2D games on **Flutter + Flame**, with
**Supabase** (Realtime Broadcast/Presence, Postgres, anonymous auth) as the
only backend. There is no game server. `README.md` explains the netcode; each
package has its own README.

## Packages

| Package | What it is | Touch it when |
| --- | --- | --- |
| `packages/manloram` | Side-view Lorestan stone/Ajor throwing game, live at https://shayan-dnsh.github.io/manloram/ | Most active work happens here |
| `packages/game` | Finished workshop space game (reference solution) | Only when the task says so |
| `packages/skeleton` | Exercise starting point: plumbing only, no game | Only when the task says so |
| `packages/slides` | `flutter_deck` workshop deck | Only when the task says so |

Keep changes scoped to the package the task is about. The workshop packages
(`game`, `skeleton`, `slides`) are presented material: don't refactor them as
a side effect of ManLoram work.

## Commands

Pub workspace (`resolution: workspace`) with Melos scripts in the root
`pubspec.yaml`. Run `dart pub get` from the root, never per package.

```sh
dart pub get
supabase start                      # local stack, API on port 54621
melos run manloram                  # or: game, skeleton, slides (Chrome)
melos run manloram:lan              # serve to phones/friends on the LAN
melos run analyze                   # flutter analyze .
melos run format                    # dart format --set-exit-if-changed .

cd packages/manloram
flutter test test/unit              # pure logic, no backend
flutter test test/integration       # needs `supabase start`
```

Before calling work done, run what CI runs (`.github/workflows/ci.yaml`):
`dart format --set-exit-if-changed .`, `flutter analyze` on all four
packages, and `flutter build web` for any package you changed.

## Stack and versions

- Flutter >= 3.47, Dart ^3.13, `flame: ^2.0.0-dev.1` (2.x dev API: check the
  installed source in `.dart_tool`/pub cache before assuming 1.x APIs).
- `supabase_flutter: ^3.0.0-dev.9` with typed table access
  (`client.table(Matches.table).insert(MatchesInsert(...))`). The typed API is
  experimental: files using it start with
  `// ignore_for_file: experimental_member_use`.
- Everything resolves from pub.dev. No git dependencies, no
  `dependency_overrides`.
- Lints: `flutter_lints` via the root `analysis_options.yaml`.

## Code conventions

- Layout per game package: `lib/src/{app,db,game,net,ui}` plus `env.dart` and
  `game_config.dart`. Flame components live in `game/components/`, Flutter
  overlays in `ui/`, Realtime payloads in `net/payloads/` (one class per
  file), database services in `db/`.
- Network payloads are hand-written immutable classes with `fromJson`/`toJson`
  and short wire keys. No `json_serializable` or `build_runner`.
- Every tuning constant goes in `game_config.dart`; configuration comes from
  `--dart-define` via `env.dart` (`SUPABASE_URL`, `SUPABASE_KEY`, `ROOM`,
  `LEVEL_SECONDS`). Defaults target the local stack.
- Doc comments explain *why* and the gameplay meaning, in plain English. Match
  the existing comment density.
- **Latin script only** in all identifiers, SQL, seed data, docs and UI text.
  Transliterate Lorestan names (`khorramabad`, `falak_ol_aflak`, `Ajor`); no
  Farsi/Arabic script, no `name_fa` columns.
- Keep pure logic (physics, scoring, difficulty) in plain Dart classes so
  `test/unit` can cover it without Flame or a backend.

## Netcode and trust model (ManLoram)

- One Realtime channel per room, `manloram-{room}`; Presence is the roster and
  the room host is whoever has been present longest.
- Peer-authoritative: each client simulates itself. **The victim detects a hit,
  broadcasts `hit`, and calls `record_hit`**, so nobody awards themselves
  points. Keep this model.
- Every write that touches points goes through security-definer RPCs
  (`start_match`, `record_hit`, `finish_match`, which is idempotent). Never
  add direct client writes to scoring tables.
- Weapon balance is read from the `weapons` table at startup with in-code
  fallbacks, so tuning ships as a migration, not a release.
- A lone player gets practice mode: no database rows at all.

## Database workflow

- Migrations are numbered `supabase/migrations/NNNN_description.sql`. Add a new
  file; never edit one that has been pushed (0001 to 0006 are on the hosted
  project).
- After a schema change, update `supabase/schema.json` and regenerate the
  typed models in each package that uses the tables (never hand-edit
  `supabase_schema.g.dart`):

  ```sh
  cd packages/manloram
  supabase gen types --lang dart --local > lib/src/db/supabase_schema.g.dart
  ```

  See the root README for the snapshot-based alternative.
- RLS on every table; anonymous auth is the identity.

## Deploying (ask first)

These touch shared or public systems. Confirm with the user before running:

- `supabase db push` (hosted project)
- `packages/manloram/tool/deploy_online.sh` (publishes to GitHub Pages via the
  `shayan-dnsh/manloram` repo; git push uses HTTPS through
  `gh auth git-credential`)

## Slides

Slide code snippets are string copies of game source, labelled with their true
path. If you change code in `packages/game` that a slide quotes, update the
snippet too (search the slides for the path).

## Agent skills

Project skills live in `.claude/skills/` (managed by `npx skills`, pinned in
`skills-lock.json`; update with `npx skills update -p`):

| Area | Skills |
| --- | --- |
| Flame | `flutter-flame-games` |
| Flutter | `flutter-apply-architecture-best-practices`, `flutter-build-responsive-layout`, `flutter-fix-layout-issues`, `flutter-add-widget-test`, `flutter-add-integration-test` |
| Dart | `dart-add-unit-test`, `dart-run-static-analysis`, `dart-use-pattern-matching`, `dart-resolve-package-conflicts` |
| Supabase | `supabase`, `supabase-postgres-best-practices` |

Where a skill's generic advice conflicts with this file (for example, it
suggests `json_serializable`, MVVM layers, sprite assets or a game server), this
file wins: follow the existing code.
