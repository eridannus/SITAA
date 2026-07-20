-- SITAA 0007: directorio administrativo de sólo lectura y auditoría administrativa.
-- Requiere revisión y aplicación manual coordinada. No contiene datos de prueba.

begin;

-- Preflight bloqueante: contrato post-0006 y ausencia total de objetos 0007.
do $preflight$
declare
  missing_columns integer;
begin
  if to_regclass('public.profiles') is null
     or to_regclass('public.roles') is null
     or to_regclass('public.role_assignments') is null
     or to_regclass('public.academic_programs') is null
     or to_regclass('public.divisions') is null
     or to_regclass('auth.users') is null
     or to_regclass('auth.identities') is null then
    raise exception 'sitaa_0007_missing_post_0006_tables' using errcode = 'P0001';
  end if;

  select count(*) into missing_columns
  from (values
    ('profiles','id','uuid'), ('profiles','email','text'), ('profiles','full_name','text'),
    ('profiles','primary_program_id','uuid'), ('profiles','is_active','boolean'),
    ('profiles','created_at','timestamp with time zone'), ('profiles','updated_at','timestamp with time zone'),
    ('profiles','first_names','text'), ('profiles','paternal_surname','text'),
    ('profiles','maternal_surname','text'), ('profiles','person_type','text'),
    ('profiles','institutional_id_type','text'), ('profiles','institutional_id_value','text'),
    ('profiles','account_kind','text'), ('profiles','account_status','text'),
    ('profiles','activated_at','timestamp with time zone'), ('profiles','deactivated_at','timestamp with time zone'),
    ('roles','code','text'), ('roles','label','text'), ('roles','description','text'), ('roles','sort_order','integer'),
    ('role_assignments','id','uuid'), ('role_assignments','user_id','uuid'),
    ('role_assignments','role_code','text'), ('role_assignments','scope_type','text'),
    ('role_assignments','service_area','text'), ('role_assignments','division_id','uuid'),
    ('role_assignments','program_id','uuid'), ('role_assignments','starts_at','date'),
    ('role_assignments','ends_at','date'), ('role_assignments','is_active','boolean'),
    ('role_assignments','assigned_by','uuid'), ('role_assignments','created_at','timestamp with time zone'),
    ('role_assignments','updated_at','timestamp with time zone'),
    ('academic_programs','id','uuid'), ('academic_programs','name','text'),
    ('divisions','id','uuid'), ('divisions','name','text')
  ) expected(table_name, column_name, data_type)
  where not exists (
    select 1 from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = expected.table_name
      and c.column_name = expected.column_name
      and c.data_type = expected.data_type
  );
  if missing_columns > 0 then
    raise exception 'sitaa_0007_missing_post_0006_columns' using errcode = 'P0001';
  end if;

  if (select count(*) from pg_roles where rolname in ('anon','authenticated','service_role')) <> 3 then
    raise exception 'sitaa_0007_missing_database_roles' using errcode = 'P0001';
  end if;
  if not exists (
    select 1 from pg_roles where rolname = 'service_role' and rolbypassrls = true
  ) then
    raise exception 'sitaa_0007_unexpected_service_role_contract' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.roles r where r.code = 'technical_admin') then
    raise exception 'sitaa_0007_missing_technical_admin_role' using errcode = 'P0001';
  end if;
  if to_regprocedure('public.handle_sitaa_auth_user_created()') is null
     or to_regprocedure('public.normalize_sitaa_profile_names()') is null
     or to_regprocedure('public.complete_own_google_registration(text,text,text,text,text,uuid)') is null
     or not exists (
       select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
       join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relname = 'profiles'
         and t.tgname in ('enforce_sitaa_profile_identity','normalize_sitaa_profile_names')
         and not t.tgisinternal
       group by c.oid having count(*) = 2
     ) then
    raise exception 'sitaa_0007_missing_post_0006_functions_or_triggers' using errcode = 'P0001';
  end if;
  if to_regprocedure('extensions.unaccent(text)') is null then
    raise exception 'sitaa_0007_missing_verified_unaccent' using errcode = 'P0001';
  end if;
  if exists (
       select 1 from information_schema.columns
       where table_schema = 'public' and table_name = 'roles' and column_name in ('id','is_active')
     )
     or exists (
       select 1 from information_schema.columns
       where table_schema = 'public' and table_name = 'role_assignments'
         and column_name in ('status','revoked_by','revoked_at','administrative_notes')
     )
     or not exists (
       select 1 from pg_constraint
       where conrelid = 'public.roles'::regclass and contype = 'p'
         and pg_get_constraintdef(oid) = 'PRIMARY KEY (code)'
     ) then
    raise exception 'sitaa_0007_unexpected_v1_role_shape' using errcode = 'P0001';
  end if;

  if exists (select 1 from public.profiles p left join auth.users u on u.id = p.id where u.id is null)
     or exists (select 1 from auth.users u left join public.profiles p on p.id = u.id where p.id is null) then
    raise exception 'sitaa_0007_auth_profile_one_to_one_drift' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.role_assignments ra
    left join public.profiles p on p.id = ra.user_id
    left join public.roles r on r.code = ra.role_code
    left join public.divisions d on d.id = ra.division_id
    left join public.academic_programs ap on ap.id = ra.program_id
    left join auth.users au on au.id = ra.assigned_by
    where p.id is null or r.code is null
       or (ra.division_id is not null and d.id is null)
       or (ra.program_id is not null and ap.id is null)
       or (ra.assigned_by is not null and au.id is null)
  ) then
    raise exception 'sitaa_0007_role_assignment_integrity_drift' using errcode = 'P0001';
  end if;

  if to_regclass('public.admin_audit_events') is not null
     or exists (
       select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.proname in (
         'sitaa_current_mexico_date', 'is_b1_account_admin', 'admin_audit_metadata_is_safe',
         'prevent_admin_audit_event_mutation', 'search_admin_accounts_b1',
         'get_admin_account_detail_b1', 'get_admin_account_assignments_b1',
         'get_admin_account_audit_history_b1'
       )
     )
     or exists (
       select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
       join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and t.tgname in ('prevent_admin_audit_event_mutation','prevent_admin_audit_event_truncate')
     )
     or exists (
       select 1 from pg_policies
       where schemaname = 'public' and tablename = 'admin_audit_events'
     )
     or to_regclass('public.admin_audit_events_target_occurred_idx') is not null
     or to_regclass('public.admin_audit_events_actor_occurred_idx') is not null
     or to_regclass('public.profiles_admin_directory_sort_idx') is not null
     or to_regclass('public.profiles_admin_directory_filters_idx') is not null then
    raise exception 'sitaa_0007_conflicting_objects' using errcode = 'P0001';
  end if;

  if not exists (
       select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles'
       and policyname = 'Users can read own profile' and cmd = 'SELECT'
       and roles = array['authenticated']::name[] and qual = '(auth.uid() = id)'
     )
     or not exists (
       select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles'
       and policyname = 'Users can update own basic profile' and cmd = 'UPDATE'
       and roles = array['authenticated']::name[]
       and qual = '(auth.uid() = id)' and with_check = '(auth.uid() = id)'
     )
     or not exists (
       select 1 from pg_policies where schemaname = 'public' and tablename = 'role_assignments'
       and policyname = 'Users can read own role assignments' and cmd = 'SELECT'
       and roles = array['authenticated']::name[] and qual = '(auth.uid() = user_id)'
     )
     or (select count(*) from pg_policies where schemaname = 'public' and tablename = 'profiles') <> 2
     or (select count(*) from pg_policies where schemaname = 'public' and tablename = 'role_assignments') <> 1
     or not exists (
       select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relname = 'profiles' and c.relrowsecurity
     )
     or not exists (
       select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relname = 'role_assignments' and c.relrowsecurity
     )
     or not has_table_privilege('authenticated', 'public.profiles', 'SELECT')
     or not has_table_privilege('authenticated', 'public.role_assignments', 'SELECT')
     or has_table_privilege('authenticated', 'public.profiles', 'UPDATE')
     or not has_column_privilege('authenticated', 'public.profiles', 'first_names', 'UPDATE')
     or not has_column_privilege('authenticated', 'public.profiles', 'paternal_surname', 'UPDATE')
     or not has_column_privilege('authenticated', 'public.profiles', 'maternal_surname', 'UPDATE')
     or exists (
       select 1 from pg_attribute a
       where a.attrelid = 'public.profiles'::regclass and a.attnum > 0 and not a.attisdropped
         and a.attname not in ('first_names','paternal_surname','maternal_surname')
         and has_column_privilege('authenticated', 'public.profiles', a.attname, 'UPDATE')
     )
     or exists (
       select 1 from pg_attribute a
       where a.attrelid = 'public.profiles'::regclass and a.attnum > 0 and not a.attisdropped
         and (has_column_privilege('authenticated','public.profiles',a.attname,'INSERT')
           or has_column_privilege('authenticated','public.profiles',a.attname,'REFERENCES'))
     )
     or has_table_privilege('authenticated', 'public.profiles', 'INSERT')
     or has_table_privilege('authenticated', 'public.profiles', 'DELETE')
     or has_table_privilege('authenticated', 'public.profiles', 'TRUNCATE')
     or has_table_privilege('authenticated', 'public.profiles', 'REFERENCES')
     or has_table_privilege('authenticated', 'public.profiles', 'TRIGGER')
     or exists (
       select 1
       from pg_class c
       cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) acl
       where c.oid = 'public.profiles'::regclass
         and acl.grantee = (select oid from pg_roles where rolname = 'authenticated')
         and upper(acl.privilege_type) = 'MAINTAIN'
     )
     or has_table_privilege('authenticated', 'public.role_assignments', 'INSERT')
     or has_table_privilege('authenticated', 'public.role_assignments', 'UPDATE')
     or has_table_privilege('authenticated', 'public.role_assignments', 'DELETE')
     or has_table_privilege('authenticated', 'public.role_assignments', 'TRUNCATE')
     or has_table_privilege('authenticated', 'public.role_assignments', 'REFERENCES')
     or has_table_privilege('authenticated', 'public.role_assignments', 'TRIGGER')
     or exists (
       select 1 from pg_attribute a
       where a.attrelid = 'public.role_assignments'::regclass and a.attnum > 0 and not a.attisdropped
         and (has_column_privilege('authenticated','public.role_assignments',a.attname,'INSERT')
           or has_column_privilege('authenticated','public.role_assignments',a.attname,'UPDATE')
           or has_column_privilege('authenticated','public.role_assignments',a.attname,'REFERENCES'))
     )
     or exists (
       select 1
       from pg_class c
       cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) acl
       where c.oid = 'public.role_assignments'::regclass
         and acl.grantee = (select oid from pg_roles where rolname = 'authenticated')
         and upper(acl.privilege_type) = 'MAINTAIN'
     )
     or exists (
       select 1
       from pg_class c
       cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) acl
       where c.oid in ('public.profiles'::regclass, 'public.role_assignments'::regclass)
         and (acl.grantee = 0 or acl.grantee = (select oid from pg_roles where rolname = 'anon'))
     )
     or exists (
       select 1 from information_schema.column_privileges cp
       where cp.table_schema='public' and cp.table_name in ('profiles','role_assignments')
         and cp.grantee in ('anon','PUBLIC')
     ) then
    raise exception 'sitaa_0007_client_rls_or_grant_drift' using errcode = 'P0001';
  end if;
end;
$preflight$;

-- Fecha calendario institucional, independiente de la zona horaria de la sesión.
create function public.sitaa_current_mexico_date()
returns date
language sql
stable
security invoker
set search_path = pg_catalog
as $function$
  select (current_timestamp at time zone 'America/Mexico_City')::date;
$function$;
revoke all on function public.sitaa_current_mexico_date()
  from public, anon, authenticated, service_role;

-- Autorización privada exacta de Fase B.1.
create function public.is_b1_account_admin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $function$
  select exists (
    select 1
    from public.profiles p
    join public.role_assignments ra on ra.user_id = p.id
    where p.id = auth.uid()
      and p.account_status = 'active'
      and p.is_active = true
      and ra.role_code = 'technical_admin'
      and ra.scope_type = 'system'
      and ra.service_area = 'technical'
      and ra.program_id is null
      and ra.division_id is null
      and ra.is_active = true
      and ra.starts_at <= public.sitaa_current_mexico_date()
      and (ra.ends_at is null or ra.ends_at >= public.sitaa_current_mexico_date())
  );
$function$;
revoke all on function public.is_b1_account_admin() from public, anon, authenticated;

create function public.admin_audit_metadata_is_safe(candidate jsonb)
returns boolean
language sql
immutable
security invoker
set search_path = pg_catalog, public
as $function$
  select case
    when candidate is null or jsonb_typeof(candidate) <> 'object'
      or octet_length(candidate::text) > 16384 then false
    else not exists (
      select 1 from jsonb_object_keys(candidate) as key_name
      where regexp_replace(lower(key_name), '[^a-z0-9]+', '', 'g')
        ~ '(password|passwd|token|cookie|secret|authorization|credential|recovery|session|bearer|apikey)'
    )
  end;
$function$;
revoke all on function public.admin_audit_metadata_is_safe(jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_audit_metadata_is_safe(jsonb)
  to service_role;

-- Bitácora append-only. Fase B.1 no inserta eventos desde la aplicación.
create table public.admin_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_profile_id uuid not null references public.profiles(id) on delete restrict,
  target_profile_id uuid not null references public.profiles(id) on delete restrict,
  action_code text not null,
  outcome text not null,
  reason text null,
  role_assignment_id uuid null references public.role_assignments(id) on delete restrict,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  constraint admin_audit_events_action_code_check check (
    char_length(action_code) between 1 and 100
    and action_code ~ '^[a-z][a-z0-9]*(_[a-z0-9]+)*$'
  ),
  constraint admin_audit_events_outcome_check check (outcome in ('success', 'failure')),
  constraint admin_audit_events_reason_check check (
    reason is null or (reason = btrim(reason) and char_length(reason) between 1 and 1000)
  ),
  constraint admin_audit_events_metadata_check check (public.admin_audit_metadata_is_safe(metadata))
);

create index admin_audit_events_target_occurred_idx
  on public.admin_audit_events (target_profile_id, occurred_at desc, id desc);
create index admin_audit_events_actor_occurred_idx
  on public.admin_audit_events (actor_profile_id, occurred_at desc, id desc);

alter table public.admin_audit_events enable row level security;
revoke all on table public.admin_audit_events from public, anon, authenticated, service_role;
grant select, insert on table public.admin_audit_events to service_role;

create function public.prevent_admin_audit_event_mutation()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
begin
  raise exception 'sitaa_admin_audit_is_append_only' using errcode = '55000';
end;
$function$;
revoke all on function public.prevent_admin_audit_event_mutation() from public, anon, authenticated;

create trigger prevent_admin_audit_event_mutation
before update or delete on public.admin_audit_events
for each row execute function public.prevent_admin_audit_event_mutation();

create trigger prevent_admin_audit_event_truncate
before truncate on public.admin_audit_events
for each statement execute function public.prevent_admin_audit_event_mutation();

create index profiles_admin_directory_sort_idx
  on public.profiles (paternal_surname, maternal_surname, first_names, id);
create index profiles_admin_directory_filters_idx
  on public.profiles (account_status, account_kind, person_type, primary_program_id);

-- RPC 1: búsqueda, filtrado y paginación minimizada.
create function public.search_admin_accounts_b1(
  search_text text default null,
  program_filter uuid default null,
  account_kind_filter text default null,
  account_status_filter text default null,
  person_type_filter text default null,
  role_code_filter text default null,
  service_area_filter text default null,
  scope_type_filter text default null,
  page_number integer default 1,
  page_size integer default 20
)
returns table (
  profile_id uuid,
  first_names text,
  paternal_surname text,
  maternal_surname text,
  full_name text,
  email text,
  account_kind text,
  account_status text,
  person_type text,
  primary_program_id uuid,
  primary_program_name text,
  institutional_id_type text,
  masked_institutional_id text,
  current_assignment_count bigint,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, extensions
as $function$
declare
  normalized_query text := nullif(regexp_replace(btrim(search_text), '\s+', ' ', 'g'), '');
  escaped_query text;
  search_pattern text;
  calculated_offset bigint;
begin
  if not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode = '42501';
  end if;
  if normalized_query is not null and (char_length(normalized_query) < 2 or char_length(normalized_query) > 200) then
    raise exception 'sitaa_admin_invalid_search_length' using errcode = '22023';
  end if;
  if page_number is null or page_number < 1 or page_number > 1000000
     or page_size is null or page_size < 1 or page_size > 50 then
    raise exception 'sitaa_admin_invalid_pagination' using errcode = '22023';
  end if;
  calculated_offset := (page_number::bigint - 1) * page_size::bigint;
  if account_kind_filter is not null and account_kind_filter not in ('institutional','technical')
     or account_status_filter is not null and account_status_filter not in ('pending_registration','active','inactive')
     or person_type_filter is not null and person_type_filter not in ('student','professor')
     or service_area_filter is not null and service_area_filter not in ('tutoring','advising','both','logistics','technical')
     or scope_type_filter is not null and scope_type_filter not in ('own','program','division','system') then
    raise exception 'sitaa_admin_invalid_filter' using errcode = '22023';
  end if;
  if program_filter is not null and not exists (select 1 from public.academic_programs ap where ap.id = program_filter)
     or role_code_filter is not null and not exists (select 1 from public.roles r where r.code = role_code_filter) then
    raise exception 'sitaa_admin_unknown_filter' using errcode = '22023';
  end if;

  if normalized_query is null and program_filter is null and account_kind_filter is null
     and account_status_filter is null and person_type_filter is null and role_code_filter is null
     and service_area_filter is null and scope_type_filter is null then
    return;
  end if;

  if normalized_query is not null then
    escaped_query := replace(normalized_query, E'\\', E'\\\\');
    escaped_query := replace(escaped_query, '%', E'\\%');
    escaped_query := replace(escaped_query, '_', E'\\_');
    search_pattern := '%' || extensions.unaccent(lower(escaped_query)) || '%';
  end if;

  return query
  select p.id, p.first_names, p.paternal_surname, p.maternal_surname,
    p.full_name, p.email, p.account_kind, p.account_status, p.person_type,
    p.primary_program_id, ap.name, p.institutional_id_type,
    case
      when p.institutional_id_value is null then null
      when char_length(p.institutional_id_value) <= 4 then repeat('•', char_length(p.institutional_id_value))
      else repeat('•', char_length(p.institutional_id_value) - 4) || right(p.institutional_id_value, 4)
    end,
    (
      select count(*) from public.role_assignments current_ra
      where current_ra.user_id = p.id and current_ra.is_active = true
        and current_ra.starts_at <= public.sitaa_current_mexico_date()
        and (current_ra.ends_at is null or current_ra.ends_at >= public.sitaa_current_mexico_date())
    ),
    count(*) over()
  from public.profiles p
  left join public.academic_programs ap on ap.id = p.primary_program_id
  where (program_filter is null or p.primary_program_id = program_filter)
    and (account_kind_filter is null or p.account_kind = account_kind_filter)
    and (account_status_filter is null or p.account_status = account_status_filter)
    and (person_type_filter is null or p.person_type = person_type_filter)
    and (
      normalized_query is null
      or extensions.unaccent(lower(concat_ws(' ', p.first_names, p.paternal_surname, p.maternal_surname, p.full_name))) like search_pattern escape E'\\'
      or lower(p.email) like search_pattern escape E'\\'
      or p.institutional_id_value like search_pattern escape E'\\'
    )
    and (
      (role_code_filter is null and service_area_filter is null and scope_type_filter is null)
      or exists (
        select 1 from public.role_assignments filtered_ra
        where filtered_ra.user_id = p.id and filtered_ra.is_active = true
          and filtered_ra.starts_at <= public.sitaa_current_mexico_date()
          and (filtered_ra.ends_at is null or filtered_ra.ends_at >= public.sitaa_current_mexico_date())
          and (role_code_filter is null or filtered_ra.role_code = role_code_filter)
          and (service_area_filter is null or filtered_ra.service_area = service_area_filter)
          and (scope_type_filter is null or filtered_ra.scope_type = scope_type_filter)
      )
    )
  order by p.paternal_surname asc nulls last, p.maternal_surname asc nulls last,
    p.first_names asc nulls last, p.id
  limit page_size offset calculated_offset;
end;
$function$;

-- RPC 2: identidad completa autorizada y resumen Auth mínimo.
create function public.get_admin_account_detail_b1(target_profile_id uuid)
returns table (
  profile_id uuid, first_names text, paternal_surname text, maternal_surname text,
  full_name text, email text, account_kind text, account_status text, person_type text,
  institutional_id_type text, institutional_id_value text, primary_program_id uuid,
  primary_program_name text, activated_at timestamptz, deactivated_at timestamptz,
  auth_email_confirmed boolean
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
begin
  if not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode = '42501';
  end if;
  return query
  select p.id, p.first_names, p.paternal_surname, p.maternal_surname,
    p.full_name, p.email, p.account_kind, p.account_status, p.person_type,
    p.institutional_id_type, p.institutional_id_value, p.primary_program_id,
    ap.name, p.activated_at, p.deactivated_at,
    (
      u.email_confirmed_at is not null
      or exists (
        select 1 from auth.identities identity_row
        where identity_row.user_id = u.id
          and identity_row.provider = 'google'
          and lower(btrim(identity_row.identity_data ->> 'email')) = lower(btrim(u.email))
          and lower(btrim(coalesce(identity_row.identity_data ->> 'email_verified', ''))) in ('true','t','1')
      )
    )
  from public.profiles p
  join auth.users u on u.id = p.id
  left join public.academic_programs ap on ap.id = p.primary_program_id
  where p.id = target_profile_id;
end;
$function$;

-- RPC 3: filas V1 sin inventar revocación o estados de Fase C.
create function public.get_admin_account_assignments_b1(target_profile_id uuid)
returns table (
  id uuid, role_code text, role_label text, scope_type text, service_area text,
  division_id uuid, division_name text, program_id uuid, program_name text,
  starts_at date, ends_at date, is_active boolean, assigned_by uuid,
  created_at timestamptz, presentation_status text
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $function$
begin
  if not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode = '42501';
  end if;
  return query
  select ra.id, ra.role_code, r.label, ra.scope_type, ra.service_area,
    ra.division_id, d.name, ra.program_id, ap.name, ra.starts_at, ra.ends_at,
    ra.is_active, ra.assigned_by, ra.created_at,
    case
      when not ra.is_active then 'inactive'
      when ra.starts_at > public.sitaa_current_mexico_date() then 'future'
      when ra.ends_at is not null and ra.ends_at < public.sitaa_current_mexico_date() then 'expired'
      when p.account_status <> 'active' then 'suspended_by_account_status'
      else 'current'
    end
  from public.role_assignments ra
  join public.profiles p on p.id = ra.user_id
  join public.roles r on r.code = ra.role_code
  left join public.divisions d on d.id = ra.division_id
  left join public.academic_programs ap on ap.id = ra.program_id
  where ra.user_id = target_profile_id
  order by ra.created_at desc, ra.id desc;
end;
$function$;

-- RPC 4: bitácora sanitizada; metadata nunca se devuelve en B.1.
create function public.get_admin_account_audit_history_b1(
  requested_profile_id uuid,
  result_limit integer default 50,
  result_offset integer default 0
)
returns table (
  id uuid, actor_profile_id uuid, actor_display_name text, target_profile_id uuid,
  action_code text, outcome text, reason text, role_assignment_id uuid,
  occurred_at timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $function$
begin
  if not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode = '42501';
  end if;
  if result_limit is null or result_limit < 1 or result_limit > 50
     or result_offset is null or result_offset < 0 or result_offset > 1000000 then
    raise exception 'sitaa_admin_invalid_audit_pagination' using errcode = '22023';
  end if;
  return query
  select e.id, e.actor_profile_id, actor.full_name, e.target_profile_id,
    e.action_code, e.outcome, e.reason, e.role_assignment_id, e.occurred_at
  from public.admin_audit_events e
  left join public.profiles actor on actor.id = e.actor_profile_id
  where e.target_profile_id = requested_profile_id
  order by e.occurred_at desc, e.id desc
  limit result_limit offset result_offset;
end;
$function$;

revoke all on function public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer) from public, anon, authenticated;
revoke all on function public.get_admin_account_detail_b1(uuid) from public, anon, authenticated;
revoke all on function public.get_admin_account_assignments_b1(uuid) from public, anon, authenticated;
revoke all on function public.get_admin_account_audit_history_b1(uuid,integer,integer) from public, anon, authenticated;

grant execute on function public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer) to authenticated;
grant execute on function public.get_admin_account_detail_b1(uuid) to authenticated;
grant execute on function public.get_admin_account_assignments_b1(uuid) to authenticated;
grant execute on function public.get_admin_account_audit_history_b1(uuid,integer,integer) to authenticated;

commit;
