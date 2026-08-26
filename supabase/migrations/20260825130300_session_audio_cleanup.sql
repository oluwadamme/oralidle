-- Deleting a session drops its audio object too, so the client never has to
-- carry a tombstone through the outbox just to clean up storage.

create function public.delete_session_audio()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.audio_object_path is not null then
    delete from storage.objects
     where bucket_id = 'recordings'
       and name = old.audio_object_path;
  end if;
  return old;
end;
$$;

create trigger on_session_deleted
  after delete on public.sessions
  for each row execute function public.delete_session_audio();
