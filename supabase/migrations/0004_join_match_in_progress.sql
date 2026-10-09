-- Friends may drop into a match that is already running, not only join from
-- the lobby, so their hits count and their totals reach the leaderboard.

drop policy "Players can join a lobby" on public.match_players;

create policy "Players can join a lobby or a running match"
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
      where m.id = match_id and m.status in ('lobby', 'in_progress')
    )
  );
