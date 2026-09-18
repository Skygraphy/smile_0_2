create or replace function debug_channels_policies()
returns table(polname text, polcmd text, qual text, withcheck text)
language sql security definer stable as $$
  select polname::text, polcmd::text,
    pg_get_expr(polqual, polrelid), pg_get_expr(polwithcheck, polrelid)
  from pg_policy where polrelid = 'channels'::regclass;
$$;
