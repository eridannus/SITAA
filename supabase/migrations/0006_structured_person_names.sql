-- SITAA 0006: nombres personales estructurados.
-- Creada para revisión; no aplicar sin ejecutar primero el preflight 0006.

begin;

-- -----------------------------------------------------------------------------
-- Preflight bloqueante: no adivinar la estructura de nombres históricos.
-- -----------------------------------------------------------------------------
do $preflight$
declare
  incompatible_count bigint;
begin
  if to_regprocedure('public.complete_own_google_registration(text,text,text,uuid)') is null
     or to_regprocedure('public.handle_sitaa_auth_user_created()') is null
     or to_regprocedure('public.enforce_sitaa_profile_identity()') is null then
    raise exception 'SITAA 0006 requiere el estado post-0005.' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles'
      and column_name in ('first_names', 'paternal_surname', 'maternal_surname')
    group by table_schema, table_name having count(*) = 3
  ) then
    raise exception 'SITAA 0006 requiere las columnas estructuradas reconciliadas en profiles.' using errcode = 'P0001';
  end if;

  select count(*) into incompatible_count
  from public.profiles p
  where p.account_status in ('active', 'inactive')
    and (
      nullif(btrim(p.first_names), '') is null
      or (p.account_kind = 'institutional' and nullif(btrim(p.paternal_surname), '') is null)
      or char_length(regexp_replace(btrim(coalesce(p.first_names, '')), '\s+', ' ', 'g')) > 150
      or char_length(regexp_replace(btrim(coalesce(p.paternal_surname, '')), '\s+', ' ', 'g')) > 150
      or char_length(regexp_replace(btrim(coalesce(p.maternal_surname, '')), '\s+', ' ', 'g')) > 150
      or char_length(concat_ws(' ',
        nullif(regexp_replace(btrim(coalesce(p.first_names, '')), '\s+', ' ', 'g'), ''),
        nullif(regexp_replace(btrim(coalesce(p.paternal_surname, '')), '\s+', ' ', 'g'), ''),
        nullif(regexp_replace(btrim(coalesce(p.maternal_surname, '')), '\s+', ' ', 'g'), '')
      )) > 200
    );
  if incompatible_count > 0 then
    raise exception 'SITAA 0006 preflight failed: % perfiles activos o inactivos requieren correspondencia de nombres revisada.', incompatible_count
      using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.profiles p
    where p.account_status = 'pending_registration'
      and (p.first_names is not null or p.paternal_surname is not null or p.maternal_surname is not null)
  ) then
    raise exception 'SITAA 0006 preflight failed: perfiles pendientes contienen identidad estructurada parcial.' using errcode = 'P0001';
  end if;
end;
$preflight$;

-- -----------------------------------------------------------------------------
-- Normalización y valor de compatibilidad.
-- -----------------------------------------------------------------------------
create or replace function public.normalize_sitaa_profile_names()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $function$
begin
  new.first_names := nullif(regexp_replace(btrim(coalesce(new.first_names, '')), '\s+', ' ', 'g'), '');
  new.paternal_surname := nullif(regexp_replace(btrim(coalesce(new.paternal_surname, '')), '\s+', ' ', 'g'), '');
  new.maternal_surname := nullif(regexp_replace(btrim(coalesce(new.maternal_surname, '')), '\s+', ' ', 'g'), '');

  if new.first_names is not null then
    new.full_name := concat_ws(' ', new.first_names, new.paternal_surname, new.maternal_surname);
  end if;
  return new;
end;
$function$;

revoke all on function public.normalize_sitaa_profile_names() from public, anon, authenticated;
drop trigger if exists normalize_sitaa_profile_names on public.profiles;
create trigger normalize_sitaa_profile_names
before insert or update on public.profiles
for each row execute function public.normalize_sitaa_profile_names();

-- Sincronización determinista de filas ya estructuradas. No se divide full_name.
update public.profiles
set first_names = nullif(regexp_replace(btrim(coalesce(first_names, '')), '\s+', ' ', 'g'), ''),
    paternal_surname = nullif(regexp_replace(btrim(coalesce(paternal_surname, '')), '\s+', ' ', 'g'), ''),
    maternal_surname = nullif(regexp_replace(btrim(coalesce(maternal_surname, '')), '\s+', ' ', 'g'), '')
where first_names is not null or paternal_surname is not null or maternal_surname is not null;

alter table public.profiles
  drop constraint if exists profiles_first_names_check,
  drop constraint if exists profiles_paternal_surname_check,
  drop constraint if exists profiles_maternal_surname_check,
  drop constraint if exists profiles_structured_full_name_check,
  drop constraint profiles_account_identity_check;

alter table public.profiles
  add constraint profiles_first_names_check check (
    first_names is null or (
      char_length(first_names) between 1 and 150
      and first_names = regexp_replace(btrim(first_names), '\s+', ' ', 'g')
    )
  ),
  add constraint profiles_paternal_surname_check check (
    paternal_surname is null or (
      char_length(paternal_surname) between 1 and 150
      and paternal_surname = regexp_replace(btrim(paternal_surname), '\s+', ' ', 'g')
    )
  ),
  add constraint profiles_maternal_surname_check check (
    maternal_surname is null or (
      char_length(maternal_surname) between 1 and 150
      and maternal_surname = regexp_replace(btrim(maternal_surname), '\s+', ' ', 'g')
    )
  ),
  add constraint profiles_structured_full_name_check check (
    first_names is null
    or full_name = concat_ws(' ', first_names, paternal_surname, maternal_surname)
  ),
  add constraint profiles_account_identity_check check (
    (
      account_kind = 'institutional' and account_status = 'pending_registration'
      and person_type is null and primary_program_id is null
      and institutional_id_type is null and institutional_id_value is null
      and first_names is null and paternal_surname is null and maternal_surname is null
    )
    or (
      account_kind = 'institutional' and account_status in ('active', 'inactive')
      and person_type in ('student', 'professor') and primary_program_id is not null
      and institutional_id_type is not null and institutional_id_value is not null
      and first_names is not null and paternal_surname is not null and full_name is not null
      and (
        (person_type = 'student' and institutional_id_type = 'student_account')
        or (person_type = 'professor' and institutional_id_type = 'worker_number')
      )
    )
    or (
      account_kind = 'technical' and account_status in ('active', 'inactive')
      and person_type is null and primary_program_id is null
      and institutional_id_type is null and institutional_id_value is null
      and first_names is not null and full_name is not null
    )
  );

-- -----------------------------------------------------------------------------
-- Escritura propia: sólo componentes del nombre; full_name lo deriva el trigger.
-- -----------------------------------------------------------------------------
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
$function$;

revoke update (full_name) on public.profiles from authenticated;
grant update (first_names, paternal_surname, maternal_surname) on public.profiles to authenticated;

-- -----------------------------------------------------------------------------
-- Auth técnico confiable con nombres estructurados; Google pendiente no cambia.
-- -----------------------------------------------------------------------------
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
$function$;
revoke all on function public.handle_sitaa_auth_user_created() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- Nueva finalización Google estructurada. El overload post-0005 queda sin acceso.
-- -----------------------------------------------------------------------------
create or replace function public.complete_own_google_registration(
  requested_person_type text,
  requested_first_names text,
  requested_paternal_surname text,
  requested_maternal_surname text,
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
  auth_email text; auth_email_confirmed_at timestamptz; identity_email text; identity_email_verified text;
  normalized_first_names text := regexp_replace(btrim(coalesce(requested_first_names, '')), '\s+', ' ', 'g');
  normalized_paternal text := regexp_replace(btrim(coalesce(requested_paternal_surname, '')), '\s+', ' ', 'g');
  normalized_maternal text := nullif(regexp_replace(btrim(coalesce(requested_maternal_surname, '')), '\s+', ' ', 'g'), '');
  normalized_identifier text := btrim(coalesce(requested_institutional_id_value, ''));
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
$function$;

revoke all on function public.complete_own_google_registration(text,text,text,text,text,uuid) from public, anon, authenticated;
grant execute on function public.complete_own_google_registration(text,text,text,text,text,uuid) to authenticated;
revoke execute on function public.complete_own_google_registration(text,text,text,uuid) from authenticated;

commit;
