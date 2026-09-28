-- =====================================================================
-- Study Architect V2 — Step 2: Schema, RLS, Realtime
-- =====================================================================

-- ---------- Shared helper: server-authoritative updated_at ----------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------- profiles (1 row per auth user) ----------
create table public.profiles (
  id                   uuid primary key references auth.users(id) on delete cascade,
  display_name         text not null default '',
  institution          text,
  study_level          text,
  daily_goal_minutes   integer not null default 120 check (daily_goal_minutes between 0 and 1440),
  avatar_url           text,
  xp_total             integer not null default 0 check (xp_total >= 0),
  level                integer not null default 1 check (level >= 1),
  current_streak       integer not null default 0,
  longest_streak       integer not null default 0,
  last_study_date      date,
  onboarding_done      boolean not null default false,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- ---------- user_settings ----------
create table public.user_settings (
  user_id              uuid primary key references auth.users(id) on delete cascade,
  theme_mode           text not null default 'system' check (theme_mode in ('system','light','dark')),
  notifications_on     boolean not null default true,
  reminder_minutes     integer not null default 10,
  week_starts_on       smallint not null default 1 check (week_starts_on between 0 and 6),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- ---------- subjects ----------
create table public.subjects (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  name                 text not null,
  color_value          integer not null default 0,
  weekly_target_min    integer not null default 0,
  sort_order           integer not null default 0,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  deleted_at           timestamptz
);

-- ---------- topics (ordered roadmap per subject) ----------
create table public.topics (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  subject_id           uuid not null references public.subjects(id) on delete cascade,
  title                text not null,
  notes                text,
  sort_order           integer not null default 0,
  is_completed         boolean not null default false,
  completed_at         timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  deleted_at           timestamptz
);

-- ---------- study_sessions (planned timetable entries) ----------
create table public.study_sessions (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  subject_id           uuid references public.subjects(id) on delete set null,
  topic_id             uuid references public.topics(id) on delete set null,
  title                text not null default '',
  start_at             timestamptz not null,
  end_at               timestamptz not null,
  recurrence           text not null default 'none' check (recurrence in ('none','weekly')),
  recurrence_until     date,
  status               text not null default 'planned' check (status in ('planned','completed','skipped')),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  deleted_at           timestamptz,
  check (end_at > start_at)
);

-- ---------- study_logs (what actually happened: focus + manual logs) ----------
create table public.study_logs (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  session_id           uuid references public.study_sessions(id) on delete set null,
  subject_id           uuid references public.subjects(id) on delete set null,
  topic_id             uuid references public.topics(id) on delete set null,
  started_at           timestamptz not null,
  duration_seconds     integer not null check (duration_seconds >= 0),
  source               text not null default 'focus' check (source in ('focus','manual')),
  mood                 smallint check (mood between 1 and 5),
  notes                text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  deleted_at           timestamptz
);

-- ---------- tasks ----------
create table public.tasks (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  subject_id           uuid references public.subjects(id) on delete set null,
  title                text not null,
  due_at               timestamptz,
  priority             smallint not null default 1 check (priority between 0 and 2),
  is_done              boolean not null default false,
  done_at              timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  deleted_at           timestamptz
);

-- ---------- exams (NEW in V2) ----------
create table public.exams (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  subject_id           uuid not null references public.subjects(id) on delete cascade,
  title                text not null,
  exam_at              timestamptz not null,
  location             text,
  notes                text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  deleted_at           timestamptz
);

-- ---------- exam_topics (prep checklist, NEW in V2) ----------
create table public.exam_topics (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  exam_id              uuid not null references public.exams(id) on delete cascade,
  topic_id             uuid not null references public.topics(id) on delete cascade,
  is_prepared          boolean not null default false,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  deleted_at           timestamptz,
  unique (exam_id, topic_id)
);

-- ---------- achievements (unlocked badges, NEW in V2) ----------
create table public.achievements (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  code                 text not null,
  unlocked_at          timestamptz not null default now(),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  deleted_at           timestamptz,
  unique (user_id, code)
);

-- ---------- xp_log (append-only XP ledger, NEW in V2) ----------
create table public.xp_log (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  amount               integer not null,
  reason               text not null,
  source_id            uuid,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  deleted_at           timestamptz
);

-- ---------- Indexes for incremental pull (user_id + updated_at) ----------
create index idx_subjects_sync       on public.subjects       (user_id, updated_at);
create index idx_topics_sync         on public.topics         (user_id, updated_at);
create index idx_topics_subject      on public.topics         (subject_id, sort_order);
create index idx_sessions_sync       on public.study_sessions (user_id, updated_at);
create index idx_sessions_start      on public.study_sessions (user_id, start_at);
create index idx_logs_sync           on public.study_logs     (user_id, updated_at);
create index idx_logs_started        on public.study_logs     (user_id, started_at);
create index idx_tasks_sync          on public.tasks          (user_id, updated_at);
create index idx_exams_sync          on public.exams          (user_id, updated_at);
create index idx_exam_topics_sync    on public.exam_topics    (user_id, updated_at);
create index idx_achievements_sync   on public.achievements   (user_id, updated_at);
create index idx_xp_log_sync         on public.xp_log         (user_id, updated_at);

-- ---------- updated_at triggers + Row Level Security ----------
do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles','user_settings','subjects','topics','study_sessions','study_logs',
    'tasks','exams','exam_topics','achievements','xp_log'
  ]
  loop
    execute format(
      'create trigger trg_%1$s_updated_at before update on public.%1$I
         for each row execute function public.set_updated_at();', t);

    execute format('alter table public.%I enable row level security;', t);

    if t = 'profiles' then
      execute 'create policy "profiles_select_own" on public.profiles for select using (auth.uid() = id);';
      execute 'create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = id);';
      execute 'create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);';
      execute 'create policy "profiles_delete_own" on public.profiles for delete using (auth.uid() = id);';
    else
      execute format('create policy "%1$s_select_own" on public.%1$I for select using (auth.uid() = user_id);', t);
      execute format('create policy "%1$s_insert_own" on public.%1$I for insert with check (auth.uid() = user_id);', t);
      execute format('create policy "%1$s_update_own" on public.%1$I for update using (auth.uid() = user_id) with check (auth.uid() = user_id);', t);
      execute format('create policy "%1$s_delete_own" on public.%1$I for delete using (auth.uid() = user_id);', t);
    end if;
  end loop;
end;
$$;

-- ---------- Auto-create profile + settings on sign-up ----------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', ''))
  on conflict (id) do nothing;

  insert into public.user_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- Realtime (feeds DataRefreshBus in Step 4) ----------
alter publication supabase_realtime add table
  public.profiles, public.subjects, public.topics, public.study_sessions,
  public.study_logs, public.tasks, public.exams, public.exam_topics,
  public.achievements, public.xp_log;