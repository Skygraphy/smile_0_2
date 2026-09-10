-- Auto-join: the Space Owner who creates a channel becomes its
-- channel_admin immediately. Originally scoped as Phase 6 work, but
-- implemented now because Phase 3's upload flow is broken without it -- a
-- Space Owner could see a channel they just created (via is_space_owner)
-- but couldn't post into it (media_items_insert requires an actual
-- channel_memberships row). Mirrors on_space_created's NULL-guard (0012)
-- for the same reason: inserts done via service-role Edge Functions have
-- no auth.uid() and must not crash or misattribute membership.
create or replace function handle_new_channel()
returns trigger
language plpgsql
security definer
as $$
begin
  if auth.uid() is not null then
    insert into channel_memberships (channel_id, user_id, role)
    values (new.id, auth.uid(), 'channel_admin')
    on conflict (channel_id, user_id) do nothing;
  end if;
  return new;
end;
$$;

create trigger on_channel_created
  after insert on channels
  for each row execute function handle_new_channel();
