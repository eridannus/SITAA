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
     or to_regprocedure('public.record_admin_auth_operation_result_b3a(uuid,uuid,text,text)') is null
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
  if (select string_agg(column_name||':'||data_type||':'||is_nullable,'|' order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='admin_auth_operations')<>
       'id:uuid:NO|request_id:uuid:NO|requested_by_profile_id:uuid:NO|completed_by_profile_id:uuid:YES|target_profile_id:uuid:NO|operation_code:text:NO|status:text:NO|completed_stage:text:NO|reason:text:NO|attempt_count:integer:NO|last_error_code:text:YES|profile_audit_event_id:uuid:YES|auth_audit_event_id:uuid:YES|requested_at:timestamp with time zone:NO|processing_started_at:timestamp with time zone:YES|auth_synchronized_at:timestamp with time zone:YES|completed_at:timestamp with time zone:YES|updated_at:timestamp with time zone:NO'
     or (select count(*) from pg_constraint where conrelid='public.admin_auth_operations'::regclass)<>16
     or (select count(*) from pg_indexes where schemaname='public' and tablename='admin_auth_operations')<>5
     or (select count(*) from pg_trigger where tgrelid='public.admin_auth_operations'::regclass and not tgisinternal)<>2
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
       ('guard_admin_auth_operation_b3a()','c90a06bb49d1f705d220c63691278d04'),
       ('get_admin_account_auth_lifecycle_context_b3a(uuid)','8748f265e02c560b319469752902badc'),
       ('prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)','311caba6baf9a5d220d013d58ff82ec3'),
       ('claim_admin_auth_operation_b3a(uuid,uuid)','9e56474054dc3dae3e5f000c5322bf8c'),
       ('record_admin_auth_operation_result_b3a(uuid,uuid,text,text)','3d7113328aa036840d0499a824d8fbce'),
       ('finalize_admin_account_auth_reactivation_b3a(uuid)','493c12625b205ad4e36f27d86a373ae4')
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
           ('public.record_admin_auth_operation_result_b3a(uuid,uuid,text,text)'::regprocedure::oid,'postgres'::regrole::oid),
           ('public.record_admin_auth_operation_result_b3a(uuid,uuid,text,text)'::regprocedure::oid,'service_role'::regrole::oid)
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
  if has_function_privilege('authenticated','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE') then
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
revoke all on function public.record_admin_auth_operation_result_b3a(uuid,uuid,text,text) from public,anon,authenticated,service_role;
revoke all on function public.guard_admin_auth_operation_b3a() from public,anon,authenticated,service_role;

drop function public.get_admin_account_auth_lifecycle_context_b3a(uuid);
drop function public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid);
drop function public.finalize_admin_account_auth_reactivation_b3a(uuid);
drop function public.claim_admin_auth_operation_b3a(uuid,uuid);
drop function public.record_admin_auth_operation_result_b3a(uuid,uuid,text,text);

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
  if current_setting('sitaa_0010.rollback_default_acl_hash',true) is distinct from
     (select md5(coalesce(string_agg(defaclrole::text||':'||defaclnamespace::text||':'||defaclobjtype::text||':'||defaclacl::text,'|' order by defaclrole,defaclnamespace,defaclobjtype),'')) from pg_default_acl) then
    raise exception 'sitaa_0010_rollback_default_acl_changed' using errcode='55000';
  end if;
end;
$post_rollback$;

commit;
