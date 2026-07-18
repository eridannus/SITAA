-- Verificador transaccional de SITAA 0006. No conserva fixtures ni cambios.

begin;

create temporary table sitaa_0006_context (
  division_id uuid not null,
  active_program_id uuid not null,
  inactive_program_id uuid not null
) on commit drop;

insert into sitaa_0006_context values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid());

insert into public.divisions (id, code, name)
select division_id, 'verify_0006_' || replace(division_id::text, '-', ''), 'División sintética 0006'
from sitaa_0006_context;

insert into public.academic_programs (id, division_id, code, name, is_active)
select active_program_id, division_id, 'active_0006_' || replace(active_program_id::text, '-', ''), 'Programa activo sintético 0006', true
from sitaa_0006_context
union all
select inactive_program_id, division_id, 'inactive_0006_' || replace(inactive_program_id::text, '-', ''), 'Programa inactivo sintético 0006', false
from sitaa_0006_context;

create temporary table sitaa_0006_cases (
  label text primary key,
  id uuid not null unique,
  email text not null unique
) on commit drop;

create or replace function pg_temp.case_id(target_label text)
returns uuid language sql stable set search_path = pg_temp as $$
  select id from sitaa_0006_cases where label = target_label
$$;

create or replace function pg_temp.case_email(target_label text)
returns text language sql stable set search_path = pg_temp as $$
  select email from sitaa_0006_cases where label = target_label
$$;

-- El cambio de rol posterior debe conservar acceso sólo al lookup temporal del arnés.
-- Estos permisos desaparecen con la tabla y el esquema temporal de la sesión.
revoke all on function pg_temp.case_id(text) from public, anon;
revoke all on function pg_temp.case_email(text) from public, anon;
grant select on table pg_temp.sitaa_0006_cases to authenticated;
grant execute on function pg_temp.case_id(text) to authenticated;
grant execute on function pg_temp.case_email(text) to authenticated;

create or replace function pg_temp.insert_auth_user(
  target_label text,
  target_provider text default 'google',
  target_user_metadata jsonb default '{}'::jsonb,
  target_app_metadata jsonb default '{}'::jsonb,
  confirmed boolean default false
)
returns uuid language plpgsql set search_path = public, auth, pg_temp, pg_catalog as $$
declare
  target_id uuid := gen_random_uuid();
  target_email text := replace(target_label, '_', '-') || '-0006@example.invalid';
begin
  insert into sitaa_0006_cases(label, id, email) values (target_label, target_id, target_email);
  insert into auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values (
    target_id, 'authenticated', 'authenticated', target_email, '',
    case when confirmed then now() else null end,
    jsonb_build_object('provider', target_provider, 'providers', jsonb_build_array(target_provider)) || target_app_metadata,
    target_user_metadata, now(), now()
  );
  return target_id;
end;
$$;

create or replace function pg_temp.insert_google_identity(
  target_label text,
  verified boolean default true,
  identity_email text default null
)
returns void language plpgsql set search_path = auth, pg_temp, pg_catalog, information_schema as $$
declare
  target_id uuid := pg_temp.case_id(target_label);
  provider_key text := 'google-' || target_label || '-0006';
  payload jsonb := jsonb_build_object(
    'sub', provider_key,
    'email', coalesce(identity_email, pg_temp.case_email(target_label)),
    'email_verified', verified
  );
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'identities' and column_name = 'provider_id'
  ) then
    execute 'insert into auth.identities (provider_id,user_id,identity_data,provider,last_sign_in_at,created_at,updated_at) values ($1,$2,$3,''google'',now(),now(),now())'
      using provider_key, target_id, payload;
  else
    execute 'insert into auth.identities (id,user_id,identity_data,provider,last_sign_in_at,created_at,updated_at) values ($1,$2,$3,''google'',now(),now(),now())'
      using provider_key, target_id, payload;
  end if;
end;
$$;

create or replace function pg_temp.create_google_pending(
  target_label text,
  provisional_name text default 'Nombre provisional',
  confirmed boolean default false,
  verified boolean default true,
  create_identity boolean default true,
  identity_email text default null
)
returns uuid language plpgsql set search_path = pg_temp, pg_catalog as $$
declare target_id uuid;
begin
  target_id := pg_temp.insert_auth_user(
    target_label, 'google', jsonb_build_object('name', provisional_name), '{}'::jsonb, confirmed
  );
  if create_identity then
    perform pg_temp.insert_google_identity(target_label, verified, identity_email);
  end if;
  return target_id;
end;
$$;

create or replace function pg_temp.set_request_user(target_label text)
returns void language plpgsql set search_path = pg_temp, pg_catalog as $$
declare target_id uuid := pg_temp.case_id(target_label);
begin
  perform set_config('request.jwt.claim.sub', target_id::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', target_id, 'role', 'authenticated')::text, true);
end;
$$;

create or replace function pg_temp.complete_case(
  target_label text,
  person_type text,
  first_names text,
  paternal_surname text,
  maternal_surname text,
  identifier_value text,
  program_id uuid
)
returns void language plpgsql set search_path = public, pg_temp, pg_catalog as $$
declare
  profile_count_before bigint;
  profile_count_after bigint;
begin
  select count(*) into profile_count_before from public.profiles;
  perform pg_temp.set_request_user(target_label);
  perform public.complete_own_google_registration(
    person_type, first_names, paternal_surname, maternal_surname, identifier_value, program_id
  );
  select count(*) into profile_count_after from public.profiles;
  if profile_count_after <> profile_count_before
     or (select count(*) from public.profiles where id = pg_temp.case_id(target_label)) <> 1 then
    raise exception '0006: la finalización de % no actualizó exactamente un perfil existente.', target_label;
  end if;
end;
$$;

create or replace function pg_temp.expect_completion_rejection(
  target_label text,
  person_type text,
  first_names text,
  paternal_surname text,
  maternal_surname text,
  identifier_value text,
  program_id uuid,
  expected_message text
)
returns void language plpgsql set search_path = public, pg_temp, pg_catalog as $$
declare
  before_row jsonb;
  after_row jsonb;
  rejected boolean := false;
  actual_message text;
begin
  select to_jsonb(p) into before_row from public.profiles p where p.id = pg_temp.case_id(target_label);
  perform pg_temp.set_request_user(target_label);
  begin
    perform public.complete_own_google_registration(
      person_type, first_names, paternal_surname, maternal_surname, identifier_value, program_id
    );
  exception when others then
    rejected := true;
    get stacked diagnostics actual_message = message_text;
  end;
  if not rejected or position(expected_message in coalesce(actual_message, '')) = 0 then
    raise exception '0006: rechazo inesperado para %, se esperaba % y se obtuvo %', target_label, expected_message, actual_message;
  end if;
  select to_jsonb(p) into after_row from public.profiles p where p.id = pg_temp.case_id(target_label);
  if before_row is distinct from after_row then
    raise exception '0006: el rechazo de % modificó parcialmente el perfil.', target_label;
  end if;
end;
$$;

-- Contrato de objetos y privilegios posterior a aplicar 0006.
do $contract$
declare
  new_oid oid := to_regprocedure('public.complete_own_google_registration(text,text,text,text,text,uuid)');
  old_oid oid := to_regprocedure('public.complete_own_google_registration(text,text,text,uuid)');
  public_execute_new boolean;
  public_execute_old boolean;
begin
  if new_oid is null
     or old_oid is null
     or to_regprocedure('public.normalize_sitaa_profile_names()') is null then
    raise exception '0006: faltan funciones requeridas.';
  end if;

  select exists (
    select 1 from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    where p.oid = new_oid and acl.grantee = 0 and acl.privilege_type = 'EXECUTE'
  ) into public_execute_new;
  select exists (
    select 1 from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    where p.oid = old_oid and acl.grantee = 0 and acl.privilege_type = 'EXECUTE'
  ) into public_execute_old;

  if not has_function_privilege('authenticated', new_oid, 'EXECUTE')
     or has_function_privilege('anon', new_oid, 'EXECUTE')
     or public_execute_new
     or has_function_privilege('authenticated', old_oid, 'EXECUTE')
     or has_function_privilege('anon', old_oid, 'EXECUTE')
     or public_execute_old then
    raise exception '0006: privilegios inesperados en las funciones de finalización.';
  end if;

  if has_table_privilege('authenticated', 'public.profiles', 'UPDATE')
     or not has_column_privilege('authenticated', 'public.profiles', 'first_names', 'UPDATE')
     or not has_column_privilege('authenticated', 'public.profiles', 'paternal_surname', 'UPDATE')
     or not has_column_privilege('authenticated', 'public.profiles', 'maternal_surname', 'UPDATE')
     or exists (
       select 1 from pg_attribute a
       where a.attrelid = 'public.profiles'::regclass and a.attnum > 0 and not a.attisdropped
         and a.attname not in ('first_names', 'paternal_surname', 'maternal_surname')
         and has_column_privilege('authenticated', 'public.profiles', a.attname, 'UPDATE')
     ) then
    raise exception '0006: authenticated no tiene exactamente las tres columnas de nombre editables.';
  end if;

  if has_table_privilege('authenticated', 'public.role_assignments', 'INSERT')
     or has_table_privilege('authenticated', 'public.role_assignments', 'UPDATE')
     or has_table_privilege('authenticated', 'public.role_assignments', 'DELETE') then
    raise exception '0006: los roles dejaron de estar separados de la edición de perfil.';
  end if;

  if not exists (
    select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace join pg_proc p on p.oid = t.tgfoid
    where n.nspname = 'public' and c.relname = 'profiles'
      and t.tgname = 'normalize_sitaa_profile_names'
      and p.proname = 'normalize_sitaa_profile_names' and not t.tgisinternal
  ) then raise exception '0006: falta el trigger de normalización de nombres.'; end if;
end;
$contract$;

-- Casos válidos: límites, Unicode, normalización, apellido opcional e identificadores.
select pg_temp.create_google_pending(label)
from unnest(array[
  'main_unicode', 'maternal_null', 'first_1', 'first_150', 'paternal_1', 'paternal_150',
  'maternal_150', 'identifier_1', 'identifier_50', 'same_digits_student', 'same_digits_professor',
  'confirmed_identity_true'
]) label;

select pg_temp.set_request_user('main_unicode');
select set_config('sitaa.verify.program_id', active_program_id::text, true) from sitaa_0006_context;
set local role authenticated;
select public.complete_own_google_registration(
  'student', '  José   María  ', ' D''Ángelo ', ' 李 ', '00060001',
  current_setting('sitaa.verify.program_id')::uuid
);
reset role;

do $valid_completions$
declare p uuid := (select active_program_id from sitaa_0006_context);
begin
  perform pg_temp.complete_case('maternal_null', 'professor', 'Ana', 'López', null, '00060002', p);
  perform pg_temp.complete_case('first_1', 'student', 'A', 'Pérez', null, '00060003', p);
  perform pg_temp.complete_case('first_150', 'student', repeat('N', 150), 'Pérez', null, '00060004', p);
  perform pg_temp.complete_case('paternal_1', 'student', 'Ana', 'P', null, '00060005', p);
  perform pg_temp.complete_case('paternal_150', 'student', 'Ana', repeat('P', 150), null, '00060006', p);
  perform pg_temp.complete_case('maternal_150', 'student', 'Ana', 'Pérez', repeat('M', 150), '00060007', p);
  perform pg_temp.complete_case('identifier_1', 'student', 'Ana', 'Pérez', null, '7', p);
  perform pg_temp.complete_case('identifier_50', 'student', 'Ana', 'Pérez', null, '0' || repeat('1', 49), p);
  perform pg_temp.complete_case('same_digits_student', 'student', 'Ana', 'Pérez', null, '606060', p);
  perform pg_temp.complete_case('same_digits_professor', 'professor', 'Luis', 'Pérez', null, '606060', p);
  perform pg_temp.complete_case('confirmed_identity_true', 'student', 'Eva', 'Pérez', null, '00060008', p);
end;
$valid_completions$;

-- email_confirmed_at final es evidencia válida aunque identity_data diga false.
select pg_temp.insert_auth_user('confirmed_false', 'google', '{"name":"Provisional"}'::jsonb, '{}'::jsonb, true);
select pg_temp.insert_google_identity('confirmed_false', false);
select pg_temp.complete_case('confirmed_false', 'student', 'Eva', 'Pérez', null, '00060009', active_program_id)
from sitaa_0006_context;

do $valid_assertions$
begin
  if not exists (
    select 1 from public.profiles
    where id = pg_temp.case_id('main_unicode')
      and first_names = 'José María' and paternal_surname = 'D''Ángelo' and maternal_surname = '李'
      and full_name = 'José María D''Ángelo 李'
      and full_name !~ '  ' and full_name !~ '^ | $'
  ) then raise exception '0006: falló la normalización Unicode o la derivación exacta de full_name.'; end if;
  if not exists (
    select 1 from public.profiles where id = pg_temp.case_id('maternal_null')
      and maternal_surname is null and full_name = 'Ana López'
  ) then raise exception '0006: falló el apellido materno opcional.'; end if;
  if not exists (
    select 1 from public.profiles where id = pg_temp.case_id('identifier_50')
      and institutional_id_value = '0' || repeat('1', 49)
  ) then raise exception '0006: no se preservaron ceros iniciales o el límite de 50 dígitos.'; end if;
  if exists (
    select 1 from public.role_assignments where user_id in (select id from sitaa_0006_cases)
  ) then raise exception '0006: la finalización creó roles automáticamente.'; end if;
end;
$valid_assertions$;

-- Límites inválidos de nombres e identificadores; cada rechazo debe ser atómico.
select pg_temp.create_google_pending(label)
from unnest(array[
  'invalid_first', 'invalid_paternal', 'invalid_maternal', 'invalid_derived', 'blank_first', 'blank_paternal',
  'identifier_51', 'identifier_letters', 'identifier_spaces', 'identifier_punctuation',
  'duplicate_student', 'duplicate_worker', 'inactive_program', 'missing_program'
]) label;

do $invalid_boundaries$
declare
  p uuid := (select active_program_id from sitaa_0006_context);
  inactive_p uuid := (select inactive_program_id from sitaa_0006_context);
begin
  perform pg_temp.expect_completion_rejection('invalid_first', 'student', repeat('N',151), 'Pérez', null, '10001', p, 'sitaa_invalid_first_names');
  perform pg_temp.expect_completion_rejection('invalid_paternal', 'student', 'Ana', repeat('P',151), null, '10002', p, 'sitaa_invalid_paternal_surname');
  perform pg_temp.expect_completion_rejection('invalid_maternal', 'student', 'Ana', 'Pérez', repeat('M',151), '10003', p, 'sitaa_invalid_maternal_surname');
  perform pg_temp.expect_completion_rejection('invalid_derived', 'student', repeat('N',100), repeat('P',100), 'M', '10004', p, 'sitaa_invalid_full_name');
  perform pg_temp.expect_completion_rejection('blank_first', 'student', '   ', 'Pérez', null, '10005', p, 'sitaa_invalid_first_names');
  perform pg_temp.expect_completion_rejection('blank_paternal', 'student', 'Ana', '   ', null, '10006', p, 'sitaa_invalid_paternal_surname');
  perform pg_temp.expect_completion_rejection('identifier_51', 'student', 'Ana', 'Pérez', null, repeat('1',51), p, 'sitaa_identifier_too_long');
  perform pg_temp.expect_completion_rejection('identifier_letters', 'student', 'Ana', 'Pérez', null, '12A34', p, 'sitaa_invalid_institutional_identifier');
  perform pg_temp.expect_completion_rejection('identifier_spaces', 'student', 'Ana', 'Pérez', null, '12 34', p, 'sitaa_invalid_institutional_identifier');
  perform pg_temp.expect_completion_rejection('identifier_punctuation', 'student', 'Ana', 'Pérez', null, '12-34', p, 'sitaa_invalid_institutional_identifier');
  perform pg_temp.expect_completion_rejection('duplicate_student', 'student', 'Ana', 'Pérez', null, '606060', p, 'sitaa_identifier_conflict');
  perform pg_temp.expect_completion_rejection('duplicate_worker', 'professor', 'Ana', 'Pérez', null, '606060', p, 'sitaa_identifier_conflict');
  perform pg_temp.expect_completion_rejection('inactive_program', 'student', 'Ana', 'Pérez', null, '10007', inactive_p, 'sitaa_invalid_registration_program');
  perform pg_temp.expect_completion_rejection('missing_program', 'student', 'Ana', 'Pérez', null, '10008', gen_random_uuid(), 'sitaa_invalid_registration_program');
end;
$invalid_boundaries$;

-- Frontera de identidad Google y estados de cuenta.
select pg_temp.create_google_pending('missing_identity', 'Provisional', false, true, false);
select pg_temp.create_google_pending('foreign_identity_owner');
select pg_temp.create_google_pending('foreign_identity_target', 'Provisional', false, true, false);
select pg_temp.create_google_pending('identity_email_mismatch', 'Provisional', false, true, true, 'other-0006@example.invalid');
select pg_temp.create_google_pending('profile_email_mismatch');
update public.profiles set email = 'different-profile-0006@example.invalid' where id = pg_temp.case_id('profile_email_mismatch');
select pg_temp.create_google_pending('unverified_google', 'Provisional', false, false, true);

do $google_rejections$
declare p uuid := (select active_program_id from sitaa_0006_context);
begin
  perform pg_temp.expect_completion_rejection('missing_identity', 'student', 'Ana', 'Pérez', null, '11001', p, 'sitaa_google_identity_required');
  perform pg_temp.expect_completion_rejection('foreign_identity_target', 'student', 'Ana', 'Pérez', null, '11002', p, 'sitaa_google_identity_required');
  perform pg_temp.expect_completion_rejection('identity_email_mismatch', 'student', 'Ana', 'Pérez', null, '11003', p, 'sitaa_google_identity_email_mismatch');
  perform pg_temp.expect_completion_rejection('profile_email_mismatch', 'student', 'Ana', 'Pérez', null, '11004', p, 'sitaa_google_identity_email_mismatch');
  perform pg_temp.expect_completion_rejection('unverified_google', 'student', 'Ana', 'Pérez', null, '11005', p, 'sitaa_google_email_not_verified');
end;
$google_rejections$;

-- Un perfil provisional permanece intacto hasta completar y después se reemplaza.
select pg_temp.create_google_pending('provisional_replace', ' Nombre   OAuth ');
update public.profiles set updated_at = now() where id = pg_temp.case_id('provisional_replace');
do $provisional_before$
begin
  if not exists (
    select 1 from public.profiles where id = pg_temp.case_id('provisional_replace')
      and full_name = 'Nombre OAuth' and first_names is null and paternal_surname is null and maternal_surname is null
  ) then raise exception '0006: una actualización ajena a nombres alteró la identidad provisional.'; end if;
end;
$provisional_before$;
select pg_temp.complete_case('provisional_replace', 'student', 'Nombre', 'Definitivo', null, '12001', active_program_id)
from sitaa_0006_context;

-- Ciclo de vida: activo, inactivo y técnico no pueden volver a finalizar.
select pg_temp.create_google_pending('inactive_case');
select pg_temp.complete_case('inactive_case', 'student', 'Ana', 'Pérez', null, '12002', active_program_id)
from sitaa_0006_context;
update public.profiles set account_status = 'inactive' where id = pg_temp.case_id('inactive_case');

select pg_temp.insert_auth_user(
  'technical_case', 'email', '{}'::jsonb,
  '{"sitaa_account_kind":"technical","sitaa_first_names":"Soporte SITAA"}'::jsonb, true
);

do $lifecycle_rejections$
declare p uuid := (select active_program_id from sitaa_0006_context);
begin
  perform pg_temp.expect_completion_rejection('main_unicode', 'student', 'Otro', 'Nombre', null, '12003', p, 'sitaa_registration_not_pending');
  perform pg_temp.expect_completion_rejection('inactive_case', 'student', 'Otro', 'Nombre', null, '12004', p, 'sitaa_registration_not_pending');
  perform pg_temp.expect_completion_rejection('technical_case', 'student', 'Otro', 'Nombre', null, '12005', p, 'sitaa_registration_not_pending');
end;
$lifecycle_rejections$;

-- El trigger siempre vuelve a derivar full_name en escrituras confiables.
update public.profiles set full_name = 'Valor incorrecto' where id = pg_temp.case_id('main_unicode');
update public.profiles set updated_at = now() where id = pg_temp.case_id('main_unicode');
do $trusted_sync$
begin
  if not exists (
    select 1 from public.profiles where id = pg_temp.case_id('main_unicode')
      and full_name = concat_ws(' ', first_names, paternal_surname, maternal_surname)
  ) then raise exception '0006: full_name no se resincronizó en una escritura confiable.'; end if;
end;
$trusted_sync$;

-- Edición propia: sólo tres componentes, normalización y restricciones de blancos.
select pg_temp.set_request_user('main_unicode');
set local role authenticated;
update public.profiles
set first_names = '  María   José ', paternal_surname = ' O''Connor ', maternal_surname = null
where id = pg_temp.case_id('main_unicode');

do $self_edit_rejections$
declare rejected boolean;
begin
  rejected := false;
  begin update public.profiles set full_name = 'No permitido' where id = pg_temp.case_id('main_unicode');
  exception when insufficient_privilege then rejected := true; end;
  if not rejected then raise exception '0006: authenticated pudo editar full_name directamente.'; end if;

  rejected := false;
  begin update public.profiles set institutional_id_value = '999999' where id = pg_temp.case_id('main_unicode');
  exception when insufficient_privilege then rejected := true; end;
  if not rejected then raise exception '0006: authenticated pudo editar identidad administrativa.'; end if;

  rejected := false;
  begin update public.profiles set first_names = '   ' where id = pg_temp.case_id('main_unicode');
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0006: authenticated pudo dejar first_names vacío.'; end if;

  rejected := false;
  begin update public.profiles set paternal_surname = '   ' where id = pg_temp.case_id('main_unicode');
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0006: authenticated pudo dejar paternal_surname vacío.'; end if;
end;
$self_edit_rejections$;
reset role;

do $self_edit_assertion$
begin
  if not exists (
    select 1 from public.profiles where id = pg_temp.case_id('main_unicode')
      and first_names = 'María José' and paternal_surname = 'O''Connor'
      and maternal_surname is null and full_name = 'María José O''Connor'
  ) then raise exception '0006: la edición propia no normalizó o sincronizó nombres.'; end if;
end;
$self_edit_assertion$;

-- Una cuenta técnica puede mantener apellidos nulos y sincroniza su nombre derivado.
select pg_temp.set_request_user('technical_case');
set local role authenticated;
update public.profiles set first_names = ' Soporte   Institucional ', paternal_surname = null, maternal_surname = null
where id = pg_temp.case_id('technical_case');
reset role;

do $technical_assertion$
begin
  if not exists (
    select 1 from public.profiles where id = pg_temp.case_id('technical_case')
      and first_names = 'Soporte Institucional' and paternal_surname is null
      and maternal_surname is null and full_name = 'Soporte Institucional'
  ) then raise exception '0006: la cuenta técnica no conservó su contrato sin apellidos.'; end if;
end;
$technical_assertion$;

-- Regresiones de contratos 0002–0005: funciones, triggers y políticas esenciales.
do $previous_contracts$
begin
  if to_regprocedure('public.publish_activity(uuid)') is null
     or to_regprocedure('public.can_update_activity_base(uuid)') is null
     or to_regprocedure('public.can_delete_activity(uuid)') is null
     or to_regprocedure('public.finalize_expired_attendance()') is null
     or to_regprocedure('public.handle_sitaa_auth_user_created()') is null
     or to_regprocedure('public.sync_sitaa_profile_email_from_auth()') is null
     or to_regprocedure('public.enforce_sitaa_profile_identity()') is null then
    raise exception '0006: falta una función requerida por 0002–0005.';
  end if;

  if not exists (
    select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace join pg_proc p on p.oid = t.tgfoid
    where n.nspname = 'auth' and c.relname = 'users' and t.tgname = 'on_sitaa_auth_user_created'
      and p.proname = 'handle_sitaa_auth_user_created' and not t.tgisinternal
  ) or not exists (
    select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace join pg_proc p on p.oid = t.tgfoid
    where n.nspname = 'auth' and c.relname = 'users' and t.tgname = 'on_sitaa_auth_user_email_changed'
      and p.proname = 'sync_sitaa_profile_email_from_auth' and not t.tgisinternal
  ) or not exists (
    select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace join pg_proc p on p.oid = t.tgfoid
    where n.nspname = 'public' and c.relname = 'profiles' and t.tgname = 'enforce_sitaa_profile_identity'
      and p.proname = 'enforce_sitaa_profile_identity' and not t.tgisinternal
  ) or not exists (
    select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace join pg_proc p on p.oid = t.tgfoid
    where n.nspname = 'public' and c.relname = 'profiles' and t.tgname = 'set_profiles_updated_at'
      and p.proname = 'set_updated_at' and not t.tgisinternal
  ) then raise exception '0006: falta un trigger requerido por 0002–0005.'; end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'activities' and policyname = 'Users can read permitted activities')
     or not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'Users can read own profile')
     or not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'Users can update own basic profile') then
    raise exception '0006: falta una política esencial establecida antes de 0006.';
  end if;
end;
$previous_contracts$;

select 'Verificación 0006 completada; todas las fixtures se revertirán.' as resultado;
rollback;
