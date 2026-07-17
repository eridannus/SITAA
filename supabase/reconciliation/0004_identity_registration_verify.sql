-- Verificación transaccional de SITAA 0004.
-- Ejecutar sólo después de aplicar 0004 en un entorno de prueba. Usa datos
-- sintéticos, no depende de usuarios reales y termina siempre en ROLLBACK.

begin;

create temporary table sitaa_0004_ids on commit drop as
select
  gen_random_uuid() student_id,
  gen_random_uuid() professor_id,
  gen_random_uuid() inactive_id,
  gen_random_uuid() technical_id,
  gen_random_uuid() authorized_professor_id,
  gen_random_uuid() division_id,
  gen_random_uuid() program_id;

do $settings$
declare ids sitaa_0004_ids%rowtype;
begin
  select * into ids from sitaa_0004_ids;
  perform set_config('sitaa_test.student_id', ids.student_id::text, true);
  perform set_config('sitaa_test.professor_id', ids.professor_id::text, true);
  perform set_config('sitaa_test.inactive_id', ids.inactive_id::text, true);
  perform set_config('sitaa_test.technical_id', ids.technical_id::text, true);
  perform set_config('sitaa_test.authorized_professor_id', ids.authorized_professor_id::text, true);
  perform set_config('sitaa_test.division_id', ids.division_id::text, true);
  perform set_config('sitaa_test.program_id', ids.program_id::text, true);
end;
$settings$;

insert into public.divisions (id, code, name)
select division_id, 'sitaa_0004_' || replace(division_id::text, '-', ''), 'División sintética 0004'
from sitaa_0004_ids;

insert into public.academic_programs (id, division_id, code, name, is_active)
select program_id, division_id, 'sitaa_0004_' || replace(program_id::text, '-', ''), 'Programa sintético 0004', true
from sitaa_0004_ids;

create or replace function pg_temp.insert_registration_user(
  target_id uuid,
  target_email text,
  registration_type text,
  identifier_value text,
  target_program uuid,
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
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object(
      'sitaa_registration_type', registration_type,
      'full_name', 'Identidad sintética 0004',
      'primary_program_id', target_program::text,
      'institutional_id_value', identifier_value
    ),
    now(), now()
  );
end;
$$;

create or replace function pg_temp.expect_registration_rejection(
  registration_type text,
  identifier_value text,
  expected_label text
) returns void
language plpgsql
set search_path = public, auth, pg_temp
as $$
declare rejected boolean := false;
begin
  begin
    perform pg_temp.insert_registration_user(
      gen_random_uuid(),
      'rejected-' || gen_random_uuid()::text || '@example.invalid',
      registration_type,
      identifier_value,
      current_setting('sitaa_test.program_id')::uuid,
      false
    );
  exception when others then
    rejected := true;
  end;
  if not rejected then
    raise exception '0004 aceptó un registro inválido: %.', expected_label;
  end if;
end;
$$;

-- Altas institucionales válidas; el mismo valor se permite entre tipos.
select pg_temp.insert_registration_user(
  current_setting('sitaa_test.student_id')::uuid,
  'student-0004@example.invalid', 'student', '00123456',
  current_setting('sitaa_test.program_id')::uuid, false
);
select pg_temp.insert_registration_user(
  current_setting('sitaa_test.professor_id')::uuid,
  'professor-0004@example.invalid', 'professor', '00123456',
  current_setting('sitaa_test.program_id')::uuid, false
);

do $verify_valid_profiles$
begin
  if not exists (
    select 1 from public.profiles
    where id = current_setting('sitaa_test.student_id')::uuid
      and account_kind = 'institutional'
      and account_status = 'pending_verification'
      and person_type = 'student'
      and institutional_id_type = 'student_account'
      and institutional_id_value = '00123456'
      and pg_typeof(institutional_id_value) = 'text'::regtype
  ) then raise exception 'No se creó correctamente el perfil alumno pendiente.'; end if;

  if not exists (
    select 1 from public.profiles
    where id = current_setting('sitaa_test.professor_id')::uuid
      and account_kind = 'institutional'
      and account_status = 'pending_verification'
      and person_type = 'professor'
      and institutional_id_type = 'worker_number'
      and institutional_id_value = '00123456'
  ) then raise exception 'No se creó correctamente el perfil profesor pendiente.'; end if;

  if exists (
    select 1 from public.role_assignments
    where user_id in (
      current_setting('sitaa_test.student_id')::uuid,
      current_setting('sitaa_test.professor_id')::uuid
    )
  ) then raise exception 'El registro público creó asignaciones de rol.'; end if;
end;
$verify_valid_profiles$;

-- Formatos inválidos y duplicado dentro del mismo tipo.
select pg_temp.expect_registration_rejection('student', 'ABC123', 'letras');
select pg_temp.expect_registration_rejection('student', '12 34', 'espacios');
select pg_temp.expect_registration_rejection('student', '12-34', 'guion');
select pg_temp.expect_registration_rejection('student', '12.34', 'puntuación');
select pg_temp.expect_registration_rejection('student', '00123456', 'duplicado del mismo tipo');
select pg_temp.expect_registration_rejection('technical', '00999', 'technical desde metadata pública');

-- Cuenta técnica: sólo app_metadata confiable, sin identidad institucional.
insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select technical_id, 'authenticated', 'authenticated', 'technical-0004@example.invalid', '', now(),
       '{"provider":"email","providers":["email"],"sitaa_account_kind":"technical","sitaa_full_name":"Cuenta técnica sintética"}'::jsonb,
       '{}'::jsonb, now(), now()
from sitaa_0004_ids;

do $verify_technical$
begin
  if not exists (
    select 1 from public.profiles
    where id = current_setting('sitaa_test.technical_id')::uuid
      and account_kind = 'technical' and account_status = 'active'
      and person_type is null and primary_program_id is null
      and institutional_id_type is null and institutional_id_value is null
  ) then raise exception 'La cuenta técnica confiable no cumple el contrato.'; end if;
end;
$verify_technical$;

do $verify_account_exclusivity$
declare
  institutional_auth_id uuid := gen_random_uuid();
  technical_auth_id uuid := gen_random_uuid();
  institutional_rejected boolean := false;
  technical_rejected boolean := false;
begin
  insert into auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values
    (institutional_auth_id, 'authenticated', 'authenticated',
     'incomplete-' || institutional_auth_id::text || '@example.invalid', '', now(),
     '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now()),
    (technical_auth_id, 'authenticated', 'authenticated',
     'invalid-technical-' || technical_auth_id::text || '@example.invalid', '', now(),
     '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now());

  begin
    insert into public.profiles (
      id, email, full_name, account_kind, account_status, is_active,
      person_type, institutional_id_type, institutional_id_value, activated_at
    ) values (
      institutional_auth_id, 'incomplete-' || institutional_auth_id::text || '@example.invalid',
      'Institucional incompleta', 'institutional', 'active', true,
      'student', 'student_account', '00007777', now()
    );
  exception when check_violation then institutional_rejected := true;
  end;

  begin
    insert into public.profiles (
      id, email, full_name, account_kind, account_status, is_active,
      person_type, institutional_id_type, institutional_id_value,
      primary_program_id, activated_at
    ) values (
      technical_auth_id, 'invalid-technical-' || technical_auth_id::text || '@example.invalid',
      'Técnica inválida', 'technical', 'active', true,
      'professor', 'worker_number', '00008888',
      current_setting('sitaa_test.program_id')::uuid, now()
    );
  exception when check_violation then technical_rejected := true;
  end;

  if not institutional_rejected then
    raise exception 'Una cuenta institucional incompleta superó los constraints.';
  end if;
  if not technical_rejected then
    raise exception 'Una cuenta técnica con identidad institucional superó los constraints.';
  end if;
end;
$verify_account_exclusivity$;

-- Confirmación activa pending, pero nunca reactiva inactive.
update auth.users set email_confirmed_at = now()
where id = current_setting('sitaa_test.student_id')::uuid;

select pg_temp.insert_registration_user(
  current_setting('sitaa_test.inactive_id')::uuid,
  'inactive-0004@example.invalid', 'student', '00987654',
  current_setting('sitaa_test.program_id')::uuid, false
);
update public.profiles set account_status = 'inactive'
where id = current_setting('sitaa_test.inactive_id')::uuid;
update auth.users set email_confirmed_at = now()
where id = current_setting('sitaa_test.inactive_id')::uuid;

do $verify_activation$
begin
  if not exists (
    select 1 from public.profiles
    where id = current_setting('sitaa_test.student_id')::uuid
      and account_status = 'active' and is_active = true and activated_at is not null
  ) then raise exception 'La confirmación no activó el perfil pendiente.'; end if;
  if not exists (
    select 1 from public.profiles
    where id = current_setting('sitaa_test.inactive_id')::uuid
      and account_status = 'inactive' and is_active = false
  ) then raise exception 'La confirmación reactivó indebidamente un perfil inactivo.'; end if;
end;
$verify_activation$;

-- Autoservicio: nombre permitido; identidad y estado prohibidos.
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.student_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.student_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;

update public.profiles set full_name = 'Nombre actualizado sintético'
where id = current_setting('sitaa_test.student_id')::uuid;

do $verify_self_update$
declare rejected boolean := false;
begin
  if not exists (
    select 1 from public.profiles
    where id = current_setting('sitaa_test.student_id')::uuid
      and full_name = 'Nombre actualizado sintético'
  ) then
    raise exception 'El usuario no pudo actualizar el nombre aprobado.';
  end if;
  begin
    update public.profiles set institutional_id_value = '55555555'
    where id = current_setting('sitaa_test.student_id')::uuid;
  exception when insufficient_privilege then rejected := true;
  end;
  if not rejected then raise exception 'El usuario pudo modificar su identificador.'; end if;
end;
$verify_self_update$;

do $verify_no_base_permissions$
begin
  if public.can_create_activity(
    'program', current_setting('sitaa_test.program_id')::uuid,
    current_setting('sitaa_test.division_id')::uuid, 'tutoring'
  ) then raise exception 'Un alumno nuevo obtuvo permiso de creación.'; end if;
end;
$verify_no_base_permissions$;
reset role;

-- Profesor sin roles tampoco crea; una asignación existente conserva su efecto.
select pg_temp.insert_registration_user(
  current_setting('sitaa_test.authorized_professor_id')::uuid,
  'authorized-0004@example.invalid', 'professor', '00004444',
  current_setting('sitaa_test.program_id')::uuid, true
);

select set_config('request.jwt.claim.sub', current_setting('sitaa_test.authorized_professor_id'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', current_setting('sitaa_test.authorized_professor_id'), 'role', 'authenticated'
)::text, true);
set local role authenticated;
do $verify_professor_without_role$
begin
  if public.can_create_activity(
    'program', current_setting('sitaa_test.program_id')::uuid,
    current_setting('sitaa_test.division_id')::uuid, 'tutoring'
  ) then raise exception 'Un profesor nuevo obtuvo permiso sin asignación.'; end if;
end;
$verify_professor_without_role$;
reset role;

insert into public.role_assignments (
  user_id, role_code, scope_type, service_area, program_id, is_active, starts_at
) values (
  current_setting('sitaa_test.authorized_professor_id')::uuid,
  'professor', 'program', 'both', current_setting('sitaa_test.program_id')::uuid,
  true, current_date
);

set local role authenticated;
do $verify_existing_assignment$
begin
  if not public.can_create_activity(
    'program', current_setting('sitaa_test.program_id')::uuid,
    current_setting('sitaa_test.division_id')::uuid, 'tutoring'
  ) then raise exception 'Una asignación actual dejó de conceder su permiso existente.'; end if;
end;
$verify_existing_assignment$;
reset role;

-- Contratos de 0002/0003 que no deben debilitarse.
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

select 'Verificación 0004 completada; todas las fixtures serán revertidas.' as resultado;
rollback;
