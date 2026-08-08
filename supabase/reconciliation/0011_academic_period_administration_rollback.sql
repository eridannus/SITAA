-- SEM-01 / 0011: rollback conservador hacia el contrato exacto post-0010.
-- Sólo es elegible antes del primer uso administrativo real o publicación que
-- dependa de la semántica nueva. Nunca elimina periodos, actividades ni eventos.

begin;
set transaction isolation level read committed;
set transaction read write;
set local lock_timeout = '5s';
set local statement_timeout = '120s';
set local idle_in_transaction_session_timeout = '120s';
set local timezone = 'UTC';
set local datestyle = 'ISO, YMD';
set local search_path = pg_catalog, public;

do $rollback_shape_guard$
begin
  if current_user <> 'postgres' or session_user <> 'postgres' then
    raise exception 'sitaa_0011_rollback_owner_required' using errcode = '42501';
  end if;
  if current_setting('transaction_isolation') <> 'read committed' then
    raise exception 'sitaa_0011_read_committed_required' using errcode = '25000';
  end if;
  if current_setting('transaction_read_only') <> 'off' then
    raise exception 'sitaa_0011_read_write_required' using errcode = '25006';
  end if;
  if to_regclass('public.academic_period_audit_events') is null
     or to_regprocedure('public.list_admin_academic_periods(integer,integer)') is null
     or to_regprocedure('public.create_admin_academic_period(text,date,date,boolean)') is null
     or to_regprocedure('public.correct_admin_academic_period(uuid,text,date,date,text)') is null
     or to_regprocedure('public.activate_admin_academic_period(uuid,text)') is null
     or to_regprocedure('public.deactivate_admin_academic_period(uuid,text)') is null then
    raise exception 'sitaa_0011_rollback_unexpected_schema' using errcode = '55000';
  end if;
end;
$rollback_shape_guard$;

select pg_catalog.pg_advisory_xact_lock(1397310541, 1101);
lock table public.activities in share row exclusive mode nowait;
lock table public.academic_periods in access exclusive mode nowait;
lock table public.academic_period_audit_events in access exclusive mode nowait;

do $rollback_eligibility$
declare
  dependent_activity_count bigint;
begin
  if (select count(*) from public.academic_period_audit_events) <> 0 then
    raise exception 'sitaa_0011_rollback_audit_history_exists' using errcode = '55000';
  end if;

  if (select count(*) from public.academic_periods) <> 5
     or (
       select md5(string_agg(
         period.id::text || '|' || period.code,
         E'\n' order by period.code collate "C"
       ))
       from public.academic_periods period
     ) <> '8af9fc114f31320519e894770823cc1d'
     or exists (
       (
         select code, name, starts_on, ends_on, is_active, sort_order,
           created_at, updated_at
         from public.academic_periods
       )
       except
       values
         ('pilot'::text, 'Periodo piloto'::text, null::date, null::date, false, 0,
           timestamptz '2026-07-07 21:34:09.731881+00', timestamptz '2026-07-08 22:04:07.767746+00'),
         ('2026-1', '2026-1', date '2025-08-11', date '2025-11-28', true, 202601,
           timestamptz '2026-07-08 22:04:07.767746+00', timestamptz '2026-07-08 22:04:07.767746+00'),
         ('2026-2', '2026-2', date '2026-02-03', date '2026-05-29', true, 202602,
           timestamptz '2026-07-08 22:04:07.767746+00', timestamptz '2026-07-08 22:04:07.767746+00'),
         ('2027-1', '2027-1', date '2026-08-10', date '2026-11-27', true, 202701,
           timestamptz '2026-07-08 22:04:07.767746+00', timestamptz '2026-07-08 22:04:07.767746+00'),
         ('2027-2', '2027-2', date '2027-02-02', date '2027-05-28', true, 202702,
           timestamptz '2026-07-08 22:04:07.767746+00', timestamptz '2026-07-08 22:04:07.767746+00')
     )
     or exists (
       values
         ('pilot'::text, 'Periodo piloto'::text, null::date, null::date, false, 0,
           timestamptz '2026-07-07 21:34:09.731881+00', timestamptz '2026-07-08 22:04:07.767746+00'),
         ('2026-1', '2026-1', date '2025-08-11', date '2025-11-28', true, 202601,
           timestamptz '2026-07-08 22:04:07.767746+00', timestamptz '2026-07-08 22:04:07.767746+00'),
         ('2026-2', '2026-2', date '2026-02-03', date '2026-05-29', true, 202602,
           timestamptz '2026-07-08 22:04:07.767746+00', timestamptz '2026-07-08 22:04:07.767746+00'),
         ('2027-1', '2027-1', date '2026-08-10', date '2026-11-27', true, 202701,
           timestamptz '2026-07-08 22:04:07.767746+00', timestamptz '2026-07-08 22:04:07.767746+00'),
         ('2027-2', '2027-2', date '2027-02-02', date '2027-05-28', true, 202702,
           timestamptz '2026-07-08 22:04:07.767746+00', timestamptz '2026-07-08 22:04:07.767746+00')
       except
       select code, name, starts_on, ends_on, is_active, sort_order,
         created_at, updated_at
       from public.academic_periods
     ) then
    raise exception 'sitaa_0011_rollback_period_baseline_changed' using errcode = '55000';
  end if;

  with old_resolution as (
    select
      activity.id,
      activity.status_code,
      activity.academic_period_id,
      (
        select period.id
        from public.academic_periods period
        where period.is_active
          and period.code <> 'pilot'
          and period.starts_on is not null
          and period.starts_on <= activity.start_date
        order by period.starts_on desc
        limit 1
      ) as old_period_id,
      resolved.id as new_period_id
    from public.activities activity
    left join lateral public.get_academic_period_for_date(activity.start_date) resolved on true
  )
  select count(*) into dependent_activity_count
  from old_resolution
  where status_code <> 'draft'
    and (
      academic_period_id is distinct from old_period_id
      or academic_period_id is distinct from new_period_id
      or old_period_id is distinct from new_period_id
    );

  if dependent_activity_count <> 0 then
    raise exception 'sitaa_0011_rollback_dependent_activity_exists' using errcode = '55000';
  end if;

  if exists (
    select 1
    from pg_catalog.pg_constraint constraint_info
    where constraint_info.confrelid = 'public.academic_period_audit_events'::regclass
      and constraint_info.conrelid <> 'public.academic_period_audit_events'::regclass
  ) then
    raise exception 'sitaa_0011_rollback_new_dependency_exists' using errcode = '55000';
  end if;
end;
$rollback_eligibility$;

drop trigger activities_sem01_lock_update on public.activities;
drop trigger activities_sem01_lock_insert on public.activities;
drop trigger academic_periods_set_updated_at_sem01 on public.academic_periods;
drop trigger academic_periods_guard_truncate_sem01 on public.academic_periods;
drop trigger academic_periods_guard_sem01 on public.academic_periods;

drop function public.list_admin_academic_periods(integer, integer);
drop function public.create_admin_academic_period(text, date, date, boolean);
drop function public.correct_admin_academic_period(uuid, text, date, date, text);
drop function public.activate_admin_academic_period(uuid, text);
drop function public.deactivate_admin_academic_period(uuid, text);

drop table public.academic_period_audit_events;

alter table public.academic_periods
  drop constraint academic_periods_active_date_range_excl;
alter table public.academic_periods
  drop constraint academic_periods_sem01_shape_check;

drop function public.diagnose_academic_period_impact_0011(text, uuid, text, text, date, date, boolean);
drop function public.resolve_academic_period_proposal_0011(date, text, uuid, text, text, date, date, boolean);
drop function public.lock_and_reauthorize_sem01_admin_0011(uuid);
drop function public.is_exact_sem01_period_admin_0011(uuid);
drop function public.normalize_sem01_reason_0011(text);
drop function public.is_sem01_audit_payload_valid_0011(text, text[], jsonb, jsonb);
drop function public.acquire_sem01_calendar_lock_0011();
drop function public.guard_academic_periods_sem01_0011();
drop function public.set_academic_period_updated_at_0011();
drop function public.guard_academic_period_audit_append_only_0011();

-- Definiciones exactas reconciliadas post-0010.
create or replace function public.get_academic_period_for_date(target_date date)
returns table(id uuid, code text, name text, starts_on date, ends_on date)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select
    ap.id,
    ap.code,
    ap.name,
    ap.starts_on,
    ap.ends_on
  from public.academic_periods ap
  where
    ap.is_active = true
    and ap.starts_on is not null
    and ap.starts_on <= target_date
  order by ap.starts_on desc
  limit 1;
$function$;

create or replace function public.publish_activity(target_activity_id uuid)
returns table(activity_id uuid, status_code text, academic_period_id uuid, semester_label text)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  target_activity public.activities%rowtype;
  target_period_id uuid;
  target_semester_label text;
  start_value timestamp;
begin
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;
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
  if target_activity.created_by is distinct from auth.uid() then
    raise exception 'Sólo el creador puede publicar esta actividad.' using errcode = '42501';
  end if;
  if target_activity.status_code <> 'draft' then
    raise exception 'Sólo pueden publicarse actividades en borrador.' using errcode = 'P0001';
  end if;
  if public.can_create_activity(
    target_activity.scope_type,
    target_activity.program_id,
    target_activity.division_id,
    target_activity.service_type_code
  ) is distinct from true then
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
$function$;

create or replace function public.validate_activity_scheduled_state()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
declare
  expected_period_id uuid;
  start_value timestamp;
  end_value timestamp;
  require_future_start boolean := false;
  trusted_database_role boolean := current_user in ('postgres', 'service_role');
begin
  if tg_op = 'UPDATE' and not trusted_database_role then
    if new.created_by is distinct from old.created_by then
      raise exception 'No se puede cambiar el creador de una actividad.' using errcode = '23514';
    end if;
    if old.status_code <> 'draft' and new.status_code = 'draft' then
      raise exception 'Una actividad publicada no puede volver a borrador.' using errcode = '23514';
    end if;
    if old.status_code = 'draft' and new.status_code = 'scheduled' then
      if auth.uid() is null
         or new.created_by is distinct from auth.uid()
         or public.can_create_activity(
           new.scope_type, new.program_id, new.division_id, new.service_type_code
         ) is distinct from true then
        raise exception 'No tienes permiso para publicar esta actividad.' using errcode = '42501';
      end if;
    end if;
  end if;

  if new.status_code <> 'scheduled' then return new; end if;
  if nullif(btrim(new.title), '') is null then raise exception 'Escribe el título de la actividad.' using errcode = '23514'; end if;
  if length(new.title) > 200 then raise exception 'El título no puede exceder 200 caracteres.' using errcode = '23514'; end if;
  if length(coalesce(new.description, '')) > 5000 then raise exception 'La descripción no puede exceder 5000 caracteres.' using errcode = '23514'; end if;

  if new.scope_type = 'program' then
    if new.program_id is null or new.division_id is null or not exists (
      select 1 from public.academic_programs ap
      where ap.id = new.program_id and ap.division_id = new.division_id
    ) then
      raise exception 'El programa y la división no corresponden al alcance de la actividad.' using errcode = '23514';
    end if;
  elsif new.scope_type = 'division' then
    if new.division_id is null or new.program_id is not null then
      raise exception 'El alcance divisional requiere una división y no admite programa.' using errcode = '23514';
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
  if length(new.location_detail) > 500 then raise exception 'El detalle de ubicación no puede exceder 500 caracteres.' using errcode = '23514'; end if;
  if new.modality_code = 'online' and new.location_type_code <> 'online_space' then raise exception 'Una actividad en línea debe usar la ubicación En línea.' using errcode = '23514'; end if;
  if new.modality_code <> 'online' and new.location_type_code = 'online_space' then raise exception 'La ubicación En línea sólo corresponde a la modalidad En línea.' using errcode = '23514'; end if;
  if new.start_date is null then raise exception 'Indica una fecha de inicio válida.' using errcode = '23514'; end if;
  if new.start_time is null then raise exception 'Indica una hora válida en formato de 24 horas.' using errcode = '23514'; end if;
  if new.duration_mode not in ('one_hour', 'two_hours', 'custom') or new.duration_mode is null then raise exception 'Selecciona una duración.' using errcode = '23514'; end if;
  if new.end_date is null then raise exception 'Indica una fecha de término válida.' using errcode = '23514'; end if;
  if new.end_time is null then raise exception 'Indica una hora de término válida en formato de 24 horas.' using errcode = '23514'; end if;

  start_value := new.start_date + new.start_time;
  end_value := new.end_date + new.end_time;
  if end_value <= start_value then raise exception 'El término de la actividad debe ser posterior al inicio.' using errcode = '23514'; end if;
  if new.duration_mode = 'one_hour' and end_value <> start_value + interval '1 hour' then raise exception 'La duración de 1 hora no coincide con la fecha y hora de término.' using errcode = '23514'; end if;
  if new.duration_mode = 'two_hours' and end_value <> start_value + interval '2 hours' then raise exception 'La duración de 2 horas no coincide con la fecha y hora de término.' using errcode = '23514'; end if;
  if new.responsible_profile_id is null then raise exception 'La actividad requiere una persona responsable.' using errcode = '23514'; end if;

  select period.id into expected_period_id
  from public.get_academic_period_for_date(new.start_date) period limit 1;
  if expected_period_id is null then raise exception 'No hay semestre registrado para la fecha de inicio.' using errcode = '23514'; end if;
  if new.academic_period_id is distinct from expected_period_id then raise exception 'El semestre asignado no corresponde a la fecha de inicio.' using errcode = '23514'; end if;

  if tg_op = 'INSERT' then require_future_start := true;
  elsif old.status_code = 'draft' then require_future_start := true;
  end if;
  if require_future_start and (start_value at time zone 'America/Mexico_City') <= now() then
    raise exception 'La fecha y hora de inicio deben ser posteriores a la hora actual de Ciudad de México.' using errcode = '23514';
  end if;
  return new;
end;
$function$;

revoke all privileges on function public.get_academic_period_for_date(date)
  from public, anon, authenticated, service_role;
grant execute on function public.get_academic_period_for_date(date)
  to authenticated, service_role;
revoke all privileges on function public.publish_activity(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.publish_activity(uuid)
  to authenticated, service_role;
revoke all privileges on function public.validate_activity_scheduled_state()
  from public, anon, authenticated, service_role;
grant execute on function public.validate_activity_scheduled_state()
  to authenticated, service_role;

revoke all privileges on table public.academic_periods
  from public, anon, authenticated, service_role;
grant select on table public.academic_periods to authenticated;
grant all privileges on table public.academic_periods to service_role;

do $rollback_postconditions$
begin
  if to_regclass('public.academic_period_audit_events') is not null
     or to_regprocedure('public.list_admin_academic_periods(integer,integer)') is not null
     or exists (
       select 1 from pg_catalog.pg_trigger
       where tgrelid = 'public.activities'::regclass
         and tgname like 'activities_sem01_lock_%'
         and not tgisinternal
     )
     or exists (
       select 1 from pg_catalog.pg_constraint
       where conrelid = 'public.academic_periods'::regclass
         and conname in (
           'academic_periods_sem01_shape_check',
           'academic_periods_active_date_range_excl'
         )
     ) then
    raise exception 'sitaa_0011_rollback_residual_object' using errcode = '55000';
  end if;

  if md5(btrim(regexp_replace(pg_catalog.pg_get_functiondef(
       'public.get_academic_period_for_date(date)'::regprocedure
     ), E'\\s+', ' ', 'g'))) <> 'dd112ebab92161480ffedfe0d094b297'
     or md5(btrim(regexp_replace(pg_catalog.pg_get_functiondef(
       'public.publish_activity(uuid)'::regprocedure
     ), E'\\s+', ' ', 'g'))) <> '3351926e90e96d49774ae2fed556586d'
     or md5(btrim(regexp_replace(pg_catalog.pg_get_functiondef(
       'public.validate_activity_scheduled_state()'::regprocedure
     ), E'\\s+', ' ', 'g'))) <> '940439094000f003c6e7a531dd46a7d7' then
    raise exception 'sitaa_0011_rollback_function_restore_failed' using errcode = '55000';
  end if;

  if not has_table_privilege('authenticated', 'public.academic_periods', 'SELECT')
     or not has_table_privilege('service_role', 'public.academic_periods', 'INSERT')
     or not has_table_privilege('service_role', 'public.academic_periods', 'UPDATE')
     or not has_table_privilege('service_role', 'public.academic_periods', 'DELETE') then
    raise exception 'sitaa_0011_rollback_acl_restore_failed' using errcode = '55000';
  end if;
end;
$rollback_postconditions$;

commit;
