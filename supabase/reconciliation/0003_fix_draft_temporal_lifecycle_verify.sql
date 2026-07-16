-- Verificación transaccional de SITAA 0003.
--
-- Ejecutar únicamente en un entorno de prueba con rol administrativo. Todas las
-- filas usan UUID generados en la sesión y la transacción termina en ROLLBACK.
-- session_replication_role se usa sólo para crear fixtures sintéticas sin tocar
-- auth.users ni depender de catálogos o identidades reales.

begin;

-- 1. Contrato estático de las funciones reemplazadas.
do $verify_static$
declare
  ended_definition text := lower(pg_get_functiondef('public.activity_has_ended(uuid)'::regprocedure));
  update_definition text := lower(pg_get_functiondef('public.can_update_activity_base(uuid)'::regprocedure));
  delete_definition text := lower(pg_get_functiondef('public.can_delete_activity(uuid)'::regprocedure));
  read_definition text := lower(pg_get_functiondef('public.can_read_activity(uuid)'::regprocedure));
  edit_definition text := lower(pg_get_functiondef('public.can_edit_activity(uuid)'::regprocedure));
begin
  if position('when a.status_code = ''draft'' then false' in ended_definition) = 0 then
    raise exception '0003 no excluye draft de activity_has_ended.';
  end if;
  if position('activity_has_ended' in update_definition) > 0
     or position('activity_has_ended' in delete_definition) > 0 then
    raise exception 'Los helpers de borrador todavía dependen del bloqueo temporal.';
  end if;
  if position('a.status_code = ''draft''' in update_definition) = 0
     or position('a.created_by = auth.uid()' in update_definition) = 0
     or position('a.status_code = ''draft''' in delete_definition) = 0
     or position('a.created_by = auth.uid()' in delete_definition) = 0 then
    raise exception 'Los helpers no conservan el contrato de creador del borrador.';
  end if;
  if position('a.status_code = ''draft'' and a.created_by = auth.uid()' in read_definition) = 0
     or position('a.status_code = ''draft'' and a.created_by = auth.uid()' in edit_definition) = 0 then
    raise exception 'can_read_activity o can_edit_activity no conservan la privacidad de 0002.';
  end if;
end;
$verify_static$;

-- 2. Identificadores efímeros para las pruebas de comportamiento.
create temporary table sitaa_0003_fixture_ids on commit drop as
select
  gen_random_uuid() as creator_id,
  gen_random_uuid() as other_user_id,
  gen_random_uuid() as technical_admin_id,
  gen_random_uuid() as division_id,
  gen_random_uuid() as program_id,
  gen_random_uuid() as draft_past_no_time_id,
  gen_random_uuid() as draft_delete_id,
  gen_random_uuid() as draft_past_complete_id,
  gen_random_uuid() as published_past_id;

do $fixture_settings$
declare
  ids sitaa_0003_fixture_ids%rowtype;
begin
  select * into ids from sitaa_0003_fixture_ids;
  perform set_config('sitaa_test.creator_id', ids.creator_id::text, true);
  perform set_config('sitaa_test.other_user_id', ids.other_user_id::text, true);
  perform set_config('sitaa_test.technical_admin_id', ids.technical_admin_id::text, true);
  perform set_config('sitaa_test.division_id', ids.division_id::text, true);
  perform set_config('sitaa_test.program_id', ids.program_id::text, true);
  perform set_config('sitaa_test.draft_past_no_time_id', ids.draft_past_no_time_id::text, true);
  perform set_config('sitaa_test.draft_delete_id', ids.draft_delete_id::text, true);
  perform set_config('sitaa_test.draft_past_complete_id', ids.draft_past_complete_id::text, true);
  perform set_config('sitaa_test.published_past_id', ids.published_past_id::text, true);
end;
$fixture_settings$;

set local session_replication_role = replica;

insert into public.profiles (id, email, full_name, primary_program_id, is_active, person_type, institutional_id_type)
select creator_id, 'sitaa-0003-' || creator_id::text || '@example.invalid', 'Creador sintético 0003', program_id, true, 'worker', 'worker_number'
from sitaa_0003_fixture_ids;

insert into public.role_assignments (user_id, role_code, scope_type, service_area, program_id, is_active, starts_at)
select creator_id, 'professor', 'program', 'both', program_id, true, current_date - 1
from sitaa_0003_fixture_ids
union all
select technical_admin_id, 'technical_admin', 'system', 'technical', null, true, current_date - 1
from sitaa_0003_fixture_ids;

insert into public.activities (
  id, title, status_code, scope_type, division_id, program_id,
  responsible_profile_id, created_by, service_type_code,
  start_date, start_time, end_date, end_time, duration_mode
)
select draft_past_no_time_id, 'Borrador pasado sin hora 0003', 'draft', 'program', division_id, program_id,
       creator_id, creator_id, 'tutoring', current_date - 30, null::time, null::date, null::time, null::text
from sitaa_0003_fixture_ids
union all
select draft_delete_id, 'Borrador eliminable 0003', 'draft', 'program', division_id, program_id,
       creator_id, creator_id, 'tutoring', current_date - 20, null::time, null::date, null::time, null::text
from sitaa_0003_fixture_ids
union all
select draft_past_complete_id, 'Borrador pasado completo 0003', 'draft', 'program', division_id, program_id,
       creator_id, creator_id, 'tutoring', current_date - 10, time '10:00', current_date - 10, time '11:00', 'one_hour'
from sitaa_0003_fixture_ids
union all
select published_past_id, 'Publicada ocurrida 0003', 'scheduled', 'program', division_id, program_id,
       creator_id, creator_id, 'tutoring', current_date - 2, time '10:00', current_date - 2, time '11:00', 'one_hour'
from sitaa_0003_fixture_ids;

set local session_replication_role = origin;

-- 3. Creador: el borrador pasado no termina y admite UPDATE/DELETE. Los intentos
-- de publicación incompleta o pasada fallan sin cambiar status_code.
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.creator_id'), true);
select set_config(
  'request.jwt.claims',
  jsonb_build_object('sub', current_setting('sitaa_test.creator_id'), 'role', 'authenticated')::text,
  true
);
set local role authenticated;

do $verify_creator$
declare
  affected integer;
  preserved_count integer;
  rejected boolean;
  rejection_message text;
begin
  if public.activity_has_ended(current_setting('sitaa_test.draft_past_no_time_id')::uuid) is distinct from false then
    raise exception 'Un borrador pasado fue considerado ocurrido.';
  end if;
  if public.activity_has_ended(current_setting('sitaa_test.published_past_id')::uuid) is distinct from true then
    raise exception 'Una actividad publicada pasada dejó de considerarse ocurrida.';
  end if;
  if not public.can_read_activity(current_setting('sitaa_test.draft_past_no_time_id')::uuid)
     or not public.can_edit_activity(current_setting('sitaa_test.draft_past_no_time_id')::uuid)
     or not public.can_update_activity_base(current_setting('sitaa_test.draft_past_no_time_id')::uuid)
     or not public.can_delete_activity(current_setting('sitaa_test.draft_past_no_time_id')::uuid) then
    raise exception 'El creador no conserva todas las capacidades sobre su borrador.';
  end if;

  update public.activities
  set title = 'Borrador editable después de 0003'
  where id = current_setting('sitaa_test.draft_past_no_time_id')::uuid;
  get diagnostics affected = row_count;
  if affected <> 1 then
    raise exception 'RLS no permitió actualizar el borrador propio.';
  end if;

  delete from public.activities
  where id = current_setting('sitaa_test.draft_delete_id')::uuid;
  get diagnostics affected = row_count;
  if affected <> 1 then
    raise exception 'RLS no permitió eliminar el borrador propio.';
  end if;

  rejected := false;
  rejection_message := null;
  begin
    perform * from public.publish_activity(current_setting('sitaa_test.draft_past_no_time_id')::uuid);
  exception when others then
    rejected := true;
    rejection_message := sqlerrm;
  end;
  if not rejected or rejection_message not like 'Indica una fecha y hora de inicio válidas.%' then
    raise exception 'publish_activity no rechazó el borrador incompleto por la causa esperada.';
  end if;

  rejected := false;
  rejection_message := null;
  begin
    perform * from public.publish_activity(current_setting('sitaa_test.draft_past_complete_id')::uuid);
  exception when others then
    rejected := true;
    rejection_message := sqlerrm;
  end;
  if not rejected or rejection_message not like 'La fecha y hora de inicio deben ser posteriores%' then
    raise exception 'publish_activity no rechazó el inicio pasado por la causa esperada.';
  end if;

  select count(*) into preserved_count
  from public.activities
  where id in (
      current_setting('sitaa_test.draft_past_no_time_id')::uuid,
      current_setting('sitaa_test.draft_past_complete_id')::uuid
    )
    and status_code = 'draft';
  if preserved_count <> 2 then
    raise exception 'Un intento fallido de publicación no conservó ambos borradores.';
  end if;
  if not public.can_update_activity_base(current_setting('sitaa_test.draft_past_no_time_id')::uuid)
     or not public.can_update_activity_base(current_setting('sitaa_test.draft_past_complete_id')::uuid) then
    raise exception 'Un borrador rechazado dejó de ser editable.';
  end if;
end;
$verify_creator$;

reset role;

-- 4. Otro usuario no obtiene lectura, edición ni eliminación del borrador.
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.other_user_id'), true);
select set_config(
  'request.jwt.claims',
  jsonb_build_object('sub', current_setting('sitaa_test.other_user_id'), 'role', 'authenticated')::text,
  true
);
set local role authenticated;

do $verify_other_user$
declare
  affected integer;
begin
  if public.can_read_activity(current_setting('sitaa_test.draft_past_no_time_id')::uuid)
     or public.can_edit_activity(current_setting('sitaa_test.draft_past_no_time_id')::uuid)
     or public.can_update_activity_base(current_setting('sitaa_test.draft_past_no_time_id')::uuid)
     or public.can_delete_activity(current_setting('sitaa_test.draft_past_no_time_id')::uuid) then
    raise exception 'Otro usuario obtuvo acceso al borrador ajeno.';
  end if;
  if exists (
    select 1 from public.activities
    where id = current_setting('sitaa_test.draft_past_no_time_id')::uuid
  ) then
    raise exception 'RLS expuso el borrador ajeno por SELECT.';
  end if;
  update public.activities set title = 'Actualización no autorizada'
  where id = current_setting('sitaa_test.draft_past_no_time_id')::uuid;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'RLS permitió UPDATE ajeno.'; end if;
  delete from public.activities
  where id = current_setting('sitaa_test.draft_past_no_time_id')::uuid;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'RLS permitió DELETE ajeno.'; end if;
end;
$verify_other_user$;

reset role;

-- 5. technical_admin conserva gestión publicada, pero no amplía borradores.
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.technical_admin_id'), true);
select set_config(
  'request.jwt.claims',
  jsonb_build_object('sub', current_setting('sitaa_test.technical_admin_id'), 'role', 'authenticated')::text,
  true
);
set local role authenticated;

do $verify_technical_admin$
declare
  affected integer;
begin
  if not public.can_manage_activity(
    'program',
    current_setting('sitaa_test.program_id')::uuid,
    current_setting('sitaa_test.division_id')::uuid,
    'tutoring'
  ) then
    raise exception 'La fixture technical_admin no conserva su alcance publicado.';
  end if;
  if not public.can_read_activity(current_setting('sitaa_test.published_past_id')::uuid)
     or not public.can_edit_activity(current_setting('sitaa_test.published_past_id')::uuid)
     or not public.can_update_activity_base(current_setting('sitaa_test.published_past_id')::uuid)
     or not public.can_delete_activity(current_setting('sitaa_test.published_past_id')::uuid) then
    raise exception '0003 restringió el acceso amplio diferido de technical_admin a contenido publicado.';
  end if;
  if public.can_read_activity(current_setting('sitaa_test.draft_past_no_time_id')::uuid)
     or public.can_edit_activity(current_setting('sitaa_test.draft_past_no_time_id')::uuid)
     or public.can_update_activity_base(current_setting('sitaa_test.draft_past_no_time_id')::uuid)
     or public.can_delete_activity(current_setting('sitaa_test.draft_past_no_time_id')::uuid) then
    raise exception 'technical_admin obtuvo acceso al borrador ajeno.';
  end if;
  if exists (
    select 1 from public.activities
    where id = current_setting('sitaa_test.draft_past_no_time_id')::uuid
  ) then
    raise exception 'RLS expuso el borrador ajeno a technical_admin.';
  end if;
  update public.activities set title = 'Actualización técnica no autorizada'
  where id = current_setting('sitaa_test.draft_past_no_time_id')::uuid;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'RLS permitió UPDATE técnico sobre borrador ajeno.'; end if;
  delete from public.activities
  where id = current_setting('sitaa_test.draft_past_no_time_id')::uuid;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'RLS permitió DELETE técnico sobre borrador ajeno.'; end if;
end;
$verify_technical_admin$;

reset role;

select 'Verificación 0003 completada; todas las fixtures serán revertidas.' as resultado;

rollback;
