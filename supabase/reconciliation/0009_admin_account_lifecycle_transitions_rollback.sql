-- Rollback controlado 0009. No revierte estados ni elimina auditoría/datos.
begin;

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
     or (select count(*) from information_schema.usage_privileges where object_schema='public' and object_type='SEQUENCE')<>6
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public') + (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault(case when c.relkind='S' then 's'::"char" else 'r'::"char" end,c.relowner))) a where n.nspname='public' and c.relkind in ('r','p','v','m','S'))<>445 then
    raise exception 'sitaa_0009_rollback_guard_failed' using errcode='55000';
  end if;
  select count(*) into mismatch_count
  from (values
    ('is_exact_b1_account_admin_profile_b2b(uuid)','104d16a531ea53a5b4908102322097dc'),
    ('get_admin_account_lifecycle_context_b2b(uuid)','6e7c8bb5e2dcf99fce6a75e03e07c309'),
    ('transition_admin_account_lifecycle_b2b(uuid,text,text)','0080f41a2cd78576763ebb5d5128996e')
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
    if not (select p.prosecdef and p.proconfig=array['search_path=pg_catalog, public']::text[] from pg_proc p where p.oid=function_oid)
       or has_function_privilege('anon',function_oid,'EXECUTE')
       or has_function_privilege('service_role',function_oid,'EXECUTE')
       or exists(
         select 1 from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
         where p.oid=function_oid and acl.privilege_type='EXECUTE' and (
           acl.grantee=0 or acl.is_grantable and acl.grantee<>p.proowner
           or function_oid='public.is_exact_b1_account_admin_profile_b2b(uuid)'::regprocedure and acl.grantee<>p.proowner
           or function_oid<>'public.is_exact_b1_account_admin_profile_b2b(uuid)'::regprocedure and acl.grantee not in (p.proowner,'authenticated'::regrole)
         )
       ) then
      raise exception 'sitaa_0009_rollback_function_acl_guard_failed:%',function_oid using errcode='55000';
    end if;
  end loop;
  if has_function_privilege('authenticated','public.is_exact_b1_account_admin_profile_b2b(uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.get_admin_account_lifecycle_context_b2b(uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('is_exact_b1_account_admin_profile_b2b','get_admin_account_lifecycle_context_b2b','transition_admin_account_lifecycle_b2b'))<>3 then
    raise exception 'sitaa_0009_rollback_signature_or_acl_guard_failed' using errcode='55000';
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
     or (select count(*) from pg_trigger where tgrelid='public.admin_audit_events'::regclass and not tgisinternal)<>2 then
    raise exception 'sitaa_0009_rollback_prior_contract_guard_failed' using errcode='55000';
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
     or (select count(*) from information_schema.usage_privileges where object_schema='public' and object_type='SEQUENCE')<>6
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public') + (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault(case when c.relkind='S' then 's'::"char" else 'r'::"char" end,c.relowner))) a where n.nspname='public' and c.relkind in ('r','p','v','m','S'))<>440 then
    raise exception 'sitaa_0009_rollback_postcondition_failed' using errcode='55000';
  end if;
  if to_regprocedure('public.get_admin_account_detail_b1(uuid)') is null
     or to_regprocedure('public.correct_admin_account_identity_b2a(uuid,text,text,text,text,text,uuid,text)') is null
     or to_regclass('public.admin_audit_events') is null then
    raise exception 'sitaa_0009_rollback_preservation_failed' using errcode='55000';
  end if;
end;
$post_rollback$;

commit;
