-- Run this migration in Supabase SQL Editor or via Supabase CLI.
create extension if not exists pgcrypto;

create type public.app_role as enum ('admin', 'viewer');
create type public.content_status as enum ('draft', 'published', 'archived');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text not null,
  last_name text not null,
  father_name text,
  birth_date date,
  national_code text,
  field_of_study text,
  grade text,
  role public.app_role not null default 'viewer',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint national_code_format check (national_code is null or national_code ~ '^[0-9]{10}$')
);

create table public.news (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 180),
  summary text,
  body text not null,
  category text not null default 'اطلاعیه',
  status public.content_status not null default 'draft',
  cover_url text,
  image_urls text[] not null default '{}',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.work_reports (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 180),
  summary text,
  body text not null,
  activity_date date not null default current_date,
  status public.content_status not null default 'draft',
  cover_url text,
  image_urls text[] not null default '{}',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.report_attendees (
  report_id uuid not null references public.work_reports(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete restrict,
  display_name text not null,
  primary key (report_id, profile_id)
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 180),
  description text,
  starts_at timestamptz not null,
  location text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  target_table text not null,
  target_id text,
  created_at timestamptz not null default now()
);

create index news_published_created_idx on public.news(status, created_at desc);
create index reports_published_date_idx on public.work_reports(status, activity_date desc);
create index events_starts_idx on public.events(starts_at);

create or replace function public.is_active_user()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.is_active = true)
$$;
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.is_active = true and p.role = 'admin')
$$;
revoke all on function public.is_active_user() from public;
revoke all on function public.is_admin() from public;
grant execute on function public.is_active_user() to authenticated;
grant execute on function public.is_admin() to authenticated;

alter table public.profiles enable row level security;
alter table public.news enable row level security;
alter table public.work_reports enable row level security;
alter table public.report_attendees enable row level security;
alter table public.events enable row level security;
alter table public.audit_logs enable row level security;

-- Site is private: authenticated, active users can read published content only.
create policy "active users read own profile" on public.profiles for select to authenticated
using (id = (select auth.uid()) or public.is_admin());
create policy "admins create profiles" on public.profiles for insert to authenticated with check (public.is_admin());
create policy "admins update profiles" on public.profiles for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "active users read published news" on public.news for select to authenticated
using (public.is_active_user() and status = 'published');
create policy "admins manage news" on public.news for all to authenticated
using (public.is_admin()) with check (public.is_admin());
create policy "active users read published reports" on public.work_reports for select to authenticated
using (public.is_active_user() and status = 'published');
create policy "admins manage reports" on public.work_reports for all to authenticated
using (public.is_admin()) with check (public.is_admin());
create policy "active users read attendees of published reports" on public.report_attendees for select to authenticated
using (public.is_active_user() and exists (select 1 from public.work_reports r where r.id = report_id and r.status = 'published'));
create policy "admins manage report attendees" on public.report_attendees for all to authenticated
using (public.is_admin()) with check (public.is_admin());
create policy "active users read events" on public.events for select to authenticated using (public.is_active_user());
create policy "admins manage events" on public.events for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admins read audit logs" on public.audit_logs for select to authenticated using (public.is_admin());
create policy "admins insert audit logs" on public.audit_logs for insert to authenticated with check (public.is_admin());

-- Private media bucket. Store object paths (not public URLs) in cover_url/image_urls.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', false, 5242880, array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set public = false, file_size_limit = 5242880, allowed_mime_types = excluded.allowed_mime_types;
create policy "active users read media" on storage.objects for select to authenticated
using (bucket_id = 'media' and public.is_active_user());
create policy "admins upload media" on storage.objects for insert to authenticated
with check (bucket_id = 'media' and public.is_admin());
create policy "admins update media" on storage.objects for update to authenticated
using (bucket_id = 'media' and public.is_admin()) with check (bucket_id = 'media' and public.is_admin());
create policy "admins delete media" on storage.objects for delete to authenticated
using (bucket_id = 'media' and public.is_admin());

-- IMPORTANT: create the first Auth user in Supabase Dashboard, then insert its profile
-- with role='admin' from the SQL Editor using that user's auth.users UUID.
