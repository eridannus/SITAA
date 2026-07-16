-- Verificación transaccional de SITAA 0003.
--
-- Ejecutar únicamente en un entorno de prueba con rol administrativo. Todas las
-- filas usan UUID generados en la sesión y la transacción termina en ROLLBACK.
-- session_replication_role = replica se limita al alta de usuarios Auth ficticios
-- para evitar efectos secundarios de bootstrap; las fixtures públicas se crean
-- después de restaurar origin y con todas las restricciones activas.

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

-- 2. Identificadores y resultados efímeros.
create temporary table sitaa_0003_fixture_ids on commit drop as
select
  gen_random_uuid() as creator_id,
  gen_random_uuid() as other_professor_id,
  gen_random_uuid() as management_user_id,
  gen_random_uuid() as student_id,
  gen_random_uuid() as technical_admin_id,
  gen_random_uuid() as division_id,
  gen_random_uuid() as program_id,
  gen_random_uuid() as academic_period_id,
  gen_random_uuid() as draft_without_schedule_id,
  gen_random_uuid() as draft_past_no_time_id,
  gen_random_uuid() as draft_past_complete_id,
  gen_random_uuid() as draft_future_id,
  gen_random_uuid() as published_elapsed_id;

create temporary table sitaa_0003_results (
  check_name text primary key,
  passed boolean not null
) on commit drop;

do $fixture_settings$
declare
  ids sitaa_0003_fixture_ids%rowtype;
begin
  select * into ids from sitaa_0003_fixture_ids;
  perform set_config('sitaa_test.creator_id', ids.creator_id::text, true);
  perform set_config('sitaa_test.other_professor_id', ids.other_professor_id::text, true);
  perform set_config('sitaa_test.management_user_id', ids.management_user_id::text, true);
  perform set_config('sitaa_test.student_id', ids.student_id::text, true);
  perform set_config('sitaa_test.technical_admin_id', ids.technical_admin_id::text, true);
  perform set_config('sitaa_test.division_id', ids.division_id::text, true);
  perform set_config('sitaa_test.program_id', ids.program_id::text, true);
  perform set_config('sitaa_test.academic_period_id', ids.academic_period_id::text, true);
  perform set_config('sitaa_test.draft_without_schedule_id', ids.draft_without_schedule_id::text, true);
  perform set_config('sitaa_test.draft_past_no_time_id', ids.draft_past_no_time_id::text, true);
  perform set_config('sitaa_test.draft_past_complete_id', ids.draft_past_complete_id::text, true);
  perform set_config('sitaa_test.draft_future_id', ids.draft_future_id::text, true);
  perform set_config('sitaa_test.published_elapsed_id', ids.published_elapsed_id::text, true);
end;
$fixture_settings$;

-- Los códigos funcionales son catálogos sembrados y estables. Si el entorno no
-- contiene el contrato esperado, el verificador se detiene antes de crear datos.
do $verify_catalog_contract$
begin
  if (select count(*) from public.roles where code = any (
    array['professor', 'program_tutoring_lead', 'student', 'technical_admin']
  )) <> 4 then
    raise exception 'Fixture 0003: faltan roles requeridos del catálogo.';
  end if;
  if not exists (select 1 from public.activity_statuses where code = 'draft')
     or not exists (select 1 from public.activity_statuses where code = 'completed')
     or not exists (select 1 from public.activity_types where code = 'individual_activity')
     or not exists (select 1 from public.service_types where code = 'tutoring')
     or not exists (select 1 from public.attention_categories where code = 'disciplinary')
     or not exists (select 1 from public.activity_modalities where code = 'in_person')
     or not exists (select 1 from public.location_types where code = 'classroom') then
    raise exception 'Fixture 0003: faltan códigos operativos requeridos del catálogo.';
  end if;
end;
$verify_catalog_contract$;

-- El único bypass de triggers se usa para identidades Auth sintéticas. Las filas
-- se eliminan por el ROLLBACK final y nunca se consultan datos personales reales.
set local session_replication_role = replica;

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select actor_id, 'authenticated', 'authenticated',
       'sitaa-0003-' || actor_id::text || '@example.invalid',
       '', now(), '{"provider":"email","providers":["email"]}'::jsonb,
       '{}'::jsonb, now(), now()
from (
  select creator_id as actor_id from sitaa_0003_fixture_ids
  union all select other_professor_id from sitaa_0003_fixture_ids
  union all select management_user_id from sitaa_0003_fixture_ids
  union all select student_id from sitaa_0003_fixture_ids
  union all select technical_admin_id from sitaa_0003_fixture_ids
) actors;

set local session_replication_role = origin;

-- Grafo institucional sintético y referencialmente completo. Desde este punto
-- todas las FK, checks y triggers se encuentran activos.
insert into public.divisions (id, code, name)
select division_id, 'sitaa_0003_' || replace(division_id::text, '-', ''),
       'División sintética 0003'
from sitaa_0003_fixture_ids;

insert into public.academic_programs (id, division_id, code, name)
select program_id, division_id,
       'sitaa_0003_' || replace(program_id::text, '-', ''),
       'Programa sintético 0003'
from sitaa_0003_fixture_ids;

insert into public.academic_periods (
  id, code, name, starts_on, ends_on, is_active, sort_order
)
select academic_period_id,
       'sitaa_0003_' || replace(academic_period_id::text, '-', ''),
       'Semestre sintético 0003', current_date - 60, current_date + 60, true, -30003
from sitaa_0003_fixture_ids;

insert into public.profiles (
  id, email, full_name, primary_program_id, is_active,
  person_type, institutional_id_type, institutional_id_value
)
select actor_id,
       'sitaa-0003-' || actor_id::text || '@example.invalid',
       full_name, program_id, true, person_type, identifier_type,
       '0003-' || replace(actor_id::text, '-', '')
from sitaa_0003_fixture_ids ids
cross join lateral (
  values
    (ids.creator_id, 'Profesor creador sintético 0003', 'worker', 'worker_number'),
    (ids.other_professor_id, 'Profesor externo sintético 0003', 'worker', 'worker_number'),
    (ids.management_user_id, 'Responsable sintético 0003', 'worker', 'worker_number'),
    (ids.student_id, 'Alumno sintético 0003', 'student', 'student_account'),
    (ids.technical_admin_id, 'Administrador técnico sintético 0003', 'worker', 'worker_number')
) actor(actor_id, full_name, person_type, identifier_type);

insert into public.role_assignments (
  user_id, role_code, scope_type, service_area,
  division_id, program_id, is_active, starts_at
)
select actor_id, role_code, scope_type, service_area,
       division_scope_id, program_scope_id, true, current_date - 1
from sitaa_0003_fixture_ids ids
cross join lateral (
  values
    (ids.creator_id, 'professor', 'program', 'both', null::uuid, ids.program_id),
    (ids.other_professor_id, 'professor', 'program', 'both', null::uuid, ids.program_id),
    (ids.management_user_id, 'program_tutoring_lead', 'program', 'tutoring', null::uuid, ids.program_id),
    (ids.student_id, 'student', 'own', 'tutoring', null::uuid, null::uuid),
    (ids.technical_admin_id, 'technical_admin', 'system', 'technical', null::uuid, null::uuid)
) assignment(
  actor_id, role_code, scope_type, service_area, division_scope_id, program_scope_id
);

insert into public.activities (
  id, title, description, academic_period_id, program_id,
  activity_type_code, service_type_code, attention_category_code,
  modality_code, status_code, location_type_code, location_detail,
  responsible_profile_id, created_by, start_date, start_time,
  end_date, end_time, duration_mode, scope_type, division_id
)
select activity_id, title, 'Fixture transaccional SITAA 0003', period_id, ids.program_id,
       'individual_activity', 'tutoring', 'disciplinary',
       'in_person', status_code, 'classroom', 'Aula sintética 0003',
       ids.management_user_id, ids.creator_id, start_date, start_time,
       end_date, end_time, duration_mode, 'program', ids.division_id
from sitaa_0003_fixture_ids ids
cross join lateral (
  values
    (ids.draft_without_schedule_id, 'Borrador sin horario 0003', 'draft',
      null::uuid, null::date, null::time, null::date, null::time, null::text),
    (ids.draft_past_no_time_id, 'Borrador pasado sin hora 0003', 'draft',
      null::uuid, current_date - 30, null::time, null::date, null::time, null::text),
    (ids.draft_past_complete_id, 'Borrador pasado completo 0003', 'draft',
      ids.academic_period_id, current_date - 10, time '10:00', current_date - 10, time '11:00', 'one_hour'),
    (ids.draft_future_id, 'Borrador futuro 0003', 'draft',
      ids.academic_period_id, current_date + 10, time '10:00', current_date + 10, time '11:00', 'one_hour'),
    (ids.published_elapsed_id, 'Actividad publicada ocurrida 0003', 'completed',
      ids.academic_period_id, current_date - 2, time '10:00', current_date - 2, time '11:00', 'one_hour')
) fixture(
  activity_id, title, status_code, period_id,
  start_date, start_time, end_date, end_time, duration_mode
);

-- 3. Integridad completa de las fixtures antes de cualquier prueba funcional.
do $verify_fixture_integrity$
declare
  fixture_activity_ids uuid[] := array[
    current_setting('sitaa_test.draft_without_schedule_id')::uuid,
    current_setting('sitaa_test.draft_past_no_time_id')::uuid,
    current_setting('sitaa_test.draft_past_complete_id')::uuid,
    current_setting('sitaa_test.draft_future_id')::uuid,
    current_setting('sitaa_test.published_elapsed_id')::uuid
  ];
  actor_ids uuid[] := array[
    current_setting('sitaa_test.creator_id')::uuid,
    current_setting('sitaa_test.other_professor_id')::uuid,
    current_setting('sitaa_test.management_user_id')::uuid,
    current_setting('sitaa_test.student_id')::uuid,
    current_setting('sitaa_test.technical_admin_id')::uuid
  ];
begin
  if (select count(*) from public.activities where id = any(fixture_activity_ids)) <> 5
     or (select count(*) from auth.users where id = any(actor_ids)) <> 5
     or (select count(*) from public.profiles where id = any(actor_ids)) <> 5
     or (select count(*) from public.role_assignments where user_id = any(actor_ids)) <> 5
     or not exists (
       select 1 from public.divisions
       where id = current_setting('sitaa_test.division_id')::uuid
     )
     or not exists (
       select 1 from public.academic_programs
       where id = current_setting('sitaa_test.program_id')::uuid
     )
     or not exists (
       select 1 from public.academic_periods
       where id = current_setting('sitaa_test.academic_period_id')::uuid
     ) then
    raise exception 'Fixture 0003 inválida: el grafo sintético está incompleto.';
  end if;

  if exists (
    select 1
    from public.activities a
    left join public.academic_programs ap on ap.id = a.program_id
    where a.id = any(fixture_activity_ids)
      and (a.program_id is null or ap.id is null)
  ) then
    raise exception 'Fixture 0003 inválida: existe un program_id sin academic_programs.';
  end if;

  if exists (
    select 1
    from public.activities a
    left join public.divisions d on d.id = a.division_id
    left join public.academic_programs ap
      on ap.id = a.program_id and ap.division_id = a.division_id
    where a.id = any(fixture_activity_ids)
      and (a.division_id is null or d.id is null or ap.id is null)
  ) then
    raise exception 'Fixture 0003 inválida: división ausente o programa fuera de su división.';
  end if;

  if exists (
    select 1
    from public.activities a
    left join public.academic_periods sem on sem.id = a.academic_period_id
    where a.id = any(fixture_activity_ids)
      and a.academic_period_id is not null
      and sem.id is null
  ) then
    raise exception 'Fixture 0003 inválida: existe academic_period_id sin semestre.';
  end if;

  if exists (
    select 1
    from public.activities a
    left join auth.users creator on creator.id = a.created_by
    where a.id = any(fixture_activity_ids)
      and creator.id is null
  ) then
    raise exception 'Fixture 0003 inválida: existe created_by sin usuario Auth.';
  end if;

  if exists (
    select 1
    from public.activities a
    left join public.profiles responsible on responsible.id = a.responsible_profile_id
    where a.id = any(fixture_activity_ids)
      and (a.responsible_profile_id is null or responsible.id is null)
  ) then
    raise exception 'Fixture 0003 inválida: responsible_profile_id no resuelve a profiles.';
  end if;

  if exists (
    select 1
    from public.profiles p
    left join auth.users u on u.id = p.id
    left join public.academic_programs ap on ap.id = p.primary_program_id
    where p.id = any(actor_ids)
      and (u.id is null or ap.id is null)
  ) then
    raise exception 'Fixture 0003 inválida: un perfil no resuelve a Auth o a su programa.';
  end if;

  if exists (
    select 1
    from public.role_assignments ra
    left join public.profiles p on p.id = ra.user_id
    left join public.roles r on r.code = ra.role_code
    left join public.academic_programs ap on ap.id = ra.program_id
    left join public.divisions d on d.id = ra.division_id
    where ra.user_id = any(actor_ids) and (
      p.id is null or r.code is null
      or (ra.program_id is not null and ap.id is null)
      or (ra.division_id is not null and d.id is null)
    )
  ) then
    raise exception 'Fixture 0003 inválida: una asignación no resuelve perfil, rol o alcance.';
  end if;

  if exists (
    select 1
    from public.activities a
    left join public.activity_statuses ast on ast.code = a.status_code
    left join public.activity_types aty on aty.code = a.activity_type_code
    left join public.service_types st on st.code = a.service_type_code
    left join public.attention_categories ac on ac.code = a.attention_category_code
    left join public.activity_modalities am on am.code = a.modality_code
    left join public.location_types lt on lt.code = a.location_type_code
    where a.id = any(fixture_activity_ids)
      and (ast.code is null or aty.code is null or st.code is null
        or ac.code is null or am.code is null or lt.code is null)
  ) then
    raise exception 'Fixture 0003 inválida: una actividad usa un catálogo inexistente.';
  end if;
end;
$verify_fixture_integrity$;

insert into sitaa_0003_results values ('fixture_foreign_keys_valid', true);

-- Helper temporal de seguridad: prueba helpers y RLS con el actor autenticado.
create or replace function pg_temp.assert_foreign_drafts_denied(actor_label text)
returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  draft_ids uuid[] := array[
    current_setting('sitaa_test.draft_without_schedule_id')::uuid,
    current_setting('sitaa_test.draft_past_no_time_id')::uuid,
    current_setting('sitaa_test.draft_past_complete_id')::uuid,
    current_setting('sitaa_test.draft_future_id')::uuid
  ];
  target_id uuid;
  affected integer;
  visible_count integer;
begin
  foreach target_id in array draft_ids loop
    if public.can_read_activity(target_id)
       or public.can_edit_activity(target_id)
       or public.can_update_activity_base(target_id)
       or public.can_delete_activity(target_id) then
      raise exception '% obtuvo capacidad sobre un borrador ajeno.', actor_label;
    end if;
  end loop;

  select count(*) into visible_count
  from public.activities where id = any(draft_ids);
  if visible_count <> 0 then
    raise exception 'RLS expuso % borradores ajenos a %.', visible_count, actor_label;
  end if;

  update public.activities set title = title
  where id = any(draft_ids);
  get diagnostics affected = row_count;
  if affected <> 0 then
    raise exception 'RLS permitió UPDATE de borrador ajeno a %.', actor_label;
  end if;

  delete from public.activities where id = any(draft_ids);
  get diagnostics affected = row_count;
  if affected <> 0 then
    raise exception 'RLS permitió DELETE de borrador ajeno a %.', actor_label;
  end if;
end;
$$;

-- 4. Creador: las cuatro variantes nunca terminan, son editables y eliminables.
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.creator_id'), true);
select set_config(
  'request.jwt.claims',
  jsonb_build_object('sub', current_setting('sitaa_test.creator_id'), 'role', 'authenticated')::text,
  true
);
set local role authenticated;

do $verify_creator$
declare
  draft_ids uuid[] := array[
    current_setting('sitaa_test.draft_without_schedule_id')::uuid,
    current_setting('sitaa_test.draft_past_no_time_id')::uuid,
    current_setting('sitaa_test.draft_past_complete_id')::uuid,
    current_setting('sitaa_test.draft_future_id')::uuid
  ];
  target_id uuid;
  affected integer;
  visible_count integer;
  preserved_count integer;
  rejected boolean;
  rejection_message text;
begin
  foreach target_id in array draft_ids loop
    if public.activity_has_ended(target_id) is distinct from false then
      raise exception 'Un borrador provisional fue considerado ocurrido: %.', target_id;
    end if;
    if not public.can_read_activity(target_id)
       or not public.can_edit_activity(target_id)
       or not public.can_update_activity_base(target_id)
       or not public.can_delete_activity(target_id) then
      raise exception 'El creador no conserva todas las capacidades sobre el borrador %.', target_id;
    end if;
  end loop;

  select count(*) into visible_count
  from public.activities where id = any(draft_ids);
  if visible_count <> 4 then
    raise exception 'RLS no mostró al creador sus cuatro borradores.';
  end if;

  update public.activities
  set title = title || ' [actualizado]'
  where id = any(draft_ids);
  get diagnostics affected = row_count;
  if affected <> 4 then
    raise exception 'RLS sólo permitió actualizar % de 4 borradores propios.', affected;
  end if;

  rejected := false;
  begin
    update public.activities
    set created_by = current_setting('sitaa_test.other_professor_id')::uuid
    where id = current_setting('sitaa_test.draft_future_id')::uuid;
  exception when check_violation then
    rejected := true;
  end;
  if not rejected or exists (
    select 1 from public.activities
    where id = current_setting('sitaa_test.draft_future_id')::uuid
      and created_by <> current_setting('sitaa_test.creator_id')::uuid
  ) then
    raise exception 'La regla 0002 dejó de mantener created_by inmutable.';
  end if;

  if public.activity_has_ended(current_setting('sitaa_test.published_elapsed_id')::uuid)
     is distinct from true then
    raise exception 'Una actividad publicada pasada dejó de considerarse ocurrida.';
  end if;

  rejected := false;
  rejection_message := null;
  begin
    perform * from public.publish_activity(
      current_setting('sitaa_test.draft_without_schedule_id')::uuid
    );
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
    perform * from public.publish_activity(
      current_setting('sitaa_test.draft_past_complete_id')::uuid
    );
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
      current_setting('sitaa_test.draft_without_schedule_id')::uuid,
      current_setting('sitaa_test.draft_past_complete_id')::uuid
    )
    and status_code = 'draft';
  if preserved_count <> 2 then
    raise exception 'Un intento fallido de publicación no conservó ambos borradores.';
  end if;

  update public.activities
  set description = 'Borrador rechazado aún editable 0003'
  where id in (
    current_setting('sitaa_test.draft_without_schedule_id')::uuid,
    current_setting('sitaa_test.draft_past_complete_id')::uuid
  );
  get diagnostics affected = row_count;
  if affected <> 2
     or not public.can_delete_activity(current_setting('sitaa_test.draft_without_schedule_id')::uuid)
     or not public.can_delete_activity(current_setting('sitaa_test.draft_past_complete_id')::uuid) then
    raise exception 'Un borrador rechazado dejó de ser editable o eliminable.';
  end if;
end;
$verify_creator$;

reset role;

insert into sitaa_0003_results values
  ('drafts_never_end', true),
  ('creator_can_update_drafts', true),
  ('published_elapsed_activity_has_ended', true),
  ('invalid_publication_rejected', true),
  ('rejected_publication_remains_editable_draft', true);

-- 5. Profesor ajeno, responsable/gestor y alumno no acceden a borradores.
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.other_professor_id'), true);
select set_config(
  'request.jwt.claims',
  jsonb_build_object('sub', current_setting('sitaa_test.other_professor_id'), 'role', 'authenticated')::text,
  true
);
set local role authenticated;
select pg_temp.assert_foreign_drafts_denied('otro profesor');
reset role;

select set_config('request.jwt.claim.sub', current_setting('sitaa_test.management_user_id'), true);
select set_config(
  'request.jwt.claims',
  jsonb_build_object('sub', current_setting('sitaa_test.management_user_id'), 'role', 'authenticated')::text,
  true
);
set local role authenticated;
select pg_temp.assert_foreign_drafts_denied('responsable/gestor');
do $verify_manager_published_access$
declare
  transition_rejected boolean := false;
begin
  if not public.can_read_activity(current_setting('sitaa_test.published_elapsed_id')::uuid)
     or not public.can_edit_activity(current_setting('sitaa_test.published_elapsed_id')::uuid)
     or not public.can_update_activity_base(current_setting('sitaa_test.published_elapsed_id')::uuid)
     or not public.can_delete_activity(current_setting('sitaa_test.published_elapsed_id')::uuid) then
    raise exception 'Las reglas 0002 dejaron de permitir gestión sobre contenido publicado.';
  end if;

  begin
    update public.activities
    set status_code = 'draft'
    where id = current_setting('sitaa_test.published_elapsed_id')::uuid;
  exception when check_violation then
    transition_rejected := true;
  end;
  if not transition_rejected or exists (
    select 1 from public.activities
    where id = current_setting('sitaa_test.published_elapsed_id')::uuid
      and status_code = 'draft'
  ) then
    raise exception 'La regla 0002 permitió que contenido publicado volviera a borrador.';
  end if;
end;
$verify_manager_published_access$;
reset role;

select set_config('request.jwt.claim.sub', current_setting('sitaa_test.student_id'), true);
select set_config(
  'request.jwt.claims',
  jsonb_build_object('sub', current_setting('sitaa_test.student_id'), 'role', 'authenticated')::text,
  true
);
set local role authenticated;
select pg_temp.assert_foreign_drafts_denied('alumno');
reset role;

insert into sitaa_0003_results values ('other_users_cannot_access_drafts', true);

-- 6. technical_admin conserva gestión publicada, pero no amplía borradores.
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.technical_admin_id'), true);
select set_config(
  'request.jwt.claims',
  jsonb_build_object('sub', current_setting('sitaa_test.technical_admin_id'), 'role', 'authenticated')::text,
  true
);
set local role authenticated;
select pg_temp.assert_foreign_drafts_denied('technical_admin');
do $verify_technical_admin_published_access$
begin
  if not public.can_manage_activity(
    'program',
    current_setting('sitaa_test.program_id')::uuid,
    current_setting('sitaa_test.division_id')::uuid,
    'tutoring'
  ) then
    raise exception 'La fixture technical_admin no conserva su alcance publicado.';
  end if;
  if not public.can_read_activity(current_setting('sitaa_test.published_elapsed_id')::uuid)
     or not public.can_edit_activity(current_setting('sitaa_test.published_elapsed_id')::uuid)
     or not public.can_update_activity_base(current_setting('sitaa_test.published_elapsed_id')::uuid)
     or not public.can_delete_activity(current_setting('sitaa_test.published_elapsed_id')::uuid) then
    raise exception '0003 restringió el acceso amplio diferido de technical_admin a contenido publicado.';
  end if;
end;
$verify_technical_admin_published_access$;
reset role;

insert into sitaa_0003_results
values ('technical_admin_cannot_access_foreign_drafts', true);

-- 7. El creador elimina realmente las cuatro variantes después de que todos los
-- demás actores probaron su aislamiento.
select set_config('request.jwt.claim.sub', current_setting('sitaa_test.creator_id'), true);
select set_config(
  'request.jwt.claims',
  jsonb_build_object('sub', current_setting('sitaa_test.creator_id'), 'role', 'authenticated')::text,
  true
);
set local role authenticated;
do $verify_creator_delete$
declare
  affected integer;
begin
  delete from public.activities
  where id in (
    current_setting('sitaa_test.draft_without_schedule_id')::uuid,
    current_setting('sitaa_test.draft_past_no_time_id')::uuid,
    current_setting('sitaa_test.draft_past_complete_id')::uuid,
    current_setting('sitaa_test.draft_future_id')::uuid
  );
  get diagnostics affected = row_count;
  if affected <> 4 then
    raise exception 'RLS sólo permitió eliminar % de 4 borradores propios.', affected;
  end if;
end;
$verify_creator_delete$;
reset role;

insert into sitaa_0003_results values ('creator_can_delete_drafts', true);

-- Salida compacta y estable para conservar evidencia sin datos operativos.
select check_name as verificacion, passed as resultado
from sitaa_0003_results
order by array_position(
  array[
    'fixture_foreign_keys_valid',
    'drafts_never_end',
    'creator_can_update_drafts',
    'creator_can_delete_drafts',
    'other_users_cannot_access_drafts',
    'technical_admin_cannot_access_foreign_drafts',
    'published_elapsed_activity_has_ended',
    'invalid_publication_rejected',
    'rejected_publication_remains_editable_draft'
  ],
  check_name
);

select 'Verificación 0003 completada; todas las fixtures serán revertidas.' as resultado;

rollback;
