-- Preflight 0007: sólo lectura, sin PII ni filas operativas.
begin;
set local transaction read only;

select category, classification, issue_count
from (
  select 'post_0006_tables'::text as category, 'blocking'::text as classification,
    count(*)::bigint as issue_count
  from (values ('public.profiles'), ('public.roles'), ('public.role_assignments'),
    ('public.academic_programs'), ('public.divisions'), ('auth.users')) expected(object_name)
  where to_regclass(expected.object_name) is null

  union all
  select 'post_0006_columns', 'blocking', count(*)::bigint
  from (values
    ('profiles','id'), ('profiles','email'), ('profiles','first_names'),
    ('profiles','paternal_surname'), ('profiles','maternal_surname'),
    ('profiles','full_name'), ('profiles','account_kind'), ('profiles','account_status'),
    ('profiles','person_type'), ('profiles','institutional_id_type'),
    ('profiles','institutional_id_value'), ('profiles','primary_program_id'),
    ('profiles','activated_at'), ('profiles','deactivated_at'),
    ('role_assignments','id'), ('role_assignments','user_id'),
    ('role_assignments','role_code'), ('role_assignments','scope_type'),
    ('role_assignments','service_area'), ('role_assignments','division_id'),
    ('role_assignments','program_id'), ('role_assignments','starts_at'),
    ('role_assignments','ends_at'), ('role_assignments','is_active'),
    ('role_assignments','assigned_by'), ('role_assignments','created_at')
  ) expected(table_name, column_name)
  where not exists (
    select 1 from information_schema.columns c
    where c.table_schema = 'public' and c.table_name = expected.table_name
      and c.column_name = expected.column_name
  )

  union all
  select 'technical_admin_catalog', 'blocking',
    case when exists (select 1 from public.roles where code = 'technical_admin') then 0 else 1 end

  union all
  select 'post_0006_functions_triggers', 'blocking',
    (case when to_regprocedure('public.handle_sitaa_auth_user_created()') is null then 1 else 0 end
      + case when to_regprocedure('public.normalize_sitaa_profile_names()') is null then 1 else 0 end
      + case when to_regprocedure('public.complete_own_google_registration(text,text,text,text,text,uuid)') is null then 1 else 0 end
      + case when exists (
          select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
          join pg_namespace n on n.oid = c.relnamespace
          where n.nspname = 'public' and c.relname = 'profiles'
            and t.tgname in ('enforce_sitaa_profile_identity','normalize_sitaa_profile_names')
            and not t.tgisinternal
          group by c.oid having count(*) = 2
        ) then 0 else 1 end)::bigint

  union all
  select 'verified_unaccent', 'blocking',
    case when exists (select 1 from pg_extension where extname = 'unaccent') then 0 else 1 end

  union all
  select 'auth_profile_one_to_one', 'blocking',
    (select count(*) from public.profiles p left join auth.users u on u.id = p.id where u.id is null)
    + (select count(*) from auth.users u left join public.profiles p on p.id = u.id where p.id is null)

  union all
  select 'role_assignment_foreign_keys', 'blocking', count(*)::bigint
  from public.role_assignments ra
  left join public.profiles p on p.id = ra.user_id
  left join public.roles r on r.code = ra.role_code
  left join public.divisions d on d.id = ra.division_id
  left join public.academic_programs ap on ap.id = ra.program_id
  left join auth.users au on au.id = ra.assigned_by
  where p.id is null or r.code is null
    or (ra.division_id is not null and d.id is null)
    or (ra.program_id is not null and ap.id is null)
    or (ra.assigned_by is not null and au.id is null)

  union all
  select 'conflicting_0007_table', 'blocking',
    case when to_regclass('public.admin_audit_events') is null then 0 else 1 end

  union all
  select 'conflicting_0007_functions', 'blocking', count(*)::bigint
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname in (
    'is_b1_account_admin', 'admin_audit_metadata_is_safe',
    'prevent_admin_audit_event_mutation', 'search_admin_accounts_b1',
    'get_admin_account_detail_b1', 'get_admin_account_assignments_b1',
    'get_admin_account_audit_history_b1'
  )

  union all
  select 'conflicting_0007_triggers_policies', 'blocking',
    (select count(*) from pg_trigger where tgname = 'prevent_admin_audit_event_mutation' and not tgisinternal)
    + (select count(*) from pg_policies where schemaname = 'public' and tablename = 'admin_audit_events')

  union all
  select 'conflicting_0007_indexes', 'blocking', count(*)::bigint
  from (values
    ('public.admin_audit_events_target_occurred_idx'),
    ('public.admin_audit_events_actor_occurred_idx'),
    ('public.profiles_admin_directory_sort_idx'),
    ('public.profiles_admin_directory_filters_idx')
  ) expected(object_name)
  where to_regclass(expected.object_name) is not null

  union all
  select 'own_profile_assignment_policies', 'blocking',
    (case when exists (
       select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles'
       and policyname = 'Users can read own profile' and cmd = 'SELECT' and qual = '(auth.uid() = id)'
     ) then 0 else 1 end
     + case when exists (
       select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles'
       and policyname = 'Users can update own basic profile' and cmd = 'UPDATE'
       and qual = '(auth.uid() = id)' and with_check = '(auth.uid() = id)'
     ) then 0 else 1 end
     + case when exists (
       select 1 from pg_policies where schemaname = 'public' and tablename = 'role_assignments'
       and policyname = 'Users can read own role assignments' and cmd = 'SELECT'
       and qual = '(auth.uid() = user_id)'
     ) then 0 else 1 end
     + abs((select count(*) from pg_policies where schemaname = 'public' and tablename = 'profiles') - 2)
     + abs((select count(*) from pg_policies where schemaname = 'public' and tablename = 'role_assignments') - 1))::bigint

  union all
  select 'client_grant_drift', 'blocking',
    (case when has_table_privilege('authenticated','public.profiles','SELECT') then 0 else 1 end
      + case when has_table_privilege('authenticated','public.role_assignments','SELECT') then 0 else 1 end
      + case when has_table_privilege('anon','public.profiles','SELECT') then 1 else 0 end
      + case when has_table_privilege('anon','public.role_assignments','SELECT') then 1 else 0 end
      + case when has_table_privilege('authenticated','public.profiles','INSERT') then 1 else 0 end
      + case when has_table_privilege('authenticated','public.profiles','DELETE') then 1 else 0 end
      + case when has_table_privilege('authenticated','public.role_assignments','INSERT') then 1 else 0 end
      + case when has_table_privilege('authenticated','public.role_assignments','UPDATE') then 1 else 0 end
      + case when has_table_privilege('authenticated','public.role_assignments','DELETE') then 1 else 0 end)::bigint
) checks
order by category;

rollback;
