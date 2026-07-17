-- Rollback manual de emergencia para SITAA 0005.
-- Restaura las funciones post-0004 sin transformar datos. Al hacerlo también
-- restaura la validación prematura de email_confirmed_at que bloquea Google.

begin;

do $operator_review$
begin
  if current_setting('sitaa.rollback_0005_reviewed', true) is distinct from 'yes' then
    raise exception 'Rollback 0005 detenido: falta revisión explícita del operador.';
  end if;
end;
$operator_review$;

create or replace function public.handle_sitaa_auth_user_created()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  normalized_email text := lower(btrim(coalesce(new.email, '')));
  trusted_kind text := new.raw_app_meta_data ->> 'sitaa_account_kind';
  provider text := lower(coalesce(new.raw_app_meta_data ->> 'provider', ''));
  is_google boolean := provider = 'google'
    or coalesce(new.raw_app_meta_data -> 'providers', '[]'::jsonb) ? 'google';
  public_technical_request boolean :=
    new.raw_user_meta_data ? 'sitaa_account_kind'
    or new.raw_user_meta_data ->> 'sitaa_registration_type' = 'technical';
  provisional_name text := regexp_replace(
    btrim(coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', '')),
    '\s+', ' ', 'g'
  );
  technical_name text;
begin
  if normalized_email = '' or char_length(normalized_email) > 254 then
    raise exception 'sitaa_invalid_registration_email' using errcode = '23514';
  end if;
  if public_technical_request then
    raise exception 'sitaa_public_technical_account_forbidden' using errcode = '42501';
  end if;
  if trusted_kind is not null and trusted_kind <> 'technical' then
    raise exception 'sitaa_unsupported_account_kind' using errcode = '23514';
  end if;
  if trusted_kind = 'technical' and is_google then
    raise exception 'sitaa_ambiguous_account_metadata' using errcode = '23514';
  end if;

  if trusted_kind = 'technical' then
    technical_name := regexp_replace(
      btrim(coalesce(new.raw_app_meta_data ->> 'sitaa_full_name', '')), '\s+', ' ', 'g'
    );
    if new.email_confirmed_at is null then
      raise exception 'sitaa_unverified_technical_email' using errcode = '23514';
    end if;
    if char_length(technical_name) not between 2 and 200 then
      raise exception 'sitaa_invalid_full_name' using errcode = '23514';
    end if;
    insert into public.profiles (
      id, email, full_name, is_active, account_kind, account_status, activated_at
    ) values (
      new.id, normalized_email, technical_name, true, 'technical', 'active', new.email_confirmed_at
    );
    return new;
  end if;

  if is_google then
    if new.email_confirmed_at is null then
      raise exception 'sitaa_google_email_not_verified' using errcode = '23514';
    end if;
    if char_length(provisional_name) not between 2 and 200 then
      provisional_name := null;
    end if;
    insert into public.profiles (
      id, email, full_name, is_active, account_kind, account_status,
      person_type, primary_program_id, institutional_id_type,
      institutional_id_value, activated_at, deactivated_at
    ) values (
      new.id, normalized_email, provisional_name, false, 'institutional',
      'pending_registration', null, null, null, null, null, null
    );
    return new;
  end if;

  if provider = 'email' or coalesce(new.raw_app_meta_data -> 'providers', '[]'::jsonb) ? 'email' then
    raise exception 'sitaa_public_password_signup_disabled' using errcode = '42501';
  end if;
  if provider <> '' then
    raise exception 'sitaa_unsupported_auth_provider' using errcode = '23514';
  end if;
  raise exception 'sitaa_missing_or_invalid_account_metadata' using errcode = '23514';
end;
$function$;

revoke all on function public.handle_sitaa_auth_user_created() from public, anon, authenticated;

create or replace function public.complete_own_google_registration(
  requested_person_type text,
  requested_full_name text,
  requested_institutional_id_value text,
  requested_primary_program_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  current_user_id uuid := auth.uid();
  target_profile public.profiles%rowtype;
  normalized_name text := regexp_replace(btrim(coalesce(requested_full_name, '')), '\s+', ' ', 'g');
  normalized_identifier text := btrim(coalesce(requested_institutional_id_value, ''));
  identifier_type text;
begin
  if current_user_id is null then
    raise exception 'sitaa_authentication_required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from auth.users u
    where u.id = current_user_id
      and u.email_confirmed_at is not null
      and (
        coalesce(u.raw_app_meta_data -> 'providers', '[]'::jsonb) ? 'google'
        or u.raw_app_meta_data ->> 'provider' = 'google'
        or exists (
          select 1 from auth.identities i
          where i.user_id = u.id and i.provider = 'google'
        )
      )
  ) then
    raise exception 'sitaa_google_identity_required' using errcode = '42501';
  end if;

  select * into target_profile from public.profiles
  where id = current_user_id for update;
  if not found or target_profile.account_kind <> 'institutional'
     or target_profile.account_status <> 'pending_registration' then
    raise exception 'sitaa_registration_not_pending' using errcode = '42501';
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
        activated_at = now(), deactivated_at = null
    where id = current_user_id;
  exception when unique_violation then
    raise exception 'sitaa_identifier_conflict' using errcode = '23505';
  end;
end;
$function$;

revoke all on function public.complete_own_google_registration(text, text, text, uuid)
  from public, anon;
grant execute on function public.complete_own_google_registration(text, text, text, uuid)
  to authenticated;

commit;

-- Este rollback no elimina Auth users, identities o profiles. Debe usarse sólo
-- para restauración urgente del esquema post-0004, pues reintroduce el defecto.
