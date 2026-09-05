-- VouchTerra — account schema v1
-- Paste this whole file into Supabase → SQL Editor → New query → Run. Safe to re-run.
--
-- What it does:
--   1. profiles table: one row per signed-in user, keyed to auth.users
--   2. member_number: assigned automatically and permanently on first save (1, 2, 3, …)
--      The first N (N = foundingLimit in config.js, default 10) are Founding Members.
--   3. Row-level security: a user can read/write ONLY their own row. Nothing is public yet.
--   4. Trigger: creates the profile stub the moment a user signs up, so member numbers
--      are claimed in true signup order, not "who filled the form fastest".

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------
-- 1. profiles
-- ---------------------------------------------------------------
create table if not exists public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  email           text,
  first_name      text,
  last_name       text,
  role            text,
  market          text,
  license_number  text,                         -- WA DOL license #, agents/brokers only; never public
  license_verified boolean not null default false,
  member_number   integer unique,               -- permanent, assigned on insert, never re-issued
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.profiles is 'One row per VouchTerra account. member_number is permanent.';

-- ---------------------------------------------------------------
-- 2. member numbering (sequence + trigger)
-- ---------------------------------------------------------------
create sequence if not exists public.member_number_seq start 1;

create or replace function public.assign_member_number()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.member_number is null then
    new.member_number := nextval('public.member_number_seq');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_assign_member_number on public.profiles;
create trigger trg_assign_member_number
  before insert on public.profiles
  for each row execute function public.assign_member_number();

-- Never let a client change member_number after the fact.
create or replace function public.protect_member_number()
returns trigger
language plpgsql
as $$
begin
  if new.member_number is distinct from old.member_number then
    raise exception 'member_number is permanent';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_protect_member_number on public.profiles;
create trigger trg_protect_member_number
  before update on public.profiles
  for each row execute function public.protect_member_number();

-- ---------------------------------------------------------------
-- 3. Create the profile stub at signup (claims the number in signup order)
-- ---------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------
-- 4. Row-level security — users see and edit only themselves
-- ---------------------------------------------------------------
alter table public.profiles enable row level security;

drop policy if exists "profiles: read own"   on public.profiles;
drop policy if exists "profiles: insert own" on public.profiles;
drop policy if exists "profiles: update own" on public.profiles;

create policy "profiles: read own"
  on public.profiles for select
  using (auth.uid() = id);

create policy "profiles: insert own"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "profiles: update own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Only signed-in users can touch the table at all.
revoke all on public.profiles from anon;
grant select, insert, update on public.profiles to authenticated;
grant usage on sequence public.member_number_seq to authenticated;

-- ---------------------------------------------------------------
-- Handy: see your members in signup order
-- ---------------------------------------------------------------
-- select member_number, first_name, last_name, role, market, email, created_at
-- from public.profiles order by member_number;
