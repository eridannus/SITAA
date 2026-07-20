-- Verificador transaccional 0007. Sólo usa identidades sintéticas y termina en ROLLBACK.
begin;

-- Contrato estático de objetos, RLS, firmas, search_path y privilegios.
do $static_contract$
declare
  rpc regprocedure;
begin
  if to_regclass('public.admin_audit_events') is null
     or not exists (
       select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relname = 'admin_audit_events' and c.relrowsecurity
     )
     or exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'admin_audit_events')
     or has_table_privilege('authenticated','public.admin_audit_events','SELECT')
     or has_table_privilege('authenticated','public.admin_audit_events','INSERT') then
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
     or has_function_privilege('authenticated','public.admin_audit_metadata_is_safe(jsonb)','EXECUTE')
     or has_function_privilege('authenticated','public.prevent_admin_audit_event_mutation()','EXECUTE')
     or not exists (
       select 1 from pg_trigger t where t.tgrelid = 'public.admin_audit_events'::regclass
         and t.tgname = 'prevent_admin_audit_event_mutation' and not t.tgisinternal
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
  division_id uuid not null,
  program_id uuid not null
) on commit drop;
insert into sitaa_0007_context values (gen_random_uuid(), gen_random_uuid());

insert into public.divisions (id, code, name)
select division_id, 'v7d_' || left(replace(division_id::text,'-',''), 16), 'División sintética 0007'
from sitaa_0007_context;
insert into public.academic_programs (id, division_id, code, name, is_active)
select program_id, division_id, 'v7p_' || left(replace(program_id::text,'-',''), 16), 'Programa sintético 0007', true
from sitaa_0007_context;

create temporary table sitaa_0007_cases (
  label text primary key,
  id uuid not null unique,
  email text not null unique
) on commit drop;

create function pg_temp.case_id(target_label text)
returns uuid language sql stable set search_path = pg_temp as $$
  select id from sitaa_0007_cases where label = target_label
$$;
create function pg_temp.case_email(target_label text)
returns text language sql stable set search_path = pg_temp as $$
  select email from sitaa_0007_cases where label = target_label
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
revoke all on function pg_temp.set_request_user(text) from public, anon;
grant select on table pg_temp.sitaa_0007_cases, pg_temp.sitaa_0007_context to authenticated;
grant execute on function pg_temp.case_id(text), pg_temp.case_email(text), pg_temp.set_request_user(text) to authenticated;

create function pg_temp.create_case(
  target_label text,
  target_kind text,
  target_person text default null,
  target_status text default 'active'
)
returns uuid
language plpgsql
set search_path = public, auth, pg_temp, pg_catalog
as $$
declare
  target_id uuid := gen_random_uuid();
  target_email text := replace(target_label, '_', '-') || '-0007@example.invalid';
  target_program uuid := (select program_id from sitaa_0007_context limit 1);
  case_number integer := (select count(*) + 1 from sitaa_0007_cases);
  app_metadata jsonb;
begin
  if target_kind = 'technical' then
    app_metadata := jsonb_build_object('sitaa_account_kind','technical','sitaa_first_names','Soporte sintético');
  else
    app_metadata := jsonb_build_object('provider','google','providers',jsonb_build_array('google'));
  end if;
  insert into sitaa_0007_cases values (target_label, target_id, target_email);
  insert into auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values (
    target_id, 'authenticated', 'authenticated', target_email, '', now(),
    app_metadata, jsonb_build_object('name','Cuenta sintética'), now(), now()
  );

  if target_kind = 'technical' then
    update public.profiles set
      first_names = 'Soporte sintético', paternal_surname = null, maternal_surname = null,
      full_name = 'Soporte sintético', account_kind = 'technical',
      account_status = target_status, person_type = null, primary_program_id = null,
      institutional_id_type = null, institutional_id_value = null,
      is_active = (target_status = 'active'), activated_at = now(),
      deactivated_at = case when target_status = 'inactive' then now() else null end
    where id = target_id;
  else
    update public.profiles set
      first_names = case when target_label = 'target_account' then 'Búsqueda' else 'Persona' end,
      paternal_surname = case when target_label = 'target_account' then 'Árbol' else 'Sintética' end,
      maternal_surname = 'Prueba',
      full_name = case when target_label = 'target_account' then 'Búsqueda Árbol Prueba' else 'Persona Sintética Prueba' end,
      account_kind = 'institutional', account_status = target_status,
      person_type = target_person, primary_program_id = target_program,
      institutional_id_type = case when target_person = 'student' then 'student_account' else 'worker_number' end,
      institutional_id_value = case when target_label = 'target_account' then '123456789' else (700000000 + case_number)::text end,
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
select pg_temp.create_case('admin_inactive','technical',null,'inactive');
select pg_temp.create_case('target_account','institutional','student');
select pg_temp.create_case('same_row_target','institutional','professor');

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
  (pg_temp.case_id('admin_inactive'),'technical_admin','system','technical',null,null,current_date,null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('target_account'),'student','own','both',null,null,current_date,null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('same_row_target'),'professor','program','advising',null,(select program_id from sitaa_0007_context),current_date,null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('same_row_target'),'peer_tutor','own','tutoring',null,null,current_date,null,true,pg_temp.case_id('admin_exact'));

insert into public.admin_audit_events (
  actor_profile_id, target_profile_id, action_code, outcome, reason, metadata
) values (
  pg_temp.case_id('admin_exact'), pg_temp.case_id('target_account'),
  'synthetic_verification', 'success', 'Evento sintético transaccional',
  jsonb_build_object('context','0007 verifier')
);

-- Casos 2 a 5: toda identidad sin el contrato exacto recibe el mismo 42501.
create function pg_temp.expect_denied(target_label text)
returns void language plpgsql set search_path = public, pg_temp, pg_catalog as $$
declare denied boolean := false;
begin
  perform pg_temp.set_request_user(target_label);
  begin
    perform * from public.search_admin_accounts_b1('synthetic',null,null,null,null,null,null,null,1,20);
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception '0007: % obtuvo acceso administrativo.', target_label; end if;
end;
$$;
select pg_temp.expect_denied('ordinary_student');
select pg_temp.expect_denied('ordinary_professor');
select pg_temp.expect_denied('admin_bad_scope');
select pg_temp.expect_denied('admin_bad_service');
select pg_temp.expect_denied('admin_inactive');

-- Casos autorizados 1 y 6 a 15.
select pg_temp.set_request_user('admin_exact');
set local role authenticated;

do $authorized_cases$
declare
  target_id uuid := pg_temp.case_id('target_account');
  program_value uuid := (select program_id from pg_temp.sitaa_0007_context limit 1);
  result_count bigint;
  masked_value text;
  rejected boolean;
begin
  select count(*) into result_count from public.search_admin_accounts_b1('arbol',null,null,null,null,null,null,null,1,20);
  if result_count <> 1 then raise exception '0007: la búsqueda acento-insensible por nombre falló.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1('target-account-0007@example.invalid',null,null,null,null,null,null,null,1,20);
  if result_count <> 1 then raise exception '0007: la búsqueda por correo falló.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1('456789',null,null,null,null,null,null,null,1,20);
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
  begin perform * from public.search_admin_accounts_b1('ab',null,null,null,null,null,null,null,0,20);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: page_number inválido fue aceptado.'; end if;
  rejected := false;
  begin perform * from public.search_admin_accounts_b1('ab',null,null,null,null,null,null,null,1,51);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: page_size mayor a 50 fue aceptado.'; end if;

  select masked_institutional_id into masked_value
  from public.search_admin_accounts_b1('456789',null,null,null,null,null,null,null,1,20)
  where profile_id = target_id;
  if masked_value = '123456789' or right(masked_value,4) <> '6789' then
    raise exception '0007: el identificador de lista no está enmascarado.';
  end if;

  if not exists (
    select 1 from public.get_admin_account_detail_b1(target_id)
    where institutional_id_value = '123456789'
      and auth_email_confirmed is true
  ) then raise exception '0007: detalle completo o resumen Auth mínimo incorrecto.'; end if;

  if not exists (
    select 1 from public.get_admin_account_assignments_b1(target_id)
    where presentation_status = 'current'
  ) then raise exception '0007: clasificación V1 de asignación incorrecta.'; end if;

  if not exists (
    select 1 from public.get_admin_account_audit_history_b1(target_id,50,0)
    where action_code = 'synthetic_verification' and reason = 'Evento sintético transaccional'
  ) then raise exception '0007: historial sanitizado no devolvió el evento sintético.'; end if;
end;
$authorized_cases$;

-- Casos 16: sin acceso directo a la bitácora.
do $direct_table_denial$
declare denied boolean := false;
begin
  begin perform count(*) from public.admin_audit_events;
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception '0007: authenticated leyó directamente la bitácora.'; end if;
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
  begin
    insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values (pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'unsafe_metadata','failure','{"access_token":"prohibido"}'::jsonb);
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: metadata sensible fue aceptada.'; end if;

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
begin
  if to_regprocedure('public.publish_activity(uuid)') is null
     or to_regprocedure('public.add_activity_participant(uuid,uuid,text)') is null
     or to_regprocedure('public.update_activity_participant_attendance(uuid,text,text)') is null
     or to_regprocedure('public.open_activity_attendance_checkin(uuid)') is null
     or to_regprocedure('public.check_in_activity(text)') is null
     or to_regprocedure('public.complete_own_google_registration(text,text,text,text,text,uuid)') is null
     or to_regprocedure('public.normalize_sitaa_profile_names()') is null
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
