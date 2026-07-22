-- Rollback controlado 0009. No revierte estados ni elimina auditoría/datos.
begin;

set local time zone 'UTC';
set local datestyle to 'ISO, MDY';

do $guard$
declare
  mismatch_count integer;
  function_oid regprocedure;
begin
  if to_regprocedure('public.is_exact_b1_account_admin_profile_b2b(uuid)') is null
     or to_regprocedure('public.get_admin_account_lifecycle_context_b2b(uuid)') is null
     or to_regprocedure('public.transition_admin_account_lifecycle_b2b(uuid,text,text)') is null
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>54
     or (select count(*) from information_schema.tables where table_schema='public' and table_type='BASE TABLE')<>18
     or (select count(*) from information_schema.columns where table_schema='public')<>165
     or (select count(*) from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname='public' and c.contype in ('p','f','u','c'))<>80
     or (select count(*) from pg_indexes where schemaname='public')<>43
     or (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal)<>11
     or (select count(*) from pg_policies where schemaname='public')<>25
     or (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and c.relrowsecurity)<>18
     or (select count(*) from information_schema.routine_privileges where routine_schema='public')<>137
     or (select count(*) from information_schema.table_privileges where table_schema='public')<>267
     or not (
       with actual(sequence_schema,sequence_name,grantor,grantee,privilege_type,is_grantable) as (
         select namespace_definition.nspname::text,sequence_definition.relname::text,pg_get_userbyid(acl.grantor)::text,
           case when acl.grantee=0 then 'PUBLIC' else pg_get_userbyid(acl.grantee) end::text,
           upper(acl.privilege_type)::text,acl.is_grantable
         from pg_class sequence_definition join pg_namespace namespace_definition on namespace_definition.oid=sequence_definition.relnamespace
         cross join lateral aclexplode(coalesce(sequence_definition.relacl,acldefault('S',sequence_definition.relowner))) acl
         where namespace_definition.nspname='public' and sequence_definition.relkind='S'
       ), expected(sequence_schema,sequence_name,grantor,grantee,privilege_type,is_grantable) as (values
         ('public','system_health_id_seq','postgres','postgres','SELECT',false),('public','system_health_id_seq','postgres','postgres','UPDATE',false),('public','system_health_id_seq','postgres','postgres','USAGE',false),
         ('public','system_health_id_seq','postgres','service_role','SELECT',false),('public','system_health_id_seq','postgres','service_role','UPDATE',false),('public','system_health_id_seq','postgres','service_role','USAGE',false)
       )
       select (select count(*) from actual)=6 and not exists(select 1 from ((select * from expected except select * from actual) union all (select * from actual except select * from expected)) differences)
     )
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public') + (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault(case when c.relkind='S' then 's'::"char" else 'r'::"char" end,c.relowner))) a where n.nspname='public' and c.relkind in ('r','p','v','m','S'))<>445 then
    raise exception 'sitaa_0009_rollback_guard_failed' using errcode='55000';
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
    raise exception 'sitaa_0009_rollback_seed_guard_failed' using errcode='55000';
  end if;
  if (select md5(coalesce(string_agg(p.oid::regprocedure::text,'|' order by p.oid::regprocedure::text),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>'89d8e1d260ccc0af72ee42c394f79f90'
     or (select md5(coalesce(string_agg(p.oid::regprocedure::text||':'||md5(regexp_replace(p.prosrc,'\s+','','g')),'|' order by p.oid::regprocedure::text),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>'71f9763d702e95e4eede51a4a4611694'
     or (select md5(coalesce(string_agg(table_name||':'||ordinal_position::text||':'||column_name||':'||data_type||':'||udt_name||':'||is_nullable||':'||coalesce(column_default,'')||':'||coalesce(character_maximum_length::text,'')||':'||coalesce(numeric_precision::text,'')||':'||coalesce(numeric_scale::text,'')||':'||coalesce(datetime_precision::text,''),'|' order by table_name,ordinal_position),'')) from information_schema.columns where table_schema='public')<>'847b9f5c4ec9d428c522f714de59fd1f'
     or (select md5(coalesce(string_agg(table_definition.relname||':'||constraint_definition.conname||':'||case constraint_definition.contype when 'p' then 'primary_key' when 'f' then 'foreign_key' when 'u' then 'unique' when 'c' then 'check' end||':'||pg_get_constraintdef(constraint_definition.oid,true),'|' order by table_definition.relname,constraint_definition.conname),'')) from pg_constraint constraint_definition join pg_class table_definition on table_definition.oid=constraint_definition.conrelid join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace where namespace_definition.nspname='public' and constraint_definition.contype in ('p','f','u','c'))<>'64f099164063d0cf500478dda3b5d25c'
     or (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||indexname||':'||indexdef,'|' order by schemaname,tablename,indexname),'')) from pg_indexes where schemaname='public')<>'653875a8435cf43bda4fe55950f65802'
     or (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||policyname||':'||permissive||':'||roles::text||':'||cmd||':'||coalesce(qual,'')||':'||coalesce(with_check,''),'|' order by schemaname,tablename,policyname),'')) from pg_policies where schemaname='public')<>'a72df97fbb8e73d8445f7fe8765da4ba'
     or (select md5(coalesce(string_agg(table_definition.relname||':'||trigger_definition.tgname||':'||pg_get_triggerdef(trigger_definition.oid,true),'|' order by table_definition.relname,trigger_definition.tgname),'')) from pg_trigger trigger_definition join pg_class table_definition on table_definition.oid=trigger_definition.tgrelid join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace where namespace_definition.nspname='public' and not trigger_definition.tgisinternal)<>'67ee47bcd43c0594129facf3d7729bad'
     or (select md5(coalesce(string_agg(table_name||':'||privilege_type,'|' order by table_name,privilege_type),'')) from information_schema.table_privileges where table_schema='public' and grantee='authenticated')<>'edbb0931514cafe989d3d345c4ea61d6'
     or not (
       with actual(table_name,privilege_type,grantor,grantee,is_grantable,with_hierarchy) as (
         select table_name::text,upper(privilege_type)::text,grantor::text,grantee::text,is_grantable::text,with_hierarchy::text
         from information_schema.table_privileges where table_schema='public' and grantee='authenticated'
       ), expected(table_name,privilege_type,grantor,grantee,is_grantable,with_hierarchy) as (values
         ('academic_periods','SELECT','postgres','authenticated','NO','YES'),('academic_programs','SELECT','postgres','authenticated','NO','YES'),
         ('activities','DELETE','postgres','authenticated','NO','NO'),('activities','INSERT','postgres','authenticated','NO','NO'),('activities','SELECT','postgres','authenticated','NO','YES'),('activities','UPDATE','postgres','authenticated','NO','NO'),
         ('activity_modalities','SELECT','postgres','authenticated','NO','YES'),('activity_participants','SELECT','postgres','authenticated','NO','YES'),('activity_statuses','SELECT','postgres','authenticated','NO','YES'),('activity_types','SELECT','postgres','authenticated','NO','YES'),
         ('attention_categories','SELECT','postgres','authenticated','NO','YES'),('divisions','SELECT','postgres','authenticated','NO','YES'),('location_types','SELECT','postgres','authenticated','NO','YES'),('participant_roles','SELECT','postgres','authenticated','NO','YES'),
         ('profiles','SELECT','postgres','authenticated','NO','YES'),('role_assignments','SELECT','postgres','authenticated','NO','YES'),('roles','SELECT','postgres','authenticated','NO','YES'),('service_types','SELECT','postgres','authenticated','NO','YES'),('system_health','SELECT','postgres','authenticated','NO','YES')
       )
       select (select count(*) from actual)=19 and not exists(select 1 from ((select * from expected except select * from actual) union all (select * from actual except select * from expected)) differences)
     )
     or not exists (select 1 from pg_class table_definition where table_definition.oid='public.activity_participants'::regclass and (select count(*) from aclexplode(table_definition.relacl) acl where acl.grantee=table_definition.relowner and upper(acl.privilege_type) in ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN') and not acl.is_grantable)=8 and (select count(*) from aclexplode(table_definition.relacl) acl where acl.grantee='service_role'::regrole and upper(acl.privilege_type) in ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN') and not acl.is_grantable)=8 and (select count(*) from aclexplode(table_definition.relacl) acl where acl.grantee='authenticated'::regrole and upper(acl.privilege_type)='SELECT' and not acl.is_grantable)=1 and (select count(*) from aclexplode(table_definition.relacl))=17 and not exists(select 1 from pg_attribute attribute_definition where attribute_definition.attrelid=table_definition.oid and attribute_definition.attnum>0 and not attribute_definition.attisdropped and attribute_definition.attacl is not null and exists(select 1 from aclexplode(attribute_definition.attacl)))) then
    raise exception 'sitaa_0009_rollback_exact_post_0009_map_failed' using errcode='55000';
  end if;
  select count(*) into mismatch_count
  from (values
    ('is_exact_b1_account_admin_profile_b2b(uuid)','104d16a531ea53a5b4908102322097dc'),
    ('get_admin_account_lifecycle_context_b2b(uuid)','6e7c8bb5e2dcf99fce6a75e03e07c309'),
    ('transition_admin_account_lifecycle_b2b(uuid,text,text)','7f940968051ff1b844443f6c76b561c3')
  ) expected(signature,body_hash)
  left join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
  where p.oid is null or md5(regexp_replace(p.prosrc,'\s+','','g'))<>expected.body_hash;
  if mismatch_count<>0 then
    raise exception 'sitaa_0009_rollback_function_body_guard_failed' using errcode='55000';
  end if;

  foreach function_oid in array array[
    'public.is_exact_b1_account_admin_profile_b2b(uuid)'::regprocedure,
    'public.get_admin_account_lifecycle_context_b2b(uuid)'::regprocedure,
    'public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure
  ] loop
    if not (select p.prosecdef
          and p.proconfig=array['search_path=pg_catalog, public']::text[]
          and pg_get_userbyid(p.proowner)='postgres'
        from pg_proc p where p.oid=function_oid)
       or has_function_privilege('anon',function_oid,'EXECUTE')
       or has_function_privilege('service_role',function_oid,'EXECUTE')
       or exists(
         select 1 from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
         where p.oid=function_oid and (
           acl.privilege_type<>'EXECUTE' or acl.grantee=0 or acl.is_grantable
           or function_oid='public.is_exact_b1_account_admin_profile_b2b(uuid)'::regprocedure and acl.grantee<>p.proowner
           or function_oid<>'public.is_exact_b1_account_admin_profile_b2b(uuid)'::regprocedure and acl.grantee not in (p.proowner,'authenticated'::regrole)
         )
       ) then
      raise exception 'sitaa_0009_rollback_function_acl_guard_failed:%',function_oid using errcode='55000';
    end if;
  end loop;
  if (select count(*) from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where p.oid='public.is_exact_b1_account_admin_profile_b2b(uuid)'::regprocedure)<>1
     or (select count(*) from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where p.oid='public.get_admin_account_lifecycle_context_b2b(uuid)'::regprocedure)<>2
     or (select count(*) from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where p.oid='public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure)<>2 then
    raise exception 'sitaa_0009_rollback_function_acl_cardinality_guard_failed' using errcode='55000';
  end if;
  if has_function_privilege('authenticated','public.is_exact_b1_account_admin_profile_b2b(uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.get_admin_account_lifecycle_context_b2b(uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('is_exact_b1_account_admin_profile_b2b','get_admin_account_lifecycle_context_b2b','transition_admin_account_lifecycle_b2b'))<>3 then
    raise exception 'sitaa_0009_rollback_signature_or_acl_guard_failed' using errcode='55000';
  end if;
  if (select pg_get_userbyid(p.proowner)<>'postgres' or p.provolatile<>'s' or pg_get_function_identity_arguments(p.oid)<>'requested_profile_id uuid' or pg_get_function_result(p.oid)<>'boolean' from pg_proc p where p.oid='public.is_exact_b1_account_admin_profile_b2b(uuid)'::regprocedure)
     or (select pg_get_userbyid(p.proowner)<>'postgres' or p.provolatile<>'s' or pg_get_function_identity_arguments(p.oid)<>'requested_profile_id uuid' or pg_get_function_result(p.oid)<>'TABLE(target_profile_id uuid, account_kind text, account_status text, is_self boolean, can_deactivate boolean, can_reactivate boolean, denial_code text, has_exact_b1_assignment boolean, active_exact_b1_admin_count bigint, current_or_future_assignment_count bigint, open_responsibility_count bigint, open_participation_count bigint)' from pg_proc p where p.oid='public.get_admin_account_lifecycle_context_b2b(uuid)'::regprocedure)
     or (select pg_get_userbyid(p.proowner)<>'postgres' or p.provolatile<>'v' or pg_get_function_identity_arguments(p.oid)<>'requested_profile_id uuid, requested_transition text, transition_reason text' or pg_get_function_result(p.oid)<>'TABLE(target_profile_id uuid, audit_event_id uuid, previous_status text, new_status text, changed_fields text[], updated_at timestamp with time zone)' from pg_proc p where p.oid='public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure)
     or (select language.lanname<>'sql' from pg_proc p join pg_language language on language.oid=p.prolang where p.oid='public.is_exact_b1_account_admin_profile_b2b(uuid)'::regprocedure)
     or exists(select 1 from pg_proc p join pg_language language on language.oid=p.prolang where p.oid in ('public.get_admin_account_lifecycle_context_b2b(uuid)'::regprocedure,'public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure) and language.lanname<>'plpgsql') then
    raise exception 'sitaa_0009_rollback_exact_function_contract_failed' using errcode='55000';
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
     or (select count(*) from pg_constraint constraint_definition where constraint_definition.conrelid='public.admin_audit_events'::regclass and constraint_definition.conname='admin_audit_events_action_code_check' and constraint_definition.contype='c' and constraint_definition.convalidated and pg_get_constraintdef(constraint_definition.oid,true)='CHECK (char_length(action_code) >= 1 AND char_length(action_code) <= 100 AND action_code ~ ''^[a-z][a-z0-9]*(_[a-z0-9]+)*$''::text)' and cardinality(constraint_definition.conkey)=1 and exists(select 1 from unnest(constraint_definition.conkey) key_column(attnum) join pg_attribute attribute_definition on attribute_definition.attrelid=constraint_definition.conrelid and attribute_definition.attnum=key_column.attnum where attribute_definition.attname='action_code' and not attribute_definition.attisdropped))<>1
     or not ('account_deactivated'~'^[a-z][a-z0-9]*(_[a-z0-9]+)*$' and 'account_reactivated'~'^[a-z][a-z0-9]*(_[a-z0-9]+)*$') then
    raise exception 'sitaa_0009_rollback_prior_contract_guard_failed' using errcode='55000';
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
       select 1 from ((select * from expected except select * from actual) union all (select * from actual except select * from expected)) differences
     )
     or has_table_privilege('authenticated','public.profiles','UPDATE')
     or exists (select 1 from (values ('full_name'),('email'),('account_kind'),('account_status'),('is_active'),('activated_at'),('deactivated_at'),('person_type'),('institutional_id_type'),('institutional_id_value'),('primary_program_id')) protected(column_name) where has_column_privilege('authenticated','public.profiles',protected.column_name,'UPDATE'))
     or (select count(*) from pg_policies where schemaname='public' and tablename='profiles' and (policyname='Users can read own profile' and permissive='PERMISSIVE' and roles='{authenticated}' and cmd='SELECT' and qual='(auth.uid() = id)' and with_check is null or policyname='Users can update own basic profile' and permissive='PERMISSIVE' and roles='{authenticated}' and cmd='UPDATE' and qual='(auth.uid() = id)' and with_check='(auth.uid() = id)'))<>2 then
    raise exception 'sitaa_0009_rollback_profile_acl_or_rls_guard_failed' using errcode='55000';
  end if;

  if (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_created')<>1
     or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_created' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgenabled='O' and trigger_definition.tgtype=5::smallint and trigger_definition.tgfoid=to_regprocedure('public.handle_sitaa_auth_user_created()') and cardinality(trigger_definition.tgattr::smallint[])=0 and trigger_definition.tgqual is null)<>1
     or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_email_changed')<>1
     or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_email_changed' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgenabled='O' and trigger_definition.tgtype=17::smallint and trigger_definition.tgfoid=to_regprocedure('public.sync_sitaa_profile_email_from_auth()') and cardinality(trigger_definition.tgattr::smallint[])=1 and trigger_definition.tgqual is not null and (select count(*) from unnest(trigger_definition.tgattr::smallint[]) update_attribute(attnum) join pg_attribute attribute_definition on attribute_definition.attrelid=trigger_definition.tgrelid and attribute_definition.attnum=update_attribute.attnum and attribute_definition.attname='email' and not attribute_definition.attisdropped)=1 and regexp_replace(regexp_replace(split_part(split_part(lower(pg_get_triggerdef(trigger_definition.oid,false)),' when ',2),' execute function ',1),'[[:space:]()]','','g'),'::text','','g')='old.emailisdistinctfromnew.email')<>1
     or exists (select 1 from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgfoid in (to_regprocedure('public.handle_sitaa_auth_user_created()'),to_regprocedure('public.sync_sitaa_profile_email_from_auth()')) and not (trigger_definition.tgname='on_sitaa_auth_user_created' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgfoid=to_regprocedure('public.handle_sitaa_auth_user_created()') or trigger_definition.tgname='on_sitaa_auth_user_email_changed' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgfoid=to_regprocedure('public.sync_sitaa_profile_email_from_auth()'))) then
    raise exception 'sitaa_0009_rollback_auth_trigger_guard_failed' using errcode='55000';
  end if;
end;
$guard$;

revoke all on function public.get_admin_account_lifecycle_context_b2b(uuid)
  from public,anon,authenticated,service_role;
revoke all on function public.transition_admin_account_lifecycle_b2b(uuid,text,text)
  from public,anon,authenticated,service_role;
revoke all on function public.is_exact_b1_account_admin_profile_b2b(uuid)
  from public,anon,authenticated,service_role;

drop function public.transition_admin_account_lifecycle_b2b(uuid,text,text);
drop function public.get_admin_account_lifecycle_context_b2b(uuid);
drop function public.is_exact_b1_account_admin_profile_b2b(uuid);

do $post_rollback$
begin
  if to_regprocedure('public.is_exact_b1_account_admin_profile_b2b(uuid)') is not null
     or to_regprocedure('public.get_admin_account_lifecycle_context_b2b(uuid)') is not null
     or to_regprocedure('public.transition_admin_account_lifecycle_b2b(uuid,text,text)') is not null
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>51
     or (select count(*) from information_schema.tables where table_schema='public' and table_type='BASE TABLE')<>18
     or (select count(*) from information_schema.columns where table_schema='public')<>165
     or (select count(*) from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname='public' and c.contype in ('p','f','u','c'))<>80
     or (select count(*) from pg_indexes where schemaname='public')<>43
     or (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal)<>11
     or (select count(*) from pg_policies where schemaname='public')<>25
     or (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and c.relrowsecurity)<>18
     or (select count(*) from information_schema.routine_privileges where routine_schema='public')<>132
     or (select count(*) from information_schema.table_privileges where table_schema='public')<>267
     or not (
       with actual(sequence_schema,sequence_name,grantor,grantee,privilege_type,is_grantable) as (
         select namespace_definition.nspname::text,sequence_definition.relname::text,pg_get_userbyid(acl.grantor)::text,
           case when acl.grantee=0 then 'PUBLIC' else pg_get_userbyid(acl.grantee) end::text,
           upper(acl.privilege_type)::text,acl.is_grantable
         from pg_class sequence_definition join pg_namespace namespace_definition on namespace_definition.oid=sequence_definition.relnamespace
         cross join lateral aclexplode(coalesce(sequence_definition.relacl,acldefault('S',sequence_definition.relowner))) acl
         where namespace_definition.nspname='public' and sequence_definition.relkind='S'
       ), expected(sequence_schema,sequence_name,grantor,grantee,privilege_type,is_grantable) as (values
         ('public','system_health_id_seq','postgres','postgres','SELECT',false),('public','system_health_id_seq','postgres','postgres','UPDATE',false),('public','system_health_id_seq','postgres','postgres','USAGE',false),
         ('public','system_health_id_seq','postgres','service_role','SELECT',false),('public','system_health_id_seq','postgres','service_role','UPDATE',false),('public','system_health_id_seq','postgres','service_role','USAGE',false)
       )
       select (select count(*) from actual)=6 and not exists(select 1 from ((select * from expected except select * from actual) union all (select * from actual except select * from expected)) differences)
     )
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public') + (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault(case when c.relkind='S' then 's'::"char" else 'r'::"char" end,c.relowner))) a where n.nspname='public' and c.relkind in ('r','p','v','m','S'))<>440 then
    raise exception 'sitaa_0009_rollback_postcondition_failed' using errcode='55000';
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
    raise exception 'sitaa_0009_rollback_post_seed_contract_failed' using errcode='55000';
  end if;
  if (select md5(coalesce(string_agg(p.oid::regprocedure::text,'|' order by p.oid::regprocedure::text),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>'7f2ecc4f95b05b5ea44413773bdc8e71'
     or (select md5(coalesce(string_agg(p.oid::regprocedure::text||':'||md5(regexp_replace(p.prosrc,'\s+','','g')),'|' order by p.oid::regprocedure::text),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>'43f89f8dba9ff02bb3c3f47dcee25af2'
     or (select md5(coalesce(string_agg(table_name||':'||ordinal_position::text||':'||column_name||':'||data_type||':'||udt_name||':'||is_nullable||':'||coalesce(column_default,'')||':'||coalesce(character_maximum_length::text,'')||':'||coalesce(numeric_precision::text,'')||':'||coalesce(numeric_scale::text,'')||':'||coalesce(datetime_precision::text,''),'|' order by table_name,ordinal_position),'')) from information_schema.columns where table_schema='public')<>'847b9f5c4ec9d428c522f714de59fd1f'
     or (select md5(coalesce(string_agg(table_definition.relname||':'||constraint_definition.conname||':'||case constraint_definition.contype when 'p' then 'primary_key' when 'f' then 'foreign_key' when 'u' then 'unique' when 'c' then 'check' end||':'||pg_get_constraintdef(constraint_definition.oid,true),'|' order by table_definition.relname,constraint_definition.conname),'')) from pg_constraint constraint_definition join pg_class table_definition on table_definition.oid=constraint_definition.conrelid join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace where namespace_definition.nspname='public' and constraint_definition.contype in ('p','f','u','c'))<>'64f099164063d0cf500478dda3b5d25c'
     or (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||indexname||':'||indexdef,'|' order by schemaname,tablename,indexname),'')) from pg_indexes where schemaname='public')<>'653875a8435cf43bda4fe55950f65802'
     or (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||policyname||':'||permissive||':'||roles::text||':'||cmd||':'||coalesce(qual,'')||':'||coalesce(with_check,''),'|' order by schemaname,tablename,policyname),'')) from pg_policies where schemaname='public')<>'a72df97fbb8e73d8445f7fe8765da4ba'
     or (select md5(coalesce(string_agg(table_definition.relname||':'||trigger_definition.tgname||':'||pg_get_triggerdef(trigger_definition.oid,true),'|' order by table_definition.relname,trigger_definition.tgname),'')) from pg_trigger trigger_definition join pg_class table_definition on table_definition.oid=trigger_definition.tgrelid join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace where namespace_definition.nspname='public' and not trigger_definition.tgisinternal)<>'67ee47bcd43c0594129facf3d7729bad'
     or (select md5(coalesce(string_agg(table_name||':'||privilege_type,'|' order by table_name,privilege_type),'')) from information_schema.table_privileges where table_schema='public' and grantee='authenticated')<>'edbb0931514cafe989d3d345c4ea61d6'
     or not (
       with actual(table_name,privilege_type,grantor,grantee,is_grantable,with_hierarchy) as (
         select table_name::text,upper(privilege_type)::text,grantor::text,grantee::text,is_grantable::text,with_hierarchy::text
         from information_schema.table_privileges where table_schema='public' and grantee='authenticated'
       ), expected(table_name,privilege_type,grantor,grantee,is_grantable,with_hierarchy) as (values
         ('academic_periods','SELECT','postgres','authenticated','NO','YES'),('academic_programs','SELECT','postgres','authenticated','NO','YES'),
         ('activities','DELETE','postgres','authenticated','NO','NO'),('activities','INSERT','postgres','authenticated','NO','NO'),('activities','SELECT','postgres','authenticated','NO','YES'),('activities','UPDATE','postgres','authenticated','NO','NO'),
         ('activity_modalities','SELECT','postgres','authenticated','NO','YES'),('activity_participants','SELECT','postgres','authenticated','NO','YES'),('activity_statuses','SELECT','postgres','authenticated','NO','YES'),('activity_types','SELECT','postgres','authenticated','NO','YES'),
         ('attention_categories','SELECT','postgres','authenticated','NO','YES'),('divisions','SELECT','postgres','authenticated','NO','YES'),('location_types','SELECT','postgres','authenticated','NO','YES'),('participant_roles','SELECT','postgres','authenticated','NO','YES'),
         ('profiles','SELECT','postgres','authenticated','NO','YES'),('role_assignments','SELECT','postgres','authenticated','NO','YES'),('roles','SELECT','postgres','authenticated','NO','YES'),('service_types','SELECT','postgres','authenticated','NO','YES'),('system_health','SELECT','postgres','authenticated','NO','YES')
       )
       select (select count(*) from actual)=19 and not exists(select 1 from ((select * from expected except select * from actual) union all (select * from actual except select * from expected)) differences)
     )
     or not exists (select 1 from pg_class table_definition where table_definition.oid='public.activity_participants'::regclass and (select count(*) from aclexplode(table_definition.relacl) acl where acl.grantee=table_definition.relowner and upper(acl.privilege_type) in ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN') and not acl.is_grantable)=8 and (select count(*) from aclexplode(table_definition.relacl) acl where acl.grantee='service_role'::regrole and upper(acl.privilege_type) in ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN') and not acl.is_grantable)=8 and (select count(*) from aclexplode(table_definition.relacl) acl where acl.grantee='authenticated'::regrole and upper(acl.privilege_type)='SELECT' and not acl.is_grantable)=1 and (select count(*) from aclexplode(table_definition.relacl))=17 and not exists(select 1 from pg_attribute attribute_definition where attribute_definition.attrelid=table_definition.oid and attribute_definition.attnum>0 and not attribute_definition.attisdropped and attribute_definition.attacl is not null and exists(select 1 from aclexplode(attribute_definition.attacl)))) then
    raise exception 'sitaa_0009_rollback_exact_post_0008_map_failed' using errcode='55000';
  end if;
  if to_regprocedure('public.get_admin_account_detail_b1(uuid)') is null
     or to_regprocedure('public.correct_admin_account_identity_b2a(uuid,text,text,text,text,text,uuid,text)') is null
     or to_regclass('public.admin_audit_events') is null
     or (select count(*) from pg_constraint constraint_definition where constraint_definition.conrelid='public.admin_audit_events'::regclass and constraint_definition.conname='admin_audit_events_action_code_check' and constraint_definition.contype='c' and constraint_definition.convalidated and pg_get_constraintdef(constraint_definition.oid,true)='CHECK (char_length(action_code) >= 1 AND char_length(action_code) <= 100 AND action_code ~ ''^[a-z][a-z0-9]*(_[a-z0-9]+)*$''::text)' and cardinality(constraint_definition.conkey)=1 and exists(select 1 from unnest(constraint_definition.conkey) key_column(attnum) join pg_attribute attribute_definition on attribute_definition.attrelid=constraint_definition.conrelid and attribute_definition.attnum=key_column.attnum where attribute_definition.attname='action_code' and not attribute_definition.attisdropped))<>1
     or not ('account_deactivated'~'^[a-z][a-z0-9]*(_[a-z0-9]+)*$' and 'account_reactivated'~'^[a-z][a-z0-9]*(_[a-z0-9]+)*$') then
    raise exception 'sitaa_0009_rollback_preservation_failed' using errcode='55000';
  end if;
  if exists (
       with expected(column_name,grantee,privilege_type,is_grantable) as (
         values ('first_names','authenticated','UPDATE',false),('paternal_surname','authenticated','UPDATE',false),('maternal_surname','authenticated','UPDATE',false)
       ), actual as (
         select attribute_definition.attname::text,coalesce(grantee_role.rolname,'PUBLIC')::text,upper(acl.privilege_type)::text,acl.is_grantable
         from pg_attribute attribute_definition cross join lateral aclexplode(attribute_definition.attacl) acl
         left join pg_roles grantee_role on grantee_role.oid=acl.grantee
         where attribute_definition.attrelid='public.profiles'::regclass and attribute_definition.attnum>0 and not attribute_definition.attisdropped
       )
       select 1 from ((select * from expected except select * from actual) union all (select * from actual except select * from expected)) differences
     )
     or has_table_privilege('authenticated','public.profiles','UPDATE')
     or exists (select 1 from (values ('full_name'),('email'),('account_kind'),('account_status'),('is_active'),('activated_at'),('deactivated_at'),('person_type'),('institutional_id_type'),('institutional_id_value'),('primary_program_id')) protected(column_name) where has_column_privilege('authenticated','public.profiles',protected.column_name,'UPDATE')) then
    raise exception 'sitaa_0009_rollback_post_profile_acl_failed' using errcode='55000';
  end if;
  if (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_created')<>1
     or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_created' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgenabled='O' and trigger_definition.tgtype=5::smallint and trigger_definition.tgfoid=to_regprocedure('public.handle_sitaa_auth_user_created()') and cardinality(trigger_definition.tgattr::smallint[])=0 and trigger_definition.tgqual is null)<>1
     or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_email_changed')<>1
     or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_email_changed' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgenabled='O' and trigger_definition.tgtype=17::smallint and trigger_definition.tgfoid=to_regprocedure('public.sync_sitaa_profile_email_from_auth()') and cardinality(trigger_definition.tgattr::smallint[])=1 and trigger_definition.tgqual is not null and (select count(*) from unnest(trigger_definition.tgattr::smallint[]) update_attribute(attnum) join pg_attribute attribute_definition on attribute_definition.attrelid=trigger_definition.tgrelid and attribute_definition.attnum=update_attribute.attnum and attribute_definition.attname='email' and not attribute_definition.attisdropped)=1 and regexp_replace(regexp_replace(split_part(split_part(lower(pg_get_triggerdef(trigger_definition.oid,false)),' when ',2),' execute function ',1),'[[:space:]()]','','g'),'::text','','g')='old.emailisdistinctfromnew.email')<>1
     or exists (select 1 from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgfoid in (to_regprocedure('public.handle_sitaa_auth_user_created()'),to_regprocedure('public.sync_sitaa_profile_email_from_auth()')) and not (trigger_definition.tgname='on_sitaa_auth_user_created' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgfoid=to_regprocedure('public.handle_sitaa_auth_user_created()') or trigger_definition.tgname='on_sitaa_auth_user_email_changed' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgfoid=to_regprocedure('public.sync_sitaa_profile_email_from_auth()'))) then
    raise exception 'sitaa_0009_rollback_post_auth_trigger_failed' using errcode='55000';
  end if;
end;
$post_rollback$;

commit;
