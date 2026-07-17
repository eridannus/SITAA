-- SITAA 0004: fundamento de identidad y registro institucional.
--
-- Requiere 0001 + 0002 + 0003 aplicadas. Esta migración no crea cuentas,
-- asignaciones de rol ni datos personales reales. Debe revisarse y ejecutarse
-- manualmente después de aprobar el preflight de reconciliación.

begin;

set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- -----------------------------------------------------------------------------
-- Preflight bloqueante: no reescribe identificadores ni inventa identidad.
-- -----------------------------------------------------------------------------

do $preflight$
declare
  diagnostics jsonb;
  incompatible_count bigint;
begin
  with categories as (
    select 'duplicate_identifier_pair'::text as category, count(*)::bigint as total
    from (
      select institutional_id_type, institutional_id_value
      from public.profiles
      where institutional_id_type is not null and institutional_id_value is not null
      group by institutional_id_type, institutional_id_value
      having count(*) > 1
    ) duplicate_pairs
    union all
    select 'identifier_not_digits', count(*)
    from public.profiles
    where institutional_id_value is not null
      and institutional_id_value !~ '^[0-9]+$'
    union all
    select 'missing_institutional_identity', count(*)
    from public.profiles
    where person_type is null
       or institutional_id_type is null
       or institutional_id_value is null
       or primary_program_id is null
       or nullif(btrim(full_name), '') is null
    union all
    select 'invalid_person_type', count(*)
    from public.profiles
    where person_type is not null and person_type not in ('student', 'worker')
    union all
    select 'person_identifier_mismatch', count(*)
    from public.profiles
    where not (
      (person_type = 'student' and institutional_id_type = 'student_account')
      or (person_type = 'worker' and institutional_id_type = 'worker_number')
    )
    union all
    select 'missing_academic_program', count(*)
    from public.profiles p
    left join public.academic_programs ap on ap.id = p.primary_program_id
    where p.primary_program_id is null or ap.id is null
    union all
    select 'missing_or_inconsistent_auth_user', count(*)
    from public.profiles p
    left join auth.users u on u.id = p.id
    where u.id is null
       or u.email is null
       or lower(btrim(u.email)) <> lower(btrim(p.email))
  ), invalid as (
    select category, total from categories where total > 0
  )
  select coalesce(sum(total), 0), coalesce(jsonb_object_agg(category, total), '{}'::jsonb)
  into incompatible_count, diagnostics
  from invalid;

  if incompatible_count > 0 then
    raise exception 'SITAA 0004 preflight failed. Remediate these categories before applying: %', diagnostics
      using errcode = 'P0001';
  end if;
end;
$preflight$;

-- -----------------------------------------------------------------------------
-- Catálogo académico público requerido por los formularios de registro.
-- -----------------------------------------------------------------------------

alter table public.academic_programs
  add column if not exists is_active boolean not null default true;

drop policy if exists "Public can read active academic programs" on public.academic_programs;
create policy "Public can read active academic programs"
on public.academic_programs for select to anon
using (is_active = true);

grant select on table public.academic_programs to anon;

-- -----------------------------------------------------------------------------
-- Evolución canónica de profiles; se reutilizan todas las columnas existentes.
-- -----------------------------------------------------------------------------

alter table public.profiles
  add column if not exists account_kind text,
  add column if not exists account_status text,
  add column if not exists activated_at timestamp with time zone,
  add column if not exists deactivated_at timestamp with time zone;

alter table public.profiles drop constraint if exists profiles_person_identifier_consistency_check;
alter table public.profiles drop constraint if exists profiles_person_type_check;
alter table public.profiles drop constraint if exists profiles_institutional_id_type_check;

update public.profiles
set person_type = 'professor'
where person_type = 'worker';

update public.profiles p
set
  account_kind = 'institutional',
  account_status = case
    when p.is_active = false then 'inactive'
    when u.email_confirmed_at is null then 'pending_verification'
    else 'active'
  end,
  is_active = p.is_active and u.email_confirmed_at is not null,
  activated_at = case
    when p.is_active = true and u.email_confirmed_at is not null
      then coalesce(u.email_confirmed_at, p.created_at)
    else null
  end,
  deactivated_at = case when p.is_active = false then p.updated_at else null end
from auth.users u
where u.id = p.id;

alter table public.profiles
  alter column account_kind set default 'institutional',
  alter column account_kind set not null,
  alter column account_status set default 'pending_verification',
  alter column account_status set not null,
  alter column is_active set default false;

alter table public.profiles
  add constraint profiles_account_kind_check
    check (account_kind in ('institutional', 'technical')),
  add constraint profiles_account_status_check
    check (account_status in ('pending_verification', 'active', 'inactive')),
  add constraint profiles_person_type_check
    check (person_type is null or person_type in ('student', 'professor')),
  add constraint profiles_institutional_id_type_check
    check (institutional_id_type is null or institutional_id_type in ('student_account', 'worker_number')),
  add constraint profiles_identifier_digits_check
    check (institutional_id_value is null or institutional_id_value ~ '^[0-9]+$'),
  add constraint profiles_account_identity_check
    check (
      (
        account_kind = 'institutional'
        and person_type is not null
        and person_type in ('student', 'professor')
        and primary_program_id is not null
        and institutional_id_type is not null
        and institutional_id_value is not null
        and nullif(btrim(full_name), '') is not null
        and (
          (person_type = 'student' and institutional_id_type = 'student_account')
          or (person_type = 'professor' and institutional_id_type = 'worker_number')
        )
      )
      or
      (
        account_kind = 'technical'
        and person_type is null
        and primary_program_id is null
        and institutional_id_type is null
        and institutional_id_value is null
        and account_status in ('active', 'inactive')
      )
    ),
  add constraint profiles_account_lifecycle_check
    check (
      is_active = (account_status = 'active')
      and (account_status <> 'active' or activated_at is not null)
      and (account_status <> 'pending_verification' or (activated_at is null and deactivated_at is null))
      and (account_status <> 'inactive' or deactivated_at is not null)
    );

create unique index if not exists profiles_institutional_identifier_pair_key
  on public.profiles (institutional_id_type, institutional_id_value)
  where account_kind = 'institutional';

-- -----------------------------------------------------------------------------
-- Validación, ciclo de vida e inmutabilidad de identidad por autoservicio.
-- -----------------------------------------------------------------------------

create or replace function public.enforce_sitaa_profile_identity()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $function$
begin
  if tg_op = 'UPDATE'
     and current_user = 'authenticated'
     and auth.uid() = old.id
     and (
       (to_jsonb(new) - 'full_name' - 'updated_at')
       is distinct from
       (to_jsonb(old) - 'full_name' - 'updated_at')
     ) then
    raise exception 'Sólo puedes actualizar tu nombre completo.' using errcode = '42501';
  end if;

  if new.account_kind = 'institutional' and not exists (
    select 1 from public.academic_programs ap
    where ap.id = new.primary_program_id and ap.is_active = true
  ) then
    raise exception 'El programa académico no existe o está inactivo.' using errcode = '23514';
  end if;

  if tg_op = 'INSERT' or new.account_status is distinct from old.account_status then
    if new.account_status = 'active' then
      new.activated_at := coalesce(new.activated_at, now());
      new.deactivated_at := null;
    elsif new.account_status = 'inactive' then
      new.deactivated_at := coalesce(new.deactivated_at, now());
    else
      new.activated_at := null;
      new.deactivated_at := null;
    end if;
  end if;

  new.is_active := new.account_status = 'active';
  return new;
end;
$function$;

revoke all on function public.enforce_sitaa_profile_identity() from public, anon, authenticated;

drop trigger if exists enforce_sitaa_profile_identity on public.profiles;
create trigger enforce_sitaa_profile_identity
before insert or update on public.profiles
for each row execute function public.enforce_sitaa_profile_identity();

-- La política propia permanece, pero el privilegio de columna limita el único
-- cambio directo permitido. El trigger anterior es una segunda defensa.
revoke update on table public.profiles from authenticated;
grant update (full_name) on table public.profiles to authenticated;

-- -----------------------------------------------------------------------------
-- Sincronización atómica Auth -> profile.
-- -----------------------------------------------------------------------------

create or replace function public.handle_sitaa_auth_user_created()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  registration_type text := new.raw_user_meta_data ->> 'sitaa_registration_type';
  requested_program text := new.raw_user_meta_data ->> 'primary_program_id';
  requested_identifier text := new.raw_user_meta_data ->> 'institutional_id_value';
  requested_name text := regexp_replace(btrim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), '\s+', ' ', 'g');
  trusted_kind text := new.raw_app_meta_data ->> 'sitaa_account_kind';
  program_id uuid;
  initial_status text;
begin
  if registration_type in ('student', 'professor') then
    if requested_program is null
       or requested_program !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
      raise exception 'sitaa_invalid_registration_program' using errcode = '23514';
    end if;
    program_id := requested_program::uuid;

    if requested_name = '' or requested_identifier is null or requested_identifier !~ '^[0-9]+$' then
      raise exception 'sitaa_invalid_registration_identity' using errcode = '23514';
    end if;
    if not exists (
      select 1 from public.academic_programs ap
      where ap.id = program_id and ap.is_active = true
    ) then
      raise exception 'sitaa_invalid_registration_program' using errcode = '23514';
    end if;

    initial_status := case when new.email_confirmed_at is null then 'pending_verification' else 'active' end;

    begin
      insert into public.profiles (
        id, email, full_name, primary_program_id, is_active,
        person_type, institutional_id_type, institutional_id_value,
        account_kind, account_status, activated_at
      ) values (
        new.id, lower(btrim(new.email)), requested_name, program_id,
        initial_status = 'active', registration_type,
        case when registration_type = 'student' then 'student_account' else 'worker_number' end,
        requested_identifier, 'institutional', initial_status,
        case when initial_status = 'active' then coalesce(new.email_confirmed_at, now()) else null end
      );
    exception when unique_violation then
      raise exception 'sitaa_identifier_conflict' using errcode = '23505';
    end;

    return new;
  end if;

  -- Una cuenta técnica sólo se materializa si un proceso Auth administrativo
  -- confiable escribió app_metadata. signUp público no controla app_metadata.
  if trusted_kind = 'technical' then
    requested_name := regexp_replace(btrim(coalesce(new.raw_app_meta_data ->> 'sitaa_full_name', 'Cuenta técnica SITAA')), '\s+', ' ', 'g');
    insert into public.profiles (
      id, email, full_name, is_active, account_kind, account_status, activated_at
    ) values (
      new.id, lower(btrim(new.email)), requested_name, true,
      'technical', 'active', coalesce(new.email_confirmed_at, now())
    );
  elsif new.raw_user_meta_data ? 'sitaa_registration_type' then
    raise exception 'sitaa_invalid_registration_type' using errcode = '23514';
  end if;

  return new;
end;
$function$;

revoke all on function public.handle_sitaa_auth_user_created() from public, anon, authenticated;

drop trigger if exists on_sitaa_auth_user_created on auth.users;
create trigger on_sitaa_auth_user_created
after insert on auth.users
for each row execute function public.handle_sitaa_auth_user_created();

create or replace function public.sync_sitaa_profile_from_auth()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
begin
  update public.profiles p
  set
    email = lower(btrim(new.email)),
    account_status = case
      when p.account_status = 'pending_verification' and new.email_confirmed_at is not null then 'active'
      else p.account_status
    end,
    activated_at = case
      when p.account_status = 'pending_verification' and new.email_confirmed_at is not null
        then coalesce(new.email_confirmed_at, now())
      else p.activated_at
    end
  where p.id = new.id;
  return new;
end;
$function$;

revoke all on function public.sync_sitaa_profile_from_auth() from public, anon, authenticated;

drop trigger if exists on_sitaa_auth_user_verified on auth.users;
create trigger on_sitaa_auth_user_verified
after update of email, email_confirmed_at on auth.users
for each row execute function public.sync_sitaa_profile_from_auth();

create or replace function public.activate_own_verified_profile()
returns text
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  target_status text;
begin
  if auth.uid() is null then
    raise exception 'Se requiere una sesión autenticada.' using errcode = '42501';
  end if;
  if not exists (
    select 1 from auth.users u
    where u.id = auth.uid() and u.email_confirmed_at is not null
  ) then
    raise exception 'El correo todavía no está verificado.' using errcode = '42501';
  end if;

  update public.profiles
  set account_status = 'active', activated_at = coalesce(activated_at, now())
  where id = auth.uid() and account_status = 'pending_verification';

  select account_status into target_status from public.profiles where id = auth.uid();
  if target_status is null then
    raise exception 'El perfil SITAA no existe.' using errcode = 'P0001';
  end if;
  return target_status;
end;
$function$;

revoke all on function public.activate_own_verified_profile() from public, anon;
grant execute on function public.activate_own_verified_profile() to authenticated;

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
set search_path = pg_catalog, public
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
  select p.primary_program_id, p.person_type
  into participant_program_id, participant_person_type
  from public.profiles p
  where p.id = target_profile_id and p.is_active = true;
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

-- Conserva los grants/revokes endurecidos en 0002 para este RPC existente.
revoke all on function public.add_activity_participant(uuid, uuid, text) from public, anon;
grant execute on function public.add_activity_participant(uuid, uuid, text) to authenticated;

commit;
