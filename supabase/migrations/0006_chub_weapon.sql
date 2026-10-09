-- The chub, the Lor fighting stick, swung up close. record_hit takes its
-- points from this row like any other weapon. speed is unused for a swing.

insert into public.weapons (id, name, damage, speed, cooldown_ms, body_points, head_points)
values ('chub', 'Chub', 20, 1, 650, 20, 50)
on conflict (id) do nothing;
