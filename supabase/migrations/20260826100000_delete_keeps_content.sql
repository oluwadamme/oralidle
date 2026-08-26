-- Narrows what a soft delete destroys.
--
-- 20260826090000 stripped the whole row on delete, which made deletion final:
-- no undo, no trash view, nothing to restore for someone who deleted the wrong
-- session. The scores and transcript are small and worth keeping for exactly
-- that.
--
-- The audio still goes immediately. It is ~1.9 MB a session — the entire
-- storage cost — and the most personal artefact of the three, so there is no
-- reason to hold it once someone has asked for the recording to be gone.
--
-- Net effect: a deleted row is a normal, complete row with `deleted_at` set and
-- no audio. Reads filter on `deleted_at is null` as before.

create or replace function public.blank_deleted_session()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    if old.audio_object_path is not null then
      delete from storage.objects
       where bucket_id = 'recordings'
         and name = old.audio_object_path;
    end if;
    new.audio_object_path := null;
  end if;
  return new;
end;
$$;

-- Interviews carry no audio, so nothing needs doing when one is deleted.
drop trigger if exists on_interview_soft_deleted on public.interviews;
drop function if exists public.blank_deleted_interview();

-- Content is always present again, so the "tombstones may be empty" escape
-- hatch goes and the original NOT NULLs come back.
alter table public.sessions   drop constraint if exists sessions_live_rows_complete;
alter table public.interviews drop constraint if exists interviews_live_rows_complete;

alter table public.sessions
  alter column topic_title      set not null,
  alter column topic_category   set not null,
  alter column duration_seconds set not null,
  alter column result           set not null;

alter table public.interviews
  alter column mode             set not null,
  alter column target_questions set not null,
  alter column turns            set not null,
  alter column evaluation       set not null;
