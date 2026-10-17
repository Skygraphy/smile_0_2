-- "Aus Kontakten" einladen, stage 1 (decided 2026-10-17): which people from
-- the caller's phone book already have Smile, matched by email address.
--
-- The phone sends only SHA-256 hashes (hex) of the lowercased, trimmed
-- addresses -- never the phone book itself -- and gets back only the hits.
-- Nothing is stored. Every Smile account's email is already confirmed by
-- the login, so a hit really is that person (unlike an unconfirmed phone
-- number, which is why phone numbers are stage 2 with an SMS code).
--
-- At most 2000 hashes per call. Computes the hashes of all accounts per
-- call: fine for now; at scale this becomes an indexed hash column.

create or replace function public.match_contact_emails(hashes text[])
returns table (email_hash text, user_id uuid, display_name text, avatar_path text, handle text, manages_a_space boolean)
language sql stable security definer set search_path = public, auth as $$
  with wanted as (
    select distinct lower(h) as h from unnest(hashes[1:2000]) as h where h ~* '^[0-9a-f]{64}$'
  ),
  accounts as (
    select u.id, encode(sha256(convert_to(lower(trim(u.email)), 'UTF8')), 'hex') as h
    from auth.users u
    where u.email is not null and u.id <> auth.uid()
  )
  select a.h, p.user_id, p.display_name, p.avatar_path, p.handle,
         exists (
           select 1 from spaces s where s.owner_id = p.user_id and s.deleted_at is null
           union all
           select 1 from space_co_owners co join spaces s on s.id = co.space_id and s.deleted_at is null
           where co.user_id = p.user_id
         ) as manages_a_space
  from accounts a
  join wanted w on w.h = a.h
  join profiles p on p.user_id = a.id;
$$;

revoke all on function public.match_contact_emails(text[]) from public, anon;
grant execute on function public.match_contact_emails(text[]) to authenticated;
