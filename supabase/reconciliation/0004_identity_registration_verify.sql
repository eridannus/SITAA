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

create or replace function pg_temp.expect_intent_rejection(
  target_person_type text,
  target_name text,
  target_identifier text,
  target_program uuid,
  expected_error text,
  expected_label text
) returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare caught_message text; rejected boolean := false;
begin
  begin
    perform public.create_registration_intent(
      target_person_type, target_name, target_identifier, target_program
    );
  exception when others then
    rejected := true;
    get stacked diagnostics caught_message = message_text;
  end;
  if not rejected or position(expected_error in coalesce(caught_message, '')) = 0 then
    raise exception 'El intent inválido % no respetó el contrato.', expected_label;
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

-- Intent: tokens opacos, hash persistido, límites, programa y privilegios.
select set_config('sitaa_test.student_token', public.create_registration_intent(
  'student', repeat('A', 200), '00001234', current_setting('sitaa_test.program_id')::uuid
), true);
select set_config('sitaa_test.professor_token', public.create_registration_intent(
  'professor', 'Profesor sintético 0004', '00001234', current_setting('sitaa_test.program_id')::uuid
), true);

do $verify_intent_storage$
declare raw_token text := current_setting('sitaa_test.student_token');
begin
  if char_length(raw_token) < 40 then raise exception 'El token de intent no es suficientemente opaco.'; end if;
  if (select count(*) from public.registration_intents
      where token_hash = encode(extensions.digest(raw_token, 'sha256'), 'hex')
        and token_hash <> raw_token and expires_at > now()
        and consumed_at is null and consumed_by is null
  ) <> 1 then raise exception 'El intent no almacenó exclusivamente la huella esperada.'; end if;
  if has_table_privilege('anon', 'public.registration_intents', 'SELECT')
     or has_table_privilege('authenticated', 'public.registration_intents', 'SELECT')
     or has_table_privilege('anon', 'public.registration_intents', 'INSERT')
     or has_table_privilege('authenticated', 'public.registration_intents', 'UPDATE')
     or has_table_privilege('anon', 'public.registration_intents', 'DELETE')
     or has_table_privilege('authenticated', 'public.registration_intents', 'DELETE') then
    raise exception 'anon/authenticated conserva acceso directo a registration_intents.';
  end if;
  if not has_function_privilege('anon',
       'public.create_registration_intent(text,text,text,uuid)', 'EXECUTE')
     or not has_function_privilege('authenticated',
       'public.complete_own_google_registration(text)', 'EXECUTE') then
    raise exception 'Faltan grants mínimos para los RPC de registro.';
  end if;
end;
$verify_intent_storage$;

select pg_temp.expect_intent_rejection(
  'student', 'Nombre válido', 'ABC', current_setting('sitaa_test.program_id')::uuid,
  'sitaa_invalid_institutional_identifier', 'identificador no numérico'
);
select pg_temp.expect_intent_rejection(
  'student', 'Nombre válido', repeat('9', 51), current_setting('sitaa_test.program_id')::uuid,
  'sitaa_identifier_too_long', 'identificador de 51 dígitos'
);
select pg_temp.expect_intent_rejection(
  'student', 'N', '00009001', current_setting('sitaa_test.program_id')::uuid,
  'sitaa_invalid_full_name', 'nombre de un carácter'
);
select pg_temp.expect_intent_rejection(
  'student', repeat('N', 201), '00009002', current_setting('sitaa_test.program_id')::uuid,
  'sitaa_invalid_full_name', 'nombre de 201 caracteres'
);
select pg_temp.expect_intent_rejection(
  'student', 'Nombre válido', '00009003', current_setting('sitaa_test.inactive_program_id')::uuid,
  'sitaa_invalid_registration_program', 'programa inactivo'
);
select pg_temp.expect_intent_rejection(
  'student', 'Nombre válido', '00009004', gen_random_uuid(),
  'sitaa_invalid_registration_program', 'programa inexistente'
);

-- Completar alumno y profesor: identidad derivada, ceros y cero roles.
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.student_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.student_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
select public.complete_own_google_registration(current_setting('sitaa_test.student_token'));
reset role;

select set_config('request.jwt.claim.sub', current_setting('sitaa_test.professor_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.professor_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
select public.complete_own_google_registration(current_setting('sitaa_test.professor_token'));
reset role;

do $verify_completed_profiles$
begin
  if (select count(*) from public.profiles
      where id = current_setting('sitaa_test.student_id')::uuid
        and account_status = 'active' and is_active
        and person_type = 'student' and institutional_id_type = 'student_account'
        and institutional_id_value = '00001234'
        and full_name = repeat('A', 200)
        and primary_program_id = current_setting('sitaa_test.program_id')::uuid
  ) <> 1 then raise exception 'El alumno no completó la identidad esperada.'; end if;
  if (select count(*) from public.profiles
      where id = current_setting('sitaa_test.professor_id')::uuid
        and account_status = 'active' and is_active
        and person_type = 'professor' and institutional_id_type = 'worker_number'
        and institutional_id_value = '00001234'
  ) <> 1 then raise exception 'El profesor no completó la identidad esperada.'; end if;
  if exists (
    select 1 from public.role_assignments where user_id in (
      current_setting('sitaa_test.student_id')::uuid,
      current_setting('sitaa_test.professor_id')::uuid
    )
  ) then raise exception 'La finalización creó roles académicos.'; end if;
end;
$verify_completed_profiles$;

-- Un token consumido no se reutiliza por el mismo usuario ni por otro.
do $verify_one_time_token$
declare rejected boolean := false;
begin
  begin
    perform public.complete_own_google_registration(current_setting('sitaa_test.student_token'));
  exception when others then rejected := true;
  end;
  if not rejected then raise exception 'Un token consumido pudo reutilizarse.'; end if;
end;
$verify_one_time_token$;

-- Intent expirado: el profile permanece pending_registration.
select pg_temp.insert_auth_user(
  current_setting('sitaa_test.inactive_id')::uuid,
  'expired-intent-0004@example.invalid', 'google',
  '{"full_name":"Cuenta pendiente"}'::jsonb
);
select set_config('sitaa_test.expired_token', public.create_registration_intent(
  'student', 'Intent expirado', '00008001', current_setting('sitaa_test.program_id')::uuid
), true);
update public.registration_intents set expires_at = now() - interval '1 second'
where token_hash = encode(extensions.digest(current_setting('sitaa_test.expired_token'), 'sha256'), 'hex');
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.inactive_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.inactive_id'), 'role', 'authenticated'
)::text, true);
do $verify_expired_intent$
declare rejected boolean := false;
begin
  begin
    perform public.complete_own_google_registration(current_setting('sitaa_test.expired_token'));
  exception when others then rejected := true;
  end;
  if not rejected or not exists (
    select 1 from public.profiles
    where id = current_setting('sitaa_test.inactive_id')::uuid
      and account_status = 'pending_registration' and not is_active
  ) then raise exception 'El intent expirado activó o alteró el profile.'; end if;
end;
$verify_expired_intent$;

-- Carrera de duplicados: dos intents se crean; sólo el primero puede completar.
select set_config('sitaa_test.duplicate_token', public.create_registration_intent(
  'student', 'Segundo duplicado', '00007777', current_setting('sitaa_test.program_id')::uuid
), true);
select set_config('sitaa_test.peer_token', public.create_registration_intent(
  'student', 'Primer duplicado', '00007777', current_setting('sitaa_test.program_id')::uuid
), true);
select pg_temp.insert_auth_user(
  current_setting('sitaa_test.peer_tutor_id')::uuid,
  'first-duplicate-0004@example.invalid', 'google', '{}'::jsonb
);
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.peer_tutor_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.peer_tutor_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
select public.complete_own_google_registration(current_setting('sitaa_test.peer_token'));
reset role;

select pg_temp.insert_auth_user(
  current_setting('sitaa_test.duplicate_id')::uuid,
  'second-duplicate-0004@example.invalid', 'google', '{}'::jsonb
);
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.duplicate_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.duplicate_id'), 'role', 'authenticated'
)::text, true);

do $verify_different_user_cannot_reuse_token$
declare rejected boolean := false;
begin
  begin
    perform public.complete_own_google_registration(current_setting('sitaa_test.student_token'));
  exception when others then rejected := true;
  end;
  if not rejected then raise exception 'Otro usuario reutilizó un intent consumido.'; end if;
end;
$verify_different_user_cannot_reuse_token$;

do $verify_duplicate_completion$
declare rejected boolean := false; message text;
begin
  begin
    perform public.complete_own_google_registration(current_setting('sitaa_test.duplicate_token'));
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

-- Una cuenta inactiva no se reactiva y vincular Google no reescribe identidad.
update public.profiles set account_status = 'inactive'
where id = current_setting('sitaa_test.duplicate_id')::uuid;

do $verify_inactive_not_completed$
declare rejected boolean := false;
begin
  begin
    perform public.complete_own_google_registration(current_setting('sitaa_test.duplicate_token'));
  exception when others then rejected := true;
  end;
  if not rejected then raise exception 'Una cuenta inactiva fue reactivada por completion.'; end if;
end;
$verify_inactive_not_completed$;

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
  if not exists (
    select 1 from public.profiles
    where id = current_setting('sitaa_test.duplicate_id')::uuid
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
