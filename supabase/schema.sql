-- Future cloud schema; Phase 1 demo uses local SharedPreferences only.
create extension if not exists pgcrypto;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null check (char_length(display_name) between 1 and 60),
 exam_level text not null check (exam_level in ('professional','subprofessional')),
 exam_date date,
 created_at timestamptz not null default now()
);
create table public.study_preferences (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 local_start_time time not null default '19:00',
 daily_minutes integer not null default 120 check (daily_minutes between 30 and 720),
 break_minutes integer not null default 10 check (break_minutes between 0 and 60),
 timezone text not null default 'Asia/Manila',
 notifications_enabled boolean not null default false,
 updated_at timestamptz not null default now()
);
create table public.subjects (
 id uuid primary key default gen_random_uuid(),
 title text not null,
 exam_level text not null check (exam_level in ('professional','subprofessional','both')),
 display_order integer not null default 0
);
create table public.topics (
 id uuid primary key default gen_random_uuid(),
 subject_id uuid not null references public.subjects(id) on delete cascade,
 title text not null,
 display_order integer not null default 0
);
create table public.lessons (
 id uuid primary key default gen_random_uuid(),
 topic_id uuid not null references public.topics(id) on delete cascade,
 title text not null,
 body text not null default '',
 review_status text not null default 'draft' check (review_status in ('draft','reviewed','published')),
 source_url text,
 verified_at timestamptz
);
create table public.study_sessions (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 started_at timestamptz not null,
 ended_at timestamptz,
 status text not null default 'planned' check (status in ('planned','active','completed','missed','cancelled'))
);
alter table public.profiles enable row level security;
alter table public.study_preferences enable row level security;
alter table public.study_sessions enable row level security;
alter table public.subjects enable row level security;
alter table public.topics enable row level security;
alter table public.lessons enable row level security;
create policy "own profile" on public.profiles for all to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy "own preferences" on public.study_preferences for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "own sessions" on public.study_sessions for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "read subjects" on public.subjects for select to authenticated using (true);
create policy "read topics" on public.topics for select to authenticated using (true);
create policy "read published lessons" on public.lessons for select to authenticated using (review_status = 'published');
-- Editorial writes must use a separate secured admin service and explicit authorization.
