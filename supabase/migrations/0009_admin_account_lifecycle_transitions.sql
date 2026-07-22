-- SITAA 0009: transiciones administrativas del ciclo de vida de cuentas.
-- Revisar preflight, verificador y plan manual antes de aplicar.

begin;

set local time zone 'UTC';
set local datestyle to 'ISO, MDY';

-- Preflight bloqueante: 0008 debe ser el estado canónico y 0009 no debe existir.
do $preflight$
declare
  mismatch_count integer:=0;
begin
  select count(*) into mismatch_count
  from (
    select 1 where (select count(*) from information_schema.tables where table_schema='public' and table_type='BASE TABLE')<>18
    union all select 1 where (select count(*) from information_schema.columns where table_schema='public')<>165
    union all select 1 where (select count(*) from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname='public' and c.contype in ('p','f','u','c'))<>80
    union all select 1 where (select count(*) from pg_indexes where schemaname='public')<>43
    union all select 1 where (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal)<>11
    union all select 1 where (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>51
    union all select 1 where (select count(*) from pg_policies where schemaname='public')<>25
    union all select 1 where (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and c.relrowsecurity)<>18
    union all select 1 where (select count(*) from information_schema.routine_privileges where routine_schema='public')<>132
    union all select 1 where (select count(*) from information_schema.table_privileges where table_schema='public')<>267
    union all select 1 where (select count(*) from information_schema.usage_privileges where object_schema='public' and object_type='SEQUENCE')<>6
    union all select 1 where (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public') + (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault(case when c.relkind='S' then 's'::"char" else 'r'::"char" end,c.relowner))) a where n.nspname='public' and c.relkind in ('r','p','v','m','S'))<>440
    union all select 1 where (select md5(coalesce(string_agg(p.oid::regprocedure::text,'|' order by p.oid::regprocedure::text),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>'7f2ecc4f95b05b5ea44413773bdc8e71'
    union all select 1 where (select md5(coalesce(string_agg(p.oid::regprocedure::text||':'||md5(regexp_replace(p.prosrc,'\s+','','g')),'|' order by p.oid::regprocedure::text),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>'43f89f8dba9ff02bb3c3f47dcee25af2'
    union all select 1 where (select md5(coalesce(string_agg(table_name||':'||ordinal_position::text||':'||column_name||':'||data_type||':'||udt_name||':'||is_nullable||':'||coalesce(column_default,'')||':'||coalesce(character_maximum_length::text,'')||':'||coalesce(numeric_precision::text,'')||':'||coalesce(numeric_scale::text,'')||':'||coalesce(datetime_precision::text,''),'|' order by table_name,ordinal_position),'')) from information_schema.columns where table_schema='public')<>'847b9f5c4ec9d428c522f714de59fd1f'
    union all select 1 where (select md5(coalesce(string_agg(table_definition.relname||':'||constraint_definition.conname||':'||case constraint_definition.contype when 'p' then 'primary_key' when 'f' then 'foreign_key' when 'u' then 'unique' when 'c' then 'check' end||':'||pg_get_constraintdef(constraint_definition.oid),'|' order by table_definition.relname,constraint_definition.conname),'')) from pg_constraint constraint_definition join pg_class table_definition on table_definition.oid=constraint_definition.conrelid join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace where namespace_definition.nspname='public' and constraint_definition.contype in ('p','f','u','c'))<>'64f099164063d0cf500478dda3b5d25c'
    union all select 1 where (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||indexname||':'||indexdef,'|' order by schemaname,tablename,indexname),'')) from pg_indexes where schemaname='public')<>'653875a8435cf43bda4fe55950f65802'
    union all select 1 where not (
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
      select count(*)=51
        and count(*) filter(where catalog='academic_periods')=5
        and count(*) filter(where catalog='academic_programs')=2
        and count(*) filter(where catalog='activity_modalities')=3
        and count(*) filter(where catalog='activity_statuses')=6
        and count(*) filter(where catalog='activity_types')=5
        and count(*) filter(where catalog='attention_categories')=5
        and count(*) filter(where catalog='divisions')=1
        and count(*) filter(where catalog='location_types')=7
        and count(*) filter(where catalog='participant_roles')=5
        and count(*) filter(where catalog='roles')=10
        and count(*) filter(where catalog='service_types')=2
        and md5(string_agg(catalog||E'\t'||row_json,E'\n' order by catalog,row_json))='2e450238768fbe9889470864a1832486'
      from controlled_seed_rows
    )
    union all select 1 where (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||policyname||':'||permissive||':'||roles::text||':'||cmd||':'||coalesce(qual,'')||':'||coalesce(with_check,''),'|' order by schemaname,tablename,policyname),'')) from pg_policies where schemaname='public')<>'a72df97fbb8e73d8445f7fe8765da4ba'
    union all select 1 where (select md5(coalesce(string_agg(table_definition.relname||':'||trigger_definition.tgname||':'||pg_get_triggerdef(trigger_definition.oid,false),'|' order by table_definition.relname,trigger_definition.tgname),'')) from pg_trigger trigger_definition join pg_class table_definition on table_definition.oid=trigger_definition.tgrelid join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace where namespace_definition.nspname='public' and not trigger_definition.tgisinternal)<>'67ee47bcd43c0594129facf3d7729bad'
    union all select 1 where (select md5(coalesce(string_agg(table_name||':'||privilege_type,'|' order by table_name,privilege_type),'')) from information_schema.role_table_grants where table_schema='public' and grantee='authenticated')<>'017b6a7c8048ffdfdc0b7d7319b59a92'
    union all select 1 where not exists (select 1 from pg_class table_definition where table_definition.oid='public.activity_participants'::regclass and (select count(*) from aclexplode(table_definition.relacl) acl where acl.grantee=table_definition.relowner and upper(acl.privilege_type) in ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN') and not acl.is_grantable)=8 and (select count(*) from aclexplode(table_definition.relacl) acl where acl.grantee='service_role'::regrole and upper(acl.privilege_type) in ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN') and not acl.is_grantable)=8 and (select count(*) from aclexplode(table_definition.relacl) acl where acl.grantee='authenticated'::regrole and upper(acl.privilege_type)='SELECT' and not acl.is_grantable)=1 and (select count(*) from aclexplode(table_definition.relacl))=17 and not exists(select 1 from pg_attribute attribute_definition where attribute_definition.attrelid=table_definition.oid and attribute_definition.attnum>0 and not attribute_definition.attisdropped and attribute_definition.attacl is not null and exists(select 1 from aclexplode(attribute_definition.attacl))))
    union all select 1 where to_regprocedure('public.is_b1_account_admin()') is null
    union all select 1 where to_regprocedure('public.sitaa_current_mexico_date()') is null
    union all select 1 where to_regprocedure('public.activity_has_ended(uuid)') is null
    union all select 1 where to_regclass('public.admin_audit_events') is null
    union all select 1 where to_regprocedure('public.is_exact_b1_account_admin_profile_b2b(uuid)') is not null or to_regprocedure('public.get_admin_account_lifecycle_context_b2b(uuid)') is not null or to_regprocedure('public.transition_admin_account_lifecycle_b2b(uuid,text,text)') is not null
    union all select 1 where not exists (select 1 from pg_constraint where conrelid='public.admin_audit_events'::regclass and conname='admin_audit_events_action_code_check' and pg_get_constraintdef(oid)='CHECK (char_length(action_code) >= 1 AND char_length(action_code) <= 100 AND action_code ~ ''^[a-z][a-z0-9]*(_[a-z0-9]+)*$''::text)')
    union all select 1 where exists (select 1 from public.profiles where account_status not in ('pending_registration','active','inactive') or account_kind not in ('institutional','technical'))
      or exists (
        select 1 from (values
          ('is_sitaa_operational_account_active()','f85f733578f09c0f7466af7e18a90f4c'),
          ('get_admin_identity_correction_context_b2a(uuid)','83932d04ff8f1b33793e8c7a49bb8e68'),
          ('correct_admin_account_identity_b2a(uuid,text,text,text,text,text,uuid,text)','ce05cbc529473c070953e765e3ee05b2'),
          ('enforce_activity_writer_integrity_b2a()','c58bd04859f1e2a044fcca58d3333e3c')
        ) expected(signature,body_hash)
        left join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
        where p.oid is null or md5(regexp_replace(p.prosrc,'\s+','','g'))<>expected.body_hash
      )
    union all select 1 where
      (select string_agg(column_name||':'||data_type||':'||is_nullable||':'||coalesce(column_default,''),'|' order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='profiles')<>'id:uuid:NO:|email:text:NO:|full_name:text:YES:|primary_program_id:uuid:YES:|is_active:boolean:NO:false|created_at:timestamp with time zone:NO:now()|updated_at:timestamp with time zone:NO:now()|first_names:text:YES:|paternal_surname:text:YES:|maternal_surname:text:YES:|person_type:text:YES:|institutional_id_type:text:YES:|institutional_id_value:text:YES:|account_kind:text:NO:''institutional''::text|account_status:text:NO:''pending_registration''::text|activated_at:timestamp with time zone:YES:|deactivated_at:timestamp with time zone:YES:'
      or (select count(*) from pg_constraint where conrelid='public.profiles'::regclass)<>17
      or (select count(*) from pg_trigger where tgrelid='public.profiles'::regclass and not tgisinternal)<>3
      or not (select relrowsecurity and not relforcerowsecurity from pg_class where oid='public.profiles'::regclass)
      or (select count(*) from pg_policies where schemaname='public' and tablename='profiles')<>2
      or exists (
        with expected(column_name,grantee,privilege_type,is_grantable) as (
          values
            ('first_names','authenticated','UPDATE',false),
            ('paternal_surname','authenticated','UPDATE',false),
            ('maternal_surname','authenticated','UPDATE',false)
        ), actual as (
          select attribute_definition.attname::text,
            coalesce(grantee_role.rolname,'PUBLIC')::text,
            upper(acl.privilege_type)::text,acl.is_grantable
          from pg_attribute attribute_definition
          cross join lateral aclexplode(attribute_definition.attacl) acl
          left join pg_roles grantee_role on grantee_role.oid=acl.grantee
          where attribute_definition.attrelid='public.profiles'::regclass
            and attribute_definition.attnum>0 and not attribute_definition.attisdropped
        )
        select 1 from (
          (select * from expected except select * from actual)
          union all
          (select * from actual except select * from expected)
        ) differences
      )
      or not has_table_privilege('authenticated','public.profiles','SELECT')
      or has_table_privilege('authenticated','public.profiles','INSERT')
      or has_table_privilege('authenticated','public.profiles','UPDATE')
      or has_table_privilege('authenticated','public.profiles','DELETE')
      or exists (
        select 1 from (values
          ('full_name'),('email'),('account_kind'),('account_status'),('is_active'),
          ('activated_at'),('deactivated_at'),('person_type'),
          ('institutional_id_type'),('institutional_id_value'),('primary_program_id')
        ) protected(column_name)
        where has_column_privilege('authenticated','public.profiles',protected.column_name,'UPDATE')
      )
      or (select count(*) from pg_policies where schemaname='public' and tablename='profiles' and (
        policyname='Users can read own profile' and permissive='PERMISSIVE' and roles='{authenticated}' and cmd='SELECT' and qual='(auth.uid() = id)' and with_check is null
        or policyname='Users can update own basic profile' and permissive='PERMISSIVE' and roles='{authenticated}' and cmd='UPDATE' and qual='(auth.uid() = id)' and with_check='(auth.uid() = id)'
      ))<>2
    union all select 1 where exists(select 1 from public.profiles where not (
      account_status='active' and is_active and activated_at is not null and deactivated_at is null
      or account_status='pending_registration' and not is_active and activated_at is null and deactivated_at is null
      or account_status='inactive' and not is_active and activated_at is not null and deactivated_at is not null))
    union all select 1 where exists(select 1 from public.profiles profile where not (
      profile.account_kind='institutional' and profile.account_status='pending_registration' and profile.person_type is null and profile.primary_program_id is null and profile.institutional_id_type is null and profile.institutional_id_value is null and profile.first_names is null and profile.paternal_surname is null and profile.maternal_surname is null
      or profile.account_kind='institutional' and profile.account_status in ('active','inactive') and profile.person_type in ('student','professor') and profile.first_names is not null and profile.paternal_surname is not null and profile.full_name=concat_ws(' ',profile.first_names,profile.paternal_surname,profile.maternal_surname) and profile.primary_program_id is not null and profile.institutional_id_value~'^[0-9]{1,50}$' and profile.institutional_id_type=case when profile.person_type='student' then 'student_account' else 'worker_number' end
      or profile.account_kind='technical' and profile.account_status in ('active','inactive') and profile.first_names is not null and profile.full_name=concat_ws(' ',profile.first_names,profile.paternal_surname,profile.maternal_surname) and profile.person_type is null and profile.primary_program_id is null and profile.institutional_id_type is null and profile.institutional_id_value is null))
    union all select 1 where exists(select 1 from public.profiles profile left join auth.users auth_user on auth_user.id=profile.id where auth_user.id is null)
      or exists(select 1 from auth.users auth_user left join public.profiles profile on profile.id=auth_user.id where profile.id is null)
      or exists(select 1 from public.profiles profile join auth.users auth_user on auth_user.id=profile.id where profile.email<>lower(btrim(profile.email)) or lower(btrim(auth_user.email))<>profile.email)
    union all select 1 where exists(
      select 1 from pg_proc p where p.oid=to_regprocedure('public.is_b1_account_admin()')
        and (pg_get_userbyid(p.proowner)<>'postgres' or not p.prosecdef or p.provolatile<>'s' or p.proconfig<>array['search_path=pg_catalog, public']::text[] or md5(regexp_replace(p.prosrc,'\s+','','g'))<>'0486f72652abc79ed3d1334704d55fbe' or has_function_privilege('authenticated',p.oid,'EXECUTE') or has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('service_role',p.oid,'EXECUTE') or (select count(*) from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where acl.privilege_type='EXECUTE' and acl.grantee=p.proowner and not acl.is_grantable)<>1 or exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where acl.privilege_type<>'EXECUTE' or acl.grantee<>p.proowner or acl.is_grantable))
    union all select 1 where exists(
      select 1 from (values
        ('public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)',array['search_path=pg_catalog, public, extensions']::text[]),
        ('public.get_admin_account_detail_b1(uuid)',array['search_path=pg_catalog, public, auth']::text[]),
        ('public.get_admin_account_assignments_b1(uuid)',array['search_path=pg_catalog, public']::text[]),
        ('public.get_admin_account_audit_history_b1(uuid,integer,integer)',array['search_path=pg_catalog, public']::text[])
      ) expected(signature,search_path) left join pg_proc p on p.oid=to_regprocedure(expected.signature)
      left join pg_language language on language.oid=p.prolang
      where p.oid is null or pg_get_userbyid(p.proowner)<>'postgres' or not p.prosecdef or p.provolatile<>'s' or p.proconfig is distinct from expected.search_path or language.lanname<>'plpgsql' or not has_function_privilege('authenticated',p.oid,'EXECUTE') or has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('service_role',p.oid,'EXECUTE') or (select count(*) from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where acl.privilege_type='EXECUTE' and acl.grantee in (p.proowner,'authenticated'::regrole) and not acl.is_grantable)<>2 or exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where acl.privilege_type<>'EXECUTE' or acl.grantee not in (p.proowner,'authenticated'::regrole) or acl.is_grantable))
    union all select 1 where
      (select count(*) from information_schema.columns where table_schema='public' and table_name='admin_audit_events')<>9
      or (select count(*) from pg_constraint where conrelid='public.admin_audit_events'::regclass)<>8
      or (select count(*) from pg_trigger where tgrelid='public.admin_audit_events'::regclass and not tgisinternal)<>2
      or not (select relrowsecurity from pg_class where oid='public.admin_audit_events'::regclass)
      or (select count(*) from pg_policies where schemaname='public' and tablename='admin_audit_events')<>0
      or has_table_privilege('authenticated','public.admin_audit_events','SELECT')
      or has_table_privilege('authenticated','public.admin_audit_events','INSERT')
      or not has_table_privilege('service_role','public.admin_audit_events','SELECT')
      or not has_table_privilege('service_role','public.admin_audit_events','INSERT')
    union all select 1 where has_column_privilege('authenticated','public.profiles','account_status','UPDATE')
      or has_column_privilege('authenticated','public.profiles','is_active','UPDATE')
      or has_column_privilege('authenticated','public.profiles','activated_at','UPDATE')
      or has_column_privilege('authenticated','public.profiles','deactivated_at','UPDATE')
    union all select 1 where not exists(
      select 1 from public.profiles profile join public.role_assignments assignment on assignment.user_id=profile.id
      where profile.account_status='active' and profile.is_active
        and assignment.role_code='technical_admin' and assignment.scope_type='system'
        and assignment.service_area='technical' and assignment.program_id is null
        and assignment.division_id is null and assignment.is_active
        and assignment.starts_at<=public.sitaa_current_mexico_date()
        and (assignment.ends_at is null or assignment.ends_at>=public.sitaa_current_mexico_date()))
    union all select 1 where
      (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_created')<>1
      or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_created' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgenabled='O' and trigger_definition.tgtype=5::smallint and trigger_definition.tgfoid=to_regprocedure('public.handle_sitaa_auth_user_created()') and cardinality(trigger_definition.tgattr::smallint[])=0 and trigger_definition.tgqual is null)<>1
      or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_email_changed')<>1
      or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_email_changed' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgenabled='O' and trigger_definition.tgtype=17::smallint and trigger_definition.tgfoid=to_regprocedure('public.sync_sitaa_profile_email_from_auth()') and cardinality(trigger_definition.tgattr::smallint[])=1 and trigger_definition.tgqual is not null and (select count(*) from unnest(trigger_definition.tgattr::smallint[]) update_attribute(attnum) join pg_attribute attribute_definition on attribute_definition.attrelid=trigger_definition.tgrelid and attribute_definition.attnum=update_attribute.attnum and attribute_definition.attname='email' and not attribute_definition.attisdropped)=1 and regexp_replace(regexp_replace(split_part(split_part(lower(pg_get_triggerdef(trigger_definition.oid,false)),' when ',2),' execute function ',1),'[[:space:]()]','','g'),'::text','','g')='old.emailisdistinctfromnew.email')<>1
      or exists (select 1 from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgfoid in (to_regprocedure('public.handle_sitaa_auth_user_created()'),to_regprocedure('public.sync_sitaa_profile_email_from_auth()')) and not (trigger_definition.tgname='on_sitaa_auth_user_created' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgfoid=to_regprocedure('public.handle_sitaa_auth_user_created()') or trigger_definition.tgname='on_sitaa_auth_user_email_changed' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgfoid=to_regprocedure('public.sync_sitaa_profile_email_from_auth()')))
  ) mismatches;

  if mismatch_count<>0 then
    raise exception 'sitaa_0009_preflight_blocked:%',mismatch_count using errcode='55000';
  end if;

  perform set_config(
    'sitaa_0009.default_acl_hash',
    (select md5(coalesce(string_agg(defaclrole::text||':'||defaclnamespace::text||':'||defaclobjtype||':'||defaclacl::text,'|' order by defaclrole,defaclnamespace,defaclobjtype),'')) from pg_default_acl),
    true
  );
  perform set_config(
    'sitaa_0009.policy_hash',
    (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||policyname||':'||permissive||':'||roles::text||':'||cmd||':'||coalesce(qual,'')||':'||coalesce(with_check,''),'|' order by schemaname,tablename,policyname),'')) from pg_policies where schemaname='public'),
    true
  );
  perform set_config(
    'sitaa_0009.table_column_acl_hash',
    md5(
      coalesce((select string_agg(table_name||':'||grantor||':'||grantee||':'||privilege_type||':'||is_grantable,'|' order by table_name,grantor,grantee,privilege_type) from information_schema.table_privileges where table_schema='public'),'')
      ||'#'||coalesce((select string_agg(attrelid::text||':'||attnum::text||':'||attacl::text,'|' order by attrelid,attnum) from pg_attribute where attrelid in (select c.oid from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public') and attnum>0 and not attisdropped and attacl is not null),'')
    ),
    true
  );
end;
$preflight$;

create function public.is_exact_b1_account_admin_profile_b2b(
  requested_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path=pg_catalog,public
as $function$
  select exists (
    select 1
    from public.profiles profile
    join public.role_assignments assignment on assignment.user_id=profile.id
    where profile.id=requested_profile_id
      and profile.account_status='active'
      and profile.is_active=true
      and assignment.role_code='technical_admin'
      and assignment.scope_type='system'
      and assignment.service_area='technical'
      and assignment.program_id is null
      and assignment.division_id is null
      and assignment.is_active=true
      and assignment.starts_at<=public.sitaa_current_mexico_date()
      and (assignment.ends_at is null or assignment.ends_at>=public.sitaa_current_mexico_date())
  );
$function$;

revoke all on function public.is_exact_b1_account_admin_profile_b2b(uuid)
  from public,anon,authenticated,service_role;

create function public.get_admin_account_lifecycle_context_b2b(
  requested_profile_id uuid
)
returns table(
  target_profile_id uuid,
  account_kind text,
  account_status text,
  is_self boolean,
  can_deactivate boolean,
  can_reactivate boolean,
  denial_code text,
  has_exact_b1_assignment boolean,
  active_exact_b1_admin_count bigint,
  current_or_future_assignment_count bigint,
  open_responsibility_count bigint,
  open_participation_count bigint
)
language plpgsql
stable
security definer
set search_path=pg_catalog,public
as $function$
declare
  target_profile public.profiles%rowtype;
  institutional_today date:=public.sitaa_current_mexico_date();
  exact_assignment boolean:=false;
  exact_admin_count bigint:=0;
  assignment_count bigint:=0;
  responsibility_count bigint:=0;
  participation_count bigint:=0;
  matching_auth_count bigint:=0;
  auth_confirmed boolean:=false;
  identity_valid boolean:=false;
  lifecycle_valid boolean:=false;
  denial text:=null;
  deactivate_allowed boolean:=false;
  reactivate_allowed boolean:=false;
begin
  if not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode='42501';
  end if;

  select profile.* into target_profile
  from public.profiles profile
  where profile.id=requested_profile_id;
  if not found then return; end if;

  select exists(
    select 1 from public.role_assignments assignment
    where assignment.user_id=target_profile.id
      and assignment.role_code='technical_admin'
      and assignment.scope_type='system'
      and assignment.service_area='technical'
      and assignment.program_id is null
      and assignment.division_id is null
      and assignment.is_active=true
      and assignment.starts_at<=institutional_today
      and (assignment.ends_at is null or assignment.ends_at>=institutional_today)
  ) into exact_assignment;
  select count(distinct profile.id) into exact_admin_count
  from public.profiles profile
  where public.is_exact_b1_account_admin_profile_b2b(profile.id);

  select count(*) into assignment_count
  from public.role_assignments assignment
  where assignment.user_id=target_profile.id
    and assignment.is_active=true
    and (assignment.ends_at is null or assignment.ends_at>=institutional_today);

  select count(distinct activity.id) into responsibility_count
  from public.activities activity
  where (activity.created_by=target_profile.id
      or activity.responsible_profile_id=target_profile.id)
    and (activity.status_code='draft'
      or public.activity_has_ended(activity.id) is distinct from true);

  select count(distinct activity.id) into participation_count
  from public.activity_participants participant
  join public.activities activity on activity.id=participant.activity_id
  where participant.profile_id=target_profile.id
    and (activity.status_code='draft' or public.activity_has_ended(activity.id) is distinct from true);

  select count(*),coalesce(bool_or(
    auth_user.email_confirmed_at is not null or exists (
      select 1 from auth.identities identity_row
      where identity_row.user_id=auth_user.id
        and identity_row.provider='google'
        and lower(btrim(identity_row.identity_data->>'email'))=lower(btrim(auth_user.email))
        and lower(btrim(coalesce(identity_row.identity_data->>'email_verified',''))) in ('true','t','1')
    )
  ),false)
  into matching_auth_count,auth_confirmed
  from auth.users auth_user
  where auth_user.id=target_profile.id
    and lower(btrim(auth_user.email))=target_profile.email;

  lifecycle_valid:=
    (target_profile.account_status='active' and target_profile.is_active=true and target_profile.activated_at is not null and target_profile.deactivated_at is null)
    or (target_profile.account_status='inactive' and target_profile.is_active=false
      and target_profile.activated_at is not null and target_profile.deactivated_at is not null);

  identity_valid:=target_profile.email=lower(btrim(target_profile.email)) and (
      target_profile.account_kind='institutional'
      and target_profile.person_type in ('student','professor')
      and target_profile.first_names is not null
      and target_profile.paternal_surname is not null
      and target_profile.full_name is not null
      and char_length(target_profile.first_names) between 1 and 150
      and target_profile.first_names=regexp_replace(btrim(target_profile.first_names),'\s+',' ','g')
      and char_length(target_profile.paternal_surname) between 1 and 150
      and target_profile.paternal_surname=regexp_replace(btrim(target_profile.paternal_surname),'\s+',' ','g')
      and (target_profile.maternal_surname is null or char_length(target_profile.maternal_surname) between 1 and 150 and target_profile.maternal_surname=regexp_replace(btrim(target_profile.maternal_surname),'\s+',' ','g'))
      and char_length(target_profile.full_name) between 2 and 200
      and target_profile.full_name=concat_ws(' ',target_profile.first_names,target_profile.paternal_surname,target_profile.maternal_surname)
      and target_profile.primary_program_id is not null
      and exists (select 1 from public.academic_programs program where program.id=target_profile.primary_program_id and program.is_active=true)
      and target_profile.institutional_id_value~'^[0-9]{1,50}$'
      and target_profile.institutional_id_type=case when target_profile.person_type='student' then 'student_account' else 'worker_number' end
      or target_profile.account_kind='technical'
      and target_profile.first_names is not null
      and target_profile.full_name is not null
      and char_length(target_profile.first_names) between 1 and 150
      and target_profile.first_names=regexp_replace(btrim(target_profile.first_names),'\s+',' ','g')
      and (target_profile.paternal_surname is null or char_length(target_profile.paternal_surname) between 1 and 150 and target_profile.paternal_surname=regexp_replace(btrim(target_profile.paternal_surname),'\s+',' ','g'))
      and (target_profile.maternal_surname is null or char_length(target_profile.maternal_surname) between 1 and 150 and target_profile.maternal_surname=regexp_replace(btrim(target_profile.maternal_surname),'\s+',' ','g'))
      and char_length(target_profile.full_name) between 2 and 200
      and target_profile.full_name=concat_ws(' ',target_profile.first_names,target_profile.paternal_surname,target_profile.maternal_surname)
      and target_profile.person_type is null
      and target_profile.primary_program_id is null
      and target_profile.institutional_id_type is null
      and target_profile.institutional_id_value is null
    );

  denial:=case
    when target_profile.id=auth.uid() then 'self_forbidden'
    when target_profile.account_status='pending_registration' then 'pending_target'
    when target_profile.account_status not in ('active','inactive') or not lifecycle_valid then 'invalid_lifecycle'
    when target_profile.account_status='active' and exact_assignment and exact_admin_count<=1 then 'last_admin'
    when target_profile.account_status='inactive' and not identity_valid then 'invalid_identity'
    when target_profile.account_status='inactive' and (matching_auth_count<>1 or not auth_confirmed) then 'auth_unconfirmed'
    else null
  end;

  deactivate_allowed:=denial is null and target_profile.account_status='active';
  reactivate_allowed:=denial is null and target_profile.account_status='inactive';

  return query select target_profile.id,target_profile.account_kind,
    target_profile.account_status,target_profile.id=auth.uid(),deactivate_allowed,
    reactivate_allowed,denial,exact_assignment,exact_admin_count,assignment_count,
    responsibility_count,participation_count;
end;
$function$;

revoke all on function public.get_admin_account_lifecycle_context_b2b(uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.get_admin_account_lifecycle_context_b2b(uuid)
  to authenticated;

create function public.transition_admin_account_lifecycle_b2b(
  requested_profile_id uuid,
  requested_transition text,
  transition_reason text
)
returns table(
  target_profile_id uuid,
  audit_event_id uuid,
  previous_status text,
  new_status text,
  changed_fields text[],
  updated_at timestamp with time zone
)
language plpgsql
volatile
security definer
set search_path=pg_catalog,public
as $function$
declare
  actor_profile_id uuid:=auth.uid();
  target_profile public.profiles%rowtype;
  normalized_reason text;
  exact_assignment boolean:=false;
  exact_admin_count bigint:=0;
  matching_auth_count bigint:=0;
  auth_confirmed boolean:=false;
  identity_valid boolean:=false;
  locked_program_active boolean:=null;
  event_id uuid;
  persisted_updated_at timestamptz;
  prior_status text;
  resulting_status text;
  changed text[]:=array['account_status','deactivated_at','is_active']::text[];
begin
  if actor_profile_id is null or not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode='42501';
  end if;
  if requested_transition is null or requested_transition not in ('deactivate','reactivate') then
    raise exception 'sitaa_account_lifecycle_invalid_transition' using errcode='22023';
  end if;
  normalized_reason:=nullif(btrim(regexp_replace(coalesce(transition_reason,''),'\s+',' ','g')),'');
  if normalized_reason is null or char_length(normalized_reason)<10 or char_length(normalized_reason)>1000 then
    raise exception 'sitaa_account_lifecycle_invalid_reason' using errcode='22023';
  end if;
  if actor_profile_id=requested_profile_id then
    raise exception 'sitaa_account_lifecycle_self_forbidden' using errcode='42501';
  end if;

  perform pg_advisory_xact_lock(1397310529,9002);
  lock table public.role_assignments in share mode;

  -- El usuario Auth objetivo se bloquea antes de cualquier perfil.
  perform 1
  from auth.users auth_user
  where auth_user.id=requested_profile_id
  for update;

  -- Actor, objetivo y candidatos B.1 exactos se bloquean juntos por UUID.
  perform 1
  from public.profiles profile
  where profile.id in (actor_profile_id,requested_profile_id)
     or exists (
       select 1 from public.role_assignments assignment
       where assignment.user_id=profile.id
         and assignment.role_code='technical_admin'
         and assignment.scope_type='system'
         and assignment.service_area='technical'
         and assignment.program_id is null
         and assignment.division_id is null
         and assignment.is_active=true
         and assignment.starts_at<=public.sitaa_current_mexico_date()
         and (assignment.ends_at is null or assignment.ends_at>=public.sitaa_current_mexico_date())
     )
  order by profile.id
  for update;

  if not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode='42501';
  end if;

  select profile.* into target_profile
  from public.profiles profile
  where profile.id=requested_profile_id;
  if target_profile.id is null then
    raise exception 'sitaa_account_lifecycle_target_unavailable' using errcode='P0001';
  end if;
  if target_profile.account_status='pending_registration' then
    raise exception 'sitaa_account_lifecycle_pending_target' using errcode='P0001';
  end if;

  if requested_transition='deactivate' and not (
    target_profile.account_status='active' and target_profile.is_active=true
    and target_profile.activated_at is not null and target_profile.deactivated_at is null
  ) or requested_transition='reactivate' and not (
    target_profile.account_status='inactive' and target_profile.is_active=false
    and target_profile.activated_at is not null and target_profile.deactivated_at is not null
  ) then
    raise exception 'sitaa_account_lifecycle_state_conflict' using errcode='55000';
  end if;

  select public.is_exact_b1_account_admin_profile_b2b(target_profile.id)
    into exact_assignment;
  select count(distinct profile.id) into exact_admin_count
  from public.profiles profile
  where public.is_exact_b1_account_admin_profile_b2b(profile.id);
  if requested_transition='deactivate' and exact_assignment and exact_admin_count<=1 then
    raise exception 'sitaa_account_lifecycle_last_admin_forbidden' using errcode='55000';
  end if;

  if requested_transition='reactivate' then
    -- La decisión institucional usa la fila bloqueada, no una lectura no protegida.
    if target_profile.account_kind='institutional' then
      select program.is_active into locked_program_active
      from public.academic_programs program
      where program.id=target_profile.primary_program_id
      for share;
      if locked_program_active is distinct from true then
        raise exception 'sitaa_account_lifecycle_invalid_identity' using errcode='23514';
      end if;
    end if;

    select count(*),coalesce(bool_or(
      auth_user.email_confirmed_at is not null or exists (
        select 1 from auth.identities identity_row
        where identity_row.user_id=auth_user.id
          and identity_row.provider='google'
          and lower(btrim(identity_row.identity_data->>'email'))=lower(btrim(auth_user.email))
          and lower(btrim(coalesce(identity_row.identity_data->>'email_verified',''))) in ('true','t','1')
      )
    ),false)
    into matching_auth_count,auth_confirmed
    from auth.users auth_user
    where auth_user.id=target_profile.id
      and lower(btrim(auth_user.email))=target_profile.email;

    identity_valid:=target_profile.email=lower(btrim(target_profile.email)) and (
        target_profile.account_kind='institutional'
        and target_profile.person_type in ('student','professor')
        and target_profile.first_names is not null
        and target_profile.paternal_surname is not null
        and target_profile.full_name is not null
        and char_length(target_profile.first_names) between 1 and 150
        and target_profile.first_names=regexp_replace(btrim(target_profile.first_names),'\s+',' ','g')
        and char_length(target_profile.paternal_surname) between 1 and 150
        and target_profile.paternal_surname=regexp_replace(btrim(target_profile.paternal_surname),'\s+',' ','g')
        and (target_profile.maternal_surname is null or char_length(target_profile.maternal_surname) between 1 and 150 and target_profile.maternal_surname=regexp_replace(btrim(target_profile.maternal_surname),'\s+',' ','g'))
        and char_length(target_profile.full_name) between 2 and 200
        and target_profile.full_name=concat_ws(' ',target_profile.first_names,target_profile.paternal_surname,target_profile.maternal_surname)
        and target_profile.primary_program_id is not null
        and locked_program_active is true
        and target_profile.institutional_id_value~'^[0-9]{1,50}$'
        and target_profile.institutional_id_type=case when target_profile.person_type='student' then 'student_account' else 'worker_number' end
        or target_profile.account_kind='technical'
        and target_profile.first_names is not null
        and target_profile.full_name is not null
        and char_length(target_profile.first_names) between 1 and 150
        and target_profile.first_names=regexp_replace(btrim(target_profile.first_names),'\s+',' ','g')
        and (target_profile.paternal_surname is null or char_length(target_profile.paternal_surname) between 1 and 150 and target_profile.paternal_surname=regexp_replace(btrim(target_profile.paternal_surname),'\s+',' ','g'))
        and (target_profile.maternal_surname is null or char_length(target_profile.maternal_surname) between 1 and 150 and target_profile.maternal_surname=regexp_replace(btrim(target_profile.maternal_surname),'\s+',' ','g'))
        and char_length(target_profile.full_name) between 2 and 200
        and target_profile.full_name=concat_ws(' ',target_profile.first_names,target_profile.paternal_surname,target_profile.maternal_surname)
        and target_profile.person_type is null
        and target_profile.primary_program_id is null
        and target_profile.institutional_id_type is null
        and target_profile.institutional_id_value is null
      );
    if not identity_valid then
      raise exception 'sitaa_account_lifecycle_invalid_identity' using errcode='23514';
    end if;
    if matching_auth_count<>1 or not auth_confirmed then
      raise exception 'sitaa_account_lifecycle_auth_unconfirmed' using errcode='42501';
    end if;
  end if;

  prior_status:=target_profile.account_status;
  if requested_transition='deactivate' then
    update public.profiles profile
    set account_status='inactive',is_active=false,deactivated_at=now(),updated_at=now()
    where profile.id=target_profile.id
    returning profile.account_status,profile.updated_at into resulting_status,persisted_updated_at;
  else
    update public.profiles profile
    set account_status='active',is_active=true,deactivated_at=null,updated_at=now()
    where profile.id=target_profile.id
    returning profile.account_status,profile.updated_at into resulting_status,persisted_updated_at;
  end if;

  insert into public.admin_audit_events(
    actor_profile_id,target_profile_id,action_code,outcome,reason,
    role_assignment_id,metadata
  ) values (
    actor_profile_id,target_profile.id,
    case when requested_transition='deactivate' then 'account_deactivated' else 'account_reactivated' end,
    'success',normalized_reason,null,
    jsonb_build_object('changed_fields',to_jsonb(changed))
  ) returning id into event_id;

  return query select target_profile.id,event_id,prior_status,resulting_status,
    changed,persisted_updated_at;
end;
$function$;

revoke all on function public.transition_admin_account_lifecycle_b2b(uuid,text,text)
  from public,anon,authenticated,service_role;
grant execute on function public.transition_admin_account_lifecycle_b2b(uuid,text,text)
  to authenticated;

-- Contrato post-DDL exacto de inventario, firmas, seguridad y ACL.
do $post_ddl$
declare
  function_oid regprocedure;
  mismatch_count integer;
begin
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
     or (select count(*) from information_schema.usage_privileges where object_schema='public' and object_type='SEQUENCE')<>6
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public') + (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault(case when c.relkind='S' then 's'::"char" else 'r'::"char" end,c.relowner))) a where n.nspname='public' and c.relkind in ('r','p','v','m','S'))<>445 then
    raise exception 'sitaa_0009_post_ddl_inventory_mismatch' using errcode='55000';
  end if;

  if not (
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
    select count(*)=51
      and count(*) filter(where catalog='academic_periods')=5
      and count(*) filter(where catalog='academic_programs')=2
      and count(*) filter(where catalog='activity_modalities')=3
      and count(*) filter(where catalog='activity_statuses')=6
      and count(*) filter(where catalog='activity_types')=5
      and count(*) filter(where catalog='attention_categories')=5
      and count(*) filter(where catalog='divisions')=1
      and count(*) filter(where catalog='location_types')=7
      and count(*) filter(where catalog='participant_roles')=5
      and count(*) filter(where catalog='roles')=10
      and count(*) filter(where catalog='service_types')=2
      and md5(string_agg(catalog||E'\t'||row_json,E'\n' order by catalog,row_json))='2e450238768fbe9889470864a1832486'
    from controlled_seed_rows
  ) then
    raise exception 'sitaa_0009_post_ddl_seed_contract_mismatch' using errcode='55000';
  end if;

  if (select md5(coalesce(string_agg(p.oid::regprocedure::text,'|' order by p.oid::regprocedure::text),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>'89d8e1d260ccc0af72ee42c394f79f90'
     or (select md5(coalesce(string_agg(p.oid::regprocedure::text||':'||md5(regexp_replace(p.prosrc,'\s+','','g')),'|' order by p.oid::regprocedure::text),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>'71f9763d702e95e4eede51a4a4611694'
     or (select md5(coalesce(string_agg(table_name||':'||ordinal_position::text||':'||column_name||':'||data_type||':'||udt_name||':'||is_nullable||':'||coalesce(column_default,'')||':'||coalesce(character_maximum_length::text,'')||':'||coalesce(numeric_precision::text,'')||':'||coalesce(numeric_scale::text,'')||':'||coalesce(datetime_precision::text,''),'|' order by table_name,ordinal_position),'')) from information_schema.columns where table_schema='public')<>'847b9f5c4ec9d428c522f714de59fd1f'
     or (select md5(coalesce(string_agg(table_definition.relname||':'||constraint_definition.conname||':'||case constraint_definition.contype when 'p' then 'primary_key' when 'f' then 'foreign_key' when 'u' then 'unique' when 'c' then 'check' end||':'||pg_get_constraintdef(constraint_definition.oid),'|' order by table_definition.relname,constraint_definition.conname),'')) from pg_constraint constraint_definition join pg_class table_definition on table_definition.oid=constraint_definition.conrelid join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace where namespace_definition.nspname='public' and constraint_definition.contype in ('p','f','u','c'))<>'64f099164063d0cf500478dda3b5d25c'
     or (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||indexname||':'||indexdef,'|' order by schemaname,tablename,indexname),'')) from pg_indexes where schemaname='public')<>'653875a8435cf43bda4fe55950f65802'
     or (select md5(coalesce(string_agg(table_definition.relname||':'||trigger_definition.tgname||':'||pg_get_triggerdef(trigger_definition.oid,false),'|' order by table_definition.relname,trigger_definition.tgname),'')) from pg_trigger trigger_definition join pg_class table_definition on table_definition.oid=trigger_definition.tgrelid join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace where namespace_definition.nspname='public' and not trigger_definition.tgisinternal)<>'67ee47bcd43c0594129facf3d7729bad'
     or (select md5(coalesce(string_agg(table_name||':'||privilege_type,'|' order by table_name,privilege_type),'')) from information_schema.role_table_grants where table_schema='public' and grantee='authenticated')<>'017b6a7c8048ffdfdc0b7d7319b59a92'
     or not exists (select 1 from pg_class table_definition where table_definition.oid='public.activity_participants'::regclass and (select count(*) from aclexplode(table_definition.relacl) acl where acl.grantee=table_definition.relowner and upper(acl.privilege_type) in ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN') and not acl.is_grantable)=8 and (select count(*) from aclexplode(table_definition.relacl) acl where acl.grantee='service_role'::regrole and upper(acl.privilege_type) in ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN') and not acl.is_grantable)=8 and (select count(*) from aclexplode(table_definition.relacl) acl where acl.grantee='authenticated'::regrole and upper(acl.privilege_type)='SELECT' and not acl.is_grantable)=1 and (select count(*) from aclexplode(table_definition.relacl))=17 and not exists(select 1 from pg_attribute attribute_definition where attribute_definition.attrelid=table_definition.oid and attribute_definition.attnum>0 and not attribute_definition.attisdropped and attribute_definition.attacl is not null and exists(select 1 from aclexplode(attribute_definition.attacl)))) then
    raise exception 'sitaa_0009_post_ddl_exact_map_mismatch' using errcode='55000';
  end if;

  if current_setting('sitaa_0009.default_acl_hash',true) is distinct from
       (select md5(coalesce(string_agg(defaclrole::text||':'||defaclnamespace::text||':'||defaclobjtype||':'||defaclacl::text,'|' order by defaclrole,defaclnamespace,defaclobjtype),'')) from pg_default_acl)
     or current_setting('sitaa_0009.policy_hash',true) is distinct from
       (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||policyname||':'||permissive||':'||roles::text||':'||cmd||':'||coalesce(qual,'')||':'||coalesce(with_check,''),'|' order by schemaname,tablename,policyname),'')) from pg_policies where schemaname='public')
     or current_setting('sitaa_0009.table_column_acl_hash',true) is distinct from
       md5(
         coalesce((select string_agg(table_name||':'||grantor||':'||grantee||':'||privilege_type||':'||is_grantable,'|' order by table_name,grantor,grantee,privilege_type) from information_schema.table_privileges where table_schema='public'),'')
         ||'#'||coalesce((select string_agg(attrelid::text||':'||attnum::text||':'||attacl::text,'|' order by attrelid,attnum) from pg_attribute where attrelid in (select c.oid from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public') and attnum>0 and not attisdropped and attacl is not null),'')
       ) then
    raise exception 'sitaa_0009_post_ddl_unexpected_policy_or_acl_delta';
  end if;

  foreach function_oid in array array[
    'public.is_exact_b1_account_admin_profile_b2b(uuid)'::regprocedure,
    'public.get_admin_account_lifecycle_context_b2b(uuid)'::regprocedure,
    'public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure
  ] loop
    if not (select p.prosecdef
          and p.proconfig=array['search_path=pg_catalog, public']::text[]
          and pg_get_userbyid(p.proowner)='postgres'
        from pg_proc p where p.oid=function_oid) then
      raise exception 'sitaa_0009_post_ddl_function_security_mismatch:%',function_oid;
    end if;
    if has_function_privilege('anon',function_oid,'EXECUTE')
       or has_function_privilege('service_role',function_oid,'EXECUTE')
       or exists (
         select 1 from pg_proc p
         cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
         where p.oid=function_oid
           and (
             acl.privilege_type<>'EXECUTE'
             or acl.is_grantable
             or acl.grantee=0
             or function_oid='public.is_exact_b1_account_admin_profile_b2b(uuid)'::regprocedure
               and acl.grantee<>p.proowner
             or function_oid<>'public.is_exact_b1_account_admin_profile_b2b(uuid)'::regprocedure
               and acl.grantee not in (p.proowner,'authenticated'::regrole)
           )
       ) then
      raise exception 'sitaa_0009_post_ddl_function_acl_mismatch:%',function_oid;
    end if;
  end loop;

  if (select count(*) from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where p.oid='public.is_exact_b1_account_admin_profile_b2b(uuid)'::regprocedure)<>1
     or (select count(*) from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where p.oid='public.get_admin_account_lifecycle_context_b2b(uuid)'::regprocedure)<>2
     or (select count(*) from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where p.oid='public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure)<>2 then
    raise exception 'sitaa_0009_post_ddl_function_acl_cardinality_mismatch';
  end if;

  if has_function_privilege('authenticated','public.is_exact_b1_account_admin_profile_b2b(uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.get_admin_account_lifecycle_context_b2b(uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE') then
    raise exception 'sitaa_0009_post_ddl_authenticated_acl_mismatch';
  end if;

  if (select p.provolatile<>'s' or pg_get_function_identity_arguments(p.oid)<>'requested_profile_id uuid' or pg_get_function_result(p.oid)<>'boolean' from pg_proc p where p.oid='public.is_exact_b1_account_admin_profile_b2b(uuid)'::regprocedure)
     or (select p.provolatile<>'s' or pg_get_function_identity_arguments(p.oid)<>'requested_profile_id uuid' or pg_get_function_result(p.oid)<>'TABLE(target_profile_id uuid, account_kind text, account_status text, is_self boolean, can_deactivate boolean, can_reactivate boolean, denial_code text, has_exact_b1_assignment boolean, active_exact_b1_admin_count bigint, current_or_future_assignment_count bigint, open_responsibility_count bigint, open_participation_count bigint)' from pg_proc p where p.oid='public.get_admin_account_lifecycle_context_b2b(uuid)'::regprocedure)
     or (select p.provolatile<>'v' or pg_get_function_identity_arguments(p.oid)<>'requested_profile_id uuid, requested_transition text, transition_reason text' or pg_get_function_result(p.oid)<>'TABLE(target_profile_id uuid, audit_event_id uuid, previous_status text, new_status text, changed_fields text[], updated_at timestamp with time zone)' from pg_proc p where p.oid='public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure) then
    raise exception 'sitaa_0009_post_ddl_function_signature_mismatch';
  end if;
  if (select language.lanname<>'sql' from pg_proc p join pg_language language on language.oid=p.prolang where p.oid='public.is_exact_b1_account_admin_profile_b2b(uuid)'::regprocedure)
     or exists(select 1 from pg_proc p join pg_language language on language.oid=p.prolang where p.oid in ('public.get_admin_account_lifecycle_context_b2b(uuid)'::regprocedure,'public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure) and language.lanname<>'plpgsql')
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('is_exact_b1_account_admin_profile_b2b','get_admin_account_lifecycle_context_b2b','transition_admin_account_lifecycle_b2b'))<>3 then
    raise exception 'sitaa_0009_post_ddl_language_or_overload_mismatch';
  end if;

  select count(*) into mismatch_count
  from (values
    ('is_exact_b1_account_admin_profile_b2b(uuid)','104d16a531ea53a5b4908102322097dc'),
    ('get_admin_account_lifecycle_context_b2b(uuid)','6e7c8bb5e2dcf99fce6a75e03e07c309'),
    ('transition_admin_account_lifecycle_b2b(uuid,text,text)','7f940968051ff1b844443f6c76b561c3')
  ) expected(signature,body_hash)
  left join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
  where p.oid is null
     or md5(regexp_replace(p.prosrc,'\s+','','g'))<>expected.body_hash;
  if mismatch_count<>0 then
    raise exception 'sitaa_0009_post_ddl_function_body_mismatch';
  end if;

  select count(*) into mismatch_count
  from (values
    ('is_sitaa_operational_account_active()','f85f733578f09c0f7466af7e18a90f4c'),
    ('get_admin_identity_correction_context_b2a(uuid)','83932d04ff8f1b33793e8c7a49bb8e68'),
    ('correct_admin_account_identity_b2a(uuid,text,text,text,text,text,uuid,text)','ce05cbc529473c070953e765e3ee05b2'),
    ('enforce_activity_writer_integrity_b2a()','c58bd04859f1e2a044fcca58d3333e3c'),
    ('is_b1_account_admin()','0486f72652abc79ed3d1334704d55fbe')
  ) expected(signature,body_hash)
  left join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
  where p.oid is null or md5(regexp_replace(p.prosrc,'\s+','','g'))<>expected.body_hash;
  if mismatch_count<>0
     or (select count(*) from pg_constraint where conrelid='public.profiles'::regclass)<>17
     or (select count(*) from pg_trigger where tgrelid='public.profiles'::regclass and not tgisinternal)<>3
     or (select count(*) from pg_trigger where tgrelid='public.admin_audit_events'::regclass and not tgisinternal)<>2
     or not exists(select 1 from pg_constraint where conrelid='public.admin_audit_events'::regclass and conname='admin_audit_events_action_code_check' and pg_get_constraintdef(oid)='CHECK (char_length(action_code) >= 1 AND char_length(action_code) <= 100 AND action_code ~ ''^[a-z][a-z0-9]*(_[a-z0-9]+)*$''::text)') then
    raise exception 'sitaa_0009_post_ddl_prior_contract_drift';
  end if;

  if exists (
       with expected(column_name,grantee,privilege_type,is_grantable) as (
         values
           ('first_names','authenticated','UPDATE',false),
           ('paternal_surname','authenticated','UPDATE',false),
           ('maternal_surname','authenticated','UPDATE',false)
       ), actual as (
         select attribute_definition.attname::text,
           coalesce(grantee_role.rolname,'PUBLIC')::text,
           upper(acl.privilege_type)::text,acl.is_grantable
         from pg_attribute attribute_definition
         cross join lateral aclexplode(attribute_definition.attacl) acl
         left join pg_roles grantee_role on grantee_role.oid=acl.grantee
         where attribute_definition.attrelid='public.profiles'::regclass
           and attribute_definition.attnum>0 and not attribute_definition.attisdropped
       )
       select 1 from (
         (select * from expected except select * from actual)
         union all
         (select * from actual except select * from expected)
       ) differences
     )
     or has_table_privilege('authenticated','public.profiles','UPDATE')
     or exists (
       select 1 from (values
         ('full_name'),('email'),('account_kind'),('account_status'),('is_active'),
         ('activated_at'),('deactivated_at'),('person_type'),
         ('institutional_id_type'),('institutional_id_value'),('primary_program_id')
       ) protected(column_name)
       where has_column_privilege('authenticated','public.profiles',protected.column_name,'UPDATE')
     )
     or (select count(*) from pg_policies where schemaname='public' and tablename='profiles' and (
       policyname='Users can read own profile' and permissive='PERMISSIVE' and roles='{authenticated}' and cmd='SELECT' and qual='(auth.uid() = id)' and with_check is null
       or policyname='Users can update own basic profile' and permissive='PERMISSIVE' and roles='{authenticated}' and cmd='UPDATE' and qual='(auth.uid() = id)' and with_check='(auth.uid() = id)'
     ))<>2 then
    raise exception 'sitaa_0009_post_ddl_profile_acl_or_rls_drift';
  end if;

  if (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_created')<>1
     or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_created' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgenabled='O' and trigger_definition.tgtype=5::smallint and trigger_definition.tgfoid=to_regprocedure('public.handle_sitaa_auth_user_created()') and cardinality(trigger_definition.tgattr::smallint[])=0 and trigger_definition.tgqual is null)<>1
     or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_email_changed')<>1
     or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_email_changed' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgenabled='O' and trigger_definition.tgtype=17::smallint and trigger_definition.tgfoid=to_regprocedure('public.sync_sitaa_profile_email_from_auth()') and cardinality(trigger_definition.tgattr::smallint[])=1 and trigger_definition.tgqual is not null and (select count(*) from unnest(trigger_definition.tgattr::smallint[]) update_attribute(attnum) join pg_attribute attribute_definition on attribute_definition.attrelid=trigger_definition.tgrelid and attribute_definition.attnum=update_attribute.attnum and attribute_definition.attname='email' and not attribute_definition.attisdropped)=1 and regexp_replace(regexp_replace(split_part(split_part(lower(pg_get_triggerdef(trigger_definition.oid,false)),' when ',2),' execute function ',1),'[[:space:]()]','','g'),'::text','','g')='old.emailisdistinctfromnew.email')<>1
     or exists (select 1 from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgfoid in (to_regprocedure('public.handle_sitaa_auth_user_created()'),to_regprocedure('public.sync_sitaa_profile_email_from_auth()')) and not (trigger_definition.tgname='on_sitaa_auth_user_created' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgfoid=to_regprocedure('public.handle_sitaa_auth_user_created()') or trigger_definition.tgname='on_sitaa_auth_user_email_changed' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgfoid=to_regprocedure('public.sync_sitaa_profile_email_from_auth()'))) then
    raise exception 'sitaa_0009_post_ddl_auth_trigger_drift';
  end if;
end;
$post_ddl$;

commit;
