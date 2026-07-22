-- Preflight 0009. Sólo lectura; devuelve categorías y conteos, nunca PII.
begin transaction read only;

with blocking(category,aggregate_count) as (
  values
  ('post_0008_inventory_drift',
    (case when (select count(*) from information_schema.tables where table_schema='public' and table_type='BASE TABLE')=18 then 0 else 1 end)+
    (case when (select count(*) from information_schema.columns where table_schema='public')=165 then 0 else 1 end)+
    (case when (select count(*) from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname='public' and c.contype in ('p','f','u','c'))=80 then 0 else 1 end)+
    (case when (select count(*) from pg_indexes where schemaname='public')=43 then 0 else 1 end)+
    (case when (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal)=11 then 0 else 1 end)+
    (case when (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')=51 then 0 else 1 end)+
    (case when (select count(*) from pg_policies where schemaname='public')=25 then 0 else 1 end)+
    (case when (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and c.relrowsecurity)=18 then 0 else 1 end)),
  ('post_0008_privilege_drift',
    (case when (select count(*) from information_schema.routine_privileges where routine_schema='public')=132 then 0 else 1 end)+
    (case when (select count(*) from information_schema.table_privileges where table_schema='public')=267 then 0 else 1 end)+
    (case when (select count(*) from information_schema.usage_privileges where object_schema='public' and object_type='SEQUENCE')=6 then 0 else 1 end)+
    (case when (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public')+(select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault(case when c.relkind='S' then 's'::"char" else 'r'::"char" end,c.relowner))) a where n.nspname='public' and c.relkind in ('r','p','v','m','S'))=440 then 0 else 1 end)),
  ('post_0001_0008_object_contract_drift',
    (select count(*) from (values
      ('public.sitaa_current_mexico_date()'),('public.is_b1_account_admin()'),
      ('public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)'),
      ('public.get_admin_account_detail_b1(uuid)'),
      ('public.get_admin_account_assignments_b1(uuid)'),
      ('public.get_admin_account_audit_history_b1(uuid,integer,integer)'),
      ('public.is_sitaa_operational_account_active()'),
      ('public.get_admin_identity_correction_context_b2a(uuid)'),
      ('public.correct_admin_account_identity_b2a(uuid,text,text,text,text,text,uuid,text)'),
      ('public.enforce_activity_writer_integrity_b2a()')
    ) expected(signature) where to_regprocedure(expected.signature) is null)),
  ('conflicting_0009_objects',
    (case when to_regprocedure('public.is_exact_b1_account_admin_profile_b2b(uuid)') is null then 0 else 1 end)+
    (case when to_regprocedure('public.get_admin_account_lifecycle_context_b2b(uuid)') is null then 0 else 1 end)+
    (case when to_regprocedure('public.transition_admin_account_lifecycle_b2b(uuid,text,text)') is null then 0 else 1 end)),
  ('profile_physical_security_contract_drift',
    (case when (select count(*) from information_schema.columns where table_schema='public' and table_name='profiles')=17 then 0 else 1 end)+
    (case when (select string_agg(column_name||':'||data_type||':'||is_nullable||':'||coalesce(column_default,''),'|' order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='profiles')='id:uuid:NO:|email:text:NO:|full_name:text:YES:|primary_program_id:uuid:YES:|is_active:boolean:NO:false|created_at:timestamp with time zone:NO:now()|updated_at:timestamp with time zone:NO:now()|first_names:text:YES:|paternal_surname:text:YES:|maternal_surname:text:YES:|person_type:text:YES:|institutional_id_type:text:YES:|institutional_id_value:text:YES:|account_kind:text:NO:''institutional''::text|account_status:text:NO:''pending_registration''::text|activated_at:timestamp with time zone:YES:|deactivated_at:timestamp with time zone:YES:' then 0 else 1 end)+
    (case when (select count(*) from pg_constraint where conrelid='public.profiles'::regclass)=17 then 0 else 1 end)+
    (case when (select count(*) from pg_trigger where tgrelid='public.profiles'::regclass and not tgisinternal)=3 then 0 else 1 end)+
    (case when (select relrowsecurity and not relforcerowsecurity from pg_class where oid='public.profiles'::regclass) then 0 else 1 end)+
    (case when (select count(*) from pg_policies where schemaname='public' and tablename='profiles')=2 then 0 else 1 end)+
    (case when (select count(*) from pg_attribute where attrelid='public.profiles'::regclass and attnum>0 and not attisdropped and attacl is not null)=0 then 0 else 1 end)+
    (case when has_table_privilege('authenticated','public.profiles','SELECT') and not has_table_privilege('authenticated','public.profiles','INSERT') and not has_table_privilege('authenticated','public.profiles','UPDATE') and not has_table_privilege('authenticated','public.profiles','DELETE') and not has_table_privilege('authenticated','public.profiles','TRUNCATE') and not has_table_privilege('authenticated','public.profiles','REFERENCES') and not has_table_privilege('authenticated','public.profiles','TRIGGER') and not has_table_privilege('authenticated','public.profiles','MAINTAIN') then 0 else 1 end)),
  ('profile_lifecycle_inconsistency',
    (select count(*) from public.profiles where not (
      account_status='active' and is_active and activated_at is not null and deactivated_at is null
      or account_status='pending_registration' and not is_active and activated_at is null and deactivated_at is null
      or account_status='inactive' and not is_active and activated_at is not null and deactivated_at is not null))),
  ('profile_identity_inconsistency',
    (select count(*) from public.profiles profile where not (
      profile.account_kind='institutional' and profile.account_status='pending_registration' and profile.person_type is null and profile.primary_program_id is null and profile.institutional_id_type is null and profile.institutional_id_value is null and profile.first_names is null and profile.paternal_surname is null and profile.maternal_surname is null
      or profile.account_kind='institutional' and profile.account_status in ('active','inactive') and profile.person_type in ('student','professor') and profile.first_names is not null and profile.paternal_surname is not null and profile.full_name=concat_ws(' ',profile.first_names,profile.paternal_surname,profile.maternal_surname) and profile.primary_program_id is not null and profile.institutional_id_value~'^[0-9]{1,50}$' and profile.institutional_id_type=case when profile.person_type='student' then 'student_account' else 'worker_number' end
      or profile.account_kind='technical' and profile.account_status in ('active','inactive') and profile.first_names is not null and profile.full_name=concat_ws(' ',profile.first_names,profile.paternal_surname,profile.maternal_surname) and profile.person_type is null and profile.primary_program_id is null and profile.institutional_id_type is null and profile.institutional_id_value is null))),
  ('auth_profile_cardinality_drift',
    (select count(*) from public.profiles profile left join auth.users auth_user on auth_user.id=profile.id where auth_user.id is null)+
    (select count(*) from auth.users auth_user left join public.profiles profile on profile.id=auth_user.id where profile.id is null)),
  ('auth_profile_email_drift',
    (select count(*) from public.profiles profile join auth.users auth_user on auth_user.id=profile.id where profile.email<>lower(btrim(profile.email)) or lower(btrim(auth_user.email))<>profile.email)),
  ('b1_private_helper_drift',
    (select case when p.oid is not null and p.prosecdef and p.provolatile='s' and p.proconfig=array['search_path=pg_catalog, public']::text[] and md5(regexp_replace(p.prosrc,'\s+','','g'))='0486f72652abc79ed3d1334704d55fbe' and not has_function_privilege('authenticated',p.oid,'EXECUTE') and not has_function_privilege('anon',p.oid,'EXECUTE') and not has_function_privilege('service_role',p.oid,'EXECUTE') then 0 else 1 end from (select to_regprocedure('public.is_b1_account_admin()') oid) expected left join pg_proc p on p.oid=expected.oid)),
  ('b1_public_rpc_contract_drift',
    (select count(*) from (values
      ('public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)'),
      ('public.get_admin_account_detail_b1(uuid)'),
      ('public.get_admin_account_assignments_b1(uuid)'),
      ('public.get_admin_account_audit_history_b1(uuid,integer,integer)')
    ) expected(signature) left join pg_proc p on p.oid=to_regprocedure(expected.signature)
    where p.oid is null or not p.prosecdef or not has_function_privilege('authenticated',p.oid,'EXECUTE') or has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('service_role',p.oid,'EXECUTE'))),
  ('active_account_barrier_drift',
    (select count(*) from (values
      ('is_sitaa_operational_account_active()','f85f733578f09c0f7466af7e18a90f4c'),
      ('get_admin_identity_correction_context_b2a(uuid)','83932d04ff8f1b33793e8c7a49bb8e68'),
      ('correct_admin_account_identity_b2a(uuid,text,text,text,text,text,uuid,text)','ce05cbc529473c070953e765e3ee05b2'),
      ('enforce_activity_writer_integrity_b2a()','c58bd04859f1e2a044fcca58d3333e3c')
    ) expected(signature,body_hash) left join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
    where p.oid is null or md5(regexp_replace(p.prosrc,'\s+','','g'))<>expected.body_hash)),
  ('admin_audit_contract_drift',
    (case when to_regclass('public.admin_audit_events') is not null then 0 else 1 end)+
    (case when (select count(*) from information_schema.columns where table_schema='public' and table_name='admin_audit_events')=9 then 0 else 1 end)+
    (case when (select count(*) from pg_constraint where conrelid='public.admin_audit_events'::regclass)=8 then 0 else 1 end)+
    (case when (select count(*) from pg_trigger where tgrelid='public.admin_audit_events'::regclass and not tgisinternal)=2 then 0 else 1 end)+
    (case when (select relrowsecurity from pg_class where oid='public.admin_audit_events'::regclass) then 0 else 1 end)+
    (case when (select count(*) from pg_policies where schemaname='public' and tablename='admin_audit_events')=0 then 0 else 1 end)+
    (case when not has_table_privilege('authenticated','public.admin_audit_events','SELECT') and not has_table_privilege('authenticated','public.admin_audit_events','INSERT') and not has_table_privilege('authenticated','public.admin_audit_events','UPDATE') and not has_table_privilege('authenticated','public.admin_audit_events','DELETE') and has_table_privilege('service_role','public.admin_audit_events','SELECT') and has_table_privilege('service_role','public.admin_audit_events','INSERT') and not has_table_privilege('service_role','public.admin_audit_events','UPDATE') and not has_table_privilege('service_role','public.admin_audit_events','DELETE') and not has_table_privilege('service_role','public.admin_audit_events','TRUNCATE') then 0 else 1 end)),
  ('audit_action_code_incompatible',case when exists(select 1 from pg_constraint where conrelid='public.admin_audit_events'::regclass and conname='admin_audit_events_action_code_check' and pg_get_constraintdef(oid) like '%a-z0-9%') then 0 else 1 end),
  ('authenticated_lifecycle_column_update',
    (case when has_column_privilege('authenticated','public.profiles','account_status','UPDATE') or has_column_privilege('authenticated','public.profiles','is_active','UPDATE') or has_column_privilege('authenticated','public.profiles','activated_at','UPDATE') or has_column_privilege('authenticated','public.profiles','deactivated_at','UPDATE') then 1 else 0 end)),
  ('existing_0009_signature_overload',
    (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('is_exact_b1_account_admin_profile_b2b','get_admin_account_lifecycle_context_b2b','transition_admin_account_lifecycle_b2b'))),
  ('missing_active_exact_b1_administrator',case when exists(select 1 from public.profiles profile join public.role_assignments assignment on assignment.user_id=profile.id where profile.account_status='active' and profile.is_active and assignment.role_code='technical_admin' and assignment.scope_type='system' and assignment.service_area='technical' and assignment.program_id is null and assignment.division_id is null and assignment.is_active and assignment.starts_at<=public.sitaa_current_mexico_date() and (assignment.ends_at is null or assignment.ends_at>=public.sitaa_current_mexico_date())) then 0 else 1 end),
  ('canonical_auth_trigger_drift',
    (case when (select count(*) from pg_trigger trigger_row where trigger_row.tgrelid='auth.users'::regclass and not trigger_row.tgisinternal and trigger_row.tgname in ('on_sitaa_auth_user_created','on_sitaa_auth_user_email_changed') and trigger_row.tgenabled='O')=2 then 0 else 1 end)+
    (case when to_regprocedure('public.handle_sitaa_auth_user_created()') is not null and to_regprocedure('public.handle_sitaa_auth_user_email_changed()') is not null then 0 else 1 end)),
  ('unexplained_lifecycle_state',
    (select count(*) from public.profiles where account_kind not in ('institutional','technical') or account_status not in ('pending_registration','active','inactive')))
), exact_admins as (
  select distinct profile.id
  from public.profiles profile join public.role_assignments assignment on assignment.user_id=profile.id
  where profile.account_status='active' and profile.is_active
    and assignment.role_code='technical_admin' and assignment.scope_type='system'
    and assignment.service_area='technical' and assignment.program_id is null
    and assignment.division_id is null and assignment.is_active
    and assignment.starts_at<=public.sitaa_current_mexico_date()
    and (assignment.ends_at is null or assignment.ends_at>=public.sitaa_current_mexico_date())
), informational(category,aggregate_count) as (
  values
  ('active_exact_b1_administrators',(select count(*) from exact_admins)),
  ('inactive_accounts_with_current_or_future_assignments',(select count(distinct profile.id) from public.profiles profile join public.role_assignments assignment on assignment.user_id=profile.id where profile.account_status='inactive' and assignment.is_active and (assignment.ends_at is null or assignment.ends_at>=public.sitaa_current_mexico_date()))),
  ('inactive_accounts_with_open_responsibilities',(select count(distinct profile.id) from public.profiles profile join public.activities activity on activity.created_by=profile.id or activity.responsible_profile_id=profile.id where profile.account_status='inactive' and (activity.status_code='draft' or public.activity_has_ended(activity.id) is distinct from true))),
  ('inactive_accounts_with_open_participations',(select count(distinct profile.id) from public.profiles profile join public.activity_participants participant on participant.profile_id=profile.id join public.activities activity on activity.id=participant.activity_id where profile.account_status='inactive' and (activity.status_code='draft' or public.activity_has_ended(activity.id) is distinct from true))),
  ('inactive_accounts_with_exact_current_b1_assignment',(select count(distinct profile.id) from public.profiles profile join public.role_assignments assignment on assignment.user_id=profile.id where profile.account_status='inactive' and assignment.role_code='technical_admin' and assignment.scope_type='system' and assignment.service_area='technical' and assignment.program_id is null and assignment.division_id is null and assignment.is_active and assignment.starts_at<=public.sitaa_current_mexico_date() and (assignment.ends_at is null or assignment.ends_at>=public.sitaa_current_mexico_date()))),
  ('inactive_accounts_ineligible_by_identity',(select count(*) from public.profiles profile where profile.account_status='inactive' and not (profile.full_name=concat_ws(' ',profile.first_names,profile.paternal_surname,profile.maternal_surname) and (profile.account_kind='institutional' and profile.person_type in ('student','professor') and profile.primary_program_id is not null and profile.institutional_id_value~'^[0-9]{1,50}$' or profile.account_kind='technical' and profile.person_type is null and profile.primary_program_id is null and profile.institutional_id_value is null)))),
  ('inactive_accounts_ineligible_by_auth',(select count(*) from public.profiles profile left join auth.users auth_user on auth_user.id=profile.id where profile.account_status='inactive' and (auth_user.id is null or lower(btrim(auth_user.email))<>profile.email or not (auth_user.email_confirmed_at is not null or exists(select 1 from auth.identities identity_row where identity_row.user_id=auth_user.id and identity_row.provider='google' and lower(btrim(identity_row.identity_data->>'email'))=lower(btrim(auth_user.email)) and lower(btrim(coalesce(identity_row.identity_data->>'email_verified',''))) in ('true','t','1'))))))
)
select category,'blocking'::text classification,aggregate_count
from blocking
where aggregate_count<>0
union all
select category,'informational',aggregate_count
from informational
order by classification,category;

rollback;
