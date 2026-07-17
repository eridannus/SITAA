-- SITAA 0005: corrige el alta Google y valida la identidad al completar registro.
-- Requiere 0001–0004 aplicadas. No transforma ni elimina datos operativos.

begin;

set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- Preflight bloqueante: exige el contrato post-0004 conocido.
do $preflight$
declare
  diagnostics jsonb;
  incompatible_count bigint;
begin
  with expected_functions as (
    select
      to_regprocedure('public.handle_sitaa_auth_user_created()') handle_oid,
      to_regprocedure('public.complete_own_google_registration(text,text,text,uuid)') completion_oid
  ), categories as (
    select 'missing_handle_auth_user_created'::text category,
      case when handle_oid is null then 1 else 0 end::bigint total, true blocking
    from expected_functions
    union all
    select 'missing_complete_google_registration',
      case when completion_oid is null then 1 else 0 end, true
    from expected_functions
    union all
    select 'unexpected_0004_handle_definition',
      case when handle_oid is null or not (
        pg_get_functiondef(handle_oid) ~* E'if\\s+new\\.email_confirmed_at\\s+is\\s+null\\s+then\\s+raise exception ''sitaa_google_email_not_verified'''
        and position('sitaa_public_technical_account_forbidden' in lower(pg_get_functiondef(handle_oid))) > 0
        and position('sitaa_unverified_technical_email' in lower(pg_get_functiondef(handle_oid))) > 0
        and position('sitaa_public_password_signup_disabled' in lower(pg_get_functiondef(handle_oid))) > 0
        and position('sitaa_unsupported_auth_provider' in lower(pg_get_functiondef(handle_oid))) > 0
        and position('pending_registration' in lower(pg_get_functiondef(handle_oid))) > 0
      ) then 1 else 0 end, true
    from expected_functions
    union all
    select 'unexpected_0004_completion_definition',
      case when completion_oid is null
        or position('u.email_confirmed_at is not null' in lower(pg_get_functiondef(completion_oid))) = 0
        or position('sitaa_registration_not_pending' in lower(pg_get_functiondef(completion_oid))) = 0
        or position('sitaa_identifier_conflict' in lower(pg_get_functiondef(completion_oid))) = 0
      then 1 else 0 end, true
    from expected_functions
    union all
    select 'missing_auth_user_created_trigger',
      case when exists (
        select 1 from pg_trigger t
        where t.tgrelid = 'auth.users'::regclass and not t.tgisinternal
          and t.tgname = 'on_sitaa_auth_user_created'
          and t.tgfoid = to_regprocedure('public.handle_sitaa_auth_user_created()')
      ) then 0 else 1 end, true
    union all
    select 'missing_auth_email_sync_trigger',
      case when exists (
        select 1 from pg_trigger t
        where t.tgrelid = 'auth.users'::regclass and not t.tgisinternal
          and t.tgname = 'on_sitaa_auth_user_email_changed'
          and t.tgfoid = to_regprocedure('public.sync_sitaa_profile_email_from_auth()')
      ) then 0 else 1 end, true
    union all
    select 'unexpected_auth_user_trigger', count(*), true from pg_trigger t
      where t.tgrelid = 'auth.users'::regclass and not t.tgisinternal
        and t.tgname not in ('on_sitaa_auth_user_created', 'on_sitaa_auth_user_email_changed')
    union all
    select 'missing_profile_lifecycle_column', count(*), true
    from (values ('account_kind'), ('account_status'), ('activated_at'), ('deactivated_at')) required(column_name)
    where not exists (
      select 1 from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = 'profiles'
        and c.column_name = required.column_name
    )
    union all
    select 'pending_registration_not_supported',
      case when exists (
        select 1 from pg_constraint c
        where c.conrelid = 'public.profiles'::regclass
          and position('pending_registration' in lower(pg_get_constraintdef(c.oid, true))) > 0
      ) then 0 else 1 end, true
    union all
    select 'auth_user_without_profile', count(*), true
      from auth.users u left join public.profiles p on p.id = u.id where p.id is null
    union all
    select 'profile_without_auth_user', count(*), true
      from public.profiles p left join auth.users u on u.id = p.id where u.id is null
    union all
    select 'invalid_account_lifecycle', count(*), true from public.profiles p
      where not (
        (p.account_status = 'active' and p.is_active and p.activated_at is not null and p.deactivated_at is null)
        or (p.account_status = 'pending_registration' and not p.is_active and p.activated_at is null and p.deactivated_at is null)
        or (p.account_status = 'inactive' and not p.is_active and p.deactivated_at is not null)
      )
    union all
    select 'invalid_institutional_identity', count(*), true from public.profiles p
      where p.account_kind = 'institutional' and (
        (p.account_status = 'pending_registration' and (
          p.person_type is not null or p.primary_program_id is not null
          or p.institutional_id_type is not null or p.institutional_id_value is not null
        ))
        or (p.account_status in ('active', 'inactive') and not (
          p.person_type in ('student', 'professor')
          and p.primary_program_id is not null
          and p.institutional_id_value ~ '^[0-9]{1,50}$'
          and char_length(p.full_name) between 2 and 200
          and p.full_name = regexp_replace(btrim(p.full_name), '\s+', ' ', 'g')
          and char_length(p.email) between 1 and 254 and p.email = lower(btrim(p.email))
          and exists (select 1 from public.academic_programs ap
            where ap.id = p.primary_program_id and ap.is_active)
          and ((p.person_type = 'student' and p.institutional_id_type = 'student_account')
            or (p.person_type = 'professor' and p.institutional_id_type = 'worker_number'))
        ))
      )
    union all
    select 'legacy_email_password_user', count(distinct u.id), false
      from auth.users u join auth.identities i on i.user_id = u.id where i.provider = 'email'
    union all
    select 'existing_oauth_identity', count(distinct u.id), false
      from auth.users u join auth.identities i on i.user_id = u.id where i.provider <> 'email'
    union all
    select 'possible_technical_operator', count(distinct p.id), false
      from public.profiles p join public.role_assignments ra on ra.user_id = p.id
      where ra.role_code = 'technical_admin'
  ), invalid as (
    select category, total from categories where blocking and total > 0
  )
  select coalesce(sum(total), 0), coalesce(jsonb_object_agg(category, total), '{}'::jsonb)
  into incompatible_count, diagnostics from invalid;

  if incompatible_count > 0 then
    raise exception 'SITAA 0005 preflight failed. Remediate these categories before applying: %', diagnostics
      using errcode = 'P0001';
  end if;
end;
$preflight$;

-- Google puede insertar auth.users antes de fijar email_confirmed_at. El perfil
-- permanece pendiente, incompleto e inactivo hasta la finalización autenticada.
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

-- La identidad Google enlazada y verificada es la frontera de activación.
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
$function$;

revoke all on function public.complete_own_google_registration(text, text, text, uuid)
  from public, anon;
grant execute on function public.complete_own_google_registration(text, text, text, uuid)
  to authenticated;

commit;
