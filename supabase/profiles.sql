-- =============================================================================
-- Amisa — table `public.profiles` (source de vérité profil, liée à `auth.users`)
-- =============================================================================
-- Où exécuter : Supabase Dashboard → SQL Editor → New query → coller ce fichier → Run
--
-- Idempotent : safe sur projet vide ou déjà partiellement migré.
-- L’app iOS doit envoyer gender ∈ { female, male, other } (pas « Femme » / « Homme »).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Table
-- ---------------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name text,
  last_name text,
  display_name text,
  birth_date date,
  gender text,
  country text,
  avatar_url text,
  banner_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint profiles_gender_check check (
    gender is null or gender in ('female', 'male', 'other')
  )
);

comment on table public.profiles is
  'Profil utilisateur Amisa — source de vérité hors auth.users (id = auth.users.id).';

comment on column public.profiles.id is 'UUID Supabase Auth, identique à auth.users.id';
comment on column public.profiles.display_name is 'Libellé affiché ; souvent dérivé de first_name + last_name côté app';
comment on column public.profiles.gender is 'female | male | other | null';
comment on column public.profiles.country is 'Pays / zone d’achat (texte libre, nullable)';

-- Colonnes ajoutées si la table existait déjà sans elles
alter table public.profiles
  add column if not exists first_name text,
  add column if not exists last_name text,
  add column if not exists display_name text,
  add column if not exists birth_date date,
  add column if not exists gender text,
  add column if not exists country text,
  add column if not exists avatar_url text,
  add column if not exists banner_url text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

-- Normaliser d’éventuelles valeurs legacy avant d’appliquer la contrainte gender
update public.profiles
set gender = 'female'
where gender is not null
  and lower(trim(gender)) in ('femme', 'f', 'female', 'woman', 'women');

update public.profiles
set gender = 'male'
where gender is not null
  and lower(trim(gender)) in ('homme', 'm', 'male', 'man', 'men');

update public.profiles
set gender = 'other'
where gender is not null
  and lower(trim(gender)) in ('other', 'autre', 'non-binary', 'non_binary', 'nb');

-- Valeurs hors enum → null (évite échec de la contrainte)
update public.profiles
set gender = null
where gender is not null
  and gender not in ('female', 'male', 'other');

-- Contrainte gender (idempotent)
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_gender_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_gender_check check (
        gender is null or gender in ('female', 'male', 'other')
      );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. `updated_at` automatique
-- ---------------------------------------------------------------------------

create or replace function public.handle_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

comment on function public.handle_updated_at() is
  'Met à jour updated_at avant UPDATE (utilisé par set_profiles_updated_at).';

drop trigger if exists set_profiles_updated_at on public.profiles;

create trigger set_profiles_updated_at
  before update on public.profiles
  for each row
  execute function public.handle_updated_at();

-- ---------------------------------------------------------------------------
-- 3. Row Level Security (RLS)
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles
  for select
  to authenticated
  using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles
  for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- DELETE : uniquement sa propre ligne (suppression de compte / RGPD côté app si besoin)
drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own"
  on public.profiles
  for delete
  to authenticated
  using (auth.uid() = id);

-- ---------------------------------------------------------------------------
-- 4. Création auto d’un profil à l’inscription (`auth.users`)
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta jsonb;
  v_first text;
  v_last text;
  v_full text;
  v_display text;
  v_avatar text;
begin
  meta := coalesce(new.raw_user_meta_data, '{}'::jsonb);

  v_first := nullif(trim(coalesce(
    meta ->> 'first_name',
    meta ->> 'given_name'
  )), '');

  v_last := nullif(trim(coalesce(
    meta ->> 'last_name',
    meta ->> 'family_name'
  )), '');

  v_full := nullif(trim(coalesce(
    meta ->> 'full_name',
    meta ->> 'name'
  )), '');

  v_avatar := nullif(trim(coalesce(
    meta ->> 'avatar_url',
    meta ->> 'picture'
  )), '');

  -- Si seulement full_name : display_name = full_name, prénom/nom restent null
  if v_first is null and v_last is null and v_full is not null then
    v_display := v_full;
  else
    v_display := nullif(trim(concat_ws(' ', v_first, v_last)), '');
    if v_display is null and v_full is not null then
      v_display := v_full;
    end if;
  end if;

  insert into public.profiles (
    id,
    first_name,
    last_name,
    display_name,
    avatar_url,
    created_at,
    updated_at
  )
  values (
    new.id,
    v_first,
    v_last,
    v_display,
    v_avatar,
    now(),
    now()
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

comment on function public.handle_new_user() is
  'Crée une ligne profiles à partir de raw_user_meta_data (OAuth / magic link).';

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 5. Backfill (optionnel) — utilisateurs auth sans ligne profiles
-- ---------------------------------------------------------------------------
-- Décommenter et exécuter une fois si vous aviez déjà des comptes avant ce script.

/*
insert into public.profiles (
  id,
  first_name,
  last_name,
  display_name,
  avatar_url,
  created_at,
  updated_at
)
select
  u.id,
  nullif(trim(coalesce(
    u.raw_user_meta_data ->> 'first_name',
    u.raw_user_meta_data ->> 'given_name'
  )), '') as first_name,
  nullif(trim(coalesce(
    u.raw_user_meta_data ->> 'last_name',
    u.raw_user_meta_data ->> 'family_name'
  )), '') as last_name,
  coalesce(
    nullif(trim(concat_ws(' ',
      nullif(trim(coalesce(u.raw_user_meta_data ->> 'first_name', u.raw_user_meta_data ->> 'given_name')), ''),
      nullif(trim(coalesce(u.raw_user_meta_data ->> 'last_name', u.raw_user_meta_data ->> 'family_name')), '')
    )), ''),
    nullif(trim(coalesce(
      u.raw_user_meta_data ->> 'full_name',
      u.raw_user_meta_data ->> 'name'
    )), '')
  ) as display_name,
  nullif(trim(coalesce(
    u.raw_user_meta_data ->> 'avatar_url',
    u.raw_user_meta_data ->> 'picture'
  )), '') as avatar_url,
  coalesce(u.created_at, now()),
  now()
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null
on conflict (id) do nothing;
*/

-- ---------------------------------------------------------------------------
-- 6. Vérification rapide (lecture seule)
-- ---------------------------------------------------------------------------

-- select count(*) as profiles_count from public.profiles;
-- select id, first_name, last_name, display_name, gender, country, created_at
-- from public.profiles
-- order by created_at desc
-- limit 10;
