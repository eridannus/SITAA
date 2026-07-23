-- Verificador transaccional 0010. Simula contratos DB; nunca invoca Auth Admin.
begin;
set local time zone 'UTC';
set local datestyle to 'ISO, MDY';

do $static_contract$
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
     or (select string_agg(tgname||':'||tgtype::text||':'||tgenabled||':'||tgfoid::regprocedure::text,'|' order by tgname) from pg_trigger where tgrelid='public.admin_auth_operations'::regclass and not tgisinternal)<>
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
    raise exception '0010_verify_table_shape_mismatch';
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
      and not exists(select 1 from pg_attribute attribute_definition
        where attribute_definition.attrelid=table_definition.oid
          and attribute_definition.attnum>0 and not attribute_definition.attisdropped
          and attribute_definition.attacl is not null
          and exists(select 1 from aclexplode(attribute_definition.attacl)))
  ) then
    raise exception '0010_verify_table_acl_mismatch';
  end if;

  foreach function_oid in array array[
    'public.guard_admin_auth_operation_b3a()'::regprocedure,
    'public.get_admin_account_auth_lifecycle_context_b3a(uuid)'::regprocedure,
    'public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)'::regprocedure,
    'public.finalize_admin_account_auth_reactivation_b3a(uuid)'::regprocedure,
    'public.claim_admin_auth_operation_b3a(uuid,uuid)'::regprocedure,
    'public.record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text)'::regprocedure
  ] loop
    if not (select p.prosecdef and pg_get_userbyid(p.proowner)='postgres'
      and p.proconfig=array['search_path=pg_catalog, public']::text[]
      and l.lanname='plpgsql' from pg_proc p join pg_language l on l.oid=p.prolang where p.oid=function_oid)
      or exists(select 1 from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where p.oid=function_oid and (a.is_grantable or a.grantee=0)) then
      raise exception '0010_verify_function_security_mismatch:%',function_oid;
    end if;
  end loop;
  if exists (
    select 1 from (values
      ('guard_admin_auth_operation_b3a()','d80211e442b6d9334123d8e0d4ada4c8'),
      ('get_admin_account_auth_lifecycle_context_b3a(uuid)','44fd317ebc207cbf572551835fb9be7d'),
      ('prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)','2d8d580677411110fb9255fcced4c715'),
      ('claim_admin_auth_operation_b3a(uuid,uuid)','7da7aec9b4ff17aa551a4cf820d5cfbd'),
      ('record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text)','6467440196296d77662eb4cce77d3226'),
      ('finalize_admin_account_auth_reactivation_b3a(uuid)','b8223a508478e80edd340e231b66abeb')
    ) expected(signature,body_hash)
    left join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
    where p.oid is null or md5(regexp_replace(p.prosrc,'\s+','','g'))<>expected.body_hash
  ) then
    raise exception '0010_verify_function_body_mismatch';
  end if;

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
     raise exception '0010_verify_signature_or_volatility_mismatch';
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
    raise exception '0010_verify_result_contract_mismatch';
  end if;
  if (select count(*) from information_schema.tables where table_schema='public' and table_type='BASE TABLE')<>19
     or (select count(*) from information_schema.columns where table_schema='public')<>183
     or (select count(*) from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname='public' and c.contype in ('p','f','u','c'))<>96
     or (select count(*) from pg_indexes where schemaname='public')<>48
     or (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal)<>13
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>60
     or (select count(*) from pg_policies where schemaname='public')<>25
     or (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and c.relrowsecurity)<>19
     or (select count(*) from information_schema.routine_privileges where routine_schema='public')<>147
     or (select count(*) from information_schema.table_privileges where table_schema='public')<>274
     or (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault('s',c.relowner))) acl where n.nspname='public' and c.relkind='S')<>6
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where n.nspname='public')+
         (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault(case when c.relkind='S' then 's'::"char" else 'r'::"char" end,c.relowner))) acl where n.nspname='public' and c.relkind in ('r','p','v','m','S'))<>463
     or (select md5(coalesce(string_agg(p.oid::regprocedure::text,'|' order by p.oid::regprocedure::text),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname not in ('guard_admin_auth_operation_b3a','get_admin_account_auth_lifecycle_context_b3a','prepare_admin_account_auth_lifecycle_b3a','finalize_admin_account_auth_reactivation_b3a','claim_admin_auth_operation_b3a','record_admin_auth_operation_result_b3a'))<>'89d8e1d260ccc0af72ee42c394f79f90'
     or (select md5(coalesce(string_agg(p.oid::regprocedure::text||':'||md5(regexp_replace(p.prosrc,'\s+','','g')),'|' order by p.oid::regprocedure::text),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname not in ('guard_admin_auth_operation_b3a','get_admin_account_auth_lifecycle_context_b3a','prepare_admin_account_auth_lifecycle_b3a','finalize_admin_account_auth_reactivation_b3a','claim_admin_auth_operation_b3a','record_admin_auth_operation_result_b3a'))<>'71f9763d702e95e4eede51a4a4611694'
     or exists (
       select 1 from (values
         ('is_exact_b1_account_admin_profile_b2b(uuid)','104d16a531ea53a5b4908102322097dc'),
         ('get_admin_account_lifecycle_context_b2b(uuid)','6e7c8bb5e2dcf99fce6a75e03e07c309'),
         ('transition_admin_account_lifecycle_b2b(uuid,text,text)','7f940968051ff1b844443f6c76b561c3'),
         ('is_sitaa_operational_account_active()','f85f733578f09c0f7466af7e18a90f4c'),
         ('get_admin_identity_correction_context_b2a(uuid)','83932d04ff8f1b33793e8c7a49bb8e68'),
         ('correct_admin_account_identity_b2a(uuid,text,text,text,text,text,uuid,text)','ce05cbc529473c070953e765e3ee05b2'),
         ('enforce_activity_writer_integrity_b2a()','c58bd04859f1e2a044fcca58d3333e3c')
       ) expected(signature,body_hash)
       left join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
       where p.oid is null or md5(regexp_replace(p.prosrc,'\s+','','g'))<>expected.body_hash
     ) then
    raise exception '0010_verify_accumulated_contract_drift';
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
         select p.oid,acl.grantee from pg_proc p
         cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
         where p.oid in (select expected.function_oid from expected)
           and acl.privilege_type='EXECUTE' and not acl.is_grantable
       )
       (select * from expected except select * from actual)
       union all
       (select * from actual except select * from expected)
     )
     or exists (
       select 1 from pg_proc p
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
     raise exception '0010_verify_function_acl_mismatch';
  end if;
  if (select count(*) from pg_trigger t where not t.tgisinternal and t.tgname='on_sitaa_auth_user_created')<>1
     or (select count(*) from pg_trigger t where not t.tgisinternal and t.tgname='on_sitaa_auth_user_created' and t.tgrelid='auth.users'::regclass and t.tgenabled='O' and t.tgtype=5::smallint and t.tgfoid=to_regprocedure('public.handle_sitaa_auth_user_created()') and cardinality(t.tgattr::smallint[])=0 and t.tgqual is null)<>1
     or (select count(*) from pg_trigger t where not t.tgisinternal and t.tgname='on_sitaa_auth_user_email_changed')<>1
     or (select count(*) from pg_trigger t where not t.tgisinternal and t.tgname='on_sitaa_auth_user_email_changed' and t.tgrelid='auth.users'::regclass and t.tgenabled='O' and t.tgtype=17::smallint and t.tgfoid=to_regprocedure('public.sync_sitaa_profile_email_from_auth()') and cardinality(t.tgattr::smallint[])=1 and t.tgqual is not null and (select count(*) from unnest(t.tgattr::smallint[]) u(attnum) join pg_attribute a on a.attrelid=t.tgrelid and a.attnum=u.attnum and a.attname='email' and not a.attisdropped)=1 and regexp_replace(regexp_replace(split_part(split_part(lower(pg_get_triggerdef(t.oid,false)),' when ',2),' execute function ',1),'[[:space:]()]','','g'),'::text','','g')='old.emailisdistinctfromnew.email')<>1 then
    raise exception '0010_verify_auth_trigger_contract_mismatch';
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
    raise exception '0010_verify_policy_or_seed_mismatch';
  end if;
end;
$static_contract$;

create temporary table sitaa_0010_context(
  run_marker text not null,program_id uuid not null,division_id uuid not null,
  institutional_today date not null
) on commit drop;
insert into sitaa_0010_context
select substr(replace(gen_random_uuid()::text,'-',''),1,12),p.id,p.division_id,
  public.sitaa_current_mexico_date()
from public.academic_programs p where p.is_active order by p.id limit 1;
do $$ begin if (select count(*) from pg_temp.sitaa_0010_context)<>1 then raise exception '0010_verify_active_program_fixture_missing'; end if; end $$;

create temporary table sitaa_0010_baseline_exact_admins(
  profile_id uuid primary key,profile_hash text not null,assignment_hash text not null,audit_hash text not null
) on commit drop;
insert into sitaa_0010_baseline_exact_admins
select p.id,md5(row_to_json(p)::text),
  md5(coalesce((select string_agg(row_to_json(r)::text,'|' order by r.id) from public.role_assignments r where r.user_id=p.id),'')),
  md5(coalesce((select string_agg(row_to_json(a)::text,'|' order by a.id) from public.admin_audit_events a where a.actor_profile_id=p.id or a.target_profile_id=p.id),''))
from public.profiles p where public.is_exact_b1_account_admin_profile_b2b(p.id);

create temporary table sitaa_0010_cases(label text primary key,id uuid not null unique,email text not null unique,identifier text null unique) on commit drop;
create temporary table sitaa_0010_identifiers(label text primary key,identifier text not null unique) on commit drop;
create function pg_temp.case_id(target_label text) returns uuid language sql stable set search_path=pg_temp as $$ select id from sitaa_0010_cases where label=target_label $$;
create function pg_temp.set_actor(target_label text,target_role text default 'authenticated') returns void language plpgsql set search_path=pg_temp,pg_catalog as $$
declare target_id uuid:=pg_temp.case_id(target_label);
begin
  perform set_config('request.jwt.claim.sub',target_id::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',target_id,'role',target_role)::text,true);
end $$;
create function pg_temp.allocate_identifier(target_label text) returns text language plpgsql set search_path=pg_temp,public,pg_catalog as $$
declare marker text:=(select run_marker from sitaa_0010_context); candidate text; attempt integer;
begin
  for attempt in 0..999 loop
    candidate:='0'||lpad(mod((('x'||substr(md5(marker||target_label||attempt::text),1,15))::bit(60)::bigint),1000000000000000::bigint)::text,15,'0');
    if not exists(select 1 from public.profiles where institutional_id_value=candidate)
       and not exists(select 1 from sitaa_0010_identifiers where identifier=candidate) then
      insert into sitaa_0010_identifiers values(target_label,candidate); return candidate;
    end if;
  end loop;
  raise exception '0010_verify_identifier_allocator_exhausted';
end $$;
create function pg_temp.create_case(target_label text,target_kind text,target_person text default null,target_status text default 'active')
returns uuid language plpgsql set search_path=public,auth,pg_temp,pg_catalog as $$
declare target_id uuid:=gen_random_uuid(); marker text:=(select run_marker from sitaa_0010_context);
  target_email text:=replace(target_label,'_','-')||'-'||marker||'@example.invalid'; target_identifier text;
begin
  target_identifier:=case when target_kind='institutional' then pg_temp.allocate_identifier(target_label) end;
  insert into sitaa_0010_cases values(target_label,target_id,target_email,target_identifier);
  insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
  values(target_id,'authenticated','authenticated',target_email,'',now(),
    case when target_kind='technical' then jsonb_build_object('sitaa_account_kind','technical','sitaa_first_names','Soporte 0010') else jsonb_build_object('provider','google','providers',jsonb_build_array('google')) end,
    jsonb_build_object('name','Cuenta sintética 0010'),now(),now());
  if target_kind='institutional' and target_status<>'pending_registration' then
    update public.profiles set first_names='Persona',paternal_surname='Prueba',maternal_surname=null,
      full_name='Persona Prueba',account_status=target_status,person_type=target_person,
      primary_program_id=(select program_id from sitaa_0010_context),
      institutional_id_type=case when target_person='student' then 'student_account' else 'worker_number' end,
      institutional_id_value=target_identifier,is_active=target_status='active',activated_at=now(),
      deactivated_at=case when target_status='inactive' then now() end where id=target_id;
  elsif target_kind='technical' and target_status='inactive' then
    update public.profiles set account_status='inactive',is_active=false,deactivated_at=now() where id=target_id;
  end if;
  return target_id;
end $$;

grant select on pg_temp.sitaa_0010_cases,pg_temp.sitaa_0010_context to authenticated,service_role;
grant execute on function pg_temp.case_id(text),pg_temp.set_actor(text,text) to authenticated,service_role;

create temporary table sitaa_0010_invalid_transition_baseline(
  profile_hash text not null,
  ledger_count bigint not null,
  ledger_hash text not null,
  lifecycle_count bigint not null,
  lifecycle_hash text not null,
  auth_count bigint not null,
  auth_hash text not null
) on commit drop;
create temporary table sitaa_0010_invalid_transition_outcomes(
  transition_label text primary key,
  observed_sqlstate text not null,
  observed_message text not null
) on commit drop;
grant select,insert on pg_temp.sitaa_0010_invalid_transition_outcomes to authenticated;

select pg_temp.create_case('admin_a','technical');
select pg_temp.create_case('admin_b','technical');
select pg_temp.create_case('admin_malformed','technical');
select pg_temp.create_case('admin_inactive','technical',null,'inactive');
select pg_temp.create_case('ordinary','institutional','professor');
select pg_temp.create_case('student','institutional','student');
select pg_temp.create_case('active_target','institutional','professor');
select pg_temp.create_case('status_replay_target','institutional','professor');
select pg_temp.create_case('inactive_target','institutional','student','inactive');
select pg_temp.create_case('terminal_target','institutional','professor');
select pg_temp.create_case('restore_failure_target','institutional','student','inactive');
select pg_temp.create_case('authority_loss_target','institutional','professor','inactive');
select pg_temp.create_case('pending_target','institutional',null,'pending_registration');

insert into public.role_assignments(user_id,role_code,scope_type,service_area,division_id,program_id,starts_at,ends_at,is_active,assigned_by) values
(pg_temp.case_id('admin_a'),'technical_admin','system','technical',null,null,(select institutional_today from sitaa_0010_context),null,true,pg_temp.case_id('admin_a')),
(pg_temp.case_id('admin_b'),'technical_admin','system','technical',null,null,(select institutional_today from sitaa_0010_context),null,true,pg_temp.case_id('admin_a')),
(pg_temp.case_id('admin_malformed'),'technical_admin','own','technical',null,null,(select institutional_today from sitaa_0010_context),null,true,pg_temp.case_id('admin_a')),
(pg_temp.case_id('admin_inactive'),'technical_admin','system','technical',null,null,(select institutional_today from sitaa_0010_context),null,true,pg_temp.case_id('admin_a')),
(pg_temp.case_id('active_target'),'professor','program','both',null,(select program_id from sitaa_0010_context),(select institutional_today from sitaa_0010_context),null,true,pg_temp.case_id('admin_a'));

create temporary table sitaa_0010_operational_baseline(
  object_name text primary key,content_hash text not null
) on commit drop;
insert into sitaa_0010_operational_baseline values
('auth_users',md5(coalesce((select string_agg(row_to_json(u)::text,'|' order by u.id) from auth.users u where not exists(select 1 from pg_temp.sitaa_0010_cases c where c.id=u.id)),''))),
('profiles',md5(coalesce((select string_agg(row_to_json(p)::text,'|' order by p.id) from public.profiles p where not exists(select 1 from pg_temp.sitaa_0010_cases c where c.id=p.id)),''))),
('role_assignments',md5(coalesce((select string_agg(row_to_json(r)::text,'|' order by r.id) from public.role_assignments r where not exists(select 1 from pg_temp.sitaa_0010_cases c where c.id=r.user_id)),''))),
('activities',md5(coalesce((select string_agg(row_to_json(a)::text,'|' order by a.id) from public.activities a),''))),
('activity_participants',md5(coalesce((select string_agg(row_to_json(p)::text,'|' order by p.id) from public.activity_participants p),''))),
('prior_audit',md5(coalesce((select string_agg(row_to_json(a)::text,'|' order by a.id) from public.admin_audit_events a where not exists(select 1 from pg_temp.sitaa_0010_cases c where c.id=a.actor_profile_id or c.id=a.target_profile_id)),'')));

-- Denegación de tabla directa bajo roles cliente y service_role.
select pg_temp.set_actor('admin_a');
set local role authenticated;
do $$ begin
  begin perform 1 from public.admin_auth_operations; raise exception '0010_verify_authenticated_table_read_unexpected';
  exception when insufficient_privilege then null; end;
  begin perform public.transition_admin_account_lifecycle_b2b(pg_temp.case_id('active_target'),'deactivate','Motivo sintético 0010 válido'); raise exception '0010_verify_direct_b2b_unexpected';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select pg_temp.set_actor('admin_a','service_role');
set local role service_role;
do $$ begin
  begin perform 1 from public.admin_auth_operations; raise exception '0010_verify_service_table_read_unexpected';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Actores ordinarios, perfiles pendientes y autoría propia fallan cerrados.
select pg_temp.set_actor('ordinary'); set local role authenticated;
do $$ begin
  begin perform public.get_admin_account_auth_lifecycle_context_b3a(pg_temp.case_id('active_target')); raise exception '0010_verify_ordinary_context_unexpected';
  exception when insufficient_privilege then null; end;
  begin perform public.prepare_admin_account_auth_lifecycle_b3a(pg_temp.case_id('active_target'),'deactivate','Motivo sintético 0010 válido',gen_random_uuid()); raise exception '0010_verify_ordinary_prepare_unexpected';
  exception when insufficient_privilege then null; end;
  begin perform public.finalize_admin_account_auth_reactivation_b3a(gen_random_uuid()); raise exception '0010_verify_ordinary_finalize_unexpected';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select pg_temp.set_actor('admin_a'); set local role authenticated;
do $$ begin
  begin perform public.prepare_admin_account_auth_lifecycle_b3a(pg_temp.case_id('admin_a'),'deactivate','Motivo sintético 0010 válido',gen_random_uuid()); raise exception '0010_verify_self_unexpected';
  exception when insufficient_privilege then null; end;
  begin perform public.prepare_admin_account_auth_lifecycle_b3a(pg_temp.case_id('pending_target'),'deactivate','Motivo sintético 0010 válido',gen_random_uuid()); raise exception '0010_verify_pending_unexpected';
  exception when raise_exception then
    if sqlerrm<>'sitaa_account_lifecycle_pending_target' or sqlstate<>'P0001' then raise; end if;
  end;
end $$;
reset role;

-- La transición pública es total: NULL, vacío, desconocido y mayúsculas fallan sin efectos.
insert into pg_temp.sitaa_0010_invalid_transition_baseline
select
  (select md5(row_to_json(profile_row)::text)
   from public.profiles profile_row where profile_row.id=pg_temp.case_id('active_target')),
  (select count(*) from public.admin_auth_operations),
  (select md5(coalesce(string_agg(row_to_json(operation_row)::text,'|' order by operation_row.id),''))
   from public.admin_auth_operations operation_row),
  (select count(*) from public.admin_audit_events
   where action_code in ('account_deactivated','account_reactivated')),
  (select md5(coalesce(string_agg(row_to_json(audit_row)::text,'|' order by audit_row.id),''))
   from public.admin_audit_events audit_row
   where action_code in ('account_deactivated','account_reactivated')),
  (select count(*) from public.admin_audit_events
   where action_code in (
     'account_auth_suspended','account_auth_restored',
     'account_auth_suspension_failed','account_auth_restoration_failed'
   )),
  (select md5(coalesce(string_agg(row_to_json(audit_row)::text,'|' order by audit_row.id),''))
   from public.admin_audit_events audit_row
   where action_code in (
     'account_auth_suspended','account_auth_restored',
     'account_auth_suspension_failed','account_auth_restoration_failed'
   ));

select pg_temp.set_actor('admin_a'); set local role authenticated;
do $invalid_transition_client_contract$
declare
  transition_value text;
  transition_label text;
begin
  foreach transition_value in array array[null::text,'','suspend','DEACTIVATE'] loop
    transition_label:=case
      when transition_value is null then '<NULL>'
      when transition_value='' then '<EMPTY>'
      else transition_value
    end;
    begin
      perform public.prepare_admin_account_auth_lifecycle_b3a(
        pg_temp.case_id('active_target'),transition_value,
        'Motivo sintético de transición inválida 0010',gen_random_uuid()
      );
      insert into pg_temp.sitaa_0010_invalid_transition_outcomes
      values(transition_label,'UNEXPECTED','0010_verify_invalid_transition_unexpected');
    exception when others then
      insert into pg_temp.sitaa_0010_invalid_transition_outcomes
      values(transition_label,sqlstate,sqlerrm);
    end;
  end loop;
end;
$invalid_transition_client_contract$;
reset role;

do $invalid_transition_owner_postconditions$
begin
  if (select count(*) from pg_temp.sitaa_0010_invalid_transition_outcomes)<>4
     or exists(
       select 1 from pg_temp.sitaa_0010_invalid_transition_outcomes
       where observed_sqlstate<>'22023'
          or observed_message<>'sitaa_account_lifecycle_invalid_transition'
     )
     or exists(
       (values ('<NULL>'),('<EMPTY>'),('suspend'),('DEACTIVATE'))
       except
       select transition_label from pg_temp.sitaa_0010_invalid_transition_outcomes
     )
     or (select profile_hash from pg_temp.sitaa_0010_invalid_transition_baseline) is distinct from
        (select md5(row_to_json(profile_row)::text)
         from public.profiles profile_row where profile_row.id=pg_temp.case_id('active_target'))
     or (select ledger_count from pg_temp.sitaa_0010_invalid_transition_baseline)<>
        (select count(*) from public.admin_auth_operations)
     or (select ledger_hash from pg_temp.sitaa_0010_invalid_transition_baseline) is distinct from
        (select md5(coalesce(string_agg(row_to_json(operation_row)::text,'|' order by operation_row.id),''))
         from public.admin_auth_operations operation_row)
     or (select lifecycle_count from pg_temp.sitaa_0010_invalid_transition_baseline)<>
        (select count(*) from public.admin_audit_events
         where action_code in ('account_deactivated','account_reactivated'))
     or (select lifecycle_hash from pg_temp.sitaa_0010_invalid_transition_baseline) is distinct from
        (select md5(coalesce(string_agg(row_to_json(audit_row)::text,'|' order by audit_row.id),''))
         from public.admin_audit_events audit_row
         where action_code in ('account_deactivated','account_reactivated'))
     or (select auth_count from pg_temp.sitaa_0010_invalid_transition_baseline)<>
        (select count(*) from public.admin_audit_events
         where action_code in (
           'account_auth_suspended','account_auth_restored',
           'account_auth_suspension_failed','account_auth_restoration_failed'
         ))
     or (select auth_hash from pg_temp.sitaa_0010_invalid_transition_baseline) is distinct from
        (select md5(coalesce(string_agg(row_to_json(audit_row)::text,'|' order by audit_row.id),''))
         from public.admin_audit_events audit_row
         where action_code in (
           'account_auth_suspended','account_auth_restored',
           'account_auth_suspension_failed','account_auth_restoration_failed'
         )) then
    raise exception '0010_verify_invalid_transition_contract_failed';
  end if;
end;
$invalid_transition_owner_postconditions$;

select pg_temp.set_actor('admin_malformed'); set local role authenticated;
do $$ begin
  begin perform public.prepare_admin_account_auth_lifecycle_b3a(pg_temp.case_id('active_target'),'deactivate','Motivo sintético 0010 válido',gen_random_uuid()); raise exception '0010_verify_malformed_admin_unexpected';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select pg_temp.set_actor('admin_inactive'); set local role authenticated;
do $$ begin
  begin perform public.prepare_admin_account_auth_lifecycle_b3a(pg_temp.case_id('active_target'),'deactivate','Motivo sintético 0010 válido',gen_random_uuid()); raise exception '0010_verify_inactive_admin_unexpected';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select pg_temp.set_actor('admin_a'); set local role authenticated;
do $context_and_acl$
declare context_rows integer; context_row record;
begin
  select count(*) into context_rows from public.get_admin_account_auth_lifecycle_context_b3a(pg_temp.case_id('active_target'));
  select * into context_row from public.get_admin_account_auth_lifecycle_context_b3a(pg_temp.case_id('active_target'));
  if context_rows<>1 or context_row.b3a_available is distinct from true or context_row.target_profile_id<>pg_temp.case_id('active_target') then
    raise exception '0010_verify_context_cardinality_failed';
  end if;
end;
$context_and_acl$;
reset role;
select pg_temp.set_actor('admin_a','service_role'); set local role service_role;
do $$ begin
  begin perform public.claim_admin_auth_operation_b3a(gen_random_uuid(),pg_temp.case_id('ordinary')); raise exception '0010_verify_ordinary_service_caller_unexpected';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

create temporary table sitaa_0010_results(label text primary key,operation_id uuid not null,request_id uuid not null) on commit drop;
grant select,insert,update on pg_temp.sitaa_0010_results to authenticated,service_role;
create temporary table sitaa_0010_rpc_observations(
  label text primary key,
  operation_id uuid not null,
  status text not null,
  completed_stage text not null,
  attempt_count integer null,
  claimed boolean null,
  last_error_code text null,
  updated_at timestamptz null
) on commit drop;
grant select,insert,update on pg_temp.sitaa_0010_rpc_observations to authenticated,service_role;

-- Desactivación: perfil primero, idempotencia, reintento y un solo evento de ciclo.
select pg_temp.set_actor('admin_a'); set local role authenticated;
do $deactivate_prepare$
declare request_uuid uuid:=gen_random_uuid(); first_result record; repeated record;
begin
  select * into first_result from public.prepare_admin_account_auth_lifecycle_b3a(pg_temp.case_id('active_target'),'deactivate','Motivo sintético coordinado 0010',request_uuid);
  select * into repeated from public.prepare_admin_account_auth_lifecycle_b3a(pg_temp.case_id('active_target'),'deactivate','  Motivo   sintético coordinado 0010  ',request_uuid);
  if first_result.operation_id<>repeated.operation_id or first_result.completed_stage<>'profile_suspended' then
    raise exception '0010_verify_deactivation_prepare_or_idempotency_failed';
  end if;
  insert into pg_temp.sitaa_0010_results values('deactivate',first_result.operation_id,request_uuid);
  insert into pg_temp.sitaa_0010_rpc_observations
  values(
    'deactivate_prepared',first_result.operation_id,first_result.status,
    first_result.completed_stage,first_result.attempt_count,null,
    first_result.last_error_code,first_result.updated_at
  );
  begin perform public.prepare_admin_account_auth_lifecycle_b3a(pg_temp.case_id('active_target'),'deactivate','Payload incompatible 0010',request_uuid); raise exception '0010_verify_request_reuse_unexpected';
  exception when unique_violation then null; end;
end;
$deactivate_prepare$;
reset role;

do $deactivate_prepare_owner_postconditions$
declare operation_row public.admin_auth_operations%rowtype;
begin
  select * into strict operation_row
  from public.admin_auth_operations
  where id=(select operation_id from pg_temp.sitaa_0010_results where label='deactivate');
  if (select account_status from public.profiles where id=pg_temp.case_id('active_target'))<>'inactive'
     or (select count(*) from public.admin_audit_events
         where target_profile_id=pg_temp.case_id('active_target')
           and action_code='account_deactivated')<>1
     or operation_row.request_id<>(select request_id from pg_temp.sitaa_0010_results where label='deactivate')
     or operation_row.requested_by_profile_id<>pg_temp.case_id('admin_a')
     or operation_row.target_profile_id<>pg_temp.case_id('active_target')
     or operation_row.operation_code<>'deactivate'
     or operation_row.status<>'open'
     or operation_row.completed_stage<>'profile_suspended'
     or operation_row.attempt_count<>0
     or operation_row.profile_audit_event_id is null
     or operation_row.auth_audit_event_id is not null
     or operation_row.reason<>'Motivo sintético coordinado 0010' then
    raise exception '0010_verify_deactivation_prepare_owner_postconditions_failed';
  end if;
end;
$deactivate_prepare_owner_postconditions$;

do $writer_guard_and_one_open_target$
declare
  source_row public.admin_auth_operations%rowtype;
  writer_value text;
  replacement_audit_id uuid;
begin
  select * into strict source_row from public.admin_auth_operations where id=(select operation_id from pg_temp.sitaa_0010_results where label='deactivate');

  -- La preparación aprobada debe haber dejado el marcador en un valor rechazado.
  if coalesce(current_setting('sitaa.b3a_writer',true),'')<>'' then
    raise exception '0010_verify_writer_not_cleared';
  end if;
  begin
    insert into public.admin_auth_operations(
      id,request_id,requested_by_profile_id,target_profile_id,operation_code,status,completed_stage,reason,
      attempt_count,profile_audit_event_id,requested_at,updated_at
    ) values (
      gen_random_uuid(),gen_random_uuid(),source_row.requested_by_profile_id,source_row.target_profile_id,
      source_row.operation_code,'open','profile_suspended',source_row.reason,0,source_row.profile_audit_event_id,now(),now()
    );
    raise exception '0010_verify_missing_writer_insert_unexpected';
  exception when insufficient_privilege then null; end;
  begin
    update public.admin_auth_operations set updated_at=updated_at+interval '1 second' where id=source_row.id;
    raise exception '0010_verify_missing_writer_update_unexpected';
  exception when insufficient_privilege then null; end;

  perform set_config('sitaa.b3a_writer','unknown',true);
  begin
    update public.admin_auth_operations set updated_at=updated_at+interval '1 second' where id=source_row.id;
    raise exception '0010_verify_unknown_writer_unexpected';
  exception when insufficient_privilege then null; end;
  perform set_config('sitaa.b3a_writer','',true);
  begin
    update public.admin_auth_operations set updated_at=updated_at+interval '1 second' where id=source_row.id;
    raise exception '0010_verify_empty_writer_unexpected';
  exception when insufficient_privilege then null; end;

  foreach writer_value in array array['prepare','claim','record','finalize'] loop
    perform set_config('sitaa.b3a_writer',writer_value,true);
    begin
      update public.admin_auth_operations set reason=reason||' alterado' where id=source_row.id;
      raise exception '0010_verify_writer_column_allowlist_unexpected:%',writer_value;
    exception when check_violation then null; end;
  end loop;

  insert into public.admin_audit_events(
    actor_profile_id,target_profile_id,action_code,outcome,reason,role_assignment_id,metadata
  ) values(
    pg_temp.case_id('admin_a'),pg_temp.case_id('ordinary'),
    'account_deactivated','success','Evidencia sintética alternativa 0010',null,
    jsonb_build_object('changed_fields',jsonb_build_array('account_status'))
  ) returning id into replacement_audit_id;
  perform set_config('sitaa.b3a_writer','record',true);
  begin
    update public.admin_auth_operations
    set profile_audit_event_id=replacement_audit_id
    where id=source_row.id;
    raise exception '0010_verify_profile_audit_replacement_unexpected';
  exception when check_violation then null; end;
  if (select profile_audit_event_id from public.admin_auth_operations where id=source_row.id)
     is distinct from source_row.profile_audit_event_id then
    raise exception '0010_verify_profile_audit_replacement_changed_row';
  end if;

  -- Con writer prepare válido, el índice parcial conserva una sola operación no final.
  perform set_config('sitaa.b3a_writer','prepare',true);
  begin
    insert into public.admin_auth_operations(
      id,request_id,requested_by_profile_id,target_profile_id,operation_code,status,completed_stage,reason,
      attempt_count,profile_audit_event_id,requested_at,updated_at
    ) values (
      gen_random_uuid(),gen_random_uuid(),source_row.requested_by_profile_id,source_row.target_profile_id,
      source_row.operation_code,'open','profile_suspended',source_row.reason,0,source_row.profile_audit_event_id,now(),now()
    );
    raise exception '0010_verify_second_open_operation_unexpected';
  exception when unique_violation then null; end;

  foreach writer_value in array array['','prepare','claim','record','finalize','unknown'] loop
    perform set_config('sitaa.b3a_writer',writer_value,true);
    begin delete from public.admin_auth_operations where id=source_row.id; raise exception '0010_verify_delete_unexpected:%',writer_value;
    exception when insufficient_privilege then null; end;
    begin truncate table public.admin_auth_operations; raise exception '0010_verify_truncate_unexpected:%',writer_value;
    exception when insufficient_privilege then null; end;
  end loop;
  perform set_config('sitaa.b3a_writer','',true);
end;
$writer_guard_and_one_open_target$;

do $invalid_state_stage_evidence_matrix$
declare source_row public.admin_auth_operations%rowtype;
begin
  select * into strict source_row from public.admin_auth_operations where id=(select operation_id from pg_temp.sitaa_0010_results where label='deactivate');
  perform set_config('sitaa.b3a_writer','prepare',true);
  begin
    insert into public.admin_auth_operations(request_id,requested_by_profile_id,target_profile_id,operation_code,status,completed_stage,reason,profile_audit_event_id)
    values(gen_random_uuid(),pg_temp.case_id('admin_a'),pg_temp.case_id('ordinary'),'reactivate','open','prepared',source_row.reason,source_row.profile_audit_event_id);
    raise exception '0010_verify_reactivation_initial_evidence_unexpected';
  exception when check_violation then null; end;
  perform set_config('sitaa.b3a_writer','prepare',true);
  begin
    insert into public.admin_auth_operations(request_id,requested_by_profile_id,target_profile_id,operation_code,status,completed_stage,reason)
    values(gen_random_uuid(),pg_temp.case_id('admin_a'),pg_temp.case_id('ordinary'),'deactivate','open','prepared',source_row.reason);
    raise exception '0010_verify_deactivation_prepared_unexpected';
  exception when check_violation then null; end;
  perform set_config('sitaa.b3a_writer','prepare',true);
  begin
    insert into public.admin_auth_operations(request_id,requested_by_profile_id,target_profile_id,operation_code,status,completed_stage,reason,profile_audit_event_id)
    values(gen_random_uuid(),pg_temp.case_id('admin_a'),pg_temp.case_id('ordinary'),'deactivate','succeeded','completed',source_row.reason,source_row.profile_audit_event_id);
    raise exception '0010_verify_success_without_terminal_evidence_unexpected';
  exception when check_violation then null; end;
  perform set_config('sitaa.b3a_writer','',true);
end;
$invalid_state_stage_evidence_matrix$;

select pg_temp.set_actor('admin_a','service_role'); set local role service_role;
do $deactivate_service$
declare
  op uuid:=(select operation_id from pg_temp.sitaa_0010_results where label='deactivate');
  claim record;
  result record;
  previous_updated_at timestamptz:=(select updated_at from pg_temp.sitaa_0010_rpc_observations where label='deactivate_prepared');
begin
  select * into claim from public.claim_admin_auth_operation_b3a(op,pg_temp.case_id('admin_a'));
  if claim.completed_stage<>'profile_suspended' or claim.attempt_count<>1
     or claim.updated_at<previous_updated_at then raise exception '0010_verify_claim_failed'; end if;
  select * into claim from public.claim_admin_auth_operation_b3a(op,pg_temp.case_id('admin_a'));
  if claim.claimed or claim.status<>'processing' or claim.attempt_count<>1 then
    raise exception '0010_verify_fresh_processing_contract_failed';
  end if;
  select * into result from public.record_admin_auth_operation_result_b3a(op,pg_temp.case_id('admin_a'),claim.attempt_count,'retryable_failure','auth_temporarily_unavailable');
  if result.status<>'retryable_failure' or result.completed_stage<>'profile_suspended'
     or result.updated_at<claim.updated_at then raise exception '0010_verify_retryable_failed'; end if;
  select * into claim from public.claim_admin_auth_operation_b3a(op,pg_temp.case_id('admin_b'));
  if claim.attempt_count<>2 or claim.updated_at<result.updated_at then raise exception '0010_verify_retry_claim_failed'; end if;
  select * into result from public.record_admin_auth_operation_result_b3a(op,pg_temp.case_id('admin_b'),claim.attempt_count,'auth_succeeded',null);
  if result.status<>'succeeded' or result.completed_stage<>'completed'
     or result.updated_at<claim.updated_at then raise exception '0010_verify_deactivation_completion_failed'; end if;
  insert into pg_temp.sitaa_0010_rpc_observations
  values(
    'deactivate_completed',op,result.status,result.completed_stage,
    result.attempt_count,null,result.last_error_code,result.updated_at
  );
  select * into claim from public.claim_admin_auth_operation_b3a(op,pg_temp.case_id('admin_b'));
  if claim.claimed or claim.status<>'succeeded' or claim.completed_stage<>'completed' then
    raise exception '0010_verify_final_operation_replay_failed';
  end if;
end;
$deactivate_service$;
reset role;

do $deactivate_service_owner_postconditions$
declare operation_row public.admin_auth_operations%rowtype;
begin
  select * into strict operation_row
  from public.admin_auth_operations
  where id=(select operation_id from pg_temp.sitaa_0010_results where label='deactivate');
  if operation_row.status<>'succeeded'
     or operation_row.completed_stage<>'completed'
     or operation_row.attempt_count<>2
     or operation_row.auth_synchronized_at is null
     or operation_row.completed_at is null
     or operation_row.auth_synchronized_at<>operation_row.completed_at
     or operation_row.completed_at<>operation_row.updated_at
     or operation_row.profile_audit_event_id is null
     or operation_row.auth_audit_event_id is null
     or operation_row.completed_by_profile_id<>pg_temp.case_id('admin_b') then
    raise exception '0010_verify_deactivation_service_owner_postconditions_failed';
  end if;
end;
$deactivate_service_owner_postconditions$;

select pg_temp.set_actor('admin_a'); set local role authenticated;
do $succeeded_request_replay$
declare replay record; operation_row record;
begin
  select * into operation_row from pg_temp.sitaa_0010_results where label='deactivate';
  select * into replay from public.prepare_admin_account_auth_lifecycle_b3a(
    pg_temp.case_id('active_target'),'deactivate','Motivo sintético coordinado 0010',operation_row.request_id
  );
  if replay.operation_id<>operation_row.operation_id or replay.status<>'succeeded' then
    raise exception '0010_verify_succeeded_request_replay_failed';
  end if;
end;
$succeeded_request_replay$;
reset role;

do $deactivation_evidence$
begin
  if (select count(*) from public.admin_audit_events where target_profile_id=pg_temp.case_id('active_target') and action_code='account_deactivated')<>1
     or (select actor_profile_id from public.admin_audit_events where target_profile_id=pg_temp.case_id('active_target') and action_code='account_deactivated')<>pg_temp.case_id('admin_a')
     or (select count(*) from public.admin_audit_events where target_profile_id=pg_temp.case_id('active_target') and action_code='account_auth_suspended' and outcome='success' and metadata ? 'operation_id' and metadata->'changed_fields'=jsonb_build_array('auth_access'))<>1
     or (select actor_profile_id from public.admin_audit_events where target_profile_id=pg_temp.case_id('active_target') and action_code='account_auth_suspended')<>pg_temp.case_id('admin_b')
     or (select count(*) from public.role_assignments where user_id=pg_temp.case_id('active_target'))<>1 then
    raise exception '0010_verify_deactivation_evidence_or_preservation_failed';
  end if;
end;
$deactivation_evidence$;

-- El mismo request_id devuelve la misma operación en open, processing, retryable y succeeded.
select pg_temp.set_actor('admin_a'); set local role authenticated;
do $status_replay_prepare$
declare prepared record; request_uuid uuid:=gen_random_uuid();
begin
  select * into prepared from public.prepare_admin_account_auth_lifecycle_b3a(
    pg_temp.case_id('status_replay_target'),'deactivate','Motivo sintético para replay de estados 0010',request_uuid
  );
  insert into pg_temp.sitaa_0010_results values('status_replay',prepared.operation_id,request_uuid);
end;
$status_replay_prepare$;
reset role;
select pg_temp.set_actor('admin_a','service_role'); set local role service_role;
do $status_replay_claim$
declare operation_row record;
begin
  select * into operation_row from public.claim_admin_auth_operation_b3a(
    (select operation_id from pg_temp.sitaa_0010_results where label='status_replay'),pg_temp.case_id('admin_a')
  );
  if operation_row.status<>'processing' or not operation_row.claimed then raise exception '0010_verify_processing_fixture_failed'; end if;
end;
$status_replay_claim$;
reset role;
select pg_temp.set_actor('admin_a'); set local role authenticated;
do $processing_request_replay$
declare replay record; fixture record;
begin
  select * into fixture from pg_temp.sitaa_0010_results where label='status_replay';
  select * into replay from public.prepare_admin_account_auth_lifecycle_b3a(
    pg_temp.case_id('status_replay_target'),'deactivate','Motivo sintético para replay de estados 0010',fixture.request_id
  );
  if replay.operation_id<>fixture.operation_id or replay.status<>'processing' then raise exception '0010_verify_processing_request_replay_failed'; end if;
end;
$processing_request_replay$;
reset role;
select pg_temp.set_actor('admin_a','service_role'); set local role service_role;
do $status_replay_retryable$
declare result_row record;
begin
  select * into result_row from public.record_admin_auth_operation_result_b3a(
    (select operation_id from pg_temp.sitaa_0010_results where label='status_replay'),pg_temp.case_id('admin_a'),
    1,'retryable_failure','auth_temporarily_unavailable'
  );
  if result_row.status<>'retryable_failure' then raise exception '0010_verify_retryable_fixture_failed'; end if;
end;
$status_replay_retryable$;
reset role;
select pg_temp.set_actor('admin_a'); set local role authenticated;
do $retryable_request_replay$
declare replay record; fixture record;
begin
  select * into fixture from pg_temp.sitaa_0010_results where label='status_replay';
  select * into replay from public.prepare_admin_account_auth_lifecycle_b3a(
    pg_temp.case_id('status_replay_target'),'deactivate','Motivo sintético para replay de estados 0010',fixture.request_id
  );
  if replay.operation_id<>fixture.operation_id or replay.status<>'retryable_failure' then raise exception '0010_verify_retryable_request_replay_failed'; end if;
end;
$retryable_request_replay$;
reset role;
select pg_temp.set_actor('admin_b','service_role'); set local role service_role;
do $status_replay_complete$
declare
  op uuid:=(select operation_id from pg_temp.sitaa_0010_results where label='status_replay');
  claim record;
begin
  select * into claim from public.claim_admin_auth_operation_b3a(op,pg_temp.case_id('admin_b'));
  perform public.record_admin_auth_operation_result_b3a(
    op,pg_temp.case_id('admin_b'),
    claim.attempt_count,
    'auth_succeeded',null
  );
end;
$status_replay_complete$;
reset role;
select pg_temp.set_actor('admin_a'); set local role authenticated;
do $all_status_request_replay_complete$
declare replay record; fixture record;
begin
  select * into fixture from pg_temp.sitaa_0010_results where label='status_replay';
  select * into replay from public.prepare_admin_account_auth_lifecycle_b3a(
    pg_temp.case_id('status_replay_target'),'deactivate','Motivo sintético para replay de estados 0010',fixture.request_id
  );
  if replay.operation_id<>fixture.operation_id or replay.status<>'succeeded' then raise exception '0010_verify_all_status_request_replay_failed'; end if;
end;
$all_status_request_replay_complete$;
reset role;

-- Fallo terminal: perfil suspendido, error allowlisted y una sola evidencia minimizada.
select pg_temp.set_actor('admin_a'); set local role authenticated;
do $terminal_prepare$
declare prepared record; request_uuid uuid:=gen_random_uuid();
begin
  select * into prepared from public.prepare_admin_account_auth_lifecycle_b3a(pg_temp.case_id('terminal_target'),'deactivate','Motivo sintético para fallo terminal 0010',request_uuid);
  insert into pg_temp.sitaa_0010_results values('terminal',prepared.operation_id,request_uuid);
end;
$terminal_prepare$;
reset role;
select pg_temp.set_actor('admin_a','service_role'); set local role service_role;
do $terminal_service$
declare op uuid:=(select operation_id from pg_temp.sitaa_0010_results where label='terminal'); claim record; result record;
begin
  select * into claim from public.claim_admin_auth_operation_b3a(op,pg_temp.case_id('admin_a'));
  begin
    perform public.record_admin_auth_operation_result_b3a(op,pg_temp.case_id('admin_a'),claim.attempt_count,'terminal_failure','provider raw detail');
    raise exception '0010_verify_raw_error_code_unexpected';
  exception when invalid_parameter_value then null; end;
  select * into result from public.record_admin_auth_operation_result_b3a(op,pg_temp.case_id('admin_a'),claim.attempt_count,'terminal_failure','auth_update_rejected');
  if result.status<>'terminal_failure' or result.completed_stage<>'profile_suspended' or result.last_error_code<>'auth_update_rejected' then
    raise exception '0010_verify_terminal_result_failed';
  end if;
end;
$terminal_service$;
reset role;
do $terminal_evidence$
begin
  if (select account_status from public.profiles where id=pg_temp.case_id('terminal_target'))<>'inactive'
     or (select count(*) from public.admin_audit_events where target_profile_id=pg_temp.case_id('terminal_target') and action_code='account_auth_suspension_failed' and outcome='failure' and metadata->>'error_code'='auth_update_rejected')<>1
     or exists(select 1 from public.admin_audit_events where target_profile_id=pg_temp.case_id('terminal_target') and metadata::text~*'(provider raw detail|password|token|cookie|secret|email)') then
    raise exception '0010_verify_terminal_evidence_failed';
  end if;
end;
$terminal_evidence$;

select pg_temp.set_actor('admin_a'); set local role authenticated;
do $terminal_request_replay$
declare replay record; fixture record;
begin
  select * into fixture from pg_temp.sitaa_0010_results where label='terminal';
  select * into replay from public.prepare_admin_account_auth_lifecycle_b3a(
    pg_temp.case_id('terminal_target'),'deactivate','Motivo sintético para fallo terminal 0010',fixture.request_id
  );
  if replay.operation_id<>fixture.operation_id or replay.status<>'terminal_failure' then
    raise exception '0010_verify_terminal_request_replay_failed';
  end if;
end;
$terminal_request_replay$;
reset role;

-- Una operación exitosa más reciente suprime el fallo terminal anterior en contexto.
select pg_temp.set_actor('admin_a'); set local role authenticated;
do $terminal_recovery_prepare$
declare prepared record; request_uuid uuid:=gen_random_uuid();
begin
  select * into prepared from public.prepare_admin_account_auth_lifecycle_b3a(
    pg_temp.case_id('terminal_target'),'reactivate','Motivo sintético de recuperación posterior 0010',request_uuid
  );
  insert into pg_temp.sitaa_0010_results values('terminal_recovery',prepared.operation_id,request_uuid);
end;
$terminal_recovery_prepare$;
reset role;
select pg_temp.set_actor('admin_b','service_role'); set local role service_role;
do $terminal_recovery_auth$
declare op uuid:=(select operation_id from pg_temp.sitaa_0010_results where label='terminal_recovery'); claim record;
begin
  select * into claim from public.claim_admin_auth_operation_b3a(op,pg_temp.case_id('admin_b'));
  perform public.record_admin_auth_operation_result_b3a(op,pg_temp.case_id('admin_b'),claim.attempt_count,'auth_succeeded',null);
end;
$terminal_recovery_auth$;
reset role;
select pg_temp.set_actor('admin_b'); set local role authenticated;
do $terminal_recovery_finalize_and_context$
declare op uuid:=(select operation_id from pg_temp.sitaa_0010_results where label='terminal_recovery'); context_row record;
begin
  perform public.finalize_admin_account_auth_reactivation_b3a(op);
  select * into context_row from public.get_admin_account_auth_lifecycle_context_b3a(pg_temp.case_id('terminal_target'));
  if context_row.current_operation_id<>op or context_row.operation_status<>'succeeded'
     or context_row.completed_stage<>'completed' or context_row.can_retry_or_finalize then
    raise exception '0010_verify_latest_success_selection_failed';
  end if;
end;
$terminal_recovery_finalize_and_context$;
reset role;

-- Reactivación: Auth simulado precede al perfil y un segundo administrador finaliza.
select pg_temp.set_actor('admin_a'); set local role authenticated;
do $reactivate_prepare$
declare request_uuid uuid:=gen_random_uuid(); prepared record;
begin
  select * into prepared from public.prepare_admin_account_auth_lifecycle_b3a(pg_temp.case_id('inactive_target'),'reactivate','Motivo sintético de restauración 0010',request_uuid);
  if prepared.completed_stage<>'prepared' then raise exception '0010_verify_reactivation_preparation_failed'; end if;
  insert into pg_temp.sitaa_0010_results values('reactivate',prepared.operation_id,request_uuid);
end;
$reactivate_prepare$;
reset role;

do $reactivate_prepare_owner_postconditions$
begin
  if (select account_status from public.profiles where id=pg_temp.case_id('inactive_target'))<>'inactive'
     or not exists(
       select 1 from public.admin_auth_operations
       where id=(select operation_id from pg_temp.sitaa_0010_results where label='reactivate')
         and operation_code='reactivate'
         and status='open'
         and completed_stage='prepared'
         and profile_audit_event_id is null
         and auth_audit_event_id is null
     ) then
    raise exception '0010_verify_reactivation_prepare_owner_postconditions_failed';
  end if;
end;
$reactivate_prepare_owner_postconditions$;

select pg_temp.set_actor('admin_a','service_role'); set local role service_role;
do $reactivate_service$
declare op uuid:=(select operation_id from pg_temp.sitaa_0010_results where label='reactivate'); claim record; result record;
begin
  select * into claim from public.claim_admin_auth_operation_b3a(op,pg_temp.case_id('admin_a'));
  begin perform public.record_admin_auth_operation_result_b3a(op,pg_temp.case_id('admin_a'),null,'retryable_failure','auth_temporarily_unavailable');
    raise exception '0010_verify_null_attempt_unexpected'; exception when invalid_parameter_value then null; end;
  begin perform public.record_admin_auth_operation_result_b3a(op,pg_temp.case_id('admin_a'),0,'retryable_failure','auth_temporarily_unavailable');
    raise exception '0010_verify_zero_attempt_unexpected'; exception when invalid_parameter_value then null; end;
  begin perform public.record_admin_auth_operation_result_b3a(op,pg_temp.case_id('admin_a'),claim.attempt_count,null,null);
    raise exception '0010_verify_null_result_unexpected'; exception when invalid_parameter_value then null; end;
  begin perform public.record_admin_auth_operation_result_b3a(op,pg_temp.case_id('admin_a'),claim.attempt_count,'retryable_failure',null);
    raise exception '0010_verify_null_retryable_code_unexpected'; exception when invalid_parameter_value then null; end;
  begin perform public.record_admin_auth_operation_result_b3a(op,pg_temp.case_id('admin_a'),claim.attempt_count,'terminal_failure',null);
    raise exception '0010_verify_null_terminal_code_unexpected'; exception when invalid_parameter_value then null; end;
  begin perform public.record_admin_auth_operation_result_b3a(op,pg_temp.case_id('admin_a'),claim.attempt_count,'auth_succeeded','auth_temporarily_unavailable');
    raise exception '0010_verify_success_error_code_unexpected'; exception when invalid_parameter_value then null; end;
  select * into result from public.record_admin_auth_operation_result_b3a(op,pg_temp.case_id('admin_a'),claim.attempt_count,'auth_succeeded',null);
  if result.status<>'processing' or result.completed_stage<>'auth_synchronized' then raise exception '0010_verify_auth_restore_stage_failed'; end if;
end;
$reactivate_service$;
reset role;

do $reactivate_service_owner_postconditions$
begin
  if (select account_status from public.profiles where id=pg_temp.case_id('inactive_target'))<>'inactive'
     or not exists(
       select 1 from public.admin_auth_operations
       where id=(select operation_id from pg_temp.sitaa_0010_results where label='reactivate')
         and status='processing'
         and completed_stage='auth_synchronized'
         and attempt_count=1
         and profile_audit_event_id is null
         and auth_audit_event_id is not null
         and auth_synchronized_at is not null
         and completed_at is null
     ) then
    raise exception '0010_verify_reactivation_service_owner_postconditions_failed';
  end if;
end;
$reactivate_service_owner_postconditions$;

select pg_temp.set_actor('admin_b'); set local role authenticated;
do $reactivate_finalize$
declare op uuid:=(select operation_id from pg_temp.sitaa_0010_results where label='reactivate'); finalized record;
begin
  select * into finalized from public.finalize_admin_account_auth_reactivation_b3a(op);
  if finalized.status<>'succeeded' or finalized.completed_stage<>'completed' then
    raise exception '0010_verify_second_admin_finalization_failed';
  end if;
end;
$reactivate_finalize$;
reset role;

do $reactivate_finalize_owner_postconditions$
declare operation_row public.admin_auth_operations%rowtype;
begin
  select * into strict operation_row
  from public.admin_auth_operations
  where id=(select operation_id from pg_temp.sitaa_0010_results where label='reactivate');
  if (select account_status from public.profiles where id=pg_temp.case_id('inactive_target'))<>'active'
     or operation_row.status<>'succeeded'
     or operation_row.completed_stage<>'completed'
     or operation_row.completed_by_profile_id<>pg_temp.case_id('admin_b')
     or operation_row.profile_audit_event_id is null
     or operation_row.auth_audit_event_id is null
     or operation_row.completed_at is null then
    raise exception '0010_verify_reactivation_finalize_owner_postconditions_failed';
  end if;
end;
$reactivate_finalize_owner_postconditions$;

-- Éxito Auth seguido de fallo de finalización: el perfil sigue inactivo y el retry no repite Auth.
select pg_temp.set_actor('admin_a'); set local role authenticated;
do $restore_failure_prepare$
declare prepared record; request_uuid uuid:=gen_random_uuid();
begin
  select * into prepared from public.prepare_admin_account_auth_lifecycle_b3a(pg_temp.case_id('restore_failure_target'),'reactivate','Motivo sintético de recuperación 0010',request_uuid);
  insert into pg_temp.sitaa_0010_results values('restore_failure',prepared.operation_id,request_uuid);
end;
$restore_failure_prepare$;
reset role;
select pg_temp.set_actor('admin_a','service_role'); set local role service_role;
do $restore_failure_auth_stage$
declare
  op uuid:=(select operation_id from pg_temp.sitaa_0010_results where label='restore_failure');
  initial_claim record;
  result record;
  recovered_claim record;
begin
  select * into initial_claim from public.claim_admin_auth_operation_b3a(op,pg_temp.case_id('admin_a'));
  select * into result from public.record_admin_auth_operation_result_b3a(
    op,pg_temp.case_id('admin_a'),initial_claim.attempt_count,'auth_succeeded',null
  );
  if result.completed_stage<>'auth_synchronized' then raise exception '0010_verify_restore_failure_auth_stage_failed'; end if;
  select * into recovered_claim from public.claim_admin_auth_operation_b3a(op,pg_temp.case_id('admin_b'));
  if not recovered_claim.claimed or recovered_claim.completed_stage<>'auth_synchronized' or recovered_claim.attempt_count<>2 then
    raise exception '0010_verify_auth_synchronized_immediate_recovery_failed';
  end if;
  insert into pg_temp.sitaa_0010_rpc_observations
  values(
    'restore_failure_recovered_claim',op,recovered_claim.status,
    recovered_claim.completed_stage,recovered_claim.attempt_count,
    recovered_claim.claimed,recovered_claim.last_error_code,recovered_claim.updated_at
  );
end;
$restore_failure_auth_stage$;
reset role;

create temporary table sitaa_0010_restore_failure_baseline(
  operation_hash text not null,
  audit_hash text not null,
  auth_audit_event_id uuid not null
) on commit drop;
insert into pg_temp.sitaa_0010_restore_failure_baseline
select
  md5(row_to_json(operation)::text),
  (select md5(coalesce(string_agg(row_to_json(audit_event)::text,'|' order by audit_event.id),''))
   from public.admin_audit_events audit_event),
  operation.auth_audit_event_id
from public.admin_auth_operations operation
where operation.id=(select operation_id from pg_temp.sitaa_0010_results where label='restore_failure');

create temporary table sitaa_0010_expected_error_outcomes(
  label text primary key,
  observed_sqlstate text not null,
  observed_message text not null
) on commit drop;
grant select,insert on pg_temp.sitaa_0010_expected_error_outcomes to authenticated,service_role;

select pg_temp.set_actor('admin_a','service_role'); set local role service_role;
do $restore_failure_rejected_results$
declare
  op uuid:=(select operation_id from pg_temp.sitaa_0010_results where label='restore_failure');
  recovered_attempt integer:=(select attempt_count from pg_temp.sitaa_0010_rpc_observations where label='restore_failure_recovered_claim');
begin
  begin
    perform public.record_admin_auth_operation_result_b3a(
      op,pg_temp.case_id('admin_a'),recovered_attempt-1,
      'retryable_failure','database_finalize_pending'
    );
    insert into pg_temp.sitaa_0010_expected_error_outcomes
    values('stale_attempt','UNEXPECTED','0010_verify_stale_attempt_unexpected');
  exception when others then
    insert into pg_temp.sitaa_0010_expected_error_outcomes
    values('stale_attempt',sqlstate,sqlerrm);
  end;

  begin
    perform public.record_admin_auth_operation_result_b3a(
      op,pg_temp.case_id('admin_b'),recovered_attempt,
      'terminal_failure','auth_update_rejected'
    );
    insert into pg_temp.sitaa_0010_expected_error_outcomes
    values('terminal_after_sync','UNEXPECTED','0010_verify_terminal_after_sync_unexpected');
  exception when others then
    insert into pg_temp.sitaa_0010_expected_error_outcomes
    values('terminal_after_sync',sqlstate,sqlerrm);
  end;
end;
$restore_failure_rejected_results$;
reset role;

do $restore_failure_rejected_owner_postconditions$
begin
  if (select observed_sqlstate from pg_temp.sitaa_0010_expected_error_outcomes where label='stale_attempt')<>'55000'
     or (select observed_message from pg_temp.sitaa_0010_expected_error_outcomes where label='stale_attempt')<>
        'sitaa_auth_operation_stale_attempt'
     or (select observed_sqlstate from pg_temp.sitaa_0010_expected_error_outcomes where label='terminal_after_sync')<>'55000'
     or (select observed_message from pg_temp.sitaa_0010_expected_error_outcomes where label='terminal_after_sync')<>
        'sitaa_auth_operation_terminal_after_sync'
     or (select operation_hash from pg_temp.sitaa_0010_restore_failure_baseline) is distinct from
        (select md5(row_to_json(operation)::text)
         from public.admin_auth_operations operation
         where operation.id=(select operation_id from pg_temp.sitaa_0010_results where label='restore_failure'))
     or (select audit_hash from pg_temp.sitaa_0010_restore_failure_baseline) is distinct from
        (select md5(coalesce(string_agg(row_to_json(audit_event)::text,'|' order by audit_event.id),''))
         from public.admin_audit_events audit_event) then
    raise exception '0010_verify_restore_failure_rejected_results_mutated_state';
  end if;
end;
$restore_failure_rejected_owner_postconditions$;

do $restore_failure_auth_audit_replacement_owner$
declare
  op uuid:=(select operation_id from pg_temp.sitaa_0010_results where label='restore_failure');
  auth_audit_id_before uuid:=(select auth_audit_event_id from pg_temp.sitaa_0010_restore_failure_baseline);
  replacement_audit_id uuid;
begin
  insert into public.admin_audit_events(
    actor_profile_id,target_profile_id,action_code,outcome,reason,role_assignment_id,metadata
  ) values(
    pg_temp.case_id('admin_b'),pg_temp.case_id('ordinary'),
    'account_auth_restored','success','Evidencia Auth sintética alternativa 0010',null,
    jsonb_build_object('operation_id',op,'operation_code','reactivate','changed_fields',jsonb_build_array('auth_access'))
  ) returning id into replacement_audit_id;
  perform set_config('sitaa.b3a_writer','record',true);
  begin
    update public.admin_auth_operations
    set auth_audit_event_id=replacement_audit_id
    where id=op;
    raise exception '0010_verify_auth_audit_replacement_unexpected';
  exception when check_violation then null; end;
  perform set_config('sitaa.b3a_writer','',true);
  if (select auth_audit_event_id from public.admin_auth_operations where id=op)
     is distinct from auth_audit_id_before then
    raise exception '0010_verify_auth_audit_replacement_changed_row';
  end if;
end;
$restore_failure_auth_audit_replacement_owner$;
update auth.users set email_confirmed_at=null where id=pg_temp.case_id('restore_failure_target');
select pg_temp.set_actor('admin_a'); set local role authenticated;
do $restore_failure_finalize$
declare op uuid:=(select operation_id from pg_temp.sitaa_0010_results where label='restore_failure');
begin
  begin perform public.finalize_admin_account_auth_reactivation_b3a(op); raise exception '0010_verify_invalid_finalization_unexpected';
  exception when raise_exception then
    if sqlerrm<>'sitaa_account_lifecycle_auth_unconfirmed' then raise; end if;
  end;
end;
$restore_failure_finalize$;
reset role;
do $$ begin
  if (select account_status from public.profiles where id=pg_temp.case_id('restore_failure_target'))<>'inactive' then
    raise exception '0010_verify_failed_finalization_activated_profile';
  end if;
end $$;
update auth.users set email_confirmed_at=now() where id=pg_temp.case_id('restore_failure_target');
select pg_temp.set_actor('admin_a','service_role'); set local role service_role;
do $restore_failure_retry$
declare
  op uuid:=(select operation_id from pg_temp.sitaa_0010_results where label='restore_failure');
  claim record;
  result record;
  recovered_attempt integer:=(select attempt_count from pg_temp.sitaa_0010_rpc_observations where label='restore_failure_recovered_claim');
begin
  select * into result from public.record_admin_auth_operation_result_b3a(
    op,pg_temp.case_id('admin_a'),
    recovered_attempt,
    'retryable_failure','database_finalize_pending'
  );
  if result.status<>'retryable_failure' or result.completed_stage<>'auth_synchronized' then
    raise exception '0010_verify_finalize_retryable_failed';
  end if;
  select * into claim from public.claim_admin_auth_operation_b3a(op,pg_temp.case_id('admin_b'));
  if claim.completed_stage<>'auth_synchronized' or claim.attempt_count<>3 then raise exception '0010_verify_retry_repeated_auth_stage'; end if;
end;
$restore_failure_retry$;
reset role;
do $$ begin
  if (select auth_audit_event_id
      from public.admin_auth_operations
      where id=(select operation_id from pg_temp.sitaa_0010_results where label='restore_failure'))
     is distinct from
     (select auth_audit_event_id from pg_temp.sitaa_0010_restore_failure_baseline) then
    raise exception '0010_verify_finalize_retryable_changed_auth_evidence';
  end if;
end $$;
select pg_temp.set_actor('admin_b'); set local role authenticated;
do $restore_failure_recovered$
declare op uuid:=(select operation_id from pg_temp.sitaa_0010_results where label='restore_failure'); finalized record;
begin
  select * into finalized from public.finalize_admin_account_auth_reactivation_b3a(op);
  if finalized.status<>'succeeded' or finalized.completed_stage<>'completed' then
    raise exception '0010_verify_stranded_operation_recovery_failed';
  end if;
end;
$restore_failure_recovered$;
reset role;
do $$ begin
  if (select account_status from public.profiles where id=pg_temp.case_id('restore_failure_target'))<>'active'
     or not exists(
       select 1 from public.admin_auth_operations
       where id=(select operation_id from pg_temp.sitaa_0010_results where label='restore_failure')
         and status='succeeded'
         and completed_stage='completed'
         and completed_by_profile_id=pg_temp.case_id('admin_b')
     ) then
    raise exception '0010_verify_stranded_operation_owner_postconditions_failed';
  end if;
end $$;

-- La autoridad perdida antes de finalizar falla cerrada; otra autoridad exacta recupera.
select pg_temp.set_actor('admin_a'); set local role authenticated;
do $authority_loss_prepare$
declare prepared record; request_uuid uuid:=gen_random_uuid();
begin
  select * into prepared from public.prepare_admin_account_auth_lifecycle_b3a(pg_temp.case_id('authority_loss_target'),'reactivate','Motivo sintético por pérdida de autoridad 0010',request_uuid);
  insert into pg_temp.sitaa_0010_results values('authority_loss',prepared.operation_id,request_uuid);
end;
$authority_loss_prepare$;
reset role;
select pg_temp.set_actor('admin_a','service_role'); set local role service_role;
do $authority_loss_auth$
declare op uuid:=(select operation_id from pg_temp.sitaa_0010_results where label='authority_loss'); claim record;
begin
  select * into claim from public.claim_admin_auth_operation_b3a(op,pg_temp.case_id('admin_a'));
  perform public.record_admin_auth_operation_result_b3a(op,pg_temp.case_id('admin_a'),claim.attempt_count,'auth_succeeded',null);
end;
$authority_loss_auth$;
reset role;
update public.role_assignments set is_active=false where user_id=pg_temp.case_id('admin_a') and role_code='technical_admin' and scope_type='system' and service_area='technical';
select pg_temp.set_actor('admin_a'); set local role authenticated;
do $authority_loss_denial$
declare op uuid:=(select operation_id from pg_temp.sitaa_0010_results where label='authority_loss');
begin
  begin perform public.finalize_admin_account_auth_reactivation_b3a(op); raise exception '0010_verify_lost_authority_unexpected';
  exception when insufficient_privilege then
    if sqlerrm<>'sitaa_admin_access_denied' then raise; end if;
  end;
end;
$authority_loss_denial$;
reset role;
do $$ begin
  if (select account_status from public.profiles where id=pg_temp.case_id('authority_loss_target'))<>'inactive' then
    raise exception '0010_verify_lost_authority_activated_profile';
  end if;
end $$;
select pg_temp.set_actor('admin_b'); set local role authenticated;
do $authority_loss_recovery$
declare op uuid:=(select operation_id from pg_temp.sitaa_0010_results where label='authority_loss'); finalized record;
begin
  select * into finalized from public.finalize_admin_account_auth_reactivation_b3a(op);
  if finalized.status<>'succeeded' or finalized.completed_stage<>'completed' then
    raise exception '0010_verify_lost_authority_recovery_failed';
  end if;
end;
$authority_loss_recovery$;
reset role;
do $$ begin
  if (select completed_by_profile_id
      from public.admin_auth_operations
      where id=(select operation_id from pg_temp.sitaa_0010_results where label='authority_loss'))
     <>pg_temp.case_id('admin_b')
     or (select account_status from public.profiles where id=pg_temp.case_id('authority_loss_target'))<>'active' then
    raise exception '0010_verify_lost_authority_owner_postconditions_failed';
  end if;
end $$;

do $final_state_machine$
declare op uuid:=(select operation_id from pg_temp.sitaa_0010_results where label='deactivate');
begin
  perform set_config('sitaa.b3a_writer','finalize',true);
  begin
    update public.admin_auth_operations set status='open',completed_stage='profile_suspended',completed_at=null where id=op;
    raise exception '0010_verify_final_state_reopened_unexpected';
  exception when check_violation then null; end;
  if (select status from public.admin_auth_operations where id=op)<>'succeeded' then
    raise exception '0010_verify_final_state_changed';
  end if;
  perform set_config('sitaa.b3a_writer','',true);
  begin
    delete from public.admin_auth_operations where id=op;
    raise exception '0010_verify_delete_unexpected';
  exception when insufficient_privilege then null; end;
  begin
    truncate table public.admin_auth_operations;
    raise exception '0010_verify_truncate_unexpected';
  exception when insufficient_privilege then null; end;
end;
$final_state_machine$;

do $final_contract$
begin
  if (select count(*) from public.admin_audit_events where target_profile_id=pg_temp.case_id('inactive_target') and action_code='account_reactivated')<>1
     or (select actor_profile_id from public.admin_audit_events where target_profile_id=pg_temp.case_id('inactive_target') and action_code='account_reactivated')<>pg_temp.case_id('admin_b')
     or (select count(*) from public.admin_audit_events where target_profile_id=pg_temp.case_id('inactive_target') and action_code='account_auth_restored')<>1
     or (select actor_profile_id from public.admin_audit_events where target_profile_id=pg_temp.case_id('inactive_target') and action_code='account_auth_restored')<>pg_temp.case_id('admin_a')
     or (select count(*) from public.admin_audit_events where target_profile_id=pg_temp.case_id('restore_failure_target') and action_code='account_auth_restored')<>1
     or (select count(*) from public.admin_audit_events where target_profile_id=pg_temp.case_id('terminal_target') and action_code='account_auth_suspension_failed')<>1
     or exists(select 1 from public.admin_audit_events where target_profile_id in (pg_temp.case_id('active_target'),pg_temp.case_id('inactive_target')) and (metadata::text~*'(password|token|cookie|secret|authorization|bearer|email)' or octet_length(metadata::text)>16384))
     or exists(select 1 from public.admin_auth_operations where last_error_code is not null and last_error_code not in ('auth_temporarily_unavailable','auth_rate_limited','auth_user_not_found','auth_update_rejected','unsupported_auth_contract','database_finalize_pending')) then
    raise exception '0010_verify_final_audit_or_error_contract_failed';
  end if;
  if exists(
    select 1 from pg_temp.sitaa_0010_baseline_exact_admins baseline
    join public.profiles p on p.id=baseline.profile_id
    where baseline.profile_hash<>md5(row_to_json(p)::text)
       or baseline.assignment_hash<>md5(coalesce((select string_agg(row_to_json(r)::text,'|' order by r.id) from public.role_assignments r where r.user_id=p.id),''))
       or baseline.audit_hash<>md5(coalesce((select string_agg(row_to_json(a)::text,'|' order by a.id) from public.admin_audit_events a where a.actor_profile_id=p.id or a.target_profile_id=p.id),''))
  ) then raise exception '0010_verify_preexisting_admin_changed'; end if;
  if exists (
    with actual(object_name,content_hash) as (
      values
      ('auth_users',md5(coalesce((select string_agg(row_to_json(u)::text,'|' order by u.id) from auth.users u where not exists(select 1 from pg_temp.sitaa_0010_cases c where c.id=u.id)),''))),
      ('profiles',md5(coalesce((select string_agg(row_to_json(p)::text,'|' order by p.id) from public.profiles p where not exists(select 1 from pg_temp.sitaa_0010_cases c where c.id=p.id)),''))),
      ('role_assignments',md5(coalesce((select string_agg(row_to_json(r)::text,'|' order by r.id) from public.role_assignments r where not exists(select 1 from pg_temp.sitaa_0010_cases c where c.id=r.user_id)),''))),
      ('activities',md5(coalesce((select string_agg(row_to_json(a)::text,'|' order by a.id) from public.activities a),''))),
      ('activity_participants',md5(coalesce((select string_agg(row_to_json(p)::text,'|' order by p.id) from public.activity_participants p),''))),
      ('prior_audit',md5(coalesce((select string_agg(row_to_json(a)::text,'|' order by a.id) from public.admin_audit_events a where not exists(select 1 from pg_temp.sitaa_0010_cases c where c.id=a.actor_profile_id or c.id=a.target_profile_id)),'')))
    )
    select 1 from actual join pg_temp.sitaa_0010_operational_baseline baseline using(object_name)
    where actual.content_hash<>baseline.content_hash
  ) then raise exception '0010_verify_preexisting_operational_history_changed'; end if;
end;
$final_contract$;

-- El ROLLBACK final elimina fixtures, operaciones, eventos y grants temporales.
rollback;
