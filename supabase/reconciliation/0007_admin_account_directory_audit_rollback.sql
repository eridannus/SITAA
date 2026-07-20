-- Rollback manual 0007. Sólo procede si la bitácora está vacía y el contrato está completo.
begin isolation level read committed;

do $require_audit_table$
begin
  if to_regclass('public.admin_audit_events') is null then
    raise exception 'sitaa_0007_rollback_contract_incomplete' using errcode = 'P0001';
  end if;
end;
$require_audit_table$;

-- Impide que un INSERT de auditoría confirme entre la comprobación de vacío y el DROP TABLE.
lock table public.admin_audit_events in access exclusive mode nowait;

do $guard$
declare
  expected_functions regprocedure[] := array[
    to_regprocedure('public.sitaa_current_mexico_date()'),
    to_regprocedure('public.is_b1_account_admin()'),
    to_regprocedure('public.admin_audit_metadata_is_safe(jsonb)'),
    to_regprocedure('public.prevent_admin_audit_event_mutation()'),
    to_regprocedure('public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)'),
    to_regprocedure('public.get_admin_account_detail_b1(uuid)'),
    to_regprocedure('public.get_admin_account_assignments_b1(uuid)'),
    to_regprocedure('public.get_admin_account_audit_history_b1(uuid,integer,integer)')
  ];
  rpc regprocedure;
  helper regprocedure;
begin
  if to_regclass('public.admin_audit_events') is null
     or array_position(expected_functions, null) is not null
     or not exists (
       select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relname = 'admin_audit_events'
         and c.relrowsecurity = true
     )
     or exists (
       select 1 from pg_policies
       where schemaname = 'public' and tablename = 'admin_audit_events'
     )
     or not exists (
       select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
       join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relname = 'admin_audit_events'
         and t.tgname = 'prevent_admin_audit_event_mutation' and not t.tgisinternal
     )
     or not exists (
       select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
       join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relname = 'admin_audit_events'
         and t.tgname = 'prevent_admin_audit_event_truncate' and not t.tgisinternal
     )
     or not exists (
       select 1 from pg_constraint
       where conrelid = 'public.admin_audit_events'::regclass
         and conname in ('admin_audit_events_action_code_check','admin_audit_events_outcome_check',
           'admin_audit_events_reason_check','admin_audit_events_metadata_check')
       group by conrelid having count(*) = 4
     )
     or (select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'admin_audit_events') <> 9
     or (select count(*) from pg_constraint where conrelid = 'public.admin_audit_events'::regclass and contype = 'f' and confdeltype = 'r') <> 3
     or to_regclass('public.admin_audit_events_target_occurred_idx') is null
     or to_regclass('public.admin_audit_events_actor_occurred_idx') is null
     or to_regclass('public.profiles_admin_directory_sort_idx') is null
     or to_regclass('public.profiles_admin_directory_filters_idx') is null
     or has_table_privilege('authenticated','public.admin_audit_events','SELECT')
     or has_table_privilege('authenticated','public.admin_audit_events','INSERT')
     or has_table_privilege('authenticated','public.admin_audit_events','UPDATE')
     or has_table_privilege('authenticated','public.admin_audit_events','DELETE')
     or has_table_privilege('authenticated','public.admin_audit_events','TRUNCATE')
     or has_table_privilege('anon','public.admin_audit_events','SELECT')
     or not has_table_privilege('service_role','public.admin_audit_events','SELECT')
     or not has_table_privilege('service_role','public.admin_audit_events','INSERT')
     or has_table_privilege('service_role','public.admin_audit_events','UPDATE')
     or has_table_privilege('service_role','public.admin_audit_events','DELETE')
     or has_table_privilege('service_role','public.admin_audit_events','TRUNCATE')
     or has_table_privilege('service_role','public.admin_audit_events','REFERENCES')
     or has_table_privilege('service_role','public.admin_audit_events','TRIGGER')
     or exists (
       select 1 from pg_class c
       cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) acl
       where c.oid='public.admin_audit_events'::regclass
         and acl.grantee=(select oid from pg_roles where rolname='service_role')
         and upper(acl.privilege_type) not in ('SELECT','INSERT')
     )
     or exists (
       select 1 from pg_class c
       cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) acl
       where c.oid='public.admin_audit_events'::regclass
         and (acl.grantee=0 or acl.grantee=(select oid from pg_roles where rolname='anon'))
     ) then
    raise exception 'sitaa_0007_rollback_contract_incomplete' using errcode = 'P0001';
  end if;

  if not exists (
       select 1
       from pg_proc p
       where p.oid = 'public.sitaa_current_mexico_date()'::regprocedure
         and p.prorettype = 'date'::regtype
         and p.provolatile = 's'
         and p.prosecdef = false
         and p.prolang = (select oid from pg_language where lanname = 'sql')
         and coalesce(p.proconfig, '{}'::text[]) = array['search_path=pg_catalog']::text[]
         and lower(pg_get_functiondef(p.oid)) like '%america/mexico_city%'
     )
     or exists (
       select 1
       from pg_proc p
       cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
       where p.oid = 'public.sitaa_current_mexico_date()'::regprocedure
         and acl.privilege_type = 'EXECUTE'
         and (
           acl.grantee = 0
           or acl.grantee = (select oid from pg_roles where rolname = 'anon')
           or acl.grantee = (select oid from pg_roles where rolname = 'authenticated')
           or acl.grantee = (select oid from pg_roles where rolname = 'service_role')
         )
     ) then
    raise exception 'sitaa_0007_rollback_mexico_date_contract_incomplete' using errcode = 'P0001';
  end if;

  foreach rpc in array array[
    'public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)'::regprocedure,
    'public.get_admin_account_detail_b1(uuid)'::regprocedure,
    'public.get_admin_account_assignments_b1(uuid)'::regprocedure,
    'public.get_admin_account_audit_history_b1(uuid,integer,integer)'::regprocedure
  ] loop
    if not has_function_privilege('authenticated', rpc, 'EXECUTE')
       or has_function_privilege('anon', rpc, 'EXECUTE')
       or has_function_privilege('service_role', rpc, 'EXECUTE')
       or exists (
         select 1 from aclexplode((select coalesce(proacl, acldefault('f', proowner)) from pg_proc where oid = rpc))
         where grantee = 0 and privilege_type = 'EXECUTE'
       )
       or (
         select count(*)
         from pg_proc p
         cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
         where p.oid = rpc and acl.privilege_type = 'EXECUTE'
       ) <> 2
       or exists (
         select 1
         from pg_proc p
         cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
         where p.oid = rpc and acl.privilege_type = 'EXECUTE'
           and acl.grantee not in (
             p.proowner,
             (select oid from pg_roles where rolname = 'authenticated')
           )
       )
       or not exists (
         select 1
         from pg_proc p
         cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
         where p.oid = rpc and acl.privilege_type = 'EXECUTE'
           and acl.grantee = (select oid from pg_roles where rolname = 'authenticated')
           and not acl.is_grantable
       )
       or (select not prosecdef from pg_proc where oid = rpc)
       or lower(pg_get_functiondef(rpc)) not like '%set search_path%pg_catalog%public%' then
      raise exception 'sitaa_0007_rollback_rpc_contract_incomplete' using errcode = 'P0001';
    end if;
  end loop;

  if lower(pg_get_functiondef('public.is_b1_account_admin()'::regprocedure))
       not like '%public.sitaa_current_mexico_date()%'
     or lower(pg_get_functiondef('public.is_b1_account_admin()'::regprocedure)) ~ '\mcurrent_date\M'
     or lower(pg_get_functiondef(
       'public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)'::regprocedure
     )) not like '%public.sitaa_current_mexico_date()%'
     or lower(pg_get_functiondef(
       'public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)'::regprocedure
     )) ~ '\mcurrent_date\M'
     or lower(pg_get_functiondef('public.get_admin_account_assignments_b1(uuid)'::regprocedure))
       not like '%public.sitaa_current_mexico_date()%'
     or lower(pg_get_functiondef('public.get_admin_account_assignments_b1(uuid)'::regprocedure))
       ~ '\mcurrent_date\M'
     or lower(pg_get_functiondef('public.admin_audit_metadata_is_safe(jsonb)'::regprocedure))
       !~ 'octet_length\(candidate::text\)\s*>\s*16384' then
    raise exception 'sitaa_0007_rollback_runtime_contract_incomplete' using errcode = 'P0001';
  end if;

  foreach helper in array array[
    'public.sitaa_current_mexico_date()'::regprocedure,
    'public.is_b1_account_admin()'::regprocedure,
    'public.prevent_admin_audit_event_mutation()'::regprocedure
  ] loop
    if has_function_privilege('anon', helper, 'EXECUTE')
       or has_function_privilege('authenticated', helper, 'EXECUTE')
       or has_function_privilege('service_role', helper, 'EXECUTE')
       or exists (
         select 1
         from pg_proc p
         cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
         where p.oid = helper and acl.privilege_type = 'EXECUTE'
           and acl.grantee <> p.proowner
       ) then
      raise exception 'sitaa_0007_rollback_owner_only_helper_grant_drift' using errcode = 'P0001';
    end if;
  end loop;

  if has_function_privilege('anon','public.admin_audit_metadata_is_safe(jsonb)','EXECUTE')
     or has_function_privilege('authenticated','public.admin_audit_metadata_is_safe(jsonb)','EXECUTE')
     or not has_function_privilege('service_role','public.admin_audit_metadata_is_safe(jsonb)','EXECUTE')
     or (
       select count(*)
       from pg_proc p
       cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
       where p.oid='public.admin_audit_metadata_is_safe(jsonb)'::regprocedure
         and acl.privilege_type='EXECUTE'
     ) <> 2
     or exists (
       select 1
       from pg_proc p
       cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
       where p.oid='public.admin_audit_metadata_is_safe(jsonb)'::regprocedure
         and acl.privilege_type='EXECUTE'
         and acl.grantee not in (
           p.proowner,
           (select oid from pg_roles where rolname='service_role')
          )
      )
     or not exists (
       select 1
       from pg_proc p
       cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
       where p.oid='public.admin_audit_metadata_is_safe(jsonb)'::regprocedure
         and acl.privilege_type='EXECUTE'
         and acl.grantee=(select oid from pg_roles where rolname='service_role')
         and not acl.is_grantable
     ) then
    raise exception 'sitaa_0007_rollback_private_helper_grant_drift' using errcode = 'P0001';
  end if;

  if exists (select 1 from public.admin_audit_events) then
    raise exception 'sitaa_0007_rollback_refuses_nonempty_audit_history' using errcode = '55000';
  end if;
end;
$guard$;

revoke all on function public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)
  from public, anon, authenticated, service_role;
revoke all on function public.get_admin_account_detail_b1(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.get_admin_account_assignments_b1(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.get_admin_account_audit_history_b1(uuid,integer,integer)
  from public, anon, authenticated, service_role;
revoke all on table public.admin_audit_events from public, anon, authenticated, service_role;
revoke all on function public.admin_audit_metadata_is_safe(jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.prevent_admin_audit_event_mutation()
  from public, anon, authenticated, service_role;
revoke all on function public.is_b1_account_admin()
  from public, anon, authenticated, service_role;
revoke all on function public.sitaa_current_mexico_date()
  from public, anon, authenticated, service_role;

drop function public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer);
drop function public.get_admin_account_detail_b1(uuid);
drop function public.get_admin_account_assignments_b1(uuid);
drop function public.get_admin_account_audit_history_b1(uuid,integer,integer);

drop trigger prevent_admin_audit_event_truncate on public.admin_audit_events;
drop trigger prevent_admin_audit_event_mutation on public.admin_audit_events;
drop function public.prevent_admin_audit_event_mutation();
drop table public.admin_audit_events;
drop function public.admin_audit_metadata_is_safe(jsonb);
drop function public.is_b1_account_admin();
drop function public.sitaa_current_mexico_date();

drop index public.profiles_admin_directory_sort_idx;
drop index public.profiles_admin_directory_filters_idx;

do $verify$
begin
  if to_regclass('public.admin_audit_events') is not null
     or to_regprocedure('public.sitaa_current_mexico_date()') is not null
     or to_regprocedure('public.is_b1_account_admin()') is not null
     or to_regprocedure('public.admin_audit_metadata_is_safe(jsonb)') is not null
     or to_regprocedure('public.prevent_admin_audit_event_mutation()') is not null
     or to_regprocedure('public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)') is not null
     or to_regprocedure('public.get_admin_account_detail_b1(uuid)') is not null
     or to_regprocedure('public.get_admin_account_assignments_b1(uuid)') is not null
     or to_regprocedure('public.get_admin_account_audit_history_b1(uuid,integer,integer)') is not null
     or exists(select 1 from pg_trigger where tgname in ('prevent_admin_audit_event_mutation','prevent_admin_audit_event_truncate') and not tgisinternal)
     or to_regclass('public.profiles_admin_directory_sort_idx') is not null
     or to_regclass('public.profiles_admin_directory_filters_idx') is not null then
    raise exception 'sitaa_0007_rollback_objects_remain' using errcode = 'P0001';
  end if;

  if to_regclass('public.profiles') is null
     or to_regclass('public.role_assignments') is null
     or to_regprocedure('public.complete_own_google_registration(text,text,text,text,text,uuid)') is null
     or to_regprocedure('public.normalize_sitaa_profile_names()') is null
     or not exists(select 1 from pg_class where oid='public.profiles'::regclass and relrowsecurity)
     or not exists(select 1 from pg_class where oid='public.role_assignments'::regclass and relrowsecurity)
     or not has_table_privilege('authenticated','public.profiles','SELECT')
     or has_table_privilege('authenticated','public.profiles','UPDATE')
     or not has_column_privilege('authenticated','public.profiles','first_names','UPDATE')
     or not has_column_privilege('authenticated','public.profiles','paternal_surname','UPDATE')
     or not has_column_privilege('authenticated','public.profiles','maternal_surname','UPDATE')
     or not has_table_privilege('authenticated','public.role_assignments','SELECT')
     or has_table_privilege('authenticated','public.role_assignments','INSERT')
     or has_table_privilege('authenticated','public.role_assignments','UPDATE')
     or has_table_privilege('authenticated','public.role_assignments','DELETE') then
    raise exception 'sitaa_0007_rollback_damaged_post_0006_contract' using errcode = 'P0001';
  end if;
end;
$verify$;

commit;
