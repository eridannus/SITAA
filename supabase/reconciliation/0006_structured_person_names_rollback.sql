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

-- Cerrar explícitamente la superficie 0006 antes de restaurar permisos post-0005.
revoke all on function public.complete_own_google_registration(text,text,text,text,text,uuid)
  from public, anon, authenticated;
revoke execute on function public.complete_own_google_registration(text,text,text,uuid)
  from public, anon, authenticated;
revoke update on public.profiles from authenticated;
revoke update (full_name, first_names, paternal_surname, maternal_surname)
  on public.profiles from authenticated;

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

revoke update on public.profiles from authenticated;
revoke update (full_name, first_names, paternal_surname, maternal_surname) on public.profiles from authenticated;
grant update (full_name) on public.profiles to authenticated;

drop trigger normalize_sitaa_profile_names on public.profiles;
drop function public.normalize_sitaa_profile_names();

-- Autoverificación: el rollback sólo confirma si reconstruyó el contrato post-0005.
do $verify_rollback$
declare
  old_oid oid := to_regprocedure('public.complete_own_google_registration(text,text,text,uuid)');
  handler_oid oid := to_regprocedure('public.handle_sitaa_auth_user_created()');
  enforcer_oid oid := to_regprocedure('public.enforce_sitaa_profile_identity()');
  definition text;
begin
  if old_oid is null
     or to_regprocedure('public.complete_own_google_registration(text,text,text,text,text,uuid)') is not null
     or to_regprocedure('public.normalize_sitaa_profile_names()') is not null then
    raise exception 'Rollback 0006: las firmas de función no coinciden con post-0005.' using errcode = 'P0001';
  end if;

  if not has_function_privilege('authenticated', old_oid, 'EXECUTE')
     or has_function_privilege('anon', old_oid, 'EXECUTE')
     or exists (
       select 1 from pg_proc p
       cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
       where p.oid = old_oid and acl.grantee = 0 and acl.privilege_type = 'EXECUTE'
     ) then
    raise exception 'Rollback 0006: los privilegios de finalización no coinciden con post-0005.' using errcode = 'P0001';
  end if;

  definition := lower(pg_get_functiondef(old_oid));
  if definition not like '%security definer%'
     or definition not like '%requested_full_name%'
     or definition not like '%sitaa_google_identity_required%'
     or definition not like '%sitaa_google_identity_email_mismatch%'
     or definition not like '%sitaa_google_email_not_verified%'
     or definition not like '%sitaa_registration_not_pending%'
     or definition like '%requested_first_names%' then
    raise exception 'Rollback 0006: la finalización no coincide semánticamente con post-0005.' using errcode = 'P0001';
  end if;

  if has_table_privilege('authenticated', 'public.profiles', 'UPDATE')
     or not has_column_privilege('authenticated', 'public.profiles', 'full_name', 'UPDATE')
     or exists (
       select 1 from pg_attribute a
       where a.attrelid = 'public.profiles'::regclass and a.attnum > 0 and not a.attisdropped
         and a.attname <> 'full_name'
         and has_column_privilege('authenticated', 'public.profiles', a.attname, 'UPDATE')
     ) then
    raise exception 'Rollback 0006: los privilegios de profiles no coinciden con post-0005.' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'profiles'
      and t.tgname = 'normalize_sitaa_profile_names' and not t.tgisinternal
  ) then
    raise exception 'Rollback 0006: permanece el trigger de normalización 0006.' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname in (
        'profiles_first_names_check', 'profiles_paternal_surname_check',
        'profiles_maternal_surname_check', 'profiles_structured_full_name_check'
      )
  ) or not exists (
    select 1 from pg_constraint
    where conrelid = 'public.profiles'::regclass and conname = 'profiles_account_identity_check'
      and lower(pg_get_constraintdef(oid)) like '%pending_registration%'
      and lower(pg_get_constraintdef(oid)) like '%full_name is not null%'
  ) then
    raise exception 'Rollback 0006: las restricciones no coinciden con post-0005.' using errcode = 'P0001';
  end if;

  definition := lower(pg_get_functiondef(enforcer_oid));
  if enforcer_oid is null
     or definition not like '%to_jsonb(new) - ''full_name'' - ''updated_at''%'
     or definition not like '%sólo puedes actualizar tu nombre completo.%'
     or definition like '%first_names%' then
    raise exception 'Rollback 0006: enforce_sitaa_profile_identity no coincide con post-0005.' using errcode = 'P0001';
  end if;

  definition := lower(pg_get_functiondef(handler_oid));
  if handler_oid is null
     or definition not like '%if is_google then%'
     or definition not like '%provisional_name%'
     or definition not like '%sitaa_unverified_technical_email%'
     or definition like '%sitaa_google_email_not_verified%' then
    raise exception 'Rollback 0006: handle_sitaa_auth_user_created no coincide con post-0005.' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace join pg_proc p on p.oid = t.tgfoid
    where n.nspname = 'auth' and c.relname = 'users' and t.tgname = 'on_sitaa_auth_user_created'
      and p.proname = 'handle_sitaa_auth_user_created' and not t.tgisinternal
  ) or not exists (
    select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace join pg_proc p on p.oid = t.tgfoid
    where n.nspname = 'auth' and c.relname = 'users' and t.tgname = 'on_sitaa_auth_user_email_changed'
      and p.proname = 'sync_sitaa_profile_email_from_auth' and not t.tgisinternal
  ) or not exists (
    select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace join pg_proc p on p.oid = t.tgfoid
    where n.nspname = 'public' and c.relname = 'profiles' and t.tgname = 'enforce_sitaa_profile_identity'
      and p.proname = 'enforce_sitaa_profile_identity' and not t.tgisinternal
  ) then
    raise exception 'Rollback 0006: faltan triggers requeridos por post-0005.' using errcode = 'P0001';
  end if;
end;
$verify_rollback$;

commit;

-- Los valores estructurados no se borran. Si existieron altas después de 0006,
-- revisar el flujo de aplicación antes de operar con la versión post-0005.
