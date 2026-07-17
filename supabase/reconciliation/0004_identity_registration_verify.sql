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
  gen_random_uuid() short_identifier_id,
  gen_random_uuid() max_identifier_id,
  gen_random_uuid() max_name_id,
  gen_random_uuid() authorized_professor_id,
  gen_random_uuid() peer_tutor_id,
  gen_random_uuid() division_id,
  gen_random_uuid() program_id,
  gen_random_uuid() inactive_program_id;

do $settings$
declare ids sitaa_0004_ids%rowtype;
begin
  select * into ids from sitaa_0004_ids;
  perform set_config('sitaa_test.student_id', ids.student_id::text, true);
  perform set_config('sitaa_test.professor_id', ids.professor_id::text, true);
  perform set_config('sitaa_test.inactive_id', ids.inactive_id::text, true);
  perform set_config('sitaa_test.technical_id', ids.technical_id::text, true);
  perform set_config('sitaa_test.short_identifier_id', ids.short_identifier_id::text, true);
  perform set_config('sitaa_test.max_identifier_id', ids.max_identifier_id::text, true);
  perform set_config('sitaa_test.max_name_id', ids.max_name_id::text, true);
  perform set_config('sitaa_test.authorized_professor_id', ids.authorized_professor_id::text, true);
  perform set_config('sitaa_test.peer_tutor_id', ids.peer_tutor_id::text, true);
  perform set_config('sitaa_test.division_id', ids.division_id::text, true);
  perform set_config('sitaa_test.program_id', ids.program_id::text, true);
  perform set_config('sitaa_test.inactive_program_id', ids.inactive_program_id::text, true);
end;
$settings$;

insert into public.divisions (id, code, name)
select division_id, 'sitaa_0004_' || replace(division_id::text, '-', ''), 'División sintética 0004'
from sitaa_0004_ids;

insert into public.academic_programs (id, division_id, code, name, is_active)
select program_id, division_id, 'sitaa_0004_' || replace(program_id::text, '-', ''), 'Programa sintético 0004', true
from sitaa_0004_ids;

insert into public.academic_programs (id, division_id, code, name, is_active)
select inactive_program_id, division_id,
       'sitaa_0004_inactive_' || replace(inactive_program_id::text, '-', ''),
       'Programa inactivo sintético 0004', false
from sitaa_0004_ids;

create or replace function pg_temp.insert_registration_user(
  target_id uuid,
  target_email text,
  registration_type text,
  identifier_value text,
  target_program uuid,
  confirmed boolean default false,
  target_name text default 'Identidad sintética 0004'
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
      'full_name', target_name,
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
  expected_error text,
  expected_sqlstate text,
  expected_label text,
  target_program uuid default null,
  target_name text default 'Identidad sintética 0004',
  target_email text default null
) returns void
language plpgsql
set search_path = public, auth, pg_temp
as $$
declare
  target_id uuid := gen_random_uuid();
  actual_email text := coalesce(
    target_email,
    'rejected-' || target_id::text || '@example.invalid'
  );
  rejected boolean := false;
  caught_message text;
  caught_state text;
begin
  begin
    perform pg_temp.insert_registration_user(
      target_id,
      actual_email,
      registration_type,
      identifier_value,
      coalesce(target_program, current_setting('sitaa_test.program_id')::uuid),
      false,
      target_name
    );
  exception when others then
    rejected := true;
    get stacked diagnostics
      caught_message = message_text,
      caught_state = returned_sqlstate;
  end;
  if not rejected then
    raise exception '0004 aceptó un registro inválido: %.', expected_label;
  end if;
  if position(expected_error in coalesce(caught_message, '')) = 0 then
    raise exception '0004 rechazó % con una excepción distinta del contrato: %.',
      expected_label, coalesce(caught_message, '<sin mensaje>');
  end if;
  if caught_state is distinct from expected_sqlstate then
    raise exception '0004 rechazó % con SQLSTATE %, se esperaba %.',
      expected_label, coalesce(caught_state, '<nulo>'), expected_sqlstate;
  end if;
  if exists (select 1 from auth.users where id = target_id)
     or exists (select 1 from public.profiles where id = target_id) then
    raise exception '0004 dejó un Auth user o profile huérfano tras rechazar: %.', expected_label;
  end if;
end;
$$;

create or replace function pg_temp.expect_auth_insert_rejection_without_orphan(
  target_user_metadata jsonb,
  target_app_metadata jsonb,
  expected_error text,
  expected_sqlstate text,
  expected_label text
) returns void
language plpgsql
set search_path = public, auth, pg_temp
as $$
declare
  target_id uuid := gen_random_uuid();
  rejected boolean := false;
  caught_message text;
  caught_state text;
begin
  begin
    insert into auth.users (
      id, aud, role, email, encrypted_password,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) values (
      target_id, 'authenticated', 'authenticated',
      'rejected-' || target_id::text || '@example.invalid', '',
      '{"provider":"email","providers":["email"]}'::jsonb || coalesce(target_app_metadata, '{}'::jsonb),
      coalesce(target_user_metadata, '{}'::jsonb), now(), now()
    );
  exception when others then
    rejected := true;
    get stacked diagnostics
      caught_message = message_text,
      caught_state = returned_sqlstate;
  end;

  if not rejected then
    raise exception '0004 aceptó metadata Auth inválida: %.', expected_label;
  end if;
  if position(expected_error in coalesce(caught_message, '')) = 0 then
    raise exception '0004 rechazó % con una excepción distinta del contrato.', expected_label;
  end if;
  if caught_state is distinct from expected_sqlstate then
    raise exception '0004 rechazó % con SQLSTATE %, se esperaba %.',
      expected_label, coalesce(caught_state, '<nulo>'), expected_sqlstate;
  end if;
  if exists (select 1 from auth.users where id = target_id)
     or exists (select 1 from public.profiles where id = target_id) then
    raise exception '0004 dejó un Auth user o profile huérfano tras rechazar: %.', expected_label;
  end if;
end;
$$;

-- La misma lógica de conciliación del preflight detecta huérfanos en ambos sentidos.
create temporary table sitaa_0004_preflight_auth_fixture (
  id uuid primary key
) on commit drop;
create temporary table sitaa_0004_preflight_profile_fixture (
  id uuid primary key
) on commit drop;

insert into sitaa_0004_preflight_auth_fixture values (gen_random_uuid());
insert into sitaa_0004_preflight_profile_fixture values (gen_random_uuid());

do $verify_bidirectional_orphan_queries$
begin
  if (
    select count(*)
    from sitaa_0004_preflight_profile_fixture p
    left join sitaa_0004_preflight_auth_fixture u on u.id = p.id
    where u.id is null
  ) <> 1 then
    raise exception 'La consulta profile_without_auth_user no detectó el fixture huérfano.';
  end if;

  if (
    select count(*)
    from sitaa_0004_preflight_auth_fixture u
    left join sitaa_0004_preflight_profile_fixture p on p.id = u.id
    where p.id is null
  ) <> 1 then
    raise exception 'La consulta auth_user_without_profile no detectó el fixture huérfano.';
  end if;
end;
$verify_bidirectional_orphan_queries$;

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
select pg_temp.insert_registration_user(
  current_setting('sitaa_test.short_identifier_id')::uuid,
  'short-identifier-0004@example.invalid', 'student', '7',
  current_setting('sitaa_test.program_id')::uuid, false
);
select pg_temp.insert_registration_user(
  current_setting('sitaa_test.max_identifier_id')::uuid,
  'max-identifier-0004@example.invalid', 'student', repeat('0', 49) || '8',
  current_setting('sitaa_test.program_id')::uuid, false
);
select pg_temp.insert_registration_user(
  current_setting('sitaa_test.max_name_id')::uuid,
  'max-name-0004@example.invalid', 'student', '00007777',
  current_setting('sitaa_test.program_id')::uuid, false, repeat('N', 200)
);

do $verify_pending_profiles$
begin
  if (select count(*) from public.profiles
    where id = current_setting('sitaa_test.student_id')::uuid
      and account_kind = 'institutional'
      and account_status = 'pending_verification'
      and person_type = 'student'
      and institutional_id_type = 'student_account'
      and institutional_id_value = '00123456'
      and pg_typeof(institutional_id_value) = 'text'::regtype
      and is_active = false and activated_at is null and deactivated_at is null
  ) <> 1 then raise exception 'El registro alumno no creó exactamente un perfil pendiente.'; end if;

  if (select count(*) from public.profiles
    where id = current_setting('sitaa_test.professor_id')::uuid
      and account_kind = 'institutional'
      and account_status = 'pending_verification'
      and person_type = 'professor'
      and institutional_id_type = 'worker_number'
      and institutional_id_value = '00123456'
      and is_active = false and activated_at is null and deactivated_at is null
  ) <> 1 then raise exception 'El registro profesor no creó exactamente un perfil pendiente.'; end if;

  if (select count(*) from public.profiles
    where id = current_setting('sitaa_test.short_identifier_id')::uuid
      and institutional_id_value = '7'
  ) <> 1 then raise exception 'El identificador institucional de un dígito no fue aceptado.'; end if;

  if (select count(*) from public.profiles
    where id = current_setting('sitaa_test.max_identifier_id')::uuid
      and institutional_id_value = repeat('0', 49) || '8'
      and char_length(institutional_id_value) = 50
  ) <> 1 then raise exception 'El identificador institucional de 50 dígitos no fue preservado.'; end if;

  if (select count(*) from public.profiles
    where id = current_setting('sitaa_test.max_name_id')::uuid
      and full_name = repeat('N', 200)
      and char_length(full_name) = 200
  ) <> 1 then raise exception 'El nombre normalizado de 200 caracteres no fue aceptado.'; end if;

  if exists (
    select 1 from public.role_assignments
    where user_id in (
      current_setting('sitaa_test.student_id')::uuid,
      current_setting('sitaa_test.professor_id')::uuid
    )
  ) then raise exception 'El registro público creó asignaciones de rol.'; end if;
end;
$verify_pending_profiles$;

-- Rechazos de contrato: excepción estable, SQLSTATE esperado y cero huérfanos.
select pg_temp.expect_registration_rejection(
  'student', 'ABC123', 'sitaa_invalid_institutional_identifier', '23514', 'identificador con letras'
);
select pg_temp.expect_registration_rejection(
  'student', '12 34', 'sitaa_invalid_institutional_identifier', '23514', 'identificador con espacios'
);
select pg_temp.expect_registration_rejection(
  'student', '12-34', 'sitaa_invalid_institutional_identifier', '23514', 'identificador con guion'
);
select pg_temp.expect_registration_rejection(
  'student', '12.34', 'sitaa_invalid_institutional_identifier', '23514', 'identificador con puntuación'
);
select pg_temp.expect_registration_rejection(
  'student', repeat('9', 51), 'sitaa_identifier_too_long', '23514', 'identificador de 51 dígitos'
);
select pg_temp.expect_registration_rejection(
  'student', '00123456', 'sitaa_identifier_conflict', '23505', 'duplicado del mismo tipo'
);
select pg_temp.expect_registration_rejection(
  'student', '00007111', 'sitaa_invalid_registration_program', '23514', 'programa inexistente', gen_random_uuid()
);
select pg_temp.expect_registration_rejection(
  'student', '00007222', 'sitaa_invalid_registration_program', '23514', 'programa inactivo',
  current_setting('sitaa_test.inactive_program_id')::uuid
);
select pg_temp.expect_registration_rejection(
  'technical', '00999', 'sitaa_invalid_registration_type', '23514', 'technical desde metadata pública'
);
select pg_temp.expect_registration_rejection(
  'student', '00007333', 'sitaa_invalid_full_name', '23514', 'nombre de un carácter',
  current_setting('sitaa_test.program_id')::uuid, 'N'
);
select pg_temp.expect_registration_rejection(
  'student', '00007444', 'sitaa_invalid_full_name', '23514', 'nombre de 201 caracteres',
  current_setting('sitaa_test.program_id')::uuid, repeat('N', 201)
);
select pg_temp.expect_registration_rejection(
  'student', '00007555', 'sitaa_invalid_registration_email', '23514', 'correo de más de 254 caracteres',
  current_setting('sitaa_test.program_id')::uuid, 'Identidad sintética 0004',
  repeat('a', 243) || '@example.invalid'
);

-- Los límites también se sostienen ante escritura directa sobre profiles.
do $verify_profile_length_constraints$
declare
  identifier_rejected boolean := false;
  name_rejected boolean := false;
  email_rejected boolean := false;
begin
  begin
    update public.profiles
    set institutional_id_value = repeat('1', 51)
    where id = current_setting('sitaa_test.max_identifier_id')::uuid;
  exception when check_violation then
    identifier_rejected := true;
  end;

  begin
    update public.profiles
    set full_name = repeat('N', 201)
    where id = current_setting('sitaa_test.max_name_id')::uuid;
  exception when check_violation then
    name_rejected := true;
  end;

  begin
    update public.profiles
    set email = repeat('a', 255)
    where id = current_setting('sitaa_test.student_id')::uuid;
  exception when check_violation then
    email_rejected := true;
  end;

  if not identifier_rejected or not name_rejected or not email_rejected then
    raise exception 'Los constraints de longitud de profiles no rechazaron todos los límites inválidos.';
  end if;
end;
$verify_profile_length_constraints$;

-- Toda alta Auth debe elegir exactamente un camino SITAA. Los rechazos ocurren
-- dentro de la misma transacción y no dejan auth.users ni profiles huérfanos.
select pg_temp.expect_auth_insert_rejection_without_orphan(
  '{}'::jsonb,
  '{}'::jsonb,
  'sitaa_missing_or_invalid_account_metadata',
  '23514',
  'metadata SITAA ausente'
);
select pg_temp.expect_auth_insert_rejection_without_orphan(
  '{}'::jsonb,
  '{"sitaa_account_kind":"institutional"}'::jsonb,
  'sitaa_unsupported_account_kind',
  '23514',
  'account_kind confiable no soportado'
);
select pg_temp.expect_auth_insert_rejection_without_orphan(
  jsonb_build_object(
    'sitaa_registration_type', 'student',
    'full_name', 'Identidad ambigua sintética',
    'primary_program_id', current_setting('sitaa_test.program_id'),
    'institutional_id_value', '00006666'
  ),
  '{"sitaa_account_kind":"technical","sitaa_full_name":"Cuenta ambigua"}'::jsonb,
  'sitaa_ambiguous_account_metadata',
  '23514',
  'metadata institucional y técnica simultánea'
);

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
  if (select count(*) from public.profiles
    where id = current_setting('sitaa_test.technical_id')::uuid
      and account_kind = 'technical' and account_status = 'active'
      and person_type is null and primary_program_id is null
      and institutional_id_type is null and institutional_id_value is null
      and nullif(btrim(full_name), '') is not null
      and nullif(btrim(email), '') is not null
      and is_active and activated_at is not null and deactivated_at is null
  ) <> 1 then raise exception 'La cuenta técnica confiable no creó exactamente un perfil válido.'; end if;
end;
$verify_technical$;

do $verify_technical_required_identity$
declare
  blank_name_rejected boolean := false;
  blank_email_rejected boolean := false;
begin
  begin
    update public.profiles set full_name = '   '
    where id = current_setting('sitaa_test.technical_id')::uuid;
  exception when check_violation then blank_name_rejected := true;
  end;
  begin
    update public.profiles set email = ''
    where id = current_setting('sitaa_test.technical_id')::uuid;
  exception when check_violation then blank_email_rejected := true;
  end;
  if not blank_name_rejected or not blank_email_rejected then
    raise exception 'Una cuenta técnica aceptó nombre o correo vacío.';
  end if;
end;
$verify_technical_required_identity$;

do $verify_account_exclusivity$
declare
  institutional_rejected boolean := false;
  technical_rejected boolean := false;
begin
  begin
    update public.profiles set primary_program_id = null
    where id = current_setting('sitaa_test.student_id')::uuid;
  exception when check_violation then institutional_rejected := true;
  end;
  begin
    update public.profiles
    set person_type = 'professor', institutional_id_type = 'worker_number',
        institutional_id_value = '00008888', primary_program_id = current_setting('sitaa_test.program_id')::uuid
    where id = current_setting('sitaa_test.technical_id')::uuid;
  exception when check_violation then technical_rejected := true;
  end;
  if not institutional_rejected then raise exception 'Una cuenta institucional incompleta superó los constraints.'; end if;
  if not technical_rejected then raise exception 'Una cuenta técnica con identidad institucional superó los constraints.'; end if;
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

do $verify_lifecycle_invariants$
begin
  if exists (
    select 1
    from public.profiles p
    where p.id in (
      current_setting('sitaa_test.student_id')::uuid,
      current_setting('sitaa_test.professor_id')::uuid,
      current_setting('sitaa_test.inactive_id')::uuid
    ) and not (
      (p.account_status = 'active' and p.is_active and p.activated_at is not null and p.deactivated_at is null)
      or (p.account_status = 'pending_verification' and not p.is_active and p.activated_at is null and p.deactivated_at is null)
      or (p.account_status = 'inactive' and not p.is_active and p.deactivated_at is not null)
    )
  ) then raise exception 'Un estado de ciclo de vida no cumple su invariante de timestamps.'; end if;
  if not exists (
    select 1 from public.profiles
    where id = current_setting('sitaa_test.inactive_id')::uuid
      and account_status = 'inactive' and is_active = false and deactivated_at is not null
  ) then raise exception 'La confirmación reactivó indebidamente un perfil inactivo.'; end if;
end;
$verify_lifecycle_invariants$;

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
  ) then raise exception 'El usuario no pudo actualizar el nombre aprobado.'; end if;
  begin
    update public.profiles set institutional_id_value = '55555555'
    where id = current_setting('sitaa_test.student_id')::uuid;
  exception when insufficient_privilege then rejected := true;
  end;
  if not rejected then raise exception 'El usuario pudo modificar su identificador.'; end if;
  if public.can_create_activity(
    'program', current_setting('sitaa_test.program_id')::uuid,
    current_setting('sitaa_test.division_id')::uuid, 'tutoring'
  ) then raise exception 'Un alumno nuevo obtuvo permiso de creación.'; end if;
end;
$verify_self_update$;
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
do $verify_existing_professor_assignment$
begin
  if not public.can_create_activity(
    'program', current_setting('sitaa_test.program_id')::uuid,
    current_setting('sitaa_test.division_id')::uuid, 'tutoring'
  ) then raise exception 'Una asignación actual de profesor dejó de conceder su permiso existente.'; end if;
end;
$verify_existing_professor_assignment$;
reset role;

select pg_temp.insert_registration_user(
  current_setting('sitaa_test.peer_tutor_id')::uuid,
  'peer-tutor-0004@example.invalid', 'student', '00005555',
  current_setting('sitaa_test.program_id')::uuid, true
);
insert into public.role_assignments (
  user_id, role_code, scope_type, service_area, program_id, is_active, starts_at
) values (
  current_setting('sitaa_test.peer_tutor_id')::uuid,
  'peer_tutor', 'program', 'both', current_setting('sitaa_test.program_id')::uuid,
  true, current_date
);
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
  ) then raise exception 'Una asignación actual de tutor par dejó de conceder su permiso existente.'; end if;
end;
$verify_existing_peer_tutor_assignment$;
reset role;

-- auth.users queda exactamente con los dos triggers SITAA previstos.
do $verify_auth_triggers$
declare non_internal_count integer;
begin
  select count(*) into non_internal_count
  from pg_trigger t
  where t.tgrelid = 'auth.users'::regclass and not t.tgisinternal;
  if non_internal_count <> 2
     or not exists (
       select 1 from pg_trigger t join pg_proc p on p.oid = t.tgfoid join pg_namespace n on n.oid = p.pronamespace
       where t.tgrelid = 'auth.users'::regclass and not t.tgisinternal
         and t.tgname = 'on_sitaa_auth_user_created' and n.nspname = 'public' and p.proname = 'handle_sitaa_auth_user_created'
     )
     or not exists (
       select 1 from pg_trigger t join pg_proc p on p.oid = t.tgfoid join pg_namespace n on n.oid = p.pronamespace
       where t.tgrelid = 'auth.users'::regclass and not t.tgisinternal
         and t.tgname = 'on_sitaa_auth_user_verified' and n.nspname = 'public' and p.proname = 'sync_sitaa_profile_from_auth'
     ) then
    raise exception 'auth.users no tiene exactamente los dos triggers SITAA esperados.';
  end if;
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    where n.nspname = 'public'
      and p.proname in ('handle_sitaa_auth_user_created', 'sync_sitaa_profile_from_auth')
      and acl.privilege_type = 'EXECUTE' and acl.grantee = 0
  ) then raise exception 'Una función trigger SITAA conserva EXECUTE para PUBLIC.'; end if;
  if has_function_privilege('anon', 'public.handle_sitaa_auth_user_created()', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.handle_sitaa_auth_user_created()', 'EXECUTE')
     or has_function_privilege('anon', 'public.sync_sitaa_profile_from_auth()', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.sync_sitaa_profile_from_auth()', 'EXECUTE') then
    raise exception 'anon o authenticated puede invocar directamente una función trigger SITAA.';
  end if;
end;
$verify_auth_triggers$;

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
