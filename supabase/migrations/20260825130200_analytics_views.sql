-- Read-side for product analytics.
--
-- These live in `analytics` rather than `public` on purpose: PostgREST exposes
-- only `public` and `graphql_public`, so nothing here is reachable with the
-- anon key. Query them from the SQL editor, where you run as `postgres` and
-- RLS does not apply.

create schema if not exists analytics;

revoke all on schema analytics from anon, authenticated;

-- Which topics get practised, and how people do on them.
create view analytics.v_topic_popularity as
select
  topic_category,
  topic_title,
  count(*)                                          as sessions,
  count(distinct user_id)                           as users,
  round(avg((result ->> 'overall_score')::numeric), 1) as avg_score,
  round(avg(duration_seconds)::numeric, 0)          as avg_duration_seconds,
  max(recorded_at)                                  as last_practised_at
from public.sessions
group by topic_category, topic_title
order by sessions desc;

-- Topics opened versus topics actually completed. A topic with a wide gap is
-- one people are drawn to but bounce off — the interesting signal.
create view analytics.v_topic_funnel as
with selected as (
  select props ->> 'topic_id' as topic_id,
         props ->> 'category'  as category,
         count(*)              as opened
  from public.events
  where name = 'topic_selected'
  group by 1, 2
),
completed as (
  select props ->> 'topic_id' as topic_id,
         count(*)              as completed
  from public.events
  where name = 'recording_completed'
  group by 1
)
select
  s.topic_id,
  s.category,
  s.opened,
  coalesce(c.completed, 0) as completed,
  round(100.0 * coalesce(c.completed, 0) / nullif(s.opened, 0), 1) as completion_pct
from selected s
left join completed c using (topic_id)
order by s.opened desc;

-- Interview mode mix and drop-off.
create view analytics.v_interview_modes as
select
  mode,
  count(*)                                             as completed,
  count(distinct user_id)                              as users,
  round(avg((evaluation ->> 'overall_score')::numeric), 1) as avg_score,
  round(avg(target_questions)::numeric, 1)             as avg_questions,
  round(avg(jsonb_array_length(turns))::numeric, 1)    as avg_turns_answered
from public.interviews
group by mode
order by completed desc;

create view analytics.v_interview_funnel as
select
  props ->> 'mode' as mode,
  count(*) filter (where name = 'interview_started')   as started,
  count(*) filter (where name = 'interview_completed') as completed,
  round(
    100.0 * count(*) filter (where name = 'interview_completed')
          / nullif(count(*) filter (where name = 'interview_started'), 0),
    1
  ) as completion_pct
from public.events
where name in ('interview_started', 'interview_completed')
group by 1
order by started desc;

-- Record-versus-upload mix, and what kinds of files arrive. Filenames are
-- deliberately never recorded — only the extension and size.
create view analytics.v_upload_mix as
select
  props ->> 'ext'                                        as ext,
  count(*)                                               as uploads,
  count(distinct user_id)                                as users,
  round(avg((props ->> 'size_bytes')::numeric) / 1048576, 2)   as avg_size_mb,
  round(avg((props ->> 'duration_seconds')::numeric), 0) as avg_duration_seconds
from public.events
where name = 'file_uploaded'
group by 1
order by uploads desc;

-- Daily active users across both flows.
create view analytics.v_daily_active as
select
  day,
  count(distinct user_id) as active_users,
  sum(activities)         as activities
from (
  select date_trunc('day', recorded_at) as day, user_id, count(*) as activities
  from public.sessions group by 1, 2
  union all
  select date_trunc('day', recorded_at) as day, user_id, count(*) as activities
  from public.interviews group by 1, 2
) t
group by day
order by day desc;

-- Raw event volume, for anything the named views above do not answer.
create view analytics.v_event_volume as
select
  name,
  date_trunc('day', created_at) as day,
  count(*)                      as events,
  count(distinct user_id)       as users
from public.events
group by 1, 2
order by day desc, events desc;
