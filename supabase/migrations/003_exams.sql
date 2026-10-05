-- =====================================================================
-- Study Architect V2 - Step 11: exams, in the same style as the other
-- synced tables (text ids, camelCase columns, primary key (user_id, id)).
-- Replaces the unused snake_case exams / exam_topics tables from 001.
-- =====================================================================

drop table if exists public.exam_topics;
drop table if exists public.exams;

create table public.exams (
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id           text not null,
  "subjectId"  text not null,
  title        text not null,
  "examDate"   text not null,
  location     text not null default '',
  notes        text not null default '',
  "createdAt"  text not null,
  "updatedAt"  timestamptz not null,
  "deletedAt"  timestamptz,
  primary key (user_id, id)
);

create table public.exam_topics (
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id           text not null,
  "examId"     text not null,
  "topicId"    text not null,
  prepared     integer not null default 0,
  "updatedAt"  timestamptz not null,
  "deletedAt"  timestamptz,
  primary key (user_id, id)
);

create index idx_exams_sync       on public.exams       (user_id, "updatedAt");
create index idx_exam_topics_sync on public.exam_topics (user_id, "updatedAt");

alter table public.exams       enable row level security;
alter table public.exam_topics enable row level security;

create policy "exams_select_own" on public.exams for select using (auth.uid() = user_id);
create policy "exams_insert_own" on public.exams for insert with check (auth.uid() = user_id);
create policy "exams_update_own" on public.exams for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "exams_delete_own" on public.exams for delete using (auth.uid() = user_id);

create policy "exam_topics_select_own" on public.exam_topics for select using (auth.uid() = user_id);
create policy "exam_topics_insert_own" on public.exam_topics for insert with check (auth.uid() = user_id);
create policy "exam_topics_update_own" on public.exam_topics for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "exam_topics_delete_own" on public.exam_topics for delete using (auth.uid() = user_id);

alter publication supabase_realtime add table public.exams, public.exam_topics;

notify pgrst, 'reload schema';
