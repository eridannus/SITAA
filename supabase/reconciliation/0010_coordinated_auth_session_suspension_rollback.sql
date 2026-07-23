-- Rollback 0010 disponible únicamente antes de la primera operación B.3a real.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
set local time zone 'UTC';
set local datestyle to 'ISO, MDY';

do $predestructive$
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
  if (select string_agg(column_name||':'||data_type||':'||is_nullable,'|' order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='admin_auth_operations')<>
       'id:uuid:NO|request_id:uuid:NO|requested_by_profile_id:uuid:NO|completed_by_profile_id:uuid:YES|target_profile_id:uuid:NO|operation_code:text:NO|status:text:NO|completed_stage:text:NO|reason:text:NO|attempt_count:integer:NO|last_error_code:text:YES|profile_audit_event_id:uuid:YES|auth_audit_event_id:uuid:YES|requested_at:timestamp with time zone:NO|processing_started_at:timestamp with time zone:YES|auth_synchronized_at:timestamp with time zone:YES|completed_at:timestamp with time zone:YES|updated_at:timestamp with time zone:NO'
     or (select count(*) from pg_constraint where conrelid='public.admin_auth_operations'::regclass)<>16
     or (select count(*) from pg_indexes where schemaname='public' and tablename='admin_auth_operations')<>5
     or (select count(*) from pg_trigger where tgrelid='public.admin_auth_operations'::regclass and not tgisinternal)<>2
     or not (select relrowsecurity from pg_class where oid='public.admin_auth_operations'::regclass)
     or (select count(*) from pg_policies where schemaname='public' and tablename='admin_auth_operations')<>0
     or exists(select 1 from (values
       ('guard_admin_auth_operation_b3a()','43660b1265d2a648a84e85bef18185b1'),
       ('get_admin_account_auth_lifecycle_context_b3a(uuid)','cf48187f1d6f0f90f76c85a1a4f245c7'),
       ('prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)','5079a57ba8f237a5ebb890357e090c14'),
       ('claim_admin_auth_operation_b3a(uuid,uuid)','20154250d73d4ae51d8004d5d8287ad0'),
       ('record_admin_auth_operation_result_b3a(uuid,uuid,text,text)','33a344c12fa1878fe18cede103246dea'),
       ('finalize_admin_account_auth_reactivation_b3a(uuid)','573cf1c366f0995cdc81ad0c57b31d44')
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
end;
$predestructive$;

lock table public.admin_auth_operations in access exclusive mode nowait;

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
     or (select count(*) from information_schema.table_privileges where table_schema='public')<>267 then
    raise exception 'sitaa_0010_rollback_post_0009_mismatch' using errcode='55000';
  end if;
end;
$post_rollback$;

commit;
