-- Null-Zustand of the TESTSUITE project: every row of every public table
-- (except app_releases, which is configuration) and every user. Storage
-- files are removed separately by reset_storage.ts (the storage API is the
-- only allowed way).
do $$
declare t text;
begin
  -- Second guard besides env.sh: test users only ever have @example.com
  -- addresses. A real address means this is not the testsuite project.
  if exists (select 1 from auth.users where email not like '%@example.com') then
    raise exception 'Abbruch: echte Benutzer gefunden, das ist nicht das Testprojekt.';
  end if;
  select string_agg(format('public.%I', tablename), ', ')
    into t
    from pg_tables
   where schemaname = 'public' and tablename <> 'app_releases';
  execute 'truncate ' || t || ' restart identity cascade';
end $$;
delete from auth.users;
