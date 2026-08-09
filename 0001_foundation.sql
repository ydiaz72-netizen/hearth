-- ============================================================
-- HEARTH — Phase 1 Foundation Migration
-- Users, Households, Membership, Roles, Permissions, RLS
-- ============================================================

-- Extensions
create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------
-- PROFILES (extends auth.users)
-- ------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  display_name text,
  avatar_url text,
  default_currency text not null default 'EUR',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- HOUSEHOLDS
-- ------------------------------------------------------------
create table if not exists public.households (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  reporting_currency text not null default 'EUR',
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- HOUSEHOLD ROLES (lookup, extensible)
-- ------------------------------------------------------------
create table if not exists public.household_roles (
  id text primary key,              -- 'admin' | 'member'
  label text not null
);

insert into public.household_roles (id, label) values
  ('admin', 'Household Admin'),
  ('member', 'Household Member')
on conflict (id) do nothing;

-- ------------------------------------------------------------
-- HOUSEHOLD MEMBERSHIP
-- ------------------------------------------------------------
create table if not exists public.household_members (
  id uuid primary key default uuid_generate_v4(),
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role_id text not null references public.household_roles(id) default 'member',
  status text not null default 'active',   -- 'invited' | 'active' | 'removed'
  invited_email text,
  created_at timestamptz not null default now(),
  unique (household_id, user_id)
);

create index if not exists idx_household_members_user on public.household_members(user_id);
create index if not exists idx_household_members_household on public.household_members(household_id);

-- ------------------------------------------------------------
-- BUSINESSES (Phase 3 groundwork — created now so FKs exist later)
-- ------------------------------------------------------------
create table if not exists public.businesses (
  id uuid primary key default uuid_generate_v4(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null,
  currency text not null default 'EUR',
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- HELPER FUNCTIONS
-- ------------------------------------------------------------

-- Is the current user an active member of a household?
create or replace function public.is_household_member(target_household_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from public.household_members hm
    where hm.household_id = target_household_id
      and hm.user_id = auth.uid()
      and hm.status = 'active'
  );
$$;

-- Is the current user an admin of a household?
create or replace function public.is_household_admin(target_household_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from public.household_members hm
    where hm.household_id = target_household_id
      and hm.user_id = auth.uid()
      and hm.role_id = 'admin'
      and hm.status = 'active'
  );
$$;

-- ------------------------------------------------------------
-- ROW LEVEL SECURITY
-- ------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.businesses enable row level security;
alter table public.household_roles enable row level security;

-- PROFILES: a user can read their own profile, and profiles of people
-- who share a household with them (needed for displaying member names).
-- A user can only update their own profile.
drop policy if exists "profiles_select_own_or_household" on public.profiles;
create policy "profiles_select_own_or_household"
  on public.profiles for select
  using (
    id = auth.uid()
    or exists (
      select 1
      from public.household_members me
      join public.household_members them on them.household_id = me.household_id
      where me.user_id = auth.uid()
        and me.status = 'active'
        and them.user_id = public.profiles.id
        and them.status = 'active'
    )
  );

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (id = auth.uid());

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (id = auth.uid());

-- HOUSEHOLDS: members can select; only creators/admins can update.
-- Insert is allowed for any authenticated user (they become admin via app logic).
drop policy if exists "households_select_member" on public.households;
create policy "households_select_member"
  on public.households for select
  using (public.is_household_member(id));

drop policy if exists "households_insert_authenticated" on public.households;
create policy "households_insert_authenticated"
  on public.households for insert
  with check (auth.uid() is not null);

drop policy if exists "households_update_admin" on public.households;
create policy "households_update_admin"
  on public.households for update
  using (public.is_household_admin(id));

-- HOUSEHOLD_MEMBERS: members can see other members of their own household.
-- Only admins can insert/update/delete membership rows (except a user
-- accepting their own invite, handled at application layer via service role).
drop policy if exists "household_members_select_own_household" on public.household_members;
create policy "household_members_select_own_household"
  on public.household_members for select
  using (public.is_household_member(household_id));

drop policy if exists "household_members_insert_admin_or_self_creation" on public.household_members;
create policy "household_members_insert_admin_or_self_creation"
  on public.household_members for insert
  with check (
    public.is_household_admin(household_id)
    or user_id = auth.uid()
  );

drop policy if exists "household_members_update_admin" on public.household_members;
create policy "household_members_update_admin"
  on public.household_members for update
  using (public.is_household_admin(household_id));

drop policy if exists "household_members_delete_admin" on public.household_members;
create policy "household_members_delete_admin"
  on public.household_members for delete
  using (public.is_household_admin(household_id));

-- HOUSEHOLD_ROLES: readable by any authenticated user (it's a lookup table).
drop policy if exists "household_roles_select_all" on public.household_roles;
create policy "household_roles_select_all"
  on public.household_roles for select
  using (auth.uid() is not null);

-- BUSINESSES: same household-membership rule as other shared data.
drop policy if exists "businesses_select_member" on public.businesses;
create policy "businesses_select_member"
  on public.businesses for select
  using (public.is_household_member(household_id));

drop policy if exists "businesses_insert_admin" on public.businesses;
create policy "businesses_insert_admin"
  on public.businesses for insert
  with check (public.is_household_admin(household_id));

drop policy if exists "businesses_update_admin" on public.businesses;
create policy "businesses_update_admin"
  on public.businesses for update
  using (public.is_household_admin(household_id));

-- ------------------------------------------------------------
-- TRIGGER: auto-create a profile row when a new auth user signs up
-- ------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ------------------------------------------------------------
-- updated_at maintenance
-- ------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_updated_at_profiles on public.profiles;
create trigger set_updated_at_profiles before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at_households on public.households;
create trigger set_updated_at_households before update on public.households
  for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at_businesses on public.businesses;
create trigger set_updated_at_businesses before update on public.businesses
  for each row execute function public.set_updated_at();
