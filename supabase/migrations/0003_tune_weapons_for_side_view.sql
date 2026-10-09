-- ManLoram is a side-view game with gravity: speed is the launch speed of a
-- fully charged throw in pixels per second, and cooldowns leave room for the
-- charge. Points stay as they were.

update public.weapons set speed = 1100, cooldown_ms = 450 where id = 'stone';
update public.weapons set speed = 950, cooldown_ms = 1400 where id = 'ajor';
