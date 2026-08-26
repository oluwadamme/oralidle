-- Soft delete, so a deletion made on one device reaches the others.
--
-- Pull only ever added rows, which meant deleting a recording on your phone
-- left it on your laptop — and the laptop's next sync pushed it back up. A
-- tombstone the other devices can see is the only way to close that loop;
-- reconciling id sets cannot tell "deleted elsewhere" from "not pushed yet"
-- and guesses wrong in one direction or the other.
--
-- The row survives, its *contents* do not. `blank_deleted_row` strips the
-- transcript, scores and audio the moment `deleted_at` is set, leaving an id
-- and a timestamp. A delete that quietly retained someone's speech transcript
-- indefinitely would be worse than not offering one.

alter table public.sessions   add column deleted_at timestamptz;
alter table public.interviews add column deleted_at timestamptz;

create index sessions_user_deleted_idx
  on public.sessions (user_id, deleted_at);
create index interviews_user_deleted_idx
  on public.interviews (user_id, deleted_at);

-- Content becomes optional, because a tombstone has none.
alter table public.sessions
  alter column topic_title      drop not null,
  alter column topic_category   drop not null,
  alter column duration_seconds drop not null,
  alter column result           drop not null;

alter table public.interviews
  alter column mode             drop not null,
  alter column target_questions drop not null,
  alter column turns            drop not null,
  alter column evaluation       drop not null;

-- A live row still has to be complete; only tombstones may be empty.
alter table public.sessions add constraint sessions_live_rows_complete check (
  deleted_at is not null
  or (topic_title is not null and topic_category is not null
      and duration_seconds is not null and result is not null)
);

alter table public.interviews add constraint interviews_live_rows_complete check (
  deleted_at is not null
  or (mode is not null and target_questions is not null
      and turns is not null and evaluation is not null)
);

create function public.blank_deleted_session()
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
    new.topic_title := null;
    new.topic_category := null;
    new.duration_seconds := null;
    new.result := null;
    new.audio_object_path := null;
  end if;
  return new;
end;
$$;

create trigger on_session_soft_deleted
  before update of deleted_at on public.sessions
  for each row execute function public.blank_deleted_session();

create function public.blank_deleted_interview()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    new.mode := null;
    new.target_questions := null;
    new.turns := null;
    new.evaluation := null;
  end if;
  return new;
end;
$$;

create trigger on_interview_soft_deleted
  before update of deleted_at on public.interviews
  for each row execute function public.blank_deleted_interview();

-- Analytics counts live rows only; a tombstone has nothing left to count.
create or replace view analytics.v_users as
select
  p.id,
  p.display_name,
  u.email,
  u.is_anonymous,
  u.email_confirmed_at is not null as email_verified,
  p.created_at,
  u.last_sign_in_at,
  (select count(*) from public.sessions s
    where s.user_id = p.id and s.deleted_at is null)   as sessions,
  (select count(*) from public.interviews i
    where i.user_id = p.id and i.deleted_at is null)   as interviews,
  greatest(
    (select max(s.recorded_at) from public.sessions s
      where s.user_id = p.id and s.deleted_at is null),
    (select max(i.recorded_at) from public.interviews i
      where i.user_id = p.id and i.deleted_at is null)
  ) as last_activity_at
from public.profiles p
join auth.users u on u.id = p.id;

create or replace view analytics.v_topic_popularity as
select
  topic_category,
  topic_title,
  count(*)                                             as sessions,
  count(distinct user_id)                              as users,
  round(avg((result ->> 'overall_score')::numeric), 1) as avg_score,
  round(avg(duration_seconds)::numeric, 0)             as avg_duration_seconds,
  max(recorded_at)                                     as last_practised_at
from public.sessions
where deleted_at is null
group by topic_category, topic_title
order by sessions desc;

create or replace view analytics.v_interview_modes as
select
  mode,
  count(*)                                                 as completed,
  count(distinct user_id)                                  as users,
  round(avg((evaluation ->> 'overall_score')::numeric), 1) as avg_score,
  round(avg(target_questions)::numeric, 1)                 as avg_questions,
  round(avg(jsonb_array_length(turns))::numeric, 1)        as avg_turns_answered
from public.interviews
where deleted_at is null
group by mode
order by completed desc;
