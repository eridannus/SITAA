-- signature	identity_arguments	arguments	definition
activity_attendance_deadline(uuid)	target_activity_id uuid	target_activity_id uuid	CREATE OR REPLACE FUNCTION public.activity_attendance_deadline(target_activity_id uuid)
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

activity_attendance_open_at(uuid)	target_activity_id uuid	target_activity_id uuid	CREATE OR REPLACE FUNCTION public.activity_attendance_open_at(target_activity_id uuid)
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

activity_has_ended(uuid)	target_activity_id uuid	target_activity_id uuid	CREATE OR REPLACE FUNCTION public.activity_has_ended(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  where a.id = target_activity_id;
$function$

add_activity_participant(uuid,uuid,text)	target_activity_id uuid, target_profile_id uuid, target_participant_role_code text	target_activity_id uuid, target_profile_id uuid, target_participant_role_code text	CREATE OR REPLACE FUNCTION public.add_activity_participant(target_activity_id uuid, target_profile_id uuid, target_participant_role_code text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  target_program_id uuid;
  participant_program_id uuid;
  participant_person_type text;
begin
  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para agregar participantes a esta actividad.' using errcode = '42501';
  end if;
  select a.program_id into target_program_id from public.activities a where a.id = target_activity_id;
  if target_program_id is null then
    raise exception 'La actividad no tiene programa académico asignado.' using errcode = 'P0001';
  end if;
  select p.primary_program_id, p.person_type into participant_program_id, participant_person_type
  from public.profiles p where p.id = target_profile_id and p.is_active = true;
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
$function$

can_create_activity(text,uuid,uuid,text)	target_scope_type text, target_program_id uuid, target_division_id uuid, target_service_type_code text	target_scope_type text, target_program_id uuid, target_division_id uuid, target_service_type_code text	CREATE OR REPLACE FUNCTION public.can_create_activity(target_scope_type text, target_program_id uuid, target_division_id uuid, target_service_type_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

can_create_activity(uuid,text)	target_program_id uuid, target_service_type_code text	target_program_id uuid, target_service_type_code text	CREATE OR REPLACE FUNCTION public.can_create_activity(target_program_id uuid, target_service_type_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

can_delete_activity(uuid)	target_activity_id uuid	target_activity_id uuid	CREATE OR REPLACE FUNCTION public.can_delete_activity(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
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
$function$

can_edit_activity(uuid)	target_activity_id uuid	target_activity_id uuid	CREATE OR REPLACE FUNCTION public.can_edit_activity(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

can_manage_activity(text,uuid,uuid,text)	target_scope_type text, target_program_id uuid, target_division_id uuid, target_service_type_code text	target_scope_type text, target_program_id uuid, target_division_id uuid, target_service_type_code text	CREATE OR REPLACE FUNCTION public.can_manage_activity(target_scope_type text, target_program_id uuid, target_division_id uuid, target_service_type_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

can_manage_activity(uuid,text)	target_program_id uuid, target_service_type_code text	target_program_id uuid, target_service_type_code text	CREATE OR REPLACE FUNCTION public.can_manage_activity(target_program_id uuid, target_service_type_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

can_read_activity(uuid)	target_activity_id uuid	target_activity_id uuid	CREATE OR REPLACE FUNCTION public.can_read_activity(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

can_update_activity_base(uuid)	target_activity_id uuid	target_activity_id uuid	CREATE OR REPLACE FUNCTION public.can_update_activity_base(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
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
$function$

check_in_activity(text)	checkin_input text	checkin_input text	CREATE OR REPLACE FUNCTION public.check_in_activity(checkin_input text)
 RETURNS TABLE(activity_id uuid, activity_title text, attendance_status text, checked_in_at timestamp with time zone, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

close_activity_attendance_checkin(uuid)	target_activity_id uuid	target_activity_id uuid	CREATE OR REPLACE FUNCTION public.close_activity_attendance_checkin(target_activity_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

complete_own_google_registration(text,text,text,text,text,uuid)	requested_person_type text, requested_first_names text, requested_paternal_surname text, requested_maternal_surname text, requested_institutional_id_value text, requested_primary_program_id uuid	requested_person_type text, requested_first_names text, requested_paternal_surname text, requested_maternal_surname text, requested_institutional_id_value text, requested_primary_program_id uuid	CREATE OR REPLACE FUNCTION public.complete_own_google_registration(requested_person_type text, requested_first_names text, requested_paternal_surname text, requested_maternal_surname text, requested_institutional_id_value text, requested_primary_program_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
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
$function$

complete_own_google_registration(text,text,text,uuid)	requested_person_type text, requested_full_name text, requested_institutional_id_value text, requested_primary_program_id uuid	requested_person_type text, requested_full_name text, requested_institutional_id_value text, requested_primary_program_id uuid	CREATE OR REPLACE FUNCTION public.complete_own_google_registration(requested_person_type text, requested_full_name text, requested_institutional_id_value text, requested_primary_program_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
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
$function$

enforce_sitaa_profile_identity()			CREATE OR REPLACE FUNCTION public.enforce_sitaa_profile_identity()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
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
$function$

finalize_expired_attendance()			CREATE OR REPLACE FUNCTION public.finalize_expired_attendance()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

generate_three_word_code()			CREATE OR REPLACE FUNCTION public.generate_three_word_code()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

get_academic_period_for_date(date)	target_date date	target_date date	CREATE OR REPLACE FUNCTION public.get_academic_period_for_date(target_date date)
 RETURNS TABLE(id uuid, code text, name text, starts_on date, ends_on date)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

get_active_activity_attendance_checkin(uuid)	target_activity_id uuid	target_activity_id uuid	CREATE OR REPLACE FUNCTION public.get_active_activity_attendance_checkin(target_activity_id uuid)
 RETURNS TABLE(id uuid, activity_id uuid, code_words text, secret_token text, opened_at timestamp with time zone, expires_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

get_activity_attendance_checkin_state(uuid)	target_activity_id uuid	target_activity_id uuid	CREATE OR REPLACE FUNCTION public.get_activity_attendance_checkin_state(target_activity_id uuid)
 RETURNS TABLE(can_manage boolean, is_draft boolean, has_schedule boolean, has_active_token boolean, can_open_now boolean, window_status text, opens_at timestamp with time zone, ordinary_closes_at timestamp with time zone, active_expires_at timestamp with time zone, message text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

get_activity_participants(uuid)	target_activity_id uuid	target_activity_id uuid	CREATE OR REPLACE FUNCTION public.get_activity_participants(target_activity_id uuid)
 RETURNS TABLE(id uuid, activity_id uuid, profile_id uuid, participant_role_code text, participant_role_label text, full_name text, email text, person_type text, institutional_id_type text, institutional_id_value text, program_name text, attendance_status text, attendance_source text, checked_in_at timestamp with time zone, attendance_updated_at timestamp with time zone, attendance_notes text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

get_visible_activity_cards()			CREATE OR REPLACE FUNCTION public.get_visible_activity_cards()
 RETURNS TABLE(id uuid, title text, description text, activity_type_label text, service_type_label text, service_type_code text, modality_label text, status_label text, status_code text, semester_label text, program_label text, location_type_label text, location_detail text, start_date date, start_time time without time zone, end_date date, end_time time without time zone, duration_mode text, responsible_full_name text, viewer_can_edit boolean, viewer_is_participant boolean, viewer_attendance_status text, viewer_attendance_source text, viewer_checked_in_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

guard_activity_participant_pending_deadline()			CREATE OR REPLACE FUNCTION public.guard_activity_participant_pending_deadline()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
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
$function$

handle_sitaa_auth_user_created()			CREATE OR REPLACE FUNCTION public.handle_sitaa_auth_user_created()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
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
$function$

has_active_role(text)	required_role text	required_role text	CREATE OR REPLACE FUNCTION public.has_active_role(required_role text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.role_assignments ra
    where ra.user_id = auth.uid()
      and ra.role_code = required_role
      and ra.is_active = true
      and ra.starts_at <= current_date
      and (ra.ends_at is null or ra.ends_at >= current_date)
  );
$function$

has_any_active_role(text[])	required_roles text[]	required_roles text[]	CREATE OR REPLACE FUNCTION public.has_any_active_role(required_roles text[])
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.role_assignments ra
    where ra.user_id = auth.uid()
      and ra.role_code = any(required_roles)
      and ra.is_active = true
      and ra.starts_at <= current_date
      and (ra.ends_at is null or ra.ends_at >= current_date)
  );
$function$

is_activity_participant(uuid)	target_activity_id uuid	target_activity_id uuid	CREATE OR REPLACE FUNCTION public.is_activity_participant(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.activity_participants ap
    where ap.activity_id = target_activity_id
      and ap.profile_id = auth.uid()
  );
$function$

normalize_sitaa_profile_names()			CREATE OR REPLACE FUNCTION public.normalize_sitaa_profile_names()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
  new.first_names := nullif(regexp_replace(btrim(coalesce(new.first_names, '')), '\s+', ' ', 'g'), '');
  new.paternal_surname := nullif(regexp_replace(btrim(coalesce(new.paternal_surname, '')), '\s+', ' ', 'g'), '');
  new.maternal_surname := nullif(regexp_replace(btrim(coalesce(new.maternal_surname, '')), '\s+', ' ', 'g'), '');

  if new.first_names is not null then
    new.full_name := concat_ws(' ', new.first_names, new.paternal_surname, new.maternal_surname);
  end if;
  return new;
end;
$function$

open_activity_attendance_checkin(uuid)	target_activity_id uuid	target_activity_id uuid	CREATE OR REPLACE FUNCTION public.open_activity_attendance_checkin(target_activity_id uuid)
 RETURNS TABLE(id uuid, activity_id uuid, code_words text, secret_token text, opened_at timestamp with time zone, expires_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

publish_activity(uuid)	target_activity_id uuid	target_activity_id uuid	CREATE OR REPLACE FUNCTION public.publish_activity(target_activity_id uuid)
 RETURNS TABLE(activity_id uuid, status_code text, academic_period_id uuid, semester_label text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

remove_activity_participant(uuid)	target_participant_id uuid	target_participant_id uuid	CREATE OR REPLACE FUNCTION public.remove_activity_participant(target_participant_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

search_profiles_for_participation(uuid,text)	target_activity_id uuid, search_text text	target_activity_id uuid, search_text text	CREATE OR REPLACE FUNCTION public.search_profiles_for_participation(target_activity_id uuid, search_text text)
 RETURNS TABLE(id uuid, full_name text, email text, person_type text, institutional_id_type text, institutional_id_value text, primary_program_id uuid, program_name text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

set_updated_at()			CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$

sync_sitaa_profile_email_from_auth()			CREATE OR REPLACE FUNCTION public.sync_sitaa_profile_email_from_auth()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
declare normalized_email text := lower(btrim(coalesce(new.email, '')));
begin
  if normalized_email = '' or char_length(normalized_email) > 254 then
    raise exception 'sitaa_invalid_registration_email' using errcode = '23514';
  end if;
  update public.profiles set email = normalized_email where id = new.id;
  return new;
end;
$function$

update_activity_participant_attendance(uuid,text,text)	target_participant_id uuid, new_attendance_status text, new_attendance_notes text	target_participant_id uuid, new_attendance_status text, new_attendance_notes text DEFAULT NULL::text	CREATE OR REPLACE FUNCTION public.update_activity_participant_attendance(target_participant_id uuid, new_attendance_status text, new_attendance_notes text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

update_activity_participants_attendance_bulk(uuid,uuid[],text,text)	target_activity_id uuid, target_participant_ids uuid[], new_attendance_status text, new_attendance_notes text	target_activity_id uuid, target_participant_ids uuid[], new_attendance_status text, new_attendance_notes text DEFAULT NULL::text	CREATE OR REPLACE FUNCTION public.update_activity_participants_attendance_bulk(target_activity_id uuid, target_participant_ids uuid[], new_attendance_status text, new_attendance_notes text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$

validate_activity_scheduled_state()			CREATE OR REPLACE FUNCTION public.validate_activity_scheduled_state()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
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
$function$

