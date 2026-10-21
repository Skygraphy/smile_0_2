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
  -- Files per bucket and first folder, ids replaced so runs compare:
  -- users/<id> becomes the email, spaces/<id> and channels/<id> the name.
  select coalesce(jsonb_object_agg(k, c order by k), '{}'::jsonb) into files from (
    select o.bucket_id || '/' || coalesce(
             u.email,
             'spaces/' || s.name,
             'channels/' || ch.name,
             split_part(o.name, '/', 1) || '/' || split_part(o.name, '/', 2)) as k,
           count(*) as c
      from storage.objects o
      left join auth.users u on split_part(o.name, '/', 1) = 'users' and u.id::text = split_part(o.name, '/', 2)
      left join public.spaces s on split_part(o.name, '/', 1) = 'spaces' and s.id::text = split_part(o.name, '/', 2)
      left join public.channels ch on split_part(o.name, '/', 1) = 'channels' and ch.id::text = split_part(o.name, '/', 2)
     group by 1) f;
  return jsonb_build_object('rows', counts, 'people', people, 'files', files);
end;
$$;
revoke all on function public.testsuite_state() from public, anon, authenticated;
grant execute on function public.testsuite_state() to service_role;

-- Back to zero in one call (the Dart chapters, integration_test): every row
-- of every public table except app_releases, and every user. Refuses as soon
-- as a user has a real address: then this is not the testsuite project.
create or replace function public.testsuite_reset()
returns void language plpgsql security definer set search_path = public, auth as $$
declare t text;
begin
  if exists (select 1 from auth.users where email not like '%@example.com') then
    raise exception 'Abbruch: echte Benutzer gefunden, das ist nicht das Testprojekt.';
  end if;
  select string_agg(format('public.%I', tablename), ', ') into t
    from pg_tables where schemaname = 'public' and tablename <> 'app_releases';
  execute 'truncate ' || t || ' restart identity cascade';
  delete from auth.users where true;  -- the API demands a WHERE (pg_safeupdate)
end;
$$;
revoke all on function public.testsuite_reset() from public, anon, authenticated;
grant execute on function public.testsuite_reset() to service_role;
