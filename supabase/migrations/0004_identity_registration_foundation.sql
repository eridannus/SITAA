-- SITAA 0004: identidad institucional posterior a Google OAuth.
--
-- Requiere 0001 + 0002 + 0003 aplicadas. No crea usuarios, roles ni cuentas
-- técnicas reales. Debe revisarse y aplicarse manualmente después de aprobar
-- el preflight. Google autentica; SITAA conserva la identidad institucional.
-- No recibe PII institucional ni ejecuta escrituras de registro antes de OAuth.

begin;

set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- -----------------------------------------------------------------------------
-- Preflight bloqueante. La salida de error contiene sólo categorías y conteos.
-- -----------------------------------------------------------------------------

do $preflight$
declare
  diagnostics jsonb;
  incompatible_count bigint;
begin
  with categories as (
    select 'duplicate_identifier_pair'::text category, count(*)::bigint total, true blocking
    from (
      select institutional_id_type, institutional_id_value
      from public.profiles
      where institutional_id_type is not null and institutional_id_value is not null
      group by institutional_id_type, institutional_id_value
      having count(*) > 1
    ) duplicates
    union all
    select 'identifier_not_digits', count(*), true from public.profiles
      where institutional_id_value is not null and institutional_id_value !~ '^[0-9]+$'
    union all
    select 'identifier_too_long', count(*), true from public.profiles
      where institutional_id_value is not null and char_length(institutional_id_value) > 50
    union all
    select 'missing_institutional_identity', count(*), true from public.profiles
      where person_type is null or institutional_id_type is null
         or institutional_id_value is null or primary_program_id is null
         or nullif(btrim(full_name), '') is null or nullif(btrim(email), '') is null
    union all
    select 'invalid_full_name', count(*), true from public.profiles
      where nullif(btrim(full_name), '') is null
         or char_length(regexp_replace(btrim(full_name), '\s+', ' ', 'g')) not between 2 and 200
         or full_name is distinct from regexp_replace(btrim(full_name), '\s+', ' ', 'g')
    union all
    select 'invalid_profile_email', count(*), true from public.profiles
      where nullif(btrim(email), '') is null or char_length(btrim(email)) > 254
         or email is distinct from lower(btrim(email))
    union all
    select 'invalid_person_type', count(*), true from public.profiles
      where person_type is not null and person_type not in ('student', 'worker')
    union all
    select 'person_identifier_mismatch', count(*), true from public.profiles
      where not (
        (person_type = 'student' and institutional_id_type = 'student_account')
        or (person_type = 'worker' and institutional_id_type = 'worker_number')
      )
    union all
    select 'missing_academic_program', count(*), true
      from public.profiles p left join public.academic_programs ap on ap.id = p.primary_program_id
      where p.primary_program_id is null or ap.id is null
    union all
    select 'profile_without_auth_user', count(*), true
      from public.profiles p left join auth.users u on u.id = p.id where u.id is null
    union all
    select 'auth_user_without_profile', count(*), true
      from auth.users u left join public.profiles p on p.id = u.id where p.id is null
    union all
    select 'auth_email_missing', count(*), true
      from public.profiles p join auth.users u on u.id = p.id
      where nullif(btrim(u.email), '') is null
    union all
    select 'auth_profile_email_mismatch', count(*), true
      from public.profiles p join auth.users u on u.id = p.id
      where lower(btrim(u.email)) <> lower(btrim(p.email))
    union all
    select 'unexpected_auth_user_trigger', count(*), true from pg_trigger t
      where t.tgrelid = 'auth.users'::regclass and not t.tgisinternal
    union all
    select 'existing_pending_verification_dependency', count(*), true from (
      select p.id::text dependency from public.profiles p
      where to_jsonb(p) ->> 'account_status' = 'pending_verification'
      union all
      select p.oid::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prokind in ('f', 'p')
        and position('pending_verification' in lower(pg_get_functiondef(p.oid))) > 0
    ) pending_dependencies
    union all
    select 'invalid_projected_lifecycle', count(*), true
      from public.profiles p left join auth.users u on u.id = p.id
      where u.id is null or p.is_active is null
         or (p.is_active and coalesce(p.updated_at, p.created_at) is null)
         or (not p.is_active and coalesce(p.updated_at, p.created_at) is null)
    union all
    select 'possible_technical_operator', count(distinct p.id), false
      from public.profiles p join public.role_assignments ra on ra.user_id = p.id
      where ra.role_code = 'technical_admin'
    union all
    select 'legacy_email_password_user', count(distinct u.id), false
      from auth.users u join auth.identities i on i.user_id = u.id
      where i.provider = 'email'
    union all
    select 'existing_oauth_identity', count(distinct u.id), false
      from auth.users u join auth.identities i on i.user_id = u.id
      where i.provider <> 'email'
  ), invalid as (
    select category, total from categories where blocking and total > 0
  )
  select coalesce(sum(total), 0), coalesce(jsonb_object_agg(category, total), '{}'::jsonb)
  into incompatible_count, diagnostics from invalid;

  if incompatible_count > 0 then
    raise exception 'SITAA 0004 preflight failed. Remediate these categories before applying: %', diagnostics
      using errcode = 'P0001';
  end if;
end;
$preflight$;

-- -----------------------------------------------------------------------------
-- Catálogo de programas para el formulario autenticado.
-- -----------------------------------------------------------------------------

alter table public.academic_programs
  add column if not exists is_active boolean not null default true;

-- -----------------------------------------------------------------------------
-- Profiles: identidad estable y ciclo pending_registration | active | inactive.
-- -----------------------------------------------------------------------------

alter table public.profiles
  add column if not exists account_kind text,
  add column if not exists account_status text,
  add column if not exists activated_at timestamp with time zone,
  add column if not exists deactivated_at timestamp with time zone;

alter table public.profiles drop constraint if exists profiles_person_identifier_consistency_check;
alter table public.profiles drop constraint if exists profiles_person_type_check;
alter table public.profiles drop constraint if exists profiles_institutional_id_type_check;

update public.profiles set person_type = 'professor' where person_type = 'worker';

update public.profiles p
set
  email = lower(btrim(u.email)),
  account_kind = 'institutional',
  account_status = case when p.is_active then 'active' else 'inactive' end,
  activated_at = case
    when p.is_active then coalesce(u.email_confirmed_at, p.updated_at, p.created_at, now())
    else null
  end,
  deactivated_at = case
    when not p.is_active then coalesce(p.updated_at, p.created_at, now())
    else null
  end
from auth.users u where u.id = p.id;

alter table public.profiles
  alter column account_kind set default 'institutional',
  alter column account_kind set not null,
  alter column account_status set default 'pending_registration',
  alter column account_status set not null,
  alter column is_active set default false;

alter table public.profiles
  add constraint profiles_account_kind_check
    check (account_kind in ('institutional', 'technical')),
  add constraint profiles_account_status_check
    check (account_status in ('pending_registration', 'active', 'inactive')),
  add constraint profiles_person_type_check
    check (person_type is null or person_type in ('student', 'professor')),
  add constraint profiles_institutional_id_type_check
    check (institutional_id_type is null or institutional_id_type in ('student_account', 'worker_number')),
  add constraint profiles_identifier_digits_check
    check (institutional_id_value is null or institutional_id_value ~ '^[0-9]+$'),
  add constraint profiles_identifier_length_check
    check (institutional_id_value is null or char_length(institutional_id_value) between 1 and 50),
  add constraint profiles_full_name_check
    check (
      full_name is null
      or (
        char_length(full_name) between 2 and 200
        and full_name = regexp_replace(btrim(full_name), '\s+', ' ', 'g')
      )
    ),
  add constraint profiles_email_check
    check (char_length(email) between 1 and 254 and email = lower(btrim(email))),
  add constraint profiles_account_identity_check
    check (
      (
        account_kind = 'institutional'
        and account_status = 'pending_registration'
        and person_type is null and primary_program_id is null
        and institutional_id_type is null and institutional_id_value is null
      )
      or (
        account_kind = 'institutional'
        and account_status in ('active', 'inactive')
        and person_type in ('student', 'professor')
        and primary_program_id is not null
        and institutional_id_type is not null
        and institutional_id_value is not null
        and full_name is not null
        and (
          (person_type = 'student' and institutional_id_type = 'student_account')
          or (person_type = 'professor' and institutional_id_type = 'worker_number')
        )
      )
      or (
        account_kind = 'technical'
        and account_status in ('active', 'inactive')
        and person_type is null and primary_program_id is null
        and institutional_id_type is null and institutional_id_value is null
        and full_name is not null
      )
    ),
  add constraint profiles_account_lifecycle_check
    check (
      (account_status = 'active' and is_active and activated_at is not null and deactivated_at is null)
      or (account_status = 'pending_registration' and not is_active and activated_at is null and deactivated_at is null)
      or (account_status = 'inactive' and not is_active and deactivated_at is not null)
    );

create unique index if not exists profiles_institutional_identifier_pair_key
  on public.profiles (institutional_id_type, institutional_id_value)
  where account_kind = 'institutional' and institutional_id_value is not null;

-- -----------------------------------------------------------------------------
-- Protección de profiles y normalización del ciclo de vida.
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

revoke all on function public.enforce_sitaa_profile_identity() from public, anon, authenticated;
drop trigger if exists enforce_sitaa_profile_identity on public.profiles;
create trigger enforce_sitaa_profile_identity
before insert or update on public.profiles
for each row execute function public.enforce_sitaa_profile_identity();

revoke update on table public.profiles from authenticated;
grant update (full_name) on table public.profiles to authenticated;

-- -----------------------------------------------------------------------------
-- Auth -> profile. Sólo Google OAuth nuevo o bootstrap técnico confiable.
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
create trigger on_sitaa_auth_user_created
after insert on auth.users
for each row execute function public.handle_sitaa_auth_user_created();

create or replace function public.sync_sitaa_profile_email_from_auth()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare normalized_email text := lower(btrim(coalesce(new.email, '')));
begin
  if normalized_email = '' or char_length(normalized_email) > 254 then
    raise exception 'sitaa_invalid_registration_email' using errcode = '23514';
  end if;
  update public.profiles set email = normalized_email where id = new.id;
  return new;
end;
$function$;

revoke all on function public.sync_sitaa_profile_email_from_auth() from public, anon, authenticated;
create trigger on_sitaa_auth_user_email_changed
after update of email on auth.users
for each row when (old.email is distinct from new.email)
execute function public.sync_sitaa_profile_email_from_auth();

-- -----------------------------------------------------------------------------
-- Finalización autenticada y transaccional del registro institucional.
-- -----------------------------------------------------------------------------

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

-- -----------------------------------------------------------------------------
-- Compatibilidad funcional: worker pasa a professor sin cambiar roles actuales.
-- -----------------------------------------------------------------------------

create or replace function public.add_activity_participant(
  target_activity_id uuid,
  target_profile_id uuid,
  target_participant_role_code text
) returns void
language plpgsql
security definer
set search_path = public
as $function$
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
$function$;

revoke all on function public.add_activity_participant(uuid, uuid, text) from public, anon;
grant execute on function public.add_activity_participant(uuid, uuid, text) to authenticated;

commit;
