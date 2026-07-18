-- Verificación transaccional de SITAA 0006. Termina siempre en ROLLBACK.

begin;

create temporary table sitaa_0006_ids on commit drop as
select gen_random_uuid() division_id, gen_random_uuid() program_id,
  gen_random_uuid() student_id, gen_random_uuid() professor_id,
  gen_random_uuid() invalid_id, gen_random_uuid() technical_id;

insert into public.divisions (id, code, name)
select division_id, 'sitaa_0006_' || replace(division_id::text, '-', ''), 'División sintética 0006' from sitaa_0006_ids;
insert into public.academic_programs (id, division_id, code, name, is_active)
select program_id, division_id, 'sitaa_0006_' || replace(program_id::text, '-', ''), 'Programa sintético 0006', true from sitaa_0006_ids;

create or replace function pg_temp.insert_auth_user(target_id uuid, target_email text, target_provider text, target_user_metadata jsonb default '{}'::jsonb, target_app_metadata jsonb default '{}'::jsonb, confirmed boolean default false)
returns void language plpgsql set search_path = public, auth, pg_temp as $$
begin
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (target_id, 'authenticated', 'authenticated', target_email, '', case when confirmed then now() else null end,
    jsonb_build_object('provider', target_provider, 'providers', jsonb_build_array(target_provider)) || target_app_metadata,
    target_user_metadata, now(), now());
end;
$$;

create or replace function pg_temp.insert_google_identity(target_user_id uuid, target_provider_id text, target_email text)
returns void language plpgsql set search_path = auth, pg_catalog, pg_temp as $$
declare payload jsonb := jsonb_build_object('sub', target_provider_id, 'email', target_email, 'email_verified', true);
begin
  if exists (select 1 from information_schema.columns where table_schema = 'auth' and table_name = 'identities' and column_name = 'provider_id') then
    execute 'insert into auth.identities (provider_id,user_id,identity_data,provider,last_sign_in_at,created_at,updated_at) values ($1,$2,$3,''google'',now(),now(),now())'
      using target_provider_id, target_user_id, payload;
  else
    execute 'insert into auth.identities (id,user_id,identity_data,provider,last_sign_in_at,created_at,updated_at) values ($1,$2,$3,''google'',now(),now(),now())'
      using target_provider_id, target_user_id, payload;
  end if;
end;
$$;

do $privileges$
begin
  if has_function_privilege('authenticated', 'public.complete_own_google_registration(text,text,text,uuid)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.complete_own_google_registration(text,text,text,text,text,uuid)', 'EXECUTE')
     or has_function_privilege('anon', 'public.complete_own_google_registration(text,text,text,text,text,uuid)', 'EXECUTE') then
    raise exception 'Los privilegios de completion no respetan el contrato 0006.';
  end if;
end;
$privileges$;

select pg_temp.insert_auth_user(student_id, 'student-0006@example.invalid', 'google', '{"name":"Nombre provisional"}'::jsonb)
from sitaa_0006_ids;
select pg_temp.insert_auth_user(professor_id, 'professor-0006@example.invalid', 'google', '{}'::jsonb)
from sitaa_0006_ids;
select pg_temp.insert_google_identity(student_id, 'google-student-0006', 'student-0006@example.invalid') from sitaa_0006_ids;
select pg_temp.insert_google_identity(professor_id, 'google-professor-0006', 'professor-0006@example.invalid') from sitaa_0006_ids;

select set_config('request.jwt.claim.sub', student_id::text, true) from sitaa_0006_ids;
select set_config('request.jwt.claims', jsonb_build_object('sub', student_id, 'role', 'authenticated')::text, true) from sitaa_0006_ids;
set local role authenticated;
select public.complete_own_google_registration('student', '  José   María  ', '  Pérez  ', '  Ávila  ', '00060001', program_id) from sitaa_0006_ids;
reset role;

select set_config('request.jwt.claim.sub', professor_id::text, true) from sitaa_0006_ids;
select set_config('request.jwt.claims', jsonb_build_object('sub', professor_id, 'role', 'authenticated')::text, true) from sitaa_0006_ids;
set local role authenticated;
select public.complete_own_google_registration('professor', 'Ana', 'López', null, '00060002', program_id) from sitaa_0006_ids;
reset role;

do $completed$
declare ids sitaa_0006_ids%rowtype;
begin
  select * into ids from sitaa_0006_ids;
  if not exists (select 1 from public.profiles where id = ids.student_id and first_names = 'José María' and paternal_surname = 'Pérez' and maternal_surname = 'Ávila' and full_name = 'José María Pérez Ávila') then
    raise exception 'No se normalizaron o sincronizaron los nombres del alumno.';
  end if;
  if not exists (select 1 from public.profiles where id = ids.professor_id and first_names = 'Ana' and paternal_surname = 'López' and maternal_surname is null and full_name = 'Ana López') then
    raise exception 'El apellido materno opcional no respetó el contrato.';
  end if;
  if exists (select 1 from public.role_assignments where user_id in (ids.student_id, ids.professor_id)) then
    raise exception 'La finalización estructurada creó roles.';
  end if;
end;
$completed$;

-- Edición propia mantiene sincronía y no permite cambiar identidad administrativa.
select set_config('request.jwt.claim.sub', student_id::text, true) from sitaa_0006_ids;
select set_config('request.jwt.claims', jsonb_build_object('sub', student_id, 'role', 'authenticated')::text, true) from sitaa_0006_ids;
set local role authenticated;
update public.profiles set first_names = '  María   José ', paternal_surname = 'Pérez', maternal_surname = null
where id = (select student_id from sitaa_0006_ids);
do $self_edit_rejects_admin$
declare rejected boolean := false;
begin
  begin
    update public.profiles set institutional_id_value = '99999999' where id = (select student_id from sitaa_0006_ids);
  exception when insufficient_privilege then rejected := true;
  end;
  if not rejected then raise exception 'La edición propia permitió cambiar identidad administrativa.'; end if;
end;
$self_edit_rejects_admin$;
reset role;

do $self_edit_sync$
begin
  if not exists (select 1 from public.profiles where id = (select student_id from sitaa_0006_ids)
    and first_names = 'María José' and full_name = 'María José Pérez') then
    raise exception 'La edición propia no sincronizó full_name.';
  end if;
end;
$self_edit_sync$;

-- Campo requerido en blanco se rechaza sin activar parcialmente el perfil.
select pg_temp.insert_auth_user(invalid_id, 'invalid-0006@example.invalid', 'google', '{}'::jsonb) from sitaa_0006_ids;
select pg_temp.insert_google_identity(invalid_id, 'google-invalid-0006', 'invalid-0006@example.invalid') from sitaa_0006_ids;
select set_config('request.jwt.claim.sub', invalid_id::text, true) from sitaa_0006_ids;
select set_config('request.jwt.claims', jsonb_build_object('sub', invalid_id, 'role', 'authenticated')::text, true) from sitaa_0006_ids;
set local role authenticated;
do $blank_rejected$
declare rejected boolean := false; message text;
begin
  begin
    perform public.complete_own_google_registration('student', '   ', 'Pérez', null, '00060003', (select program_id from sitaa_0006_ids));
  exception when others then rejected := true; get stacked diagnostics message = message_text;
  end;
  if not rejected or position('sitaa_invalid_first_names' in coalesce(message, '')) = 0 then raise exception 'No se rechazó el nombre requerido vacío.'; end if;
end;
$blank_rejected$;
reset role;

-- Bootstrap técnico conserva compatibilidad con sitaa_full_name sin dividirlo.
select pg_temp.insert_auth_user(technical_id, 'technical-0006@example.invalid', 'email', '{}'::jsonb,
  '{"sitaa_account_kind":"technical","sitaa_full_name":"Soporte SITAA"}'::jsonb, true) from sitaa_0006_ids;
do $technical$
begin
  if not exists (select 1 from public.profiles where id = (select technical_id from sitaa_0006_ids)
    and account_kind = 'technical' and first_names = 'Soporte SITAA' and paternal_surname is null and full_name = 'Soporte SITAA') then
    raise exception 'El bootstrap técnico estructurado dejó de funcionar.';
  end if;
end;
$technical$;

-- Claves de orden se recuperan por separado; contratos 0002–0005 permanecen.
do $regressions$
begin
  perform paternal_surname, maternal_surname, first_names from public.profiles where id = (select student_id from sitaa_0006_ids);
  if to_regprocedure('public.publish_activity(uuid)') is null
     or to_regprocedure('public.can_update_activity_base(uuid)') is null
     or to_regprocedure('public.finalize_expired_attendance()') is null
     or to_regprocedure('public.handle_sitaa_auth_user_created()') is null then
    raise exception 'Falta un contrato establecido por 0002–0005.';
  end if;
end;
$regressions$;

select 'Verificación 0006 completada; todas las fixtures serán revertidas.' resultado;
rollback;
