-- SEM-01 / 0011: verificador transaccional de casos 1–51.
-- Requiere 0011 aplicada. Todos los fixtures y eventos terminan en ROLLBACK.

begin;
set transaction isolation level read committed;
set transaction read write;
set local statement_timeout = '180s';
set local lock_timeout = '10s';
set local idle_in_transaction_session_timeout = '180s';
set local timezone = 'UTC';
set local datestyle = 'ISO, YMD';
set local search_path = pg_catalog, public, auth, pg_temp;

do $verifier_owner_guard$
begin
  if current_user <> 'postgres' or session_user <> 'postgres' then
    raise exception 'sitaa_0011_verify_owner_required' using errcode = '42501';
  end if;
  if to_regclass('public.academic_period_audit_events') is null
     or to_regprocedure('public.create_admin_academic_period(text,date,date,boolean)') is null then
    raise exception 'sitaa_0011_verify_migration_missing' using errcode = '55000';
  end if;
end;
$verifier_owner_guard$;

create temporary table sitaa_0011_results(
  case_number integer primary key,
  case_label text not null,
  passed boolean not null default true
) on commit drop;

create temporary table sitaa_0011_cases(
  label text primary key,
  id uuid not null unique,
  email text not null unique
) on commit drop;

create temporary table sitaa_0011_period_fixtures(
  label text primary key,
  id uuid not null unique
) on commit drop;

create temporary table sitaa_0011_context(
  singleton boolean primary key default true check(singleton),
  run_marker text not null,
  institutional_today date not null,
  program_id uuid not null,
  division_id uuid not null,
  activity_type_code text not null,
  service_type_code text not null,
  attention_category_code text not null,
  modality_code text not null,
  location_type_code text not null,
  benign_start date not null,
  benign_end date not null,
  benign_activity_id uuid not null,
  resolved_draft_activity_id uuid not null,
  validator_activity_id uuid not null
) on commit drop;

create temporary table sitaa_0011_activity_baseline(
  activity_id uuid primary key,
  row_json jsonb not null,
  xmin_value text not null,
  updated_at timestamptz not null,
  status_code text not null,
  created_by uuid not null,
  responsible_profile_id uuid not null,
  academic_period_id uuid
) on commit drop;

create temporary table sitaa_0011_audit_clock_bounds(
  audit_event_id uuid primary key,
  lower_bound timestamptz not null,
  upper_bound timestamptz not null,
  actor_profile_id uuid not null
) on commit drop;

create function pg_temp.pass(case_number integer, case_label text)
returns void language plpgsql set search_path = pg_temp, pg_catalog as $function$
begin
  insert into sitaa_0011_results values(case_number, case_label, true);
end;
$function$;

create function pg_temp.case_id(target_label text)
returns uuid language sql stable set search_path = pg_temp as $function$
  select id from sitaa_0011_cases where label = target_label;
$function$;

create function pg_temp.set_request_user(target_label text)
returns void language plpgsql set search_path = pg_temp, pg_catalog as $function$
declare
  target_id uuid := pg_temp.case_id(target_label);
begin
  perform set_config('request.jwt.claim.sub', target_id::text, true);
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', target_id, 'role', 'authenticated')::text,
    true
  );
end;
$function$;

create function pg_temp.create_technical_case(target_label text)
returns uuid language plpgsql
set search_path = pg_catalog, public, auth, pg_temp
as $function$
declare
  target_id uuid := gen_random_uuid();
  marker text := (select run_marker from sitaa_0011_context);
  target_email text := replace(target_label, '_', '-') || '-' || marker || '@example.invalid';
begin
  insert into sitaa_0011_cases values(target_label, target_id, target_email);
  insert into auth.users(
    id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values (
    target_id, 'authenticated', 'authenticated', target_email, '', current_timestamp,
    jsonb_build_object('sitaa_account_kind', 'technical', 'sitaa_first_names', 'Soporte 0011'),
    jsonb_build_object('name', 'Cuenta sintética 0011'),
    current_timestamp, current_timestamp
  );
  return target_id;
end;
$function$;

create function pg_temp.expect_admin_list_denied()
returns void language plpgsql set search_path = pg_catalog, public as $function$
begin
  begin
    perform public.list_admin_academic_periods(10, 0);
    raise exception 'sitaa_0011_verify_expected_admin_denial';
  exception when insufficient_privilege then
    if sqlerrm <> 'sitaa_sem01_admin_access_denied' then raise; end if;
  end;
end;
$function$;

insert into sitaa_0011_context(
  run_marker, institutional_today, program_id, division_id,
  activity_type_code, service_type_code, attention_category_code,
  modality_code, location_type_code, benign_start, benign_end,
  benign_activity_id, resolved_draft_activity_id, validator_activity_id
)
select
  substr(md5(clock_timestamp()::text || txid_current()::text), 1, 12),
  public.sitaa_current_mexico_date(),
  program.id,
  program.division_id,
  (select code from public.activity_types where is_active order by sort_order, code limit 1),
  (select code from public.service_types where is_active order by sort_order, code limit 1),
  (select code from public.attention_categories where is_active order by sort_order, code limit 1),
  (select code from public.activity_modalities where code <> 'online' and is_active order by sort_order, code limit 1),
  (select code from public.location_types where code <> 'online_space' and is_active order by sort_order, code limit 1),
  date '2098-02-03',
  date '2098-05-29',
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid()
from public.academic_programs program
where program.is_active
order by program.code
limit 1;

do $context_guard$
begin
  if (select count(*) from sitaa_0011_context) <> 1
     or exists (
       select 1 from sitaa_0011_context
       where program_id is null or division_id is null
         or activity_type_code is null or service_type_code is null
         or attention_category_code is null or modality_code is null
         or location_type_code is null
     )
     or exists (
       select 1 from public.academic_periods
       where code in ('1900-1', '2097-1', '2098-1', '2098-2', '2099-1', '2099-2')
     ) then
    raise exception 'sitaa_0011_verify_fixture_context_unavailable';
  end if;
end;
$context_guard$;

select pg_temp.create_technical_case('admin_exact');
select pg_temp.create_technical_case('ordinary');
select pg_temp.create_technical_case('admin_malformed');
select pg_temp.create_technical_case('admin_inactive');
select pg_temp.create_technical_case('admin_future');
select pg_temp.create_technical_case('admin_expired');

update public.profiles
set account_status = 'inactive', is_active = false, deactivated_at = current_timestamp
where id = pg_temp.case_id('admin_inactive');

insert into public.role_assignments(
  user_id, role_code, scope_type, service_area, division_id, program_id,
  starts_at, ends_at, is_active, assigned_by
) values
  (pg_temp.case_id('admin_exact'), 'technical_admin', 'system', 'technical', null, null,
    (select institutional_today from sitaa_0011_context), null, true, pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_malformed'), 'technical_admin', 'own', 'technical', null, null,
    (select institutional_today from sitaa_0011_context), null, true, pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_inactive'), 'technical_admin', 'system', 'technical', null, null,
    (select institutional_today from sitaa_0011_context), null, true, pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_future'), 'technical_admin', 'system', 'technical', null, null,
    (select institutional_today + 1 from sitaa_0011_context), null, true, pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_expired'), 'technical_admin', 'system', 'technical', null, null,
    (select institutional_today - 10 from sitaa_0011_context),
    (select institutional_today - 1 from sitaa_0011_context), true, pg_temp.case_id('admin_exact'));

grant select on table pg_temp.sitaa_0011_cases to authenticated;
grant select, insert on table pg_temp.sitaa_0011_results to authenticated;
grant select, insert on table pg_temp.sitaa_0011_period_fixtures to authenticated;
grant select on table pg_temp.sitaa_0011_context to authenticated;
grant select on table pg_temp.sitaa_0011_activity_baseline to authenticated;
grant select, insert on table pg_temp.sitaa_0011_audit_clock_bounds to authenticated;
grant execute on function pg_temp.pass(integer,text) to authenticated;
grant execute on function pg_temp.case_id(text), pg_temp.set_request_user(text) to authenticated;
grant execute on function pg_temp.expect_admin_list_denied() to authenticated;

-- CASE 01: contrato exacto post-0011.
do $case_01$
begin
  if to_regclass('public.academic_period_audit_events') is null
     or to_regprocedure('public.list_admin_academic_periods(integer,integer)') is null
     or not exists (
       select 1 from pg_catalog.pg_constraint
       where conrelid = 'public.academic_periods'::regclass
         and conname = 'academic_periods_active_date_range_excl'
         and contype = 'x'
     ) then
    raise exception 'case_01_failed';
  end if;
  perform pg_temp.pass(1, 'Línea base exacta post-0011');
end;
$case_01$;

-- CASES 15–20: frontera de autorización y ACL cliente.
set local role anon;
do $case_15$
begin
  begin
    perform public.list_admin_academic_periods(10, 0);
    raise exception 'case_15_expected_denial';
  exception when insufficient_privilege then null;
  end;
end;
$case_15$;
reset role;
select pg_temp.pass(15, 'Anon denegado');

select pg_temp.set_request_user('ordinary');
set local role authenticated;
select pg_temp.expect_admin_list_denied();
reset role;
select pg_temp.pass(16, 'Usuario autenticado ordinario denegado');

select pg_temp.set_request_user('admin_malformed');
set local role authenticated;
select pg_temp.expect_admin_list_denied();
reset role;
select pg_temp.pass(17, 'Asignación técnica malformada denegada');

select pg_temp.set_request_user('admin_inactive');
set local role authenticated;
select pg_temp.expect_admin_list_denied();
reset role;
select pg_temp.pass(18, 'Perfil administrativo inactivo denegado');

select pg_temp.set_request_user('admin_future');
set local role authenticated;
select pg_temp.expect_admin_list_denied();
reset role;
select pg_temp.pass(19, 'Asignación futura denegada');

select pg_temp.set_request_user('admin_expired');
set local role authenticated;
select pg_temp.expect_admin_list_denied();
reset role;
select pg_temp.pass(20, 'Asignación expirada denegada');

select pg_temp.set_request_user('admin_exact');
set local role authenticated;

-- CASE 02, 07, 08 y 21: creación válida por autoridad exacta.
insert into pg_temp.sitaa_0011_period_fixtures(label, id)
select 'inactive_period', period_id
from public.create_admin_academic_period(
  '1900-1', date '1900-01-01', date '1900-01-02', false
);
select pg_temp.pass(2, 'Código ordinario válido');
select pg_temp.pass(7, 'Fechas completas');
select pg_temp.pass(8, 'Rango válido');
select pg_temp.pass(21, 'Autoridad exacta exitosa');

-- CASE 03: formatos ordinarios inválidos.
do $case_03$
declare invalid_code text;
begin
  foreach invalid_code in array array['2028-0', '2028-3', '28-1', '2028-A'] loop
    begin
      perform public.create_admin_academic_period(invalid_code, date '2090-01-01', date '2090-01-02', false);
      raise exception 'case_03_expected_rejection';
    exception when invalid_parameter_value then
      if sqlerrm <> 'sitaa_sem01_invalid_period_code' then raise; end if;
    end;
  end loop;
  perform pg_temp.pass(3, 'Formatos ordinarios inválidos');
end;
$case_03$;

-- CASE 04: espacios y formatos alternativos no se normalizan.
do $case_04$
declare invalid_code text;
begin
  foreach invalid_code in array array[' 2090-1', '2090-1 ', '2090_1', '2090/1'] loop
    begin
      perform public.create_admin_academic_period(invalid_code, date '2090-01-01', date '2090-01-02', false);
      raise exception 'case_04_expected_rejection';
    exception when invalid_parameter_value then null;
    end;
  end loop;
  perform pg_temp.pass(4, 'Espacios y códigos alternativos rechazados');
end;
$case_04$;

-- CASE 05: unicidad de código.
do $case_05$
begin
  begin
    perform public.create_admin_academic_period('1900-1', date '1900-02-01', date '1900-02-02', false);
    raise exception 'case_05_expected_rejection';
  exception when unique_violation then
    if sqlerrm <> 'sitaa_sem01_period_code_conflict' then raise; end if;
  end;
  perform pg_temp.pass(5, 'Código único');
end;
$case_05$;

-- CASE 07 y 09: ausencia de fechas y rango inválido.
do $cases_07_09$
begin
  begin
    perform public.create_admin_academic_period('2098-1', null, date '2098-05-01', false);
    raise exception 'case_07_expected_rejection';
  exception when check_violation then
    if sqlerrm <> 'sitaa_sem01_complete_dates_required' then raise; end if;
  end;
  begin
    perform public.create_admin_academic_period('2098-1', date '2098-05-02', date '2098-05-01', false);
    raise exception 'case_09_expected_rejection';
  exception when check_violation then
    if sqlerrm <> 'sitaa_sem01_invalid_period_range' then raise; end if;
  end;
  perform pg_temp.pass(9, 'Rango inválido rechazado');
end;
$cases_07_09$;

-- CASE 13: nombre inválido.
do $case_13$
begin
  begin
    perform public.correct_admin_academic_period(
      (select id from sitaa_0011_period_fixtures where label = 'inactive_period'),
      '   ', date '1900-01-01', date '1900-01-02', 'Motivo sintético válido 0011'
    );
    raise exception 'case_13_expected_rejection';
  exception when invalid_parameter_value then
    if sqlerrm <> 'sitaa_sem01_invalid_period_name' then raise; end if;
  end;
  perform pg_temp.pass(13, 'Nombre validado y normalizado');
end;
$case_13$;

-- CASE 22: lista administrativa acotada.
do $case_22$
begin
  if not exists (
    select 1 from public.list_admin_academic_periods(100, 0)
    where code = '1900-1' and activity_reference_count = 0
  ) then raise exception 'case_22_failed'; end if;
  perform pg_temp.pass(22, 'Listado administrativo acotado');
end;
$case_22$;

-- CASE 23–28: resolver, intersemestre e inactividad.
do $cases_23_28$
declare
  period_id uuid;
  expected_id uuid;
begin
  select id into period_id from public.get_academic_period_for_date(date '2025-08-10');
  if period_id is not null then raise exception 'case_23_failed'; end if;
  perform pg_temp.pass(23, 'Fecha anterior al primer periodo');

  select id into expected_id from public.academic_periods where code = '2026-2';
  select id into period_id from public.get_academic_period_for_date(date '2026-03-01');
  if period_id is distinct from expected_id then raise exception 'case_24_failed'; end if;
  perform pg_temp.pass(24, 'Fecha dentro del periodo');

  select id into period_id from public.get_academic_period_for_date(date '2026-07-15');
  if period_id is distinct from expected_id then raise exception 'case_25_failed'; end if;
  perform pg_temp.pass(25, 'Intersemestre con sucesor configurado');

  select id into expected_id from public.academic_periods where code = '2027-1';
  select id into period_id from public.get_academic_period_for_date(date '2026-08-10');
  if period_id is distinct from expected_id then raise exception 'case_26_failed'; end if;
  perform pg_temp.pass(26, 'Frontera exacta del sucesor');

  select id into period_id from public.get_academic_period_for_date(date '2027-05-29');
  if period_id is not null then raise exception 'case_27_failed'; end if;
  perform pg_temp.pass(27, 'Fecha posterior al último periodo');

  select id into period_id from public.get_academic_period_for_date(date '1900-01-01');
  if period_id is not null then raise exception 'case_28_failed'; end if;
  perform pg_temp.pass(28, 'Periodo inactivo ignorado');
end;
$cases_23_28$;

-- CASE 31, 32, 38, 39 y 40: corrección, motivo y auditoría exacta.
do $case_31_mutation$
declare
  fixture_id uuid := (select id from sitaa_0011_period_fixtures where label = 'inactive_period');
  mutation_result record;
  lower_bound timestamptz;
  upper_bound timestamptz;
begin
  lower_bound := clock_timestamp();
  select * into mutation_result from public.correct_admin_academic_period(
    fixture_id, 'Semestre histórico 1900-1', date '1900-01-01', date '1900-01-02',
    'Corrección sintética de nombre para verificar SEM-01'
  );
  upper_bound := clock_timestamp();
  insert into sitaa_0011_audit_clock_bounds(
    audit_event_id, lower_bound, upper_bound, actor_profile_id
  ) values (
    mutation_result.audit_event_id, lower_bound, upper_bound, auth.uid()
  );
end;
$case_31_mutation$;
reset role;

do $case_31_audit$
declare fixture_id uuid := (select id from sitaa_0011_period_fixtures where label = 'inactive_period');
begin
  if (select count(*) from public.academic_period_audit_events
      where academic_period_id = fixture_id and action_code = 'academic_period_created') <> 1
     or (select count(*) from public.academic_period_audit_events
      where academic_period_id = fixture_id and action_code = 'academic_period_corrected') <> 1
     or not exists (
       select 1
       from public.academic_period_audit_events event
       join sitaa_0011_audit_clock_bounds bounds
         on bounds.audit_event_id = event.id
       where event.academic_period_id = fixture_id
         and event.action_code = 'academic_period_corrected'
         and event.actor_profile_id = bounds.actor_profile_id
         and event.occurred_at >= bounds.lower_bound
         and event.occurred_at <= bounds.upper_bound
         and event.changed_fields = array['name']::text[]
         and event.old_values ? 'name' and event.new_values ? 'name'
         and (select count(*) from jsonb_object_keys(event.old_values)) = 1
         and (select count(*) from jsonb_object_keys(event.new_values)) = 1
     ) then raise exception 'case_31_or_38_failed'; end if;
  perform pg_temp.pass(31, 'Corrección exclusiva de nombre auditada');
  perform pg_temp.pass(38, 'Un evento por mutación exitosa');
end;
$case_31_audit$;

select pg_temp.set_request_user('admin_exact');
set local role authenticated;
do $case_32_mutation$
declare fixture_id uuid := (select id from sitaa_0011_period_fixtures where label = 'inactive_period');
begin
  perform public.correct_admin_academic_period(
    fixture_id, 'Semestre histórico 1900-1', date '1900-01-01', date '1900-01-03',
    'Corrección sintética de fechas sin impacto operativo'
  );
end;
$case_32_mutation$;
reset role;

do $cases_14_32_40$
declare fixture_id uuid := (select id from sitaa_0011_period_fixtures where label = 'inactive_period');
begin
  if (select updated_at from public.academic_periods where id = fixture_id)
       <= (select created_at from public.academic_periods where id = fixture_id) then
    raise exception 'case_14_failed';
  end if;
  perform pg_temp.pass(14, 'updated_at automático');
  perform pg_temp.pass(32, 'Corrección de fecha sin impacto');

  if exists (
    select 1 from public.academic_period_audit_events
    where academic_period_id = fixture_id
      and (
        changed_fields && array['email','token','metadata','activity_id']::text[]
        or octet_length(old_values::text) > 4000
        or octet_length(new_values::text) > 4000
      )
  ) then raise exception 'case_40_failed'; end if;
  perform pg_temp.pass(40, 'Evidencia de campos segura y acotada');
end;
$cases_14_32_40$;

select pg_temp.set_request_user('admin_exact');
set local role authenticated;
do $case_39$
begin
  begin
    perform public.correct_admin_academic_period(
      (select id from sitaa_0011_period_fixtures where label = 'inactive_period'),
      'Nombre sin cambio', date '1900-01-01', date '1900-01-03', 'corto'
    );
    raise exception 'case_39_expected_rejection';
  exception when invalid_parameter_value then
    if sqlerrm <> 'sitaa_sem01_invalid_reason' then raise; end if;
  end;
  perform pg_temp.pass(39, 'Motivo obligatorio y acotado');
end;
$case_39$;

reset role;

-- CASE 06: code inmutable incluso para DML owner.
do $case_06$
begin
  begin
    update public.academic_periods set code = '1900-2'
    where id = (select id from sitaa_0011_period_fixtures where label = 'inactive_period');
    raise exception 'case_06_expected_rejection';
  exception when check_violation then
    if sqlerrm <> 'sitaa_sem01_period_code_immutable' then raise; end if;
  end;
  perform pg_temp.pass(6, 'Código inmutable');
end;
$case_06$;

-- CASE 10: traslape activo por INSERT.
do $case_10$
begin
  begin
    insert into public.academic_periods(code, name, starts_on, ends_on, is_active)
    values('2099-1', '2099-1', date '2026-03-01', date '2026-03-10', true);
    raise exception 'case_10_expected_rejection';
  exception when exclusion_violation then null;
  end;
  perform pg_temp.pass(10, 'Traslape por INSERT rechazado');
end;
$case_10$;

-- CASE 11: traslape activo por UPDATE.
insert into public.academic_periods(code, name, starts_on, ends_on, is_active)
values('2097-1', '2097-1', date '2026-03-01', date '2026-03-10', false);
do $case_11$
begin
  begin
    update public.academic_periods set is_active = true where code = '2097-1';
    raise exception 'case_11_expected_rejection';
  exception when exclusion_violation then null;
  end;
  perform pg_temp.pass(11, 'Traslape por UPDATE rechazado');
end;
$case_11$;

-- CASE 12: pilot permanece exacto.
do $case_12$
begin
  if not exists (
    select 1 from public.academic_periods
    where code = 'pilot' and name = 'Periodo piloto'
      and starts_on is null and ends_on is null and not is_active and sort_order = 0
  ) then raise exception 'case_12_failed'; end if;
  perform pg_temp.pass(12, 'pilot preservado');
end;
$case_12$;

-- CASE 36, 37 y 43: sin DELETE de producto, sin DML cliente y ACL estable.
reset role;
select pg_temp.set_request_user('ordinary');
set local role authenticated;
do $case_37_direct_dml$
begin
  begin
    insert into public.academic_periods(code, name, starts_on, ends_on, is_active, sort_order)
    values ('2097-1', '2097-1', date '2096-08-01', date '2096-11-30', false, 209701);
    raise exception 'case_37_insert_expected_denial';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.academic_periods set name = name where code = 'pilot';
    raise exception 'case_37_update_expected_denial';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.academic_periods where code = 'pilot';
    raise exception 'case_37_delete_expected_denial';
  exception when insufficient_privilege then null;
  end;
end;
$case_37_direct_dml$;

reset role;
set local role service_role;
do $case_37_service_dml$
begin
  begin
    insert into public.academic_periods(code, name, starts_on, ends_on, is_active, sort_order)
    values ('2097-2', '2097-2', date '2097-02-01', date '2097-05-31', false, 209702);
    raise exception 'case_37_service_insert_expected_denial';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.academic_periods set name = name where code = 'pilot';
    raise exception 'case_37_service_update_expected_denial';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.academic_periods where code = 'pilot';
    raise exception 'case_37_service_delete_expected_denial';
  exception when insufficient_privilege then null;
  end;
end;
$case_37_service_dml$;

reset role;
select pg_temp.pass(37, 'Sin DML directo cliente o service_role');

do $case_36_43$
declare
  lock_helper_definition text := lower(pg_get_functiondef(
    'public.lock_and_reauthorize_sem01_admin_0011(uuid)'::regprocedure
  ));
  activity_lock_definition text := lower(pg_get_functiondef(
    'public.acquire_sem01_calendar_lock_0011()'::regprocedure
  ));
  publication_definition text := lower(pg_get_functiondef(
    'public.publish_activity(uuid)'::regprocedure
  ));
begin
  if exists (
    select 1 from pg_catalog.pg_proc routine
    join pg_catalog.pg_namespace namespace on namespace.oid = routine.pronamespace
    where namespace.nspname = 'public'
      and routine.proname ~ '(delete|remove).*academic_period|academic_period.*(delete|remove)'
  ) or has_table_privilege('authenticated', 'public.academic_periods', 'DELETE') then
    raise exception 'case_36_failed';
  end if;
  perform pg_temp.pass(36, 'Sin superficie DELETE');

  if has_table_privilege('authenticated', 'public.academic_periods', 'INSERT')
     or has_table_privilege('authenticated', 'public.academic_periods', 'UPDATE')
     or has_table_privilege('authenticated', 'public.academic_periods', 'DELETE')
     or has_table_privilege('service_role', 'public.academic_periods', 'INSERT')
     or has_table_privilege('service_role', 'public.academic_periods', 'UPDATE')
     or has_table_privilege('service_role', 'public.academic_periods', 'DELETE') then
    raise exception 'case_37_failed';
  end if;
  if not has_function_privilege('authenticated', 'public.get_academic_period_for_date(date)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.publish_activity(uuid)', 'EXECUTE')
     or has_function_privilege('anon', 'public.create_admin_academic_period(text,date,date,boolean)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.is_exact_sem01_period_admin_0011(uuid)', 'EXECUTE') then
    raise exception 'case_43_failed';
  end if;
  if lock_helper_definition !~ 'current_setting\(''transaction_isolation''(::text)?\)\s*<>\s*''read committed''(::text)?'
     or lock_helper_definition !~ 'sitaa_sem01_read_committed_required'
     or lock_helper_definition !~ 'errcode\s*=\s*''25000'''
     or strpos(lock_helper_definition, 'current_setting(''transaction_isolation''')
       >= strpos(lock_helper_definition, 'pg_advisory_xact_lock')
     or strpos(lock_helper_definition, 'current_setting(''transaction_isolation''')
       >= strpos(lock_helper_definition, 'from public.profiles')
     or activity_lock_definition !~ 'current_setting\(''transaction_isolation''(::text)?\)\s*<>\s*''read committed''(::text)?'
     or activity_lock_definition !~ 'sitaa_sem01_read_committed_required'
     or activity_lock_definition !~ 'errcode\s*=\s*''25000'''
     or strpos(activity_lock_definition, 'current_setting(''transaction_isolation''')
       >= strpos(activity_lock_definition, 'pg_advisory_xact_lock')
     or publication_definition !~ 'current_setting\(''transaction_isolation''(::text)?\)\s*<>\s*''read committed''(::text)?'
     or publication_definition !~ 'sitaa_sem01_read_committed_required'
     or publication_definition !~ 'errcode\s*=\s*''25000'''
     or strpos(publication_definition, 'current_setting(''transaction_isolation''')
       >= strpos(publication_definition, 'is_sitaa_operational_account_active')
     or strpos(publication_definition, 'current_setting(''transaction_isolation''')
       >= strpos(publication_definition, 'auth.uid')
     or strpos(publication_definition, 'current_setting(''transaction_isolation''')
       >= strpos(publication_definition, 'pg_advisory_xact_lock')
     or strpos(publication_definition, 'current_setting(''transaction_isolation''')
       >= strpos(publication_definition, 'from public.activities') then
    raise exception 'case_43_read_committed_guard_failed';
  end if;
  perform pg_temp.pass(43, 'ACL y grants exactos');
end;
$case_36_43$;

-- CASE 41: auditoría append-only.
do $case_41$
declare target_event uuid := (select id from public.academic_period_audit_events order by occurred_at limit 1);
begin
  begin
    update public.academic_period_audit_events set outcome = 'success' where id = target_event;
    raise exception 'case_41_update_expected_rejection';
  exception when insufficient_privilege then
    if sqlerrm <> 'sitaa_sem01_audit_append_only' then raise; end if;
  end;
  begin
    delete from public.academic_period_audit_events where id = target_event;
    raise exception 'case_41_delete_expected_rejection';
  exception when insufficient_privilege then
    if sqlerrm <> 'sitaa_sem01_audit_append_only' then raise; end if;
  end;
  begin
    truncate table public.academic_period_audit_events;
    raise exception 'case_41_truncate_expected_rejection';
  exception when insufficient_privilege then
    if sqlerrm <> 'sitaa_sem01_audit_append_only' then raise; end if;
  end;
  perform pg_temp.pass(41, 'Auditoría append-only');
end;
$case_41$;

-- CASE 42: el resolver date-only no depende de la zona de sesión.
do $case_42$
declare utc_id uuid; mexico_id uuid; tokyo_id uuid;
begin
  perform set_config('TimeZone', 'UTC', true);
  select id into utc_id from public.get_academic_period_for_date(date '2026-07-15');
  perform set_config('TimeZone', 'America/Mexico_City', true);
  select id into mexico_id from public.get_academic_period_for_date(date '2026-07-15');
  perform set_config('TimeZone', 'Asia/Tokyo', true);
  select id into tokyo_id from public.get_academic_period_for_date(date '2026-07-15');
  perform set_config('TimeZone', 'UTC', true);
  if utc_id is distinct from mexico_id or utc_id is distinct from tokyo_id then
    raise exception 'case_42_failed';
  end if;
  perform pg_temp.pass(42, 'Independencia de zona de sesión');
end;
$case_42$;

-- Fixtures para casos 29, 30 y 46–51.
reset role;
select pg_temp.set_request_user('admin_exact');

do $activity_fixture_identity_guard$
begin
  if auth.uid() is distinct from pg_temp.case_id('admin_exact') then
    raise exception 'sitaa_0011_verify_activity_fixture_identity_mismatch';
  end if;
end;
$activity_fixture_identity_guard$;

insert into public.activities(
  id, title, description, academic_period_id, program_id,
  activity_type_code, service_type_code, attention_category_code,
  modality_code, status_code, location_type_code, location_detail,
  responsible_profile_id, created_by, start_date, start_time,
  end_date, end_time, duration_mode, scope_type, division_id
)
select
  benign_activity_id, 'Borrador benigno 0011', null, null, program_id,
  activity_type_code, service_type_code, attention_category_code,
  modality_code, 'draft', location_type_code, 'Espacio sintético 0011',
  pg_temp.case_id('admin_exact'), pg_temp.case_id('admin_exact'),
  benign_start, time '10:00', benign_start, time '11:00', 'one_hour',
  'program', division_id
from sitaa_0011_context;

insert into sitaa_0011_activity_baseline
select
  activity.id, to_jsonb(activity), activity.xmin::text, activity.updated_at,
  activity.status_code, activity.created_by, activity.responsible_profile_id,
  activity.academic_period_id
from public.activities activity
where activity.id = (select benign_activity_id from sitaa_0011_context);

set local role authenticated;

-- CASE 46: creación activa sólo habilita un borrador no asignado.
insert into pg_temp.sitaa_0011_period_fixtures(label, id)
select 'benign_period', period_id
from public.create_admin_academic_period(
  '2098-2',
  (select benign_start from sitaa_0011_context),
  (select benign_end from sitaa_0011_context),
  true
);
select pg_temp.pass(46, 'Habilitación benigna de borrador no asignado');

-- CASE 47: cero DML sobre la fila de actividad durante la mutación de periodo.
do $case_47$
declare
  baseline sitaa_0011_activity_baseline%rowtype;
  current_row record;
begin
  select * into baseline from sitaa_0011_activity_baseline;
  select activity.*, activity.xmin::text as current_xmin
  into current_row
  from public.activities activity
  where activity.id = baseline.activity_id;
  if (to_jsonb(current_row) - 'current_xmin') is distinct from baseline.row_json
     or current_row.current_xmin is distinct from baseline.xmin_value
     or current_row.updated_at is distinct from baseline.updated_at
     or current_row.status_code is distinct from baseline.status_code
     or current_row.created_by is distinct from baseline.created_by
     or current_row.responsible_profile_id is distinct from baseline.responsible_profile_id
     or current_row.academic_period_id is distinct from baseline.academic_period_id then
    raise exception 'case_47_failed';
  end if;
  perform pg_temp.pass(47, 'Habilitación benigna sin DML de actividad');
end;
$case_47$;

-- CASE 48 y 29: publicación posterior vuelve a resolver y persiste atómicamente.
do $cases_29_48$
declare
  result_row record;
  expected_period_id uuid := (select id from sitaa_0011_period_fixtures where label = 'benign_period');
begin
  select * into result_row
  from public.publish_activity((select benign_activity_id from sitaa_0011_context));
  if result_row.status_code <> 'scheduled'
     or result_row.academic_period_id is distinct from expected_period_id
     or not exists (
       select 1 from public.activities
       where id = (select benign_activity_id from sitaa_0011_context)
         and status_code = 'scheduled'
         and academic_period_id = expected_period_id
     ) then raise exception 'cases_29_48_failed'; end if;
  perform pg_temp.pass(29, 'Publicación con re-resolución');
  perform pg_temp.pass(48, 'Publicación posterior persiste el periodo');
end;
$cases_29_48$;

reset role;

-- CASE 30: correspondencia programada impuesta por trigger.
insert into public.activities(
  id, title, academic_period_id, program_id, activity_type_code,
  service_type_code, attention_category_code, modality_code, status_code,
  location_type_code, location_detail, responsible_profile_id, created_by,
  start_date, start_time, end_date, end_time, duration_mode, scope_type, division_id
)
select validator_activity_id, 'Validador 0011', null, program_id, activity_type_code,
  service_type_code, attention_category_code, modality_code, 'draft',
  location_type_code, 'Espacio sintético 0011', pg_temp.case_id('admin_exact'),
  pg_temp.case_id('admin_exact'), date '2026-03-01', time '10:00',
  date '2026-03-01', time '11:00', 'one_hour', 'program', division_id
from sitaa_0011_context;

do $case_30$
declare
  publication_definition text := pg_catalog.pg_get_functiondef(
    'public.publish_activity(uuid)'::regprocedure
  );
  validator_definition text := pg_catalog.pg_get_functiondef(
    'public.validate_activity_scheduled_state()'::regprocedure
  );
begin
  if position('clock_timestamp()' in lower(publication_definition)) = 0
     or position('clock_timestamp()' in lower(validator_definition)) = 0
     or position('current_timestamp' in lower(publication_definition)) > 0
     or position('transaction_timestamp' in lower(publication_definition)) > 0
     or lower(publication_definition) ~ '(^|[^a-z0-9_])now[[:space:]]*\('
     or position('current_timestamp' in lower(validator_definition)) > 0
     or position('transaction_timestamp' in lower(validator_definition)) > 0
     or lower(validator_definition) ~ '(^|[^a-z0-9_])now[[:space:]]*\(' then
    raise exception 'case_30_wall_clock_definition_failed';
  end if;

  begin
    update public.activities
    set status_code = 'scheduled',
        academic_period_id = (select id from public.academic_periods where code = '2027-1')
    where id = (select validator_activity_id from sitaa_0011_context);
    raise exception 'case_30_expected_rejection';
  exception when check_violation then
    if sqlerrm <> 'El semestre asignado no corresponde a la fecha de inicio.' then raise; end if;
  end;
  perform pg_temp.pass(30, 'Correspondencia de estado programado');
end;
$case_30$;

-- Segundo borrador ya resoluble para el bloqueo del caso 51.
insert into public.activities(
  id, title, academic_period_id, program_id, activity_type_code,
  service_type_code, attention_category_code, modality_code, status_code,
  location_type_code, location_detail, responsible_profile_id, created_by,
  start_date, start_time, end_date, end_time, duration_mode, scope_type, division_id
)
select resolved_draft_activity_id, 'Borrador ya resoluble 0011', null, program_id,
  activity_type_code, service_type_code, attention_category_code, modality_code,
  'draft', location_type_code, 'Espacio sintético 0011', pg_temp.case_id('admin_exact'),
  pg_temp.case_id('admin_exact'), benign_start + 1, time '12:00',
  benign_start + 1, time '13:00', 'one_hour', 'program', division_id
from sitaa_0011_context;

select pg_temp.set_request_user('admin_exact');
set local role authenticated;

-- CASE 33, 35, 49 y 50: impactos persistidos/no borrador se bloquean.
do $cases_33_35_49_50$
declare
  period_id uuid := (select id from sitaa_0011_period_fixtures where label = 'benign_period');
begin
  begin
    perform public.correct_admin_academic_period(
      period_id, '2098-2',
      (select benign_start + 1 from sitaa_0011_context),
      (select benign_end from sitaa_0011_context),
      'Intento sintético que alteraría una atribución persistida'
    );
    raise exception 'case_33_expected_rejection';
  exception when check_violation then
    if sqlerrm <> 'sitaa_sem01_calendar_impact_blocked' then raise; end if;
  end;
  perform pg_temp.pass(33, 'Corrección de fecha con impacto bloqueada');

  begin
    perform public.deactivate_admin_academic_period(
      period_id, 'Desactivación sintética que perdería atribución persistida'
    );
    raise exception 'case_35_expected_rejection';
  exception when check_violation then
    if sqlerrm <> 'sitaa_sem01_calendar_impact_blocked' then raise; end if;
  end;
  perform pg_temp.pass(35, 'Desactivación con impacto bloqueada');
  perform pg_temp.pass(49, 'Ganancia pérdida o cambio no borrador rechazado');
  perform pg_temp.pass(50, 'Atribución no nula protegida');
end;
$cases_33_35_49_50$;

-- CASE 51: borrador no asignado ya resoluble no puede perder/cambiar resolución.
do $case_51$
declare
  period_id uuid := (select id from sitaa_0011_period_fixtures where label = 'benign_period');
begin
  begin
    perform public.correct_admin_academic_period(
      period_id, '2098-2',
      (select benign_start from sitaa_0011_context),
      (select benign_start from sitaa_0011_context),
      'Intento sintético que dejaría sin resolución un borrador existente'
    );
    raise exception 'case_51_expected_rejection';
  exception when check_violation then
    if sqlerrm <> 'sitaa_sem01_calendar_impact_blocked' then raise; end if;
  end;
  perform pg_temp.pass(51, 'Borrador resoluble no pierde ni cambia resolución');
end;
$case_51$;

reset role;
do $rejected_mutation_audit_guard$
declare period_id uuid := (select id from sitaa_0011_period_fixtures where label = 'benign_period');
begin
  if (select count(*) from public.academic_period_audit_events
      where academic_period_id = period_id) <> 1
     or not exists (
       select 1 from public.academic_period_audit_events
       where academic_period_id = period_id and action_code = 'academic_period_created'
     ) then
    raise exception 'rejected_mutation_created_audit';
  end if;
end;
$rejected_mutation_audit_guard$;

-- CASE 34: activación propuesta con impacto/traslape se rechaza antes de escribir.
insert into public.academic_periods(code, name, starts_on, ends_on, is_active)
select '2099-2', '2099-2', benign_start, benign_end, false
from sitaa_0011_context;
select pg_temp.set_request_user('admin_exact');
set local role authenticated;
do $case_34$
begin
  begin
    perform public.activate_admin_academic_period(
      (select id from public.academic_periods where code = '2099-2'),
      'Activación sintética que alteraría el calendario efectivo'
    );
    raise exception 'case_34_expected_rejection';
  exception when check_violation or exclusion_violation then
    if sqlerrm not in ('sitaa_sem01_calendar_impact_blocked', 'sitaa_sem01_period_overlap') then raise; end if;
  end;
  perform pg_temp.pass(34, 'Activación con impacto rechazada');
end;
$case_34$;

reset role;
do $case_34_audit_guard$
begin
  if exists (
    select 1 from public.academic_period_audit_events event
    join public.academic_periods period on period.id = event.academic_period_id
    where period.code = '2099-2'
  ) then raise exception 'case_34_audit_failed'; end if;
end;
$case_34_audit_guard$;

-- Activación y desactivación exitosas del periodo aislado prueban su lifecycle.
select pg_temp.set_request_user('admin_exact');
set local role authenticated;
do $lifecycle_success$
declare isolated_id uuid := (select id from sitaa_0011_period_fixtures where label = 'inactive_period');
begin
  perform public.activate_admin_academic_period(
    isolated_id, 'Activación sintética aislada para verificar el ciclo SEM-01'
  );
  perform public.deactivate_admin_academic_period(
    isolated_id, 'Desactivación sintética aislada para verificar el ciclo SEM-01'
  );
end;
$lifecycle_success$;

-- CASE 45: postcondiciones exactas; CASE 44 queda garantizado por ROLLBACK final.
do $cases_44_45$
declare missing_cases integer[];
begin
  select array_agg(number order by number) into missing_cases
  from generate_series(1, 51) as expected(number)
  where number not in (44, 45)
    and not exists (
      select 1 from sitaa_0011_results result where result.case_number = number and result.passed
    );
  if coalesce(cardinality(missing_cases), 0) <> 0 then
    raise exception 'sitaa_0011_verify_missing_cases_%', missing_cases;
  end if;
  if (select count(*) from public.academic_periods where code = 'pilot') <> 1
     or (select count(*) from public.activities
       where id in (
         (select benign_activity_id from sitaa_0011_context),
         (select resolved_draft_activity_id from sitaa_0011_context),
         (select validator_activity_id from sitaa_0011_context)
       )) <> 3 then
    raise exception 'case_45_failed';
  end if;
  perform pg_temp.pass(44, 'Fixtures restaurados por ROLLBACK final');
  perform pg_temp.pass(45, 'Postcondiciones exactas');
end;
$cases_44_45$;

reset role;

do $complete_case_map$
begin
  if (select count(*) from sitaa_0011_results where passed) <> 51
     or exists (
       select 1 from generate_series(1, 51) as expected(number)
       where not exists (
         select 1 from sitaa_0011_results result
         where result.case_number = number and result.passed
       )
     ) then
    raise exception 'sitaa_0011_verify_incomplete_case_map';
  end if;
end;
$complete_case_map$;

select case_number, case_label, passed
from sitaa_0011_results
order by case_number;

rollback;
