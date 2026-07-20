-- Verificador transaccional 0007. Sólo usa identidades sintéticas y termina en ROLLBACK.
begin;

-- Contrato estático de objetos, RLS, firmas, search_path y privilegios.
do $static_contract$
declare
  rpc regprocedure;
begin
  if not exists(select 1 from pg_roles where rolname='service_role' and rolbypassrls=true)
     or to_regclass('public.admin_audit_events') is null
     or not exists (
       select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relname = 'admin_audit_events' and c.relrowsecurity
     )
     or exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'admin_audit_events')
     or has_table_privilege('authenticated','public.admin_audit_events','SELECT')
     or has_table_privilege('authenticated','public.admin_audit_events','INSERT')
     or not has_table_privilege('service_role','public.admin_audit_events','SELECT')
     or not has_table_privilege('service_role','public.admin_audit_events','INSERT')
     or has_table_privilege('service_role','public.admin_audit_events','UPDATE')
     or has_table_privilege('service_role','public.admin_audit_events','DELETE')
     or has_table_privilege('service_role','public.admin_audit_events','TRUNCATE')
     or has_table_privilege('service_role','public.admin_audit_events','REFERENCES')
     or has_table_privilege('service_role','public.admin_audit_events','TRIGGER')
     or exists (
       select 1 from pg_class c
       cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) acl
       where c.oid='public.admin_audit_events'::regclass
         and acl.grantee=(select oid from pg_roles where rolname='service_role')
         and upper(acl.privilege_type) not in ('SELECT','INSERT')
     )
     or exists (
       select 1 from pg_class c
       cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) acl
       where c.oid='public.admin_audit_events'::regclass
         and (acl.grantee=0 or acl.grantee=(select oid from pg_roles where rolname='anon'))
     ) then
    raise exception '0007: contrato RLS o privilegios de admin_audit_events inválido.';
  end if;

  foreach rpc in array array[
    'public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)'::regprocedure,
    'public.get_admin_account_detail_b1(uuid)'::regprocedure,
    'public.get_admin_account_assignments_b1(uuid)'::regprocedure,
    'public.get_admin_account_audit_history_b1(uuid,integer,integer)'::regprocedure
  ] loop
    if not has_function_privilege('authenticated', rpc, 'EXECUTE')
       or has_function_privilege('anon', rpc, 'EXECUTE')
       or exists (
         select 1 from aclexplode((select coalesce(proacl, acldefault('f', proowner)) from pg_proc where oid = rpc))
         where grantee = 0 and privilege_type = 'EXECUTE'
       )
       or (select not prosecdef from pg_proc where oid = rpc)
       or lower(pg_get_functiondef(rpc)) not like '%set search_path%pg_catalog%public%' then
      raise exception '0007: privilegio, SECURITY DEFINER o search_path inválido para %.', rpc;
    end if;
  end loop;

  if has_function_privilege('authenticated','public.is_b1_account_admin()','EXECUTE')
     or has_function_privilege('anon','public.admin_audit_metadata_is_safe(jsonb)','EXECUTE')
     or has_function_privilege('authenticated','public.admin_audit_metadata_is_safe(jsonb)','EXECUTE')
     or not has_function_privilege('service_role','public.admin_audit_metadata_is_safe(jsonb)','EXECUTE')
     or exists (
       select 1
       from pg_proc p
       cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
       where p.oid='public.admin_audit_metadata_is_safe(jsonb)'::regprocedure
         and acl.privilege_type='EXECUTE'
         and acl.grantee not in (
           p.proowner,
           (select oid from pg_roles where rolname='service_role')
         )
     )
     or has_function_privilege('authenticated','public.prevent_admin_audit_event_mutation()','EXECUTE')
     or not exists (
       select 1 from pg_trigger t where t.tgrelid = 'public.admin_audit_events'::regclass
         and t.tgname = 'prevent_admin_audit_event_mutation' and not t.tgisinternal
     )
     or not exists (
       select 1 from pg_trigger t where t.tgrelid = 'public.admin_audit_events'::regclass
         and t.tgname = 'prevent_admin_audit_event_truncate' and not t.tgisinternal
     ) then
    raise exception '0007: helper privado o trigger append-only inválido.';
  end if;

  if lower(pg_get_function_result('public.get_admin_account_detail_b1(uuid)'::regprocedure))
       ~ '(email_confirmed_at|raw_|token|password|cookie|identity_data)'
     or lower(pg_get_function_result('public.get_admin_account_assignments_b1(uuid)'::regprocedure))
       ~ '(revoked_by|revoked_at|administrative_notes)'
     or lower(pg_get_function_result('public.get_admin_account_audit_history_b1(uuid,integer,integer)'::regprocedure))
       ~ '(^|[ ,])metadata([ ,]|$)' then
    raise exception '0007: una proyección RPC expone campos fuera de B.1.';
  end if;

  if pg_get_function_arguments('public.get_admin_account_audit_history_b1(uuid,integer,integer)'::regprocedure)
       not like 'requested_profile_id uuid%'
     or pg_get_function_result('public.get_admin_account_audit_history_b1(uuid,integer,integer)'::regprocedure)
       not like '%target_profile_id uuid%' then
    raise exception '0007: firma nominal del historial incompatible con PostgREST.';
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'role_assignments'
      and column_name in ('revoked_by','revoked_at','administrative_notes','status')
  ) then
    raise exception '0007: el esquema V1 fue sustituido indebidamente por semántica de Fase C.';
  end if;
end;
$static_contract$;

create temporary table sitaa_0007_context (
  run_id uuid not null,
  run_marker text not null,
  wildcard_marker text not null,
  identifier_seed text not null,
  division_id uuid not null,
  program_id uuid not null
) on commit drop;
with generated as (select gen_random_uuid() run_id)
insert into sitaa_0007_context
select run_id,
  'v7' || replace(run_id::text,'-',''),
  'v7' || replace(run_id::text,'-','') || E'%_\\ruta',
  translate(replace(run_id::text,'-',''),'abcdef','012345'),
  gen_random_uuid(), gen_random_uuid()
from generated;

insert into public.divisions (id, code, name)
select division_id, 'v7d_' || left(replace(division_id::text,'-',''), 16), 'División sintética 0007'
from sitaa_0007_context;
insert into public.academic_programs (id, division_id, code, name, is_active)
select program_id, division_id, 'v7p_' || left(replace(program_id::text,'-',''), 16), 'Programa sintético 0007', true
from sitaa_0007_context;

create temporary table sitaa_0007_cases (
  label text primary key,
  id uuid not null unique,
  email text not null unique,
  institutional_identifier text null unique
) on commit drop;

create function pg_temp.case_id(target_label text)
returns uuid language sql stable set search_path = pg_temp as $$
  select id from sitaa_0007_cases where label = target_label
$$;
create function pg_temp.case_email(target_label text)
returns text language sql stable set search_path = pg_temp as $$
  select email from sitaa_0007_cases where label = target_label
$$;
create function pg_temp.case_identifier(target_label text)
returns text language sql stable set search_path = pg_temp as $$
  select institutional_identifier from sitaa_0007_cases where label = target_label
$$;
create function pg_temp.run_marker()
returns text language sql stable set search_path = pg_temp as $$
  select run_marker from sitaa_0007_context limit 1
$$;
create function pg_temp.wildcard_marker()
returns text language sql stable set search_path = pg_temp as $$
  select wildcard_marker from sitaa_0007_context limit 1
$$;
create function pg_temp.set_request_user(target_label text)
returns void language plpgsql set search_path = pg_temp, pg_catalog as $$
declare target_id uuid := pg_temp.case_id(target_label);
begin
  perform set_config('request.jwt.claim.sub', target_id::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', target_id, 'role', 'authenticated')::text, true);
end;
$$;

revoke all on function pg_temp.case_id(text) from public, anon;
revoke all on function pg_temp.case_email(text) from public, anon;
revoke all on function pg_temp.case_identifier(text) from public, anon;
revoke all on function pg_temp.run_marker() from public, anon;
revoke all on function pg_temp.wildcard_marker() from public, anon;
revoke all on function pg_temp.set_request_user(text) from public, anon;
grant select on table pg_temp.sitaa_0007_cases, pg_temp.sitaa_0007_context to authenticated;
grant execute on function pg_temp.case_id(text), pg_temp.case_email(text),
  pg_temp.case_identifier(text), pg_temp.run_marker(), pg_temp.wildcard_marker(),
  pg_temp.set_request_user(text) to authenticated;

create function pg_temp.create_case(
  target_label text,
  target_kind text,
  target_person text default null,
  target_status text default 'active',
  target_confirmed boolean default true
)
returns uuid
language plpgsql
set search_path = public, auth, pg_temp, pg_catalog
as $$
declare
  target_id uuid := gen_random_uuid();
  target_run_marker text := (select run_marker from sitaa_0007_context limit 1);
  target_email text := replace(target_label, '_', '-') || '-' || target_run_marker || '@example.invalid';
  target_program uuid := (select program_id from sitaa_0007_context limit 1);
  case_number integer := (select count(*) + 1 from sitaa_0007_cases);
  target_identifier text;
  app_metadata jsonb;
begin
  if target_kind <> 'technical' then
    target_identifier := (select identifier_seed from sitaa_0007_context limit 1)
      || lpad(case_number::text,3,'0');
  end if;
  if target_kind = 'technical' then
    app_metadata := jsonb_build_object(
      'sitaa_account_kind','technical',
      'sitaa_first_names','Soporte ' || target_run_marker
    );
  else
    app_metadata := jsonb_build_object('provider','google','providers',jsonb_build_array('google'));
  end if;
  insert into sitaa_0007_cases
  values (target_label, target_id, target_email, target_identifier);
  insert into auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values (
    target_id, 'authenticated', 'authenticated', target_email, '',
    case when target_confirmed then now() else null end,
    app_metadata, jsonb_build_object('name','Cuenta sintética'), now(), now()
  );

  if target_kind = 'technical' then
    update public.profiles set
      first_names = 'Soporte ' || target_run_marker, paternal_surname = null, maternal_surname = null,
      full_name = 'Soporte ' || target_run_marker, account_kind = 'technical',
      account_status = target_status, person_type = null, primary_program_id = null,
      institutional_id_type = null, institutional_id_value = null,
      is_active = (target_status = 'active'), activated_at = now(),
      deactivated_at = case when target_status = 'inactive' then now() else null end
    where id = target_id;
  else
    update public.profiles set
      first_names = case when target_label = 'target_account'
        then (select wildcard_marker from sitaa_0007_context limit 1)
        else 'Persona ' || target_run_marker end,
      paternal_surname = case when target_label = 'target_account' then 'Única' else 'Sintética' end,
      maternal_surname = 'Prueba',
      full_name = case when target_label = 'target_account'
        then (select wildcard_marker from sitaa_0007_context limit 1) || ' Única Prueba'
        else 'Persona ' || target_run_marker || ' Sintética Prueba' end,
      account_kind = 'institutional', account_status = target_status,
      person_type = target_person, primary_program_id = target_program,
      institutional_id_type = case when target_person = 'student' then 'student_account' else 'worker_number' end,
      institutional_id_value = target_identifier,
      is_active = (target_status = 'active'), activated_at = now(),
      deactivated_at = case when target_status = 'inactive' then now() else null end
    where id = target_id;
  end if;
  return target_id;
end;
$$;

select pg_temp.create_case('admin_exact','technical');
select pg_temp.create_case('ordinary_student','institutional','student');
select pg_temp.create_case('ordinary_professor','institutional','professor');
select pg_temp.create_case('admin_bad_scope','technical');
select pg_temp.create_case('admin_bad_service','technical');
select pg_temp.create_case('admin_bad_program','technical');
select pg_temp.create_case('admin_bad_division','technical');
select pg_temp.create_case('admin_future','technical');
select pg_temp.create_case('admin_expired','technical');
select pg_temp.create_case('admin_inactive_assignment','technical');
select pg_temp.create_case('admin_start_today','technical');
select pg_temp.create_case('admin_end_today','technical');
select pg_temp.create_case('admin_inactive','technical',null,'inactive');
select pg_temp.create_case('target_account','institutional','student');
select pg_temp.create_case('same_row_target','institutional','professor');
select pg_temp.create_case('google_confirmed','institutional','student','active',false);
select pg_temp.create_case('google_mismatch','institutional','student','active',false);
select pg_temp.create_case('unconfirmed','institutional','student','active',false);

insert into public.role_assignments (
  user_id, role_code, scope_type, service_area, division_id, program_id,
  starts_at, ends_at, is_active, assigned_by
)
values
  (pg_temp.case_id('admin_exact'),'technical_admin','system','technical',null,null,current_date,null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('ordinary_student'),'student','own','both',null,null,current_date,null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('ordinary_professor'),'professor','program','both',null,(select program_id from sitaa_0007_context),current_date,null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_bad_scope'),'technical_admin','own','technical',null,null,current_date,null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_bad_service'),'technical_admin','system','both',null,null,current_date,null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_bad_program'),'technical_admin','program','technical',null,(select program_id from sitaa_0007_context),current_date,null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_bad_division'),'technical_admin','division','technical',(select division_id from sitaa_0007_context),null,current_date,null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_future'),'technical_admin','system','technical',null,null,current_date+1,null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_expired'),'technical_admin','system','technical',null,null,current_date-2,current_date-1,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_inactive_assignment'),'technical_admin','system','technical',null,null,current_date,null,false,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_start_today'),'technical_admin','system','technical',null,null,current_date,null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_end_today'),'technical_admin','system','technical',null,null,current_date-1,current_date,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_inactive'),'technical_admin','system','technical',null,null,current_date,null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('target_account'),'student','own','both',null,null,current_date,null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('same_row_target'),'professor','program','advising',null,(select program_id from sitaa_0007_context),current_date,null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('same_row_target'),'peer_tutor','own','tutoring',null,null,current_date,null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('target_account'),'peer_tutor','own','tutoring',null,null,current_date+1,null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('target_account'),'professor','program','advising',null,(select program_id from sitaa_0007_context),current_date-3,current_date-1,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('target_account'),'student','own','both',null,null,current_date,null,false,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_inactive'),'technical_admin','system','technical',null,null,current_date,null,true,pg_temp.case_id('admin_exact'));

create function pg_temp.insert_google_identity(target_label text, identity_email text)
returns void language plpgsql set search_path = auth, pg_temp, pg_catalog, information_schema as $$
declare
  target_id uuid := pg_temp.case_id(target_label);
  provider_key text := 'google-' || target_label || '-' || pg_temp.run_marker();
  payload jsonb := jsonb_build_object('sub',provider_key,'email',identity_email,'email_verified',true);
begin
  if exists (select 1 from information_schema.columns
    where table_schema='auth' and table_name='identities' and column_name='provider_id') then
    execute 'insert into auth.identities (provider_id,user_id,identity_data,provider,last_sign_in_at,created_at,updated_at) values ($1,$2,$3,''google'',now(),now(),now())'
      using provider_key,target_id,payload;
  else
    execute 'insert into auth.identities (id,user_id,identity_data,provider,last_sign_in_at,created_at,updated_at) values ($1,$2,$3,''google'',now(),now(),now())'
      using provider_key,target_id,payload;
  end if;
end;
$$;
select pg_temp.insert_google_identity('google_confirmed',pg_temp.case_email('google_confirmed'));
select pg_temp.insert_google_identity(
  'google_mismatch',
  'different-' || pg_temp.run_marker() || '@example.invalid'
);

insert into public.admin_audit_events (
  actor_profile_id, target_profile_id, action_code, outcome, reason, metadata
) values (
  pg_temp.case_id('admin_exact'), pg_temp.case_id('target_account'),
  'synthetic_verification', 'success', 'Evento sintético transaccional',
  jsonb_build_object('context','0007 verifier')
);

-- Contrato funcional de service_role: sólo inserta/consulta y alcanza el CHECK seguro.
grant select on table pg_temp.sitaa_0007_cases to service_role;
grant execute on function pg_temp.case_id(text) to service_role;
set local role service_role;
do $service_role_contract$
declare rejected boolean;
begin
  insert into public.admin_audit_events(
    actor_profile_id,target_profile_id,action_code,outcome,metadata
  ) values (
    pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),
    'service_role_safe_insert','success',jsonb_build_object('source','service_role_verifier')
  );
  if not exists (
    select 1 from public.admin_audit_events
    where action_code='service_role_safe_insert'
      and actor_profile_id=pg_temp.case_id('admin_exact')
      and target_profile_id=pg_temp.case_id('target_account')
  ) then
    raise exception '0007: service_role no pudo consultar su inserción válida.';
  end if;

  rejected := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'service_unsafe_key','failure',jsonb_build_object('accessToken','x'));
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: service_role aceptó metadata sensible.'; end if;

  rejected := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'service_non_object','failure','[]'::jsonb);
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: service_role aceptó metadata no objeto.'; end if;

  rejected := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'service_oversized','failure',jsonb_build_object('context',repeat('x',17000)));
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: service_role aceptó metadata sobredimensionada.'; end if;

  rejected := false;
  begin update public.admin_audit_events set reason='Prohibido';
  exception when insufficient_privilege then rejected := true; end;
  if not rejected then raise exception '0007: service_role obtuvo UPDATE.'; end if;
  rejected := false;
  begin delete from public.admin_audit_events;
  exception when insufficient_privilege then rejected := true; end;
  if not rejected then raise exception '0007: service_role obtuvo DELETE.'; end if;
  rejected := false;
  begin truncate public.admin_audit_events;
  exception when insufficient_privilege then rejected := true; end;
  if not rejected then raise exception '0007: service_role obtuvo TRUNCATE.'; end if;
end;
$service_role_contract$;
reset role;

-- Casos 2 a 5: toda identidad sin el contrato exacto recibe el mismo 42501.
create function pg_temp.expect_denied(target_label text)
returns void language plpgsql set search_path = public, pg_temp, pg_catalog as $$
declare
  denied boolean;
  requested_id uuid;
begin
  perform pg_temp.set_request_user(target_label);
  denied := false;
  begin
    perform * from public.search_admin_accounts_b1(
      pg_temp.run_marker(),null,null,null,null,null,null,null,1,20
    );
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then
    raise exception '0007: % obtuvo acceso a search_admin_accounts_b1.',target_label;
  end if;

  foreach requested_id in array array[pg_temp.case_id('target_account'),gen_random_uuid()] loop
    denied := false;
    begin perform * from public.get_admin_account_detail_b1(requested_id);
    exception when insufficient_privilege then denied := true; end;
    if not denied then
      raise exception '0007: % distinguió existencia mediante detalle.',target_label;
    end if;

    denied := false;
    begin perform * from public.get_admin_account_assignments_b1(requested_id);
    exception when insufficient_privilege then denied := true; end;
    if not denied then
      raise exception '0007: % distinguió existencia mediante asignaciones.',target_label;
    end if;

    denied := false;
    begin perform * from public.get_admin_account_audit_history_b1(
      requested_profile_id=>requested_id,result_limit=>50,result_offset=>0
    );
    exception when insufficient_privilege then denied := true; end;
    if not denied then
      raise exception '0007: % distinguió existencia mediante auditoría.',target_label;
    end if;
  end loop;
end;
$$;
select pg_temp.expect_denied('ordinary_student');
select pg_temp.expect_denied('ordinary_professor');
select pg_temp.expect_denied('admin_bad_scope');
select pg_temp.expect_denied('admin_bad_service');
select pg_temp.expect_denied('admin_bad_program');
select pg_temp.expect_denied('admin_bad_division');
select pg_temp.expect_denied('admin_future');
select pg_temp.expect_denied('admin_expired');
select pg_temp.expect_denied('admin_inactive_assignment');
select pg_temp.expect_denied('admin_inactive');

-- Los límites de fecha de la asignación son inclusivos.
select pg_temp.set_request_user('admin_start_today');
set local role authenticated;
do $$ begin
  if not exists(select 1 from public.search_admin_accounts_b1(
    pg_temp.run_marker() || '%',null,null,null,null,null,null,null,1,1
  )) then
    raise exception '0007: starts_at del día actual no fue inclusivo.';
  end if;
end $$;
reset role;
select pg_temp.set_request_user('admin_end_today');
set local role authenticated;
do $$ begin
  if not exists(select 1 from public.search_admin_accounts_b1(
    pg_temp.run_marker() || '%',null,null,null,null,null,null,null,1,1
  )) then
    raise exception '0007: ends_at del día actual no fue inclusivo.';
  end if;
end $$;
reset role;

-- Casos autorizados 1 y 6 a 15.
select pg_temp.set_request_user('admin_exact');
set local role authenticated;

do $authorized_cases$
declare
  target_id uuid := pg_temp.case_id('target_account');
  program_value uuid := (select program_id from pg_temp.sitaa_0007_context limit 1);
  result_count bigint;
  masked_value text;
  expected_identifier text := pg_temp.case_identifier('target_account');
  rejected boolean;
begin
  select count(*) into result_count from public.search_admin_accounts_b1(
    pg_temp.run_marker() || '%',null,null,null,null,null,null,null,1,20
  );
  if result_count <> 1 then raise exception '0007: el porcentaje no fue tratado literalmente.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(
    pg_temp.run_marker() || '%_',null,null,null,null,null,null,null,1,20
  );
  if result_count <> 1 then raise exception '0007: porcentaje y guion bajo no fueron literales.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(
    pg_temp.wildcard_marker(),null,null,null,null,null,null,null,1,20
  );
  if result_count <> 1 then raise exception '0007: la barra inversa no fue tratada de forma segura.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(
    pg_temp.run_marker() || '%%',null,null,null,null,null,null,null,1,20
  );
  if result_count <> 0 then raise exception '0007: un patrón de comodines amplió el directorio.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(
    pg_temp.case_email('target_account'),null,null,null,null,null,null,null,1,20
  );
  if result_count <> 1 then raise exception '0007: la búsqueda por correo falló.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(
    expected_identifier,null,null,null,null,null,null,null,1,20
  );
  if result_count <> 1 then raise exception '0007: la búsqueda por identificador falló.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(null,null,null,null,null,null,null,null,1,20);
  if result_count <> 0 then raise exception '0007: el estado sin criterios expuso el directorio.'; end if;

  select count(*) into result_count from public.search_admin_accounts_b1(null,program_value,null,null,null,null,null,null,1,20);
  if result_count < 1 then raise exception '0007: filtro de programa falló.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(null,null,'technical',null,null,null,null,null,1,20);
  if result_count < 1 then raise exception '0007: filtro de tipo de cuenta falló.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(null,null,null,'inactive',null,null,null,null,1,20);
  if result_count < 1 then raise exception '0007: filtro de estado falló.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(null,null,null,null,'student',null,null,null,1,20);
  if result_count < 1 then raise exception '0007: filtro de persona falló.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(null,null,null,null,null,'student','both','own',1,20);
  if result_count < 1 then raise exception '0007: filtros de asignación actual fallaron.'; end if;

  select count(*) into result_count from public.search_admin_accounts_b1(null,null,null,null,null,'professor','tutoring',null,1,20)
  where profile_id = pg_temp.case_id('same_row_target');
  if result_count <> 0 then raise exception '0007: rol y servicio combinaron filas distintas.'; end if;

  rejected := false;
  begin perform * from public.search_admin_accounts_b1(pg_temp.run_marker(),null,null,null,null,null,null,null,0,20);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: page_number inválido fue aceptado.'; end if;
  rejected := false;
  begin perform * from public.search_admin_accounts_b1(pg_temp.run_marker(),null,null,null,null,null,null,null,1,51);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: page_size mayor a 50 fue aceptado.'; end if;
  rejected := false;
  begin perform * from public.search_admin_accounts_b1(pg_temp.run_marker(),null,null,null,null,null,null,null,1,0);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: page_size cero fue aceptado.'; end if;
  rejected := false;
  begin perform * from public.search_admin_accounts_b1(pg_temp.run_marker(),null,null,null,null,null,null,null,1,-1);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: page_size negativo fue aceptado.'; end if;

  rejected := false;
  begin perform * from public.search_admin_accounts_b1(pg_temp.run_marker(),null,null,null,null,null,null,null,null,20);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: page_number NULL fue aceptado.'; end if;
  rejected := false;
  begin perform * from public.search_admin_accounts_b1(pg_temp.run_marker(),null,null,null,null,null,null,null,1,null);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: page_size NULL fue aceptado.'; end if;
  rejected := false;
  begin perform * from public.search_admin_accounts_b1(pg_temp.run_marker(),null,null,null,null,null,null,null,-1,20);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: page_number negativo fue aceptado.'; end if;
  rejected := false;
  begin perform * from public.search_admin_accounts_b1(pg_temp.run_marker(),null,null,null,null,null,null,null,1000001,20);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: page_number superior al máximo fue aceptado.'; end if;
  perform * from public.search_admin_accounts_b1(pg_temp.run_marker(),null,null,null,null,null,null,null,1000000,50);

  select masked_institutional_id into masked_value
  from public.search_admin_accounts_b1(expected_identifier,null,null,null,null,null,null,null,1,20)
  where profile_id = target_id;
  if masked_value = expected_identifier
     or right(masked_value,4) <> right(expected_identifier,4) then
    raise exception '0007: el identificador de lista no está enmascarado.';
  end if;

  if not exists (
    select 1 from public.get_admin_account_detail_b1(target_id)
    where institutional_id_value = expected_identifier
      and auth_email_confirmed is true
  ) then raise exception '0007: detalle completo o resumen Auth mínimo incorrecto.'; end if;

  if not exists(select 1 from public.get_admin_account_detail_b1(pg_temp.case_id('google_confirmed')) where auth_email_confirmed)
     or exists(select 1 from public.get_admin_account_detail_b1(pg_temp.case_id('google_mismatch')) where auth_email_confirmed)
     or exists(select 1 from public.get_admin_account_detail_b1(pg_temp.case_id('unconfirmed')) where auth_email_confirmed) then
    raise exception '0007: el resumen booleano de confirmación Google no coincide con el contrato vivo.';
  end if;

  if not exists (
    select 1 from public.get_admin_account_assignments_b1(target_id)
    where presentation_status = 'current'
  ) then raise exception '0007: clasificación V1 de asignación incorrecta.'; end if;
  if (select count(distinct presentation_status) from public.get_admin_account_assignments_b1(target_id)
      where presentation_status in ('current','future','expired','inactive')) <> 4
     or not exists(select 1 from public.get_admin_account_assignments_b1(pg_temp.case_id('admin_inactive'))
       where presentation_status='suspended_by_account_status') then
    raise exception '0007: faltan estados de presentación V1.';
  end if;

  if not exists (
    select 1 from public.get_admin_account_audit_history_b1(requested_profile_id => target_id,result_limit => 50,result_offset => 0)
    where action_code = 'synthetic_verification' and reason = 'Evento sintético transaccional'
  ) then raise exception '0007: historial sanitizado no devolvió el evento sintético.'; end if;

  foreach result_count in array array[0,-1,51,1000001] loop
    rejected := false;
    begin perform * from public.get_admin_account_audit_history_b1(target_id,result_count::integer,0);
    exception when invalid_parameter_value then rejected := true; end;
    if not rejected then raise exception '0007: result_limit inválido fue aceptado: %.',result_count; end if;
  end loop;
  rejected := false;
  begin perform * from public.get_admin_account_audit_history_b1(target_id,null,0);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: result_limit NULL fue aceptado.'; end if;
  foreach result_count in array array[-1,1000001] loop
    rejected := false;
    begin perform * from public.get_admin_account_audit_history_b1(target_id,50,result_count::integer);
    exception when invalid_parameter_value then rejected := true; end;
    if not rejected then raise exception '0007: result_offset inválido fue aceptado: %.',result_count; end if;
  end loop;
  rejected := false;
  begin perform * from public.get_admin_account_audit_history_b1(target_id,50,null);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: result_offset NULL fue aceptado.'; end if;
  perform * from public.get_admin_account_audit_history_b1(target_id,50,1000000);
end;
$authorized_cases$;

-- Casos 16: sin acceso directo a la bitácora.
do $direct_table_denial$
declare denied boolean;
begin
  denied := false;
  begin perform count(*) from public.admin_audit_events;
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception '0007: authenticated leyó directamente la bitácora.'; end if;
  denied := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'forbidden_insert','failure');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception '0007: authenticated insertó directamente en la bitácora.'; end if;
  denied := false;
  begin update public.admin_audit_events set reason='Prohibido';
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception '0007: authenticated actualizó directamente la bitácora.'; end if;
  denied := false;
  begin delete from public.admin_audit_events;
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception '0007: authenticated eliminó directamente de la bitácora.'; end if;
  denied := false;
  begin truncate public.admin_audit_events;
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception '0007: authenticated truncó directamente la bitácora.'; end if;
end;
$direct_table_denial$;

reset role;

-- Casos 17 y 18: append-only y metadata segura, aun para ejecución privilegiada.
do $audit_integrity$
declare rejected boolean;
begin
  rejected := false;
  begin update public.admin_audit_events set reason = 'Cambio prohibido';
  exception when object_not_in_prerequisite_state then rejected := true; end;
  if not rejected then raise exception '0007: UPDATE de bitácora fue aceptado.'; end if;

  rejected := false;
  begin delete from public.admin_audit_events;
  exception when object_not_in_prerequisite_state then rejected := true; end;
  if not rejected then raise exception '0007: DELETE de bitácora fue aceptado.'; end if;

  rejected := false;
  begin truncate public.admin_audit_events;
  exception when object_not_in_prerequisite_state then rejected := true; end;
  if not rejected then raise exception '0007: TRUNCATE de bitácora fue aceptado.'; end if;

  rejected := false;
  begin
    insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values (pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'unsafe_metadata','failure','{"access_token":"prohibido"}'::jsonb);
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: metadata sensible fue aceptada.'; end if;

  rejected := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'unsafe_camel','failure',jsonb_build_object('accessToken','x'));
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: accessToken fue aceptado.'; end if;
  rejected := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'unsafe_dash','failure',jsonb_build_object('refresh-token','x'));
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: refresh-token fue aceptado.'; end if;
  rejected := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'unsafe_auth','failure',jsonb_build_object('authorizationHeader','x'));
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: authorizationHeader fue aceptado.'; end if;
  rejected := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'unsafe_recovery','failure',jsonb_build_object('recoveryLink','x'));
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: recoveryLink fue aceptado.'; end if;
  rejected := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'unsafe_secret','failure',jsonb_build_object('clientSecretValue','x'));
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: clientSecretValue fue aceptado.'; end if;

  insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
  values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'safe_metadata','success',jsonb_build_object('source','verifier'));

  rejected := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'non_object','failure','[]'::jsonb);
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: metadata no objeto fue aceptada.'; end if;

  rejected := false;
  begin
    insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values (pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'oversized_metadata','failure',jsonb_build_object('context',repeat('x',17000)));
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: metadata sobredimensionada fue aceptada.'; end if;
end;
$audit_integrity$;

-- Caso 19: RLS propio permanece sin ampliación transversal.
select pg_temp.set_request_user('ordinary_student');
set local role authenticated;
do $own_rls$
begin
  if (select count(*) from public.profiles) <> 1
     or not exists (select 1 from public.profiles where id = pg_temp.case_id('ordinary_student'))
     or exists (select 1 from public.profiles where id = pg_temp.case_id('target_account'))
     or exists (select 1 from public.role_assignments where user_id <> pg_temp.case_id('ordinary_student')) then
    raise exception '0007: las políticas propias de perfiles o asignaciones cambiaron.';
  end if;
end;
$own_rls$;
reset role;

-- Caso 20: regresiones estáticas esenciales 0002–0006.
do $regressions$
declare draft_definition text := lower(pg_get_functiondef('public.get_visible_activity_cards()'::regprocedure));
begin
  if to_regprocedure('public.publish_activity(uuid)') is null
     or to_regprocedure('public.add_activity_participant(uuid,uuid,text)') is null
     or to_regprocedure('public.update_activity_participant_attendance(uuid,text,text)') is null
     or to_regprocedure('public.open_activity_attendance_checkin(uuid)') is null
     or to_regprocedure('public.check_in_activity(text)') is null
     or to_regprocedure('public.complete_own_google_registration(text,text,text,text,text,uuid)') is null
     or to_regprocedure('public.normalize_sitaa_profile_names()') is null
     or not has_column_privilege('authenticated','public.profiles','first_names','UPDATE')
     or not has_column_privilege('authenticated','public.profiles','paternal_surname','UPDATE')
     or not has_column_privilege('authenticated','public.profiles','maternal_surname','UPDATE')
     or has_column_privilege('authenticated','public.profiles','full_name','UPDATE')
     or not has_table_privilege('authenticated','public.role_assignments','SELECT')
     or has_table_privilege('authenticated','public.role_assignments','UPDATE')
     or not has_function_privilege('authenticated','public.complete_own_google_registration(text,text,text,text,text,uuid)','EXECUTE')
     or has_function_privilege('anon','public.complete_own_google_registration(text,text,text,text,text,uuid)','EXECUTE')
     or has_function_privilege('authenticated','public.complete_own_google_registration(text,text,text,uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.add_activity_participant(uuid,uuid,text)','EXECUTE')
     or has_function_privilege('anon','public.add_activity_participant(uuid,uuid,text)','EXECUTE')
     or not has_function_privilege('authenticated','public.update_activity_participant_attendance(uuid,text,text)','EXECUTE')
     or not has_function_privilege('authenticated','public.open_activity_attendance_checkin(uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.check_in_activity(text)','EXECUTE')
     or draft_definition not like '%status_code = ''draft''%'
     or draft_definition not like '%created_by = auth.uid()%'
     or not exists (
       select 1 from pg_trigger t where t.tgrelid = 'public.profiles'::regclass
         and t.tgname in ('enforce_sitaa_profile_identity','normalize_sitaa_profile_names')
       group by t.tgrelid having count(*) = 2
     ) then
    raise exception '0007: regresión detectada en contratos 0002–0006.';
  end if;
end;
$regressions$;

rollback;
