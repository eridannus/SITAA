-- Preflight 0007: sólo lectura, sin PII ni filas operativas.
begin;
set local transaction read only;

select category, classification, issue_count
from (
  select 'database_roles'::text category, 'blocking'::text classification,
    (3 - count(*))::bigint issue_count
  from pg_roles where rolname in ('anon','authenticated','service_role')

  union all
  select 'service_role_bypassrls', 'blocking',
    case when exists (
      select 1 from pg_roles where rolname='service_role' and rolbypassrls=true
    ) then 0 else 1 end

  union all
  select 'post_0006_tables', 'blocking', count(*)::bigint
  from (values ('public.profiles'),('public.roles'),('public.role_assignments'),
    ('public.academic_programs'),('public.divisions'),('auth.users'),('auth.identities')) expected(object_name)
  where to_regclass(expected.object_name) is null

  union all
  select 'post_0006_columns_and_types', 'blocking', count(*)::bigint
  from (values
    ('profiles','id','uuid'),('profiles','email','text'),('profiles','full_name','text'),
    ('profiles','primary_program_id','uuid'),('profiles','is_active','boolean'),
    ('profiles','created_at','timestamp with time zone'),('profiles','updated_at','timestamp with time zone'),
    ('profiles','first_names','text'),('profiles','paternal_surname','text'),
    ('profiles','maternal_surname','text'),('profiles','person_type','text'),
    ('profiles','institutional_id_type','text'),('profiles','institutional_id_value','text'),
    ('profiles','account_kind','text'),('profiles','account_status','text'),
    ('profiles','activated_at','timestamp with time zone'),('profiles','deactivated_at','timestamp with time zone'),
    ('roles','code','text'),('roles','label','text'),('roles','description','text'),('roles','sort_order','integer'),
    ('role_assignments','id','uuid'),('role_assignments','user_id','uuid'),
    ('role_assignments','role_code','text'),('role_assignments','scope_type','text'),
    ('role_assignments','service_area','text'),('role_assignments','division_id','uuid'),
    ('role_assignments','program_id','uuid'),('role_assignments','starts_at','date'),
    ('role_assignments','ends_at','date'),('role_assignments','is_active','boolean'),
    ('role_assignments','assigned_by','uuid'),('role_assignments','created_at','timestamp with time zone'),
    ('role_assignments','updated_at','timestamp with time zone'),
    ('academic_programs','id','uuid'),('academic_programs','name','text'),
    ('divisions','id','uuid'),('divisions','name','text')
  ) expected(table_name,column_name,data_type)
  where not exists (
    select 1 from information_schema.columns c
    where c.table_schema='public' and c.table_name=expected.table_name
      and c.column_name=expected.column_name and c.data_type=expected.data_type
  )

  union all
  select 'v1_role_shape', 'blocking',
    ((select count(*) from information_schema.columns
      where table_schema='public' and table_name='roles' and column_name in ('id','is_active'))
     + (select count(*) from information_schema.columns
      where table_schema='public' and table_name='role_assignments'
        and column_name in ('status','revoked_by','revoked_at','administrative_notes'))
     + case when exists (
       select 1 from pg_constraint where conrelid='public.roles'::regclass and contype='p'
         and pg_get_constraintdef(oid)='PRIMARY KEY (code)'
     ) then 0 else 1 end)::bigint

  union all
  select 'technical_admin_catalog', 'blocking',
    case when exists(select 1 from public.roles where code='technical_admin') then 0 else 1 end

  union all
  select 'post_0006_functions_triggers', 'blocking',
    (case when to_regprocedure('public.handle_sitaa_auth_user_created()') is null then 1 else 0 end
     + case when to_regprocedure('public.normalize_sitaa_profile_names()') is null then 1 else 0 end
     + case when to_regprocedure('public.complete_own_google_registration(text,text,text,text,text,uuid)') is null then 1 else 0 end
     + case when exists (
       select 1 from pg_trigger t join pg_class c on c.oid=t.tgrelid
       join pg_namespace n on n.oid=c.relnamespace
       where n.nspname='public' and c.relname='profiles'
         and t.tgname in ('enforce_sitaa_profile_identity','normalize_sitaa_profile_names')
         and not t.tgisinternal group by c.oid having count(*)=2
     ) then 0 else 1 end)::bigint

  union all
  select 'verified_unaccent_function', 'blocking',
    case when to_regprocedure('extensions.unaccent(text)') is null then 1 else 0 end

  union all
  select 'auth_profile_one_to_one', 'blocking',
    (select count(*) from public.profiles p left join auth.users u on u.id=p.id where u.id is null)
    + (select count(*) from auth.users u left join public.profiles p on p.id=u.id where p.id is null)

  union all
  select 'role_assignment_foreign_keys', 'blocking', count(*)::bigint
  from public.role_assignments ra
  left join public.profiles p on p.id=ra.user_id
  left join public.roles r on r.code=ra.role_code
  left join public.divisions d on d.id=ra.division_id
  left join public.academic_programs ap on ap.id=ra.program_id
  left join auth.users au on au.id=ra.assigned_by
  where p.id is null or r.code is null
    or (ra.division_id is not null and d.id is null)
    or (ra.program_id is not null and ap.id is null)
    or (ra.assigned_by is not null and au.id is null)

  union all
  select 'conflicting_0007_objects', 'blocking',
    (case when to_regclass('public.admin_audit_events') is null then 0 else 1 end
     + (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
       where n.nspname='public' and p.proname in (
         'sitaa_current_mexico_date','is_b1_account_admin','admin_audit_metadata_is_safe',
         'prevent_admin_audit_event_mutation','search_admin_accounts_b1',
         'get_admin_account_detail_b1','get_admin_account_assignments_b1',
         'get_admin_account_audit_history_b1'))
     + (select count(*) from pg_trigger where tgname in (
       'prevent_admin_audit_event_mutation','prevent_admin_audit_event_truncate') and not tgisinternal)
     + (select count(*) from pg_policies where schemaname='public' and tablename='admin_audit_events')
     + (select count(*) from (values
       ('public.admin_audit_events_target_occurred_idx'),('public.admin_audit_events_actor_occurred_idx'),
       ('public.profiles_admin_directory_sort_idx'),('public.profiles_admin_directory_filters_idx')
     ) expected(object_name) where to_regclass(expected.object_name) is not null))::bigint

  union all
  select 'rls_and_own_policies', 'blocking',
    (case when exists(select 1 from pg_class where oid='public.profiles'::regclass and relrowsecurity) then 0 else 1 end
     + case when exists(select 1 from pg_class where oid='public.role_assignments'::regclass and relrowsecurity) then 0 else 1 end
     + case when exists(select 1 from pg_policies where schemaname='public' and tablename='profiles'
       and policyname='Users can read own profile' and roles=array['authenticated']::name[]
       and cmd='SELECT' and qual='(auth.uid() = id)') then 0 else 1 end
     + case when exists(select 1 from pg_policies where schemaname='public' and tablename='profiles'
       and policyname='Users can update own basic profile' and roles=array['authenticated']::name[]
       and cmd='UPDATE' and qual='(auth.uid() = id)' and with_check='(auth.uid() = id)') then 0 else 1 end
     + case when exists(select 1 from pg_policies where schemaname='public' and tablename='role_assignments'
       and policyname='Users can read own role assignments' and roles=array['authenticated']::name[]
       and cmd='SELECT' and qual='(auth.uid() = user_id)') then 0 else 1 end
     + abs((select count(*) from pg_policies where schemaname='public' and tablename='profiles')-2)
     + abs((select count(*) from pg_policies where schemaname='public' and tablename='role_assignments')-1))::bigint

  union all
  select 'profile_client_privileges', 'blocking',
    (case when has_table_privilege('authenticated','public.profiles','SELECT') then 0 else 1 end
     + case when has_table_privilege('authenticated','public.profiles','UPDATE') then 1 else 0 end
     + case when has_column_privilege('authenticated','public.profiles','first_names','UPDATE') then 0 else 1 end
     + case when has_column_privilege('authenticated','public.profiles','paternal_surname','UPDATE') then 0 else 1 end
     + case when has_column_privilege('authenticated','public.profiles','maternal_surname','UPDATE') then 0 else 1 end
     + (select count(*) from pg_attribute a where a.attrelid='public.profiles'::regclass
       and a.attnum>0 and not a.attisdropped
       and a.attname not in ('first_names','paternal_surname','maternal_surname')
       and has_column_privilege('authenticated','public.profiles',a.attname,'UPDATE'))
     + (select count(*) from pg_attribute a where a.attrelid='public.profiles'::regclass
       and a.attnum>0 and not a.attisdropped
       and (has_column_privilege('authenticated','public.profiles',a.attname,'INSERT')
         or has_column_privilege('authenticated','public.profiles',a.attname,'REFERENCES')))
     + case when has_table_privilege('authenticated','public.profiles','INSERT') then 1 else 0 end
     + case when has_table_privilege('authenticated','public.profiles','DELETE') then 1 else 0 end
     + case when has_table_privilege('authenticated','public.profiles','TRUNCATE') then 1 else 0 end
     + case when has_table_privilege('authenticated','public.profiles','REFERENCES') then 1 else 0 end
     + case when has_table_privilege('authenticated','public.profiles','TRIGGER') then 1 else 0 end
     + (select count(*) from pg_class c
       cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) acl
       where c.oid='public.profiles'::regclass
         and acl.grantee=(select oid from pg_roles where rolname='authenticated')
         and upper(acl.privilege_type)='MAINTAIN'))::bigint

  union all
  select 'role_assignment_client_privileges', 'blocking',
    (case when has_table_privilege('authenticated','public.role_assignments','SELECT') then 0 else 1 end
     + case when has_table_privilege('authenticated','public.role_assignments','INSERT') then 1 else 0 end
     + case when has_table_privilege('authenticated','public.role_assignments','UPDATE') then 1 else 0 end
     + case when has_table_privilege('authenticated','public.role_assignments','DELETE') then 1 else 0 end
     + case when has_table_privilege('authenticated','public.role_assignments','TRUNCATE') then 1 else 0 end
     + case when has_table_privilege('authenticated','public.role_assignments','REFERENCES') then 1 else 0 end
     + case when has_table_privilege('authenticated','public.role_assignments','TRIGGER') then 1 else 0 end
     + (select count(*) from pg_attribute a where a.attrelid='public.role_assignments'::regclass
       and a.attnum>0 and not a.attisdropped
       and (has_column_privilege('authenticated','public.role_assignments',a.attname,'INSERT')
         or has_column_privilege('authenticated','public.role_assignments',a.attname,'UPDATE')
         or has_column_privilege('authenticated','public.role_assignments',a.attname,'REFERENCES')))
     + (select count(*) from pg_class c
       cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) acl
       where c.oid='public.role_assignments'::regclass
         and acl.grantee=(select oid from pg_roles where rolname='authenticated')
         and upper(acl.privilege_type)='MAINTAIN'))::bigint

  union all
  select 'anon_public_profile_assignment_privileges', 'blocking', count(*)::bigint
  from pg_class c cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) acl
  where c.oid in ('public.profiles'::regclass,'public.role_assignments'::regclass)
    and (acl.grantee=0 or acl.grantee=(select oid from pg_roles where rolname='anon'))

  union all
  select 'anon_public_profile_assignment_column_privileges', 'blocking', count(*)::bigint
  from information_schema.column_privileges cp
  where cp.table_schema='public' and cp.table_name in ('profiles','role_assignments')
    and cp.grantee in ('anon','PUBLIC')

  union all
  select 'malformed_current_technical_admin_assignments', 'informational', count(*)::bigint
  from public.role_assignments ra
  where ra.role_code='technical_admin' and ra.is_active
    and ra.starts_at<=(current_timestamp at time zone 'America/Mexico_City')::date
    and (ra.ends_at is null
      or ra.ends_at>=(current_timestamp at time zone 'America/Mexico_City')::date)
    and (ra.scope_type is distinct from 'system' or ra.service_area is distinct from 'technical'
      or ra.program_id is not null or ra.division_id is not null)
) checks
order by category;

rollback;
