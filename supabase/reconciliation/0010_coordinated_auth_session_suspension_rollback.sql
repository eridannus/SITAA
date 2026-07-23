-- Rollback 0010 disponible únicamente antes de la primera operación B.3a real.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
set local time zone 'UTC';
set local datestyle to 'ISO, MDY';

do $minimal_existence$
begin
  if to_regclass('public.admin_auth_operations') is null
     or to_regprocedure('public.get_admin_account_auth_lifecycle_context_b3a(uuid)') is null
     or to_regprocedure('public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)') is null
     or to_regprocedure('public.finalize_admin_account_auth_reactivation_b3a(uuid)') is null
     or to_regprocedure('public.claim_admin_auth_operation_b3a(uuid,uuid)') is null
     or to_regprocedure('public.record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text)') is null
     or to_regprocedure('public.guard_admin_auth_operation_b3a()') is null then
    raise exception 'sitaa_0010_rollback_contract_missing' using errcode='55000';
  end if;
end;
$minimal_existence$;

lock table public.admin_auth_operations in access exclusive mode nowait;
lock table public.admin_audit_events in access exclusive mode nowait;

do $predestructive$
begin
  perform set_config('sitaa_0010.rollback_default_acl_hash',
    (select md5(coalesce(string_agg(defaclrole::text||':'||defaclnamespace::text||':'||defaclobjtype::text||':'||defaclacl::text,'|' order by defaclrole,defaclnamespace,defaclobjtype),'')) from pg_default_acl),true);
  if (
       with entries(value) as (
         select p.oid::regprocedure::text||':'||pg_get_userbyid(p.proowner)||':'||language_definition.lanname||':'||
           p.provolatile::text||':'||p.prosecdef::text||':'||coalesce(array_to_string(p.proconfig,E'\n'),'')
         from pg_proc p
         join pg_namespace namespace_definition on namespace_definition.oid=p.pronamespace
         join pg_language language_definition on language_definition.oid=p.prolang
          where namespace_definition.nspname='public'
            and p.proname not in (
             'guard_admin_auth_operation_b3a',
             'get_admin_account_auth_lifecycle_context_b3a',
             'prepare_admin_account_auth_lifecycle_b3a',
             'finalize_admin_account_auth_reactivation_b3a',
             'claim_admin_auth_operation_b3a',
             'record_admin_auth_operation_result_b3a'
           )
       )
       select md5(coalesce(string_agg(value,'|' order by value),'')) from entries
     )<>'c2095a58fb96e7387513b4bebf33b95d'
     or not (
       with entries(value) as (
         select p.oid::regprocedure::text||':'||pg_get_userbyid(p.proowner)||':'||
           pg_get_userbyid(acl.grantor)||':'||
           case when acl.grantee=0 then 'PUBLIC' else pg_get_userbyid(acl.grantee) end||':'||
           acl.privilege_type||':'||acl.is_grantable::text
         from pg_proc p
         join pg_namespace namespace_definition on namespace_definition.oid=p.pronamespace
          cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
          where namespace_definition.nspname='public'
            and p.oid<>'public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure
            and p.proname not in (
             'guard_admin_auth_operation_b3a',
             'get_admin_account_auth_lifecycle_context_b3a',
             'prepare_admin_account_auth_lifecycle_b3a',
             'finalize_admin_account_auth_reactivation_b3a',
             'claim_admin_auth_operation_b3a',
             'record_admin_auth_operation_result_b3a'
           )
       )
       select count(*)=135
          and md5(coalesce(string_agg(value,'|' order by value),''))='5c2ce865124e0669c787d12fe4c46b59'
       from entries
     )
     or not (
       with entries(value) as (
         select table_definition.relname||':'||pg_get_userbyid(table_definition.relowner)||':'||
           pg_get_userbyid(acl.grantor)||':'||
           case when acl.grantee=0 then 'PUBLIC' else pg_get_userbyid(acl.grantee) end||':'||
           acl.privilege_type||':'||acl.is_grantable::text
         from pg_class table_definition
         join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace
         cross join lateral aclexplode(coalesce(table_definition.relacl,acldefault('r',table_definition.relowner))) acl
         where namespace_definition.nspname='public'
           and table_definition.relkind in ('r','p','v','m')
           and table_definition.relname<>'admin_auth_operations'
       )
       select count(*)=302
          and md5(coalesce(string_agg(value,'|' order by value),''))='e1e24e4406a6b72e539a412396b58a83'
       from entries
     )
     or not (
       with entries(value) as (
         select sequence_definition.relname||':'||pg_get_userbyid(sequence_definition.relowner)||':'||
           pg_get_userbyid(acl.grantor)||':'||
           case when acl.grantee=0 then 'PUBLIC' else pg_get_userbyid(acl.grantee) end||':'||
           acl.privilege_type||':'||acl.is_grantable::text
         from pg_class sequence_definition
         join pg_namespace namespace_definition on namespace_definition.oid=sequence_definition.relnamespace
         cross join lateral aclexplode(coalesce(sequence_definition.relacl,acldefault('s',sequence_definition.relowner))) acl
         where namespace_definition.nspname='public' and sequence_definition.relkind='S'
       )
       select count(*)=6
          and md5(coalesce(string_agg(value,'|' order by value),''))='f33fd097dfc9ed8a316ad5a3accab896'
       from entries
     )
     or exists (
       (
         select table_definition.relname,attribute_definition.attname,pg_get_userbyid(acl.grantor),
           case when acl.grantee=0 then 'PUBLIC' else pg_get_userbyid(acl.grantee) end,
           acl.privilege_type,acl.is_grantable
         from pg_attribute attribute_definition
         join pg_class table_definition on table_definition.oid=attribute_definition.attrelid
         join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace
         cross join lateral aclexplode(attribute_definition.attacl) acl
         where namespace_definition.nspname='public'
           and attribute_definition.attnum>0
           and not attribute_definition.attisdropped
           and attribute_definition.attacl is not null
       )
       except
       values
         ('profiles','first_names','postgres','authenticated','UPDATE',false),
         ('profiles','maternal_surname','postgres','authenticated','UPDATE',false),
         ('profiles','paternal_surname','postgres','authenticated','UPDATE',false)
     )
     or exists (
       (values
         ('profiles','first_names','postgres','authenticated','UPDATE',false),
         ('profiles','maternal_surname','postgres','authenticated','UPDATE',false),
         ('profiles','paternal_surname','postgres','authenticated','UPDATE',false)
       )
       except
       select table_definition.relname,attribute_definition.attname,pg_get_userbyid(acl.grantor),
         case when acl.grantee=0 then 'PUBLIC' else pg_get_userbyid(acl.grantee) end,
         acl.privilege_type,acl.is_grantable
       from pg_attribute attribute_definition
       join pg_class table_definition on table_definition.oid=attribute_definition.attrelid
       join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace
       cross join lateral aclexplode(attribute_definition.attacl) acl
       where namespace_definition.nspname='public'
         and attribute_definition.attnum>0
         and not attribute_definition.attisdropped
         and attribute_definition.attacl is not null
     )
     or (select count(*)
         from pg_default_acl default_acl
         cross join lateral aclexplode(default_acl.defaclacl) acl
         where acl.grantee in (0,'anon'::regrole,'authenticated'::regrole)
           and acl.privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE'))<>0 then
    raise exception 'sitaa_0010_rollback_canonical_acl_mismatch' using errcode='55000';
  end if;
  if (select string_agg(column_name||':'||data_type||':'||is_nullable,'|' order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='admin_auth_operations')<>
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
     or (select count(*) from pg_policies where schemaname='public' and tablename='admin_auth_operations')<>0
     or (select count(*) from information_schema.tables where table_schema='public' and table_type='BASE TABLE')<>19
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
     or (select md5(coalesce(string_agg(table_name||':'||ordinal_position::text||':'||column_name||':'||data_type||':'||udt_name||':'||is_nullable||':'||coalesce(column_default,'')||':'||coalesce(character_maximum_length::text,'')||':'||coalesce(numeric_precision::text,'')||':'||coalesce(numeric_scale::text,'')||':'||coalesce(datetime_precision::text,''),'|' order by table_name,ordinal_position),'')) from information_schema.columns where table_schema='public' and table_name<>'admin_auth_operations')<>'847b9f5c4ec9d428c522f714de59fd1f'
     or (select md5(coalesce(string_agg(table_definition.relname||':'||constraint_definition.conname||':'||case constraint_definition.contype when 'p' then 'primary_key' when 'f' then 'foreign_key' when 'u' then 'unique' when 'c' then 'check' end||':'||pg_get_constraintdef(constraint_definition.oid,true),'|' order by table_definition.relname,constraint_definition.conname),'')) from pg_constraint constraint_definition join pg_class table_definition on table_definition.oid=constraint_definition.conrelid join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace where namespace_definition.nspname='public' and table_definition.relname<>'admin_auth_operations' and constraint_definition.contype in ('p','f','u','c'))<>'64f099164063d0cf500478dda3b5d25c'
     or (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||indexname||':'||indexdef,'|' order by schemaname,tablename,indexname),'')) from pg_indexes where schemaname='public' and tablename<>'admin_auth_operations')<>'653875a8435cf43bda4fe55950f65802'
     or (select md5(coalesce(string_agg(table_definition.relname||':'||trigger_definition.tgname||':'||pg_get_triggerdef(trigger_definition.oid,true),'|' order by table_definition.relname,trigger_definition.tgname),'')) from pg_trigger trigger_definition join pg_class table_definition on table_definition.oid=trigger_definition.tgrelid join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace where namespace_definition.nspname='public' and table_definition.relname<>'admin_auth_operations' and not trigger_definition.tgisinternal)<>'67ee47bcd43c0594129facf3d7729bad'
     or (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||policyname||':'||permissive||':'||roles::text||':'||cmd||':'||coalesce(qual,'')||':'||coalesce(with_check,''),'|' order by schemaname,tablename,policyname),'')) from pg_policies where schemaname='public')<>'a72df97fbb8e73d8445f7fe8765da4ba'
     or exists(select 1 from (values
       ('guard_admin_auth_operation_b3a()','d80211e442b6d9334123d8e0d4ada4c8'),
       ('get_admin_account_auth_lifecycle_context_b3a(uuid)','44fd317ebc207cbf572551835fb9be7d'),
       ('prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)','2d8d580677411110fb9255fcced4c715'),
       ('claim_admin_auth_operation_b3a(uuid,uuid)','7da7aec9b4ff17aa551a4cf820d5cfbd'),
       ('record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text)','6467440196296d77662eb4cce77d3226'),
       ('finalize_admin_account_auth_reactivation_b3a(uuid)','b8223a508478e80edd340e231b66abeb')
     ) expected(signature,body_hash) left join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
     where p.oid is null or not p.prosecdef or pg_get_userbyid(p.proowner)<>'postgres'
       or p.proconfig is distinct from array['search_path=pg_catalog, public']::text[]
       or md5(regexp_replace(p.prosrc,'\s+','','g'))<>expected.body_hash) then
    raise exception 'sitaa_0010_rollback_exact_contract_mismatch' using errcode='55000';
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
         select p.oid,acl.grantee from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
         where p.oid in (select expected.function_oid from expected) and acl.privilege_type='EXECUTE' and not acl.is_grantable
       )
       (select * from expected except select * from actual)
       union all
       (select * from actual except select * from expected)
     ) then
    raise exception 'sitaa_0010_rollback_function_acl_mismatch' using errcode='55000';
  end if;
  if has_function_privilege('authenticated','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or has_function_privilege('anon','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or has_function_privilege('service_role','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or has_function_privilege('PUBLIC','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or (select count(*)
         from pg_proc p
         cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
         where p.oid='public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure
           and acl.privilege_type='EXECUTE'
           and acl.grantee=p.proowner
           and not acl.is_grantable)<>1
     or exists(
       select 1
       from pg_proc p
       cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
       where p.oid='public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure
         and (
           acl.privilege_type<>'EXECUTE'
           or acl.grantee<>p.proowner
           or acl.is_grantable
         )
     ) then
    raise exception 'sitaa_0010_rollback_legacy_acl_already_restored' using errcode='55000';
  end if;
  if not exists (
    select 1 from pg_class table_definition
    where table_definition.oid='public.admin_auth_operations'::regclass
      and pg_get_userbyid(table_definition.relowner)='postgres'
      and (select count(*) from aclexplode(table_definition.relacl) acl where acl.grantee=table_definition.relowner and not acl.is_grantable)=8
      and (select count(*) from aclexplode(table_definition.relacl))=8
      and not exists(select 1 from pg_attribute attribute_definition where attribute_definition.attrelid=table_definition.oid and attribute_definition.attnum>0 and not attribute_definition.attisdropped and attribute_definition.attacl is not null and exists(select 1 from aclexplode(attribute_definition.attacl)))
  ) then
    raise exception 'sitaa_0010_rollback_ledger_acl_mismatch' using errcode='55000';
  end if;
  if (select count(*) from pg_trigger t where not t.tgisinternal and t.tgname='on_sitaa_auth_user_created')<>1
     or (select count(*) from pg_trigger t where not t.tgisinternal and t.tgname='on_sitaa_auth_user_created' and t.tgrelid='auth.users'::regclass and t.tgenabled='O' and t.tgtype=5::smallint and t.tgfoid=to_regprocedure('public.handle_sitaa_auth_user_created()') and cardinality(t.tgattr::smallint[])=0 and t.tgqual is null)<>1
     or (select count(*) from pg_trigger t where not t.tgisinternal and t.tgname='on_sitaa_auth_user_email_changed')<>1
     or (select count(*) from pg_trigger t where not t.tgisinternal and t.tgname='on_sitaa_auth_user_email_changed' and t.tgrelid='auth.users'::regclass and t.tgenabled='O' and t.tgtype=17::smallint and t.tgfoid=to_regprocedure('public.sync_sitaa_profile_email_from_auth()') and cardinality(t.tgattr::smallint[])=1 and t.tgqual is not null and (select count(*) from unnest(t.tgattr::smallint[]) u(attnum) join pg_attribute a on a.attrelid=t.tgrelid and a.attnum=u.attnum and a.attname='email' and not a.attisdropped)=1 and regexp_replace(regexp_replace(split_part(split_part(lower(pg_get_triggerdef(t.oid,false)),' when ',2),' execute function ',1),'[[:space:]()]','','g'),'::text','','g')='old.emailisdistinctfromnew.email')<>1 then
    raise exception 'sitaa_0010_rollback_auth_trigger_mismatch' using errcode='55000';
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
    select count(*)=51 and md5(string_agg(catalog||E'\t'||row_json,E'\n' order by catalog,row_json))='2e450238768fbe9889470864a1832486'
    from controlled_seed_rows
  ) then
    raise exception 'sitaa_0010_rollback_seed_mismatch' using errcode='55000';
  end if;
end;
$predestructive$;

do $history_guard$
begin
  if exists(select 1 from public.admin_auth_operations) then
    raise exception 'sitaa_0010_rollback_forbidden_after_operation' using errcode='55000';
  end if;
  if exists(select 1 from public.admin_audit_events where action_code in (
    'account_auth_suspended','account_auth_restored',
    'account_auth_suspension_failed','account_auth_restoration_failed'
  )) then
    raise exception 'sitaa_0010_rollback_forbidden_after_auth_event' using errcode='55000';
  end if;
end;
$history_guard$;

revoke all on function public.get_admin_account_auth_lifecycle_context_b3a(uuid) from public,anon,authenticated,service_role;
revoke all on function public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid) from public,anon,authenticated,service_role;
revoke all on function public.finalize_admin_account_auth_reactivation_b3a(uuid) from public,anon,authenticated,service_role;
revoke all on function public.claim_admin_auth_operation_b3a(uuid,uuid) from public,anon,authenticated,service_role;
revoke all on function public.record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text) from public,anon,authenticated,service_role;
revoke all on function public.guard_admin_auth_operation_b3a() from public,anon,authenticated,service_role;

drop function public.get_admin_account_auth_lifecycle_context_b3a(uuid);
drop function public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid);
drop function public.finalize_admin_account_auth_reactivation_b3a(uuid);
drop function public.claim_admin_auth_operation_b3a(uuid,uuid);
drop function public.record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text);

drop trigger guard_admin_auth_operation_b3a on public.admin_auth_operations;
drop trigger guard_admin_auth_operation_truncate_b3a on public.admin_auth_operations;
drop function public.guard_admin_auth_operation_b3a();
drop table public.admin_auth_operations;

revoke all on function public.transition_admin_account_lifecycle_b2b(uuid,text,text)
  from public,anon,authenticated,service_role;
grant execute on function public.transition_admin_account_lifecycle_b2b(uuid,text,text)
  to authenticated;

do $post_rollback$
begin
  if to_regclass('public.admin_auth_operations') is not null
     or exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname like '%_b3a')
     or (select count(*) from information_schema.tables where table_schema='public' and table_type='BASE TABLE')<>18
     or (select count(*) from information_schema.columns where table_schema='public')<>165
     or (select count(*) from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname='public' and c.contype in ('p','f','u','c'))<>80
     or (select count(*) from pg_indexes where schemaname='public')<>43
     or (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal)<>11
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>54
     or (select count(*) from pg_policies where schemaname='public')<>25
     or (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and c.relrowsecurity)<>18
     or not has_function_privilege('authenticated','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or has_function_privilege('anon','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or has_function_privilege('service_role','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or (select count(*) from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where p.oid='public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure and acl.privilege_type='EXECUTE' and acl.grantee in (p.proowner,'authenticated'::regrole) and not acl.is_grantable)<>2
     or exists(select 1 from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where p.oid='public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure and (acl.privilege_type<>'EXECUTE' or acl.grantee not in (p.proowner,'authenticated'::regrole) or acl.is_grantable))
     or (select md5(coalesce(string_agg(p.oid::regprocedure::text||':'||md5(regexp_replace(p.prosrc,'\s+','','g')),'|' order by p.oid::regprocedure::text),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>'71f9763d702e95e4eede51a4a4611694'
     or (select count(*) from information_schema.routine_privileges where routine_schema='public')<>137
     or (select count(*) from information_schema.table_privileges where table_schema='public')<>267
     or (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault('s',c.relowner))) acl where n.nspname='public' and c.relkind='S')<>6
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where n.nspname='public')+
        (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault(case when c.relkind='S' then 's'::"char" else 'r'::"char" end,c.relowner))) acl where n.nspname='public' and c.relkind in ('r','p','v','m','S'))<>445
     or (select md5(coalesce(string_agg(p.oid::regprocedure::text,'|' order by p.oid::regprocedure::text),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>'89d8e1d260ccc0af72ee42c394f79f90'
     or (select md5(coalesce(string_agg(table_name||':'||ordinal_position::text||':'||column_name||':'||data_type||':'||udt_name||':'||is_nullable||':'||coalesce(column_default,'')||':'||coalesce(character_maximum_length::text,'')||':'||coalesce(numeric_precision::text,'')||':'||coalesce(numeric_scale::text,'')||':'||coalesce(datetime_precision::text,''),'|' order by table_name,ordinal_position),'')) from information_schema.columns where table_schema='public')<>'847b9f5c4ec9d428c522f714de59fd1f'
     or (select md5(coalesce(string_agg(table_definition.relname||':'||constraint_definition.conname||':'||case constraint_definition.contype when 'p' then 'primary_key' when 'f' then 'foreign_key' when 'u' then 'unique' when 'c' then 'check' end||':'||pg_get_constraintdef(constraint_definition.oid,true),'|' order by table_definition.relname,constraint_definition.conname),'')) from pg_constraint constraint_definition join pg_class table_definition on table_definition.oid=constraint_definition.conrelid join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace where namespace_definition.nspname='public' and constraint_definition.contype in ('p','f','u','c'))<>'64f099164063d0cf500478dda3b5d25c'
     or (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||indexname||':'||indexdef,'|' order by schemaname,tablename,indexname),'')) from pg_indexes where schemaname='public')<>'653875a8435cf43bda4fe55950f65802'
     or (select md5(coalesce(string_agg(schemaname||':'||tablename||':'||policyname||':'||permissive||':'||roles::text||':'||cmd||':'||coalesce(qual,'')||':'||coalesce(with_check,''),'|' order by schemaname,tablename,policyname),'')) from pg_policies where schemaname='public')<>'a72df97fbb8e73d8445f7fe8765da4ba'
     or (select md5(coalesce(string_agg(table_definition.relname||':'||trigger_definition.tgname||':'||pg_get_triggerdef(trigger_definition.oid,true),'|' order by table_definition.relname,trigger_definition.tgname),'')) from pg_trigger trigger_definition join pg_class table_definition on table_definition.oid=trigger_definition.tgrelid join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace where namespace_definition.nspname='public' and not trigger_definition.tgisinternal)<>'67ee47bcd43c0594129facf3d7729bad' then
    raise exception 'sitaa_0010_rollback_post_0009_mismatch' using errcode='55000';
  end if;
  if (
       with entries(value) as (
         select p.oid::regprocedure::text||':'||pg_get_userbyid(p.proowner)||':'||language_definition.lanname||':'||
           p.provolatile::text||':'||p.prosecdef::text||':'||coalesce(array_to_string(p.proconfig,E'\n'),'')
         from pg_proc p
         join pg_namespace namespace_definition on namespace_definition.oid=p.pronamespace
         join pg_language language_definition on language_definition.oid=p.prolang
         where namespace_definition.nspname='public'
       )
       select md5(coalesce(string_agg(value,'|' order by value),'')) from entries
     )<>'c2095a58fb96e7387513b4bebf33b95d'
     or not (
       with entries(value) as (
         select p.oid::regprocedure::text||':'||pg_get_userbyid(p.proowner)||':'||
           pg_get_userbyid(acl.grantor)||':'||
           case when acl.grantee=0 then 'PUBLIC' else pg_get_userbyid(acl.grantee) end||':'||
           acl.privilege_type||':'||acl.is_grantable::text
         from pg_proc p
         join pg_namespace namespace_definition on namespace_definition.oid=p.pronamespace
         cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
         where namespace_definition.nspname='public'
       )
       select count(*)=137
          and md5(coalesce(string_agg(value,'|' order by value),''))='4ea1d04b7d1b1632fd5ce01a1dc83e05'
       from entries
     )
     or not (
       with entries(value) as (
         select table_definition.relname||':'||pg_get_userbyid(table_definition.relowner)||':'||
           pg_get_userbyid(acl.grantor)||':'||
           case when acl.grantee=0 then 'PUBLIC' else pg_get_userbyid(acl.grantee) end||':'||
           acl.privilege_type||':'||acl.is_grantable::text
         from pg_class table_definition
         join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace
         cross join lateral aclexplode(coalesce(table_definition.relacl,acldefault('r',table_definition.relowner))) acl
         where namespace_definition.nspname='public' and table_definition.relkind in ('r','p','v','m')
       )
       select count(*)=302
          and md5(coalesce(string_agg(value,'|' order by value),''))='e1e24e4406a6b72e539a412396b58a83'
       from entries
     )
     or not (
       with entries(value) as (
         select sequence_definition.relname||':'||pg_get_userbyid(sequence_definition.relowner)||':'||
           pg_get_userbyid(acl.grantor)||':'||
           case when acl.grantee=0 then 'PUBLIC' else pg_get_userbyid(acl.grantee) end||':'||
           acl.privilege_type||':'||acl.is_grantable::text
         from pg_class sequence_definition
         join pg_namespace namespace_definition on namespace_definition.oid=sequence_definition.relnamespace
         cross join lateral aclexplode(coalesce(sequence_definition.relacl,acldefault('s',sequence_definition.relowner))) acl
         where namespace_definition.nspname='public' and sequence_definition.relkind='S'
       )
       select count(*)=6
          and md5(coalesce(string_agg(value,'|' order by value),''))='f33fd097dfc9ed8a316ad5a3accab896'
       from entries
     )
     or exists (
       (
         select table_definition.relname,attribute_definition.attname,pg_get_userbyid(acl.grantor),
           case when acl.grantee=0 then 'PUBLIC' else pg_get_userbyid(acl.grantee) end,
           acl.privilege_type,acl.is_grantable
         from pg_attribute attribute_definition
         join pg_class table_definition on table_definition.oid=attribute_definition.attrelid
         join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace
         cross join lateral aclexplode(attribute_definition.attacl) acl
         where namespace_definition.nspname='public'
           and attribute_definition.attnum>0
           and not attribute_definition.attisdropped
           and attribute_definition.attacl is not null
       )
       except
       values
         ('profiles','first_names','postgres','authenticated','UPDATE',false),
         ('profiles','maternal_surname','postgres','authenticated','UPDATE',false),
         ('profiles','paternal_surname','postgres','authenticated','UPDATE',false)
     )
     or exists (
       (values
         ('profiles','first_names','postgres','authenticated','UPDATE',false),
         ('profiles','maternal_surname','postgres','authenticated','UPDATE',false),
         ('profiles','paternal_surname','postgres','authenticated','UPDATE',false)
       )
       except
       select table_definition.relname,attribute_definition.attname,pg_get_userbyid(acl.grantor),
         case when acl.grantee=0 then 'PUBLIC' else pg_get_userbyid(acl.grantee) end,
         acl.privilege_type,acl.is_grantable
       from pg_attribute attribute_definition
       join pg_class table_definition on table_definition.oid=attribute_definition.attrelid
       join pg_namespace namespace_definition on namespace_definition.oid=table_definition.relnamespace
       cross join lateral aclexplode(attribute_definition.attacl) acl
       where namespace_definition.nspname='public'
         and attribute_definition.attnum>0
         and not attribute_definition.attisdropped
         and attribute_definition.attacl is not null
     ) then
    raise exception 'sitaa_0010_rollback_post_0009_acl_mismatch' using errcode='55000';
  end if;
  if (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_created')<>1
     or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_created' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgenabled='O' and trigger_definition.tgtype=5::smallint and trigger_definition.tgfoid=to_regprocedure('public.handle_sitaa_auth_user_created()') and cardinality(trigger_definition.tgattr::smallint[])=0 and trigger_definition.tgqual is null)<>1
     or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_email_changed')<>1
     or (select count(*) from pg_trigger trigger_definition where not trigger_definition.tgisinternal and trigger_definition.tgname='on_sitaa_auth_user_email_changed' and trigger_definition.tgrelid='auth.users'::regclass and trigger_definition.tgenabled='O' and trigger_definition.tgtype=17::smallint and trigger_definition.tgfoid=to_regprocedure('public.sync_sitaa_profile_email_from_auth()') and cardinality(trigger_definition.tgattr::smallint[])=1 and trigger_definition.tgqual is not null and (select count(*) from unnest(trigger_definition.tgattr::smallint[]) attribute_number(attnum) join pg_attribute attribute_definition on attribute_definition.attrelid=trigger_definition.tgrelid and attribute_definition.attnum=attribute_number.attnum and attribute_definition.attname='email' and not attribute_definition.attisdropped)=1 and regexp_replace(regexp_replace(split_part(split_part(lower(pg_get_triggerdef(trigger_definition.oid,false)),' when ',2),' execute function ',1),'[[:space:]()]','','g'),'::text','','g')='old.emailisdistinctfromnew.email')<>1
     or to_regclass('public.admin_audit_events') is null
     or (select count(*) from information_schema.columns where table_schema='public' and table_name='admin_audit_events')<>9
     or (select count(*) from pg_trigger where tgrelid='public.admin_audit_events'::regclass and not tgisinternal)<>2
     or not (select relrowsecurity from pg_class where oid='public.admin_audit_events'::regclass)
     or (select count(*) from pg_policies where schemaname='public' and tablename='admin_audit_events')<>0
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
       select count(*)=51
          and md5(string_agg(catalog||E'\t'||row_json,E'\n' order by catalog,row_json))='2e450238768fbe9889470864a1832486'
       from controlled_seed_rows
     )
     or (select count(*)
         from pg_default_acl default_acl
         cross join lateral aclexplode(default_acl.defaclacl) acl
         where acl.grantee in (0,'anon'::regrole,'authenticated'::regrole)
           and acl.privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE'))<>0 then
    raise exception 'sitaa_0010_rollback_post_0009_contract_mismatch' using errcode='55000';
  end if;
  if current_setting('sitaa_0010.rollback_default_acl_hash',true) is distinct from
     (select md5(coalesce(string_agg(defaclrole::text||':'||defaclnamespace::text||':'||defaclobjtype::text||':'||defaclacl::text,'|' order by defaclrole,defaclnamespace,defaclobjtype),'')) from pg_default_acl) then
    raise exception 'sitaa_0010_rollback_default_acl_changed' using errcode='55000';
  end if;
end;
$post_rollback$;

commit;
