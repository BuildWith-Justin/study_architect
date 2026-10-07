-- =====================================================================
-- Study Architect V2 - Step 13: gamification tables, in the same style
-- as the other synced tables (text ids, camelCase columns, primary key
-- (user_id, id)). Replaces the unused snake_case achievements / xp_log
-- tables created by 001.
-- =====================================================================

drop table if exists public.xp_log;
drop table if exists public.achievements;

create table public.achievements (
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id            text not null,
  "unlockedAt"  text not null,
  "updatedAt"   timestamptz not null,
  "deletedAt"   timestamptz,
  primary key (user_id, id)
);

create table public.xp_log (
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id            text not null,
  "sourceType"  text not null,
  "sourceId"    text not null,
  amount        integer not null,
  reason        text not null default '',
  "earnedAt"    text not null,
  "updatedAt"   timestamptz not null,
  "deletedAt"   timestamptz,
  primary key (user_id, id)
);

create index idx_achievements_sync on public.achievements (user_id, "updatedAt");
create index idx_xp_log_sync       on public.xp_log       (user_id, "updatedAt");

alter table public.achievements enable row level security;
alter table public.xp_log       enable row level security;

create policy "achievements_select_own" on public.achievements for select using (auth.uid() = user_id);
create policy "achievements_insert_own" on public.achievements for insert with check (auth.uid() = user_id);
create policy "achievements_update_own" on public.achievements for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "achievements_delete_own" on public.achievements for delete using (auth.uid() = user_id);

create policy "xp_log_select_own" on public.xp_log for select using (auth.uid() = user_id);
create policy "xp_log_insert_own" on public.xp_log for insert with check (auth.uid() = user_id);
create policy "xp_log_update_own" on public.xp_log for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "xp_log_delete_own" on public.xp_log for delete using (auth.uid() = user_id);

alter publication supabase_realtime add table public.achievements, public.xp_log;

notify pgrst, 'reload schema';
