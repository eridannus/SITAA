-- Phase B.3a: coordinación fail-closed entre ciclo de vida SITAA y Supabase Auth.
-- Preparada localmente; requiere preflight, revisión y aplicación manual controlada.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';
set local time zone 'UTC';
set local datestyle to 'ISO, MDY';

-- Preflight bloqueante post-0009. No modifica objetos antes de completar todas
-- las comprobaciones y no inspecciona secretos ni devuelve datos personales.
do $preflight$
declare
  mismatch_count integer := 0;
  expected_function_hash text := '71f9763d702e95e4eede51a4a4611694';
begin
  -- El estado capturado abajo sólo es válido si primero coincide con toda la
  -- superficie bloqueante canónica post-0009 del preflight independiente.
  with canonical_blocking(category,aggregate_count) as (
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
    ('post_0009_function_signature_drift',case when (select md5(coalesce(string_agg(p.oid::regprocedure::text,'|' order by p.oid::regprocedure::text),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')='89d8e1d260ccc0af72ee42c394f79f90' then 0 else 1 end),
    ('post_0009_function_metadata_drift',case when (
      with entries(value) as (
        select p.oid::regprocedure::text||':'||pg_get_userbyid(p.proowner)||':'||l.lanname||':'||
          p.provolatile::text||':'||p.prosecdef::text||':'||coalesce(array_to_string(p.proconfig,E'\n'),'')
        from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
        where n.nspname='public'
      )
      select md5(coalesce(string_agg(value,'|' order by value),'')) from entries
    )='c2095a58fb96e7387513b4bebf33b95d' then 0 else 1 end),
    ('post_0009_function_acl_drift',case when (
      with entries(value) as (
        select p.oid::regprocedure::text||':'||pg_get_userbyid(p.proowner)||':'||
          pg_get_userbyid(acl.grantor)||':'||
          case when acl.grantee=0 then 'PUBLIC' else pg_get_userbyid(acl.grantee) end||':'||
          acl.privilege_type||':'||acl.is_grantable::text
        from pg_proc p join pg_namespace n on n.oid=p.pronamespace
        cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
        where n.nspname='public'
      )
      select count(*)=137 and md5(coalesce(string_agg(value,'|' order by value),''))='4ea1d04b7d1b1632fd5ce01a1dc83e05' from entries
    ) then 0 else 1 end),
    ('post_0009_table_acl_drift',case when (
      with entries(value) as (
        select c.relname||':'||pg_get_userbyid(c.relowner)||':'||
          pg_get_userbyid(acl.grantor)||':'||
          case when acl.grantee=0 then 'PUBLIC' else pg_get_userbyid(acl.grantee) end||':'||
          acl.privilege_type||':'||acl.is_grantable::text
        from pg_class c join pg_namespace n on n.oid=c.relnamespace
        cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) acl
        where n.nspname='public' and c.relkind in ('r','p','v','m')
      )
      select count(*)=302 and md5(coalesce(string_agg(value,'|' order by value),''))='e1e24e4406a6b72e539a412396b58a83' from entries
    ) then 0 else 1 end),
    ('post_0009_sequence_acl_exact_drift',case when (
      with entries(value) as (
        select c.relname||':'||pg_get_userbyid(c.relowner)||':'||
          pg_get_userbyid(acl.grantor)||':'||
          case when acl.grantee=0 then 'PUBLIC' else pg_get_userbyid(acl.grantee) end||':'||
          acl.privilege_type||':'||acl.is_grantable::text
        from pg_class c join pg_namespace n on n.oid=c.relnamespace
        cross join lateral aclexplode(coalesce(c.relacl,acldefault('s',c.relowner))) acl
        where n.nspname='public' and c.relkind='S'
      )
      select count(*)=6 and md5(coalesce(string_agg(value,'|' order by value),''))='f33fd097dfc9ed8a316ad5a3accab896' from entries
    ) then 0 else 1 end),
    ('post_0009_explicit_column_acl_drift',case when not exists (
      (
        select c.relname,a.attname,pg_get_userbyid(acl.grantor),
          case when acl.grantee=0 then 'PUBLIC' else pg_get_userbyid(acl.grantee) end,
          acl.privilege_type,acl.is_grantable
        from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace
        cross join lateral aclexplode(a.attacl) acl
        where n.nspname='public' and a.attnum>0 and not a.attisdropped and a.attacl is not null
      )
      except
      values
        ('profiles','first_names','postgres','authenticated','UPDATE',false),
        ('profiles','maternal_surname','postgres','authenticated','UPDATE',false),
        ('profiles','paternal_surname','postgres','authenticated','UPDATE',false)
    ) and not exists (
      (values
        ('profiles','first_names','postgres','authenticated','UPDATE',false),
        ('profiles','maternal_surname','postgres','authenticated','UPDATE',false),
        ('profiles','paternal_surname','postgres','authenticated','UPDATE',false)
      )
      except
      select c.relname,a.attname,pg_get_userbyid(acl.grantor),
        case when acl.grantee=0 then 'PUBLIC' else pg_get_userbyid(acl.grantee) end,
        acl.privilege_type,acl.is_grantable
      from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace
      cross join lateral aclexplode(a.attacl) acl
      where n.nspname='public' and a.attnum>0 and not a.attisdropped and a.attacl is not null
    ) then 0 else 1 end),
    ('post_0009_column_hash_drift',case when (select md5(coalesce(string_agg(table_name||':'||ordinal_position::text||':'||column_name||':'||data_type||':'||udt_name||':'||is_nullable||':'||coalesce(column_default,'')||':'||coalesce(character_maximum_length::text,'')||':'||coalesce(numeric_precision::text,'')||':'||coalesce(numeric_scale::text,'')||':'||coalesce(datetime_precision::text,''),'|' order by table_name,ordinal_position),'')) from information_schema.columns where table_schema='public')='847b9f5c4ec9d428c522f714de59fd1f' then 0 else 1 end),
    ('post_0009_constraint_hash_drift',case when (select md5(coalesce(string_agg(c.relname||':'||k.conname||':'||case k.contype when 'p' then 'primary_key' when 'f' then 'foreign_key' when 'u' then 'unique' when 'c' then 'check' end||':'||pg_get_constraintdef(k.oid,true),'|' order by c.relname,k.conname),'')) from pg_constraint k join pg_class c on c.oid=k.conrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and k.contype in ('p','f','u','c'))='64f099164063d0cf500478dda3b5d25c' then 0 else 1 end),
    ('post_0009_index_hash_drift',case when (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||indexname||':'||indexdef,'|' order by schemaname,tablename,indexname),'')) from pg_indexes where schemaname='public')='653875a8435cf43bda4fe55950f65802' then 0 else 1 end),
    ('post_0009_policy_hash_drift',case when (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||policyname||':'||permissive||':'||roles::text||':'||cmd||':'||coalesce(qual,'')||':'||coalesce(with_check,''),'|' order by schemaname,tablename,policyname),'')) from pg_policies where schemaname='public')='a72df97fbb8e73d8445f7fe8765da4ba' then 0 else 1 end),
    ('post_0009_trigger_hash_drift',case when (select md5(coalesce(string_agg(c.relname||':'||t.tgname||':'||pg_get_triggerdef(t.oid,true),'|' order by c.relname,t.tgname),'')) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal)='67ee47bcd43c0594129facf3d7729bad' then 0 else 1 end),
    ('post_0009_authenticated_table_acl_drift',case when (select md5(coalesce(string_agg(table_name||':'||privilege_type,'|' order by table_name,privilege_type),'')) from information_schema.table_privileges where table_schema='public' and grantee='authenticated')='edbb0931514cafe989d3d345c4ea61d6' then 0 else 1 end),
    ('post_0009_sequence_acl_drift',case when (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault('s',c.relowner))) acl where n.nspname='public' and c.relkind='S')=6 then 0 else 1 end),
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
      (case when (select count(*) from pg_trigger t where not t.tgisinternal and t.tgname='on_sitaa_auth_user_created')=1 then 0 else 1 end)+
      (case when (select count(*) from pg_trigger t where not t.tgisinternal and t.tgname='on_sitaa_auth_user_created' and t.tgrelid='auth.users'::regclass and t.tgenabled='O' and t.tgtype=5::smallint and t.tgfoid=to_regprocedure('public.handle_sitaa_auth_user_created()') and cardinality(t.tgattr::smallint[])=0 and t.tgqual is null)=1 then 0 else 1 end)+
      (case when (select count(*) from pg_trigger t where not t.tgisinternal and t.tgname='on_sitaa_auth_user_email_changed')=1 then 0 else 1 end)+
      (case when (select count(*) from pg_trigger t where not t.tgisinternal and t.tgname='on_sitaa_auth_user_email_changed' and t.tgrelid='auth.users'::regclass and t.tgenabled='O' and t.tgtype=17::smallint and t.tgfoid=to_regprocedure('public.sync_sitaa_profile_email_from_auth()') and cardinality(t.tgattr::smallint[])=1 and t.tgqual is not null and (select count(*) from unnest(t.tgattr::smallint[]) u(attnum) join pg_attribute a on a.attrelid=t.tgrelid and a.attnum=u.attnum and a.attname='email' and not a.attisdropped)=1 and regexp_replace(regexp_replace(split_part(split_part(lower(pg_get_triggerdef(t.oid,false)),' when ',2),' execute function ',1),'[[:space:]()]','','g'),'::text','','g')='old.emailisdistinctfromnew.email')=1 then 0 else 1 end)),
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
  )
  select count(*) into mismatch_count
  from canonical_blocking
  where aggregate_count<>0;
  if mismatch_count<>0 then
    raise exception 'sitaa_0010_preflight_canonical_baseline_mismatch' using errcode='55000';
  end if;

  if (select count(*) from information_schema.tables where table_schema='public' and table_type='BASE TABLE')<>18
     or (select count(*) from information_schema.columns where table_schema='public')<>165
     or (select count(*) from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname='public' and c.contype in ('p','f','u','c'))<>80
     or (select count(*) from pg_indexes where schemaname='public')<>43
     or (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal)<>11
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>54
     or (select count(*) from pg_policies where schemaname='public')<>25
     or (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and c.relrowsecurity)<>18
     or (select count(*) from information_schema.routine_privileges where routine_schema='public')<>137
     or (select count(*) from information_schema.table_privileges where table_schema='public')<>267
     or (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault('s',c.relowner))) acl where n.nspname='public' and c.relkind='S')<>6
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public')+
        (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault(case when c.relkind='S' then 's'::"char" else 'r'::"char" end,c.relowner))) a where n.nspname='public' and c.relkind in ('r','p','v','m','S'))<>445 then
    raise exception 'sitaa_0010_preflight_inventory_mismatch' using errcode='55000';
  end if;

  if (select md5(coalesce(string_agg(p.oid::regprocedure::text||':'||md5(regexp_replace(p.prosrc,'\s+','','g')),'|' order by p.oid::regprocedure::text),''))
      from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>expected_function_hash then
    raise exception 'sitaa_0010_preflight_function_map_mismatch' using errcode='55000';
  end if;

  select count(*) into mismatch_count
  from (values
    ('is_exact_b1_account_admin_profile_b2b(uuid)','104d16a531ea53a5b4908102322097dc'),
    ('get_admin_account_lifecycle_context_b2b(uuid)','6e7c8bb5e2dcf99fce6a75e03e07c309'),
    ('transition_admin_account_lifecycle_b2b(uuid,text,text)','7f940968051ff1b844443f6c76b561c3'),
    ('is_sitaa_operational_account_active()','f85f733578f09c0f7466af7e18a90f4c'),
    ('is_b1_account_admin()','0486f72652abc79ed3d1334704d55fbe')
  ) expected(signature,body_hash)
  left join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
  where p.oid is null or md5(regexp_replace(p.prosrc,'\s+','','g'))<>expected.body_hash;
  if mismatch_count<>0 then
    raise exception 'sitaa_0010_preflight_prior_function_mismatch' using errcode='55000';
  end if;

  if not has_function_privilege('authenticated','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or has_function_privilege('anon','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or has_function_privilege('service_role','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or not has_function_privilege('authenticated','public.get_admin_account_lifecycle_context_b2b(uuid)','EXECUTE') then
    raise exception 'sitaa_0010_preflight_0009_acl_mismatch' using errcode='55000';
  end if;

  if to_regclass('public.admin_audit_events') is null
     or (select count(*) from information_schema.columns where table_schema='public' and table_name='admin_audit_events')<>9
     or (select count(*) from pg_trigger where tgrelid='public.admin_audit_events'::regclass and not tgisinternal)<>2
     or not (select relrowsecurity from pg_class where oid='public.admin_audit_events'::regclass)
     or (select count(*) from pg_policies where schemaname='public' and tablename='admin_audit_events')<>0
     or has_table_privilege('authenticated','public.admin_audit_events','SELECT')
     or not has_table_privilege('service_role','public.admin_audit_events','SELECT')
     or not has_table_privilege('service_role','public.admin_audit_events','INSERT') then
    raise exception 'sitaa_0010_preflight_audit_contract_mismatch' using errcode='55000';
  end if;

  if not exists(select 1 from pg_roles where rolname='service_role' and rolbypassrls)
     or (select count(*) from public.profiles p left join auth.users u on u.id=p.id where u.id is null)>0
     or (select count(*) from auth.users u left join public.profiles p on p.id=u.id where p.id is null)>0
     or (select count(*) from public.profiles where not (
       account_status='active' and is_active and activated_at is not null and deactivated_at is null
       or account_status='pending_registration' and not is_active and activated_at is null and deactivated_at is null
       or account_status='inactive' and not is_active and activated_at is not null and deactivated_at is not null))>0 then
    raise exception 'sitaa_0010_preflight_identity_or_role_mismatch' using errcode='55000';
  end if;

  if (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_created')<>1
     or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_created' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgenabled='O' and trigger_definition.tgtype=5::smallint and trigger_definition.tgfoid=to_regprocedure('public.handle_sitaa_auth_user_created()') and cardinality(trigger_definition.tgattr::smallint[])=0 and trigger_definition.tgqual is null)<>1
     or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_email_changed')<>1
     or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_email_changed' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgenabled='O' and trigger_definition.tgtype=17::smallint and trigger_definition.tgfoid=to_regprocedure('public.sync_sitaa_profile_email_from_auth()') and cardinality(trigger_definition.tgattr::smallint[])=1 and trigger_definition.tgqual is not null and (select count(*) from unnest(trigger_definition.tgattr::smallint[]) update_attribute(attnum) join pg_attribute attribute_definition on attribute_definition.attrelid=trigger_definition.tgrelid and attribute_definition.attnum=update_attribute.attnum and attribute_definition.attname='email' and not attribute_definition.attisdropped)=1 and regexp_replace(regexp_replace(split_part(split_part(lower(pg_get_triggerdef(trigger_definition.oid,false)),' when ',2),' execute function ',1),'[[:space:]()]','','g'),'::text','','g')='old.emailisdistinctfromnew.email')<>1
     or exists (select 1 from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgfoid in (to_regprocedure('public.handle_sitaa_auth_user_created()'),to_regprocedure('public.sync_sitaa_profile_email_from_auth()')) and not (trigger_definition.tgname='on_sitaa_auth_user_created' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgfoid=to_regprocedure('public.handle_sitaa_auth_user_created()') or trigger_definition.tgname='on_sitaa_auth_user_email_changed' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgfoid=to_regprocedure('public.sync_sitaa_profile_email_from_auth()'))) then
    raise exception 'sitaa_0010_preflight_auth_trigger_mismatch' using errcode='55000';
  end if;

  if to_regclass('public.admin_auth_operations') is not null
     or exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in (
       'guard_admin_auth_operation_b3a','get_admin_account_auth_lifecycle_context_b3a',
       'prepare_admin_account_auth_lifecycle_b3a','finalize_admin_account_auth_reactivation_b3a',
       'claim_admin_auth_operation_b3a','record_admin_auth_operation_result_b3a')) then
    raise exception 'sitaa_0010_preflight_conflicting_object' using errcode='55000';
  end if;

  if not (
    with controlled_seed_rows(catalog,row_json) as (
      select 'academic_periods',to_jsonb(s)::text from public.academic_periods s union all
      select 'academic_programs',to_jsonb(s)::text from public.academic_programs s union all
      select 'activity_modalities',to_jsonb(s)::text from public.activity_modalities s union all
      select 'activity_statuses',to_jsonb(s)::text from public.activity_statuses s union all
      select 'activity_types',to_jsonb(s)::text from public.activity_types s union all
      select 'attention_categories',to_jsonb(s)::text from public.attention_categories s union all
      select 'divisions',to_jsonb(s)::text from public.divisions s union all
      select 'location_types',to_jsonb(s)::text from public.location_types s union all
      select 'participant_roles',to_jsonb(s)::text from public.participant_roles s union all
      select 'roles',to_jsonb(s)::text from public.roles s union all
      select 'service_types',to_jsonb(s)::text from public.service_types s
    ) select count(*)=51 and md5(string_agg(catalog||E'\t'||row_json,E'\n' order by catalog,row_json))='2e450238768fbe9889470864a1832486' from controlled_seed_rows
  ) then
    raise exception 'sitaa_0010_preflight_seed_mismatch' using errcode='55000';
  end if;

  if (select md5(coalesce(string_agg(p.oid::regprocedure::text,'|' order by p.oid::regprocedure::text),''))
      from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>'89d8e1d260ccc0af72ee42c394f79f90'
     or (select md5(coalesce(string_agg(table_name||':'||ordinal_position::text||':'||column_name||':'||data_type||':'||udt_name||':'||is_nullable||':'||coalesce(column_default,'')||':'||coalesce(character_maximum_length::text,'')||':'||coalesce(numeric_precision::text,'')||':'||coalesce(numeric_scale::text,'')||':'||coalesce(datetime_precision::text,''),'|' order by table_name,ordinal_position),'')) from information_schema.columns where table_schema='public')<>'847b9f5c4ec9d428c522f714de59fd1f'
     or (select md5(coalesce(string_agg(table_definition.relname||':'||constraint_definition.conname||':'||case constraint_definition.contype when 'p' then 'primary_key' when 'f' then 'foreign_key' when 'u' then 'unique' when 'c' then 'check' end||':'||pg_get_constraintdef(constraint_definition.oid,true),'|' order by table_definition.relname,constraint_definition.conname),'')) from pg_constraint constraint_definition join pg_class table_definition on table_definition.oid=constraint_definition.conrelid join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace where namespace_definition.nspname='public' and constraint_definition.contype in ('p','f','u','c'))<>'64f099164063d0cf500478dda3b5d25c'
     or (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||indexname||':'||indexdef,'|' order by schemaname,tablename,indexname),'')) from pg_indexes where schemaname='public')<>'653875a8435cf43bda4fe55950f65802'
     or (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||policyname||':'||permissive||':'||roles::text||':'||cmd||':'||coalesce(qual,'')||':'||coalesce(with_check,''),'|' order by schemaname,tablename,policyname),'')) from pg_policies where schemaname='public')<>'a72df97fbb8e73d8445f7fe8765da4ba'
     or (select md5(coalesce(string_agg(table_definition.relname||':'||trigger_definition.tgname||':'||pg_get_triggerdef(trigger_definition.oid,true),'|' order by table_definition.relname,trigger_definition.tgname),'')) from pg_trigger trigger_definition join pg_class table_definition on table_definition.oid=trigger_definition.tgrelid join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace where namespace_definition.nspname='public' and not trigger_definition.tgisinternal)<>'67ee47bcd43c0594129facf3d7729bad'
     or (select md5(coalesce(string_agg(table_name||':'||privilege_type,'|' order by table_name,privilege_type),'')) from information_schema.table_privileges where table_schema='public' and grantee='authenticated')<>'edbb0931514cafe989d3d345c4ea61d6' then
    raise exception 'sitaa_0010_preflight_exact_map_mismatch' using errcode='55000';
  end if;

  perform set_config('sitaa_0010.default_acl_hash',
    (select md5(coalesce(string_agg(defaclrole::text||':'||defaclnamespace::text||':'||defaclobjtype::text||':'||defaclacl::text,'|' order by defaclrole,defaclnamespace,defaclobjtype),'')) from pg_default_acl),true);
  perform set_config('sitaa_0010.prior_function_metadata_hash',
    (select md5(coalesce(string_agg(p.oid::regprocedure::text||':'||pg_get_userbyid(p.proowner)||':'||l.lanname||':'||p.provolatile::text||':'||p.prosecdef::text||':'||coalesce(p.proconfig::text,''),'|' order by p.oid::regprocedure::text),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where n.nspname='public'),true);
  perform set_config('sitaa_0010.prior_function_body_hash',
    (select md5(coalesce(string_agg(p.oid::regprocedure::text||':'||md5(regexp_replace(p.prosrc,'\s+','','g')),'|' order by p.oid::regprocedure::text),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'),true);
  perform set_config('sitaa_0010.prior_function_acl_hash',
    (select md5(coalesce(string_agg(p.oid::regprocedure::text||':'||acl.grantor::text||':'||acl.grantee::text||':'||acl.privilege_type||':'||acl.is_grantable::text,'|' order by p.oid::regprocedure::text,acl.grantor,acl.grantee,acl.privilege_type),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where n.nspname='public' and p.oid<>'public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure),true);
  perform set_config('sitaa_0010.prior_table_column_acl_hash',md5(
    coalesce((select string_agg(table_name||':'||grantor||':'||grantee||':'||privilege_type||':'||is_grantable,'|' order by table_name,grantor,grantee,privilege_type) from information_schema.table_privileges where table_schema='public'),'')
    ||'#'||coalesce((select string_agg(attrelid::text||':'||attnum::text||':'||attacl::text,'|' order by attrelid,attnum) from pg_attribute where attrelid in (select c.oid from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public') and attnum>0 and not attisdropped and attacl is not null),'')
  ),true);
  perform set_config('sitaa_0010.prior_sequence_acl_hash',
    (select md5(coalesce(string_agg(c.relname||':'||acl.grantor::text||':'||acl.grantee::text||':'||acl.privilege_type||':'||acl.is_grantable::text,'|' order by c.relname,acl.grantor,acl.grantee,acl.privilege_type),'')) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault('s',c.relowner))) acl where n.nspname='public' and c.relkind='S'),true);
  perform set_config('sitaa_0010.prior_column_hash',(select md5(coalesce(string_agg(table_name||':'||ordinal_position::text||':'||column_name||':'||data_type||':'||udt_name||':'||is_nullable||':'||coalesce(column_default,'')||':'||coalesce(character_maximum_length::text,'')||':'||coalesce(numeric_precision::text,'')||':'||coalesce(numeric_scale::text,'')||':'||coalesce(datetime_precision::text,''),'|' order by table_name,ordinal_position),'')) from information_schema.columns where table_schema='public'),true);
  perform set_config('sitaa_0010.prior_constraint_hash',(select md5(coalesce(string_agg(table_definition.relname||':'||constraint_definition.conname||':'||case constraint_definition.contype when 'p' then 'primary_key' when 'f' then 'foreign_key' when 'u' then 'unique' when 'c' then 'check' end||':'||pg_get_constraintdef(constraint_definition.oid,true),'|' order by table_definition.relname,constraint_definition.conname),'')) from pg_constraint constraint_definition join pg_class table_definition on table_definition.oid=constraint_definition.conrelid join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace where namespace_definition.nspname='public' and constraint_definition.contype in ('p','f','u','c')),true);
  perform set_config('sitaa_0010.prior_index_hash',(select md5(coalesce(string_agg(schemaname||':'||tablename||':'||indexname||':'||indexdef,'|' order by schemaname,tablename,indexname),'')) from pg_indexes where schemaname='public'),true);
  perform set_config('sitaa_0010.prior_trigger_hash',(select md5(coalesce(string_agg(table_definition.relname||':'||trigger_definition.tgname||':'||pg_get_triggerdef(trigger_definition.oid,true),'|' order by table_definition.relname,trigger_definition.tgname),'')) from pg_trigger trigger_definition join pg_class table_definition on table_definition.oid=trigger_definition.tgrelid join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace where namespace_definition.nspname='public' and not trigger_definition.tgisinternal),true);
end;
$preflight$;

create table public.admin_auth_operations (
  id uuid not null default gen_random_uuid(),
  request_id uuid not null,
  requested_by_profile_id uuid not null
    constraint admin_auth_operations_requested_by_profile_id_fkey
    references public.profiles(id) on delete restrict,
  completed_by_profile_id uuid null
    constraint admin_auth_operations_completed_by_profile_id_fkey
    references public.profiles(id) on delete restrict,
  target_profile_id uuid not null
    constraint admin_auth_operations_target_profile_id_fkey
    references public.profiles(id) on delete restrict,
  operation_code text not null,
  status text not null default 'open',
  completed_stage text not null default 'prepared',
  reason text not null,
  attempt_count integer not null default 0,
  last_error_code text null,
  profile_audit_event_id uuid null
    constraint admin_auth_operations_profile_audit_event_id_fkey
    references public.admin_audit_events(id) on delete restrict,
  auth_audit_event_id uuid null
    constraint admin_auth_operations_auth_audit_event_id_fkey
    references public.admin_audit_events(id) on delete restrict,
  requested_at timestamptz not null default now(),
  processing_started_at timestamptz null,
  auth_synchronized_at timestamptz null,
  completed_at timestamptz null,
  updated_at timestamptz not null default now(),
  constraint admin_auth_operations_pkey primary key (id),
  constraint admin_auth_operations_request_id_key unique (request_id),
  constraint admin_auth_operations_operation_check check (operation_code in ('deactivate','reactivate')),
  constraint admin_auth_operations_status_check check (status in ('open','processing','retryable_failure','succeeded','terminal_failure')),
  constraint admin_auth_operations_stage_check check (completed_stage in ('prepared','profile_suspended','auth_synchronized','completed')),
  constraint admin_auth_operations_reason_check check (
    reason=btrim(regexp_replace(reason,'\s+',' ','g')) and char_length(reason) between 10 and 1000
  ),
  constraint admin_auth_operations_attempt_check check (attempt_count>=0),
  constraint admin_auth_operations_error_check check (last_error_code is null or last_error_code in (
    'auth_temporarily_unavailable','auth_rate_limited','auth_user_not_found',
    'auth_update_rejected','unsupported_auth_contract','database_finalize_pending'
  )),
  constraint admin_auth_operations_stage_operation_check check (
    requested_by_profile_id<>target_profile_id
    and (
      operation_code='reactivate' and completed_stage in ('prepared','auth_synchronized','completed')
      or operation_code='deactivate' and completed_stage in ('profile_suspended','auth_synchronized','completed')
    )
  ),
  constraint admin_auth_operations_evidence_check check (
    (operation_code='deactivate' and profile_audit_event_id is not null
      or operation_code='reactivate' and (
        completed_stage<>'completed' and profile_audit_event_id is null
        or completed_stage='completed' and profile_audit_event_id is not null
      ))
    and (completed_stage in ('auth_synchronized','completed'))=(auth_synchronized_at is not null)
    and (status in ('succeeded','terminal_failure'))=(completed_at is not null)
    and (status in ('succeeded','terminal_failure'))=(completed_by_profile_id is not null)
    and (status='succeeded' and completed_stage='completed'
      or status<>'succeeded' and completed_stage<>'completed')
    and (auth_audit_event_id is not null)=(
      completed_stage in ('auth_synchronized','completed') or status='terminal_failure'
    )
    and (status='succeeded' and last_error_code is null
      or status='terminal_failure' and last_error_code is not null
      or status in ('open','processing') and last_error_code is null
      or status='retryable_failure' and last_error_code is not null)
    and (
      status in ('open','processing')
        and (
          operation_code='reactivate' and completed_stage in ('prepared','auth_synchronized')
          or operation_code='deactivate' and completed_stage='profile_suspended'
        )
      or status='retryable_failure'
        and (
          completed_stage=case when operation_code='reactivate' then 'prepared' else 'profile_suspended' end
            and auth_synchronized_at is null
            and last_error_code in (
              'auth_temporarily_unavailable','auth_rate_limited','auth_user_not_found',
              'auth_update_rejected','unsupported_auth_contract'
            )
          or operation_code='reactivate' and completed_stage='auth_synchronized'
            and auth_audit_event_id is not null and auth_synchronized_at is not null
            and last_error_code='database_finalize_pending'
        )
      or status='terminal_failure'
        and completed_stage=case when operation_code='reactivate' then 'prepared' else 'profile_suspended' end
        and auth_synchronized_at is null
        and last_error_code in ('auth_user_not_found','auth_update_rejected','unsupported_auth_contract')
      or status='succeeded' and completed_stage='completed'
    )
  ),
  constraint admin_auth_operations_timestamp_check check (
    updated_at>=requested_at
    and (processing_started_at is null or processing_started_at>=requested_at)
    and (auth_synchronized_at is null or auth_synchronized_at>=requested_at)
    and (completed_at is null or completed_at>=requested_at)
    and (auth_synchronized_at is null or completed_at is null or completed_at>=auth_synchronized_at)
    and (
      status='open' and processing_started_at is null and last_error_code is null
      or status='processing' and processing_started_at is not null and last_error_code is null
      or status='retryable_failure' and processing_started_at is not null and last_error_code is not null
      or status='succeeded' and processing_started_at is not null
      or status='terminal_failure' and processing_started_at is not null and last_error_code is not null
    )
  )
);

create index admin_auth_operations_target_status_idx
  on public.admin_auth_operations(target_profile_id,status,updated_at desc);
create index admin_auth_operations_actor_requested_idx
  on public.admin_auth_operations(requested_by_profile_id,requested_at desc,id desc);
create unique index admin_auth_operations_one_nonfinal_target_uidx
  on public.admin_auth_operations(target_profile_id)
  where status in ('open','processing','retryable_failure');

alter table public.admin_auth_operations enable row level security;
revoke all on table public.admin_auth_operations from public,anon,authenticated,service_role;
do $normalize_ledger_acl$
declare grantee_name text;
begin
  for grantee_name in
    select distinct pg_get_userbyid(acl.grantee)
    from pg_class table_definition
    cross join lateral aclexplode(coalesce(table_definition.relacl,acldefault('r',table_definition.relowner))) acl
    where table_definition.oid='public.admin_auth_operations'::regclass
      and acl.grantee<>table_definition.relowner and acl.grantee<>0
  loop
    execute format('revoke all privileges on table public.admin_auth_operations from %I',grantee_name);
  end loop;
end;
$normalize_ledger_acl$;
grant all privileges on table public.admin_auth_operations to postgres;

create function public.guard_admin_auth_operation_b3a()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog,public
as $function$
declare
  writer text:=current_setting('sitaa.b3a_writer',true);
  old_rank integer;
  new_rank integer;
begin
  if tg_op in ('DELETE','TRUNCATE') then
    raise exception 'sitaa_auth_operation_destructive_change_forbidden' using errcode='42501';
  end if;
  if writer is null or writer not in ('prepare','claim','record','finalize') then
    raise exception 'sitaa_auth_operation_writer_forbidden' using errcode='42501';
  end if;
  if tg_op='INSERT' then
    if writer is distinct from 'prepare' or new.status is distinct from 'open'
       or not (
         new.operation_code='reactivate' and new.completed_stage='prepared'
         or new.operation_code='deactivate' and new.completed_stage='profile_suspended'
       )
       or new.attempt_count<>0 or new.completed_by_profile_id is not null
       or new.last_error_code is not null
       or (new.operation_code='reactivate' and new.profile_audit_event_id is not null)
       or (new.operation_code='deactivate' and new.profile_audit_event_id is null)
       or new.auth_audit_event_id is not null or new.processing_started_at is not null
       or new.auth_synchronized_at is not null or new.completed_at is not null then
      raise exception 'sitaa_auth_operation_invalid_initial_state' using errcode='23514';
    end if;
    return new;
  end if;

  if row(old.id,old.request_id,old.requested_by_profile_id,old.target_profile_id,old.operation_code,old.reason,old.requested_at)
     is distinct from row(new.id,new.request_id,new.requested_by_profile_id,new.target_profile_id,new.operation_code,new.reason,new.requested_at) then
    raise exception 'sitaa_auth_operation_identity_immutable' using errcode='23514';
  end if;
  if old.status in ('succeeded','terminal_failure') then
    raise exception 'sitaa_auth_operation_final_state_immutable' using errcode='23514';
  end if;
  old_rank:=case old.completed_stage when 'prepared' then 1 when 'profile_suspended' then 2 when 'auth_synchronized' then 3 else 4 end;
  new_rank:=case new.completed_stage when 'prepared' then 1 when 'profile_suspended' then 2 when 'auth_synchronized' then 3 else 4 end;
  if new_rank<old_rank or new.attempt_count<old.attempt_count
     or new.updated_at<old.updated_at
     or old.processing_started_at is not null and new.processing_started_at<old.processing_started_at
     or old.completed_by_profile_id is not null and new.completed_by_profile_id is distinct from old.completed_by_profile_id
     or old.profile_audit_event_id is not null and new.profile_audit_event_id is distinct from old.profile_audit_event_id
     or old.auth_audit_event_id is not null and new.auth_audit_event_id is distinct from old.auth_audit_event_id
     or old.auth_synchronized_at is not null and new.auth_synchronized_at is distinct from old.auth_synchronized_at
     or old.completed_at is not null and new.completed_at is distinct from old.completed_at then
    raise exception 'sitaa_auth_operation_regression_forbidden' using errcode='23514';
  end if;

  if writer='claim' then
    if row(new.status,new.attempt_count,new.processing_started_at,new.last_error_code,new.updated_at)
       is not distinct from row(old.status,old.attempt_count,old.processing_started_at,old.last_error_code,old.updated_at)
       or row(old.id,old.request_id,old.requested_by_profile_id,old.completed_by_profile_id,
              old.target_profile_id,old.operation_code,old.completed_stage,old.reason,
              old.profile_audit_event_id,old.auth_audit_event_id,old.requested_at,
              old.auth_synchronized_at,old.completed_at)
          is distinct from
          row(new.id,new.request_id,new.requested_by_profile_id,new.completed_by_profile_id,
              new.target_profile_id,new.operation_code,new.completed_stage,new.reason,
              new.profile_audit_event_id,new.auth_audit_event_id,new.requested_at,
              new.auth_synchronized_at,new.completed_at)
       or new.status<>'processing' or new.attempt_count<>old.attempt_count+1
       or new.processing_started_at is null or new.processing_started_at<old.updated_at
       or new.last_error_code is not null
       or old.status not in ('open','processing','retryable_failure') then
      raise exception 'sitaa_auth_operation_invalid_claim' using errcode='23514';
    end if;
  elsif writer='record' then
    if new.status='retryable_failure' and not (
         new.completed_stage=case when new.operation_code='reactivate' then 'prepared' else 'profile_suspended' end
           and new.auth_synchronized_at is null
           and new.last_error_code in (
             'auth_temporarily_unavailable','auth_rate_limited','auth_user_not_found',
             'auth_update_rejected','unsupported_auth_contract'
           )
         or new.operation_code='reactivate' and new.completed_stage='auth_synchronized'
           and new.auth_audit_event_id is not null and new.auth_synchronized_at is not null
           and new.last_error_code='database_finalize_pending'
       )
       or new.status='terminal_failure' and not (
         new.completed_stage=case when new.operation_code='reactivate' then 'prepared' else 'profile_suspended' end
         and new.auth_synchronized_at is null
         and new.last_error_code in ('auth_user_not_found','auth_update_rejected','unsupported_auth_contract')
       ) then
      raise exception 'sitaa_auth_operation_error_stage_conflict' using errcode='55000';
    end if;
    if old.status<>'processing'
       or row(old.id,old.request_id,old.requested_by_profile_id,old.target_profile_id,
              old.operation_code,old.reason,old.attempt_count,old.profile_audit_event_id,
              old.requested_at,old.processing_started_at)
          is distinct from
          row(new.id,new.request_id,new.requested_by_profile_id,new.target_profile_id,
              new.operation_code,new.reason,new.attempt_count,new.profile_audit_event_id,
              new.requested_at,new.processing_started_at)
       or not (
         new.status='retryable_failure' and new.completed_stage=old.completed_stage
            and new.completed_by_profile_id is null and new.completed_at is null
            and new.auth_audit_event_id is not distinct from old.auth_audit_event_id
            and new.auth_synchronized_at is not distinct from old.auth_synchronized_at
         or new.status='terminal_failure'
           and old.completed_stage in ('prepared','profile_suspended')
           and old.auth_audit_event_id is null and old.auth_synchronized_at is null
           and new.completed_stage=old.completed_stage
           and new.completed_by_profile_id is not null and new.completed_at is not null
           and new.auth_audit_event_id is not null and new.auth_synchronized_at is not distinct from old.auth_synchronized_at
         or old.operation_code='reactivate' and new.status='processing'
           and old.completed_stage='prepared' and new.completed_stage='auth_synchronized'
           and new.completed_by_profile_id is null and new.completed_at is null
           and new.auth_audit_event_id is not null and new.auth_synchronized_at is not null
           and new.last_error_code is null
         or old.operation_code='deactivate' and new.status='succeeded'
           and old.completed_stage='profile_suspended' and new.completed_stage='completed'
           and new.completed_by_profile_id is not null and new.completed_at is not null
           and new.auth_audit_event_id is not null and new.auth_synchronized_at is not null
           and new.last_error_code is null
       ) then
      raise exception 'sitaa_auth_operation_invalid_record' using errcode='23514';
    end if;
  elsif writer='finalize' then
    if row(old.id,old.request_id,old.requested_by_profile_id,old.target_profile_id,
           old.operation_code,old.reason,old.attempt_count,old.auth_audit_event_id,
           old.requested_at,old.processing_started_at,old.auth_synchronized_at)
       is distinct from
       row(new.id,new.request_id,new.requested_by_profile_id,new.target_profile_id,
           new.operation_code,new.reason,new.attempt_count,new.auth_audit_event_id,
           new.requested_at,new.processing_started_at,new.auth_synchronized_at)
       or old.operation_code<>'reactivate' or old.status<>'processing'
       or old.completed_stage<>'auth_synchronized' or old.auth_audit_event_id is null
       or new.status<>'succeeded' or new.completed_stage<>'completed'
       or new.profile_audit_event_id is null or new.completed_by_profile_id is null
       or new.completed_at is null or new.last_error_code is not null then
      raise exception 'sitaa_auth_operation_invalid_finalization' using errcode='23514';
    end if;
  else
    raise exception 'sitaa_auth_operation_prepare_update_forbidden' using errcode='23514';
  end if;
  return new;
end;
$function$;
revoke all on function public.guard_admin_auth_operation_b3a() from public,anon,authenticated,service_role;

create trigger guard_admin_auth_operation_b3a
before insert or update or delete on public.admin_auth_operations
for each row execute function public.guard_admin_auth_operation_b3a();
create trigger guard_admin_auth_operation_truncate_b3a
before truncate on public.admin_auth_operations
for each statement execute function public.guard_admin_auth_operation_b3a();

create function public.get_admin_account_auth_lifecycle_context_b3a(requested_profile_id uuid)
returns table(
  target_profile_id uuid,account_kind text,account_status text,is_self boolean,
  can_deactivate boolean,can_reactivate boolean,denial_code text,
  has_exact_b1_assignment boolean,active_exact_b1_admin_count bigint,
  current_or_future_assignment_count bigint,open_responsibility_count bigint,
  open_participation_count bigint,b3a_available boolean,current_operation_id uuid,
  operation_code text,operation_status text,completed_stage text,attempt_count integer,
  retryable boolean,last_error_code text,operation_updated_at timestamptz,
  can_retry_or_finalize boolean
)
language plpgsql
stable
security definer
set search_path=pg_catalog,public
as $function$
declare
  actor_id uuid:=auth.uid();
  base record;
  operation_row public.admin_auth_operations%rowtype;
begin
  if actor_id is null or not public.is_exact_b1_account_admin_profile_b2b(actor_id) then
    raise exception 'sitaa_admin_access_denied' using errcode='42501';
  end if;
  select * into base from public.get_admin_account_lifecycle_context_b2b(requested_profile_id);
  if not found then return; end if;
  select operation.* into operation_row
  from public.admin_auth_operations operation
  where operation.target_profile_id=requested_profile_id
  order by operation.requested_at desc,operation.id desc limit 1;
  return query select base.target_profile_id,base.account_kind,base.account_status,
    base.is_self,
    base.can_deactivate and (operation_row.id is null or operation_row.status in ('succeeded','terminal_failure')),
    base.can_reactivate and (operation_row.id is null or operation_row.status in ('succeeded','terminal_failure')),
    case when operation_row.id is not null and operation_row.status in ('open','processing','retryable_failure')
      then 'operation_in_progress' else base.denial_code end,
    base.has_exact_b1_assignment,base.active_exact_b1_admin_count,
    base.current_or_future_assignment_count,base.open_responsibility_count,
    base.open_participation_count,true,
    operation_row.id,operation_row.operation_code,operation_row.status,
    operation_row.completed_stage,coalesce(operation_row.attempt_count,0),
    coalesce(operation_row.status='retryable_failure',false),operation_row.last_error_code,
    operation_row.updated_at,
    coalesce(operation_row.id is not null and (
      operation_row.status in ('open','retryable_failure')
      or operation_row.status='processing' and (
        operation_row.completed_stage='auth_synchronized'
        or operation_row.processing_started_at<=statement_timestamp()-interval '5 minutes'
      )
    ),false);
end;
$function$;

create function public.prepare_admin_account_auth_lifecycle_b3a(
  requested_profile_id uuid,requested_transition text,transition_reason text,request_id uuid
)
returns table(
  operation_id uuid,target_profile_id uuid,operation_code text,status text,
  completed_stage text,attempt_count integer,retryable boolean,
  last_error_code text,updated_at timestamptz
)
language plpgsql
volatile
security definer
set search_path=pg_catalog,public
as $function$
declare
  actor_id uuid:=auth.uid();
  normalized_reason text:=nullif(btrim(regexp_replace(coalesce(transition_reason,''),'\s+',' ','g')),'');
  existing public.admin_auth_operations%rowtype;
  base record;
  lifecycle_result record;
  operation_timestamp timestamptz;
begin
  if actor_id is null or not public.is_exact_b1_account_admin_profile_b2b(actor_id) then
    raise exception 'sitaa_admin_access_denied' using errcode='42501';
  end if;
  if request_id is null then raise exception 'sitaa_auth_operation_request_id_required' using errcode='22023'; end if;
  if requested_transition is null
     or requested_transition not in ('deactivate','reactivate') then
    raise exception 'sitaa_account_lifecycle_invalid_transition' using errcode='22023';
  end if;
  if normalized_reason is null or char_length(normalized_reason) not between 10 and 1000 then raise exception 'sitaa_account_lifecycle_invalid_reason' using errcode='22023'; end if;
  if actor_id=requested_profile_id then raise exception 'sitaa_account_lifecycle_self_forbidden' using errcode='42501'; end if;

  perform pg_advisory_xact_lock(1397310529,9002);
  if not public.is_exact_b1_account_admin_profile_b2b(actor_id) then
    raise exception 'sitaa_admin_access_denied' using errcode='42501';
  end if;
  select operation.* into existing from public.admin_auth_operations operation where operation.request_id=$4 for update;
  if found then
    if existing.requested_by_profile_id is distinct from actor_id
       or existing.target_profile_id is distinct from requested_profile_id
       or existing.operation_code is distinct from requested_transition
       or existing.reason is distinct from normalized_reason then
      raise exception 'sitaa_auth_operation_request_id_conflict' using errcode='23505';
    end if;
    return query select existing.id,existing.target_profile_id,existing.operation_code,
      existing.status,existing.completed_stage,existing.attempt_count,
      existing.status='retryable_failure',existing.last_error_code,existing.updated_at;
    return;
  end if;

  select * into base from public.get_admin_account_lifecycle_context_b2b(requested_profile_id);
  if not found then raise exception 'sitaa_account_lifecycle_target_unavailable' using errcode='P0001'; end if;
  if base.account_status='pending_registration' then raise exception 'sitaa_account_lifecycle_pending_target' using errcode='P0001'; end if;
  if requested_transition='deactivate' and not base.can_deactivate
     or requested_transition='reactivate' and not base.can_reactivate then
    if base.denial_code='last_admin' then raise exception 'sitaa_account_lifecycle_last_admin_forbidden' using errcode='55000'; end if;
    if base.denial_code='invalid_identity' then raise exception 'sitaa_account_lifecycle_invalid_identity' using errcode='23514'; end if;
    if base.denial_code='auth_unconfirmed' then raise exception 'sitaa_account_lifecycle_auth_unconfirmed' using errcode='42501'; end if;
    raise exception 'sitaa_account_lifecycle_state_conflict' using errcode='55000';
  end if;
  if exists(select 1 from public.admin_auth_operations operation where operation.target_profile_id=requested_profile_id and operation.status in ('open','processing','retryable_failure')) then
    raise exception 'sitaa_auth_operation_target_busy' using errcode='55000';
  end if;

  if requested_transition='deactivate' then
    select * into lifecycle_result from public.transition_admin_account_lifecycle_b2b(
      requested_profile_id,'deactivate',normalized_reason
    );
    operation_timestamp:=clock_timestamp();
    perform set_config('sitaa.b3a_writer','prepare',true);
    insert into public.admin_auth_operations(
      request_id,requested_by_profile_id,target_profile_id,operation_code,reason,
      completed_stage,profile_audit_event_id,requested_at,updated_at
    ) values(
      $4,actor_id,requested_profile_id,requested_transition,normalized_reason,
      'profile_suspended',lifecycle_result.audit_event_id,operation_timestamp,operation_timestamp
    ) returning * into existing;
  else
    operation_timestamp:=clock_timestamp();
    perform set_config('sitaa.b3a_writer','prepare',true);
    insert into public.admin_auth_operations(
      request_id,requested_by_profile_id,target_profile_id,operation_code,reason,
      completed_stage,requested_at,updated_at
    ) values(
      $4,actor_id,requested_profile_id,requested_transition,normalized_reason,
      'prepared',operation_timestamp,operation_timestamp
    )
    returning * into existing;
  end if;
  perform set_config('sitaa.b3a_writer','',true);
  return query select existing.id,existing.target_profile_id,existing.operation_code,
    existing.status,existing.completed_stage,existing.attempt_count,false,
    existing.last_error_code,existing.updated_at;
end;
$function$;

create function public.claim_admin_auth_operation_b3a(
  requested_operation_id uuid,caller_profile_id uuid
)
returns table(
  operation_id uuid,target_profile_id uuid,operation_code text,status text,
  completed_stage text,attempt_count integer,retryable boolean,
  last_error_code text,updated_at timestamptz,claimed boolean
)
language plpgsql
volatile
security definer
set search_path=pg_catalog,public
as $function$
declare
  operation_row public.admin_auth_operations%rowtype;
  operation_timestamp timestamptz;
  operation_found boolean;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'sitaa_service_boundary_required' using errcode='42501'; end if;
  if caller_profile_id is null or not public.is_exact_b1_account_admin_profile_b2b(caller_profile_id) then raise exception 'sitaa_admin_access_denied' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(1397310529,9002);
  select operation.* into operation_row from public.admin_auth_operations operation where operation.id=requested_operation_id for update;
  operation_found:=found;
  if caller_profile_id is null or not public.is_exact_b1_account_admin_profile_b2b(caller_profile_id) then raise exception 'sitaa_admin_access_denied' using errcode='42501'; end if;
  if not operation_found then raise exception 'sitaa_auth_operation_unavailable' using errcode='P0001'; end if;
  operation_timestamp:=greatest(clock_timestamp(),operation_row.updated_at);
  if operation_row.status in ('succeeded','terminal_failure') then
    return query select operation_row.id,operation_row.target_profile_id,operation_row.operation_code,
      operation_row.status,operation_row.completed_stage,operation_row.attempt_count,
      false,operation_row.last_error_code,operation_row.updated_at,false;
    return;
  end if;
  if operation_row.status='processing'
     and operation_row.completed_stage<>'auth_synchronized'
     and operation_row.processing_started_at>operation_timestamp-interval '5 minutes' then
    return query select operation_row.id,operation_row.target_profile_id,operation_row.operation_code,
      operation_row.status,operation_row.completed_stage,operation_row.attempt_count,
      false,operation_row.last_error_code,operation_row.updated_at,false;
    return;
  end if;
  perform set_config('sitaa.b3a_writer','claim',true);
  update public.admin_auth_operations operation set status='processing',
    attempt_count=operation.attempt_count+1,processing_started_at=operation_timestamp,
    last_error_code=null,updated_at=operation_timestamp
  where operation.id=operation_row.id returning * into operation_row;
  perform set_config('sitaa.b3a_writer','',true);
  return query select operation_row.id,operation_row.target_profile_id,
    operation_row.operation_code,operation_row.status,operation_row.completed_stage,
    operation_row.attempt_count,false,operation_row.last_error_code,operation_row.updated_at,true;
end;
$function$;

create function public.record_admin_auth_operation_result_b3a(
  requested_operation_id uuid,caller_profile_id uuid,claimed_attempt_count integer,
  requested_result text,stable_error_code text
)
returns table(
  operation_id uuid,target_profile_id uuid,operation_code text,status text,completed_stage text,attempt_count integer,
  retryable boolean,last_error_code text,updated_at timestamptz
)
language plpgsql
volatile
security definer
set search_path=pg_catalog,public
as $function$
declare
  operation_row public.admin_auth_operations%rowtype;
  event_id uuid;
  action text;
  operation_timestamp timestamptz;
  operation_found boolean;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'sitaa_service_boundary_required' using errcode='42501'; end if;
  if caller_profile_id is null or not public.is_exact_b1_account_admin_profile_b2b(caller_profile_id) then raise exception 'sitaa_admin_access_denied' using errcode='42501'; end if;
  if requested_result is null or requested_result not in ('auth_succeeded','retryable_failure','terminal_failure') then
    raise exception 'sitaa_auth_operation_invalid_result' using errcode='22023';
  end if;
  if claimed_attempt_count is null or claimed_attempt_count<=0 then
    raise exception 'sitaa_auth_operation_invalid_attempt' using errcode='22023';
  end if;
  if requested_result='retryable_failure' and (
       stable_error_code is null
       or stable_error_code not in (
         'auth_temporarily_unavailable','auth_rate_limited','auth_user_not_found',
         'auth_update_rejected','unsupported_auth_contract','database_finalize_pending'
       )
     )
     or requested_result='terminal_failure' and (
       stable_error_code is null
       or stable_error_code not in ('auth_user_not_found','auth_update_rejected','unsupported_auth_contract')
     )
     or requested_result='auth_succeeded' and stable_error_code is not null then
    raise exception 'sitaa_auth_operation_invalid_error_code' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(1397310529,9002);
  select operation.* into operation_row from public.admin_auth_operations operation where operation.id=requested_operation_id for update;
  operation_found:=found;
  if caller_profile_id is null or not public.is_exact_b1_account_admin_profile_b2b(caller_profile_id) then raise exception 'sitaa_admin_access_denied' using errcode='42501'; end if;
  if not operation_found or operation_row.status<>'processing' then raise exception 'sitaa_auth_operation_not_processing' using errcode='55000'; end if;
  if claimed_attempt_count<>operation_row.attempt_count then
    raise exception 'sitaa_auth_operation_stale_attempt' using errcode='55000';
  end if;
  if requested_result='retryable_failure' and not (
       operation_row.completed_stage=case when operation_row.operation_code='reactivate' then 'prepared' else 'profile_suspended' end
         and operation_row.auth_audit_event_id is null
         and operation_row.auth_synchronized_at is null
         and stable_error_code in (
           'auth_temporarily_unavailable','auth_rate_limited','auth_user_not_found',
           'auth_update_rejected','unsupported_auth_contract'
         )
       or operation_row.operation_code='reactivate'
         and operation_row.completed_stage='auth_synchronized'
         and operation_row.auth_audit_event_id is not null
         and operation_row.auth_synchronized_at is not null
         and stable_error_code='database_finalize_pending'
     )
     or requested_result='terminal_failure' and not (
       operation_row.completed_stage=case when operation_row.operation_code='reactivate' then 'prepared' else 'profile_suspended' end
       and operation_row.auth_synchronized_at is null
       and stable_error_code in ('auth_user_not_found','auth_update_rejected','unsupported_auth_contract')
     ) then
    raise exception 'sitaa_auth_operation_error_stage_conflict' using errcode='55000';
  end if;
  operation_timestamp:=greatest(clock_timestamp(),operation_row.updated_at);
  perform set_config('sitaa.b3a_writer','record',true);

  if requested_result='auth_succeeded' then
    if operation_row.operation_code='deactivate' then
      if operation_row.completed_stage<>'profile_suspended' then raise exception 'sitaa_auth_operation_stage_conflict' using errcode='55000'; end if;
      insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,reason,role_assignment_id,metadata)
      values(caller_profile_id,operation_row.target_profile_id,'account_auth_suspended','success',operation_row.reason,null,
        jsonb_build_object('operation_id',operation_row.id,'operation_code',operation_row.operation_code,'changed_fields',jsonb_build_array('auth_access')))
      returning id into event_id;
      update public.admin_auth_operations operation set status='succeeded',completed_stage='completed',
        auth_audit_event_id=event_id,auth_synchronized_at=operation_timestamp,
        completed_at=operation_timestamp,completed_by_profile_id=caller_profile_id,
        last_error_code=null,updated_at=operation_timestamp
      where operation.id=operation_row.id returning * into operation_row;
    else
      if operation_row.completed_stage<>'prepared' then raise exception 'sitaa_auth_operation_stage_conflict' using errcode='55000'; end if;
      insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,reason,role_assignment_id,metadata)
      values(caller_profile_id,operation_row.target_profile_id,'account_auth_restored','success',operation_row.reason,null,
        jsonb_build_object('operation_id',operation_row.id,'operation_code',operation_row.operation_code,'changed_fields',jsonb_build_array('auth_access')))
      returning id into event_id;
      update public.admin_auth_operations operation set completed_stage='auth_synchronized',
        auth_audit_event_id=event_id,auth_synchronized_at=operation_timestamp,
        last_error_code=null,updated_at=operation_timestamp
      where operation.id=operation_row.id returning * into operation_row;
    end if;
  elsif requested_result='retryable_failure' then
    update public.admin_auth_operations operation set status='retryable_failure',
      last_error_code=stable_error_code,updated_at=operation_timestamp
    where operation.id=operation_row.id returning * into operation_row;
  else
    action:=case when operation_row.operation_code='deactivate' then 'account_auth_suspension_failed' else 'account_auth_restoration_failed' end;
    insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,reason,role_assignment_id,metadata)
    values(caller_profile_id,operation_row.target_profile_id,action,'failure',operation_row.reason,null,
      jsonb_build_object('operation_id',operation_row.id,'operation_code',operation_row.operation_code,'error_code',stable_error_code))
    returning id into event_id;
    update public.admin_auth_operations operation set status='terminal_failure',
      auth_audit_event_id=event_id,last_error_code=stable_error_code,
      completed_at=operation_timestamp,completed_by_profile_id=caller_profile_id,
      updated_at=operation_timestamp
    where operation.id=operation_row.id returning * into operation_row;
  end if;
  perform set_config('sitaa.b3a_writer','',true);
  return query select operation_row.id,operation_row.target_profile_id,operation_row.operation_code,
    operation_row.status,operation_row.completed_stage,
    operation_row.attempt_count,operation_row.status='retryable_failure',
    operation_row.last_error_code,operation_row.updated_at;
end;
$function$;

create function public.finalize_admin_account_auth_reactivation_b3a(requested_operation_id uuid)
returns table(
  operation_id uuid,target_profile_id uuid,status text,completed_stage text,
  profile_audit_event_id uuid,auth_audit_event_id uuid,completed_at timestamptz
)
language plpgsql
volatile
security definer
set search_path=pg_catalog,public
as $function$
declare
  actor_id uuid:=auth.uid();
  operation_row public.admin_auth_operations%rowtype;
  lifecycle_result record;
  operation_timestamp timestamptz;
  operation_found boolean;
begin
  if actor_id is null or not public.is_exact_b1_account_admin_profile_b2b(actor_id) then raise exception 'sitaa_admin_access_denied' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(1397310529,9002);
  select operation.* into operation_row from public.admin_auth_operations operation where operation.id=requested_operation_id for update;
  operation_found:=found;
  if not public.is_exact_b1_account_admin_profile_b2b(actor_id) then raise exception 'sitaa_admin_access_denied' using errcode='42501'; end if;
  if operation_found and operation_row.operation_code='reactivate' and operation_row.status='succeeded' then
    return query select operation_row.id,operation_row.target_profile_id,operation_row.status,
      operation_row.completed_stage,operation_row.profile_audit_event_id,
      operation_row.auth_audit_event_id,operation_row.completed_at;
    return;
  end if;
  if not operation_found or operation_row.operation_code<>'reactivate' or operation_row.status<>'processing' or operation_row.completed_stage<>'auth_synchronized' then
    raise exception 'sitaa_auth_operation_not_ready_to_finalize' using errcode='55000';
  end if;
  select * into lifecycle_result from public.transition_admin_account_lifecycle_b2b(operation_row.target_profile_id,'reactivate',operation_row.reason);
  operation_timestamp:=greatest(clock_timestamp(),operation_row.updated_at);
  perform set_config('sitaa.b3a_writer','finalize',true);
  update public.admin_auth_operations operation set status='succeeded',completed_stage='completed',
    profile_audit_event_id=lifecycle_result.audit_event_id,
    completed_by_profile_id=actor_id,completed_at=operation_timestamp,
    last_error_code=null,updated_at=operation_timestamp
  where operation.id=operation_row.id returning * into operation_row;
  perform set_config('sitaa.b3a_writer','',true);
  return query select operation_row.id,operation_row.target_profile_id,operation_row.status,
    operation_row.completed_stage,operation_row.profile_audit_event_id,
    operation_row.auth_audit_event_id,operation_row.completed_at;
end;
$function$;

alter function public.guard_admin_auth_operation_b3a() owner to postgres;
alter function public.get_admin_account_auth_lifecycle_context_b3a(uuid) owner to postgres;
alter function public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid) owner to postgres;
alter function public.finalize_admin_account_auth_reactivation_b3a(uuid) owner to postgres;
alter function public.claim_admin_auth_operation_b3a(uuid,uuid) owner to postgres;
alter function public.record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text) owner to postgres;

revoke all on function public.get_admin_account_auth_lifecycle_context_b3a(uuid) from public,anon,authenticated,service_role;
revoke all on function public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid) from public,anon,authenticated,service_role;
revoke all on function public.finalize_admin_account_auth_reactivation_b3a(uuid) from public,anon,authenticated,service_role;
revoke all on function public.claim_admin_auth_operation_b3a(uuid,uuid) from public,anon,authenticated,service_role;
revoke all on function public.record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text) from public,anon,authenticated,service_role;
grant execute on function public.get_admin_account_auth_lifecycle_context_b3a(uuid) to authenticated;
grant execute on function public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid) to authenticated;
grant execute on function public.finalize_admin_account_auth_reactivation_b3a(uuid) to authenticated;
grant execute on function public.claim_admin_auth_operation_b3a(uuid,uuid) to service_role;
grant execute on function public.record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text) to service_role;

-- 0010 elimina la invocación cliente directa del mutador B.2b.
revoke all on function public.transition_admin_account_lifecycle_b2b(uuid,text,text)
  from public,anon,authenticated,service_role;

-- Guardia post-DDL: todo el contrato debe estar presente antes del COMMIT.
do $post_ddl$
declare function_oid regprocedure;
begin
  if to_regclass('public.admin_auth_operations') is null
     or (select count(*) from information_schema.columns where table_schema='public' and table_name='admin_auth_operations')<>18
     or (select string_agg(column_name||':'||data_type||':'||is_nullable,'|' order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='admin_auth_operations')<>
       'id:uuid:NO|request_id:uuid:NO|requested_by_profile_id:uuid:NO|completed_by_profile_id:uuid:YES|target_profile_id:uuid:NO|operation_code:text:NO|status:text:NO|completed_stage:text:NO|reason:text:NO|attempt_count:integer:NO|last_error_code:text:YES|profile_audit_event_id:uuid:YES|auth_audit_event_id:uuid:YES|requested_at:timestamp with time zone:NO|processing_started_at:timestamp with time zone:YES|auth_synchronized_at:timestamp with time zone:YES|completed_at:timestamp with time zone:YES|updated_at:timestamp with time zone:NO'
     or (select string_agg(column_name||':'||coalesce(column_default,''),'|' order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='admin_auth_operations')<>
       'id:gen_random_uuid()|request_id:|requested_by_profile_id:|completed_by_profile_id:|target_profile_id:|operation_code:|status:''open''::text|completed_stage:''prepared''::text|reason:|attempt_count:0|last_error_code:|profile_audit_event_id:|auth_audit_event_id:|requested_at:now()|processing_started_at:|auth_synchronized_at:|completed_at:|updated_at:now()'
     or (select count(*) from pg_constraint where conrelid='public.admin_auth_operations'::regclass)<>16
     or (select string_agg(conname||':'||contype::text,'|' order by conname) from pg_constraint where conrelid='public.admin_auth_operations'::regclass)<>
       'admin_auth_operations_attempt_check:c|admin_auth_operations_auth_audit_event_id_fkey:f|admin_auth_operations_completed_by_profile_id_fkey:f|admin_auth_operations_error_check:c|admin_auth_operations_evidence_check:c|admin_auth_operations_operation_check:c|admin_auth_operations_pkey:p|admin_auth_operations_profile_audit_event_id_fkey:f|admin_auth_operations_reason_check:c|admin_auth_operations_request_id_key:u|admin_auth_operations_requested_by_profile_id_fkey:f|admin_auth_operations_stage_check:c|admin_auth_operations_stage_operation_check:c|admin_auth_operations_status_check:c|admin_auth_operations_target_profile_id_fkey:f|admin_auth_operations_timestamp_check:c'
     or exists (
       with expected(conname,contype,key_columns,referenced_table,referenced_columns,update_action,delete_action) as (
         values
           ('admin_auth_operations_pkey','p','id',null::oid,null::text,null::text,null::text),
           ('admin_auth_operations_request_id_key','u','request_id',null::oid,null::text,null::text,null::text),
           ('admin_auth_operations_requested_by_profile_id_fkey','f','requested_by_profile_id','public.profiles'::regclass::oid,'id','a','r'),
           ('admin_auth_operations_completed_by_profile_id_fkey','f','completed_by_profile_id','public.profiles'::regclass::oid,'id','a','r'),
           ('admin_auth_operations_target_profile_id_fkey','f','target_profile_id','public.profiles'::regclass::oid,'id','a','r'),
           ('admin_auth_operations_profile_audit_event_id_fkey','f','profile_audit_event_id','public.admin_audit_events'::regclass::oid,'id','a','r'),
           ('admin_auth_operations_auth_audit_event_id_fkey','f','auth_audit_event_id','public.admin_audit_events'::regclass::oid,'id','a','r')
       )
       select 1
       from expected
       left join pg_constraint constraint_definition
         on constraint_definition.conrelid='public.admin_auth_operations'::regclass
        and constraint_definition.conname=expected.conname
       where constraint_definition.oid is null
          or constraint_definition.contype::text<>expected.contype
          or constraint_definition.condeferrable
          or constraint_definition.condeferred
          or not constraint_definition.convalidated
          or (select string_agg(attribute_definition.attname,',' order by key_column.ordinality)
              from unnest(constraint_definition.conkey) with ordinality key_column(attnum,ordinality)
              join pg_attribute attribute_definition
                on attribute_definition.attrelid=constraint_definition.conrelid
               and attribute_definition.attnum=key_column.attnum)<>expected.key_columns
          or expected.referenced_table is not null and (
               constraint_definition.confrelid<>expected.referenced_table
            or constraint_definition.confupdtype::text<>expected.update_action
            or constraint_definition.confdeltype::text<>expected.delete_action
            or constraint_definition.confmatchtype<>'s'
            or (select string_agg(attribute_definition.attname,',' order by key_column.ordinality)
                from unnest(constraint_definition.confkey) with ordinality key_column(attnum,ordinality)
                join pg_attribute attribute_definition
                  on attribute_definition.attrelid=constraint_definition.confrelid
                 and attribute_definition.attnum=key_column.attnum)<>expected.referenced_columns
          )
     )
     or (select count(*) from pg_indexes where schemaname='public' and tablename='admin_auth_operations')<>5
     or (select string_agg(indexname,'|' order by indexname) from pg_indexes where schemaname='public' and tablename='admin_auth_operations')<>
       'admin_auth_operations_actor_requested_idx|admin_auth_operations_one_nonfinal_target_uidx|admin_auth_operations_pkey|admin_auth_operations_request_id_key|admin_auth_operations_target_status_idx'
     or exists (
       with expected(indexname,indexdef) as (
         values
           ('admin_auth_operations_actor_requested_idx','CREATE INDEX admin_auth_operations_actor_requested_idx ON public.admin_auth_operations USING btree (requested_by_profile_id, requested_at DESC, id DESC)'),
           ('admin_auth_operations_one_nonfinal_target_uidx','CREATE UNIQUE INDEX admin_auth_operations_one_nonfinal_target_uidx ON public.admin_auth_operations USING btree (target_profile_id) WHERE (status = ANY (ARRAY[''open''::text, ''processing''::text, ''retryable_failure''::text]))'),
           ('admin_auth_operations_pkey','CREATE UNIQUE INDEX admin_auth_operations_pkey ON public.admin_auth_operations USING btree (id)'),
           ('admin_auth_operations_request_id_key','CREATE UNIQUE INDEX admin_auth_operations_request_id_key ON public.admin_auth_operations USING btree (request_id)'),
           ('admin_auth_operations_target_status_idx','CREATE INDEX admin_auth_operations_target_status_idx ON public.admin_auth_operations USING btree (target_profile_id, status, updated_at DESC)')
       )
       (select * from expected except
        select indexname,indexdef from pg_indexes where schemaname='public' and tablename='admin_auth_operations')
       union all
       (select indexname,indexdef from pg_indexes where schemaname='public' and tablename='admin_auth_operations'
        except select * from expected)
     )
     or to_regclass('public.admin_auth_operations_request_id_'||'uidx') is not null
     or not exists (
       select 1
       from pg_constraint constraint_definition
       join pg_index index_definition on index_definition.indexrelid=constraint_definition.conindid
       where constraint_definition.conrelid='public.admin_auth_operations'::regclass
         and constraint_definition.conname='admin_auth_operations_request_id_key'
         and constraint_definition.contype='u'
         and constraint_definition.conindid='public.admin_auth_operations_request_id_key'::regclass
         and index_definition.indrelid='public.admin_auth_operations'::regclass
         and index_definition.indisunique
         and index_definition.indisvalid
         and index_definition.indisready
         and not index_definition.indisprimary
         and index_definition.indpred is null
         and index_definition.indexprs is null
         and index_definition.indnkeyatts=1
         and index_definition.indnatts=1
         and (select string_agg(attribute_definition.attname,',' order by key_column.ordinality)
              from unnest(index_definition.indkey::smallint[]) with ordinality key_column(attnum,ordinality)
              join pg_attribute attribute_definition
                on attribute_definition.attrelid=index_definition.indrelid
               and attribute_definition.attnum=key_column.attnum)='request_id'
     )
     or (select count(*) from pg_trigger where tgrelid='public.admin_auth_operations'::regclass and not tgisinternal)<>2
     or (select string_agg(tgname||':'||tgtype::text||':'||tgenabled::text||':'||tgfoid::regprocedure::text,'|' order by tgname) from pg_trigger where tgrelid='public.admin_auth_operations'::regclass and not tgisinternal)<>
       'guard_admin_auth_operation_b3a:31:O:guard_admin_auth_operation_b3a()|guard_admin_auth_operation_truncate_b3a:34:O:guard_admin_auth_operation_b3a()'
     or exists (
       with expected(tgname,definition) as (
         values
           ('guard_admin_auth_operation_b3a','CREATE TRIGGER guard_admin_auth_operation_b3a BEFORE INSERT OR DELETE OR UPDATE ON admin_auth_operations FOR EACH ROW EXECUTE FUNCTION guard_admin_auth_operation_b3a()'),
           ('guard_admin_auth_operation_truncate_b3a','CREATE TRIGGER guard_admin_auth_operation_truncate_b3a BEFORE TRUNCATE ON admin_auth_operations FOR EACH STATEMENT EXECUTE FUNCTION guard_admin_auth_operation_b3a()')
       )
       (select * from expected except
        select tgname,pg_get_triggerdef(oid,true) from pg_trigger where tgrelid='public.admin_auth_operations'::regclass and not tgisinternal)
       union all
       (select tgname,pg_get_triggerdef(oid,true) from pg_trigger where tgrelid='public.admin_auth_operations'::regclass and not tgisinternal
        except select * from expected)
     )
     or not (select relrowsecurity from pg_class where oid='public.admin_auth_operations'::regclass)
     or (select count(*) from pg_policies where schemaname='public' and tablename='admin_auth_operations')<>0 then
    raise exception 'sitaa_0010_post_ddl_table_contract_mismatch';
  end if;
  if not exists (
      select 1 from pg_class table_definition
      where table_definition.oid='public.admin_auth_operations'::regclass
        and pg_get_userbyid(table_definition.relowner)='postgres'
        and (select count(*) from aclexplode(table_definition.relacl) acl
             where acl.grantee=table_definition.relowner
               and upper(acl.privilege_type) in ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN')
               and not acl.is_grantable)=8
        and (select count(*) from aclexplode(table_definition.relacl))=8
        and not exists(
          select 1 from pg_attribute attribute_definition
          where attribute_definition.attrelid=table_definition.oid
            and attribute_definition.attnum>0 and not attribute_definition.attisdropped
            and attribute_definition.attacl is not null
            and exists(select 1 from aclexplode(attribute_definition.attacl))
        )
     ) then
    raise exception 'sitaa_0010_post_ddl_table_acl_mismatch';
  end if;
  foreach function_oid in array array[
    'public.guard_admin_auth_operation_b3a()'::regprocedure,
    'public.get_admin_account_auth_lifecycle_context_b3a(uuid)'::regprocedure,
    'public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)'::regprocedure,
    'public.finalize_admin_account_auth_reactivation_b3a(uuid)'::regprocedure,
    'public.claim_admin_auth_operation_b3a(uuid,uuid)'::regprocedure,
    'public.record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text)'::regprocedure
  ] loop
     if not (select p.prosecdef and p.proconfig=array['search_path=pg_catalog, public']::text[] and pg_get_userbyid(p.proowner)='postgres' and l.lanname='plpgsql' from pg_proc p join pg_language l on l.oid=p.prolang where p.oid=function_oid) then
       raise exception 'sitaa_0010_post_ddl_function_contract_mismatch:%',function_oid;
     end if;
  end loop;
  if (select pg_get_function_identity_arguments(p.oid) from pg_proc p where p.oid='public.guard_admin_auth_operation_b3a()'::regprocedure)<>''
     or (select pg_get_function_identity_arguments(p.oid) from pg_proc p where p.oid='public.get_admin_account_auth_lifecycle_context_b3a(uuid)'::regprocedure)<>'requested_profile_id uuid'
     or (select pg_get_function_identity_arguments(p.oid) from pg_proc p where p.oid='public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)'::regprocedure)<>'requested_profile_id uuid, requested_transition text, transition_reason text, request_id uuid'
     or (select pg_get_function_identity_arguments(p.oid) from pg_proc p where p.oid='public.finalize_admin_account_auth_reactivation_b3a(uuid)'::regprocedure)<>'requested_operation_id uuid'
     or (select pg_get_function_identity_arguments(p.oid) from pg_proc p where p.oid='public.claim_admin_auth_operation_b3a(uuid,uuid)'::regprocedure)<>'requested_operation_id uuid, caller_profile_id uuid'
     or (select pg_get_function_identity_arguments(p.oid) from pg_proc p where p.oid='public.record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text)'::regprocedure)<>'requested_operation_id uuid, caller_profile_id uuid, claimed_attempt_count integer, requested_result text, stable_error_code text'
     or (select p.provolatile from pg_proc p where p.oid='public.get_admin_account_auth_lifecycle_context_b3a(uuid)'::regprocedure)<>'s'
     or exists(select 1 from pg_proc p where p.oid in (
       'public.guard_admin_auth_operation_b3a()'::regprocedure,
       'public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)'::regprocedure,
       'public.finalize_admin_account_auth_reactivation_b3a(uuid)'::regprocedure,
       'public.claim_admin_auth_operation_b3a(uuid,uuid)'::regprocedure,
       'public.record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text)'::regprocedure
     ) and p.provolatile<>'v') then
    raise exception 'sitaa_0010_post_ddl_function_signature_mismatch';
  end if;
  if pg_get_function_result('public.guard_admin_auth_operation_b3a()'::regprocedure)<>'trigger'
     or pg_get_function_result('public.get_admin_account_auth_lifecycle_context_b3a(uuid)'::regprocedure)<>
       'TABLE(target_profile_id uuid, account_kind text, account_status text, is_self boolean, can_deactivate boolean, can_reactivate boolean, denial_code text, has_exact_b1_assignment boolean, active_exact_b1_admin_count bigint, current_or_future_assignment_count bigint, open_responsibility_count bigint, open_participation_count bigint, b3a_available boolean, current_operation_id uuid, operation_code text, operation_status text, completed_stage text, attempt_count integer, retryable boolean, last_error_code text, operation_updated_at timestamp with time zone, can_retry_or_finalize boolean)'
     or pg_get_function_result('public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)'::regprocedure)<>
       'TABLE(operation_id uuid, target_profile_id uuid, operation_code text, status text, completed_stage text, attempt_count integer, retryable boolean, last_error_code text, updated_at timestamp with time zone)'
     or pg_get_function_result('public.claim_admin_auth_operation_b3a(uuid,uuid)'::regprocedure)<>
       'TABLE(operation_id uuid, target_profile_id uuid, operation_code text, status text, completed_stage text, attempt_count integer, retryable boolean, last_error_code text, updated_at timestamp with time zone, claimed boolean)'
     or pg_get_function_result('public.record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text)'::regprocedure)<>
       'TABLE(operation_id uuid, target_profile_id uuid, operation_code text, status text, completed_stage text, attempt_count integer, retryable boolean, last_error_code text, updated_at timestamp with time zone)'
     or pg_get_function_result('public.finalize_admin_account_auth_reactivation_b3a(uuid)'::regprocedure)<>
       'TABLE(operation_id uuid, target_profile_id uuid, status text, completed_stage text, profile_audit_event_id uuid, auth_audit_event_id uuid, completed_at timestamp with time zone)' then
    raise exception 'sitaa_0010_post_ddl_function_result_mismatch';
  end if;
  if exists (
    select 1 from (values
      ('guard_admin_auth_operation_b3a()','b4f997c0089a103737539c380c0c05d1'),
      ('get_admin_account_auth_lifecycle_context_b3a(uuid)','44fd317ebc207cbf572551835fb9be7d'),
      ('prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)','2d8d580677411110fb9255fcced4c715'),
      ('claim_admin_auth_operation_b3a(uuid,uuid)','f100545d885836bdfcc6c6f71063f709'),
      ('record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text)','0aa2e5f2d1399b086b7223dc7193c61a'),
      ('finalize_admin_account_auth_reactivation_b3a(uuid)','496707f95d11ca6d9b75c1b3f43a3c6b')
    ) expected(signature,body_hash)
    left join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
    where p.oid is null or md5(regexp_replace(p.prosrc,'\s+','','g'))<>expected.body_hash
  ) then
    raise exception 'sitaa_0010_post_ddl_function_body_mismatch';
  end if;
  if exists (
       with expected(function_oid,grantee) as (
         values
           ('public.guard_admin_auth_operation_b3a()'::regprocedure::oid,'postgres'::regrole::oid),
           ('public.get_admin_account_auth_lifecycle_context_b3a(uuid)'::regprocedure::oid,'postgres'::regrole::oid),
           ('public.get_admin_account_auth_lifecycle_context_b3a(uuid)'::regprocedure::oid,'authenticated'::regrole::oid),
           ('public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)'::regprocedure::oid,'postgres'::regrole::oid),
           ('public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)'::regprocedure::oid,'authenticated'::regrole::oid),
           ('public.finalize_admin_account_auth_reactivation_b3a(uuid)'::regprocedure::oid,'postgres'::regrole::oid),
           ('public.finalize_admin_account_auth_reactivation_b3a(uuid)'::regprocedure::oid,'authenticated'::regrole::oid),
           ('public.claim_admin_auth_operation_b3a(uuid,uuid)'::regprocedure::oid,'postgres'::regrole::oid),
           ('public.claim_admin_auth_operation_b3a(uuid,uuid)'::regprocedure::oid,'service_role'::regrole::oid),
           ('public.record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text)'::regprocedure::oid,'postgres'::regrole::oid),
           ('public.record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text)'::regprocedure::oid,'service_role'::regrole::oid)
       ), actual(function_oid,grantee) as (
         select p.oid,acl.grantee
         from pg_proc p
         cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
         where p.oid in (select expected.function_oid from expected)
           and acl.privilege_type='EXECUTE' and not acl.is_grantable
       )
       (select * from expected except select * from actual)
       union all
       (select * from actual except select * from expected)
     )
     or exists (
       select 1
       from pg_proc p
       cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
       where p.oid in (
         'public.guard_admin_auth_operation_b3a()'::regprocedure,
         'public.get_admin_account_auth_lifecycle_context_b3a(uuid)'::regprocedure,
         'public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)'::regprocedure,
         'public.finalize_admin_account_auth_reactivation_b3a(uuid)'::regprocedure,
         'public.claim_admin_auth_operation_b3a(uuid,uuid)'::regprocedure,
         'public.record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text)'::regprocedure
       ) and (acl.privilege_type<>'EXECUTE' or acl.is_grantable)
     )
     or has_function_privilege('authenticated','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or has_function_privilege('anon','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or has_function_privilege('service_role','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or (select count(*) from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where p.oid='public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure and acl.privilege_type='EXECUTE' and acl.grantee=p.proowner and not acl.is_grantable)<>1
     or exists(select 1 from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where p.oid='public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure and (acl.privilege_type<>'EXECUTE' or acl.grantee<>p.proowner or acl.is_grantable)) then
     raise exception 'sitaa_0010_post_ddl_acl_mismatch';
  end if;
  if (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>60
     or (select count(*) from information_schema.tables where table_schema='public' and table_type='BASE TABLE')<>19
     or (select count(*) from information_schema.columns where table_schema='public')<>183
     or (select count(*) from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname='public' and c.contype in ('p','f','u','c'))<>96
     or (select count(*) from pg_indexes where schemaname='public')<>48
     or (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal)<>13
     or (select count(*) from pg_policies where schemaname='public')<>25
     or (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and c.relrowsecurity)<>19
     or (select count(*) from information_schema.routine_privileges where routine_schema='public')<>147
     or (select count(*) from information_schema.table_privileges where table_schema='public')<>274
     or (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault('s',c.relowner))) acl where n.nspname='public' and c.relkind='S')<>6
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where n.nspname='public')+
        (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault(case when c.relkind='S' then 's'::"char" else 'r'::"char" end,c.relowner))) acl where n.nspname='public' and c.relkind in ('r','p','v','m','S'))<>463 then
    raise exception 'sitaa_0010_post_ddl_inventory_mismatch';
  end if;

  if current_setting('sitaa_0010.default_acl_hash',true) is distinct from
       (select md5(coalesce(string_agg(defaclrole::text||':'||defaclnamespace::text||':'||defaclobjtype::text||':'||defaclacl::text,'|' order by defaclrole,defaclnamespace,defaclobjtype),'')) from pg_default_acl)
     or current_setting('sitaa_0010.prior_function_metadata_hash',true) is distinct from
       (select md5(coalesce(string_agg(p.oid::regprocedure::text||':'||pg_get_userbyid(p.proowner)||':'||l.lanname||':'||p.provolatile::text||':'||p.prosecdef::text||':'||coalesce(p.proconfig::text,''),'|' order by p.oid::regprocedure::text),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where n.nspname='public' and p.proname not in ('guard_admin_auth_operation_b3a','get_admin_account_auth_lifecycle_context_b3a','prepare_admin_account_auth_lifecycle_b3a','finalize_admin_account_auth_reactivation_b3a','claim_admin_auth_operation_b3a','record_admin_auth_operation_result_b3a'))
     or current_setting('sitaa_0010.prior_function_body_hash',true) is distinct from
       (select md5(coalesce(string_agg(p.oid::regprocedure::text||':'||md5(regexp_replace(p.prosrc,'\s+','','g')),'|' order by p.oid::regprocedure::text),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname not in ('guard_admin_auth_operation_b3a','get_admin_account_auth_lifecycle_context_b3a','prepare_admin_account_auth_lifecycle_b3a','finalize_admin_account_auth_reactivation_b3a','claim_admin_auth_operation_b3a','record_admin_auth_operation_result_b3a'))
     or current_setting('sitaa_0010.prior_function_acl_hash',true) is distinct from
       (select md5(coalesce(string_agg(p.oid::regprocedure::text||':'||acl.grantor::text||':'||acl.grantee::text||':'||acl.privilege_type||':'||acl.is_grantable::text,'|' order by p.oid::regprocedure::text,acl.grantor,acl.grantee,acl.privilege_type),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where n.nspname='public' and p.oid<>'public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure and p.proname not in ('guard_admin_auth_operation_b3a','get_admin_account_auth_lifecycle_context_b3a','prepare_admin_account_auth_lifecycle_b3a','finalize_admin_account_auth_reactivation_b3a','claim_admin_auth_operation_b3a','record_admin_auth_operation_result_b3a'))
     or current_setting('sitaa_0010.prior_table_column_acl_hash',true) is distinct from md5(
       coalesce((select string_agg(table_name||':'||grantor||':'||grantee||':'||privilege_type||':'||is_grantable,'|' order by table_name,grantor,grantee,privilege_type) from information_schema.table_privileges where table_schema='public' and table_name<>'admin_auth_operations'),'')
       ||'#'||coalesce((select string_agg(attrelid::text||':'||attnum::text||':'||attacl::text,'|' order by attrelid,attnum) from pg_attribute where attrelid in (select c.oid from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname<>'admin_auth_operations') and attnum>0 and not attisdropped and attacl is not null),'')
     )
     or current_setting('sitaa_0010.prior_sequence_acl_hash',true) is distinct from
       (select md5(coalesce(string_agg(c.relname||':'||acl.grantor::text||':'||acl.grantee::text||':'||acl.privilege_type||':'||acl.is_grantable::text,'|' order by c.relname,acl.grantor,acl.grantee,acl.privilege_type),'')) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault('s',c.relowner))) acl where n.nspname='public' and c.relkind='S')
     or current_setting('sitaa_0010.prior_column_hash',true) is distinct from
       (select md5(coalesce(string_agg(table_name||':'||ordinal_position::text||':'||column_name||':'||data_type||':'||udt_name||':'||is_nullable||':'||coalesce(column_default,'')||':'||coalesce(character_maximum_length::text,'')||':'||coalesce(numeric_precision::text,'')||':'||coalesce(numeric_scale::text,'')||':'||coalesce(datetime_precision::text,''),'|' order by table_name,ordinal_position),'')) from information_schema.columns where table_schema='public' and table_name<>'admin_auth_operations')
     or current_setting('sitaa_0010.prior_constraint_hash',true) is distinct from
       (select md5(coalesce(string_agg(table_definition.relname||':'||constraint_definition.conname||':'||case constraint_definition.contype when 'p' then 'primary_key' when 'f' then 'foreign_key' when 'u' then 'unique' when 'c' then 'check' end||':'||pg_get_constraintdef(constraint_definition.oid,true),'|' order by table_definition.relname,constraint_definition.conname),'')) from pg_constraint constraint_definition join pg_class table_definition on table_definition.oid=constraint_definition.conrelid join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace where namespace_definition.nspname='public' and table_definition.relname<>'admin_auth_operations' and constraint_definition.contype in ('p','f','u','c'))
     or current_setting('sitaa_0010.prior_index_hash',true) is distinct from
       (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||indexname||':'||indexdef,'|' order by schemaname,tablename,indexname),'')) from pg_indexes where schemaname='public' and tablename<>'admin_auth_operations')
     or current_setting('sitaa_0010.prior_trigger_hash',true) is distinct from
       (select md5(coalesce(string_agg(table_definition.relname||':'||trigger_definition.tgname||':'||pg_get_triggerdef(trigger_definition.oid,true),'|' order by table_definition.relname,trigger_definition.tgname),'')) from pg_trigger trigger_definition join pg_class table_definition on table_definition.oid=trigger_definition.tgrelid join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace where namespace_definition.nspname='public' and table_definition.relname<>'admin_auth_operations' and not trigger_definition.tgisinternal) then
    raise exception 'sitaa_0010_post_ddl_prior_map_or_default_acl_mismatch';
  end if;
  if (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||policyname||':'||permissive||':'||roles::text||':'||cmd||':'||coalesce(qual,'')||':'||coalesce(with_check,''),'|' order by schemaname,tablename,policyname),'')) from pg_policies where schemaname='public')<>'a72df97fbb8e73d8445f7fe8765da4ba'
     or not (
       with controlled_seed_rows(catalog,row_json) as (
         select 'academic_periods',to_jsonb(seed)::text from public.academic_periods seed union all
         select 'academic_programs',to_jsonb(seed)::text from public.academic_programs seed union all
         select 'activity_modalities',to_jsonb(seed)::text from public.activity_modalities seed union all
         select 'activity_statuses',to_jsonb(seed)::text from public.activity_statuses seed union all
         select 'activity_types',to_jsonb(seed)::text from public.activity_types seed union all
         select 'attention_categories',to_jsonb(seed)::text from public.attention_categories seed union all
         select 'divisions',to_jsonb(seed)::text from public.divisions seed union all
         select 'location_types',to_jsonb(seed)::text from public.location_types seed union all
         select 'participant_roles',to_jsonb(seed)::text from public.participant_roles seed union all
         select 'roles',to_jsonb(seed)::text from public.roles seed union all
         select 'service_types',to_jsonb(seed)::text from public.service_types seed
       )
       select count(*)=51 and md5(string_agg(catalog||E'\t'||row_json,E'\n' order by catalog,row_json))='2e450238768fbe9889470864a1832486'
       from controlled_seed_rows
     ) then
    raise exception 'sitaa_0010_post_ddl_policy_or_seed_mismatch';
  end if;
  if (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_created')<>1
     or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_created' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgenabled='O' and trigger_definition.tgtype=5::smallint and trigger_definition.tgfoid=to_regprocedure('public.handle_sitaa_auth_user_created()') and cardinality(trigger_definition.tgattr::smallint[])=0 and trigger_definition.tgqual is null)<>1
     or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_email_changed')<>1
     or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_email_changed' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgenabled='O' and trigger_definition.tgtype=17::smallint and trigger_definition.tgfoid=to_regprocedure('public.sync_sitaa_profile_email_from_auth()') and cardinality(trigger_definition.tgattr::smallint[])=1 and trigger_definition.tgqual is not null and (select count(*) from unnest(trigger_definition.tgattr::smallint[]) update_attribute(attnum) join pg_attribute attribute_definition on attribute_definition.attrelid=trigger_definition.tgrelid and attribute_definition.attnum=update_attribute.attnum and attribute_definition.attname='email' and not attribute_definition.attisdropped)=1 and regexp_replace(regexp_replace(split_part(split_part(lower(pg_get_triggerdef(trigger_definition.oid,false)),' when ',2),' execute function ',1),'[[:space:]()]','','g'),'::text','','g')='old.emailisdistinctfromnew.email')<>1 then
    raise exception 'sitaa_0010_post_ddl_auth_trigger_mismatch';
  end if;
end;
$post_ddl$;

commit;
