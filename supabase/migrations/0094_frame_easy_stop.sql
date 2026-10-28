-- "Easy Stopping" (Ernst 2026-10-28): a tap anywhere on the Frame stops the
-- picture and says so, the next tap goes on as before -- on every control
-- level, also "Nur zuschauen". After 10 minutes it goes on by itself.
alter table frames add column if not exists easy_stop boolean not null default true;
