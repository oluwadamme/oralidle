-- Core schema for cross-device history and usage analytics.
--
-- Every table is keyed on auth.uid() and protected by RLS. The anon key ships
-- in the web bundle by design, so RLS is the only thing standing between one
-- user's transcripts and another's — it is enabled on every table here without
-- exception.
--
-- Rows are append-only: a session is written once when analysis completes and
-- never edited. That is what lets the client sync with last-write-wins and no
-- conflict resolution.

create extension if not exists "uuid-ossp";

-- ── profiles ──────────────────────────────────────────────────────────────
-- One row per auth user, created by trigger on signup. Anonymous users get a
-- row too, with a null display_name until they link an email.

create table public.profiles (
  id           uuid primary key references auth.users on delete cascade,
  display_name text,
  created_at   timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "own profile" on public.profiles
  for all to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, new.raw_user_meta_data ->> 'display_name')
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── sessions ──────────────────────────────────────────────────────────────
-- One completed speech-practice session. `result` is AnalysisResult.toJson()
-- stored verbatim — the Dart model already emits snake_case wire keys, so no
-- column-per-score mapping is needed and the model can evolve without a
-- migration.

create table public.sessions (
  id                uuid primary key,
  user_id           uuid not null references auth.users on delete cascade,
  topic_title       text not null,
  topic_category    text not null,
  duration_seconds  int not null,
  result            jsonb not null,
  -- Storage object key, never a device file path: a path from one device is
  -- meaningless on another.
  audio_object_path text,
  recorded_at       timestamptz not null,
  created_at        timestamptz not null default now()
);

create index sessions_user_recorded_idx
  on public.sessions (user_id, recorded_at desc);

alter table public.sessions enable row level security;

create policy "own sessions" on public.sessions
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ── interviews ────────────────────────────────────────────────────────────

create table public.interviews (
  id               uuid primary key,
  user_id          uuid not null references auth.users on delete cascade,
  mode             text not null,
  target_questions int not null,
  turns            jsonb not null,
  evaluation       jsonb not null,
  recorded_at      timestamptz not null,
  created_at       timestamptz not null default now()
);

create index interviews_user_recorded_idx
  on public.interviews (user_id, recorded_at desc);

alter table public.interviews enable row level security;

create policy "own interviews" on public.interviews
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ── events ────────────────────────────────────────────────────────────────
-- Product analytics. Covers intent that never produces a session row — a topic
-- opened but abandoned, an interview started but not finished.
--
-- Insert-only for the client: there is deliberately no select policy, so a
-- user cannot read the event stream at all. Aggregates are read from the SQL
-- editor via the analytics schema, which PostgREST does not expose.
--
-- `props` must never carry a filename, a transcript, or CV content.

create table public.events (
  id         bigserial primary key,
  user_id    uuid references auth.users on delete set null,
  name       text not null,
  props      jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index events_name_created_idx on public.events (name, created_at desc);
create index events_created_idx on public.events (created_at desc);

alter table public.events enable row level security;

create policy "insert own events" on public.events
  for insert to authenticated
  with check ((select auth.uid()) = user_id);
