-- Study Architect V2 - Step 7: recurring study sessions
alter table public.study_sessions
  add column if not exists "recurrence" text not null default 'none',
  add column if not exists "recurrenceUntil" text,
  add column if not exists "seriesId" text;

notify pgrst, 'reload schema';
