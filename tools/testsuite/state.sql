-- The state of the TESTSUITE project in one call, after every recorded step
-- (chapter.sh): the context a confirmation belongs to. Only in the
-- testsuite project (not a migration), callable by the service role only.
--   npx supabase db query --linked --project-ref ohcrvjvhglrxxrkyrnhr -f state.sql
create or replace function public.testsuite_state()
returns jsonb language plpgsql security definer set search_path = public, storage, auth as $$
declare
  t record;
  n bigint;
  counts jsonb := '{}'::jsonb;
  people jsonb;
  files jsonb;
begin
  -- How many rows each table holds (logs left out: they grow by themselves).
  for t in select tablename from pg_tables
           where schemaname = 'public' and tablename not in ('internal_calls', 'health_alerts', 'app_releases')
           order by tablename loop
    execute format('select count(*) from public.%I', t.tablename) into n;
    counts := counts || jsonb_build_object(t.tablename, n);
  end loop;
  -- Each test person by email: what the app shows of them.
  select coalesce(jsonb_object_agg(u.email, jsonb_build_object(
           'name', p.display_name,
           'smileName', p.handle,
           'picture', p.avatar_path is not null)
         order by u.email), '{}'::jsonb)
    into people
    from auth.users u left join public.profiles p on p.user_id = u.id;
  -- Files per bucket and first folder (users/<id> becomes users/<email>).
  select coalesce(jsonb_object_agg(k, c order by k), '{}'::jsonb) into files from (
    select o.bucket_id || '/' || coalesce(u.email, split_part(o.name, '/', 1) || '/' || split_part(o.name, '/', 2)) as k,
           count(*) as c
      from storage.objects o
      left join auth.users u on split_part(o.name, '/', 1) = 'users' and u.id::text = split_part(o.name, '/', 2)
     group by 1) f;
  return jsonb_build_object('rows', counts, 'people', people, 'files', files);
end;
$$;
revoke all on function public.testsuite_state() from public, anon, authenticated;
grant execute on function public.testsuite_state() to service_role;
