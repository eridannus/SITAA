--
-- PostgreSQL database dump
--

\restrict TFu9SdP2ivvyvRgZ0S6vaShbGis4sJSB5sIzUroXZuB7M7BZMiOJSTYV3zcjQ3p

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

CREATE SCHEMA public;


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

  where public.is_sitaa_operational_account_active()
    and a.id = target_activity_id

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

  where public.is_sitaa_operational_account_active()
    and a.id = target_activity_id

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
  select case
    when not public.is_sitaa_operational_account_active() then false
    else (
      select case
        when a.status_code = 'draft' then false
        else coalesce(
          (
            coalesce(a.end_date, a.start_date)::timestamp
            + coalesce(a.end_time, a.start_time, time '23:59:59')
          ) < (now() at time zone 'America/Mexico_City'),
          false
        )
      end
      from public.activities a
      where a.id = target_activity_id
    )
  end;
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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

  -- El INSERT adquiere ROW EXCLUSIVE al inicio del protocolo para mantener el
  -- mismo orden de bloqueo que la corrección administrativa de identidad.
  lock table public.activity_participants in row exclusive mode;

  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para agregar participantes a esta actividad.' using errcode = '42501';
  end if;
  select a.program_id into target_program_id from public.activities a where a.id = target_activity_id;
  if target_program_id is null then
    raise exception 'La actividad no tiene programa académico asignado.' using errcode = 'P0001';
  end if;
  select p.primary_program_id, p.person_type into participant_program_id, participant_person_type
  from public.profiles p
  where p.id = target_profile_id and p.is_active = true
  for share;
  if participant_program_id is null then
    raise exception 'El perfil seleccionado no existe, no está activo o no tiene programa asignado.' using errcode = 'P0001';
  end if;
  if participant_program_id <> target_program_id then
    raise exception 'La persona seleccionada pertenece a otro programa académico.' using errcode = 'P0001';
  end if;
  if not exists (
    select 1 from public.participant_roles pr
    where pr.code = target_participant_role_code and pr.is_active = true
  ) then
    raise exception 'El rol de participante seleccionado no es válido.' using errcode = 'P0001';
  end if;
  if target_participant_role_code = 'responsible' and participant_person_type <> 'professor' then
    raise exception 'Sólo un profesor puede registrarse como responsable de la actividad.' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.activity_participants ap
    where ap.activity_id = target_activity_id and ap.profile_id = target_profile_id
  ) then
    raise exception 'Esta persona ya está registrada como participante en la actividad.' using errcode = '23505';
  end if;
  insert into public.activity_participants (
    activity_id, profile_id, participant_role_code, added_by
  ) values (
    target_activity_id, target_profile_id, target_participant_role_code, auth.uid()
  );
end;
$$;


--
-- Name: admin_audit_metadata_is_safe(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_audit_metadata_is_safe(candidate jsonb) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'pg_catalog', 'public'
    AS $$
  select case
    when candidate is null or jsonb_typeof(candidate) <> 'object'
      or octet_length(candidate::text) > 16384 then false
    else not exists (
      select 1 from jsonb_object_keys(candidate) as key_name
      where regexp_replace(lower(key_name), '[^a-z0-9]+', '', 'g')
        ~ '(password|passwd|token|cookie|secret|authorization|credential|recovery|session|bearer|apikey)'
    )
  end;
$$;


--
-- Name: can_create_activity(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_create_activity(target_program_id uuid, target_service_type_code text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$

  select public.is_sitaa_operational_account_active() and (
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
    or public.can_manage_activity(target_program_id, target_service_type_code)
  );
$$;


--
-- Name: can_create_activity(text, uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_create_activity(target_scope_type text, target_program_id uuid, target_division_id uuid, target_service_type_code text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$

  select public.is_sitaa_operational_account_active() and exists (

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
  select public.is_sitaa_operational_account_active() and exists (
    select 1
    from public.activities a
    where a.id = target_activity_id
      and (
        (
          a.status_code = 'draft'
          and a.created_by = auth.uid()
        )
        or (
          a.status_code <> 'draft'
          and public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)
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

  select public.is_sitaa_operational_account_active() and exists (

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


--
-- Name: can_manage_activity(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_manage_activity(target_program_id uuid, target_service_type_code text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$

  select public.is_sitaa_operational_account_active() and exists (

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

  select public.is_sitaa_operational_account_active() and exists (

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

  select public.is_sitaa_operational_account_active() and exists (

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


--
-- Name: can_update_activity_base(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_update_activity_base(target_activity_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select public.is_sitaa_operational_account_active() and exists (
    select 1
    from public.activities a
    where a.id = target_activity_id
      and (
        (
          a.status_code = 'draft'
          and a.created_by = auth.uid()
        )
        or (
          a.status_code <> 'draft'
          and public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)
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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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
-- Name: complete_own_google_registration(text, text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.complete_own_google_registration(requested_person_type text, requested_full_name text, requested_institutional_id_value text, requested_primary_program_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'auth'
    AS $_$
declare
  current_user_id uuid := auth.uid();
  target_profile public.profiles%rowtype;
  auth_email text;
  auth_email_confirmed_at timestamp with time zone;
  identity_email text;
  identity_email_verified text;
  normalized_name text := regexp_replace(btrim(coalesce(requested_full_name, '')), '\s+', ' ', 'g');
  normalized_identifier text := btrim(coalesce(requested_institutional_id_value, ''));
  identifier_type text;
begin
  if current_user_id is null then
    raise exception 'sitaa_authentication_required' using errcode = '42501';
  end if;

  select * into target_profile from public.profiles
  where id = current_user_id for update;
  if not found then
    raise exception 'sitaa_profile_missing' using errcode = '42501';
  end if;
  if target_profile.account_kind <> 'institutional'
     or target_profile.account_status <> 'pending_registration' then
    raise exception 'sitaa_registration_not_pending' using errcode = '42501';
  end if;

  select lower(btrim(u.email)), u.email_confirmed_at
  into auth_email, auth_email_confirmed_at
  from auth.users u where u.id = current_user_id;
  if not found then
    raise exception 'sitaa_auth_user_missing' using errcode = '42501';
  end if;

  if not exists (
    select 1 from auth.identities i
    where i.user_id = current_user_id and i.provider = 'google'
  ) then
    raise exception 'sitaa_google_identity_required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from auth.identities i
    where i.user_id = current_user_id and i.provider = 'google'
      and nullif(btrim(i.identity_data ->> 'email'), '') is not null
  ) then
    raise exception 'sitaa_google_identity_email_missing' using errcode = '23514';
  end if;
  if nullif(auth_email, '') is null
     or auth_email <> lower(btrim(target_profile.email)) then
    raise exception 'sitaa_google_identity_email_mismatch' using errcode = '23514';
  end if;

  select lower(btrim(i.identity_data ->> 'email')),
         lower(btrim(coalesce(i.identity_data ->> 'email_verified', '')))
  into identity_email, identity_email_verified
  from auth.identities i
  where i.user_id = current_user_id and i.provider = 'google'
    and lower(btrim(i.identity_data ->> 'email')) = auth_email
  order by i.created_at asc
  limit 1;
  if not found or identity_email <> lower(btrim(target_profile.email)) then
    raise exception 'sitaa_google_identity_email_mismatch' using errcode = '23514';
  end if;
  if auth_email_confirmed_at is null
     and identity_email_verified not in ('true', 't', '1') then
    raise exception 'sitaa_google_email_not_verified' using errcode = '23514';
  end if;

  if requested_person_type not in ('student', 'professor') then
    raise exception 'sitaa_invalid_registration_type' using errcode = '23514';
  end if;
  if char_length(normalized_name) not between 2 and 200 then
    raise exception 'sitaa_invalid_full_name' using errcode = '23514';
  end if;
  if normalized_identifier !~ '^[0-9]+$' then
    raise exception 'sitaa_invalid_institutional_identifier' using errcode = '23514';
  end if;
  if char_length(normalized_identifier) > 50 then
    raise exception 'sitaa_identifier_too_long' using errcode = '23514';
  end if;
  if not exists (
    select 1 from public.academic_programs ap
    where ap.id = requested_primary_program_id and ap.is_active
  ) then
    raise exception 'sitaa_invalid_registration_program' using errcode = '23514';
  end if;

  identifier_type := case
    when requested_person_type = 'student' then 'student_account'
    else 'worker_number'
  end;
  if exists (
    select 1 from public.profiles p
    where p.id <> current_user_id
      and p.institutional_id_type = identifier_type
      and p.institutional_id_value = normalized_identifier
  ) then
    raise exception 'sitaa_identifier_conflict' using errcode = '23505';
  end if;

  begin
    update public.profiles
    set full_name = normalized_name,
        person_type = requested_person_type,
        primary_program_id = requested_primary_program_id,
        institutional_id_type = identifier_type,
        institutional_id_value = normalized_identifier,
        account_status = 'active', is_active = true,
        activated_at = coalesce(activated_at, now()), deactivated_at = null
    where id = current_user_id;
  exception when unique_violation then
    raise exception 'sitaa_identifier_conflict' using errcode = '23505';
  end;
end;
$_$;


--
-- Name: complete_own_google_registration(text, text, text, text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.complete_own_google_registration(requested_person_type text, requested_first_names text, requested_paternal_surname text, requested_maternal_surname text, requested_institutional_id_value text, requested_primary_program_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'auth'
    AS $_$
declare
  current_user_id uuid := auth.uid();
  target_profile public.profiles%rowtype;
  auth_email text; auth_email_confirmed_at timestamptz; identity_email text; identity_email_verified text;
  normalized_first_names text := regexp_replace(btrim(coalesce(requested_first_names, '')), '\s+', ' ', 'g');
  normalized_paternal text := regexp_replace(btrim(coalesce(requested_paternal_surname, '')), '\s+', ' ', 'g');
  normalized_maternal text := nullif(regexp_replace(btrim(coalesce(requested_maternal_surname, '')), '\s+', ' ', 'g'), '');
  normalized_identifier text := coalesce(requested_institutional_id_value, '');
  identifier_type text;
begin
  if current_user_id is null then raise exception 'sitaa_authentication_required' using errcode = '42501'; end if;
  select * into target_profile from public.profiles where id = current_user_id for update;
  if not found then raise exception 'sitaa_profile_missing' using errcode = '42501'; end if;
  if target_profile.account_kind <> 'institutional' or target_profile.account_status <> 'pending_registration' then raise exception 'sitaa_registration_not_pending' using errcode = '42501'; end if;

  select lower(btrim(u.email)), u.email_confirmed_at into auth_email, auth_email_confirmed_at from auth.users u where u.id = current_user_id;
  if not found then raise exception 'sitaa_auth_user_missing' using errcode = '42501'; end if;
  if not exists (select 1 from auth.identities i where i.user_id = current_user_id and i.provider = 'google') then raise exception 'sitaa_google_identity_required' using errcode = '42501'; end if;
  select lower(btrim(i.identity_data ->> 'email')), lower(btrim(coalesce(i.identity_data ->> 'email_verified', '')))
  into identity_email, identity_email_verified
  from auth.identities i where i.user_id = current_user_id and i.provider = 'google'
    and lower(btrim(i.identity_data ->> 'email')) = auth_email order by i.created_at asc limit 1;
  if not found or nullif(auth_email, '') is null or auth_email <> lower(btrim(target_profile.email)) or identity_email <> auth_email then raise exception 'sitaa_google_identity_email_mismatch' using errcode = '23514'; end if;
  if auth_email_confirmed_at is null and identity_email_verified not in ('true', 't', '1') then raise exception 'sitaa_google_email_not_verified' using errcode = '23514'; end if;

  if requested_person_type not in ('student', 'professor') then raise exception 'sitaa_invalid_registration_type' using errcode = '23514'; end if;
  if char_length(normalized_first_names) not between 1 and 150 then raise exception 'sitaa_invalid_first_names' using errcode = '23514'; end if;
  if char_length(normalized_paternal) not between 1 and 150 then raise exception 'sitaa_invalid_paternal_surname' using errcode = '23514'; end if;
  if coalesce(char_length(normalized_maternal), 0) > 150 then raise exception 'sitaa_invalid_maternal_surname' using errcode = '23514'; end if;
  if char_length(concat_ws(' ', normalized_first_names, normalized_paternal, normalized_maternal)) > 200 then raise exception 'sitaa_invalid_full_name' using errcode = '23514'; end if;
  if normalized_identifier !~ '^[0-9]+$' then raise exception 'sitaa_invalid_institutional_identifier' using errcode = '23514'; end if;
  if char_length(normalized_identifier) > 50 then raise exception 'sitaa_identifier_too_long' using errcode = '23514'; end if;
  if not exists (select 1 from public.academic_programs ap where ap.id = requested_primary_program_id and ap.is_active) then raise exception 'sitaa_invalid_registration_program' using errcode = '23514'; end if;

  identifier_type := case when requested_person_type = 'student' then 'student_account' else 'worker_number' end;
  if exists (select 1 from public.profiles p where p.id <> current_user_id and p.institutional_id_type = identifier_type and p.institutional_id_value = normalized_identifier) then raise exception 'sitaa_identifier_conflict' using errcode = '23505'; end if;

  begin
    update public.profiles set first_names = normalized_first_names, paternal_surname = normalized_paternal,
      maternal_surname = normalized_maternal, person_type = requested_person_type,
      primary_program_id = requested_primary_program_id, institutional_id_type = identifier_type,
      institutional_id_value = normalized_identifier, account_status = 'active', is_active = true,
      activated_at = coalesce(activated_at, now()), deactivated_at = null
    where id = current_user_id;
  exception when unique_violation then raise exception 'sitaa_identifier_conflict' using errcode = '23505'; end;
end;
$_$;


--
-- Name: correct_admin_account_identity_b2a(uuid, text, text, text, text, text, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.correct_admin_account_identity_b2a(requested_profile_id uuid, requested_first_names text, requested_paternal_surname text, requested_maternal_surname text, requested_person_type text, requested_institutional_id_value text, requested_primary_program_id uuid, correction_reason text) RETURNS TABLE(target_profile_id uuid, audit_event_id uuid, changed_fields text[], updated_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $_$
declare
  target_profile public.profiles%rowtype;
  normalized_first_names text;
  normalized_paternal_surname text;
  normalized_maternal_surname text;
  normalized_full_name text;
  normalized_reason text;
  derived_identifier_type text;
  requested_division_id uuid;
  institutional_today date:=public.sitaa_current_mexico_date();
  changed text[]:=array[]::text[];
  persisted_updated_at timestamptz;
  event_id uuid;
  actor_profile_id uuid:=auth.uid();
begin
  if actor_profile_id is null or not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode='42501';
  end if;

  if actor_profile_id=requested_profile_id then
    raise exception 'sitaa_identity_self_correction_forbidden' using errcode='42501';
  end if;

  -- Protocolo fijo y corto: las escrituras normales toman ROW EXCLUSIVE y no
  -- pueden cruzar la decisión de dependencias protegida por estos SHARE locks.
  lock table public.role_assignments in share mode;
  lock table public.activities in share mode;
  lock table public.activity_participants in share mode;

  -- Actor y objetivo se bloquean juntos y por UUID para que dos administradores
  -- que se corrijan de forma cruzada no adquieran las filas en orden opuesto.
  perform 1
  from public.profiles profile
  where profile.id in (actor_profile_id,requested_profile_id)
  order by profile.id
  for update;

  -- La autorización inicial es optimista. Ésta es la decisión autoritativa:
  -- ocurre tras esperar roles, dependencias y estado de ambos perfiles.
  if not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode='42501';
  end if;

  select p.* into target_profile
  from public.profiles p
  where p.id=requested_profile_id;

  if not found then
    raise exception 'sitaa_identity_target_unavailable' using errcode='P0001';
  end if;
  if target_profile.account_status='pending_registration' then
    raise exception 'sitaa_identity_pending_target' using errcode='P0001';
  end if;
  if target_profile.account_status not in ('active','inactive')
     or target_profile.account_kind not in ('institutional','technical') then
    raise exception 'sitaa_identity_target_unavailable' using errcode='P0001';
  end if;

  normalized_reason:=nullif(
    btrim(regexp_replace(coalesce(correction_reason,''),'\s+',' ','g')),
    ''
  );
  if normalized_reason is null
     or char_length(normalized_reason)<10
     or char_length(normalized_reason)>1000 then
    raise exception 'sitaa_identity_invalid_reason' using errcode='22023';
  end if;

  normalized_first_names:=nullif(
    btrim(regexp_replace(coalesce(requested_first_names,''),'\s+',' ','g')),
    ''
  );
  normalized_paternal_surname:=nullif(
    btrim(regexp_replace(coalesce(requested_paternal_surname,''),'\s+',' ','g')),
    ''
  );
  normalized_maternal_surname:=nullif(
    btrim(regexp_replace(coalesce(requested_maternal_surname,''),'\s+',' ','g')),
    ''
  );
  normalized_full_name:=nullif(
    concat_ws(' ',normalized_first_names,normalized_paternal_surname,normalized_maternal_surname),
    ''
  );

  if normalized_first_names is null
     or char_length(normalized_first_names)>150
     or char_length(normalized_paternal_surname)>150
     or char_length(normalized_maternal_surname)>150
     or char_length(normalized_full_name) not between 2 and 200 then
    raise exception 'sitaa_identity_invalid_name' using errcode='22023';
  end if;

  if target_profile.account_kind='technical' then
    if requested_person_type is not null
       or requested_institutional_id_value is not null
       or requested_primary_program_id is not null then
      raise exception 'sitaa_identity_technical_fields_forbidden' using errcode='22023';
    end if;
  else
    if normalized_paternal_surname is null then
      raise exception 'sitaa_identity_invalid_name' using errcode='22023';
    end if;
    if requested_person_type is null
       or requested_person_type not in ('student','professor') then
      raise exception 'sitaa_identity_invalid_person_type' using errcode='22023';
    end if;
    if requested_institutional_id_value is null
       or requested_institutional_id_value !~ '^[0-9]{1,50}$' then
      raise exception 'sitaa_identity_invalid_identifier' using errcode='22023';
    end if;
    derived_identifier_type:=case
      when requested_person_type='student' then 'student_account'
      else 'worker_number'
    end;

    select program.division_id into requested_division_id
    from public.academic_programs program
    where program.id=requested_primary_program_id
      and program.is_active=true
    for share;
    if not found then
      raise exception 'sitaa_identity_invalid_program' using errcode='22023';
    end if;

    if exists (
      select 1 from public.profiles other_profile
      where other_profile.id<>target_profile.id
        and other_profile.institutional_id_type=derived_identifier_type
        and other_profile.institutional_id_value=requested_institutional_id_value
    ) then
      raise exception 'sitaa_identity_duplicate_identifier' using errcode='23505';
    end if;

    if requested_person_type is distinct from target_profile.person_type then
      if exists (
        select 1 from public.role_assignments ra
        where ra.user_id=target_profile.id
          and ra.is_active=true
          and (ra.ends_at is null or ra.ends_at>=institutional_today)
      ) then
        raise exception 'sitaa_identity_person_type_dependency' using errcode='P0001';
      end if;

      if requested_person_type='student' and exists (
        select 1
        from public.activities a
        where (
          a.responsible_profile_id=target_profile.id
          or exists (
            select 1 from public.activity_participants participant
            where participant.activity_id=a.id
              and participant.profile_id=target_profile.id
              and participant.participant_role_code='responsible'
          )
        )
        and (a.status_code='draft' or public.activity_has_ended(a.id) is distinct from true)
      ) then
        raise exception 'sitaa_identity_person_type_dependency' using errcode='P0001';
      end if;
    end if;

    if requested_primary_program_id is distinct from target_profile.primary_program_id then
      if exists (
        select 1 from public.role_assignments ra
        where ra.user_id=target_profile.id
          and ra.is_active=true
          and (ra.ends_at is null or ra.ends_at>=institutional_today)
          and (
            (ra.program_id is not null and ra.program_id<>requested_primary_program_id)
            or (ra.division_id is not null and ra.division_id<>requested_division_id)
          )
      ) then
        raise exception 'sitaa_identity_program_dependency' using errcode='P0001';
      end if;

      if exists (
        select 1
        from public.activities a
        where (
          a.responsible_profile_id=target_profile.id
          or exists (
            select 1 from public.activity_participants participant
            where participant.activity_id=a.id
              and participant.profile_id=target_profile.id
          )
        )
        and (a.status_code='draft' or public.activity_has_ended(a.id) is distinct from true)
        and (
          (a.scope_type='program' and a.program_id is distinct from requested_primary_program_id)
          or (a.scope_type='division' and a.division_id is distinct from requested_division_id)
        )
      ) then
        raise exception 'sitaa_identity_program_dependency' using errcode='P0001';
      end if;
    end if;
  end if;

  if normalized_first_names is distinct from target_profile.first_names then
    changed:=array_append(changed,'first_names');
  end if;
  if target_profile.account_kind='institutional'
     and derived_identifier_type is distinct from target_profile.institutional_id_type then
    changed:=array_append(changed,'institutional_id_type');
  end if;
  if target_profile.account_kind='institutional'
     and requested_institutional_id_value is distinct from target_profile.institutional_id_value then
    changed:=array_append(changed,'institutional_id_value');
  end if;
  if normalized_maternal_surname is distinct from target_profile.maternal_surname then
    changed:=array_append(changed,'maternal_surname');
  end if;
  if normalized_paternal_surname is distinct from target_profile.paternal_surname then
    changed:=array_append(changed,'paternal_surname');
  end if;
  if target_profile.account_kind='institutional'
     and requested_person_type is distinct from target_profile.person_type then
    changed:=array_append(changed,'person_type');
  end if;
  if target_profile.account_kind='institutional'
     and requested_primary_program_id is distinct from target_profile.primary_program_id then
    changed:=array_append(changed,'primary_program_id');
  end if;

  if coalesce(cardinality(changed),0)=0 then
    raise exception 'sitaa_identity_no_changes' using errcode='22023';
  end if;

  begin
    if target_profile.account_kind='institutional' then
      update public.profiles p
      set first_names=normalized_first_names,
          paternal_surname=normalized_paternal_surname,
          maternal_surname=normalized_maternal_surname,
          person_type=requested_person_type,
          institutional_id_type=derived_identifier_type,
          institutional_id_value=requested_institutional_id_value,
          primary_program_id=requested_primary_program_id,
          updated_at=now()
      where p.id=target_profile.id
      returning p.updated_at into persisted_updated_at;
    else
      update public.profiles p
      set first_names=normalized_first_names,
          paternal_surname=normalized_paternal_surname,
          maternal_surname=normalized_maternal_surname,
          updated_at=now()
      where p.id=target_profile.id
      returning p.updated_at into persisted_updated_at;
    end if;
  exception when unique_violation then
    raise exception 'sitaa_identity_duplicate_identifier' using errcode='23505';
  end;

  insert into public.admin_audit_events(
    actor_profile_id,target_profile_id,action_code,outcome,reason,
    role_assignment_id,metadata
  ) values (
    actor_profile_id,target_profile.id,'account_identity_corrected','success',
    normalized_reason,null,
    jsonb_build_object('changed_fields',to_jsonb(changed))
  )
  returning id into event_id;

  return query select target_profile.id,event_id,changed,persisted_updated_at;
end;
$_$;


--
-- Name: enforce_activity_writer_integrity_b2a(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_activity_writer_integrity_b2a() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $$
declare
  participant record;
  responsible record;
  old_is_open boolean:=false;
  new_is_open boolean:=false;
  scope_changed boolean:=false;
  schedule_changed boolean:=false;
  revalidate_dependencies boolean:=false;
begin
  if tg_op='UPDATE' then
    old_is_open:=old.status_code='draft' or not coalesce(
      (
        coalesce(old.end_date,old.start_date)::timestamp
        + coalesce(old.end_time,old.start_time,time '23:59:59')
      ) < (now() at time zone 'America/Mexico_City'),
      false
    );
    new_is_open:=new.status_code='draft' or not coalesce(
      (
        coalesce(new.end_date,new.start_date)::timestamp
        + coalesce(new.end_time,new.start_time,time '23:59:59')
      ) < (now() at time zone 'America/Mexico_City'),
      false
    );
    scope_changed:=new.scope_type is distinct from old.scope_type
      or new.program_id is distinct from old.program_id
      or new.division_id is distinct from old.division_id;
    schedule_changed:=new.status_code is distinct from old.status_code
      or new.start_date is distinct from old.start_date
      or new.start_time is distinct from old.start_time
      or new.end_date is distinct from old.end_date
      or new.end_time is distinct from old.end_time
      or new.starts_at is distinct from old.starts_at
      or new.ends_at is distinct from old.ends_at;

    if schedule_changed and not old_is_open and new_is_open
       and auth.uid() is not null then
      raise exception 'sitaa_activity_reopen_forbidden' using errcode='23514';
    end if;

    revalidate_dependencies:=new_is_open and (
      scope_changed or (schedule_changed and not old_is_open)
    );
  end if;

  if auth.uid() is not null then
    if tg_op='INSERT' then
      if new.created_by is distinct from auth.uid()
         or new.responsible_profile_id is distinct from auth.uid() then
        raise exception 'sitaa_activity_writer_identity_mismatch' using errcode='42501';
      end if;
      if not public.can_create_activity(
        new.scope_type,new.program_id,new.division_id,new.service_type_code
      ) then
        raise exception 'sitaa_activity_writer_scope_denied' using errcode='42501';
      end if;
    else
      if new.created_by is distinct from old.created_by
         or new.responsible_profile_id is distinct from old.responsible_profile_id then
        raise exception 'sitaa_activity_writer_identity_immutable' using errcode='42501';
      end if;
      if (
        new.scope_type is distinct from old.scope_type
        or new.program_id is distinct from old.program_id
        or new.division_id is distinct from old.division_id
        or new.service_type_code is distinct from old.service_type_code
      ) and not public.can_create_activity(
        new.scope_type,new.program_id,new.division_id,new.service_type_code
      ) then
        raise exception 'sitaa_activity_writer_scope_denied' using errcode='42501';
      end if;
    end if;
  end if;

  if tg_op='UPDATE' and revalidate_dependencies then
    lock table public.activity_participants in share mode;

    for participant in
      select
        activity_participant.participant_role_code,
        profile.person_type,
        profile.primary_program_id,
        program.division_id
      from public.activity_participants activity_participant
      join public.profiles profile on profile.id=activity_participant.profile_id
      left join public.academic_programs program on program.id=profile.primary_program_id
      where activity_participant.activity_id=new.id
      for share of profile
    loop
      if participant.primary_program_id is null
         or (new.scope_type='program'
           and participant.primary_program_id is distinct from new.program_id)
         or (new.scope_type='division'
           and participant.division_id is distinct from new.division_id)
         or (participant.participant_role_code='responsible'
           and participant.person_type is distinct from 'professor') then
        raise exception 'sitaa_activity_participant_identity_incompatible'
          using errcode='23514';
      end if;
    end loop;

    select
      profile.account_kind,
      profile.primary_program_id,
      program.division_id
    into responsible
    from public.profiles profile
    left join public.academic_programs program
      on program.id=profile.primary_program_id
    where profile.id=new.responsible_profile_id
    for share of profile;

    if responsible.account_kind='institutional' and (
      responsible.primary_program_id is null
      or (new.scope_type='program'
        and responsible.primary_program_id is distinct from new.program_id)
      or (new.scope_type='division'
        and responsible.division_id is distinct from new.division_id)
    ) then
      raise exception 'sitaa_activity_responsibility_identity_incompatible'
        using errcode='23514';
    end if;
  end if;

  return new;
end;
$$;


--
-- Name: enforce_sitaa_profile_identity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_sitaa_profile_identity() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $$
begin
  if tg_op = 'UPDATE' and current_user = 'authenticated' and auth.uid() = old.id then
    if old.account_status <> 'active' then
      raise exception 'La cuenta debe completar su registro antes de editar el perfil.' using errcode = '42501';
    end if;
    if (to_jsonb(new) - 'first_names' - 'paternal_surname' - 'maternal_surname' - 'full_name' - 'updated_at')
       is distinct from (to_jsonb(old) - 'first_names' - 'paternal_surname' - 'maternal_surname' - 'full_name' - 'updated_at') then
      raise exception 'Sólo puedes actualizar tus nombres y apellidos.' using errcode = '42501';
    end if;
  end if;

  if new.account_kind = 'institutional' and new.account_status in ('active', 'inactive')
     and not exists (select 1 from public.academic_programs ap where ap.id = new.primary_program_id and ap.is_active) then
    raise exception 'El programa académico no existe o está inactivo.' using errcode = '23514';
  end if;

  if new.account_status = 'active' then
    new.is_active := true;
    new.activated_at := coalesce(new.activated_at, now());
    new.deactivated_at := null;
  elsif new.account_status = 'pending_registration' then
    new.is_active := false; new.activated_at := null; new.deactivated_at := null;
  elsif new.account_status = 'inactive' then
    new.is_active := false; new.deactivated_at := coalesce(new.deactivated_at, now());
  end if;
  return new;
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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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
-- Name: get_admin_account_assignments_b1(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_admin_account_assignments_b1(target_profile_id uuid) RETURNS TABLE(id uuid, role_code text, role_label text, scope_type text, service_area text, division_id uuid, division_name text, program_id uuid, program_name text, starts_at date, ends_at date, is_active boolean, assigned_by uuid, created_at timestamp with time zone, presentation_status text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $$
begin
  if not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode = '42501';
  end if;
  return query
  select ra.id, ra.role_code, r.label, ra.scope_type, ra.service_area,
    ra.division_id, d.name, ra.program_id, ap.name, ra.starts_at, ra.ends_at,
    ra.is_active, ra.assigned_by, ra.created_at,
    case
      when not ra.is_active then 'inactive'
      when ra.starts_at > public.sitaa_current_mexico_date() then 'future'
      when ra.ends_at is not null and ra.ends_at < public.sitaa_current_mexico_date() then 'expired'
      when p.account_status <> 'active' then 'suspended_by_account_status'
      else 'current'
    end
  from public.role_assignments ra
  join public.profiles p on p.id = ra.user_id
  join public.roles r on r.code = ra.role_code
  left join public.divisions d on d.id = ra.division_id
  left join public.academic_programs ap on ap.id = ra.program_id
  where ra.user_id = target_profile_id
  order by ra.created_at desc, ra.id desc;
end;
$$;


--
-- Name: get_admin_account_audit_history_b1(uuid, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_admin_account_audit_history_b1(requested_profile_id uuid, result_limit integer DEFAULT 50, result_offset integer DEFAULT 0) RETURNS TABLE(id uuid, actor_profile_id uuid, actor_display_name text, target_profile_id uuid, action_code text, outcome text, reason text, role_assignment_id uuid, occurred_at timestamp with time zone)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $$
begin
  if not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode = '42501';
  end if;
  if result_limit is null or result_limit < 1 or result_limit > 50
     or result_offset is null or result_offset < 0 or result_offset > 1000000 then
    raise exception 'sitaa_admin_invalid_audit_pagination' using errcode = '22023';
  end if;
  return query
  select e.id, e.actor_profile_id, actor.full_name, e.target_profile_id,
    e.action_code, e.outcome, e.reason, e.role_assignment_id, e.occurred_at
  from public.admin_audit_events e
  left join public.profiles actor on actor.id = e.actor_profile_id
  where e.target_profile_id = requested_profile_id
  order by e.occurred_at desc, e.id desc
  limit result_limit offset result_offset;
end;
$$;


--
-- Name: get_admin_account_detail_b1(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_admin_account_detail_b1(target_profile_id uuid) RETURNS TABLE(profile_id uuid, first_names text, paternal_surname text, maternal_surname text, full_name text, email text, account_kind text, account_status text, person_type text, institutional_id_type text, institutional_id_value text, primary_program_id uuid, primary_program_name text, activated_at timestamp with time zone, deactivated_at timestamp with time zone, auth_email_confirmed boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'auth'
    AS $$
begin
  if not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode = '42501';
  end if;
  return query
  select p.id, p.first_names, p.paternal_surname, p.maternal_surname,
    p.full_name, p.email, p.account_kind, p.account_status, p.person_type,
    p.institutional_id_type, p.institutional_id_value, p.primary_program_id,
    ap.name, p.activated_at, p.deactivated_at,
    (
      u.email_confirmed_at is not null
      or exists (
        select 1 from auth.identities identity_row
        where identity_row.user_id = u.id
          and identity_row.provider = 'google'
          and lower(btrim(identity_row.identity_data ->> 'email')) = lower(btrim(u.email))
          and lower(btrim(coalesce(identity_row.identity_data ->> 'email_verified', ''))) in ('true','t','1')
      )
    )
  from public.profiles p
  join auth.users u on u.id = p.id
  left join public.academic_programs ap on ap.id = p.primary_program_id
  where p.id = target_profile_id;
end;
$$;


--
-- Name: get_admin_account_lifecycle_context_b2b(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_admin_account_lifecycle_context_b2b(requested_profile_id uuid) RETURNS TABLE(target_profile_id uuid, account_kind text, account_status text, is_self boolean, can_deactivate boolean, can_reactivate boolean, denial_code text, has_exact_b1_assignment boolean, active_exact_b1_admin_count bigint, current_or_future_assignment_count bigint, open_responsibility_count bigint, open_participation_count bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $_$
declare
  target_profile public.profiles%rowtype;
  institutional_today date:=public.sitaa_current_mexico_date();
  exact_assignment boolean:=false;
  exact_admin_count bigint:=0;
  assignment_count bigint:=0;
  responsibility_count bigint:=0;
  participation_count bigint:=0;
  matching_auth_count bigint:=0;
  auth_confirmed boolean:=false;
  identity_valid boolean:=false;
  lifecycle_valid boolean:=false;
  denial text:=null;
  deactivate_allowed boolean:=false;
  reactivate_allowed boolean:=false;
begin
  if not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode='42501';
  end if;

  select profile.* into target_profile
  from public.profiles profile
  where profile.id=requested_profile_id;
  if not found then return; end if;

  select exists(
    select 1 from public.role_assignments assignment
    where assignment.user_id=target_profile.id
      and assignment.role_code='technical_admin'
      and assignment.scope_type='system'
      and assignment.service_area='technical'
      and assignment.program_id is null
      and assignment.division_id is null
      and assignment.is_active=true
      and assignment.starts_at<=institutional_today
      and (assignment.ends_at is null or assignment.ends_at>=institutional_today)
  ) into exact_assignment;
  select count(distinct profile.id) into exact_admin_count
  from public.profiles profile
  where public.is_exact_b1_account_admin_profile_b2b(profile.id);

  select count(*) into assignment_count
  from public.role_assignments assignment
  where assignment.user_id=target_profile.id
    and assignment.is_active=true
    and (assignment.ends_at is null or assignment.ends_at>=institutional_today);

  select count(distinct activity.id) into responsibility_count
  from public.activities activity
  where (activity.created_by=target_profile.id
      or activity.responsible_profile_id=target_profile.id)
    and (activity.status_code='draft'
      or public.activity_has_ended(activity.id) is distinct from true);

  select count(distinct activity.id) into participation_count
  from public.activity_participants participant
  join public.activities activity on activity.id=participant.activity_id
  where participant.profile_id=target_profile.id
    and (activity.status_code='draft' or public.activity_has_ended(activity.id) is distinct from true);

  select count(*),coalesce(bool_or(
    auth_user.email_confirmed_at is not null or exists (
      select 1 from auth.identities identity_row
      where identity_row.user_id=auth_user.id
        and identity_row.provider='google'
        and lower(btrim(identity_row.identity_data->>'email'))=lower(btrim(auth_user.email))
        and lower(btrim(coalesce(identity_row.identity_data->>'email_verified',''))) in ('true','t','1')
    )
  ),false)
  into matching_auth_count,auth_confirmed
  from auth.users auth_user
  where auth_user.id=target_profile.id
    and lower(btrim(auth_user.email))=target_profile.email;

  lifecycle_valid:=
    (target_profile.account_status='active' and target_profile.is_active=true and target_profile.activated_at is not null and target_profile.deactivated_at is null)
    or (target_profile.account_status='inactive' and target_profile.is_active=false
      and target_profile.activated_at is not null and target_profile.deactivated_at is not null);

  identity_valid:=target_profile.email=lower(btrim(target_profile.email)) and (
      target_profile.account_kind='institutional'
      and target_profile.person_type in ('student','professor')
      and target_profile.first_names is not null
      and target_profile.paternal_surname is not null
      and target_profile.full_name is not null
      and char_length(target_profile.first_names) between 1 and 150
      and target_profile.first_names=regexp_replace(btrim(target_profile.first_names),'\s+',' ','g')
      and char_length(target_profile.paternal_surname) between 1 and 150
      and target_profile.paternal_surname=regexp_replace(btrim(target_profile.paternal_surname),'\s+',' ','g')
      and (target_profile.maternal_surname is null or char_length(target_profile.maternal_surname) between 1 and 150 and target_profile.maternal_surname=regexp_replace(btrim(target_profile.maternal_surname),'\s+',' ','g'))
      and char_length(target_profile.full_name) between 2 and 200
      and target_profile.full_name=concat_ws(' ',target_profile.first_names,target_profile.paternal_surname,target_profile.maternal_surname)
      and target_profile.primary_program_id is not null
      and exists (select 1 from public.academic_programs program where program.id=target_profile.primary_program_id and program.is_active=true)
      and target_profile.institutional_id_value~'^[0-9]{1,50}$'
      and target_profile.institutional_id_type=case when target_profile.person_type='student' then 'student_account' else 'worker_number' end
      or target_profile.account_kind='technical'
      and target_profile.first_names is not null
      and target_profile.full_name is not null
      and char_length(target_profile.first_names) between 1 and 150
      and target_profile.first_names=regexp_replace(btrim(target_profile.first_names),'\s+',' ','g')
      and (target_profile.paternal_surname is null or char_length(target_profile.paternal_surname) between 1 and 150 and target_profile.paternal_surname=regexp_replace(btrim(target_profile.paternal_surname),'\s+',' ','g'))
      and (target_profile.maternal_surname is null or char_length(target_profile.maternal_surname) between 1 and 150 and target_profile.maternal_surname=regexp_replace(btrim(target_profile.maternal_surname),'\s+',' ','g'))
      and char_length(target_profile.full_name) between 2 and 200
      and target_profile.full_name=concat_ws(' ',target_profile.first_names,target_profile.paternal_surname,target_profile.maternal_surname)
      and target_profile.person_type is null
      and target_profile.primary_program_id is null
      and target_profile.institutional_id_type is null
      and target_profile.institutional_id_value is null
    );

  denial:=case
    when target_profile.id=auth.uid() then 'self_forbidden'
    when target_profile.account_status='pending_registration' then 'pending_target'
    when target_profile.account_status not in ('active','inactive') or not lifecycle_valid then 'invalid_lifecycle'
    when target_profile.account_status='active' and exact_assignment and exact_admin_count<=1 then 'last_admin'
    when target_profile.account_status='inactive' and not identity_valid then 'invalid_identity'
    when target_profile.account_status='inactive' and (matching_auth_count<>1 or not auth_confirmed) then 'auth_unconfirmed'
    else null
  end;

  deactivate_allowed:=denial is null and target_profile.account_status='active';
  reactivate_allowed:=denial is null and target_profile.account_status='inactive';

  return query select target_profile.id,target_profile.account_kind,
    target_profile.account_status,target_profile.id=auth.uid(),deactivate_allowed,
    reactivate_allowed,denial,exact_assignment,exact_admin_count,assignment_count,
    responsibility_count,participation_count;
end;
$_$;


--
-- Name: get_admin_identity_correction_context_b2a(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_admin_identity_correction_context_b2a(requested_profile_id uuid) RETURNS TABLE(target_profile_id uuid, can_correct boolean, denial_code text, account_kind text, account_status text, is_self boolean, current_or_future_assignment_count bigint, open_responsibility_count bigint, open_participation_count bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $$
declare
  target_profile public.profiles%rowtype;
  institutional_today date:=public.sitaa_current_mexico_date();
  assignment_count bigint:=0;
  responsibility_count bigint:=0;
  participation_count bigint:=0;
  allowed boolean;
  denial text;
begin
  if not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode='42501';
  end if;

  select p.* into target_profile
  from public.profiles p
  where p.id=requested_profile_id;

  if not found then
    return;
  end if;

  select count(*) into assignment_count
  from public.role_assignments ra
  where ra.user_id=target_profile.id
    and ra.is_active=true
    and (ra.ends_at is null or ra.ends_at>=institutional_today);

  select count(distinct responsibilities.activity_id) into responsibility_count
  from (
    select a.id as activity_id
    from public.activities a
    where a.responsible_profile_id=target_profile.id
      and (a.status_code='draft' or public.activity_has_ended(a.id) is distinct from true)
    union
    select a.id
    from public.activity_participants participant
    join public.activities a on a.id=participant.activity_id
    where participant.profile_id=target_profile.id
      and participant.participant_role_code='responsible'
      and (a.status_code='draft' or public.activity_has_ended(a.id) is distinct from true)
  ) responsibilities;

  select count(distinct a.id) into participation_count
  from public.activity_participants participant
  join public.activities a on a.id=participant.activity_id
  where participant.profile_id=target_profile.id
    and (a.status_code='draft' or public.activity_has_ended(a.id) is distinct from true);

  allowed:=target_profile.id<>auth.uid()
    and target_profile.account_status in ('active','inactive')
    and target_profile.account_kind in ('institutional','technical');

  denial:=case
    when target_profile.id=auth.uid() then 'self_target'
    when target_profile.account_status='pending_registration' then 'pending_target'
    when target_profile.account_status not in ('active','inactive')
      or target_profile.account_kind not in ('institutional','technical')
      then 'unsupported_target'
    else null
  end;

  return query select
    target_profile.id,
    allowed,
    denial,
    target_profile.account_kind,
    target_profile.account_status,
    target_profile.id=auth.uid(),
    assignment_count,
    responsibility_count,
    participation_count;
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

    public.is_sitaa_operational_account_active()

    and (

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

    )

  order by a.start_date desc nulls last, a.start_time desc nulls last, a.created_at desc;

$$;


--
-- Name: guard_activity_participant_pending_deadline(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.guard_activity_participant_pending_deadline() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
declare
  natural_deadline timestamptz;
begin
  if new.attendance_status = 'pending'
     and new.attendance_status is distinct from old.attendance_status then
    natural_deadline := public.activity_attendance_deadline(new.activity_id);
    if natural_deadline is null or natural_deadline <= now() then
      raise exception 'La ventana de asistencia ya terminó; el estado Pendiente ya no está disponible.'
        using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;


--
-- Name: handle_sitaa_auth_user_created(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_sitaa_auth_user_created() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'auth'
    AS $$
declare
  normalized_email text := lower(btrim(coalesce(new.email, '')));
  trusted_kind text := new.raw_app_meta_data ->> 'sitaa_account_kind';
  provider text := lower(coalesce(new.raw_app_meta_data ->> 'provider', ''));
  is_google boolean := provider = 'google' or coalesce(new.raw_app_meta_data -> 'providers', '[]'::jsonb) ? 'google';
  public_technical_request boolean := new.raw_user_meta_data ? 'sitaa_account_kind'
    or new.raw_user_meta_data ->> 'sitaa_registration_type' = 'technical';
  provisional_name text := regexp_replace(btrim(coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', '')), '\s+', ' ', 'g');
  technical_first_names text := regexp_replace(btrim(coalesce(new.raw_app_meta_data ->> 'sitaa_first_names', new.raw_app_meta_data ->> 'sitaa_full_name', '')), '\s+', ' ', 'g');
  technical_paternal_surname text := nullif(regexp_replace(btrim(coalesce(new.raw_app_meta_data ->> 'sitaa_paternal_surname', '')), '\s+', ' ', 'g'), '');
  technical_maternal_surname text := nullif(regexp_replace(btrim(coalesce(new.raw_app_meta_data ->> 'sitaa_maternal_surname', '')), '\s+', ' ', 'g'), '');
begin
  if normalized_email = '' or char_length(normalized_email) > 254 then raise exception 'sitaa_invalid_registration_email' using errcode = '23514'; end if;
  if public_technical_request then raise exception 'sitaa_public_technical_account_forbidden' using errcode = '42501'; end if;
  if trusted_kind is not null and trusted_kind <> 'technical' then raise exception 'sitaa_unsupported_account_kind' using errcode = '23514'; end if;
  if trusted_kind = 'technical' and is_google then raise exception 'sitaa_ambiguous_account_metadata' using errcode = '23514'; end if;

  if trusted_kind = 'technical' then
    if new.email_confirmed_at is null then raise exception 'sitaa_unverified_technical_email' using errcode = '23514'; end if;
    if char_length(technical_first_names) not between 1 and 150
       or coalesce(char_length(technical_paternal_surname), 0) > 150
       or coalesce(char_length(technical_maternal_surname), 0) > 150
       or char_length(concat_ws(' ', technical_first_names, technical_paternal_surname, technical_maternal_surname)) > 200 then
      raise exception 'sitaa_invalid_structured_name' using errcode = '23514';
    end if;
    insert into public.profiles (id, email, first_names, paternal_surname, maternal_surname, full_name, is_active, account_kind, account_status, activated_at)
    values (new.id, normalized_email, technical_first_names, technical_paternal_surname, technical_maternal_surname,
      concat_ws(' ', technical_first_names, technical_paternal_surname, technical_maternal_surname), true, 'technical', 'active', new.email_confirmed_at);
    return new;
  end if;

  if is_google then
    if char_length(provisional_name) not between 2 and 200 then provisional_name := null; end if;
    insert into public.profiles (id, email, full_name, is_active, account_kind, account_status, person_type, primary_program_id, institutional_id_type, institutional_id_value, activated_at, deactivated_at)
    values (new.id, normalized_email, provisional_name, false, 'institutional', 'pending_registration', null, null, null, null, null, null);
    return new;
  end if;
  if provider = 'email' or coalesce(new.raw_app_meta_data -> 'providers', '[]'::jsonb) ? 'email' then raise exception 'sitaa_public_password_signup_disabled' using errcode = '42501'; end if;
  if provider <> '' then raise exception 'sitaa_unsupported_auth_provider' using errcode = '23514'; end if;
  raise exception 'sitaa_missing_or_invalid_account_metadata' using errcode = '23514';
end;
$$;


--
-- Name: has_active_role(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.has_active_role(required_role text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$

  select public.is_sitaa_operational_account_active() and exists (

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

  select public.is_sitaa_operational_account_active() and exists (

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

  select public.is_sitaa_operational_account_active() and exists (

    select 1

    from public.activity_participants ap

    where ap.activity_id = target_activity_id

      and ap.profile_id = auth.uid()

  );

$$;


--
-- Name: is_b1_account_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_b1_account_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $$
  select exists (
    select 1
    from public.profiles p
    join public.role_assignments ra on ra.user_id = p.id
    where p.id = auth.uid()
      and p.account_status = 'active'
      and p.is_active = true
      and ra.role_code = 'technical_admin'
      and ra.scope_type = 'system'
      and ra.service_area = 'technical'
      and ra.program_id is null
      and ra.division_id is null
      and ra.is_active = true
      and ra.starts_at <= public.sitaa_current_mexico_date()
      and (ra.ends_at is null or ra.ends_at >= public.sitaa_current_mexico_date())
  );
$$;


--
-- Name: is_exact_b1_account_admin_profile_b2b(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_exact_b1_account_admin_profile_b2b(requested_profile_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $$
  select exists (
    select 1
    from public.profiles profile
    join public.role_assignments assignment on assignment.user_id=profile.id
    where profile.id=requested_profile_id
      and profile.account_status='active'
      and profile.is_active=true
      and assignment.role_code='technical_admin'
      and assignment.scope_type='system'
      and assignment.service_area='technical'
      and assignment.program_id is null
      and assignment.division_id is null
      and assignment.is_active=true
      and assignment.starts_at<=public.sitaa_current_mexico_date()
      and (assignment.ends_at is null or assignment.ends_at>=public.sitaa_current_mexico_date())
  );
$$;


--
-- Name: is_sitaa_operational_account_active(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_sitaa_operational_account_active() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $$
  select auth.uid() is not null
     and (
       select count(*)=1
       from public.profiles p
       where p.id=auth.uid()
         and p.account_status='active'
         and p.is_active=true
     );
$$;


--
-- Name: normalize_sitaa_profile_names(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_sitaa_profile_names() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $$
begin
  new.first_names := nullif(regexp_replace(btrim(coalesce(new.first_names, '')), '\s+', ' ', 'g'), '');
  new.paternal_surname := nullif(regexp_replace(btrim(coalesce(new.paternal_surname, '')), '\s+', ' ', 'g'), '');
  new.maternal_surname := nullif(regexp_replace(btrim(coalesce(new.maternal_surname, '')), '\s+', ' ', 'g'), '');

  if new.first_names is not null then
    new.full_name := concat_ws(' ', new.first_names, new.paternal_surname, new.maternal_surname);
  end if;
  return new;
end;
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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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
-- Name: prevent_admin_audit_event_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_admin_audit_event_mutation() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $$
begin
  raise exception 'sitaa_admin_audit_is_append_only' using errcode = '55000';
end;
$$;


--
-- Name: publish_activity(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publish_activity(target_activity_id uuid) RETURNS TABLE(activity_id uuid, status_code text, academic_period_id uuid, semester_label text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$

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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
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

    raise exception 'No tienes permiso para quitar participantes de esta actividad.'

      using errcode = '42501';

  end if;



  delete from public.activity_participants

  where id = target_participant_id;

end;

$$;


--
-- Name: search_admin_accounts_b1(text, uuid, text, text, text, text, text, text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_admin_accounts_b1(search_text text DEFAULT NULL::text, program_filter uuid DEFAULT NULL::uuid, account_kind_filter text DEFAULT NULL::text, account_status_filter text DEFAULT NULL::text, person_type_filter text DEFAULT NULL::text, role_code_filter text DEFAULT NULL::text, service_area_filter text DEFAULT NULL::text, scope_type_filter text DEFAULT NULL::text, page_number integer DEFAULT 1, page_size integer DEFAULT 20) RETURNS TABLE(profile_id uuid, first_names text, paternal_surname text, maternal_surname text, full_name text, email text, account_kind text, account_status text, person_type text, primary_program_id uuid, primary_program_name text, institutional_id_type text, masked_institutional_id text, current_assignment_count bigint, total_count bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'extensions'
    AS $$
declare
  normalized_query text := nullif(regexp_replace(btrim(search_text), '\s+', ' ', 'g'), '');
  escaped_query text;
  search_pattern text;
  calculated_offset bigint;
begin
  if not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode = '42501';
  end if;
  if normalized_query is not null and (char_length(normalized_query) < 2 or char_length(normalized_query) > 200) then
    raise exception 'sitaa_admin_invalid_search_length' using errcode = '22023';
  end if;
  if page_number is null or page_number < 1 or page_number > 1000000
     or page_size is null or page_size < 1 or page_size > 50 then
    raise exception 'sitaa_admin_invalid_pagination' using errcode = '22023';
  end if;
  calculated_offset := (page_number::bigint - 1) * page_size::bigint;
  if account_kind_filter is not null and account_kind_filter not in ('institutional','technical')
     or account_status_filter is not null and account_status_filter not in ('pending_registration','active','inactive')
     or person_type_filter is not null and person_type_filter not in ('student','professor')
     or service_area_filter is not null and service_area_filter not in ('tutoring','advising','both','logistics','technical')
     or scope_type_filter is not null and scope_type_filter not in ('own','program','division','system') then
    raise exception 'sitaa_admin_invalid_filter' using errcode = '22023';
  end if;
  if program_filter is not null and not exists (select 1 from public.academic_programs ap where ap.id = program_filter)
     or role_code_filter is not null and not exists (select 1 from public.roles r where r.code = role_code_filter) then
    raise exception 'sitaa_admin_unknown_filter' using errcode = '22023';
  end if;

  if normalized_query is null and program_filter is null and account_kind_filter is null
     and account_status_filter is null and person_type_filter is null and role_code_filter is null
     and service_area_filter is null and scope_type_filter is null then
    return;
  end if;

  if normalized_query is not null then
    escaped_query := replace(normalized_query, E'\\', E'\\\\');
    escaped_query := replace(escaped_query, '%', E'\\%');
    escaped_query := replace(escaped_query, '_', E'\\_');
    search_pattern := '%' || extensions.unaccent(lower(escaped_query)) || '%';
  end if;

  return query
  select p.id, p.first_names, p.paternal_surname, p.maternal_surname,
    p.full_name, p.email, p.account_kind, p.account_status, p.person_type,
    p.primary_program_id, ap.name, p.institutional_id_type,
    case
      when p.institutional_id_value is null then null
      when char_length(p.institutional_id_value) <= 4 then repeat('•', char_length(p.institutional_id_value))
      else repeat('•', char_length(p.institutional_id_value) - 4) || right(p.institutional_id_value, 4)
    end,
    (
      select count(*) from public.role_assignments current_ra
      where current_ra.user_id = p.id and current_ra.is_active = true
        and current_ra.starts_at <= public.sitaa_current_mexico_date()
        and (current_ra.ends_at is null or current_ra.ends_at >= public.sitaa_current_mexico_date())
    ),
    count(*) over()
  from public.profiles p
  left join public.academic_programs ap on ap.id = p.primary_program_id
  where (program_filter is null or p.primary_program_id = program_filter)
    and (account_kind_filter is null or p.account_kind = account_kind_filter)
    and (account_status_filter is null or p.account_status = account_status_filter)
    and (person_type_filter is null or p.person_type = person_type_filter)
    and (
      normalized_query is null
      or extensions.unaccent(lower(concat_ws(' ', p.first_names, p.paternal_surname, p.maternal_surname, p.full_name))) like search_pattern escape E'\\'
      or lower(p.email) like search_pattern escape E'\\'
      or p.institutional_id_value like search_pattern escape E'\\'
    )
    and (
      (role_code_filter is null and service_area_filter is null and scope_type_filter is null)
      or exists (
        select 1 from public.role_assignments filtered_ra
        where filtered_ra.user_id = p.id and filtered_ra.is_active = true
          and filtered_ra.starts_at <= public.sitaa_current_mexico_date()
          and (filtered_ra.ends_at is null or filtered_ra.ends_at >= public.sitaa_current_mexico_date())
          and (role_code_filter is null or filtered_ra.role_code = role_code_filter)
          and (service_area_filter is null or filtered_ra.service_area = service_area_filter)
          and (scope_type_filter is null or filtered_ra.scope_type = scope_type_filter)
      )
    )
  order by p.paternal_surname asc nulls last, p.maternal_surname asc nulls last,
    p.first_names asc nulls last, p.id
  limit page_size offset calculated_offset;
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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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
-- Name: sitaa_current_mexico_date(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sitaa_current_mexico_date() RETURNS date
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
  select (current_timestamp at time zone 'America/Mexico_City')::date;
$$;


--
-- Name: sync_sitaa_profile_email_from_auth(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_sitaa_profile_email_from_auth() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'auth'
    AS $$
declare normalized_email text := lower(btrim(coalesce(new.email, '')));
begin
  if normalized_email = '' or char_length(normalized_email) > 254 then
    raise exception 'sitaa_invalid_registration_email' using errcode = '23514';
  end if;
  update public.profiles set email = normalized_email where id = new.id;
  return new;
end;
$$;


--
-- Name: transition_admin_account_lifecycle_b2b(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.transition_admin_account_lifecycle_b2b(requested_profile_id uuid, requested_transition text, transition_reason text) RETURNS TABLE(target_profile_id uuid, audit_event_id uuid, previous_status text, new_status text, changed_fields text[], updated_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $_$
declare
  actor_profile_id uuid:=auth.uid();
  target_profile public.profiles%rowtype;
  normalized_reason text;
  exact_assignment boolean:=false;
  exact_admin_count bigint:=0;
  matching_auth_count bigint:=0;
  auth_confirmed boolean:=false;
  identity_valid boolean:=false;
  locked_program_active boolean:=null;
  event_id uuid;
  persisted_updated_at timestamptz;
  prior_status text;
  resulting_status text;
  changed text[]:=array['account_status','deactivated_at','is_active']::text[];
begin
  if actor_profile_id is null or not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode='42501';
  end if;
  if requested_transition is null or requested_transition not in ('deactivate','reactivate') then
    raise exception 'sitaa_account_lifecycle_invalid_transition' using errcode='22023';
  end if;
  normalized_reason:=nullif(btrim(regexp_replace(coalesce(transition_reason,''),'\s+',' ','g')),'');
  if normalized_reason is null or char_length(normalized_reason)<10 or char_length(normalized_reason)>1000 then
    raise exception 'sitaa_account_lifecycle_invalid_reason' using errcode='22023';
  end if;
  if actor_profile_id=requested_profile_id then
    raise exception 'sitaa_account_lifecycle_self_forbidden' using errcode='42501';
  end if;

  perform pg_advisory_xact_lock(1397310529,9002);
  lock table public.role_assignments in share mode;

  -- El usuario Auth objetivo se bloquea antes de cualquier perfil.
  perform 1
  from auth.users auth_user
  where auth_user.id=requested_profile_id
  for update;

  -- Actor, objetivo y candidatos B.1 exactos se bloquean juntos por UUID.
  perform 1
  from public.profiles profile
  where profile.id in (actor_profile_id,requested_profile_id)
     or exists (
       select 1 from public.role_assignments assignment
       where assignment.user_id=profile.id
         and assignment.role_code='technical_admin'
         and assignment.scope_type='system'
         and assignment.service_area='technical'
         and assignment.program_id is null
         and assignment.division_id is null
         and assignment.is_active=true
         and assignment.starts_at<=public.sitaa_current_mexico_date()
         and (assignment.ends_at is null or assignment.ends_at>=public.sitaa_current_mexico_date())
     )
  order by profile.id
  for update;

  if not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode='42501';
  end if;

  select profile.* into target_profile
  from public.profiles profile
  where profile.id=requested_profile_id;
  if target_profile.id is null then
    raise exception 'sitaa_account_lifecycle_target_unavailable' using errcode='P0001';
  end if;
  if target_profile.account_status='pending_registration' then
    raise exception 'sitaa_account_lifecycle_pending_target' using errcode='P0001';
  end if;

  if requested_transition='deactivate' and not (
    target_profile.account_status='active' and target_profile.is_active=true
    and target_profile.activated_at is not null and target_profile.deactivated_at is null
  ) or requested_transition='reactivate' and not (
    target_profile.account_status='inactive' and target_profile.is_active=false
    and target_profile.activated_at is not null and target_profile.deactivated_at is not null
  ) then
    raise exception 'sitaa_account_lifecycle_state_conflict' using errcode='55000';
  end if;

  select public.is_exact_b1_account_admin_profile_b2b(target_profile.id)
    into exact_assignment;
  select count(distinct profile.id) into exact_admin_count
  from public.profiles profile
  where public.is_exact_b1_account_admin_profile_b2b(profile.id);
  if requested_transition='deactivate' and exact_assignment and exact_admin_count<=1 then
    raise exception 'sitaa_account_lifecycle_last_admin_forbidden' using errcode='55000';
  end if;

  if requested_transition='reactivate' then
    -- La decisión institucional usa la fila bloqueada, no una lectura no protegida.
    if target_profile.account_kind='institutional' then
      select program.is_active into locked_program_active
      from public.academic_programs program
      where program.id=target_profile.primary_program_id
      for share;
      if locked_program_active is distinct from true then
        raise exception 'sitaa_account_lifecycle_invalid_identity' using errcode='23514';
      end if;
    end if;

    select count(*),coalesce(bool_or(
      auth_user.email_confirmed_at is not null or exists (
        select 1 from auth.identities identity_row
        where identity_row.user_id=auth_user.id
          and identity_row.provider='google'
          and lower(btrim(identity_row.identity_data->>'email'))=lower(btrim(auth_user.email))
          and lower(btrim(coalesce(identity_row.identity_data->>'email_verified',''))) in ('true','t','1')
      )
    ),false)
    into matching_auth_count,auth_confirmed
    from auth.users auth_user
    where auth_user.id=target_profile.id
      and lower(btrim(auth_user.email))=target_profile.email;

    identity_valid:=target_profile.email=lower(btrim(target_profile.email)) and (
        target_profile.account_kind='institutional'
        and target_profile.person_type in ('student','professor')
        and target_profile.first_names is not null
        and target_profile.paternal_surname is not null
        and target_profile.full_name is not null
        and char_length(target_profile.first_names) between 1 and 150
        and target_profile.first_names=regexp_replace(btrim(target_profile.first_names),'\s+',' ','g')
        and char_length(target_profile.paternal_surname) between 1 and 150
        and target_profile.paternal_surname=regexp_replace(btrim(target_profile.paternal_surname),'\s+',' ','g')
        and (target_profile.maternal_surname is null or char_length(target_profile.maternal_surname) between 1 and 150 and target_profile.maternal_surname=regexp_replace(btrim(target_profile.maternal_surname),'\s+',' ','g'))
        and char_length(target_profile.full_name) between 2 and 200
        and target_profile.full_name=concat_ws(' ',target_profile.first_names,target_profile.paternal_surname,target_profile.maternal_surname)
        and target_profile.primary_program_id is not null
        and locked_program_active is true
        and target_profile.institutional_id_value~'^[0-9]{1,50}$'
        and target_profile.institutional_id_type=case when target_profile.person_type='student' then 'student_account' else 'worker_number' end
        or target_profile.account_kind='technical'
        and target_profile.first_names is not null
        and target_profile.full_name is not null
        and char_length(target_profile.first_names) between 1 and 150
        and target_profile.first_names=regexp_replace(btrim(target_profile.first_names),'\s+',' ','g')
        and (target_profile.paternal_surname is null or char_length(target_profile.paternal_surname) between 1 and 150 and target_profile.paternal_surname=regexp_replace(btrim(target_profile.paternal_surname),'\s+',' ','g'))
        and (target_profile.maternal_surname is null or char_length(target_profile.maternal_surname) between 1 and 150 and target_profile.maternal_surname=regexp_replace(btrim(target_profile.maternal_surname),'\s+',' ','g'))
        and char_length(target_profile.full_name) between 2 and 200
        and target_profile.full_name=concat_ws(' ',target_profile.first_names,target_profile.paternal_surname,target_profile.maternal_surname)
        and target_profile.person_type is null
        and target_profile.primary_program_id is null
        and target_profile.institutional_id_type is null
        and target_profile.institutional_id_value is null
      );
    if not identity_valid then
      raise exception 'sitaa_account_lifecycle_invalid_identity' using errcode='23514';
    end if;
    if matching_auth_count<>1 or not auth_confirmed then
      raise exception 'sitaa_account_lifecycle_auth_unconfirmed' using errcode='42501';
    end if;
  end if;

  prior_status:=target_profile.account_status;
  if requested_transition='deactivate' then
    update public.profiles profile
    set account_status='inactive',is_active=false,deactivated_at=now(),updated_at=now()
    where profile.id=target_profile.id
    returning profile.account_status,profile.updated_at into resulting_status,persisted_updated_at;
  else
    update public.profiles profile
    set account_status='active',is_active=true,deactivated_at=null,updated_at=now()
    where profile.id=target_profile.id
    returning profile.account_status,profile.updated_at into resulting_status,persisted_updated_at;
  end if;

  insert into public.admin_audit_events(
    actor_profile_id,target_profile_id,action_code,outcome,reason,
    role_assignment_id,metadata
  ) values (
    actor_profile_id,target_profile.id,
    case when requested_transition='deactivate' then 'account_deactivated' else 'account_reactivated' end,
    'success',normalized_reason,null,
    jsonb_build_object('changed_fields',to_jsonb(changed))
  ) returning id into event_id;

  return query select target_profile.id,event_id,prior_status,resulting_status,
    changed,persisted_updated_at;
end;
$_$;


--
-- Name: update_activity_participant_attendance(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_activity_participant_attendance(target_participant_id uuid, new_attendance_status text, new_attendance_notes text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$

declare

  target_activity_id uuid;

  natural_deadline timestamptz;

begin
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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

    if natural_deadline is null or natural_deadline <= now() then

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


--
-- Name: update_activity_participants_attendance_bulk(uuid, uuid[], text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_activity_participants_attendance_bulk(target_activity_id uuid, target_participant_ids uuid[], new_attendance_status text, new_attendance_notes text DEFAULT NULL::text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$

declare

  updated_count integer;

  natural_deadline timestamptz;

begin
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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

    if natural_deadline is null or natural_deadline <= now() then

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


--
-- Name: validate_activity_scheduled_state(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_activity_scheduled_state() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
declare
  expected_period_id uuid;
  start_value timestamp;
  end_value timestamp;
  require_future_start boolean := false;
  trusted_database_role boolean := current_user in ('postgres', 'service_role');
begin
  if tg_op = 'UPDATE' and not trusted_database_role then
    if new.created_by is distinct from old.created_by then
      raise exception 'No se puede cambiar el creador de una actividad.'
        using errcode = '23514';
    end if;

    if old.status_code <> 'draft' and new.status_code = 'draft' then
      raise exception 'Una actividad publicada no puede volver a borrador.'
        using errcode = '23514';
    end if;

    if old.status_code = 'draft' and new.status_code = 'scheduled' then
      if auth.uid() is null
         or new.created_by is distinct from auth.uid()
         or public.can_create_activity(
           new.scope_type,
           new.program_id,
           new.division_id,
           new.service_type_code
         ) is distinct from true then
        raise exception 'No tienes permiso para publicar esta actividad.'
          using errcode = '42501';
      end if;
    end if;
  end if;

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
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL
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
-- Name: admin_audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_audit_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_profile_id uuid NOT NULL,
    target_profile_id uuid NOT NULL,
    action_code text NOT NULL,
    outcome text NOT NULL,
    reason text,
    role_assignment_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT admin_audit_events_action_code_check CHECK ((((char_length(action_code) >= 1) AND (char_length(action_code) <= 100)) AND (action_code ~ '^[a-z][a-z0-9]*(_[a-z0-9]+)*$'::text))),
    CONSTRAINT admin_audit_events_metadata_check CHECK (public.admin_audit_metadata_is_safe(metadata)),
    CONSTRAINT admin_audit_events_outcome_check CHECK ((outcome = ANY (ARRAY['success'::text, 'failure'::text]))),
    CONSTRAINT admin_audit_events_reason_check CHECK (((reason IS NULL) OR ((reason = btrim(reason)) AND ((char_length(reason) >= 1) AND (char_length(reason) <= 1000)))))
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
    is_active boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    first_names text,
    paternal_surname text,
    maternal_surname text,
    person_type text,
    institutional_id_type text,
    institutional_id_value text,
    account_kind text DEFAULT 'institutional'::text NOT NULL,
    account_status text DEFAULT 'pending_registration'::text NOT NULL,
    activated_at timestamp with time zone,
    deactivated_at timestamp with time zone,
    CONSTRAINT profiles_account_identity_check CHECK ((((account_kind = 'institutional'::text) AND (account_status = 'pending_registration'::text) AND (person_type IS NULL) AND (primary_program_id IS NULL) AND (institutional_id_type IS NULL) AND (institutional_id_value IS NULL) AND (first_names IS NULL) AND (paternal_surname IS NULL) AND (maternal_surname IS NULL)) OR ((account_kind = 'institutional'::text) AND (account_status = ANY (ARRAY['active'::text, 'inactive'::text])) AND (person_type = ANY (ARRAY['student'::text, 'professor'::text])) AND (primary_program_id IS NOT NULL) AND (institutional_id_type IS NOT NULL) AND (institutional_id_value IS NOT NULL) AND (first_names IS NOT NULL) AND (paternal_surname IS NOT NULL) AND (full_name IS NOT NULL) AND (((person_type = 'student'::text) AND (institutional_id_type = 'student_account'::text)) OR ((person_type = 'professor'::text) AND (institutional_id_type = 'worker_number'::text)))) OR ((account_kind = 'technical'::text) AND (account_status = ANY (ARRAY['active'::text, 'inactive'::text])) AND (person_type IS NULL) AND (primary_program_id IS NULL) AND (institutional_id_type IS NULL) AND (institutional_id_value IS NULL) AND (first_names IS NOT NULL) AND (full_name IS NOT NULL)))),
    CONSTRAINT profiles_account_kind_check CHECK ((account_kind = ANY (ARRAY['institutional'::text, 'technical'::text]))),
    CONSTRAINT profiles_account_lifecycle_check CHECK ((((account_status = 'active'::text) AND is_active AND (activated_at IS NOT NULL) AND (deactivated_at IS NULL)) OR ((account_status = 'pending_registration'::text) AND (NOT is_active) AND (activated_at IS NULL) AND (deactivated_at IS NULL)) OR ((account_status = 'inactive'::text) AND (NOT is_active) AND (deactivated_at IS NOT NULL)))),
    CONSTRAINT profiles_account_status_check CHECK ((account_status = ANY (ARRAY['pending_registration'::text, 'active'::text, 'inactive'::text]))),
    CONSTRAINT profiles_email_check CHECK ((((char_length(email) >= 1) AND (char_length(email) <= 254)) AND (email = lower(btrim(email))))),
    CONSTRAINT profiles_first_names_check CHECK (((first_names IS NULL) OR (((char_length(first_names) >= 1) AND (char_length(first_names) <= 150)) AND (first_names = regexp_replace(btrim(first_names), '\s+'::text, ' '::text, 'g'::text))))),
    CONSTRAINT profiles_full_name_check CHECK (((full_name IS NULL) OR (((char_length(full_name) >= 2) AND (char_length(full_name) <= 200)) AND (full_name = regexp_replace(btrim(full_name), '\s+'::text, ' '::text, 'g'::text))))),
    CONSTRAINT profiles_identifier_digits_check CHECK (((institutional_id_value IS NULL) OR (institutional_id_value ~ '^[0-9]+$'::text))),
    CONSTRAINT profiles_identifier_length_check CHECK (((institutional_id_value IS NULL) OR ((char_length(institutional_id_value) >= 1) AND (char_length(institutional_id_value) <= 50)))),
    CONSTRAINT profiles_institutional_id_type_check CHECK (((institutional_id_type IS NULL) OR (institutional_id_type = ANY (ARRAY['student_account'::text, 'worker_number'::text])))),
    CONSTRAINT profiles_maternal_surname_check CHECK (((maternal_surname IS NULL) OR (((char_length(maternal_surname) >= 1) AND (char_length(maternal_surname) <= 150)) AND (maternal_surname = regexp_replace(btrim(maternal_surname), '\s+'::text, ' '::text, 'g'::text))))),
    CONSTRAINT profiles_paternal_surname_check CHECK (((paternal_surname IS NULL) OR (((char_length(paternal_surname) >= 1) AND (char_length(paternal_surname) <= 150)) AND (paternal_surname = regexp_replace(btrim(paternal_surname), '\s+'::text, ' '::text, 'g'::text))))),
    CONSTRAINT profiles_person_type_check CHECK (((person_type IS NULL) OR (person_type = ANY (ARRAY['student'::text, 'professor'::text])))),
    CONSTRAINT profiles_structured_full_name_check CHECK (((first_names IS NULL) OR (full_name = concat_ws(' '::text, first_names, paternal_surname, maternal_surname))))
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
-- Name: admin_audit_events admin_audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_audit_events
    ADD CONSTRAINT admin_audit_events_pkey PRIMARY KEY (id);


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
-- Name: admin_audit_events_actor_occurred_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX admin_audit_events_actor_occurred_idx ON public.admin_audit_events USING btree (actor_profile_id, occurred_at DESC, id DESC);


--
-- Name: admin_audit_events_target_occurred_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX admin_audit_events_target_occurred_idx ON public.admin_audit_events USING btree (target_profile_id, occurred_at DESC, id DESC);


--
-- Name: profiles_admin_directory_filters_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX profiles_admin_directory_filters_idx ON public.profiles USING btree (account_status, account_kind, person_type, primary_program_id);


--
-- Name: profiles_admin_directory_sort_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX profiles_admin_directory_sort_idx ON public.profiles USING btree (paternal_surname, maternal_surname, first_names, id);


--
-- Name: profiles_institutional_identifier_pair_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX profiles_institutional_identifier_pair_key ON public.profiles USING btree (institutional_id_type, institutional_id_value) WHERE ((account_kind = 'institutional'::text) AND (institutional_id_value IS NOT NULL));


--
-- Name: activities enforce_activity_writer_integrity_b2a; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER enforce_activity_writer_integrity_b2a BEFORE INSERT OR UPDATE ON public.activities FOR EACH ROW EXECUTE FUNCTION public.enforce_activity_writer_integrity_b2a();


--
-- Name: profiles enforce_sitaa_profile_identity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER enforce_sitaa_profile_identity BEFORE INSERT OR UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.enforce_sitaa_profile_identity();


--
-- Name: activity_participants guard_activity_participants_pending_deadline; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER guard_activity_participants_pending_deadline BEFORE UPDATE OF attendance_status ON public.activity_participants FOR EACH ROW EXECUTE FUNCTION public.guard_activity_participant_pending_deadline();


--
-- Name: profiles normalize_sitaa_profile_names; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER normalize_sitaa_profile_names BEFORE INSERT OR UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.normalize_sitaa_profile_names();


--
-- Name: admin_audit_events prevent_admin_audit_event_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER prevent_admin_audit_event_mutation BEFORE DELETE OR UPDATE ON public.admin_audit_events FOR EACH ROW EXECUTE FUNCTION public.prevent_admin_audit_event_mutation();


--
-- Name: admin_audit_events prevent_admin_audit_event_truncate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER prevent_admin_audit_event_truncate BEFORE TRUNCATE ON public.admin_audit_events FOR EACH STATEMENT EXECUTE FUNCTION public.prevent_admin_audit_event_mutation();


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
-- Name: activities validate_activities_scheduled_state; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER validate_activities_scheduled_state BEFORE INSERT OR UPDATE ON public.activities FOR EACH ROW EXECUTE FUNCTION public.validate_activity_scheduled_state();


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
-- Name: admin_audit_events admin_audit_events_actor_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_audit_events
    ADD CONSTRAINT admin_audit_events_actor_profile_id_fkey FOREIGN KEY (actor_profile_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: admin_audit_events admin_audit_events_role_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_audit_events
    ADD CONSTRAINT admin_audit_events_role_assignment_id_fkey FOREIGN KEY (role_assignment_id) REFERENCES public.role_assignments(id) ON DELETE RESTRICT;


--
-- Name: admin_audit_events admin_audit_events_target_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_audit_events
    ADD CONSTRAINT admin_audit_events_target_profile_id_fkey FOREIGN KEY (target_profile_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


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
-- Name: activities Active accounts may operate activities; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Active accounts may operate activities" ON public.activities AS RESTRICTIVE TO authenticated USING (public.is_sitaa_operational_account_active()) WITH CHECK (public.is_sitaa_operational_account_active());


--
-- Name: activity_participants Active accounts may operate activity participants; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Active accounts may operate activity participants" ON public.activity_participants AS RESTRICTIVE TO authenticated USING (public.is_sitaa_operational_account_active()) WITH CHECK (public.is_sitaa_operational_account_active());


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

CREATE POLICY "Users can read permitted activities" ON public.activities FOR SELECT TO authenticated USING ((((status_code = 'draft'::text) AND (created_by = auth.uid())) OR ((status_code <> 'draft'::text) AND ((created_by = auth.uid()) OR (responsible_profile_id = auth.uid()) OR public.is_activity_participant(id) OR public.can_manage_activity(scope_type, program_id, division_id, service_type_code)))));


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
-- Name: admin_audit_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.admin_audit_events ENABLE ROW LEVEL SECURITY;

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

--
-- PostgreSQL database dump complete
--

\unrestrict TFu9SdP2ivvyvRgZ0S6vaShbGis4sJSB5sIzUroXZuB7M7BZMiOJSTYV3zcjQ3p

