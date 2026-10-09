-- The fourth map: the snowy Oshtorankuh above Gahar Lake, where the wind
-- bends every throw.

insert into public.arenas (id, name, max_players) values
  ('gahar_lake', 'Gahar Lake', 8)
on conflict (id) do nothing;
