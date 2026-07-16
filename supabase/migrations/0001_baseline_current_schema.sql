-- ============================================================================
-- SITAA — baseline reconciliada del esquema vivo de Supabase
-- ============================================================================
--
-- Esta migración representa el esquema vivo reconciliado a partir del snapshot
-- completo generado con pg_dump y psql (UTC: 2026-07-16T18:41:41Z).
--
-- Es el punto de partida para instalaciones nuevas de SITAA. NO debe ejecutarse
-- a ciegas contra la base de datos actual de producción/prototipo, porque ese
-- entorno ya contiene estos objetos y datos por cambios manuales históricos.
--
-- Fuentes de verdad:
-- - supabase/reconciliation/live/live_schema.sql
-- - supabase/reconciliation/live/live_tables.sql
-- - supabase/reconciliation/live/live_columns.sql
-- - supabase/reconciliation/live/live_constraints.sql
-- - supabase/reconciliation/live/live_indexes.sql
-- - supabase/reconciliation/live/live_triggers.sql
-- - supabase/reconciliation/live/live_functions.sql
-- - supabase/reconciliation/live/live_policies.sql
-- - supabase/reconciliation/live/live_seed_catalogs.sql
-- - supabase/reconciliation/live/live_snapshot_metadata.txt
--
-- El dump se normalizó únicamente para retirar los metacomandos efímeros
-- \restrict/\unrestrict de pg_dump y tolerar un esquema public preexistente.
-- Las definiciones de tablas, constraints, índices, triggers, funciones, RLS y
-- políticas permanecen derivadas del estado vivo verificado.
--
-- TODO verificado: el dump se generó con --no-privileges y los snapshots
-- especializados no contienen inventario de grants. Los grants administrados
-- por Supabase deben reconciliarse por separado antes de usar esta baseline en
-- una instalación PostgreSQL independiente de Supabase.
-- ============================================================================

-- Dependencia verificada: las funciones vivas llaman extensions.unaccent(...).
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA extensions;

--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: activity_attendance_deadline(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.activity_attendance_deadline(target_activity_id uuid) RETURNS timestamp with time zone
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select
    (
      (
        coalesce(a.end_date, a.start_date)
        +
        coalesce(a.end_time, a.start_time, time '23:59:59')
      ) at time zone 'America/Mexico_City'
    ) + interval '15 minutes'
  from public.activities a
  where a.id = target_activity_id
    and a.start_date is not null;
$$;


--
-- Name: activity_attendance_open_at(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.activity_attendance_open_at(target_activity_id uuid) RETURNS timestamp with time zone
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select
    (
      (
        a.start_date
        +
        coalesce(a.start_time, time '00:00:00')
      ) at time zone 'America/Mexico_City'
    ) - interval '15 minutes'
  from public.activities a
  where a.id = target_activity_id
    and a.start_date is not null
    and a.start_time is not null;
$$;


--
-- Name: activity_has_ended(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.activity_has_ended(target_activity_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select coalesce(
    (
      coalesce(a.end_date, a.start_date)::timestamp
      + coalesce(a.end_time, a.start_time, time '23:59:59')
    ) < (now() at time zone 'America/Mexico_City'),
    false
  )
  from public.activities a
  where a.id = target_activity_id;
$$;


--
-- Name: add_activity_participant(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_activity_participant(target_activity_id uuid, target_profile_id uuid, target_participant_role_code text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  target_program_id uuid;
  participant_program_id uuid;
  participant_person_type text;
begin
  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para agregar participantes a esta actividad.'
      using errcode = '42501';
  end if;

  select a.program_id
  into target_program_id
  from public.activities a
  where a.id = target_activity_id;

  if target_program_id is null then
    raise exception 'La actividad no tiene programa académico asignado.'
      using errcode = 'P0001';
  end if;

  select
    p.primary_program_id,
    p.person_type
  into
    participant_program_id,
    participant_person_type
  from public.profiles p
  where p.id = target_profile_id
    and p.is_active = true;

  if participant_program_id is null then
    raise exception 'El perfil seleccionado no existe, no está activo o no tiene programa asignado.'
      using errcode = 'P0001';
  end if;

  if participant_program_id <> target_program_id then
    raise exception 'La persona seleccionada pertenece a otro programa académico.'
      using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from public.participant_roles pr
    where pr.code = target_participant_role_code
      and pr.is_active = true
  ) then
    raise exception 'El rol de participante seleccionado no es válido.'
      using errcode = 'P0001';
  end if;

  if target_participant_role_code = 'responsible'
     and participant_person_type <> 'worker' then
    raise exception 'Sólo un trabajador puede registrarse como responsable de la actividad.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.activity_participants ap
    where ap.activity_id = target_activity_id
      and ap.profile_id = target_profile_id
  ) then
    raise exception 'Esta persona ya está registrada como participante en la actividad.'
      using errcode = '23505';
  end if;

  insert into public.activity_participants (
    activity_id,
    profile_id,
    participant_role_code,
    added_by
  )
  values (
    target_activity_id,
    target_profile_id,
    target_participant_role_code,
    auth.uid()
  );
end;
$$;


--
-- Name: can_create_activity(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_create_activity(target_program_id uuid, target_service_type_code text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select
    public.has_any_active_role(array[
      'technical_admin',
      'division_tutoring_liaison',
      'division_head',
      'program_head',
      'program_tutoring_lead',
      'program_advising_lead',
      'professor',
      'peer_tutor'
    ])
    or public.can_manage_activity(target_program_id, target_service_type_code);
$$;


--
-- Name: can_create_activity(text, uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_create_activity(target_scope_type text, target_program_id uuid, target_division_id uuid, target_service_type_code text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.is_active = true
      and (
        public.can_manage_activity(
          target_scope_type,
          target_program_id,
          target_division_id,
          target_service_type_code
        )

        or (
          target_scope_type = 'program'
          and target_program_id = p.primary_program_id
          and public.has_any_active_role(array['professor', 'peer_tutor'])
        )
      )
  );
$$;


--
-- Name: can_delete_activity(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_delete_activity(target_activity_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.activities a
    where a.id = target_activity_id
      and (
        -- Roles de gestión pueden eliminar si corresponde.
        public.can_manage_activity(
          a.scope_type,
          a.program_id,
          a.division_id,
          a.service_type_code
        )

        or

        -- Responsable / creador normal sólo elimina borradores no ocurridos.
        (
          (
            a.created_by = auth.uid()
            or a.responsible_profile_id = auth.uid()
          )
          and a.status_code = 'draft'
          and not public.activity_has_ended(a.id)
        )
      )
  );
$$;


--
-- Name: can_edit_activity(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_edit_activity(target_activity_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.activities a
    where a.id = target_activity_id
      and (
        a.created_by = auth.uid()
        or a.responsible_profile_id = auth.uid()
        or public.can_manage_activity(
          a.scope_type,
          a.program_id,
          a.division_id,
          a.service_type_code
        )
      )
  );
$$;


--
-- Name: can_manage_activity(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_manage_activity(target_program_id uuid, target_service_type_code text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.role_assignments ra
    where ra.user_id = auth.uid()
      and ra.is_active = true
      and ra.starts_at <= current_date
      and (ra.ends_at is null or ra.ends_at >= current_date)
      and (
        ra.role_code = 'technical_admin'
        or ra.role_code = 'division_tutoring_liaison'
        or ra.role_code = 'division_head'
        or (
          ra.role_code = 'program_head'
          and ra.program_id = target_program_id
        )
        or (
          ra.role_code = 'program_tutoring_lead'
          and ra.program_id = target_program_id
          and target_service_type_code = 'tutoring'
        )
        or (
          ra.role_code = 'program_advising_lead'
          and ra.program_id = target_program_id
          and target_service_type_code = 'advising'
        )
      )
  );
$$;


--
-- Name: can_manage_activity(text, uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_manage_activity(target_scope_type text, target_program_id uuid, target_division_id uuid, target_service_type_code text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.role_assignments ra
    where ra.user_id = auth.uid()
      and ra.is_active = true
      and ra.starts_at <= current_date
      and (ra.ends_at is null or ra.ends_at >= current_date)
      and (
        ra.role_code = 'technical_admin'

        or (
          ra.role_code in ('division_tutoring_liaison', 'division_head')
          and ra.scope_type = 'division'
          and ra.division_id = target_division_id
        )

        or (
          target_scope_type = 'program'
          and ra.role_code = 'program_head'
          and ra.program_id = target_program_id
        )

        or (
          target_scope_type = 'program'
          and ra.role_code = 'program_tutoring_lead'
          and ra.program_id = target_program_id
          and target_service_type_code = 'tutoring'
        )

        or (
          target_scope_type = 'program'
          and ra.role_code = 'program_advising_lead'
          and ra.program_id = target_program_id
          and target_service_type_code = 'advising'
        )
      )
  );
$$;


--
-- Name: can_read_activity(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_read_activity(target_activity_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.activities a
    where a.id = target_activity_id
      and (
        a.created_by = auth.uid()
        or a.responsible_profile_id = auth.uid()
        or public.can_manage_activity(
          a.scope_type,
          a.program_id,
          a.division_id,
          a.service_type_code
        )
      )
  );
$$;


--
-- Name: can_update_activity_base(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_update_activity_base(target_activity_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.activities a
    where a.id = target_activity_id
      and (
        -- Roles de gestión pueden corregir datos base.
        public.can_manage_activity(
          a.scope_type,
          a.program_id,
          a.division_id,
          a.service_type_code
        )

        or

        -- Responsable / creador normal sólo puede editar datos base
        -- mientras siga en borrador y no haya ocurrido.
        (
          (
            a.created_by = auth.uid()
            or a.responsible_profile_id = auth.uid()
          )
          and a.status_code = 'draft'
          and not public.activity_has_ended(a.id)
        )
      )
  );
$$;


--
-- Name: check_in_activity(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_in_activity(checkin_input text) RETURNS TABLE(activity_id uuid, activity_title text, attendance_status text, checked_in_at timestamp with time zone, message text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  normalized_input text;
  found_token public.activity_checkin_tokens%rowtype;
  participant_id uuid;
  source_value text;
  existing_status text;
  existing_source text;
begin
  perform public.finalize_expired_attendance();

  normalized_input := regexp_replace(
    extensions.unaccent(lower(trim(checkin_input))),
    '\s+',
    '-',
    'g'
  );

  select *
  into found_token
  from public.activity_checkin_tokens t
  where t.is_active = true
    and t.token_type = 'attendance'
    and (t.expires_at is null or t.expires_at > now())
    and (
      t.secret_token = trim(checkin_input)
      or t.code_words = normalized_input
    )
  order by t.opened_at desc
  limit 1;

  if found_token.id is null then
    raise exception 'El código de asistencia no existe o ya fue cerrado.'
      using errcode = 'P0001';
  end if;

  select ap.id, ap.attendance_status, ap.attendance_source
  into participant_id, existing_status, existing_source
  from public.activity_participants ap
  where ap.activity_id = found_token.activity_id
    and ap.profile_id = auth.uid();

  if participant_id is null then
    raise exception 'No estás registrado como participante en esta actividad.'
      using errcode = '42501';
  end if;

  if existing_status = 'attended' then
    return query
    select
      a.id,
      a.title,
      'attended'::text,
      ap.checked_in_at,
      'Tu asistencia ya estaba registrada.'::text
    from public.activities a
    join public.activity_participants ap
      on ap.activity_id = a.id
     and ap.profile_id = auth.uid()
    where a.id = found_token.activity_id;

    return;
  end if;

  if existing_status = 'justified' then
    return query
    select
      a.id,
      a.title,
      existing_status,
      ap.checked_in_at,
      'Tu asistencia está justificada y no puede modificarse con este código.'::text
    from public.activities a
    join public.activity_participants ap
      on ap.activity_id = a.id
     and ap.profile_id = auth.uid()
    where a.id = found_token.activity_id;

    return;
  end if;

  if existing_status = 'absent' and existing_source <> 'system' then
    return query
    select
      a.id,
      a.title,
      existing_status,
      ap.checked_in_at,
      'Tu asistencia ya fue marcada manualmente. Contacta al responsable de la actividad.'::text
    from public.activities a
    join public.activity_participants ap
      on ap.activity_id = a.id
     and ap.profile_id = auth.uid()
    where a.id = found_token.activity_id;

    return;
  end if;

  source_value := case
    when found_token.secret_token = trim(checkin_input) then 'qr'
    else 'code'
  end;

  update public.activity_participants ap
  set
    attendance_status = 'attended',
    attendance_source = source_value,
    checked_in_at = coalesce(ap.checked_in_at, now()),
    attendance_updated_by = auth.uid(),
    attendance_updated_at = now(),
    updated_at = now()
  where ap.id = participant_id;

  return query
  select
    a.id,
    a.title,
    'attended'::text,
    coalesce(ap.checked_in_at, now()),
    'Asistencia registrada correctamente.'::text
  from public.activities a
  join public.activity_participants ap
    on ap.activity_id = a.id
   and ap.profile_id = auth.uid()
  where a.id = found_token.activity_id;
end;
$$;


--
-- Name: close_activity_attendance_checkin(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.close_activity_attendance_checkin(target_activity_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para cerrar asistencia en esta actividad.'
      using errcode = '42501';
  end if;

  update public.activity_checkin_tokens t
  set
    is_active = false,
    closed_at = now()
  where t.activity_id = target_activity_id
    and t.token_type = 'attendance'
    and t.is_active = true;
end;
$$;


--
-- Name: finalize_expired_attendance(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.finalize_expired_attendance() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  updated_count integer;
begin
  update public.activity_participants ap
  set
    attendance_status = 'absent',
    attendance_source = 'system',
    attendance_updated_by = null,
    attendance_updated_at = now(),
    checked_in_at = null,
    updated_at = now()
  from public.activities a
  where ap.activity_id = a.id
    and ap.attendance_status = 'pending'
    and a.status_code <> 'draft'
    and public.activity_attendance_deadline(a.id) is not null
    and public.activity_attendance_deadline(a.id) <= now();

  get diagnostics updated_count = row_count;

  update public.activity_checkin_tokens t
  set
    is_active = false,
    closed_at = coalesce(t.closed_at, now())
  where t.is_active = true
    and t.token_type = 'attendance'
    and coalesce(t.expires_at, public.activity_attendance_deadline(t.activity_id)) is not null
    and coalesce(t.expires_at, public.activity_attendance_deadline(t.activity_id)) <= now();

  return updated_count;
end;
$$;


--
-- Name: generate_three_word_code(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_three_word_code() RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  words text[] := array[
    'sol', 'luna', 'rio', 'nube', 'mesa', 'patio', 'rama', 'luz',
    'casa', 'libro', 'papel', 'azul', 'verde', 'rojo', 'cafe',
    'plaza', 'puerta', 'silla', 'campo', 'flor', 'piedra', 'mar',
    'monte', 'hoja', 'vaso', 'reloj', 'taza', 'cable', 'mapa',
    'canto', 'pluma', 'techo', 'barco', 'foco', 'arena', 'brisa'
  ];
  code text;
begin
  loop
    code :=
      words[1 + floor(random() * array_length(words, 1))::int]
      || '-' ||
      words[1 + floor(random() * array_length(words, 1))::int]
      || '-' ||
      words[1 + floor(random() * array_length(words, 1))::int];

    exit when not exists (
      select 1
      from public.activity_checkin_tokens t
      where t.code_words = code
        and t.is_active = true
    );
  end loop;

  return code;
end;
$$;


--
-- Name: get_academic_period_for_date(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_academic_period_for_date(target_date date) RETURNS TABLE(id uuid, code text, name text, starts_on date, ends_on date)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: get_active_activity_attendance_checkin(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_active_activity_attendance_checkin(target_activity_id uuid) RETURNS TABLE(id uuid, activity_id uuid, code_words text, secret_token text, opened_at timestamp with time zone, expires_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  open_at timestamptz;
  natural_deadline timestamptz;
begin
  perform public.finalize_expired_attendance();

  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para consultar el código de asistencia de esta actividad.'
      using errcode = '42501';
  end if;

  open_at := public.activity_attendance_open_at(target_activity_id);
  natural_deadline := public.activity_attendance_deadline(target_activity_id);

  if open_at is null or natural_deadline is null then
    update public.activity_checkin_tokens t
    set
      is_active = false,
      closed_at = coalesce(t.closed_at, now())
    where t.activity_id = target_activity_id
      and t.token_type = 'attendance'
      and t.is_active = true;

    return;
  end if;

  if now() < open_at then
    update public.activity_checkin_tokens t
    set
      is_active = false,
      closed_at = coalesce(t.closed_at, now())
    where t.activity_id = target_activity_id
      and t.token_type = 'attendance'
      and t.is_active = true;

    return;
  end if;

  return query
  select
    t.id,
    t.activity_id,
    t.code_words,
    t.secret_token,
    t.opened_at,
    t.expires_at
  from public.activity_checkin_tokens t
  where t.activity_id = target_activity_id
    and t.token_type = 'attendance'
    and t.is_active = true
    and (t.expires_at is null or t.expires_at > now())
  order by t.opened_at desc
  limit 1;
end;
$$;


--
-- Name: get_activity_attendance_checkin_state(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_activity_attendance_checkin_state(target_activity_id uuid) RETURNS TABLE(can_manage boolean, is_draft boolean, has_schedule boolean, has_active_token boolean, can_open_now boolean, window_status text, opens_at timestamp with time zone, ordinary_closes_at timestamp with time zone, active_expires_at timestamp with time zone, message text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_can_edit boolean;
  v_status_code text;
  v_start_ts timestamp;
  v_end_ts timestamp;
  v_current_ts timestamp := now() at time zone 'America/Mexico_City';
  v_open_ts timestamp;
  v_close_ts timestamp;
  v_active_expires_at timestamptz;
  v_has_active_token boolean;
begin
  select
    public.can_edit_activity(a.id),
    a.status_code,
    (a.start_date::timestamp + a.start_time),
    (coalesce(a.end_date, a.start_date)::timestamp + coalesce(a.end_time, a.start_time))
  into
    v_can_edit,
    v_status_code,
    v_start_ts,
    v_end_ts
  from public.activities a
  where a.id = target_activity_id;

  if v_status_code is null then
    raise exception 'La actividad no existe.'
      using errcode = 'P0001';
  end if;

  if not v_can_edit then
    raise exception 'No tienes permiso para consultar la asistencia de esta actividad.'
      using errcode = '42501';
  end if;

  if v_status_code = 'draft' then
    return query select
      v_can_edit,
      true,
      false,
      false,
      false,
      'draft'::text,
      null::timestamptz,
      null::timestamptz,
      null::timestamptz,
      'No puedes abrir asistencia en una actividad en borrador.'::text;
    return;
  end if;

  if v_start_ts is null or v_end_ts is null then
    return query select
      v_can_edit,
      false,
      false,
      false,
      false,
      'missing_schedule'::text,
      null::timestamptz,
      null::timestamptz,
      null::timestamptz,
      'La actividad necesita fecha y horario completos para abrir asistencia.'::text;
    return;
  end if;

  v_open_ts := v_start_ts - interval '15 minutes';
  v_close_ts := v_end_ts + interval '15 minutes';

  select t.expires_at
  into v_active_expires_at
  from public.activity_checkin_tokens t
  where t.activity_id = target_activity_id
    and t.token_type = 'attendance'
    and t.is_active = true
    and (t.expires_at is null or t.expires_at > now())
    and v_current_ts >= v_open_ts
  order by t.opened_at desc
  limit 1;

  v_has_active_token := v_active_expires_at is not null;

  if v_has_active_token then
    return query select
      v_can_edit,
      false,
      true,
      true,
      true,
      'open'::text,
      v_open_ts at time zone 'America/Mexico_City',
      v_close_ts at time zone 'America/Mexico_City',
      v_active_expires_at,
      'La asistencia está abierta.'::text;
    return;
  end if;

  if v_current_ts < v_open_ts then
    return query select
      v_can_edit,
      false,
      true,
      false,
      false,
      'not_yet_available'::text,
      v_open_ts at time zone 'America/Mexico_City',
      v_close_ts at time zone 'America/Mexico_City',
      null::timestamptz,
      'La asistencia podrá abrirse 15 minutos antes del inicio de la actividad.'::text;
    return;
  end if;

  if v_current_ts <= v_close_ts then
    return query select
      v_can_edit,
      false,
      true,
      false,
      true,
      'available'::text,
      v_open_ts at time zone 'America/Mexico_City',
      v_close_ts at time zone 'America/Mexico_City',
      null::timestamptz,
      'Puedes abrir asistencia para esta actividad.'::text;
    return;
  end if;

  return query select
    v_can_edit,
    false,
    true,
    false,
    true,
    'reopen_available'::text,
    v_open_ts at time zone 'America/Mexico_City',
    v_close_ts at time zone 'America/Mexico_City',
    null::timestamptz,
    'La actividad ya terminó. Puedes reabrir asistencia por 15 minutos.'::text;
end;
$$;


--
-- Name: get_activity_participants(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_activity_participants(target_activity_id uuid) RETURNS TABLE(id uuid, activity_id uuid, profile_id uuid, participant_role_code text, participant_role_label text, full_name text, email text, person_type text, institutional_id_type text, institutional_id_value text, program_name text, attendance_status text, attendance_source text, checked_in_at timestamp with time zone, attendance_updated_at timestamp with time zone, attendance_notes text, created_at timestamp with time zone)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para consultar la lista de participantes de esta actividad.'
      using errcode = '42501';
  end if;

  return query
  select
    ap.id,
    ap.activity_id,
    ap.profile_id,
    ap.participant_role_code,
    pr.label as participant_role_label,
    p.full_name,
    p.email,
    p.person_type,
    p.institutional_id_type,
    p.institutional_id_value,
    prog.name as program_name,
    ap.attendance_status,
    ap.attendance_source,
    ap.checked_in_at,
    ap.attendance_updated_at,
    ap.attendance_notes,
    ap.created_at
  from public.activity_participants ap
  join public.profiles p on p.id = ap.profile_id
  left join public.participant_roles pr on pr.code = ap.participant_role_code
  left join public.academic_programs prog on prog.id = p.primary_program_id
  where ap.activity_id = target_activity_id
  order by p.full_name;
end;
$$;


--
-- Name: get_visible_activity_cards(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_visible_activity_cards() RETURNS TABLE(id uuid, title text, description text, activity_type_label text, service_type_label text, service_type_code text, modality_label text, status_label text, status_code text, semester_label text, program_label text, location_type_label text, location_detail text, start_date date, start_time time without time zone, end_date date, end_time time without time zone, duration_mode text, responsible_full_name text, viewer_can_edit boolean, viewer_is_participant boolean, viewer_attendance_status text, viewer_attendance_source text, viewer_checked_in_at timestamp with time zone)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select
    a.id,
    a.title,
    a.description,
    at.label as activity_type_label,
    st.label as service_type_label,
    a.service_type_code,
    am.label as modality_label,
    ast.label as status_label,
    a.status_code,
    sem.name as semester_label,
    case
      when a.scope_type = 'division' then 'Ambos programas'
      else ap.name
    end as program_label,
    lt.label as location_type_label,
    a.location_detail,
    a.start_date,
    a.start_time,
    a.end_date,
    a.end_time,
    a.duration_mode,
    coalesce(rp.full_name, 'Responsable sin nombre') as responsible_full_name,
    public.can_edit_activity(a.id) as viewer_can_edit,
    public.is_activity_participant(a.id) as viewer_is_participant,
    viewer_participation.attendance_status as viewer_attendance_status,
    viewer_participation.attendance_source as viewer_attendance_source,
    viewer_participation.checked_in_at as viewer_checked_in_at
  from public.activities a
  left join public.activity_types at on at.code = a.activity_type_code
  left join public.service_types st on st.code = a.service_type_code
  left join public.activity_modalities am on am.code = a.modality_code
  left join public.activity_statuses ast on ast.code = a.status_code
  left join public.academic_periods sem on sem.id = a.academic_period_id
  left join public.academic_programs ap on ap.id = a.program_id
  left join public.location_types lt on lt.code = a.location_type_code
  left join public.profiles rp on rp.id = a.responsible_profile_id
  left join public.activity_participants viewer_participation
    on viewer_participation.activity_id = a.id
   and viewer_participation.profile_id = auth.uid()
  where
    (
      a.status_code = 'draft'
      and a.created_by = auth.uid()
    )
    or
    (
      a.status_code <> 'draft'
      and (
        a.created_by = auth.uid()
        or a.responsible_profile_id = auth.uid()
        or public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)
        or public.is_activity_participant(a.id)
      )
    )
  order by a.start_date desc nulls last, a.start_time desc nulls last, a.created_at desc;
$$;


--
-- Name: has_active_role(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.has_active_role(required_role text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.role_assignments ra
    where ra.user_id = auth.uid()
      and ra.role_code = required_role
      and ra.is_active = true
      and ra.starts_at <= current_date
      and (ra.ends_at is null or ra.ends_at >= current_date)
  );
$$;


--
-- Name: has_any_active_role(text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.has_any_active_role(required_roles text[]) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.role_assignments ra
    where ra.user_id = auth.uid()
      and ra.role_code = any(required_roles)
      and ra.is_active = true
      and ra.starts_at <= current_date
      and (ra.ends_at is null or ra.ends_at >= current_date)
  );
$$;


--
-- Name: is_activity_participant(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_activity_participant(target_activity_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.activity_participants ap
    where ap.activity_id = target_activity_id
      and ap.profile_id = auth.uid()
  );
$$;


--
-- Name: open_activity_attendance_checkin(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.open_activity_attendance_checkin(target_activity_id uuid) RETURNS TABLE(id uuid, activity_id uuid, code_words text, secret_token text, opened_at timestamp with time zone, expires_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  new_code text;
  new_id uuid;
  open_at timestamptz;
  natural_deadline timestamptz;
  effective_deadline timestamptz;
begin
  perform public.finalize_expired_attendance();

  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para abrir asistencia en esta actividad.'
      using errcode = '42501';
  end if;

  if exists (
    select 1
    from public.activities a
    where a.id = target_activity_id
      and a.status_code = 'draft'
  ) then
    raise exception 'No puedes abrir asistencia en una actividad en borrador.'
      using errcode = 'P0001';
  end if;

  open_at := public.activity_attendance_open_at(target_activity_id);
  natural_deadline := public.activity_attendance_deadline(target_activity_id);

  if open_at is null or natural_deadline is null then
    raise exception 'La actividad no tiene horario suficiente para abrir asistencia.'
      using errcode = 'P0001';
  end if;

  if now() < open_at then
    raise exception 'La asistencia aún no puede abrirse para esta actividad.'
      using errcode = 'P0001';
  end if;

  effective_deadline := case
    when natural_deadline <= now() then now() + interval '15 minutes'
    else natural_deadline
  end;

  update public.activity_checkin_tokens t
  set
    is_active = false,
    closed_at = now()
  where t.activity_id = target_activity_id
    and t.token_type = 'attendance'
    and t.is_active = true;

  new_code := public.generate_three_word_code();

  insert into public.activity_checkin_tokens (
    activity_id,
    token_type,
    code_words,
    is_active,
    expires_at,
    created_by
  )
  values (
    target_activity_id,
    'attendance',
    new_code,
    true,
    effective_deadline,
    auth.uid()
  )
  returning public.activity_checkin_tokens.id into new_id;

  return query
  select
    t.id,
    t.activity_id,
    t.code_words,
    t.secret_token,
    t.opened_at,
    t.expires_at
  from public.activity_checkin_tokens t
  where t.id = new_id;
end;
$$;


--
-- Name: remove_activity_participant(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.remove_activity_participant(target_participant_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  target_activity_id uuid;
begin
  select ap.activity_id
  into target_activity_id
  from public.activity_participants ap
  where ap.id = target_participant_id;

  if target_activity_id is null then
    raise exception 'El participante no existe.'
      using errcode = 'P0001';
  end if;

  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para quitar participantes de esta actividad.'
      using errcode = '42501';
  end if;

  delete from public.activity_participants
  where id = target_participant_id;
end;
$$;


--
-- Name: search_profiles_for_participation(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_profiles_for_participation(target_activity_id uuid, search_text text) RETURNS TABLE(id uuid, full_name text, email text, person_type text, institutional_id_type text, institutional_id_value text, primary_program_id uuid, program_name text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  target_program_id uuid;
begin
  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para buscar participantes para esta actividad.'
      using errcode = '42501';
  end if;

  select a.program_id
  into target_program_id
  from public.activities a
  where a.id = target_activity_id;

  if target_program_id is null then
    raise exception 'La actividad no tiene programa académico asignado.'
      using errcode = 'P0001';
  end if;

  return query
  select
    p.id,
    p.full_name,
    p.email,
    p.person_type,
    p.institutional_id_type,
    p.institutional_id_value,
    p.primary_program_id,
    ap.name as program_name
  from public.profiles p
  left join public.academic_programs ap on ap.id = p.primary_program_id
  where
    p.is_active = true
    and p.primary_program_id = target_program_id
    and length(trim(search_text)) >= 2
    and (
      extensions.unaccent(lower(coalesce(p.full_name, '')))
        like '%' || extensions.unaccent(lower(trim(search_text))) || '%'
      or extensions.unaccent(lower(coalesce(p.email, '')))
        like '%' || extensions.unaccent(lower(trim(search_text))) || '%'
      or extensions.unaccent(lower(coalesce(p.institutional_id_value, '')))
        like '%' || extensions.unaccent(lower(trim(search_text))) || '%'
    )
  order by p.full_name
  limit 20;
end;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


--
-- Name: update_activity_participant_attendance(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_activity_participant_attendance(target_participant_id uuid, new_attendance_status text, new_attendance_notes text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  target_activity_id uuid;
begin
  if new_attendance_status not in ('pending', 'attended', 'absent', 'justified') then
    raise exception 'El estado de asistencia no es válido.'
      using errcode = 'P0001';
  end if;

  select ap.activity_id
  into target_activity_id
  from public.activity_participants ap
  where ap.id = target_participant_id;

  if target_activity_id is null then
    raise exception 'El participante no existe.'
      using errcode = 'P0001';
  end if;

  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para modificar la asistencia de esta actividad.'
      using errcode = '42501';
  end if;

  update public.activity_participants
  set
    attendance_status = new_attendance_status,
    attendance_source = 'manual',
    attendance_updated_by = auth.uid(),
    attendance_updated_at = now(),
    attendance_notes = nullif(trim(coalesce(new_attendance_notes, '')), ''),
    checked_in_at = case
      when new_attendance_status = 'attended' then checked_in_at
      else null
    end,
    updated_at = now()
  where id = target_participant_id;
end;
$$;


--
-- Name: update_activity_participants_attendance_bulk(uuid, uuid[], text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_activity_participants_attendance_bulk(target_activity_id uuid, target_participant_ids uuid[], new_attendance_status text, new_attendance_notes text DEFAULT NULL::text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  updated_count integer;
begin
  if new_attendance_status not in ('pending', 'attended', 'absent', 'justified') then
    raise exception 'El estado de asistencia no es válido.'
      using errcode = 'P0001';
  end if;

  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para modificar la asistencia de esta actividad.'
      using errcode = '42501';
  end if;

  if target_participant_ids is null or array_length(target_participant_ids, 1) is null then
    raise exception 'No se seleccionaron participantes.'
      using errcode = 'P0001';
  end if;

  update public.activity_participants ap
  set
    attendance_status = new_attendance_status,
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


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: academic_periods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.academic_periods (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    starts_on date,
    ends_on date,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: academic_programs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.academic_programs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    division_id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    description text,
    academic_period_id uuid,
    program_id uuid,
    activity_type_code text,
    service_type_code text,
    attention_category_code text,
    modality_code text,
    status_code text DEFAULT 'draft'::text NOT NULL,
    location_type_code text,
    location_detail text,
    starts_at timestamp with time zone,
    ends_at timestamp with time zone,
    responsible_profile_id uuid NOT NULL,
    created_by uuid DEFAULT auth.uid() NOT NULL,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    start_date date,
    start_time time without time zone,
    end_date date,
    end_time time without time zone,
    duration_mode text,
    scope_type text DEFAULT 'program'::text,
    division_id uuid,
    CONSTRAINT activities_duration_mode_check CHECK (((duration_mode IS NULL) OR (duration_mode = ANY (ARRAY['one_hour'::text, 'two_hours'::text, 'custom'::text])))),
    CONSTRAINT activities_scope_consistency_check CHECK ((((scope_type = 'program'::text) AND (program_id IS NOT NULL) AND (division_id IS NOT NULL)) OR ((scope_type = 'division'::text) AND (division_id IS NOT NULL) AND (program_id IS NULL)))),
    CONSTRAINT activities_scope_type_check CHECK ((scope_type = ANY (ARRAY['program'::text, 'division'::text]))),
    CONSTRAINT activities_time_order_check CHECK (((starts_at IS NULL) OR (ends_at IS NULL) OR (ends_at > starts_at)))
);


--
-- Name: activity_checkin_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_checkin_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    activity_id uuid NOT NULL,
    token_type text DEFAULT 'attendance'::text NOT NULL,
    code_words text NOT NULL,
    secret_token text DEFAULT (gen_random_uuid())::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    opened_at timestamp with time zone DEFAULT now() NOT NULL,
    closed_at timestamp with time zone,
    expires_at timestamp with time zone,
    created_by uuid DEFAULT auth.uid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT activity_checkin_tokens_type_check CHECK ((token_type = ANY (ARRAY['attendance'::text, 'registration'::text])))
);


--
-- Name: activity_modalities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_modalities (
    code text NOT NULL,
    label text NOT NULL,
    description text,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: activity_participants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_participants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    activity_id uuid NOT NULL,
    profile_id uuid NOT NULL,
    participant_role_code text NOT NULL,
    added_by uuid DEFAULT auth.uid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    attendance_status text DEFAULT 'pending'::text NOT NULL,
    attendance_source text DEFAULT 'system'::text NOT NULL,
    checked_in_at timestamp with time zone,
    attendance_updated_by uuid,
    attendance_updated_at timestamp with time zone,
    attendance_notes text,
    CONSTRAINT activity_participants_attendance_source_check CHECK ((attendance_source = ANY (ARRAY['system'::text, 'manual'::text, 'qr'::text, 'code'::text]))),
    CONSTRAINT activity_participants_attendance_status_check CHECK ((attendance_status = ANY (ARRAY['pending'::text, 'attended'::text, 'absent'::text, 'justified'::text])))
);


--
-- Name: activity_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_statuses (
    code text NOT NULL,
    label text NOT NULL,
    description text,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: activity_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_types (
    code text NOT NULL,
    label text NOT NULL,
    description text,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: attention_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attention_categories (
    code text NOT NULL,
    label text NOT NULL,
    description text,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: divisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.divisions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: location_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.location_types (
    code text NOT NULL,
    label text NOT NULL,
    description text,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: participant_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.participant_roles (
    code text NOT NULL,
    label text NOT NULL,
    description text,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    email text NOT NULL,
    full_name text,
    primary_program_id uuid,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    first_names text,
    paternal_surname text,
    maternal_surname text,
    person_type text,
    institutional_id_type text,
    institutional_id_value text,
    CONSTRAINT profiles_institutional_id_type_check CHECK (((institutional_id_type IS NULL) OR (institutional_id_type = ANY (ARRAY['student_account'::text, 'worker_number'::text])))),
    CONSTRAINT profiles_person_identifier_consistency_check CHECK (((person_type IS NULL) OR (institutional_id_type IS NULL) OR ((person_type = 'student'::text) AND (institutional_id_type = 'student_account'::text)) OR ((person_type = 'worker'::text) AND (institutional_id_type = 'worker_number'::text)))),
    CONSTRAINT profiles_person_type_check CHECK (((person_type IS NULL) OR (person_type = ANY (ARRAY['student'::text, 'worker'::text]))))
);


--
-- Name: role_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    role_code text NOT NULL,
    scope_type text NOT NULL,
    service_area text NOT NULL,
    division_id uuid,
    program_id uuid,
    starts_at date DEFAULT CURRENT_DATE NOT NULL,
    ends_at date,
    is_active boolean DEFAULT true NOT NULL,
    assigned_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT role_assignments_scope_type_check CHECK ((scope_type = ANY (ARRAY['own'::text, 'program'::text, 'division'::text, 'system'::text]))),
    CONSTRAINT role_assignments_service_area_check CHECK ((service_area = ANY (ARRAY['tutoring'::text, 'advising'::text, 'both'::text, 'logistics'::text, 'technical'::text]))),
    CONSTRAINT valid_role_assignment_scope CHECK ((((scope_type = 'own'::text) AND (division_id IS NULL) AND (program_id IS NULL)) OR ((scope_type = 'program'::text) AND (program_id IS NOT NULL)) OR ((scope_type = 'division'::text) AND (division_id IS NOT NULL)) OR ((scope_type = 'system'::text) AND (division_id IS NULL) AND (program_id IS NULL))))
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    code text NOT NULL,
    label text NOT NULL,
    description text,
    sort_order integer DEFAULT 0 NOT NULL
);


--
-- Name: service_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service_types (
    code text NOT NULL,
    label text NOT NULL,
    description text,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: system_health; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_health (
    id bigint NOT NULL,
    status text DEFAULT 'ok'::text NOT NULL,
    message text DEFAULT 'Supabase conectado'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: system_health_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.system_health ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.system_health_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: academic_periods academic_periods_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_periods
    ADD CONSTRAINT academic_periods_code_key UNIQUE (code);


--
-- Name: academic_periods academic_periods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_periods
    ADD CONSTRAINT academic_periods_pkey PRIMARY KEY (id);


--
-- Name: academic_programs academic_programs_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_programs
    ADD CONSTRAINT academic_programs_code_key UNIQUE (code);


--
-- Name: academic_programs academic_programs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_programs
    ADD CONSTRAINT academic_programs_pkey PRIMARY KEY (id);


--
-- Name: activities activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_pkey PRIMARY KEY (id);


--
-- Name: activity_checkin_tokens activity_checkin_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_checkin_tokens
    ADD CONSTRAINT activity_checkin_tokens_pkey PRIMARY KEY (id);


--
-- Name: activity_modalities activity_modalities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_modalities
    ADD CONSTRAINT activity_modalities_pkey PRIMARY KEY (code);


--
-- Name: activity_participants activity_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_participants
    ADD CONSTRAINT activity_participants_pkey PRIMARY KEY (id);


--
-- Name: activity_participants activity_participants_unique_profile_per_activity; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_participants
    ADD CONSTRAINT activity_participants_unique_profile_per_activity UNIQUE (activity_id, profile_id);


--
-- Name: activity_statuses activity_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_statuses
    ADD CONSTRAINT activity_statuses_pkey PRIMARY KEY (code);


--
-- Name: activity_types activity_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_types
    ADD CONSTRAINT activity_types_pkey PRIMARY KEY (code);


--
-- Name: attention_categories attention_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attention_categories
    ADD CONSTRAINT attention_categories_pkey PRIMARY KEY (code);


--
-- Name: divisions divisions_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.divisions
    ADD CONSTRAINT divisions_code_key UNIQUE (code);


--
-- Name: divisions divisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.divisions
    ADD CONSTRAINT divisions_pkey PRIMARY KEY (id);


--
-- Name: location_types location_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.location_types
    ADD CONSTRAINT location_types_pkey PRIMARY KEY (code);


--
-- Name: participant_roles participant_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participant_roles
    ADD CONSTRAINT participant_roles_pkey PRIMARY KEY (code);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: role_assignments role_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (code);


--
-- Name: service_types service_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_types
    ADD CONSTRAINT service_types_pkey PRIMARY KEY (code);


--
-- Name: system_health system_health_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_health
    ADD CONSTRAINT system_health_pkey PRIMARY KEY (id);


--
-- Name: activities_created_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_created_by_idx ON public.activities USING btree (created_by);


--
-- Name: activities_division_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_division_id_idx ON public.activities USING btree (division_id);


--
-- Name: activities_program_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_program_id_idx ON public.activities USING btree (program_id);


--
-- Name: activities_responsible_profile_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_responsible_profile_id_idx ON public.activities USING btree (responsible_profile_id);


--
-- Name: activities_scope_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_scope_type_idx ON public.activities USING btree (scope_type);


--
-- Name: activities_service_type_code_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_service_type_code_idx ON public.activities USING btree (service_type_code);


--
-- Name: activities_starts_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_starts_at_idx ON public.activities USING btree (starts_at);


--
-- Name: activities_status_code_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_status_code_idx ON public.activities USING btree (status_code);


--
-- Name: activity_checkin_tokens_active_code_words_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX activity_checkin_tokens_active_code_words_idx ON public.activity_checkin_tokens USING btree (code_words) WHERE (is_active = true);


--
-- Name: activity_checkin_tokens_activity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_checkin_tokens_activity_id_idx ON public.activity_checkin_tokens USING btree (activity_id);


--
-- Name: activity_checkin_tokens_one_active_attendance_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX activity_checkin_tokens_one_active_attendance_idx ON public.activity_checkin_tokens USING btree (activity_id, token_type) WHERE ((is_active = true) AND (token_type = 'attendance'::text));


--
-- Name: activity_checkin_tokens_secret_token_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX activity_checkin_tokens_secret_token_idx ON public.activity_checkin_tokens USING btree (secret_token);


--
-- Name: activity_participants_activity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_participants_activity_id_idx ON public.activity_participants USING btree (activity_id);


--
-- Name: activity_participants_attendance_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_participants_attendance_status_idx ON public.activity_participants USING btree (attendance_status);


--
-- Name: activity_participants_profile_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_participants_profile_id_idx ON public.activity_participants USING btree (profile_id);


--
-- Name: activity_participants_role_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_participants_role_idx ON public.activity_participants USING btree (participant_role_code);


--
-- Name: activities set_activities_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_activities_updated_at BEFORE UPDATE ON public.activities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: activity_participants set_activity_participants_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_activity_participants_updated_at BEFORE UPDATE ON public.activity_participants FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: profiles set_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: role_assignments set_role_assignments_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_role_assignments_updated_at BEFORE UPDATE ON public.role_assignments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: academic_programs academic_programs_division_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_programs
    ADD CONSTRAINT academic_programs_division_id_fkey FOREIGN KEY (division_id) REFERENCES public.divisions(id) ON DELETE CASCADE;


--
-- Name: activities activities_academic_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_academic_period_id_fkey FOREIGN KEY (academic_period_id) REFERENCES public.academic_periods(id);


--
-- Name: activities activities_activity_type_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_activity_type_code_fkey FOREIGN KEY (activity_type_code) REFERENCES public.activity_types(code);


--
-- Name: activities activities_attention_category_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_attention_category_code_fkey FOREIGN KEY (attention_category_code) REFERENCES public.attention_categories(code);


--
-- Name: activities activities_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: activities activities_division_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_division_id_fkey FOREIGN KEY (division_id) REFERENCES public.divisions(id);


--
-- Name: activities activities_location_type_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_location_type_code_fkey FOREIGN KEY (location_type_code) REFERENCES public.location_types(code);


--
-- Name: activities activities_modality_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_modality_code_fkey FOREIGN KEY (modality_code) REFERENCES public.activity_modalities(code);


--
-- Name: activities activities_program_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_program_id_fkey FOREIGN KEY (program_id) REFERENCES public.academic_programs(id);


--
-- Name: activities activities_responsible_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_responsible_profile_id_fkey FOREIGN KEY (responsible_profile_id) REFERENCES public.profiles(id);


--
-- Name: activities activities_service_type_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_service_type_code_fkey FOREIGN KEY (service_type_code) REFERENCES public.service_types(code);


--
-- Name: activities activities_status_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_status_code_fkey FOREIGN KEY (status_code) REFERENCES public.activity_statuses(code);


--
-- Name: activities activities_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id);


--
-- Name: activity_checkin_tokens activity_checkin_tokens_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_checkin_tokens
    ADD CONSTRAINT activity_checkin_tokens_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES public.activities(id) ON DELETE CASCADE;


--
-- Name: activity_checkin_tokens activity_checkin_tokens_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_checkin_tokens
    ADD CONSTRAINT activity_checkin_tokens_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: activity_participants activity_participants_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_participants
    ADD CONSTRAINT activity_participants_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES public.activities(id) ON DELETE CASCADE;


--
-- Name: activity_participants activity_participants_added_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_participants
    ADD CONSTRAINT activity_participants_added_by_fkey FOREIGN KEY (added_by) REFERENCES auth.users(id);


--
-- Name: activity_participants activity_participants_attendance_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_participants
    ADD CONSTRAINT activity_participants_attendance_updated_by_fkey FOREIGN KEY (attendance_updated_by) REFERENCES auth.users(id);


--
-- Name: activity_participants activity_participants_participant_role_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_participants
    ADD CONSTRAINT activity_participants_participant_role_code_fkey FOREIGN KEY (participant_role_code) REFERENCES public.participant_roles(code);


--
-- Name: activity_participants activity_participants_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_participants
    ADD CONSTRAINT activity_participants_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_primary_program_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_primary_program_id_fkey FOREIGN KEY (primary_program_id) REFERENCES public.academic_programs(id);


--
-- Name: role_assignments role_assignments_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES auth.users(id);


--
-- Name: role_assignments role_assignments_division_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_division_id_fkey FOREIGN KEY (division_id) REFERENCES public.divisions(id) ON DELETE CASCADE;


--
-- Name: role_assignments role_assignments_program_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_program_id_fkey FOREIGN KEY (program_id) REFERENCES public.academic_programs(id) ON DELETE CASCADE;


--
-- Name: role_assignments role_assignments_role_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_role_code_fkey FOREIGN KEY (role_code) REFERENCES public.roles(code);


--
-- Name: role_assignments role_assignments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: system_health Allow public read for system health; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow public read for system health" ON public.system_health FOR SELECT TO anon USING (true);


--
-- Name: academic_periods Authenticated users can read academic periods; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can read academic periods" ON public.academic_periods FOR SELECT TO authenticated USING (true);


--
-- Name: academic_programs Authenticated users can read academic programs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can read academic programs" ON public.academic_programs FOR SELECT TO authenticated USING (true);


--
-- Name: activity_modalities Authenticated users can read activity modalities; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can read activity modalities" ON public.activity_modalities FOR SELECT TO authenticated USING (true);


--
-- Name: activity_statuses Authenticated users can read activity statuses; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can read activity statuses" ON public.activity_statuses FOR SELECT TO authenticated USING (true);


--
-- Name: activity_types Authenticated users can read activity types; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can read activity types" ON public.activity_types FOR SELECT TO authenticated USING (true);


--
-- Name: attention_categories Authenticated users can read attention categories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can read attention categories" ON public.attention_categories FOR SELECT TO authenticated USING (true);


--
-- Name: divisions Authenticated users can read divisions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can read divisions" ON public.divisions FOR SELECT TO authenticated USING (true);


--
-- Name: location_types Authenticated users can read location types; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can read location types" ON public.location_types FOR SELECT TO authenticated USING (true);


--
-- Name: participant_roles Authenticated users can read participant roles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can read participant roles" ON public.participant_roles FOR SELECT TO authenticated USING (true);


--
-- Name: roles Authenticated users can read roles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can read roles" ON public.roles FOR SELECT TO authenticated USING (true);


--
-- Name: service_types Authenticated users can read service types; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can read service types" ON public.service_types FOR SELECT TO authenticated USING (true);


--
-- Name: activities Authorized users can create activities; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authorized users can create activities" ON public.activities FOR INSERT TO authenticated WITH CHECK (((created_by = auth.uid()) AND public.can_create_activity(scope_type, program_id, division_id, service_type_code)));


--
-- Name: activities Authorized users can delete activities; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authorized users can delete activities" ON public.activities FOR DELETE TO authenticated USING (public.can_delete_activity(id));


--
-- Name: activities Authorized users can update activities; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authorized users can update activities" ON public.activities FOR UPDATE TO authenticated USING (public.can_update_activity_base(id)) WITH CHECK (public.can_update_activity_base(id));


--
-- Name: activity_participants Users can add permitted activity participants; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can add permitted activity participants" ON public.activity_participants FOR INSERT TO authenticated WITH CHECK (public.can_edit_activity(activity_id));


--
-- Name: activity_participants Users can delete permitted activity participants; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete permitted activity participants" ON public.activity_participants FOR DELETE TO authenticated USING (public.can_edit_activity(activity_id));


--
-- Name: profiles Users can read own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can read own profile" ON public.profiles FOR SELECT TO authenticated USING ((auth.uid() = id));


--
-- Name: role_assignments Users can read own role assignments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can read own role assignments" ON public.role_assignments FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: activities Users can read permitted activities; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can read permitted activities" ON public.activities FOR SELECT TO authenticated USING (((created_by = auth.uid()) OR (responsible_profile_id = auth.uid()) OR public.is_activity_participant(id) OR public.can_manage_activity(scope_type, program_id, division_id, service_type_code)));


--
-- Name: activity_participants Users can read permitted activity participants; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can read permitted activity participants" ON public.activity_participants FOR SELECT TO authenticated USING (((profile_id = auth.uid()) OR public.can_read_activity(activity_id)));


--
-- Name: profiles Users can update own basic profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own basic profile" ON public.profiles FOR UPDATE TO authenticated USING ((auth.uid() = id)) WITH CHECK ((auth.uid() = id));


--
-- Name: activity_participants Users can update permitted activity participants; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update permitted activity participants" ON public.activity_participants FOR UPDATE TO authenticated USING (public.can_edit_activity(activity_id)) WITH CHECK (public.can_edit_activity(activity_id));


--
-- Name: academic_periods; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.academic_periods ENABLE ROW LEVEL SECURITY;

--
-- Name: academic_programs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.academic_programs ENABLE ROW LEVEL SECURITY;

--
-- Name: activities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;

--
-- Name: activity_checkin_tokens; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.activity_checkin_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: activity_modalities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.activity_modalities ENABLE ROW LEVEL SECURITY;

--
-- Name: activity_participants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.activity_participants ENABLE ROW LEVEL SECURITY;

--
-- Name: activity_statuses; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.activity_statuses ENABLE ROW LEVEL SECURITY;

--
-- Name: activity_types; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.activity_types ENABLE ROW LEVEL SECURITY;

--
-- Name: attention_categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.attention_categories ENABLE ROW LEVEL SECURITY;

--
-- Name: divisions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.divisions ENABLE ROW LEVEL SECURITY;

--
-- Name: location_types; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.location_types ENABLE ROW LEVEL SECURITY;

--
-- Name: participant_roles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.participant_roles ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: role_assignments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.role_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: roles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

--
-- Name: service_types; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.service_types ENABLE ROW LEVEL SECURITY;

--
-- Name: system_health; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.system_health ENABLE ROW LEVEL SECURITY;

-- Fin del esquema capturado por pg_dump.

-- ============================================================================
-- Semillas reproducibles de catálogos controlados
-- ============================================================================
-- Se excluyen usuarios, perfiles, asignaciones de rol, actividades,
-- participantes, asistencias, tokens y cualquier dato operativo o personal.

-- Catálogo: public.divisions (1 filas)
INSERT INTO public.divisions
SELECT seed.*
FROM jsonb_populate_recordset(
  NULL::public.divisions,
  $sitaa_seed$[
  {
    "id": "287c9d07-afff-4654-8a71-f0524cac3bd9",
    "code": "design_building_division",
    "name": "División de Diseño y Edificación",
    "created_at": "2026-07-07T20:38:52.1818+00:00"
  }
]$sitaa_seed$::jsonb
) AS seed
ON CONFLICT DO NOTHING;

-- Catálogo: public.academic_programs (2 filas)
INSERT INTO public.academic_programs
SELECT seed.*
FROM jsonb_populate_recordset(
  NULL::public.academic_programs,
  $sitaa_seed$[
  {
    "id": "44ed314d-f73e-46b6-bd24-c33b8080096a",
    "code": "graphic_design",
    "name": "Diseño Gráfico",
    "created_at": "2026-07-07T20:38:52.1818+00:00",
    "division_id": "287c9d07-afff-4654-8a71-f0524cac3bd9"
  },
  {
    "id": "5754ca45-3b33-4244-a343-a7cfcf73dac2",
    "code": "architecture",
    "name": "Arquitectura",
    "created_at": "2026-07-07T20:38:52.1818+00:00",
    "division_id": "287c9d07-afff-4654-8a71-f0524cac3bd9"
  }
]$sitaa_seed$::jsonb
) AS seed
ON CONFLICT DO NOTHING;

-- Catálogo: public.roles (10 filas)
INSERT INTO public.roles
SELECT seed.*
FROM jsonb_populate_recordset(
  NULL::public.roles,
  $sitaa_seed$[
  {
    "code": "division_head",
    "label": "Jefatura de división",
    "sort_order": 80,
    "description": "Autoridad divisional con acceso a indicadores agregados."
  },
  {
    "code": "division_tutoring_liaison",
    "label": "Enlace divisional de tutorías y asesorías",
    "sort_order": 60,
    "description": "Responsable divisional de seguimiento y reporte de tutorías y asesorías."
  },
  {
    "code": "peer_tutor",
    "label": "Alumno tutor par",
    "sort_order": 20,
    "description": "Estudiante que participa como tutor par durante un periodo determinado."
  },
  {
    "code": "professor",
    "label": "Profesor tutor / asesor",
    "sort_order": 30,
    "description": "Profesor que planea, registra y da seguimiento a tutorías o asesorías."
  },
  {
    "code": "program_advising_lead",
    "label": "Encargado de asesorías de carrera",
    "sort_order": 50,
    "description": "Profesor responsable de asesorías en una carrera específica."
  },
  {
    "code": "program_head",
    "label": "Jefatura de carrera / programa",
    "sort_order": 70,
    "description": "Autoridad académica de una carrera o programa."
  },
  {
    "code": "program_tutoring_lead",
    "label": "Encargado de tutorías de carrera",
    "sort_order": 40,
    "description": "Profesor responsable de tutorías en una carrera específica."
  },
  {
    "code": "student",
    "label": "Alumno",
    "sort_order": 10,
    "description": "Estudiante que participa en tutorías o asesorías."
  },
  {
    "code": "technical_admin",
    "label": "Administrador técnico",
    "sort_order": 100,
    "description": "Responsable técnico de configuración y mantenimiento del sistema."
  },
  {
    "code": "technical_secretary",
    "label": "Secretario técnico",
    "sort_order": 90,
    "description": "Rol de apoyo logístico con acceso limitado a información operativa."
  }
]$sitaa_seed$::jsonb
) AS seed
ON CONFLICT DO NOTHING;

-- Catálogo: public.academic_periods (5 filas)
INSERT INTO public.academic_periods
SELECT seed.*
FROM jsonb_populate_recordset(
  NULL::public.academic_periods,
  $sitaa_seed$[
  {
    "id": "76166e7f-228c-43dc-9fda-75614f087937",
    "code": "2026-2",
    "name": "2026-2",
    "ends_on": "2026-05-29",
    "is_active": true,
    "starts_on": "2026-02-03",
    "created_at": "2026-07-08T22:04:07.767746+00:00",
    "sort_order": 202602,
    "updated_at": "2026-07-08T22:04:07.767746+00:00"
  },
  {
    "id": "83bb9305-c900-40f8-9441-aeaff677a6b4",
    "code": "2027-1",
    "name": "2027-1",
    "ends_on": "2026-11-27",
    "is_active": true,
    "starts_on": "2026-08-10",
    "created_at": "2026-07-08T22:04:07.767746+00:00",
    "sort_order": 202701,
    "updated_at": "2026-07-08T22:04:07.767746+00:00"
  },
  {
    "id": "bb31c5c9-b7b5-4535-ae22-7765c8cb4a9c",
    "code": "2026-1",
    "name": "2026-1",
    "ends_on": "2025-11-28",
    "is_active": true,
    "starts_on": "2025-08-11",
    "created_at": "2026-07-08T22:04:07.767746+00:00",
    "sort_order": 202601,
    "updated_at": "2026-07-08T22:04:07.767746+00:00"
  },
  {
    "id": "cc138018-3f35-4063-b818-976fb83cd69f",
    "code": "pilot",
    "name": "Periodo piloto",
    "ends_on": null,
    "is_active": false,
    "starts_on": null,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 0,
    "updated_at": "2026-07-08T22:04:07.767746+00:00"
  },
  {
    "id": "e11b1341-7535-4ae2-8b82-031234e6aec2",
    "code": "2027-2",
    "name": "2027-2",
    "ends_on": "2027-05-28",
    "is_active": true,
    "starts_on": "2027-02-02",
    "created_at": "2026-07-08T22:04:07.767746+00:00",
    "sort_order": 202702,
    "updated_at": "2026-07-08T22:04:07.767746+00:00"
  }
]$sitaa_seed$::jsonb
) AS seed
ON CONFLICT DO NOTHING;

-- Catálogo: public.activity_types (5 filas)
INSERT INTO public.activity_types
SELECT seed.*
FROM jsonb_populate_recordset(
  NULL::public.activity_types,
  $sitaa_seed$[
  {
    "code": "group_activity",
    "label": "Actividad grupal",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 20,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Actividad de acompañamiento con varios participantes."
  },
  {
    "code": "individual_activity",
    "label": "Actividad individual",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 10,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Actividad de acompañamiento con un participante principal."
  },
  {
    "code": "orientation_event",
    "label": "Evento de orientación",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 50,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Actividad informativa o de orientación académica o profesional."
  },
  {
    "code": "peer_tutoring",
    "label": "Tutoría par",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 30,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Actividad realizada por un alumno tutor par."
  },
  {
    "code": "remedial_activity",
    "label": "Actividad remedial",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 40,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Actividad orientada a reforzar o recuperar contenidos o procesos académicos."
  }
]$sitaa_seed$::jsonb
) AS seed
ON CONFLICT DO NOTHING;

-- Catálogo: public.service_types (2 filas)
INSERT INTO public.service_types
SELECT seed.*
FROM jsonb_populate_recordset(
  NULL::public.service_types,
  $sitaa_seed$[
  {
    "code": "advising",
    "label": "Asesoría",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 20,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Atención disciplinar, profesional o de orientación específica."
  },
  {
    "code": "tutoring",
    "label": "Tutoría",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 10,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Acompañamiento académico, formativo o de seguimiento."
  }
]$sitaa_seed$::jsonb
) AS seed
ON CONFLICT DO NOTHING;

-- Catálogo: public.attention_categories (5 filas)
INSERT INTO public.attention_categories
SELECT seed.*
FROM jsonb_populate_recordset(
  NULL::public.attention_categories,
  $sitaa_seed$[
  {
    "code": "academic_administrative",
    "label": "Académico-administrativa",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 40,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Atención relacionada con trámites, trayectorias escolares, inscripción, seriación u organización académica."
  },
  {
    "code": "disciplinary",
    "label": "Disciplinar",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 10,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Atención relacionada con contenidos, proyectos, ejercicios o problemas propios de una asignatura o disciplina."
  },
  {
    "code": "other",
    "label": "Otra",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 90,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Categoría no contemplada en las opciones principales."
  },
  {
    "code": "professional",
    "label": "Profesional",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 30,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Atención relacionada con titulación, servicios profesionales, inserción laboral, portafolio o trayectoria profesional."
  },
  {
    "code": "socioemotional",
    "label": "Socioemocional",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 20,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Atención relacionada con bienestar, adaptación, dificultades personales o necesidades de acompañamiento."
  }
]$sitaa_seed$::jsonb
) AS seed
ON CONFLICT DO NOTHING;

-- Catálogo: public.activity_modalities (3 filas)
INSERT INTO public.activity_modalities
SELECT seed.*
FROM jsonb_populate_recordset(
  NULL::public.activity_modalities,
  $sitaa_seed$[
  {
    "code": "hybrid",
    "label": "Híbrida",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 30,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Actividad con participantes presenciales y remotos."
  },
  {
    "code": "in_person",
    "label": "Presencial",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 10,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Actividad realizada físicamente."
  },
  {
    "code": "online",
    "label": "En línea",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 20,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Actividad realizada mediante plataforma digital."
  }
]$sitaa_seed$::jsonb
) AS seed
ON CONFLICT DO NOTHING;

-- Catálogo: public.activity_statuses (6 filas)
INSERT INTO public.activity_statuses
SELECT seed.*
FROM jsonb_populate_recordset(
  NULL::public.activity_statuses,
  $sitaa_seed$[
  {
    "code": "cancelled",
    "label": "Cancelada",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 60,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Actividad que no se realizó."
  },
  {
    "code": "completed",
    "label": "Finalizada",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 40,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Actividad realizada y cerrada por el responsable."
  },
  {
    "code": "draft",
    "label": "Borrador",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 10,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Registro iniciado pero no programado formalmente."
  },
  {
    "code": "open",
    "label": "Abierta",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 30,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Actividad activa; permite asistencia o registro."
  },
  {
    "code": "scheduled",
    "label": "Programada",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 20,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Actividad con fecha, horario y responsable definidos."
  },
  {
    "code": "validated",
    "label": "Validada",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 50,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Actividad revisada y válida para reportes."
  }
]$sitaa_seed$::jsonb
) AS seed
ON CONFLICT DO NOTHING;

-- Catálogo: public.location_types (7 filas)
INSERT INTO public.location_types
SELECT seed.*
FROM jsonb_populate_recordset(
  NULL::public.location_types,
  $sitaa_seed$[
  {
    "code": "auditorium",
    "label": "Auditorio o sala",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 30,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Actividad realizada en auditorio, sala audiovisual o espacio similar."
  },
  {
    "code": "classroom",
    "label": "Aula",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 10,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Actividad realizada en aula."
  },
  {
    "code": "external",
    "label": "Espacio externo",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 60,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Actividad realizada fuera de instalaciones universitarias."
  },
  {
    "code": "free_area",
    "label": "Área libre",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 40,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Actividad realizada en explanada, pasillo, jardín u otro espacio abierto."
  },
  {
    "code": "office",
    "label": "Cubículo u oficina",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 20,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Actividad realizada en cubículo, oficina o espacio de trabajo académico."
  },
  {
    "code": "online_space",
    "label": "En línea",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 50,
    "updated_at": "2026-07-08T18:24:58.562579+00:00",
    "description": "Actividad realizada mediante plataforma digital o enlace en línea."
  },
  {
    "code": "other",
    "label": "Otro",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 90,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Otro tipo de lugar."
  }
]$sitaa_seed$::jsonb
) AS seed
ON CONFLICT DO NOTHING;

-- Catálogo: public.participant_roles (5 filas)
INSERT INTO public.participant_roles
SELECT seed.*
FROM jsonb_populate_recordset(
  NULL::public.participant_roles,
  $sitaa_seed$[
  {
    "code": "guest",
    "label": "Invitado",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 50,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Participante invitado."
  },
  {
    "code": "peer_tutor",
    "label": "Tutor par",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 30,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Alumno que participa como tutor par."
  },
  {
    "code": "responsible",
    "label": "Responsable",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 10,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Persona que organiza o conduce la actividad."
  },
  {
    "code": "student",
    "label": "Alumno participante",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 20,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Alumno que recibe tutoría, asesoría u orientación."
  },
  {
    "code": "support",
    "label": "Apoyo",
    "is_active": true,
    "created_at": "2026-07-07T21:34:09.731881+00:00",
    "sort_order": 40,
    "updated_at": "2026-07-07T21:34:09.731881+00:00",
    "description": "Persona que participa como apoyo académico, técnico o logístico."
  }
]$sitaa_seed$::jsonb
) AS seed
ON CONFLICT DO NOTHING;
