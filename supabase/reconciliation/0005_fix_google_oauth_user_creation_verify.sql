-- Verificación transaccional de SITAA 0005.
-- Ejecutar en prueba después de aplicar 0005. Termina siempre en ROLLBACK.

begin;

create temporary table sitaa_0005_ids on commit drop as
select
  gen_random_uuid() division_id,
  gen_random_uuid() program_id,
  gen_random_uuid() inactive_program_id,
  gen_random_uuid() student_id,
  gen_random_uuid() professor_id,
  gen_random_uuid() no_identity_id,
  gen_random_uuid() mismatch_id,
  gen_random_uuid() unverified_id,
  gen_random_uuid() invalid_id,
  gen_random_uuid() duplicate_id,
  gen_random_uuid() inactive_id,
  gen_random_uuid() technical_id;

do $settings$
declare ids sitaa_0005_ids%rowtype;
begin
  select * into ids from sitaa_0005_ids;
  perform set_config('sitaa_test.division_id', ids.division_id::text, true);
  perform set_config('sitaa_test.program_id', ids.program_id::text, true);
  perform set_config('sitaa_test.inactive_program_id', ids.inactive_program_id::text, true);
  perform set_config('sitaa_test.student_id', ids.student_id::text, true);
  perform set_config('sitaa_test.professor_id', ids.professor_id::text, true);
  perform set_config('sitaa_test.no_identity_id', ids.no_identity_id::text, true);
  perform set_config('sitaa_test.mismatch_id', ids.mismatch_id::text, true);
  perform set_config('sitaa_test.unverified_id', ids.unverified_id::text, true);
  perform set_config('sitaa_test.invalid_id', ids.invalid_id::text, true);
  perform set_config('sitaa_test.duplicate_id', ids.duplicate_id::text, true);
  perform set_config('sitaa_test.inactive_id', ids.inactive_id::text, true);
  perform set_config('sitaa_test.technical_id', ids.technical_id::text, true);
end;
$settings$;

create temporary table sitaa_0005_legacy_before on commit drop as
select p.id, p.account_status, p.is_active
from public.profiles p
where exists (
  select 1 from auth.identities i where i.user_id = p.id and i.provider = 'email'
);

insert into public.divisions (id, code, name)
select division_id, 'sitaa_0005_' || replace(division_id::text, '-', ''),
       'División sintética 0005' from sitaa_0005_ids;

insert into public.academic_programs (id, division_id, code, name, is_active)
select program_id, division_id, 'sitaa_0005_' || replace(program_id::text, '-', ''),
       'Programa sintético 0005', true from sitaa_0005_ids;
insert into public.academic_programs (id, division_id, code, name, is_active)
select inactive_program_id, division_id,
       'sitaa_0005_inactive_' || replace(inactive_program_id::text, '-', ''),
       'Programa inactivo sintético 0005', false from sitaa_0005_ids;

create or replace function pg_temp.insert_auth_user(
  target_id uuid,
  target_email text,
  target_provider text,
  target_user_metadata jsonb default '{}'::jsonb,
  target_app_metadata jsonb default '{}'::jsonb,
  confirmed boolean default false
) returns void
language plpgsql
set search_path = public, auth, pg_temp
as $$
begin
  insert into auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values (
    target_id, 'authenticated', 'authenticated', target_email, '',
    case when confirmed then now() else null end,
    jsonb_build_object('provider', target_provider, 'providers', jsonb_build_array(target_provider))
      || coalesce(target_app_metadata, '{}'::jsonb),
    coalesce(target_user_metadata, '{}'::jsonb), now(), now()
  );
end;
$$;

create or replace function pg_temp.insert_google_identity(
  target_user_id uuid,
  target_provider_id text,
  target_email text,
  verified_value jsonb
) returns void
language plpgsql
set search_path = auth, pg_catalog, pg_temp
as $$
declare identity_payload jsonb := jsonb_build_object(
  'sub', target_provider_id,
  'email', target_email,
  'email_verified', verified_value
);
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'identities' and column_name = 'provider_id'
  ) then
    execute $sql$
      insert into auth.identities (
        provider_id, user_id, identity_data, provider,
        last_sign_in_at, created_at, updated_at
      ) values ($1, $2, $3, 'google', now(), now(), now())
    $sql$ using target_provider_id, target_user_id, identity_payload;
  else
    execute $sql$
      insert into auth.identities (
        id, user_id, identity_data, provider,
        last_sign_in_at, created_at, updated_at
      ) values ($1, $2, $3, 'google', now(), now(), now())
    $sql$ using target_provider_id, target_user_id, identity_payload;
  end if;
end;
$$;

create or replace function pg_temp.expect_auth_rejection(
  target_email text,
  target_provider text,
  target_user_metadata jsonb,
  target_app_metadata jsonb,
  expected_error text,
  expected_label text,
  confirmed boolean default false
) returns void
language plpgsql
set search_path = public, auth, pg_temp
as $$
declare
  target_id uuid := gen_random_uuid();
  caught_message text;
  rejected boolean := false;
begin
  begin
    perform pg_temp.insert_auth_user(
      target_id, target_email, target_provider,
      target_user_metadata, target_app_metadata, confirmed
    );
  exception when others then
    rejected := true;
    get stacked diagnostics caught_message = message_text;
  end;
  if not rejected or position(expected_error in coalesce(caught_message, '')) = 0 then
    raise exception 'Contrato de rechazo incorrecto para %: %.',
      expected_label, coalesce(caught_message, '<sin mensaje>');
  end if;
  if exists (select 1 from auth.users where id = target_id)
     or exists (select 1 from public.profiles where id = target_id) then
    raise exception 'El rechazo de % dejó un Auth user o profile huérfano.', expected_label;
  end if;
end;
$$;

do $verify_function_privileges$
begin
  if has_function_privilege(
       'anon', 'public.complete_own_google_registration(text,text,text,uuid)', 'EXECUTE'
     ) or not has_function_privilege(
       'authenticated', 'public.complete_own_google_registration(text,text,text,uuid)', 'EXECUTE'
     ) or has_function_privilege(
       'anon', 'public.handle_sitaa_auth_user_created()', 'EXECUTE'
     ) or has_function_privilege(
       'authenticated', 'public.handle_sitaa_auth_user_created()', 'EXECUTE'
     ) then
    raise exception 'Los privilegios de las funciones 0005 no respetan el contrato mínimo.';
  end if;
end;
$verify_function_privileges$;

-- A. Secuencia real: Google inserta auth.users con confirmación inicialmente nula.
select pg_temp.insert_auth_user(
  current_setting('sitaa_test.student_id')::uuid,
  'student-0005@example.invalid', 'google',
  '{"full_name":"Nombre provisional Google"}'::jsonb, '{}'::jsonb, false
);
select pg_temp.insert_auth_user(
  current_setting('sitaa_test.professor_id')::uuid,
  'professor-0005@example.invalid', 'google',
  '{"name":"Profesor provisional Google"}'::jsonb, '{}'::jsonb, false
);

do $verify_pending_creation$
begin
  if (select count(*) from auth.users
      where id in (current_setting('sitaa_test.student_id')::uuid,
                   current_setting('sitaa_test.professor_id')::uuid)
        and email_confirmed_at is null) <> 2 then
    raise exception 'La inserción Google temprana no conservó los dos Auth users sintéticos.';
  end if;
  if (select count(*) from public.profiles
      where id in (current_setting('sitaa_test.student_id')::uuid,
                   current_setting('sitaa_test.professor_id')::uuid)
        and account_kind = 'institutional' and account_status = 'pending_registration'
        and not is_active and activated_at is null and deactivated_at is null
        and person_type is null and primary_program_id is null
        and institutional_id_type is null and institutional_id_value is null) <> 2 then
    raise exception 'Google no creó exactamente dos perfiles mínimos pendientes.';
  end if;
  if exists (select 1 from public.role_assignments
    where user_id in (current_setting('sitaa_test.student_id')::uuid,
                      current_setting('sitaa_test.professor_id')::uuid)) then
    raise exception 'El alta Google creó roles.';
  end if;
end;
$verify_pending_creation$;

-- B. Identidad Google verificada: boolean para alumno y string para profesor.
select pg_temp.insert_google_identity(
  current_setting('sitaa_test.student_id')::uuid, 'google-student-0005',
  'student-0005@example.invalid', 'true'::jsonb
);
select pg_temp.insert_google_identity(
  current_setting('sitaa_test.professor_id')::uuid, 'google-professor-0005',
  'professor-0005@example.invalid', '"true"'::jsonb
);

select set_config('request.jwt.claim.sub', current_setting('sitaa_test.student_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.student_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
select public.complete_own_google_registration(
  'student', 'Alumno sintético 0005', '00001234',
  current_setting('sitaa_test.program_id')::uuid
);
reset role;

select set_config('request.jwt.claim.sub', current_setting('sitaa_test.professor_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.professor_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
select public.complete_own_google_registration(
  'professor', 'Profesor sintético 0005', '00001234',
  current_setting('sitaa_test.program_id')::uuid
);
reset role;

do $verify_completed_profiles$
begin
  if not exists (select 1 from public.profiles
    where id = current_setting('sitaa_test.student_id')::uuid
      and account_status = 'active' and is_active
      and person_type = 'student' and institutional_id_type = 'student_account'
      and institutional_id_value = '00001234') then
    raise exception 'El alumno Google no completó su identidad.';
  end if;
  if not exists (select 1 from public.profiles
    where id = current_setting('sitaa_test.professor_id')::uuid
      and account_status = 'active' and is_active
      and person_type = 'professor' and institutional_id_type = 'worker_number'
      and institutional_id_value = '00001234') then
    raise exception 'El profesor Google no completó su identidad.';
  end if;
  if exists (select 1 from public.role_assignments
    where user_id in (current_setting('sitaa_test.student_id')::uuid,
                      current_setting('sitaa_test.professor_id')::uuid)) then
    raise exception 'Completion creó roles académicos.';
  end if;
end;
$verify_completed_profiles$;

-- C. Fallos de identidad Google y datos institucionales conservan pending.
select pg_temp.insert_auth_user(current_setting('sitaa_test.no_identity_id')::uuid,
  'no-identity-0005@example.invalid', 'google', '{}'::jsonb, '{}'::jsonb, false);
select pg_temp.insert_auth_user(current_setting('sitaa_test.mismatch_id')::uuid,
  'mismatch-0005@example.invalid', 'google', '{}'::jsonb, '{}'::jsonb, false);
select pg_temp.insert_auth_user(current_setting('sitaa_test.unverified_id')::uuid,
  'unverified-0005@example.invalid', 'google', '{}'::jsonb, '{}'::jsonb, false);
select pg_temp.insert_auth_user(current_setting('sitaa_test.invalid_id')::uuid,
  'invalid-0005@example.invalid', 'google', '{}'::jsonb, '{}'::jsonb, false);
select pg_temp.insert_auth_user(current_setting('sitaa_test.duplicate_id')::uuid,
  'duplicate-0005@example.invalid', 'google', '{}'::jsonb, '{}'::jsonb, false);
select pg_temp.insert_auth_user(current_setting('sitaa_test.inactive_id')::uuid,
  'inactive-0005@example.invalid', 'google', '{}'::jsonb, '{}'::jsonb, false);

select pg_temp.insert_google_identity(current_setting('sitaa_test.mismatch_id')::uuid,
  'google-mismatch-0005', 'different-0005@example.invalid', 'true'::jsonb);
select pg_temp.insert_google_identity(current_setting('sitaa_test.unverified_id')::uuid,
  'google-unverified-0005', 'unverified-0005@example.invalid', 'false'::jsonb);
select pg_temp.insert_google_identity(current_setting('sitaa_test.invalid_id')::uuid,
  'google-invalid-0005', 'invalid-0005@example.invalid', 'true'::jsonb);
select pg_temp.insert_google_identity(current_setting('sitaa_test.duplicate_id')::uuid,
  'google-duplicate-0005', 'duplicate-0005@example.invalid', 'true'::jsonb);
select pg_temp.insert_google_identity(current_setting('sitaa_test.inactive_id')::uuid,
  'google-inactive-0005', 'inactive-0005@example.invalid', 'true'::jsonb);

create or replace function pg_temp.expect_completion_rejection(
  target_user_id uuid,
  target_person_type text,
  target_identifier text,
  target_program_id uuid,
  expected_error text,
  expected_label text
) returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  before_profile jsonb;
  after_profile jsonb;
  caught_message text;
  rejected boolean := false;
begin
  perform set_config('request.jwt.claim.sub', target_user_id::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', target_user_id, 'role', 'authenticated'
  )::text, true);
  select to_jsonb(p) - 'updated_at' into before_profile
  from public.profiles p where p.id = target_user_id;
  begin
    perform public.complete_own_google_registration(
      target_person_type, 'Nombre sintético válido', target_identifier, target_program_id
    );
  exception when others then
    rejected := true;
    get stacked diagnostics caught_message = message_text;
  end;
  select to_jsonb(p) - 'updated_at' into after_profile
  from public.profiles p where p.id = target_user_id;
  if not rejected or position(expected_error in coalesce(caught_message, '')) = 0 then
    raise exception 'Completion no respetó el rechazo de %: %.',
      expected_label, coalesce(caught_message, '<sin mensaje>');
  end if;
  if before_profile is distinct from after_profile then
    raise exception 'El rechazo de % alteró parcialmente el perfil.', expected_label;
  end if;
end;
$$;

select pg_temp.expect_completion_rejection(
  current_setting('sitaa_test.no_identity_id')::uuid, 'student', '9001',
  current_setting('sitaa_test.program_id')::uuid,
  'sitaa_google_identity_required', 'identidad Google ausente o ajena'
);
select pg_temp.expect_completion_rejection(
  current_setting('sitaa_test.mismatch_id')::uuid, 'student', '9002',
  current_setting('sitaa_test.program_id')::uuid,
  'sitaa_google_identity_email_mismatch', 'correo Google distinto'
);
select pg_temp.expect_completion_rejection(
  current_setting('sitaa_test.unverified_id')::uuid, 'student', '9003',
  current_setting('sitaa_test.program_id')::uuid,
  'sitaa_google_email_not_verified', 'identidad Google no verificada'
);
select pg_temp.expect_completion_rejection(
  current_setting('sitaa_test.invalid_id')::uuid, 'student', '90A4',
  current_setting('sitaa_test.program_id')::uuid,
  'sitaa_invalid_institutional_identifier', 'identificador inválido'
);
select pg_temp.expect_completion_rejection(
  current_setting('sitaa_test.invalid_id')::uuid, 'student', '9004',
  current_setting('sitaa_test.inactive_program_id')::uuid,
  'sitaa_invalid_registration_program', 'programa inactivo'
);
select pg_temp.expect_completion_rejection(
  current_setting('sitaa_test.invalid_id')::uuid, 'student', '9004', gen_random_uuid(),
  'sitaa_invalid_registration_program', 'programa inexistente'
);
select pg_temp.expect_completion_rejection(
  current_setting('sitaa_test.duplicate_id')::uuid, 'student', '00001234',
  current_setting('sitaa_test.program_id')::uuid,
  'sitaa_identifier_conflict', 'identificador duplicado'
);

insert into public.role_assignments (
  user_id, role_code, scope_type, service_area, program_id, is_active, starts_at
) values (
  current_setting('sitaa_test.duplicate_id')::uuid,
  'professor', 'program', 'both', current_setting('sitaa_test.program_id')::uuid,
  true, current_date
);
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.duplicate_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.duplicate_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
do $verify_pending_cannot_operate$
begin
  if public.can_create_activity('program', current_setting('sitaa_test.program_id')::uuid,
    current_setting('sitaa_test.division_id')::uuid, 'tutoring') then
    raise exception 'Un perfil pendiente operó por tener una asignación.';
  end if;
end;
$verify_pending_cannot_operate$;
reset role;

-- Un perfil activo no se reescribe.
select pg_temp.expect_completion_rejection(
  current_setting('sitaa_test.student_id')::uuid, 'professor', '9999',
  current_setting('sitaa_test.program_id')::uuid,
  'sitaa_registration_not_pending', 'perfil activo'
);

-- Cuenta completada y luego inactiva no puede reactivarse.
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.inactive_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.inactive_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
select public.complete_own_google_registration(
  'professor', 'Profesor inactivo sintético', '7777',
  current_setting('sitaa_test.program_id')::uuid
);
reset role;
update public.profiles set account_status = 'inactive'
where id = current_setting('sitaa_test.inactive_id')::uuid;
insert into public.role_assignments (
  user_id, role_code, scope_type, service_area, program_id, is_active, starts_at
) values (
  current_setting('sitaa_test.inactive_id')::uuid,
  'professor', 'program', 'both', current_setting('sitaa_test.program_id')::uuid,
  true, current_date
);
select pg_temp.expect_completion_rejection(
  current_setting('sitaa_test.inactive_id')::uuid, 'professor', '7778',
  current_setting('sitaa_test.program_id')::uuid,
  'sitaa_registration_not_pending', 'perfil inactivo'
);
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.inactive_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.inactive_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
do $verify_inactive_cannot_operate$
begin
  if public.can_create_activity('program', current_setting('sitaa_test.program_id')::uuid,
    current_setting('sitaa_test.division_id')::uuid, 'tutoring') then
    raise exception 'Un perfil inactivo operó por tener una asignación.';
  end if;
end;
$verify_inactive_cannot_operate$;
reset role;

-- JWT sin Auth/profile correspondiente también es rechazado.
select pg_temp.expect_completion_rejection(
  gen_random_uuid(), 'student', '8111', current_setting('sitaa_test.program_id')::uuid,
  'sitaa_profile_missing', 'Auth user ausente'
);

-- D. Regresiones de rechazo Auth y bootstrap técnico.
select pg_temp.expect_auth_rejection(
  'github-0005@example.invalid', 'github', '{}'::jsonb, '{}'::jsonb,
  'sitaa_unsupported_auth_provider', 'OAuth no soportado'
);
select pg_temp.expect_auth_rejection(
  'email-0005@example.invalid', 'email', '{}'::jsonb, '{}'::jsonb,
  'sitaa_public_password_signup_disabled', 'signup público por contraseña'
);
select pg_temp.expect_auth_rejection(
  'public-tech-0005@example.invalid', 'google',
  '{"sitaa_account_kind":"technical"}'::jsonb, '{}'::jsonb,
  'sitaa_public_technical_account_forbidden', 'cuenta técnica desde metadata pública'
);
select pg_temp.expect_auth_rejection(
  '', 'google', '{}'::jsonb, '{}'::jsonb,
  'sitaa_invalid_registration_email', 'alta Google malformada'
);

select pg_temp.insert_auth_user(
  current_setting('sitaa_test.technical_id')::uuid,
  'technical-0005@example.invalid', 'email', '{}'::jsonb,
  '{"sitaa_account_kind":"technical","sitaa_full_name":"Cuenta técnica sintética"}'::jsonb,
  true
);
do $verify_technical$
begin
  if not exists (select 1 from public.profiles
    where id = current_setting('sitaa_test.technical_id')::uuid
      and account_kind = 'technical' and account_status = 'active' and is_active
      and person_type is null and primary_program_id is null
      and institutional_id_type is null and institutional_id_value is null) then
    raise exception 'El bootstrap técnico confiable dejó de funcionar.';
  end if;
end;
$verify_technical$;

-- E. Autorización y contratos heredados.
do $verify_legacy_unchanged$
begin
  if exists (
    select 1 from sitaa_0005_legacy_before b
    join public.profiles p on p.id = b.id
    where p.account_status is distinct from b.account_status
       or p.is_active is distinct from b.is_active
  ) then raise exception '0005 alteró un perfil heredado email/password.'; end if;
end;
$verify_legacy_unchanged$;

select set_config('request.jwt.claim.sub', current_setting('sitaa_test.student_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.student_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
do $verify_student_without_role$
begin
  if public.can_create_activity('program', current_setting('sitaa_test.program_id')::uuid,
    current_setting('sitaa_test.division_id')::uuid, 'tutoring') then
    raise exception 'Un alumno básico pudo crear actividades.';
  end if;
end;
$verify_student_without_role$;
reset role;

select set_config('request.jwt.claim.sub', current_setting('sitaa_test.professor_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.professor_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
do $verify_professor_without_role$
begin
  if public.can_create_activity('program', current_setting('sitaa_test.program_id')::uuid,
    current_setting('sitaa_test.division_id')::uuid, 'tutoring') then
    raise exception 'Un profesor básico pudo crear actividades.';
  end if;
end;
$verify_professor_without_role$;
reset role;

insert into public.role_assignments (
  user_id, role_code, scope_type, service_area, program_id, is_active, starts_at
) values (
  current_setting('sitaa_test.professor_id')::uuid,
  'professor', 'program', 'both', current_setting('sitaa_test.program_id')::uuid,
  true, current_date
), (
  current_setting('sitaa_test.student_id')::uuid,
  'peer_tutor', 'program', 'both', current_setting('sitaa_test.program_id')::uuid,
  true, current_date
);

select set_config('request.jwt.claim.sub', current_setting('sitaa_test.professor_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.professor_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
do $verify_professor_assignment$
begin
  if not public.can_create_activity('program', current_setting('sitaa_test.program_id')::uuid,
    current_setting('sitaa_test.division_id')::uuid, 'tutoring') then
    raise exception 'La asignación de profesor perdió sus permisos.';
  end if;
end;
$verify_professor_assignment$;
reset role;

select set_config('request.jwt.claim.sub', current_setting('sitaa_test.student_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.student_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
do $verify_peer_assignment$
begin
  if not public.can_create_activity('program', current_setting('sitaa_test.program_id')::uuid,
    current_setting('sitaa_test.division_id')::uuid, 'tutoring') then
    raise exception 'La asignación de tutor par perdió sus permisos.';
  end if;
end;
$verify_peer_assignment$;
reset role;

do $verify_regressions$
begin
  if to_regprocedure('public.publish_activity(uuid)') is null
     or to_regprocedure('public.can_update_activity_base(uuid)') is null
     or to_regprocedure('public.finalize_expired_attendance()') is null
     or position(
       'a.status_code = ''draft'' and a.created_by = auth.uid()'
       in lower(pg_get_functiondef('public.can_read_activity(uuid)'::regprocedure))
     ) = 0 then
    raise exception 'Falta un contrato de integridad establecido por 0002/0003.';
  end if;
end;
$verify_regressions$;

select 'Verificación 0005 completada; todas las fixtures serán revertidas.' resultado;
rollback;
