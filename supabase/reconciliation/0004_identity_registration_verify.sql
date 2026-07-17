-- Verificación transaccional de SITAA 0004 (Google OAuth).
-- Ejecutar sólo en un entorno de prueba después de aplicar 0004. Todas las
-- identidades son sintéticas y el archivo termina siempre en ROLLBACK.

begin;

create temporary table sitaa_0004_ids on commit drop as
select
  gen_random_uuid() division_id,
  gen_random_uuid() program_id,
  gen_random_uuid() inactive_program_id,
  gen_random_uuid() student_id,
  gen_random_uuid() professor_id,
  gen_random_uuid() duplicate_id,
  gen_random_uuid() inactive_id,
  gen_random_uuid() technical_id,
  gen_random_uuid() peer_tutor_id;

do $settings$
declare ids sitaa_0004_ids%rowtype;
begin
  select * into ids from sitaa_0004_ids;
  perform set_config('sitaa_test.division_id', ids.division_id::text, true);
  perform set_config('sitaa_test.program_id', ids.program_id::text, true);
  perform set_config('sitaa_test.inactive_program_id', ids.inactive_program_id::text, true);
  perform set_config('sitaa_test.student_id', ids.student_id::text, true);
  perform set_config('sitaa_test.professor_id', ids.professor_id::text, true);
  perform set_config('sitaa_test.duplicate_id', ids.duplicate_id::text, true);
  perform set_config('sitaa_test.inactive_id', ids.inactive_id::text, true);
  perform set_config('sitaa_test.technical_id', ids.technical_id::text, true);
  perform set_config('sitaa_test.peer_tutor_id', ids.peer_tutor_id::text, true);
end;
$settings$;

insert into public.divisions (id, code, name)
select division_id, 'sitaa_0004_' || replace(division_id::text, '-', ''),
       'División sintética 0004' from sitaa_0004_ids;

insert into public.academic_programs (id, division_id, code, name, is_active)
select program_id, division_id, 'sitaa_0004_' || replace(program_id::text, '-', ''),
       'Programa sintético 0004', true from sitaa_0004_ids;
insert into public.academic_programs (id, division_id, code, name, is_active)
select inactive_program_id, division_id,
       'sitaa_0004_inactive_' || replace(inactive_program_id::text, '-', ''),
       'Programa inactivo sintético 0004', false from sitaa_0004_ids;

create or replace function pg_temp.insert_auth_user(
  target_id uuid,
  target_email text,
  target_provider text,
  target_user_metadata jsonb default '{}'::jsonb,
  target_app_metadata jsonb default '{}'::jsonb,
  confirmed boolean default true
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

create or replace function pg_temp.expect_auth_rejection(
  target_provider text,
  target_user_metadata jsonb,
  target_app_metadata jsonb,
  expected_error text,
  expected_sqlstate text,
  expected_label text,
  confirmed boolean default true
) returns void
language plpgsql
set search_path = public, auth, pg_temp
as $$
declare
  target_id uuid := gen_random_uuid();
  caught_message text;
  caught_state text;
  rejected boolean := false;
begin
  begin
    perform pg_temp.insert_auth_user(
      target_id, 'rejected-' || target_id::text || '@example.invalid',
      target_provider, target_user_metadata, target_app_metadata, confirmed
    );
  exception when others then
    rejected := true;
    get stacked diagnostics caught_message = message_text, caught_state = returned_sqlstate;
  end;
  if not rejected or position(expected_error in coalesce(caught_message, '')) = 0
     or caught_state is distinct from expected_sqlstate then
    raise exception 'Contrato de rechazo incorrecto para %: %, SQLSTATE %.',
      expected_label, coalesce(caught_message, '<sin mensaje>'), coalesce(caught_state, '<nulo>');
  end if;
  if exists (select 1 from auth.users where id = target_id)
     or exists (select 1 from public.profiles where id = target_id) then
    raise exception 'El rechazo de % dejó un Auth user o profile huérfano.', expected_label;
  end if;
end;
$$;

-- Auth: Google válido crea exactamente un profile pending_registration.
select pg_temp.insert_auth_user(
  current_setting('sitaa_test.student_id')::uuid,
  'student-google-0004@example.invalid', 'google',
  '{"full_name":"Nombre provisional de Google","email_verified":true}'::jsonb
);
select pg_temp.insert_auth_user(
  current_setting('sitaa_test.professor_id')::uuid,
  'professor-google-0004@example.invalid', 'google',
  '{"full_name":"Profesor provisional","email_verified":true}'::jsonb
);

do $verify_pending_google_profiles$
begin
  if (select count(*) from public.profiles
      where id in (
        current_setting('sitaa_test.student_id')::uuid,
        current_setting('sitaa_test.professor_id')::uuid
      ) and account_kind = 'institutional'
        and account_status = 'pending_registration' and not is_active
        and activated_at is null and deactivated_at is null
        and person_type is null and primary_program_id is null
        and institutional_id_type is null and institutional_id_value is null
  ) <> 2 then
    raise exception 'Google no creó exactamente dos perfiles mínimos pendientes.';
  end if;
  if exists (
    select 1 from public.role_assignments where user_id in (
      current_setting('sitaa_test.student_id')::uuid,
      current_setting('sitaa_test.professor_id')::uuid
    )
  ) then raise exception 'Google asignó roles durante el alta.'; end if;
end;
$verify_pending_google_profiles$;

-- Proveedores y metadata no soportados se rechazan sin huérfanos.
select pg_temp.expect_auth_rejection(
  'email', '{}'::jsonb, '{}'::jsonb,
  'sitaa_public_password_signup_disabled', '42501', 'signup público con contraseña'
);
select pg_temp.expect_auth_rejection(
  'github', '{}'::jsonb, '{}'::jsonb,
  'sitaa_unsupported_auth_provider', '23514', 'OAuth no soportado'
);
select pg_temp.expect_auth_rejection(
  '', '{}'::jsonb, '{}'::jsonb,
  'sitaa_missing_or_invalid_account_metadata', '23514', 'provider ausente'
);
select pg_temp.expect_auth_rejection(
  'google', '{"sitaa_account_kind":"technical"}'::jsonb, '{}'::jsonb,
  'sitaa_public_technical_account_forbidden', '42501', 'technical desde metadata pública'
);
select pg_temp.expect_auth_rejection(
  'google', '{}'::jsonb,
  '{"sitaa_account_kind":"technical","sitaa_full_name":"Cuenta ambigua"}'::jsonb,
  'sitaa_ambiguous_account_metadata', '23514', 'Google y technical simultáneos'
);
select pg_temp.expect_auth_rejection(
  'email', '{}'::jsonb, '{"sitaa_account_kind":"institutional"}'::jsonb,
  'sitaa_unsupported_account_kind', '23514', 'account kind confiable no soportado'
);
select pg_temp.expect_auth_rejection(
  'google', '{}'::jsonb, '{}'::jsonb,
  'sitaa_google_email_not_verified', '23514', 'Google sin correo confirmado', false
);

-- Bootstrap técnico confiable: activo, completo y sin identidad académica.
select pg_temp.insert_auth_user(
  current_setting('sitaa_test.technical_id')::uuid,
  'technical-0004@example.invalid', 'email', '{}'::jsonb,
  '{"sitaa_account_kind":"technical","sitaa_full_name":"Cuenta técnica sintética"}'::jsonb,
  true
);
do $verify_technical$
begin
  if (select count(*) from public.profiles
      where id = current_setting('sitaa_test.technical_id')::uuid
        and account_kind = 'technical' and account_status = 'active' and is_active
        and person_type is null and primary_program_id is null
        and institutional_id_type is null and institutional_id_value is null
  ) <> 1 then raise exception 'El bootstrap técnico no creó exactamente un perfil válido.'; end if;
end;
$verify_technical$;

-- El RPC de finalización sólo es ejecutable por authenticated.
do $verify_completion_privileges$
begin
  if has_function_privilege(
       'anon', 'public.complete_own_google_registration(text,text,text,uuid)', 'EXECUTE'
     ) or not has_function_privilege(
       'authenticated', 'public.complete_own_google_registration(text,text,text,uuid)', 'EXECUTE'
     ) then
    raise exception 'Los privilegios del RPC autenticado no respetan el mínimo requerido.';
  end if;
end;
$verify_completion_privileges$;

-- Completar alumno y profesor: 1 y 50 dígitos, identidad derivada y cero roles.
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.student_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.student_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
select public.complete_own_google_registration(
  'student', 'Alumno sintético 0004', '7', current_setting('sitaa_test.program_id')::uuid
);
reset role;

select set_config('request.jwt.claim.sub', current_setting('sitaa_test.professor_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.professor_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
select public.complete_own_google_registration(
  'professor', repeat('P', 200), repeat('0', 49) || '7',
  current_setting('sitaa_test.program_id')::uuid
);
reset role;

do $verify_completed_profiles$
begin
  if (select count(*) from public.profiles
      where id = current_setting('sitaa_test.student_id')::uuid
        and account_status = 'active' and is_active
        and person_type = 'student' and institutional_id_type = 'student_account'
        and institutional_id_value = '7'
        and full_name = 'Alumno sintético 0004'
        and primary_program_id = current_setting('sitaa_test.program_id')::uuid
  ) <> 1 then raise exception 'El alumno no completó la identidad esperada.'; end if;
  if (select count(*) from public.profiles
      where id = current_setting('sitaa_test.professor_id')::uuid
        and account_status = 'active' and is_active
        and person_type = 'professor' and institutional_id_type = 'worker_number'
        and institutional_id_value = repeat('0', 49) || '7'
        and char_length(institutional_id_value) = 50
  ) <> 1 then raise exception 'El profesor no completó la identidad esperada.'; end if;
  if exists (
    select 1 from public.role_assignments where user_id in (
      current_setting('sitaa_test.student_id')::uuid,
      current_setting('sitaa_test.professor_id')::uuid
    )
  ) then raise exception 'La finalización creó roles académicos.'; end if;
end;
$verify_completed_profiles$;

-- Un perfil activo no puede reescribirse mediante completion.
do $verify_active_not_rewritten$
declare before_profile jsonb; rejected boolean := false;
begin
  select to_jsonb(p) - 'updated_at' into before_profile from public.profiles p
  where id = current_setting('sitaa_test.student_id')::uuid;
  begin
    perform public.complete_own_google_registration(
      'professor', 'Nombre alterado', '999', current_setting('sitaa_test.program_id')::uuid
    );
  exception when others then rejected := true;
  end;
  if not rejected or before_profile is distinct from (
    select to_jsonb(p) - 'updated_at' from public.profiles p
    where id = current_setting('sitaa_test.student_id')::uuid
  ) then raise exception 'Un perfil activo fue reescrito por completion.'; end if;
end;
$verify_active_not_rewritten$;

-- Perfil pendiente adicional para validaciones posteriores a autenticación.
select pg_temp.insert_auth_user(
  current_setting('sitaa_test.inactive_id')::uuid,
  'validation-0004@example.invalid', 'google',
  '{"full_name":"Cuenta pendiente"}'::jsonb
);
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.inactive_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.inactive_id'), 'role', 'authenticated'
)::text, true);
do $verify_invalid_completion_inputs$
declare rejected boolean; message text;
begin
  rejected := false; message := null;
  begin perform public.complete_own_google_registration(
    'worker', 'Nombre válido', '1234', current_setting('sitaa_test.program_id')::uuid
  ); exception when others then rejected := true; get stacked diagnostics message = message_text; end;
  if not rejected or position('sitaa_invalid_registration_type' in coalesce(message, '')) = 0 then
    raise exception 'Se aceptó un tipo de registro no soportado.';
  end if;

  rejected := false; message := null;
  begin perform public.complete_own_google_registration(
    'student', 'N', '1234', current_setting('sitaa_test.program_id')::uuid
  ); exception when others then rejected := true; get stacked diagnostics message = message_text; end;
  if not rejected or position('sitaa_invalid_full_name' in coalesce(message, '')) = 0 then
    raise exception 'Se aceptó un nombre de un carácter.';
  end if;

  rejected := false; message := null;
  begin perform public.complete_own_google_registration(
    'student', repeat('N', 201), '1234', current_setting('sitaa_test.program_id')::uuid
  ); exception when others then rejected := true; get stacked diagnostics message = message_text; end;
  if not rejected or position('sitaa_invalid_full_name' in coalesce(message, '')) = 0 then
    raise exception 'Se aceptó un nombre de 201 caracteres.';
  end if;

  rejected := false;
  begin perform public.complete_own_google_registration(
    'student', 'Nombre válido', repeat('9', 51), current_setting('sitaa_test.program_id')::uuid
  ); exception when others then rejected := true; get stacked diagnostics message = message_text; end;
  if not rejected or position('sitaa_identifier_too_long' in coalesce(message, '')) = 0 then
    raise exception 'Se aceptó un identificador de 51 dígitos.';
  end if;

  rejected := false; message := null;
  begin perform public.complete_own_google_registration(
    'student', 'Nombre válido', '12A3', current_setting('sitaa_test.program_id')::uuid
  ); exception when others then rejected := true; get stacked diagnostics message = message_text; end;
  if not rejected or position('sitaa_invalid_institutional_identifier' in coalesce(message, '')) = 0 then
    raise exception 'Se aceptaron caracteres no numéricos.';
  end if;

  rejected := false; message := null;
  begin perform public.complete_own_google_registration(
    'student', 'Nombre válido', '1234', current_setting('sitaa_test.inactive_program_id')::uuid
  ); exception when others then rejected := true; get stacked diagnostics message = message_text; end;
  if not rejected or position('sitaa_invalid_registration_program' in coalesce(message, '')) = 0 then
    raise exception 'Se aceptó un programa inactivo.';
  end if;

  rejected := false;
  begin perform public.complete_own_google_registration(
    'student', 'Nombre válido', '1234', gen_random_uuid()
  ); exception when others then rejected := true; end;
  if not rejected then raise exception 'Se aceptó un programa inexistente.'; end if;

  if not exists (
    select 1 from public.profiles where id = current_setting('sitaa_test.inactive_id')::uuid
      and account_status = 'pending_registration' and not is_active
      and person_type is null and institutional_id_value is null
  ) then raise exception 'Una validación fallida alteró el perfil pendiente.'; end if;
end;
$verify_invalid_completion_inputs$;

-- Un tercer perfil comprueba ceros iniciales y conserva permisos de tutor par.
select pg_temp.insert_auth_user(
  current_setting('sitaa_test.peer_tutor_id')::uuid,
  'peer-0004@example.invalid', 'google', '{}'::jsonb
);
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.peer_tutor_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.peer_tutor_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
select public.complete_own_google_registration(
  'student', 'Tutor par sintético', '00007777', current_setting('sitaa_test.program_id')::uuid
);
reset role;

-- Duplicado: la unicidad se comprueba sólo después de autenticar al usuario.
select pg_temp.insert_auth_user(
  current_setting('sitaa_test.duplicate_id')::uuid,
  'second-duplicate-0004@example.invalid', 'google', '{}'::jsonb
);
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.duplicate_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.duplicate_id'), 'role', 'authenticated'
)::text, true);

do $verify_duplicate_completion$
declare rejected boolean := false; message text;
begin
  begin
    perform public.complete_own_google_registration(
      'student', 'Segundo duplicado', '00007777', current_setting('sitaa_test.program_id')::uuid
    );
  exception when others then
    rejected := true; get stacked diagnostics message = message_text;
  end;
  if not rejected or position('sitaa_identifier_conflict' in coalesce(message, '')) = 0
     or not exists (
       select 1 from public.profiles
       where id = current_setting('sitaa_test.duplicate_id')::uuid
         and account_status = 'pending_registration' and not is_active
     ) then raise exception 'El duplicado no preservó el profile pendiente.'; end if;
end;
$verify_duplicate_completion$;

insert into public.role_assignments (
  user_id, role_code, scope_type, service_area, program_id, is_active, starts_at
) values (
  current_setting('sitaa_test.duplicate_id')::uuid,
  'professor', 'program', 'both', current_setting('sitaa_test.program_id')::uuid,
  true, current_date
);
set local role authenticated;
do $verify_pending_cannot_operate$
begin
  if public.can_create_activity(
    'program', current_setting('sitaa_test.program_id')::uuid,
    current_setting('sitaa_test.division_id')::uuid, 'tutoring'
  ) then raise exception 'Un profile pending_registration operó con una asignación.'; end if;
end;
$verify_pending_cannot_operate$;
reset role;

-- Un usuario sin identidad Google vinculada no puede completar.
update auth.users
set raw_app_meta_data = '{"provider":"email","providers":["email"]}'::jsonb
where id = current_setting('sitaa_test.inactive_id')::uuid;

select set_config('request.jwt.claim.sub', current_setting('sitaa_test.inactive_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.inactive_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
do $verify_google_required$
declare rejected boolean := false; message text;
begin
  begin perform public.complete_own_google_registration(
    'student', 'Sin Google', '8888', current_setting('sitaa_test.program_id')::uuid
  ); exception when others then rejected := true; get stacked diagnostics message = message_text; end;
  if not rejected or position('sitaa_google_identity_required' in coalesce(message, '')) = 0 then
    raise exception 'Un usuario sin Google completó registro institucional.';
  end if;
end;
$verify_google_required$;
reset role;

-- Una cuenta inactiva no se reactiva.
update auth.users
set raw_app_meta_data = '{"provider":"google","providers":["google"]}'::jsonb
where id = current_setting('sitaa_test.inactive_id')::uuid;
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.inactive_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.inactive_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
select public.complete_own_google_registration(
  'professor', 'Profesor que será inactivo', '6666',
  current_setting('sitaa_test.program_id')::uuid
);
reset role;
update public.profiles set account_status = 'inactive'
where id = current_setting('sitaa_test.inactive_id')::uuid;
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.inactive_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.inactive_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;

do $verify_inactive_not_completed$
declare rejected boolean := false;
begin
  begin
    perform public.complete_own_google_registration(
      'professor', 'Profesor reactivado', '5555', current_setting('sitaa_test.program_id')::uuid
    );
  exception when others then rejected := true;
  end;
  if not rejected then raise exception 'Una cuenta inactiva fue reactivada por completion.'; end if;
end;
$verify_inactive_not_completed$;
reset role;

-- Vincular Google a un perfil existente no reescribe identidad canónica.
create temporary table sitaa_0004_profile_before_link on commit drop as
select to_jsonb(p) - 'updated_at' profile_snapshot
from public.profiles p where id = current_setting('sitaa_test.student_id')::uuid;

update auth.users
set raw_app_meta_data = raw_app_meta_data || '{"provider":"google","providers":["email","google"]}'::jsonb
where id = current_setting('sitaa_test.student_id')::uuid;
do $verify_inactive_and_linking$
declare before_profile jsonb; after_profile jsonb;
begin
  select profile_snapshot into before_profile from sitaa_0004_profile_before_link;
  select to_jsonb(p) - 'updated_at' into after_profile from public.profiles p
  where id = current_setting('sitaa_test.student_id')::uuid;
  if before_profile is distinct from after_profile then
    raise exception 'Vincular Google reescribió la identidad institucional activa.';
  end if;
  if not exists (select 1 from public.profiles
    where id = current_setting('sitaa_test.inactive_id')::uuid
      and account_status = 'inactive' and not is_active and deactivated_at is not null
  ) then raise exception 'La cuenta inactiva perdió su estado.'; end if;
end;
$verify_inactive_and_linking$;

-- Sin roles, alumno/profesor no crean actividades; asignaciones existentes sí.
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.student_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.student_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
do $verify_student_without_role$
begin
  if public.can_create_activity(
    'program', current_setting('sitaa_test.program_id')::uuid,
    current_setting('sitaa_test.division_id')::uuid, 'tutoring'
  ) then raise exception 'Un alumno nuevo pudo crear actividades.'; end if;
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
  if public.can_create_activity(
    'program', current_setting('sitaa_test.program_id')::uuid,
    current_setting('sitaa_test.division_id')::uuid, 'tutoring'
  ) then raise exception 'Un profesor nuevo pudo crear actividades sin asignación.'; end if;
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
  current_setting('sitaa_test.peer_tutor_id')::uuid,
  'peer_tutor', 'program', 'both', current_setting('sitaa_test.program_id')::uuid,
  true, current_date
);

select set_config('request.jwt.claim.sub', current_setting('sitaa_test.professor_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.professor_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
do $verify_existing_professor_assignment$
begin
  if not public.can_create_activity(
    'program', current_setting('sitaa_test.program_id')::uuid,
    current_setting('sitaa_test.division_id')::uuid, 'tutoring'
  ) then raise exception 'La asignación vigente de profesor dejó de conceder su permiso.'; end if;
end;
$verify_existing_professor_assignment$;
reset role;

select set_config('request.jwt.claim.sub', current_setting('sitaa_test.peer_tutor_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.peer_tutor_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
do $verify_existing_peer_tutor_assignment$
begin
  if not public.can_create_activity(
    'program', current_setting('sitaa_test.program_id')::uuid,
    current_setting('sitaa_test.division_id')::uuid, 'tutoring'
  ) then raise exception 'La asignación vigente de tutor par dejó de conceder su permiso.'; end if;
end;
$verify_existing_peer_tutor_assignment$;
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

select 'Verificación 0004 Google completada; todas las fixtures serán revertidas.' resultado;
rollback;
