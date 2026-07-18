-- Rollback de SITAA 0006 al contrato post-0005.
-- Conserva datos y columnas de nombres estructurados ya existentes; no intenta fusionarlos.

begin;

do $guard$
begin
  if to_regprocedure('public.complete_own_google_registration(text,text,text,text,text,uuid)') is null
     or to_regprocedure('public.normalize_sitaa_profile_names()') is null then
    raise exception 'El contrato 0006 no está completo; revisar antes del rollback.' using errcode = 'P0001';
  end if;
end;
$guard$;

drop function public.complete_own_google_registration(text,text,text,text,text,uuid);
grant execute on function public.complete_own_google_registration(text,text,text,uuid) to authenticated;

create or replace function public.enforce_sitaa_profile_identity()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $function$
begin
  if tg_op = 'UPDATE' and current_user = 'authenticated' and auth.uid() = old.id then
    if old.account_status <> 'active' then
      raise exception 'La cuenta debe completar su registro antes de editar el perfil.' using errcode = '42501';
    end if;
    if (to_jsonb(new) - 'full_name' - 'updated_at')
       is distinct from (to_jsonb(old) - 'full_name' - 'updated_at') then
      raise exception 'Sólo puedes actualizar tu nombre completo.' using errcode = '42501';
    end if;
  end if;

  if new.account_kind = 'institutional'
     and new.account_status in ('active', 'inactive')
     and not exists (
       select 1 from public.academic_programs ap
       where ap.id = new.primary_program_id and ap.is_active
     ) then
    raise exception 'El programa académico no existe o está inactivo.' using errcode = '23514';
  end if;

  if new.account_status = 'active' then
    new.is_active := true;
    new.activated_at := coalesce(new.activated_at, now());
    new.deactivated_at := null;
  elsif new.account_status = 'pending_registration' then
    new.is_active := false;
    new.activated_at := null;
    new.deactivated_at := null;
  elsif new.account_status = 'inactive' then
    new.is_active := false;
    new.deactivated_at := coalesce(new.deactivated_at, now());
  end if;
  return new;
end;
$function$;

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
    if char_length(provisional_name) not between 2 and 200 then provisional_name := null; end if;
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
  if provider <> '' then raise exception 'sitaa_unsupported_auth_provider' using errcode = '23514'; end if;
  raise exception 'sitaa_missing_or_invalid_account_metadata' using errcode = '23514';
end;
$function$;

revoke all on function public.handle_sitaa_auth_user_created() from public, anon, authenticated;

alter table public.profiles
  drop constraint profiles_account_identity_check,
  drop constraint profiles_first_names_check,
  drop constraint profiles_paternal_surname_check,
  drop constraint profiles_maternal_surname_check,
  drop constraint profiles_structured_full_name_check;

alter table public.profiles add constraint profiles_account_identity_check check (
  (
    account_kind = 'institutional' and account_status = 'pending_registration'
    and person_type is null and primary_program_id is null
    and institutional_id_type is null and institutional_id_value is null
  )
  or (
    account_kind = 'institutional' and account_status in ('active', 'inactive')
    and person_type in ('student', 'professor') and primary_program_id is not null
    and institutional_id_type is not null and institutional_id_value is not null
    and full_name is not null
    and (
      (person_type = 'student' and institutional_id_type = 'student_account')
      or (person_type = 'professor' and institutional_id_type = 'worker_number')
    )
  )
  or (
    account_kind = 'technical' and account_status in ('active', 'inactive')
    and person_type is null and primary_program_id is null
    and institutional_id_type is null and institutional_id_value is null
    and full_name is not null
  )
);

revoke update (first_names, paternal_surname, maternal_surname) on public.profiles from authenticated;
grant update (full_name) on public.profiles to authenticated;

drop trigger normalize_sitaa_profile_names on public.profiles;
drop function public.normalize_sitaa_profile_names();

commit;

-- Los valores estructurados no se borran. Si existieron altas después de 0006,
-- revisar el flujo de aplicación antes de operar con la versión post-0005.
