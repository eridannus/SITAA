-- Preflight 0010: sólo lectura, sin PII, UUID ni inspección de secretos.
begin transaction read only;
set local time zone 'UTC';
set local datestyle to 'ISO, MDY';

with blocking(category,aggregate_count) as (
  values
  ('post_0009_inventory_drift',
    (case when (select count(*) from information_schema.tables where table_schema='public' and table_type='BASE TABLE')=18 then 0 else 1 end)+
    (case when (select count(*) from information_schema.columns where table_schema='public')=165 then 0 else 1 end)+
    (case when (select count(*) from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname='public' and c.contype in ('p','f','u','c'))=80 then 0 else 1 end)+
    (case when (select count(*) from pg_indexes where schemaname='public')=43 then 0 else 1 end)+
    (case when (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal)=11 then 0 else 1 end)+
    (case when (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')=54 then 0 else 1 end)+
    (case when (select count(*) from pg_policies where schemaname='public')=25 then 0 else 1 end)+
    (case when (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and c.relrowsecurity)=18 then 0 else 1 end)),
  ('post_0009_privilege_inventory_drift',
    (case when (select count(*) from information_schema.routine_privileges where routine_schema='public')=137 then 0 else 1 end)+
    (case when (select count(*) from information_schema.table_privileges where table_schema='public')=267 then 0 else 1 end)+
    (case when (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public')+(select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault(case when c.relkind='S' then 's'::"char" else 'r'::"char" end,c.relowner))) a where n.nspname='public' and c.relkind in ('r','p','v','m','S'))=445 then 0 else 1 end)),
  ('post_0009_function_map_drift',case when (select md5(coalesce(string_agg(p.oid::regprocedure::text||':'||md5(regexp_replace(p.prosrc,'\s+','','g')),'|' order by p.oid::regprocedure::text),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')='71f9763d702e95e4eede51a4a4611694' then 0 else 1 end),
  ('post_0009_column_hash_drift',case when (select md5(coalesce(string_agg(table_name||':'||ordinal_position::text||':'||column_name||':'||data_type||':'||udt_name||':'||is_nullable||':'||coalesce(column_default,'')||':'||coalesce(character_maximum_length::text,'')||':'||coalesce(numeric_precision::text,'')||':'||coalesce(numeric_scale::text,'')||':'||coalesce(datetime_precision::text,''),'|' order by table_name,ordinal_position),'')) from information_schema.columns where table_schema='public')='847b9f5c4ec9d428c522f714de59fd1f' then 0 else 1 end),
  ('post_0009_constraint_hash_drift',case when (select md5(coalesce(string_agg(c.relname||':'||k.conname||':'||case k.contype when 'p' then 'primary_key' when 'f' then 'foreign_key' when 'u' then 'unique' when 'c' then 'check' end||':'||pg_get_constraintdef(k.oid,true),'|' order by c.relname,k.conname),'')) from pg_constraint k join pg_class c on c.oid=k.conrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and k.contype in ('p','f','u','c'))='64f099164063d0cf500478dda3b5d25c' then 0 else 1 end),
  ('post_0009_index_hash_drift',case when (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||indexname||':'||indexdef,'|' order by schemaname,tablename,indexname),'')) from pg_indexes where schemaname='public')='653875a8435cf43bda4fe55950f65802' then 0 else 1 end),
  ('post_0009_policy_hash_drift',case when (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||policyname||':'||permissive||':'||roles::text||':'||cmd||':'||coalesce(qual,'')||':'||coalesce(with_check,''),'|' order by schemaname,tablename,policyname),'')) from pg_policies where schemaname='public')='a72df97fbb8e73d8445f7fe8765da4ba' then 0 else 1 end),
  ('post_0009_trigger_hash_drift',case when (select md5(coalesce(string_agg(c.relname||':'||t.tgname||':'||pg_get_triggerdef(t.oid,true),'|' order by c.relname,t.tgname),'')) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal)='67ee47bcd43c0594129facf3d7729bad' then 0 else 1 end),
  ('b2b_function_body_drift',(select count(*) from (values
    ('is_exact_b1_account_admin_profile_b2b(uuid)','104d16a531ea53a5b4908102322097dc'),
    ('get_admin_account_lifecycle_context_b2b(uuid)','6e7c8bb5e2dcf99fce6a75e03e07c309'),
    ('transition_admin_account_lifecycle_b2b(uuid,text,text)','7f940968051ff1b844443f6c76b561c3')
  ) e(signature,body_hash) left join pg_proc p on p.oid=to_regprocedure('public.'||e.signature) where p.oid is null or md5(regexp_replace(p.prosrc,'\s+','','g'))<>e.body_hash)),
  ('b2b_function_acl_drift',
    (case when has_function_privilege('authenticated','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE') then 0 else 1 end)+
    (case when has_function_privilege('authenticated','public.get_admin_account_lifecycle_context_b2b(uuid)','EXECUTE') then 0 else 1 end)+
    (case when not has_function_privilege('anon','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE') and not has_function_privilege('service_role','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE') then 0 else 1 end)),
  ('b1_authority_contract_drift',case when exists(select 1 from pg_proc p where p.oid=to_regprocedure('public.is_b1_account_admin()') and p.prosecdef and p.provolatile='s' and p.proconfig=array['search_path=pg_catalog, public']::text[] and md5(regexp_replace(p.prosrc,'\s+','','g'))='0486f72652abc79ed3d1334704d55fbe') then 0 else 1 end),
  ('b2a_active_account_barrier_drift',(select count(*) from (values
    ('is_sitaa_operational_account_active()','f85f733578f09c0f7466af7e18a90f4c'),
    ('get_admin_identity_correction_context_b2a(uuid)','83932d04ff8f1b33793e8c7a49bb8e68'),
    ('correct_admin_account_identity_b2a(uuid,text,text,text,text,text,uuid,text)','ce05cbc529473c070953e765e3ee05b2'),
    ('enforce_activity_writer_integrity_b2a()','c58bd04859f1e2a044fcca58d3333e3c')
  ) e(signature,body_hash) left join pg_proc p on p.oid=to_regprocedure('public.'||e.signature) where p.oid is null or md5(regexp_replace(p.prosrc,'\s+','','g'))<>e.body_hash)),
  ('auth_profile_cardinality_drift',(select count(*) from public.profiles p left join auth.users u on u.id=p.id where u.id is null)+(select count(*) from auth.users u left join public.profiles p on p.id=u.id where p.id is null)),
  ('canonical_auth_trigger_drift',
    (case when (select count(*) from pg_trigger t where not t.tgisinternal and t.tgname='on_sitaa_auth_user_created' and t.tgrelid='auth.users'::regclass and t.tgfoid=to_regprocedure('public.handle_sitaa_auth_user_created()'))=1 then 0 else 1 end)+
    (case when (select count(*) from pg_trigger t where not t.tgisinternal and t.tgname='on_sitaa_auth_user_email_changed' and t.tgrelid='auth.users'::regclass and t.tgfoid=to_regprocedure('public.sync_sitaa_profile_email_from_auth()'))=1 then 0 else 1 end)),
  ('admin_audit_contract_drift',
    (case when to_regclass('public.admin_audit_events') is not null then 0 else 1 end)+
    (case when (select count(*) from information_schema.columns where table_schema='public' and table_name='admin_audit_events')=9 then 0 else 1 end)+
    (case when (select count(*) from pg_trigger where tgrelid='public.admin_audit_events'::regclass and not tgisinternal)=2 then 0 else 1 end)+
    (case when (select relrowsecurity from pg_class where oid='public.admin_audit_events'::regclass) then 0 else 1 end)+
    (case when (select count(*) from pg_policies where schemaname='public' and tablename='admin_audit_events')=0 then 0 else 1 end)),
  ('b3a_action_code_incompatible',case when 'account_auth_suspended'~'^[a-z][a-z0-9]*(_[a-z0-9]+)*$' and 'account_auth_restored'~'^[a-z][a-z0-9]*(_[a-z0-9]+)*$' and 'account_auth_suspension_failed'~'^[a-z][a-z0-9]*(_[a-z0-9]+)*$' and 'account_auth_restoration_failed'~'^[a-z][a-z0-9]*(_[a-z0-9]+)*$' then 0 else 1 end),
  ('service_role_contract_drift',case when exists(select 1 from pg_roles where rolname='service_role' and rolbypassrls and rolcanlogin=false) then 0 else 1 end),
  ('profile_lifecycle_inconsistency',(select count(*) from public.profiles where not (account_status='active' and is_active and activated_at is not null and deactivated_at is null or account_status='pending_registration' and not is_active and activated_at is null and deactivated_at is null or account_status='inactive' and not is_active and activated_at is not null and deactivated_at is not null))),
  ('conflicting_0010_table',case when to_regclass('public.admin_auth_operations') is null then 0 else 1 end),
  ('conflicting_0010_functions',(select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('guard_admin_auth_operation_b3a','get_admin_account_auth_lifecycle_context_b3a','prepare_admin_account_auth_lifecycle_b3a','finalize_admin_account_auth_reactivation_b3a','claim_admin_auth_operation_b3a','record_admin_auth_operation_result_b3a'))),
  ('controlled_seed_drift',case when (with rows(catalog,row_json) as (
    select 'academic_periods',to_jsonb(s)::text from public.academic_periods s union all select 'academic_programs',to_jsonb(s)::text from public.academic_programs s union all select 'activity_modalities',to_jsonb(s)::text from public.activity_modalities s union all select 'activity_statuses',to_jsonb(s)::text from public.activity_statuses s union all select 'activity_types',to_jsonb(s)::text from public.activity_types s union all select 'attention_categories',to_jsonb(s)::text from public.attention_categories s union all select 'divisions',to_jsonb(s)::text from public.divisions s union all select 'location_types',to_jsonb(s)::text from public.location_types s union all select 'participant_roles',to_jsonb(s)::text from public.participant_roles s union all select 'roles',to_jsonb(s)::text from public.roles s union all select 'service_types',to_jsonb(s)::text from public.service_types s)
    select count(*)=51 and md5(string_agg(catalog||E'\t'||row_json,E'\n' order by catalog,row_json))='2e450238768fbe9889470864a1832486' from rows) then 0 else 1 end),
  ('dangerous_default_acl',(select count(*) from pg_default_acl d cross join lateral aclexplode(d.defaclacl) a where a.grantee in (0,'anon'::regrole,'authenticated'::regrole) and a.privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE')))
), informational(category,aggregate_count) as (
  values
  ('inactive_accounts',(select count(*) from public.profiles where account_status='inactive')),
  ('inactive_accounts_with_active_or_future_assignments',(select count(distinct p.id) from public.profiles p join public.role_assignments r on r.user_id=p.id where p.account_status='inactive' and r.is_active and (r.ends_at is null or r.ends_at>=public.sitaa_current_mexico_date()))),
  ('active_exact_b1_administrators',(select count(*) from public.profiles p where public.is_exact_b1_account_admin_profile_b2b(p.id))),
  ('existing_b2b_lifecycle_events',(select count(*) from public.admin_audit_events where action_code in ('account_deactivated','account_reactivated')))
)
select category,'blocking'::text classification,aggregate_count from blocking
union all
select category,'informational',aggregate_count from informational
order by classification,category;

rollback;
