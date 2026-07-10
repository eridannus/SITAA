-- SITAA baseline migration generated from live Supabase reconciliation snapshots.
-- Source snapshots:
-- - supabase/reconciliation/live_columns_snapshot.json
-- - supabase/reconciliation/live_functions_snapshot.json
-- - supabase/reconciliation/live_policies_snapshot.json
-- - supabase/reconciliation/live_snapshot_queries.sql
--
-- Important: this baseline documents the current prototype database state for review
-- and future reproducibility. Do not execute automatically against production without
-- reviewing TODOs, constraints, indexes, triggers, grants and catalog seed data.
-- The migration is intentionally non-destructive: it does not drop data, truncate
-- tables, delete records or reset sequences/identities.

begin;

-- ============================================================
-- Extensions
-- ============================================================

create extension if not exists pgcrypto;
create extension if not exists unaccent;

-- ============================================================
-- Tables
-- ============================================================

-- Table: public.academic_periods
create table if not exists public.academic_periods (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  code text NOT NULL,
  name text NOT NULL,
  starts_on date,
  ends_on date,
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

alter table public.academic_periods
  add column if not exists id uuid DEFAULT gen_random_uuid();
alter table public.academic_periods
  alter column id set default gen_random_uuid();
do $$
begin
  if not exists (select 1 from public.academic_periods where id is null) then
    alter table public.academic_periods alter column id set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.academic_periods.id porque existen valores NULL.';
  end if;
end $$;
alter table public.academic_periods
  add column if not exists code text;
do $$
begin
  if not exists (select 1 from public.academic_periods where code is null) then
    alter table public.academic_periods alter column code set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.academic_periods.code porque existen valores NULL.';
  end if;
end $$;
alter table public.academic_periods
  add column if not exists name text;
do $$
begin
  if not exists (select 1 from public.academic_periods where name is null) then
    alter table public.academic_periods alter column name set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.academic_periods.name porque existen valores NULL.';
  end if;
end $$;
alter table public.academic_periods
  add column if not exists starts_on date;
alter table public.academic_periods
  add column if not exists ends_on date;
alter table public.academic_periods
  add column if not exists is_active boolean DEFAULT true;
alter table public.academic_periods
  alter column is_active set default true;
do $$
begin
  if not exists (select 1 from public.academic_periods where is_active is null) then
    alter table public.academic_periods alter column is_active set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.academic_periods.is_active porque existen valores NULL.';
  end if;
end $$;
alter table public.academic_periods
  add column if not exists sort_order integer DEFAULT 0;
alter table public.academic_periods
  alter column sort_order set default 0;
do $$
begin
  if not exists (select 1 from public.academic_periods where sort_order is null) then
    alter table public.academic_periods alter column sort_order set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.academic_periods.sort_order porque existen valores NULL.';
  end if;
end $$;
alter table public.academic_periods
  add column if not exists created_at timestamp with time zone DEFAULT now();
alter table public.academic_periods
  alter column created_at set default now();
do $$
begin
  if not exists (select 1 from public.academic_periods where created_at is null) then
    alter table public.academic_periods alter column created_at set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.academic_periods.created_at porque existen valores NULL.';
  end if;
end $$;
alter table public.academic_periods
  add column if not exists updated_at timestamp with time zone DEFAULT now();
alter table public.academic_periods
  alter column updated_at set default now();
do $$
begin
  if not exists (select 1 from public.academic_periods where updated_at is null) then
    alter table public.academic_periods alter column updated_at set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.academic_periods.updated_at porque existen valores NULL.';
  end if;
end $$;

-- Table: public.academic_programs
create table if not exists public.academic_programs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  division_id uuid NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

alter table public.academic_programs
  add column if not exists id uuid DEFAULT gen_random_uuid();
alter table public.academic_programs
  alter column id set default gen_random_uuid();
do $$
begin
  if not exists (select 1 from public.academic_programs where id is null) then
    alter table public.academic_programs alter column id set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.academic_programs.id porque existen valores NULL.';
  end if;
end $$;
alter table public.academic_programs
  add column if not exists division_id uuid;
do $$
begin
  if not exists (select 1 from public.academic_programs where division_id is null) then
    alter table public.academic_programs alter column division_id set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.academic_programs.division_id porque existen valores NULL.';
  end if;
end $$;
alter table public.academic_programs
  add column if not exists code text;
do $$
begin
  if not exists (select 1 from public.academic_programs where code is null) then
    alter table public.academic_programs alter column code set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.academic_programs.code porque existen valores NULL.';
  end if;
end $$;
alter table public.academic_programs
  add column if not exists name text;
do $$
begin
  if not exists (select 1 from public.academic_programs where name is null) then
    alter table public.academic_programs alter column name set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.academic_programs.name porque existen valores NULL.';
  end if;
end $$;
alter table public.academic_programs
  add column if not exists created_at timestamp with time zone DEFAULT now();
alter table public.academic_programs
  alter column created_at set default now();
do $$
begin
  if not exists (select 1 from public.academic_programs where created_at is null) then
    alter table public.academic_programs alter column created_at set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.academic_programs.created_at porque existen valores NULL.';
  end if;
end $$;

-- Table: public.activities
create table if not exists public.activities (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  academic_period_id uuid,
  program_id uuid,
  activity_type_code text,
  service_type_code text,
  attention_category_code text,
  modality_code text,
  status_code text NOT NULL DEFAULT 'draft'::text,
  location_type_code text,
  location_detail text,
  starts_at timestamp with time zone,
  ends_at timestamp with time zone,
  responsible_profile_id uuid NOT NULL,
  created_by uuid NOT NULL DEFAULT auth.uid(),
  updated_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  start_date date,
  start_time time without time zone,
  end_date date,
  end_time time without time zone,
  duration_mode text,
  scope_type text DEFAULT 'program'::text,
  division_id uuid
);

alter table public.activities
  add column if not exists id uuid DEFAULT gen_random_uuid();
alter table public.activities
  alter column id set default gen_random_uuid();
do $$
begin
  if not exists (select 1 from public.activities where id is null) then
    alter table public.activities alter column id set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activities.id porque existen valores NULL.';
  end if;
end $$;
alter table public.activities
  add column if not exists title text;
do $$
begin
  if not exists (select 1 from public.activities where title is null) then
    alter table public.activities alter column title set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activities.title porque existen valores NULL.';
  end if;
end $$;
alter table public.activities
  add column if not exists description text;
alter table public.activities
  add column if not exists academic_period_id uuid;
alter table public.activities
  add column if not exists program_id uuid;
alter table public.activities
  add column if not exists activity_type_code text;
alter table public.activities
  add column if not exists service_type_code text;
alter table public.activities
  add column if not exists attention_category_code text;
alter table public.activities
  add column if not exists modality_code text;
alter table public.activities
  add column if not exists status_code text DEFAULT 'draft'::text;
alter table public.activities
  alter column status_code set default 'draft'::text;
do $$
begin
  if not exists (select 1 from public.activities where status_code is null) then
    alter table public.activities alter column status_code set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activities.status_code porque existen valores NULL.';
  end if;
end $$;
alter table public.activities
  add column if not exists location_type_code text;
alter table public.activities
  add column if not exists location_detail text;
alter table public.activities
  add column if not exists starts_at timestamp with time zone;
alter table public.activities
  add column if not exists ends_at timestamp with time zone;
alter table public.activities
  add column if not exists responsible_profile_id uuid;
do $$
begin
  if not exists (select 1 from public.activities where responsible_profile_id is null) then
    alter table public.activities alter column responsible_profile_id set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activities.responsible_profile_id porque existen valores NULL.';
  end if;
end $$;
alter table public.activities
  add column if not exists created_by uuid DEFAULT auth.uid();
alter table public.activities
  alter column created_by set default auth.uid();
do $$
begin
  if not exists (select 1 from public.activities where created_by is null) then
    alter table public.activities alter column created_by set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activities.created_by porque existen valores NULL.';
  end if;
end $$;
alter table public.activities
  add column if not exists updated_by uuid;
alter table public.activities
  add column if not exists created_at timestamp with time zone DEFAULT now();
alter table public.activities
  alter column created_at set default now();
do $$
begin
  if not exists (select 1 from public.activities where created_at is null) then
    alter table public.activities alter column created_at set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activities.created_at porque existen valores NULL.';
  end if;
end $$;
alter table public.activities
  add column if not exists updated_at timestamp with time zone DEFAULT now();
alter table public.activities
  alter column updated_at set default now();
do $$
begin
  if not exists (select 1 from public.activities where updated_at is null) then
    alter table public.activities alter column updated_at set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activities.updated_at porque existen valores NULL.';
  end if;
end $$;
alter table public.activities
  add column if not exists start_date date;
alter table public.activities
  add column if not exists start_time time without time zone;
alter table public.activities
  add column if not exists end_date date;
alter table public.activities
  add column if not exists end_time time without time zone;
alter table public.activities
  add column if not exists duration_mode text;
alter table public.activities
  add column if not exists scope_type text DEFAULT 'program'::text;
alter table public.activities
  alter column scope_type set default 'program'::text;
alter table public.activities
  add column if not exists division_id uuid;

-- Table: public.activity_checkin_tokens
create table if not exists public.activity_checkin_tokens (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  activity_id uuid NOT NULL,
  token_type text NOT NULL DEFAULT 'attendance'::text,
  code_words text NOT NULL,
  secret_token text NOT NULL DEFAULT (gen_random_uuid())::text,
  is_active boolean NOT NULL DEFAULT true,
  opened_at timestamp with time zone NOT NULL DEFAULT now(),
  closed_at timestamp with time zone,
  expires_at timestamp with time zone,
  created_by uuid NOT NULL DEFAULT auth.uid(),
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

alter table public.activity_checkin_tokens
  add column if not exists id uuid DEFAULT gen_random_uuid();
alter table public.activity_checkin_tokens
  alter column id set default gen_random_uuid();
do $$
begin
  if not exists (select 1 from public.activity_checkin_tokens where id is null) then
    alter table public.activity_checkin_tokens alter column id set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_checkin_tokens.id porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_checkin_tokens
  add column if not exists activity_id uuid;
do $$
begin
  if not exists (select 1 from public.activity_checkin_tokens where activity_id is null) then
    alter table public.activity_checkin_tokens alter column activity_id set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_checkin_tokens.activity_id porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_checkin_tokens
  add column if not exists token_type text DEFAULT 'attendance'::text;
alter table public.activity_checkin_tokens
  alter column token_type set default 'attendance'::text;
do $$
begin
  if not exists (select 1 from public.activity_checkin_tokens where token_type is null) then
    alter table public.activity_checkin_tokens alter column token_type set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_checkin_tokens.token_type porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_checkin_tokens
  add column if not exists code_words text;
do $$
begin
  if not exists (select 1 from public.activity_checkin_tokens where code_words is null) then
    alter table public.activity_checkin_tokens alter column code_words set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_checkin_tokens.code_words porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_checkin_tokens
  add column if not exists secret_token text DEFAULT (gen_random_uuid())::text;
alter table public.activity_checkin_tokens
  alter column secret_token set default (gen_random_uuid())::text;
do $$
begin
  if not exists (select 1 from public.activity_checkin_tokens where secret_token is null) then
    alter table public.activity_checkin_tokens alter column secret_token set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_checkin_tokens.secret_token porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_checkin_tokens
  add column if not exists is_active boolean DEFAULT true;
alter table public.activity_checkin_tokens
  alter column is_active set default true;
do $$
begin
  if not exists (select 1 from public.activity_checkin_tokens where is_active is null) then
    alter table public.activity_checkin_tokens alter column is_active set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_checkin_tokens.is_active porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_checkin_tokens
  add column if not exists opened_at timestamp with time zone DEFAULT now();
alter table public.activity_checkin_tokens
  alter column opened_at set default now();
do $$
begin
  if not exists (select 1 from public.activity_checkin_tokens where opened_at is null) then
    alter table public.activity_checkin_tokens alter column opened_at set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_checkin_tokens.opened_at porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_checkin_tokens
  add column if not exists closed_at timestamp with time zone;
alter table public.activity_checkin_tokens
  add column if not exists expires_at timestamp with time zone;
alter table public.activity_checkin_tokens
  add column if not exists created_by uuid DEFAULT auth.uid();
alter table public.activity_checkin_tokens
  alter column created_by set default auth.uid();
do $$
begin
  if not exists (select 1 from public.activity_checkin_tokens where created_by is null) then
    alter table public.activity_checkin_tokens alter column created_by set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_checkin_tokens.created_by porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_checkin_tokens
  add column if not exists created_at timestamp with time zone DEFAULT now();
alter table public.activity_checkin_tokens
  alter column created_at set default now();
do $$
begin
  if not exists (select 1 from public.activity_checkin_tokens where created_at is null) then
    alter table public.activity_checkin_tokens alter column created_at set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_checkin_tokens.created_at porque existen valores NULL.';
  end if;
end $$;

-- Table: public.activity_modalities
create table if not exists public.activity_modalities (
  code text NOT NULL,
  label text NOT NULL,
  description text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

alter table public.activity_modalities
  add column if not exists code text;
do $$
begin
  if not exists (select 1 from public.activity_modalities where code is null) then
    alter table public.activity_modalities alter column code set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_modalities.code porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_modalities
  add column if not exists label text;
do $$
begin
  if not exists (select 1 from public.activity_modalities where label is null) then
    alter table public.activity_modalities alter column label set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_modalities.label porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_modalities
  add column if not exists description text;
alter table public.activity_modalities
  add column if not exists sort_order integer DEFAULT 0;
alter table public.activity_modalities
  alter column sort_order set default 0;
do $$
begin
  if not exists (select 1 from public.activity_modalities where sort_order is null) then
    alter table public.activity_modalities alter column sort_order set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_modalities.sort_order porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_modalities
  add column if not exists is_active boolean DEFAULT true;
alter table public.activity_modalities
  alter column is_active set default true;
do $$
begin
  if not exists (select 1 from public.activity_modalities where is_active is null) then
    alter table public.activity_modalities alter column is_active set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_modalities.is_active porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_modalities
  add column if not exists created_at timestamp with time zone DEFAULT now();
alter table public.activity_modalities
  alter column created_at set default now();
do $$
begin
  if not exists (select 1 from public.activity_modalities where created_at is null) then
    alter table public.activity_modalities alter column created_at set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_modalities.created_at porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_modalities
  add column if not exists updated_at timestamp with time zone DEFAULT now();
alter table public.activity_modalities
  alter column updated_at set default now();
do $$
begin
  if not exists (select 1 from public.activity_modalities where updated_at is null) then
    alter table public.activity_modalities alter column updated_at set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_modalities.updated_at porque existen valores NULL.';
  end if;
end $$;

-- Table: public.activity_participants
create table if not exists public.activity_participants (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  activity_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  participant_role_code text NOT NULL,
  added_by uuid NOT NULL DEFAULT auth.uid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  attendance_status text NOT NULL DEFAULT 'pending'::text,
  attendance_source text NOT NULL DEFAULT 'system'::text,
  checked_in_at timestamp with time zone,
  attendance_updated_by uuid,
  attendance_updated_at timestamp with time zone,
  attendance_notes text
);

alter table public.activity_participants
  add column if not exists id uuid DEFAULT gen_random_uuid();
alter table public.activity_participants
  alter column id set default gen_random_uuid();
do $$
begin
  if not exists (select 1 from public.activity_participants where id is null) then
    alter table public.activity_participants alter column id set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_participants.id porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_participants
  add column if not exists activity_id uuid;
do $$
begin
  if not exists (select 1 from public.activity_participants where activity_id is null) then
    alter table public.activity_participants alter column activity_id set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_participants.activity_id porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_participants
  add column if not exists profile_id uuid;
do $$
begin
  if not exists (select 1 from public.activity_participants where profile_id is null) then
    alter table public.activity_participants alter column profile_id set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_participants.profile_id porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_participants
  add column if not exists participant_role_code text;
do $$
begin
  if not exists (select 1 from public.activity_participants where participant_role_code is null) then
    alter table public.activity_participants alter column participant_role_code set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_participants.participant_role_code porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_participants
  add column if not exists added_by uuid DEFAULT auth.uid();
alter table public.activity_participants
  alter column added_by set default auth.uid();
do $$
begin
  if not exists (select 1 from public.activity_participants where added_by is null) then
    alter table public.activity_participants alter column added_by set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_participants.added_by porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_participants
  add column if not exists created_at timestamp with time zone DEFAULT now();
alter table public.activity_participants
  alter column created_at set default now();
do $$
begin
  if not exists (select 1 from public.activity_participants where created_at is null) then
    alter table public.activity_participants alter column created_at set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_participants.created_at porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_participants
  add column if not exists updated_at timestamp with time zone DEFAULT now();
alter table public.activity_participants
  alter column updated_at set default now();
do $$
begin
  if not exists (select 1 from public.activity_participants where updated_at is null) then
    alter table public.activity_participants alter column updated_at set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_participants.updated_at porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_participants
  add column if not exists attendance_status text DEFAULT 'pending'::text;
alter table public.activity_participants
  alter column attendance_status set default 'pending'::text;
do $$
begin
  if not exists (select 1 from public.activity_participants where attendance_status is null) then
    alter table public.activity_participants alter column attendance_status set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_participants.attendance_status porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_participants
  add column if not exists attendance_source text DEFAULT 'system'::text;
alter table public.activity_participants
  alter column attendance_source set default 'system'::text;
do $$
begin
  if not exists (select 1 from public.activity_participants where attendance_source is null) then
    alter table public.activity_participants alter column attendance_source set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_participants.attendance_source porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_participants
  add column if not exists checked_in_at timestamp with time zone;
alter table public.activity_participants
  add column if not exists attendance_updated_by uuid;
alter table public.activity_participants
  add column if not exists attendance_updated_at timestamp with time zone;
alter table public.activity_participants
  add column if not exists attendance_notes text;

-- Table: public.activity_statuses
create table if not exists public.activity_statuses (
  code text NOT NULL,
  label text NOT NULL,
  description text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

alter table public.activity_statuses
  add column if not exists code text;
do $$
begin
  if not exists (select 1 from public.activity_statuses where code is null) then
    alter table public.activity_statuses alter column code set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_statuses.code porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_statuses
  add column if not exists label text;
do $$
begin
  if not exists (select 1 from public.activity_statuses where label is null) then
    alter table public.activity_statuses alter column label set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_statuses.label porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_statuses
  add column if not exists description text;
alter table public.activity_statuses
  add column if not exists sort_order integer DEFAULT 0;
alter table public.activity_statuses
  alter column sort_order set default 0;
do $$
begin
  if not exists (select 1 from public.activity_statuses where sort_order is null) then
    alter table public.activity_statuses alter column sort_order set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_statuses.sort_order porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_statuses
  add column if not exists is_active boolean DEFAULT true;
alter table public.activity_statuses
  alter column is_active set default true;
do $$
begin
  if not exists (select 1 from public.activity_statuses where is_active is null) then
    alter table public.activity_statuses alter column is_active set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_statuses.is_active porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_statuses
  add column if not exists created_at timestamp with time zone DEFAULT now();
alter table public.activity_statuses
  alter column created_at set default now();
do $$
begin
  if not exists (select 1 from public.activity_statuses where created_at is null) then
    alter table public.activity_statuses alter column created_at set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_statuses.created_at porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_statuses
  add column if not exists updated_at timestamp with time zone DEFAULT now();
alter table public.activity_statuses
  alter column updated_at set default now();
do $$
begin
  if not exists (select 1 from public.activity_statuses where updated_at is null) then
    alter table public.activity_statuses alter column updated_at set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_statuses.updated_at porque existen valores NULL.';
  end if;
end $$;

-- Table: public.activity_types
create table if not exists public.activity_types (
  code text NOT NULL,
  label text NOT NULL,
  description text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

alter table public.activity_types
  add column if not exists code text;
do $$
begin
  if not exists (select 1 from public.activity_types where code is null) then
    alter table public.activity_types alter column code set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_types.code porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_types
  add column if not exists label text;
do $$
begin
  if not exists (select 1 from public.activity_types where label is null) then
    alter table public.activity_types alter column label set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_types.label porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_types
  add column if not exists description text;
alter table public.activity_types
  add column if not exists sort_order integer DEFAULT 0;
alter table public.activity_types
  alter column sort_order set default 0;
do $$
begin
  if not exists (select 1 from public.activity_types where sort_order is null) then
    alter table public.activity_types alter column sort_order set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_types.sort_order porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_types
  add column if not exists is_active boolean DEFAULT true;
alter table public.activity_types
  alter column is_active set default true;
do $$
begin
  if not exists (select 1 from public.activity_types where is_active is null) then
    alter table public.activity_types alter column is_active set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_types.is_active porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_types
  add column if not exists created_at timestamp with time zone DEFAULT now();
alter table public.activity_types
  alter column created_at set default now();
do $$
begin
  if not exists (select 1 from public.activity_types where created_at is null) then
    alter table public.activity_types alter column created_at set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_types.created_at porque existen valores NULL.';
  end if;
end $$;
alter table public.activity_types
  add column if not exists updated_at timestamp with time zone DEFAULT now();
alter table public.activity_types
  alter column updated_at set default now();
do $$
begin
  if not exists (select 1 from public.activity_types where updated_at is null) then
    alter table public.activity_types alter column updated_at set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.activity_types.updated_at porque existen valores NULL.';
  end if;
end $$;

-- Table: public.attention_categories
create table if not exists public.attention_categories (
  code text NOT NULL,
  label text NOT NULL,
  description text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

alter table public.attention_categories
  add column if not exists code text;
do $$
begin
  if not exists (select 1 from public.attention_categories where code is null) then
    alter table public.attention_categories alter column code set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.attention_categories.code porque existen valores NULL.';
  end if;
end $$;
alter table public.attention_categories
  add column if not exists label text;
do $$
begin
  if not exists (select 1 from public.attention_categories where label is null) then
    alter table public.attention_categories alter column label set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.attention_categories.label porque existen valores NULL.';
  end if;
end $$;
alter table public.attention_categories
  add column if not exists description text;
alter table public.attention_categories
  add column if not exists sort_order integer DEFAULT 0;
alter table public.attention_categories
  alter column sort_order set default 0;
do $$
begin
  if not exists (select 1 from public.attention_categories where sort_order is null) then
    alter table public.attention_categories alter column sort_order set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.attention_categories.sort_order porque existen valores NULL.';
  end if;
end $$;
alter table public.attention_categories
  add column if not exists is_active boolean DEFAULT true;
alter table public.attention_categories
  alter column is_active set default true;
do $$
begin
  if not exists (select 1 from public.attention_categories where is_active is null) then
    alter table public.attention_categories alter column is_active set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.attention_categories.is_active porque existen valores NULL.';
  end if;
end $$;
alter table public.attention_categories
  add column if not exists created_at timestamp with time zone DEFAULT now();
alter table public.attention_categories
  alter column created_at set default now();
do $$
begin
  if not exists (select 1 from public.attention_categories where created_at is null) then
    alter table public.attention_categories alter column created_at set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.attention_categories.created_at porque existen valores NULL.';
  end if;
end $$;
alter table public.attention_categories
  add column if not exists updated_at timestamp with time zone DEFAULT now();
alter table public.attention_categories
  alter column updated_at set default now();
do $$
begin
  if not exists (select 1 from public.attention_categories where updated_at is null) then
    alter table public.attention_categories alter column updated_at set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.attention_categories.updated_at porque existen valores NULL.';
  end if;
end $$;

-- Table: public.divisions
create table if not exists public.divisions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  code text NOT NULL,
  name text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

alter table public.divisions
  add column if not exists id uuid DEFAULT gen_random_uuid();
alter table public.divisions
  alter column id set default gen_random_uuid();
do $$
begin
  if not exists (select 1 from public.divisions where id is null) then
    alter table public.divisions alter column id set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.divisions.id porque existen valores NULL.';
  end if;
end $$;
alter table public.divisions
  add column if not exists code text;
do $$
begin
  if not exists (select 1 from public.divisions where code is null) then
    alter table public.divisions alter column code set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.divisions.code porque existen valores NULL.';
  end if;
end $$;
alter table public.divisions
  add column if not exists name text;
do $$
begin
  if not exists (select 1 from public.divisions where name is null) then
    alter table public.divisions alter column name set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.divisions.name porque existen valores NULL.';
  end if;
end $$;
alter table public.divisions
  add column if not exists created_at timestamp with time zone DEFAULT now();
alter table public.divisions
  alter column created_at set default now();
do $$
begin
  if not exists (select 1 from public.divisions where created_at is null) then
    alter table public.divisions alter column created_at set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.divisions.created_at porque existen valores NULL.';
  end if;
end $$;

-- Table: public.location_types
create table if not exists public.location_types (
  code text NOT NULL,
  label text NOT NULL,
  description text,
  sort_order integer NOT NULL DEFAULT 0
);

alter table public.location_types
  add column if not exists code text;
do $$
begin
  if not exists (select 1 from public.location_types where code is null) then
    alter table public.location_types alter column code set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.location_types.code porque existen valores NULL.';
  end if;
end $$;
alter table public.location_types
  add column if not exists label text;
do $$
begin
  if not exists (select 1 from public.location_types where label is null) then
    alter table public.location_types alter column label set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.location_types.label porque existen valores NULL.';
  end if;
end $$;
alter table public.location_types
  add column if not exists description text;
alter table public.location_types
  add column if not exists sort_order integer DEFAULT 0;
alter table public.location_types
  alter column sort_order set default 0;
do $$
begin
  if not exists (select 1 from public.location_types where sort_order is null) then
    alter table public.location_types alter column sort_order set not null;
  else
    raise notice 'No se aplicó NOT NULL a public.location_types.sort_order porque existen valores NULL.';
  end if;
end $$;

-- ============================================================
-- Indexes
-- ============================================================

-- TODO: Los snapshots disponibles no incluyen índices ni restricciones únicas.
-- Reconciliar con Supabase vivo antes de usar esta baseline para reconstrucción completa.

-- ============================================================
-- Functions
-- ============================================================

-- Function: public.activity_attendance_deadline(uuid)
CREATE OR REPLACE FUNCTION public.activity_attendance_deadline(target_activity_id uuid)
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    (
      (
        coalesce(a.end_date, a.start_date)
        +
        coalesce(a.end_time, a.start_time, time '23:59:59')
      ) at time zone 'America/Mexico_City'
    ) + interval '15 minutes'
  from public.activities a
  where a.id = target_activity_id
    and a.start_date is not null;
$function$

-- Function: public.activity_attendance_open_at(uuid)
CREATE OR REPLACE FUNCTION public.activity_attendance_open_at(target_activity_id uuid)
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    (
      (
        a.start_date
        +
        coalesce(a.start_time, time '00:00:00')
      ) at time zone 'America/Mexico_City'
    ) - interval '15 minutes'
  from public.activities a
  where a.id = target_activity_id
    and a.start_date is not null
    and a.start_time is not null;
$function$

-- Function: public.activity_has_ended(uuid)
CREATE OR REPLACE FUNCTION public.activity_has_ended(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    (
      coalesce(a.end_date, a.start_date)::timestamp
      + coalesce(a.end_time, a.start_time, time '23:59:59')
    ) < (now() at time zone 'America/Mexico_City'),
    false
  )
  from public.activities a
  where a.id = target_activity_id;
$function$

-- Function: public.add_activity_participant(uuid,uuid,text)
CREATE OR REPLACE FUNCTION public.add_activity_participant(target_activity_id uuid, target_profile_id uuid, target_participant_role_code text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  target_program_id uuid;
  participant_program_id uuid;
  participant_person_type text;
begin
  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para agregar participantes a esta actividad.'
      using errcode = '42501';
  end if;

  select a.program_id
  into target_program_id
  from public.activities a
  where a.id = target_activity_id;

  if target_program_id is null then
    raise exception 'La actividad no tiene programa académico asignado.'
      using errcode = 'P0001';
  end if;

  select
    p.primary_program_id,
    p.person_type
  into
    participant_program_id,
    participant_person_type
  from public.profiles p
  where p.id = target_profile_id
    and p.is_active = true;

  if participant_program_id is null then
    raise exception 'El perfil seleccionado no existe, no está activo o no tiene programa asignado.'
      using errcode = 'P0001';
  end if;

  if participant_program_id <> target_program_id then
    raise exception 'La persona seleccionada pertenece a otro programa académico.'
      using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from public.participant_roles pr
    where pr.code = target_participant_role_code
      and pr.is_active = true
  ) then
    raise exception 'El rol de participante seleccionado no es válido.'
      using errcode = 'P0001';
  end if;

  if target_participant_role_code = 'responsible'
     and participant_person_type <> 'worker' then
    raise exception 'Sólo un trabajador puede registrarse como responsable de la actividad.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.activity_participants ap
    where ap.activity_id = target_activity_id
      and ap.profile_id = target_profile_id
  ) then
    raise exception 'Esta persona ya está registrada como participante en la actividad.'
      using errcode = '23505';
  end if;

  insert into public.activity_participants (
    activity_id,
    profile_id,
    participant_role_code,
    added_by
  )
  values (
    target_activity_id,
    target_profile_id,
    target_participant_role_code,
    auth.uid()
  );
end;
$function$

-- Function: public.can_create_activity(text,uuid,uuid,text)
CREATE OR REPLACE FUNCTION public.can_create_activity(target_scope_type text, target_program_id uuid, target_division_id uuid, target_service_type_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.is_active = true
      and (
        public.can_manage_activity(
          target_scope_type,
          target_program_id,
          target_division_id,
          target_service_type_code
        )

        or (
          target_scope_type = 'program'
          and target_program_id = p.primary_program_id
          and public.has_any_active_role(array['professor', 'peer_tutor'])
        )
      )
  );
$function$

-- Function: public.can_create_activity(uuid,text)
CREATE OR REPLACE FUNCTION public.can_create_activity(target_program_id uuid, target_service_type_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    public.has_any_active_role(array[
      'technical_admin',
      'division_tutoring_liaison',
      'division_head',
      'program_head',
      'program_tutoring_lead',
      'program_advising_lead',
      'professor',
      'peer_tutor'
    ])
    or public.can_manage_activity(target_program_id, target_service_type_code);
$function$

-- Function: public.can_delete_activity(uuid)
CREATE OR REPLACE FUNCTION public.can_delete_activity(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.activities a
    where a.id = target_activity_id
      and (
        -- Roles de gestión pueden eliminar si corresponde.
        public.can_manage_activity(
          a.scope_type,
          a.program_id,
          a.division_id,
          a.service_type_code
        )

        or

        -- Responsable / creador normal sólo elimina borradores no ocurridos.
        (
          (
            a.created_by = auth.uid()
            or a.responsible_profile_id = auth.uid()
          )
          and a.status_code = 'draft'
          and not public.activity_has_ended(a.id)
        )
      )
  );
$function$

-- Function: public.can_edit_activity(uuid)
CREATE OR REPLACE FUNCTION public.can_edit_activity(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.activities a
    where a.id = target_activity_id
      and (
        a.created_by = auth.uid()
        or a.responsible_profile_id = auth.uid()
        or public.can_manage_activity(
          a.scope_type,
          a.program_id,
          a.division_id,
          a.service_type_code
        )
      )
  );
$function$

-- Function: public.can_manage_activity(text,uuid,uuid,text)
CREATE OR REPLACE FUNCTION public.can_manage_activity(target_scope_type text, target_program_id uuid, target_division_id uuid, target_service_type_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.role_assignments ra
    where ra.user_id = auth.uid()
      and ra.is_active = true
      and ra.starts_at <= current_date
      and (ra.ends_at is null or ra.ends_at >= current_date)
      and (
        ra.role_code = 'technical_admin'

        or (
          ra.role_code in ('division_tutoring_liaison', 'division_head')
          and ra.scope_type = 'division'
          and ra.division_id = target_division_id
        )

        or (
          target_scope_type = 'program'
          and ra.role_code = 'program_head'
          and ra.program_id = target_program_id
        )

        or (
          target_scope_type = 'program'
          and ra.role_code = 'program_tutoring_lead'
          and ra.program_id = target_program_id
          and target_service_type_code = 'tutoring'
        )

        or (
          target_scope_type = 'program'
          and ra.role_code = 'program_advising_lead'
          and ra.program_id = target_program_id
          and target_service_type_code = 'advising'
        )
      )
  );
$function$

-- Function: public.can_manage_activity(uuid,text)
CREATE OR REPLACE FUNCTION public.can_manage_activity(target_program_id uuid, target_service_type_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.role_assignments ra
    where ra.user_id = auth.uid()
      and ra.is_active = true
      and ra.starts_at <= current_date
      and (ra.ends_at is null or ra.ends_at >= current_date)
      and (
        ra.role_code = 'technical_admin'
        or ra.role_code = 'division_tutoring_liaison'
        or ra.role_code = 'division_head'
        or (
          ra.role_code = 'program_head'
          and ra.program_id = target_program_id
        )
        or (
          ra.role_code = 'program_tutoring_lead'
          and ra.program_id = target_program_id
          and target_service_type_code = 'tutoring'
        )
        or (
          ra.role_code = 'program_advising_lead'
          and ra.program_id = target_program_id
          and target_service_type_code = 'advising'
        )
      )
  );
$function$

-- Function: public.can_read_activity(uuid)
CREATE OR REPLACE FUNCTION public.can_read_activity(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.activities a
    where a.id = target_activity_id
      and (
        a.created_by = auth.uid()
        or a.responsible_profile_id = auth.uid()
        or public.can_manage_activity(
          a.scope_type,
          a.program_id,
          a.division_id,
          a.service_type_code
        )
      )
  );
$function$

-- Function: public.can_update_activity_base(uuid)
CREATE OR REPLACE FUNCTION public.can_update_activity_base(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.activities a
    where a.id = target_activity_id
      and (
        -- Roles de gestión pueden corregir datos base.
        public.can_manage_activity(
          a.scope_type,
          a.program_id,
          a.division_id,
          a.service_type_code
        )

        or

        -- Responsable / creador normal sólo puede editar datos base
        -- mientras siga en borrador y no haya ocurrido.
        (
          (
            a.created_by = auth.uid()
            or a.responsible_profile_id = auth.uid()
          )
          and a.status_code = 'draft'
          and not public.activity_has_ended(a.id)
        )
      )
  );
$function$

-- Function: public.check_in_activity(text)
CREATE OR REPLACE FUNCTION public.check_in_activity(checkin_input text)
 RETURNS TABLE(activity_id uuid, activity_title text, attendance_status text, checked_in_at timestamp with time zone, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  normalized_input text;
  found_token public.activity_checkin_tokens%rowtype;
  participant_id uuid;
  source_value text;
  existing_status text;
  existing_source text;
begin
  perform public.finalize_expired_attendance();

  normalized_input := regexp_replace(
    extensions.unaccent(lower(trim(checkin_input))),
    '\s+',
    '-',
    'g'
  );

  select *
  into found_token
  from public.activity_checkin_tokens t
  where t.is_active = true
    and t.token_type = 'attendance'
    and (t.expires_at is null or t.expires_at > now())
    and (
      t.secret_token = trim(checkin_input)
      or t.code_words = normalized_input
    )
  order by t.opened_at desc
  limit 1;

  if found_token.id is null then
    raise exception 'El código de asistencia no existe o ya fue cerrado.'
      using errcode = 'P0001';
  end if;

  select ap.id, ap.attendance_status, ap.attendance_source
  into participant_id, existing_status, existing_source
  from public.activity_participants ap
  where ap.activity_id = found_token.activity_id
    and ap.profile_id = auth.uid();

  if participant_id is null then
    raise exception 'No estás registrado como participante en esta actividad.'
      using errcode = '42501';
  end if;

  if existing_status = 'attended' then
    return query
    select
      a.id,
      a.title,
      'attended'::text,
      ap.checked_in_at,
      'Tu asistencia ya estaba registrada.'::text
    from public.activities a
    join public.activity_participants ap
      on ap.activity_id = a.id
     and ap.profile_id = auth.uid()
    where a.id = found_token.activity_id;

    return;
  end if;

  if existing_status = 'justified' then
    return query
    select
      a.id,
      a.title,
      existing_status,
      ap.checked_in_at,
      'Tu asistencia está justificada y no puede modificarse con este código.'::text
    from public.activities a
    join public.activity_participants ap
      on ap.activity_id = a.id
     and ap.profile_id = auth.uid()
    where a.id = found_token.activity_id;

    return;
  end if;

  if existing_status = 'absent' and existing_source <> 'system' then
    return query
    select
      a.id,
      a.title,
      existing_status,
      ap.checked_in_at,
      'Tu asistencia ya fue marcada manualmente. Contacta al responsable de la actividad.'::text
    from public.activities a
    join public.activity_participants ap
      on ap.activity_id = a.id
     and ap.profile_id = auth.uid()
    where a.id = found_token.activity_id;

    return;
  end if;

  source_value := case
    when found_token.secret_token = trim(checkin_input) then 'qr'
    else 'code'
  end;

  update public.activity_participants ap
  set
    attendance_status = 'attended',
    attendance_source = source_value,
    checked_in_at = coalesce(ap.checked_in_at, now()),
    attendance_updated_by = auth.uid(),
    attendance_updated_at = now(),
    updated_at = now()
  where ap.id = participant_id;

  return query
  select
    a.id,
    a.title,
    'attended'::text,
    coalesce(ap.checked_in_at, now()),
    'Asistencia registrada correctamente.'::text
  from public.activities a
  join public.activity_participants ap
    on ap.activity_id = a.id
   and ap.profile_id = auth.uid()
  where a.id = found_token.activity_id;
end;
$function$

-- Function: public.close_activity_attendance_checkin(uuid)
CREATE OR REPLACE FUNCTION public.close_activity_attendance_checkin(target_activity_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para cerrar asistencia en esta actividad.'
      using errcode = '42501';
  end if;

  update public.activity_checkin_tokens t
  set
    is_active = false,
    closed_at = now()
  where t.activity_id = target_activity_id
    and t.token_type = 'attendance'
    and t.is_active = true;
end;
$function$

-- Function: public.finalize_expired_attendance()
CREATE OR REPLACE FUNCTION public.finalize_expired_attendance()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  updated_count integer;
begin
  update public.activity_participants ap
  set
    attendance_status = 'absent',
    attendance_source = 'system',
    attendance_updated_by = null,
    attendance_updated_at = now(),
    checked_in_at = null,
    updated_at = now()
  from public.activities a
  where ap.activity_id = a.id
    and ap.attendance_status = 'pending'
    and a.status_code <> 'draft'
    and public.activity_attendance_deadline(a.id) is not null
    and public.activity_attendance_deadline(a.id) <= now();

  get diagnostics updated_count = row_count;

  update public.activity_checkin_tokens t
  set
    is_active = false,
    closed_at = coalesce(t.closed_at, now())
  where t.is_active = true
    and t.token_type = 'attendance'
    and coalesce(t.expires_at, public.activity_attendance_deadline(t.activity_id)) is not null
    and coalesce(t.expires_at, public.activity_attendance_deadline(t.activity_id)) <= now();

  return updated_count;
end;
$function$

-- Function: public.generate_three_word_code()
CREATE OR REPLACE FUNCTION public.generate_three_word_code()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  words text[] := array[
    'sol', 'luna', 'rio', 'nube', 'mesa', 'patio', 'rama', 'luz',
    'casa', 'libro', 'papel', 'azul', 'verde', 'rojo', 'cafe',
    'plaza', 'puerta', 'silla', 'campo', 'flor', 'piedra', 'mar',
    'monte', 'hoja', 'vaso', 'reloj', 'taza', 'cable', 'mapa',
    'canto', 'pluma', 'techo', 'barco', 'foco', 'arena', 'brisa'
  ];
  code text;
begin
  loop
    code :=
      words[1 + floor(random() * array_length(words, 1))::int]
      || '-' ||
      words[1 + floor(random() * array_length(words, 1))::int]
      || '-' ||
      words[1 + floor(random() * array_length(words, 1))::int];

    exit when not exists (
      select 1
      from public.activity_checkin_tokens t
      where t.code_words = code
        and t.is_active = true
    );
  end loop;

  return code;
end;
$function$

-- Function: public.get_academic_period_for_date(date)
CREATE OR REPLACE FUNCTION public.get_academic_period_for_date(target_date date)
 RETURNS TABLE(id uuid, code text, name text, starts_on date, ends_on date)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    ap.id,
    ap.code,
    ap.name,
    ap.starts_on,
    ap.ends_on
  from public.academic_periods ap
  where
    ap.is_active = true
    and ap.starts_on is not null
    and ap.starts_on <= target_date
  order by ap.starts_on desc
  limit 1;
$function$

-- Function: public.get_active_activity_attendance_checkin(uuid)
CREATE OR REPLACE FUNCTION public.get_active_activity_attendance_checkin(target_activity_id uuid)
 RETURNS TABLE(id uuid, activity_id uuid, code_words text, secret_token text, opened_at timestamp with time zone, expires_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  open_at timestamptz;
  natural_deadline timestamptz;
begin
  perform public.finalize_expired_attendance();

  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para consultar el código de asistencia de esta actividad.'
      using errcode = '42501';
  end if;

  open_at := public.activity_attendance_open_at(target_activity_id);
  natural_deadline := public.activity_attendance_deadline(target_activity_id);

  if open_at is null or natural_deadline is null then
    update public.activity_checkin_tokens t
    set
      is_active = false,
      closed_at = coalesce(t.closed_at, now())
    where t.activity_id = target_activity_id
      and t.token_type = 'attendance'
      and t.is_active = true;

    return;
  end if;

  if now() < open_at then
    update public.activity_checkin_tokens t
    set
      is_active = false,
      closed_at = coalesce(t.closed_at, now())
    where t.activity_id = target_activity_id
      and t.token_type = 'attendance'
      and t.is_active = true;

    return;
  end if;

  return query
  select
    t.id,
    t.activity_id,
    t.code_words,
    t.secret_token,
    t.opened_at,
    t.expires_at
  from public.activity_checkin_tokens t
  where t.activity_id = target_activity_id
    and t.token_type = 'attendance'
    and t.is_active = true
    and (t.expires_at is null or t.expires_at > now())
  order by t.opened_at desc
  limit 1;
end;
$function$

-- Function: public.get_activity_attendance_checkin_state(uuid)
CREATE OR REPLACE FUNCTION public.get_activity_attendance_checkin_state(target_activity_id uuid)
 RETURNS TABLE(can_manage boolean, is_draft boolean, has_schedule boolean, has_active_token boolean, can_open_now boolean, window_status text, opens_at timestamp with time zone, ordinary_closes_at timestamp with time zone, active_expires_at timestamp with time zone, message text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_can_edit boolean;
  v_status_code text;
  v_start_ts timestamp;
  v_end_ts timestamp;
  v_current_ts timestamp := now() at time zone 'America/Mexico_City';
  v_open_ts timestamp;
  v_close_ts timestamp;
  v_active_expires_at timestamptz;
  v_has_active_token boolean;
begin
  select
    public.can_edit_activity(a.id),
    a.status_code,
    (a.start_date::timestamp + a.start_time),
    (coalesce(a.end_date, a.start_date)::timestamp + coalesce(a.end_time, a.start_time))
  into
    v_can_edit,
    v_status_code,
    v_start_ts,
    v_end_ts
  from public.activities a
  where a.id = target_activity_id;

  if v_status_code is null then
    raise exception 'La actividad no existe.'
      using errcode = 'P0001';
  end if;

  if not v_can_edit then
    raise exception 'No tienes permiso para consultar la asistencia de esta actividad.'
      using errcode = '42501';
  end if;

  if v_status_code = 'draft' then
    return query select
      v_can_edit,
      true,
      false,
      false,
      false,
      'draft'::text,
      null::timestamptz,
      null::timestamptz,
      null::timestamptz,
      'No puedes abrir asistencia en una actividad en borrador.'::text;
    return;
  end if;

  if v_start_ts is null or v_end_ts is null then
    return query select
      v_can_edit,
      false,
      false,
      false,
      false,
      'missing_schedule'::text,
      null::timestamptz,
      null::timestamptz,
      null::timestamptz,
      'La actividad necesita fecha y horario completos para abrir asistencia.'::text;
    return;
  end if;

  v_open_ts := v_start_ts - interval '15 minutes';
  v_close_ts := v_end_ts + interval '15 minutes';

  select t.expires_at
  into v_active_expires_at
  from public.activity_checkin_tokens t
  where t.activity_id = target_activity_id
    and t.token_type = 'attendance'
    and t.is_active = true
    and (t.expires_at is null or t.expires_at > now())
    and v_current_ts >= v_open_ts
  order by t.opened_at desc
  limit 1;

  v_has_active_token := v_active_expires_at is not null;

  if v_has_active_token then
    return query select
      v_can_edit,
      false,
      true,
      true,
      true,
      'open'::text,
      v_open_ts at time zone 'America/Mexico_City',
      v_close_ts at time zone 'America/Mexico_City',
      v_active_expires_at,
      'La asistencia está abierta.'::text;
    return;
  end if;

  if v_current_ts < v_open_ts then
    return query select
      v_can_edit,
      false,
      true,
      false,
      false,
      'not_yet_available'::text,
      v_open_ts at time zone 'America/Mexico_City',
      v_close_ts at time zone 'America/Mexico_City',
      null::timestamptz,
      'La asistencia podrá abrirse 15 minutos antes del inicio de la actividad.'::text;
    return;
  end if;

  if v_current_ts <= v_close_ts then
    return query select
      v_can_edit,
      false,
      true,
      false,
      true,
      'available'::text,
      v_open_ts at time zone 'America/Mexico_City',
      v_close_ts at time zone 'America/Mexico_City',
      null::timestamptz,
      'Puedes abrir asistencia para esta actividad.'::text;
    return;
  end if;

  return query select
    v_can_edit,
    false,
    true,
    false,
    true,
    'reopen_available'::text,
    v_open_ts at time zone 'America/Mexico_City',
    v_close_ts at time zone 'America/Mexico_City',
    null::timestamptz,
    'La actividad ya terminó. Puedes reabrir asistencia por 15 minutos.'::text;
end;
$function$

-- Function: public.get_activity_participants(uuid)
CREATE OR REPLACE FUNCTION public.get_activity_participants(target_activity_id uuid)
 RETURNS TABLE(id uuid, activity_id uuid, profile_id uuid, participant_role_code text, participant_role_label text, full_name text, email text, person_type text, institutional_id_type text, institutional_id_value text, program_name text, attendance_status text, attendance_source text, checked_in_at timestamp with time zone, attendance_updated_at timestamp with time zone, attendance_notes text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para consultar la lista de participantes de esta actividad.'
      using errcode = '42501';
  end if;

  return query
  select
    ap.id,
    ap.activity_id,
    ap.profile_id,
    ap.participant_role_code,
    pr.label as participant_role_label,
    p.full_name,
    p.email,
    p.person_type,
    p.institutional_id_type,
    p.institutional_id_value,
    prog.name as program_name,
    ap.attendance_status,
    ap.attendance_source,
    ap.checked_in_at,
    ap.attendance_updated_at,
    ap.attendance_notes,
    ap.created_at
  from public.activity_participants ap
  join public.profiles p on p.id = ap.profile_id
  left join public.participant_roles pr on pr.code = ap.participant_role_code
  left join public.academic_programs prog on prog.id = p.primary_program_id
  where ap.activity_id = target_activity_id
  order by p.full_name;
end;
$function$

-- Function: public.get_visible_activity_cards()
CREATE OR REPLACE FUNCTION public.get_visible_activity_cards()
 RETURNS TABLE(id uuid, title text, description text, activity_type_label text, service_type_label text, service_type_code text, modality_label text, status_label text, status_code text, semester_label text, program_label text, location_type_label text, location_detail text, start_date date, start_time time without time zone, end_date date, end_time time without time zone, duration_mode text, responsible_full_name text, viewer_can_edit boolean, viewer_is_participant boolean, viewer_attendance_status text, viewer_attendance_source text, viewer_checked_in_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    a.id,
    a.title,
    a.description,
    at.label as activity_type_label,
    st.label as service_type_label,
    a.service_type_code,
    am.label as modality_label,
    ast.label as status_label,
    a.status_code,
    sem.name as semester_label,
    case
      when a.scope_type = 'division' then 'Ambos programas'
      else ap.name
    end as program_label,
    lt.label as location_type_label,
    a.location_detail,
    a.start_date,
    a.start_time,
    a.end_date,
    a.end_time,
    a.duration_mode,
    coalesce(rp.full_name, 'Responsable sin nombre') as responsible_full_name,
    public.can_edit_activity(a.id) as viewer_can_edit,
    public.is_activity_participant(a.id) as viewer_is_participant,
    viewer_participation.attendance_status as viewer_attendance_status,
    viewer_participation.attendance_source as viewer_attendance_source,
    viewer_participation.checked_in_at as viewer_checked_in_at
  from public.activities a
  left join public.activity_types at on at.code = a.activity_type_code
  left join public.service_types st on st.code = a.service_type_code
  left join public.activity_modalities am on am.code = a.modality_code
  left join public.activity_statuses ast on ast.code = a.status_code
  left join public.academic_periods sem on sem.id = a.academic_period_id
  left join public.academic_programs ap on ap.id = a.program_id
  left join public.location_types lt on lt.code = a.location_type_code
  left join public.profiles rp on rp.id = a.responsible_profile_id
  left join public.activity_participants viewer_participation
    on viewer_participation.activity_id = a.id
   and viewer_participation.profile_id = auth.uid()
  where
    (
      a.status_code = 'draft'
      and a.created_by = auth.uid()
    )
    or
    (
      a.status_code <> 'draft'
      and (
        a.created_by = auth.uid()
        or a.responsible_profile_id = auth.uid()
        or public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)
        or public.is_activity_participant(a.id)
      )
    )
  order by a.start_date desc nulls last, a.start_time desc nulls last, a.created_at desc;
$function$

-- Function: public.has_active_role(text)
CREATE OR REPLACE FUNCTION public.has_active_role(required_role text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.role_assignments ra
    where ra.user_id = auth.uid()
      and ra.role_code = required_role
      and ra.is_active = true
      and ra.starts_at <= current_date
      and (ra.ends_at is null or ra.ends_at >= current_date)
  );
$function$

-- Function: public.has_any_active_role(text[])
CREATE OR REPLACE FUNCTION public.has_any_active_role(required_roles text[])
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.role_assignments ra
    where ra.user_id = auth.uid()
      and ra.role_code = any(required_roles)
      and ra.is_active = true
      and ra.starts_at <= current_date
      and (ra.ends_at is null or ra.ends_at >= current_date)
  );
$function$

-- Function: public.is_activity_participant(uuid)
CREATE OR REPLACE FUNCTION public.is_activity_participant(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.activity_participants ap
    where ap.activity_id = target_activity_id
      and ap.profile_id = auth.uid()
  );
$function$

-- Function: public.open_activity_attendance_checkin(uuid)
CREATE OR REPLACE FUNCTION public.open_activity_attendance_checkin(target_activity_id uuid)
 RETURNS TABLE(id uuid, activity_id uuid, code_words text, secret_token text, opened_at timestamp with time zone, expires_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  new_code text;
  new_id uuid;
  open_at timestamptz;
  natural_deadline timestamptz;
  effective_deadline timestamptz;
begin
  perform public.finalize_expired_attendance();

  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para abrir asistencia en esta actividad.'
      using errcode = '42501';
  end if;

  if exists (
    select 1
    from public.activities a
    where a.id = target_activity_id
      and a.status_code = 'draft'
  ) then
    raise exception 'No puedes abrir asistencia en una actividad en borrador.'
      using errcode = 'P0001';
  end if;

  open_at := public.activity_attendance_open_at(target_activity_id);
  natural_deadline := public.activity_attendance_deadline(target_activity_id);

  if open_at is null or natural_deadline is null then
    raise exception 'La actividad no tiene horario suficiente para abrir asistencia.'
      using errcode = 'P0001';
  end if;

  if now() < open_at then
    raise exception 'La asistencia aún no puede abrirse para esta actividad.'
      using errcode = 'P0001';
  end if;

  effective_deadline := case
    when natural_deadline <= now() then now() + interval '15 minutes'
    else natural_deadline
  end;

  update public.activity_checkin_tokens t
  set
    is_active = false,
    closed_at = now()
  where t.activity_id = target_activity_id
    and t.token_type = 'attendance'
    and t.is_active = true;

  new_code := public.generate_three_word_code();

  insert into public.activity_checkin_tokens (
    activity_id,
    token_type,
    code_words,
    is_active,
    expires_at,
    created_by
  )
  values (
    target_activity_id,
    'attendance',
    new_code,
    true,
    effective_deadline,
    auth.uid()
  )
  returning public.activity_checkin_tokens.id into new_id;

  return query
  select
    t.id,
    t.activity_id,
    t.code_words,
    t.secret_token,
    t.opened_at,
    t.expires_at
  from public.activity_checkin_tokens t
  where t.id = new_id;
end;
$function$

-- Function: public.remove_activity_participant(uuid)
CREATE OR REPLACE FUNCTION public.remove_activity_participant(target_participant_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  target_activity_id uuid;
begin
  select ap.activity_id
  into target_activity_id
  from public.activity_participants ap
  where ap.id = target_participant_id;

  if target_activity_id is null then
    raise exception 'El participante no existe.'
      using errcode = 'P0001';
  end if;

  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para quitar participantes de esta actividad.'
      using errcode = '42501';
  end if;

  delete from public.activity_participants
  where id = target_participant_id;
end;
$function$

-- Function: public.search_profiles_for_participation(uuid,text)
CREATE OR REPLACE FUNCTION public.search_profiles_for_participation(target_activity_id uuid, search_text text)
 RETURNS TABLE(id uuid, full_name text, email text, person_type text, institutional_id_type text, institutional_id_value text, primary_program_id uuid, program_name text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  target_program_id uuid;
begin
  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para buscar participantes para esta actividad.'
      using errcode = '42501';
  end if;

  select a.program_id
  into target_program_id
  from public.activities a
  where a.id = target_activity_id;

  if target_program_id is null then
    raise exception 'La actividad no tiene programa académico asignado.'
      using errcode = 'P0001';
  end if;

  return query
  select
    p.id,
    p.full_name,
    p.email,
    p.person_type,
    p.institutional_id_type,
    p.institutional_id_value,
    p.primary_program_id,
    ap.name as program_name
  from public.profiles p
  left join public.academic_programs ap on ap.id = p.primary_program_id
  where
    p.is_active = true
    and p.primary_program_id = target_program_id
    and length(trim(search_text)) >= 2
    and (
      extensions.unaccent(lower(coalesce(p.full_name, '')))
        like '%' || extensions.unaccent(lower(trim(search_text))) || '%'
      or extensions.unaccent(lower(coalesce(p.email, '')))
        like '%' || extensions.unaccent(lower(trim(search_text))) || '%'
      or extensions.unaccent(lower(coalesce(p.institutional_id_value, '')))
        like '%' || extensions.unaccent(lower(trim(search_text))) || '%'
    )
  order by p.full_name
  limit 20;
end;
$function$

-- Function: public.set_updated_at()
CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$

-- Function: public.update_activity_participant_attendance(uuid,text,text)
CREATE OR REPLACE FUNCTION public.update_activity_participant_attendance(target_participant_id uuid, new_attendance_status text, new_attendance_notes text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  target_activity_id uuid;
begin
  if new_attendance_status not in ('pending', 'attended', 'absent', 'justified') then
    raise exception 'El estado de asistencia no es válido.'
      using errcode = 'P0001';
  end if;

  select ap.activity_id
  into target_activity_id
  from public.activity_participants ap
  where ap.id = target_participant_id;

  if target_activity_id is null then
    raise exception 'El participante no existe.'
      using errcode = 'P0001';
  end if;

  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para modificar la asistencia de esta actividad.'
      using errcode = '42501';
  end if;

  update public.activity_participants
  set
    attendance_status = new_attendance_status,
    attendance_source = 'manual',
    attendance_updated_by = auth.uid(),
    attendance_updated_at = now(),
    attendance_notes = nullif(trim(coalesce(new_attendance_notes, '')), ''),
    checked_in_at = case
      when new_attendance_status = 'attended' then checked_in_at
      else null
    end,
    updated_at = now()
  where id = target_participant_id;
end;
$function$

-- Function: public.update_activity_participants_attendance_bulk(uuid,uuid[],text,text)
CREATE OR REPLACE FUNCTION public.update_activity_participants_attendance_bulk(target_activity_id uuid, target_participant_ids uuid[], new_attendance_status text, new_attendance_notes text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  updated_count integer;
begin
  if new_attendance_status not in ('pending', 'attended', 'absent', 'justified') then
    raise exception 'El estado de asistencia no es válido.'
      using errcode = 'P0001';
  end if;

  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para modificar la asistencia de esta actividad.'
      using errcode = '42501';
  end if;

  if target_participant_ids is null or array_length(target_participant_ids, 1) is null then
    raise exception 'No se seleccionaron participantes.'
      using errcode = 'P0001';
  end if;

  update public.activity_participants ap
  set
    attendance_status = new_attendance_status,
    attendance_source = 'manual',
    attendance_updated_by = auth.uid(),
    attendance_updated_at = now(),
    attendance_notes = nullif(trim(coalesce(new_attendance_notes, '')), ''),
    checked_in_at = case
      when new_attendance_status = 'attended' then coalesce(ap.checked_in_at, now())
      else null
    end,
    updated_at = now()
  where ap.activity_id = target_activity_id
    and ap.id = any(target_participant_ids);

  get diagnostics updated_count = row_count;

  return updated_count;
end;
$function$

-- ============================================================
-- Row Level Security
-- ============================================================

alter table public.academic_periods enable row level security;
alter table public.academic_programs enable row level security;
alter table public.activities enable row level security;
alter table public.activity_modalities enable row level security;
alter table public.activity_participants enable row level security;
alter table public.activity_statuses enable row level security;
alter table public.activity_types enable row level security;
alter table public.attention_categories enable row level security;
alter table public.divisions enable row level security;
alter table public.location_types enable row level security;
-- TODO: La política snapshot menciona public.participant_roles, pero live_columns_snapshot.json no incluyó sus columnas.
-- alter table public.participant_roles enable row level security;
-- TODO: La política snapshot menciona public.profiles, pero live_columns_snapshot.json no incluyó sus columnas.
-- alter table public.profiles enable row level security;
-- TODO: La política snapshot menciona public.role_assignments, pero live_columns_snapshot.json no incluyó sus columnas.
-- alter table public.role_assignments enable row level security;
-- TODO: La política snapshot menciona public.roles, pero live_columns_snapshot.json no incluyó sus columnas.
-- alter table public.roles enable row level security;
-- TODO: La política snapshot menciona public.service_types, pero live_columns_snapshot.json no incluyó sus columnas.
-- alter table public.service_types enable row level security;
-- TODO: La política snapshot menciona public.system_health, pero live_columns_snapshot.json no incluyó sus columnas.
-- alter table public.system_health enable row level security;

-- ============================================================
-- Policies
-- ============================================================

-- Policy: public.academic_periods.Authenticated users can read academic periods
do $$
begin
  if to_regclass('public.academic_periods') is not null then
    execute $baseline$drop policy if exists "Authenticated users can read academic periods" on public.academic_periods;$baseline$;
    execute $baseline$create policy "Authenticated users can read academic periods"
  on public.academic_periods
  as permissive
  for SELECT
  to authenticated
  using (true);$baseline$;
  else
    raise notice 'No se creó la política Authenticated users can read academic periods porque public.academic_periods no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.academic_programs.Authenticated users can read academic programs
do $$
begin
  if to_regclass('public.academic_programs') is not null then
    execute $baseline$drop policy if exists "Authenticated users can read academic programs" on public.academic_programs;$baseline$;
    execute $baseline$create policy "Authenticated users can read academic programs"
  on public.academic_programs
  as permissive
  for SELECT
  to authenticated
  using (true);$baseline$;
  else
    raise notice 'No se creó la política Authenticated users can read academic programs porque public.academic_programs no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.activities.Authorized users can create activities
do $$
begin
  if to_regclass('public.activities') is not null then
    execute $baseline$drop policy if exists "Authorized users can create activities" on public.activities;$baseline$;
    execute $baseline$create policy "Authorized users can create activities"
  on public.activities
  as permissive
  for INSERT
  to authenticated
  with check (((created_by = auth.uid()) AND can_create_activity(scope_type, program_id, division_id, service_type_code)));$baseline$;
  else
    raise notice 'No se creó la política Authorized users can create activities porque public.activities no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.activities.Authorized users can delete activities
do $$
begin
  if to_regclass('public.activities') is not null then
    execute $baseline$drop policy if exists "Authorized users can delete activities" on public.activities;$baseline$;
    execute $baseline$create policy "Authorized users can delete activities"
  on public.activities
  as permissive
  for DELETE
  to authenticated
  using (can_delete_activity(id));$baseline$;
  else
    raise notice 'No se creó la política Authorized users can delete activities porque public.activities no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.activities.Authorized users can update activities
do $$
begin
  if to_regclass('public.activities') is not null then
    execute $baseline$drop policy if exists "Authorized users can update activities" on public.activities;$baseline$;
    execute $baseline$create policy "Authorized users can update activities"
  on public.activities
  as permissive
  for UPDATE
  to authenticated
  using (can_update_activity_base(id))
  with check (can_update_activity_base(id));$baseline$;
  else
    raise notice 'No se creó la política Authorized users can update activities porque public.activities no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.activities.Users can read permitted activities
do $$
begin
  if to_regclass('public.activities') is not null then
    execute $baseline$drop policy if exists "Users can read permitted activities" on public.activities;$baseline$;
    execute $baseline$create policy "Users can read permitted activities"
  on public.activities
  as permissive
  for SELECT
  to authenticated
  using (((created_by = auth.uid()) OR (responsible_profile_id = auth.uid()) OR is_activity_participant(id) OR can_manage_activity(scope_type, program_id, division_id, service_type_code)));$baseline$;
  else
    raise notice 'No se creó la política Users can read permitted activities porque public.activities no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.activity_modalities.Authenticated users can read activity modalities
do $$
begin
  if to_regclass('public.activity_modalities') is not null then
    execute $baseline$drop policy if exists "Authenticated users can read activity modalities" on public.activity_modalities;$baseline$;
    execute $baseline$create policy "Authenticated users can read activity modalities"
  on public.activity_modalities
  as permissive
  for SELECT
  to authenticated
  using (true);$baseline$;
  else
    raise notice 'No se creó la política Authenticated users can read activity modalities porque public.activity_modalities no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.activity_participants.Users can add permitted activity participants
do $$
begin
  if to_regclass('public.activity_participants') is not null then
    execute $baseline$drop policy if exists "Users can add permitted activity participants" on public.activity_participants;$baseline$;
    execute $baseline$create policy "Users can add permitted activity participants"
  on public.activity_participants
  as permissive
  for INSERT
  to authenticated
  with check (can_edit_activity(activity_id));$baseline$;
  else
    raise notice 'No se creó la política Users can add permitted activity participants porque public.activity_participants no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.activity_participants.Users can delete permitted activity participants
do $$
begin
  if to_regclass('public.activity_participants') is not null then
    execute $baseline$drop policy if exists "Users can delete permitted activity participants" on public.activity_participants;$baseline$;
    execute $baseline$create policy "Users can delete permitted activity participants"
  on public.activity_participants
  as permissive
  for DELETE
  to authenticated
  using (can_edit_activity(activity_id));$baseline$;
  else
    raise notice 'No se creó la política Users can delete permitted activity participants porque public.activity_participants no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.activity_participants.Users can read permitted activity participants
do $$
begin
  if to_regclass('public.activity_participants') is not null then
    execute $baseline$drop policy if exists "Users can read permitted activity participants" on public.activity_participants;$baseline$;
    execute $baseline$create policy "Users can read permitted activity participants"
  on public.activity_participants
  as permissive
  for SELECT
  to authenticated
  using (((profile_id = auth.uid()) OR can_read_activity(activity_id)));$baseline$;
  else
    raise notice 'No se creó la política Users can read permitted activity participants porque public.activity_participants no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.activity_participants.Users can update permitted activity participants
do $$
begin
  if to_regclass('public.activity_participants') is not null then
    execute $baseline$drop policy if exists "Users can update permitted activity participants" on public.activity_participants;$baseline$;
    execute $baseline$create policy "Users can update permitted activity participants"
  on public.activity_participants
  as permissive
  for UPDATE
  to authenticated
  using (can_edit_activity(activity_id))
  with check (can_edit_activity(activity_id));$baseline$;
  else
    raise notice 'No se creó la política Users can update permitted activity participants porque public.activity_participants no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.activity_statuses.Authenticated users can read activity statuses
do $$
begin
  if to_regclass('public.activity_statuses') is not null then
    execute $baseline$drop policy if exists "Authenticated users can read activity statuses" on public.activity_statuses;$baseline$;
    execute $baseline$create policy "Authenticated users can read activity statuses"
  on public.activity_statuses
  as permissive
  for SELECT
  to authenticated
  using (true);$baseline$;
  else
    raise notice 'No se creó la política Authenticated users can read activity statuses porque public.activity_statuses no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.activity_types.Authenticated users can read activity types
do $$
begin
  if to_regclass('public.activity_types') is not null then
    execute $baseline$drop policy if exists "Authenticated users can read activity types" on public.activity_types;$baseline$;
    execute $baseline$create policy "Authenticated users can read activity types"
  on public.activity_types
  as permissive
  for SELECT
  to authenticated
  using (true);$baseline$;
  else
    raise notice 'No se creó la política Authenticated users can read activity types porque public.activity_types no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.attention_categories.Authenticated users can read attention categories
do $$
begin
  if to_regclass('public.attention_categories') is not null then
    execute $baseline$drop policy if exists "Authenticated users can read attention categories" on public.attention_categories;$baseline$;
    execute $baseline$create policy "Authenticated users can read attention categories"
  on public.attention_categories
  as permissive
  for SELECT
  to authenticated
  using (true);$baseline$;
  else
    raise notice 'No se creó la política Authenticated users can read attention categories porque public.attention_categories no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.divisions.Authenticated users can read divisions
do $$
begin
  if to_regclass('public.divisions') is not null then
    execute $baseline$drop policy if exists "Authenticated users can read divisions" on public.divisions;$baseline$;
    execute $baseline$create policy "Authenticated users can read divisions"
  on public.divisions
  as permissive
  for SELECT
  to authenticated
  using (true);$baseline$;
  else
    raise notice 'No se creó la política Authenticated users can read divisions porque public.divisions no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.location_types.Authenticated users can read location types
do $$
begin
  if to_regclass('public.location_types') is not null then
    execute $baseline$drop policy if exists "Authenticated users can read location types" on public.location_types;$baseline$;
    execute $baseline$create policy "Authenticated users can read location types"
  on public.location_types
  as permissive
  for SELECT
  to authenticated
  using (true);$baseline$;
  else
    raise notice 'No se creó la política Authenticated users can read location types porque public.location_types no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.participant_roles.Authenticated users can read participant roles
do $$
begin
  if to_regclass('public.participant_roles') is not null then
    execute $baseline$drop policy if exists "Authenticated users can read participant roles" on public.participant_roles;$baseline$;
    execute $baseline$create policy "Authenticated users can read participant roles"
  on public.participant_roles
  as permissive
  for SELECT
  to authenticated
  using (true);$baseline$;
  else
    raise notice 'No se creó la política Authenticated users can read participant roles porque public.participant_roles no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.profiles.Users can read own profile
do $$
begin
  if to_regclass('public.profiles') is not null then
    execute $baseline$drop policy if exists "Users can read own profile" on public.profiles;$baseline$;
    execute $baseline$create policy "Users can read own profile"
  on public.profiles
  as permissive
  for SELECT
  to authenticated
  using ((auth.uid() = id));$baseline$;
  else
    raise notice 'No se creó la política Users can read own profile porque public.profiles no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.profiles.Users can update own basic profile
do $$
begin
  if to_regclass('public.profiles') is not null then
    execute $baseline$drop policy if exists "Users can update own basic profile" on public.profiles;$baseline$;
    execute $baseline$create policy "Users can update own basic profile"
  on public.profiles
  as permissive
  for UPDATE
  to authenticated
  using ((auth.uid() = id))
  with check ((auth.uid() = id));$baseline$;
  else
    raise notice 'No se creó la política Users can update own basic profile porque public.profiles no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.role_assignments.Users can read own role assignments
do $$
begin
  if to_regclass('public.role_assignments') is not null then
    execute $baseline$drop policy if exists "Users can read own role assignments" on public.role_assignments;$baseline$;
    execute $baseline$create policy "Users can read own role assignments"
  on public.role_assignments
  as permissive
  for SELECT
  to authenticated
  using ((auth.uid() = user_id));$baseline$;
  else
    raise notice 'No se creó la política Users can read own role assignments porque public.role_assignments no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.roles.Authenticated users can read roles
do $$
begin
  if to_regclass('public.roles') is not null then
    execute $baseline$drop policy if exists "Authenticated users can read roles" on public.roles;$baseline$;
    execute $baseline$create policy "Authenticated users can read roles"
  on public.roles
  as permissive
  for SELECT
  to authenticated
  using (true);$baseline$;
  else
    raise notice 'No se creó la política Authenticated users can read roles porque public.roles no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.service_types.Authenticated users can read service types
do $$
begin
  if to_regclass('public.service_types') is not null then
    execute $baseline$drop policy if exists "Authenticated users can read service types" on public.service_types;$baseline$;
    execute $baseline$create policy "Authenticated users can read service types"
  on public.service_types
  as permissive
  for SELECT
  to authenticated
  using (true);$baseline$;
  else
    raise notice 'No se creó la política Authenticated users can read service types porque public.service_types no está definido en el snapshot de columnas.';
  end if;
end $$;

-- Policy: public.system_health.Allow public read for system health
do $$
begin
  if to_regclass('public.system_health') is not null then
    execute $baseline$drop policy if exists "Allow public read for system health" on public.system_health;$baseline$;
    execute $baseline$create policy "Allow public read for system health"
  on public.system_health
  as permissive
  for SELECT
  to anon
  using (true);$baseline$;
  else
    raise notice 'No se creó la política Allow public read for system health porque public.system_health no está definido en el snapshot de columnas.';
  end if;
end $$;

-- ============================================================
-- Grants
-- ============================================================

-- TODO: Los snapshots disponibles no incluyen privilegios GRANT/REVOKE.
-- Reconciliar permisos de ejecución de funciones y acceso a tablas contra Supabase vivo.

-- ============================================================
-- Notes / TODOs
-- ============================================================

-- TODO: Capturar y reconciliar primary keys, foreign keys, check constraints, unique constraints,
-- índices, triggers y grants. Las consultas snapshot actuales sólo cubren columnas,
-- funciones y políticas RLS.
-- TODO: Capturar datos semilla mínimos de catálogos operativos si deben formar parte
-- de una reconstrucción reproducible.
-- TODO: Las siguientes tablas aparecen en políticas RLS pero no en live_columns_snapshot.json:
-- - public.participant_roles
-- - public.profiles
-- - public.role_assignments
-- - public.roles
-- - public.service_types
-- - public.system_health

commit;
