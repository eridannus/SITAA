-- SITAA 0002: consolidación de seguridad e integridad
--
-- Prerrequisitos:
--   * 0001_baseline_current_schema.sql representa el esquema vivo reconciliado.
--   * Revisar el resultado del preflight y ejecutar primero en un entorno no productivo.
--   * Aplicar en una ventana controlada: la tabla public.activities se bloquea contra
--     escrituras durante la validación y la instalación del trigger.
--
-- Alcance exacto:
--   1. Borradores visibles y editables exclusivamente por su creador.
--   2. Rechazo de Pendiente después del plazo natural de asistencia.
--   3. Publicación transaccional mediante public.publish_activity(uuid) e integridad
--      condicional de filas programadas.
--   4. Privilegios directos mínimos confirmados por los snapshots vivos.
--
-- Fuera de alcance:
--   * technical_admin conserva intencionalmente su acceso amplio sobre contenido
--     publicado durante desarrollo y pruebas.
--   * No se retiran overloads heredados, columnas de compatibilidad, alcance
--     divisional reservado ni capacidad de tokens de registro.
--   * No se modifican privilegios predeterminados porque pg_default_acl no fue
--     reconciliado.
--
-- Esta migración no elimina ni reescribe datos operativos.

begin;

-- Evita que una escritura concurrente introduzca una fila programada incompatible
-- entre el preflight y la creación del trigger.
lock table public.activities in share row exclusive mode;

-- -----------------------------------------------------------------------------
-- Preflight: actividades programadas incompatibles
-- -----------------------------------------------------------------------------
-- La consulta es deliberadamente de sólo lectura. Reporta cada id y todas las
-- condiciones incompatibles antes de que el bloque siguiente aborte la migración.
with scheduled_validation as (
  select
    a.id,
    array_remove(array[
      case when nullif(btrim(a.title), '') is null then 'title' end,
      case when length(a.title) > 200 then 'title_length' end,
      case when length(coalesce(a.description, '')) > 5000 then 'description_length' end,
      case
        when a.scope_type = 'program' and not exists (
          select 1
          from public.academic_programs ap
          where ap.id = a.program_id
            and ap.division_id = a.division_id
        ) then 'program_scope'
        when a.scope_type = 'division' and (a.division_id is null or a.program_id is not null)
          then 'division_scope'
        when a.scope_type not in ('program', 'division') or a.scope_type is null
          then 'scope_type'
      end,
      case when a.activity_type_code is null then 'activity_type_code' end,
      case when a.service_type_code is null then 'service_type_code' end,
      case when a.attention_category_code is null then 'attention_category_code' end,
      case when a.modality_code is null then 'modality_code' end,
      case when a.location_type_code is null then 'location_type_code' end,
      case when nullif(btrim(a.location_detail), '') is null then 'location_detail' end,
      case when length(coalesce(a.location_detail, '')) > 500 then 'location_detail_length' end,
      case when a.start_date is null then 'start_date' end,
      case when a.start_time is null then 'start_time' end,
      case when a.duration_mode not in ('one_hour', 'two_hours', 'custom') or a.duration_mode is null
        then 'duration_mode'
      end,
      case when a.end_date is null then 'end_date' end,
      case when a.end_time is null then 'end_time' end,
      case
        when a.start_date is not null and a.start_time is not null
          and a.end_date is not null and a.end_time is not null
          and (a.end_date + a.end_time) <= (a.start_date + a.start_time)
          then 'time_order'
      end,
      case
        when a.duration_mode = 'one_hour'
          and a.start_date is not null and a.start_time is not null
          and a.end_date is not null and a.end_time is not null
          and (a.end_date + a.end_time) <> (a.start_date + a.start_time + interval '1 hour')
          then 'one_hour_end'
      end,
      case
        when a.duration_mode = 'two_hours'
          and a.start_date is not null and a.start_time is not null
          and a.end_date is not null and a.end_time is not null
          and (a.end_date + a.end_time) <> (a.start_date + a.start_time + interval '2 hours')
          then 'two_hours_end'
      end,
      case
        when a.modality_code = 'online' and a.location_type_code <> 'online_space'
          then 'online_location'
        when a.modality_code <> 'online' and a.location_type_code = 'online_space'
          then 'non_online_location'
      end,
      case when a.responsible_profile_id is null then 'responsible_profile_id' end,
      case
        when a.academic_period_id is null or expected_period.id is null
          or a.academic_period_id <> expected_period.id
          then 'academic_period_id'
      end
    ]::text[], null) as issues
  from public.activities a
  left join lateral public.get_academic_period_for_date(a.start_date) expected_period on true
  where a.status_code = 'scheduled'
)
select id, issues
from scheduled_validation
where cardinality(issues) > 0
order by id;

do $preflight$
declare
  incompatible_count integer;
  incompatible_ids text;
begin
  with invalid_scheduled as (
    select a.id
    from public.activities a
    left join lateral public.get_academic_period_for_date(a.start_date) expected_period on true
    where a.status_code = 'scheduled'
      and (
        nullif(btrim(a.title), '') is null
        or length(a.title) > 200
        or length(coalesce(a.description, '')) > 5000
        or a.scope_type is null
        or a.scope_type not in ('program', 'division')
        or (
          a.scope_type = 'program'
          and not exists (
            select 1
            from public.academic_programs ap
            where ap.id = a.program_id
              and ap.division_id = a.division_id
          )
        )
        or (a.scope_type = 'division' and (a.division_id is null or a.program_id is not null))
        or a.activity_type_code is null
        or a.service_type_code is null
        or a.attention_category_code is null
        or a.modality_code is null
        or a.location_type_code is null
        or nullif(btrim(a.location_detail), '') is null
        or length(coalesce(a.location_detail, '')) > 500
        or a.start_date is null
        or a.start_time is null
        or a.duration_mode is null
        or a.duration_mode not in ('one_hour', 'two_hours', 'custom')
        or a.end_date is null
        or a.end_time is null
        or (
          a.start_date is not null and a.start_time is not null
          and a.end_date is not null and a.end_time is not null
          and (a.end_date + a.end_time) <= (a.start_date + a.start_time)
        )
        or (
          a.duration_mode = 'one_hour'
          and a.start_date is not null and a.start_time is not null
          and a.end_date is not null and a.end_time is not null
          and (a.end_date + a.end_time) <> (a.start_date + a.start_time + interval '1 hour')
        )
        or (
          a.duration_mode = 'two_hours'
          and a.start_date is not null and a.start_time is not null
          and a.end_date is not null and a.end_time is not null
          and (a.end_date + a.end_time) <> (a.start_date + a.start_time + interval '2 hours')
        )
        or (a.modality_code = 'online' and a.location_type_code <> 'online_space')
        or (a.modality_code <> 'online' and a.location_type_code = 'online_space')
        or a.responsible_profile_id is null
        or a.academic_period_id is null
        or expected_period.id is null
        or a.academic_period_id <> expected_period.id
      )
  )
  select count(*), string_agg(id::text, ', ' order by id::text)
  into incompatible_count, incompatible_ids
  from invalid_scheduled;

  if incompatible_count > 0 then
    raise exception
      '0002 abortada: % actividad(es) programada(s) incumplen el contrato de publicación. IDs: %',
      incompatible_count,
      incompatible_ids
      using errcode = 'P0001';
  end if;
end;
$preflight$;

-- -----------------------------------------------------------------------------
-- Borradores privados: helpers y RLS
-- -----------------------------------------------------------------------------

create or replace function public.can_read_activity(target_activity_id uuid)
returns boolean language sql stable security definer set search_path to 'public'
as $$
  select exists (
    select 1 from public.activities a
    where a.id = target_activity_id
      and (
        (a.status_code = 'draft' and a.created_by = auth.uid())
        or (
          a.status_code <> 'draft'
          and (
            a.created_by = auth.uid()
            or a.responsible_profile_id = auth.uid()
            or public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)
          )
        )
      )
  );
$$;

create or replace function public.can_edit_activity(target_activity_id uuid)
returns boolean language sql stable security definer set search_path to 'public'
as $$
  select exists (
    select 1 from public.activities a
    where a.id = target_activity_id
      and (
        (a.status_code = 'draft' and a.created_by = auth.uid())
        or (
          a.status_code <> 'draft'
          and (
            a.created_by = auth.uid()
            or a.responsible_profile_id = auth.uid()
            or public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)
          )
        )
      )
  );
$$;

create or replace function public.can_update_activity_base(target_activity_id uuid)
returns boolean language sql stable security definer set search_path to 'public'
as $$
  select exists (
    select 1 from public.activities a
    where a.id = target_activity_id
      and (
        (
          a.status_code = 'draft'
          and a.created_by = auth.uid()
          and not public.activity_has_ended(a.id)
        )
        or (
          a.status_code <> 'draft'
          and public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)
        )
      )
  );
$$;

create or replace function public.can_delete_activity(target_activity_id uuid)
returns boolean language sql stable security definer set search_path to 'public'
as $$
  select exists (
    select 1 from public.activities a
    where a.id = target_activity_id
      and (
        (
          a.status_code = 'draft'
          and a.created_by = auth.uid()
          and not public.activity_has_ended(a.id)
        )
        or (
          a.status_code <> 'draft'
          and public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)
        )
      )
  );
$$;

drop policy if exists "Users can read permitted activities" on public.activities;
create policy "Users can read permitted activities"
on public.activities for select to authenticated
using (
  (status_code = 'draft' and created_by = auth.uid())
  or (
    status_code <> 'draft'
    and (
      created_by = auth.uid()
      or responsible_profile_id = auth.uid()
      or public.is_activity_participant(id)
      or public.can_manage_activity(scope_type, program_id, division_id, service_type_code)
    )
  )
);

drop policy if exists "Users can read permitted activity participants" on public.activity_participants;
create policy "Users can read permitted activity participants"
on public.activity_participants for select to authenticated
using (profile_id = auth.uid() or public.can_read_activity(activity_id));

-- -----------------------------------------------------------------------------
-- Pendiente sólo dentro del plazo natural
-- -----------------------------------------------------------------------------

create or replace function public.update_activity_participant_attendance(
  target_participant_id uuid,
  new_attendance_status text,
  new_attendance_notes text default null::text
)
returns void language plpgsql security definer set search_path to 'public'
as $$
declare
  target_activity_id uuid;
  natural_deadline timestamptz;
begin
  if new_attendance_status not in ('pending', 'attended', 'absent', 'justified') then
    raise exception 'El estado de asistencia no es válido.' using errcode = 'P0001';
  end if;

  select ap.activity_id into target_activity_id
  from public.activity_participants ap
  where ap.id = target_participant_id;

  if target_activity_id is null then
    raise exception 'El participante no existe.' using errcode = 'P0001';
  end if;
  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para modificar la asistencia de esta actividad.'
      using errcode = '42501';
  end if;

  if new_attendance_status = 'pending' then
    natural_deadline := public.activity_attendance_deadline(target_activity_id);
    if natural_deadline is null or now() > natural_deadline then
      raise exception 'La ventana de asistencia ya terminó; el estado Pendiente ya no está disponible.'
        using errcode = 'P0001';
    end if;
  end if;

  update public.activity_participants
  set attendance_status = new_attendance_status,
      attendance_source = 'manual',
      attendance_updated_by = auth.uid(),
      attendance_updated_at = now(),
      attendance_notes = nullif(trim(coalesce(new_attendance_notes, '')), ''),
      checked_in_at = case when new_attendance_status = 'attended' then checked_in_at else null end,
      updated_at = now()
  where id = target_participant_id;
end;
$$;

create or replace function public.update_activity_participants_attendance_bulk(
  target_activity_id uuid,
  target_participant_ids uuid[],
  new_attendance_status text,
  new_attendance_notes text default null::text
)
returns integer language plpgsql security definer set search_path to 'public'
as $$
declare
  updated_count integer;
  natural_deadline timestamptz;
begin
  if new_attendance_status not in ('pending', 'attended', 'absent', 'justified') then
    raise exception 'El estado de asistencia no es válido.' using errcode = 'P0001';
  end if;
  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para modificar la asistencia de esta actividad.'
      using errcode = '42501';
  end if;
  if target_participant_ids is null or array_length(target_participant_ids, 1) is null then
    raise exception 'No se seleccionaron participantes.' using errcode = 'P0001';
  end if;

  if new_attendance_status = 'pending' then
    natural_deadline := public.activity_attendance_deadline(target_activity_id);
    if natural_deadline is null or now() > natural_deadline then
      raise exception 'La ventana de asistencia ya terminó; el estado Pendiente ya no está disponible.'
        using errcode = 'P0001';
    end if;
  end if;

  update public.activity_participants ap
  set attendance_status = new_attendance_status,
      attendance_source = 'manual',
      attendance_updated_by = auth.uid(),
      attendance_updated_at = now(),
      attendance_notes = nullif(trim(coalesce(new_attendance_notes, '')), ''),
      checked_in_at = case
        when new_attendance_status = 'attended' then coalesce(ap.checked_in_at, now())
        else null
      end,
      updated_at = now()
  where ap.activity_id = target_activity_id
    and ap.id = any(target_participant_ids);

  get diagnostics updated_count = row_count;
  return updated_count;
end;
$$;

-- -----------------------------------------------------------------------------
-- Integridad condicional de actividades programadas
-- -----------------------------------------------------------------------------

create or replace function public.validate_activity_scheduled_state()
returns trigger language plpgsql set search_path to 'public'
as $$
declare
  expected_period_id uuid;
  start_value timestamp;
  end_value timestamp;
  require_future_start boolean := false;
begin
  if new.status_code <> 'scheduled' then return new; end if;

  if nullif(btrim(new.title), '') is null then
    raise exception 'Escribe el título de la actividad.' using errcode = '23514';
  end if;
  if length(new.title) > 200 then
    raise exception 'El título no puede exceder 200 caracteres.' using errcode = '23514';
  end if;
  if length(coalesce(new.description, '')) > 5000 then
    raise exception 'La descripción no puede exceder 5000 caracteres.' using errcode = '23514';
  end if;

  if new.scope_type = 'program' then
    if new.program_id is null or new.division_id is null or not exists (
      select 1 from public.academic_programs ap
      where ap.id = new.program_id and ap.division_id = new.division_id
    ) then
      raise exception 'El programa y la división no corresponden al alcance de la actividad.'
        using errcode = '23514';
    end if;
  elsif new.scope_type = 'division' then
    if new.division_id is null or new.program_id is not null then
      raise exception 'El alcance divisional requiere una división y no admite programa.'
        using errcode = '23514';
    end if;
  else
    raise exception 'El alcance de la actividad no es válido.' using errcode = '23514';
  end if;

  if new.activity_type_code is null then raise exception 'Selecciona un tipo de actividad.' using errcode = '23514'; end if;
  if new.service_type_code is null then raise exception 'Selecciona un tipo de servicio.' using errcode = '23514'; end if;
  if new.attention_category_code is null then raise exception 'Selecciona una categoría de atención.' using errcode = '23514'; end if;
  if new.modality_code is null then raise exception 'Selecciona una modalidad.' using errcode = '23514'; end if;
  if new.location_type_code is null then raise exception 'Selecciona un tipo de ubicación.' using errcode = '23514'; end if;
  if nullif(btrim(new.location_detail), '') is null then
    raise exception 'Indica el lugar, aula, enlace o detalle de acceso de la actividad.' using errcode = '23514';
  end if;
  if length(new.location_detail) > 500 then
    raise exception 'El detalle de ubicación no puede exceder 500 caracteres.' using errcode = '23514';
  end if;
  if new.modality_code = 'online' and new.location_type_code <> 'online_space' then
    raise exception 'Una actividad en línea debe usar la ubicación En línea.' using errcode = '23514';
  end if;
  if new.modality_code <> 'online' and new.location_type_code = 'online_space' then
    raise exception 'La ubicación En línea sólo corresponde a la modalidad En línea.' using errcode = '23514';
  end if;

  if new.start_date is null then raise exception 'Indica una fecha de inicio válida.' using errcode = '23514'; end if;
  if new.start_time is null then raise exception 'Indica una hora válida en formato de 24 horas.' using errcode = '23514'; end if;
  if new.duration_mode not in ('one_hour', 'two_hours', 'custom') or new.duration_mode is null then
    raise exception 'Selecciona una duración.' using errcode = '23514';
  end if;
  if new.end_date is null then raise exception 'Indica una fecha de término válida.' using errcode = '23514'; end if;
  if new.end_time is null then raise exception 'Indica una hora de término válida en formato de 24 horas.' using errcode = '23514'; end if;

  start_value := new.start_date + new.start_time;
  end_value := new.end_date + new.end_time;
  if end_value <= start_value then
    raise exception 'El término de la actividad debe ser posterior al inicio.' using errcode = '23514';
  end if;
  if new.duration_mode = 'one_hour' and end_value <> start_value + interval '1 hour' then
    raise exception 'La duración de 1 hora no coincide con la fecha y hora de término.' using errcode = '23514';
  end if;
  if new.duration_mode = 'two_hours' and end_value <> start_value + interval '2 hours' then
    raise exception 'La duración de 2 horas no coincide con la fecha y hora de término.' using errcode = '23514';
  end if;

  if new.responsible_profile_id is null then
    raise exception 'La actividad requiere una persona responsable.' using errcode = '23514';
  end if;

  select period.id into expected_period_id
  from public.get_academic_period_for_date(new.start_date) period limit 1;
  if expected_period_id is null then
    raise exception 'No hay semestre registrado para la fecha de inicio.' using errcode = '23514';
  end if;
  if new.academic_period_id is distinct from expected_period_id then
    raise exception 'El semestre asignado no corresponde a la fecha de inicio.' using errcode = '23514';
  end if;

  if tg_op = 'INSERT' then
    require_future_start := true;
  elsif old.status_code = 'draft' then
    require_future_start := true;
  end if;
  if require_future_start and (start_value at time zone 'America/Mexico_City') <= now() then
    raise exception 'La fecha y hora de inicio deben ser posteriores a la hora actual de Ciudad de México.'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists validate_activities_scheduled_state on public.activities;
create trigger validate_activities_scheduled_state
before insert or update on public.activities
for each row execute function public.validate_activity_scheduled_state();

create or replace function public.publish_activity(target_activity_id uuid)
returns table(activity_id uuid, status_code text, academic_period_id uuid, semester_label text)
language plpgsql security definer set search_path to 'public'
as $$
declare
  target_activity public.activities%rowtype;
  target_period_id uuid;
  target_semester_label text;
  start_value timestamp;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesión para publicar una actividad.' using errcode = '42501';
  end if;

  select a.* into target_activity
  from public.activities a
  where a.id = target_activity_id
  for update;

  if not found then
    raise exception 'La actividad no existe o no está disponible.' using errcode = 'P0001';
  end if;
  if target_activity.created_by <> auth.uid() then
    raise exception 'Sólo el creador puede publicar esta actividad.' using errcode = '42501';
  end if;
  if target_activity.status_code <> 'draft' then
    raise exception 'Sólo pueden publicarse actividades en borrador.' using errcode = 'P0001';
  end if;
  if not public.can_create_activity(
    target_activity.scope_type,
    target_activity.program_id,
    target_activity.division_id,
    target_activity.service_type_code
  ) then
    raise exception 'Tus asignaciones actuales no permiten publicar esta actividad.'
      using errcode = '42501';
  end if;
  if target_activity.start_date is null or target_activity.start_time is null then
    raise exception 'Indica una fecha y hora de inicio válidas.' using errcode = '23514';
  end if;

  start_value := target_activity.start_date + target_activity.start_time;
  if (start_value at time zone 'America/Mexico_City') <= now() then
    raise exception 'La fecha y hora de inicio deben ser posteriores a la hora actual de Ciudad de México.'
      using errcode = '23514';
  end if;

  select period.id, period.name into target_period_id, target_semester_label
  from public.get_academic_period_for_date(target_activity.start_date) period limit 1;
  if target_period_id is null then
    raise exception 'No hay semestre registrado para la fecha de inicio.' using errcode = '23514';
  end if;

  -- El trigger valida el contrato completo en esta misma sentencia. Cualquier
  -- fallo revierte también la asignación de semestre y el cambio de estado.
  update public.activities a
  set academic_period_id = target_period_id,
      status_code = 'scheduled',
      updated_by = auth.uid()
  where a.id = target_activity_id;

  return query
  select target_activity_id, 'scheduled'::text, target_period_id, target_semester_label;
end;
$$;

-- -----------------------------------------------------------------------------
-- Privilegios mínimos confirmados
-- -----------------------------------------------------------------------------

revoke execute on all functions in schema public from public, anon;
grant execute on function public.publish_activity(uuid) to authenticated, service_role;
revoke execute on function public.publish_activity(uuid) from public, anon;

revoke all privileges on all tables in schema public from anon, authenticated;
grant select on table public.system_health to anon, authenticated;

grant select on table
  public.academic_periods,
  public.academic_programs,
  public.activity_modalities,
  public.activity_statuses,
  public.activity_types,
  public.attention_categories,
  public.divisions,
  public.location_types,
  public.participant_roles,
  public.roles,
  public.service_types
to authenticated;

grant select, update on table public.profiles to authenticated;
grant select on table public.role_assignments to authenticated;
grant select, insert, update, delete on table public.activities to authenticated;
grant select, insert, update, delete on table public.activity_participants to authenticated;

-- activity_checkin_tokens queda sin acceso directo de roles cliente; los flujos
-- continúan exclusivamente mediante RPC autorizadas.
revoke all privileges on sequence public.system_health_id_seq from anon, authenticated;

-- No se cambian grants de postgres, service_role o authenticator. Tampoco se
-- alteran DEFAULT PRIVILEGES en esta migración.
commit;
