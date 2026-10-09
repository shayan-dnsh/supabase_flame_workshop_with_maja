-- ManLoram: players, weapons, arenas, matches, scoring hits and career stats.
-- Per-frame state (positions, throws in flight, HP) stays on Realtime
-- Broadcast; only hits that score points are written here.

create type public.match_status as enum ('lobby', 'in_progress', 'finished', 'abandoned');
create type public.body_part as enum ('head', 'body');

-- Profiles: one row per player, editable by its owner.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique check (char_length(username) between 3 and 24),
  home_city text,
  skin text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Profiles are readable by everyone"
  on public.profiles for select
  using (true);

create policy "Players can insert their own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Players can update their own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Player stats: career totals, written only by finish_match().

create table public.player_stats (
  player_id uuid primary key references public.profiles (id) on delete cascade,
  total_score bigint not null default 0,
  wins integer not null default 0,
  matches_played integer not null default 0,
  kills integer not null default 0,
  deaths integer not null default 0,
  headshots integer not null default 0,
  ajor_headshots integer not null default 0,
  best_match_score integer not null default 0,
  updated_at timestamptz not null default now()
);

create index player_stats_total_score_idx on public.player_stats (total_score desc);

alter table public.player_stats enable row level security;

create policy "Player stats are readable by everyone"
  on public.player_stats for select
  using (true);

-- Weapons: static catalog and the single source of truth for points.

create table public.weapons (
  id text primary key,
  name text not null,
  damage real not null check (damage > 0),
  speed real not null check (speed > 0),
  cooldown_ms integer not null check (cooldown_ms >= 0),
  body_points integer not null check (body_points >= 0),
  head_points integer not null check (head_points >= 0)
);

alter table public.weapons enable row level security;

create policy "Weapons are readable by everyone"
  on public.weapons for select
  using (true);

insert into public.weapons (id, name, damage, speed, cooldown_ms, body_points, head_points) values
  ('stone', 'Stone', 15, 420, 250, 10, 25),
  ('ajor', 'Ajor', 40, 300, 1200, 15, 100);

-- Arenas: Lorestan maps.

create table public.arenas (
  id text primary key,
  name text not null,
  max_players integer not null default 8 check (max_players between 2 and 16)
);

alter table public.arenas enable row level security;

create policy "Arenas are readable by everyone"
  on public.arenas for select
  using (true);

insert into public.arenas (id, name, max_players) values
  ('falak_ol_aflak', 'Falak-ol-Aflak Castle', 8),
  ('bisheh_waterfall', 'Bisheh Waterfall', 6),
  ('khorramabad_bazaar', 'Khorramabad Bazaar', 8);

-- Matches: one row per match; its Realtime channel is match:{id}.

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  room_code text not null check (room_code ~ '^[A-Z0-9]{4,8}$'),
  arena_id text not null default 'falak_ol_aflak' references public.arenas (id),
  host_id uuid not null references public.profiles (id) on delete cascade,
  status public.match_status not null default 'lobby',
  winner_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  ended_at timestamptz
);

create unique index matches_active_room_code_idx
  on public.matches (room_code)
  where status in ('lobby', 'in_progress');

alter table public.matches enable row level security;

create policy "Matches are readable by everyone"
  on public.matches for select
  using (true);

create policy "Players can host a new lobby"
  on public.matches for insert
  with check (
    auth.uid() = host_id
    and status = 'lobby'
    and winner_id is null
    and started_at is null
    and ended_at is null
  );

-- Match players: who played and how they finished. Results are written only
-- by finish_match(); players may only join lobbies and mark themselves left.

create table public.match_players (
  match_id uuid not null references public.matches (id) on delete cascade,
  player_id uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  score integer,
  kills integer,
  deaths integer,
  headshots integer,
  ajor_headshots integer,
  placement integer,
  primary key (match_id, player_id)
);

create index match_players_player_id_idx on public.match_players (player_id);

alter table public.match_players enable row level security;

create policy "Match players are readable by everyone"
  on public.match_players for select
  using (true);

create policy "Players can join a lobby"
  on public.match_players for insert
  with check (
    auth.uid() = player_id
    and left_at is null
    and score is null
    and kills is null
    and deaths is null
    and headshots is null
    and ajor_headshots is null
    and placement is null
    and exists (
      select 1 from public.matches m
      where m.id = match_id and m.status = 'lobby'
    )
  );

create policy "Players can mark themselves as left"
  on public.match_players for update
  using (auth.uid() = player_id)
  with check (auth.uid() = player_id);

revoke update on public.match_players from anon, authenticated;
grant update (left_at) on public.match_players to authenticated;

-- Hits: append-only log of scoring hits, written only by record_hit().

create table public.hits (
  id bigint generated always as identity primary key,
  match_id uuid not null references public.matches (id) on delete cascade,
  attacker_id uuid not null references public.profiles (id) on delete cascade,
  victim_id uuid not null references public.profiles (id) on delete cascade,
  weapon_id text not null references public.weapons (id),
  body_part public.body_part not null,
  distance real not null check (distance >= 0),
  points integer not null,
  is_kill boolean not null default false,
  created_at timestamptz not null default now(),
  check (attacker_id <> victim_id)
);

create index hits_match_id_idx on public.hits (match_id);
create index hits_attacker_id_idx on public.hits (attacker_id);

alter table public.hits enable row level security;

create policy "Hits are readable by everyone"
  on public.hits for select
  using (true);

-- Leaderboard: sort by total_score, or by ajor_headshots for the Ajor masters.

create view public.leaderboard with (security_invoker = true) as
select
  s.player_id,
  p.username,
  p.home_city,
  p.skin,
  s.total_score,
  s.wins,
  s.matches_played,
  s.kills,
  s.deaths,
  s.headshots,
  s.ajor_headshots,
  s.best_match_score
from public.player_stats s
join public.profiles p on p.id = s.player_id;

-- record_hit: called by the victim's client, which owns its HP in the
-- netcode, so an attacker can never award themselves points.

create function public.record_hit(
  p_match_id uuid,
  p_attacker_id uuid,
  p_weapon_id text,
  p_body_part public.body_part,
  p_distance real,
  p_is_kill boolean
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_victim_id uuid := auth.uid();
  v_points integer;
  v_hit_id bigint;
begin
  if v_victim_id is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  if p_attacker_id = v_victim_id then
    raise exception 'Players cannot hit themselves' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.matches
    where id = p_match_id and status = 'in_progress'
  ) then
    raise exception 'Match is not in progress' using errcode = '22023';
  end if;

  if (
    select count(*) from public.match_players
    where match_id = p_match_id and player_id in (p_attacker_id, v_victim_id)
  ) <> 2 then
    raise exception 'Both players must be in the match' using errcode = '42501';
  end if;

  if exists (
    select 1 from public.hits
    where match_id = p_match_id
      and attacker_id = p_attacker_id
      and victim_id = v_victim_id
      and created_at > now() - interval '300 milliseconds'
  ) then
    raise exception 'Hits are coming in too fast' using errcode = '22023';
  end if;

  select case p_body_part when 'head' then head_points else body_points end
  into v_points
  from public.weapons
  where id = p_weapon_id;

  if v_points is null then
    raise exception 'Unknown weapon %', p_weapon_id using errcode = '22023';
  end if;

  insert into public.hits (match_id, attacker_id, victim_id, weapon_id, body_part, distance, points, is_kill)
  values (p_match_id, p_attacker_id, v_victim_id, p_weapon_id, p_body_part, p_distance, v_points, p_is_kill)
  returning id into v_hit_id;

  return v_hit_id;
end;
$$;

-- start_match: the host starts a lobby that has at least two players.

create function public.start_match(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.matches m
  set status = 'in_progress', started_at = now()
  where m.id = p_match_id
    and m.host_id = auth.uid()
    and m.status = 'lobby'
    and (select count(*) from public.match_players mp where mp.match_id = m.id) >= 2;

  if not found then
    raise exception 'Only the host can start a lobby with at least 2 players' using errcode = '42501';
  end if;
end;
$$;

-- finish_match: any participant may finish, so a match survives its host
-- leaving. The status claim makes a second call a no-op.

create function public.finish_match(p_match_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_winner_id uuid;
begin
  if not exists (
    select 1 from public.match_players
    where match_id = p_match_id and player_id = auth.uid()
  ) then
    raise exception 'Only players in the match can finish it' using errcode = '42501';
  end if;

  update public.matches
  set status = 'finished', ended_at = now()
  where id = p_match_id and status = 'in_progress';

  if not found then
    return (select winner_id from public.matches where id = p_match_id);
  end if;

  with attacks as (
    select
      attacker_id,
      sum(points)::integer as score,
      (count(*) filter (where is_kill))::integer as kills,
      (count(*) filter (where body_part = 'head'))::integer as headshots,
      (count(*) filter (where body_part = 'head' and weapon_id = 'ajor'))::integer as ajor_headshots,
      max(created_at) as last_hit_at
    from public.hits
    where match_id = p_match_id
    group by attacker_id
  ),
  deaths as (
    select victim_id, (count(*) filter (where is_kill))::integer as deaths
    from public.hits
    where match_id = p_match_id
    group by victim_id
  ),
  ranked as (
    select
      mp.player_id,
      coalesce(a.score, 0) as score,
      coalesce(a.kills, 0) as kills,
      coalesce(d.deaths, 0) as deaths,
      coalesce(a.headshots, 0) as headshots,
      coalesce(a.ajor_headshots, 0) as ajor_headshots,
      row_number() over (
        order by coalesce(a.score, 0) desc, coalesce(d.deaths, 0), a.last_hit_at nulls last
      )::integer as placement
    from public.match_players mp
    left join attacks a on a.attacker_id = mp.player_id
    left join deaths d on d.victim_id = mp.player_id
    where mp.match_id = p_match_id
  ),
  results as (
    update public.match_players mp
    set
      score = r.score,
      kills = r.kills,
      deaths = r.deaths,
      headshots = r.headshots,
      ajor_headshots = r.ajor_headshots,
      placement = r.placement
    from ranked r
    where mp.match_id = p_match_id and mp.player_id = r.player_id
    returning mp.player_id, mp.score, mp.kills, mp.deaths, mp.headshots, mp.ajor_headshots, mp.placement
  )
  insert into public.player_stats as s (
    player_id, total_score, wins, matches_played, kills, deaths,
    headshots, ajor_headshots, best_match_score, updated_at
  )
  select
    player_id, score, (placement = 1 and score > 0)::integer, 1, kills, deaths,
    headshots, ajor_headshots, score, now()
  from results
  on conflict (player_id) do update set
    total_score = s.total_score + excluded.total_score,
    wins = s.wins + excluded.wins,
    matches_played = s.matches_played + 1,
    kills = s.kills + excluded.kills,
    deaths = s.deaths + excluded.deaths,
    headshots = s.headshots + excluded.headshots,
    ajor_headshots = s.ajor_headshots + excluded.ajor_headshots,
    best_match_score = greatest(s.best_match_score, excluded.best_match_score),
    updated_at = now();

  select player_id into v_winner_id
  from public.match_players
  where match_id = p_match_id and placement = 1 and score > 0;

  update public.matches set winner_id = v_winner_id where id = p_match_id;

  return v_winner_id;
end;
$$;

revoke execute on function public.record_hit(uuid, uuid, text, public.body_part, real, boolean) from public, anon;
revoke execute on function public.start_match(uuid) from public, anon;
revoke execute on function public.finish_match(uuid) from public, anon;
grant execute on function public.record_hit(uuid, uuid, text, public.body_part, real, boolean) to authenticated;
grant execute on function public.start_match(uuid) to authenticated;
grant execute on function public.finish_match(uuid) to authenticated;

-- Cleanup: abandon matches with no hit for 10 minutes (stats are not
-- counted) and drop lobbies that never started.

create function public.cleanup_stale_matches()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.matches m
  set status = 'abandoned', ended_at = now()
  where m.status = 'in_progress'
    and greatest(
      m.started_at,
      (select max(h.created_at) from public.hits h where h.match_id = m.id)
    ) < now() - interval '10 minutes';

  delete from public.matches
  where status = 'lobby' and created_at < now() - interval '30 minutes';
$$;

revoke execute on function public.cleanup_stale_matches() from public, anon, authenticated;

create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule(
  'manloram-cleanup-stale-matches',
  '*/5 * * * *',
  'select public.cleanup_stale_matches()'
);
