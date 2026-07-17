-- Preflight de sólo lectura para SITAA 0005.
-- La salida ordinaria contiene exclusivamente categorías y conteos.

begin transaction read only;

with expected_functions as (
  select
    to_regprocedure('public.handle_sitaa_auth_user_created()') handle_oid,
    to_regprocedure('public.complete_own_google_registration(text,text,text,uuid)') completion_oid
), categories as (
  select 'missing_handle_auth_user_created'::text category,
    case when handle_oid is null then 1 else 0 end::bigint affected_rows, true blocking
  from expected_functions
  union all
  select 'missing_complete_google_registration',
    case when completion_oid is null then 1 else 0 end, true from expected_functions
  union all
  select 'unexpected_0004_handle_definition',
    case when handle_oid is null or not (
      pg_get_functiondef(handle_oid) ~* E'if\\s+new\\.email_confirmed_at\\s+is\\s+null\\s+then\\s+raise exception ''sitaa_google_email_not_verified'''
      and position('sitaa_public_technical_account_forbidden' in lower(pg_get_functiondef(handle_oid))) > 0
      and position('sitaa_unverified_technical_email' in lower(pg_get_functiondef(handle_oid))) > 0
      and position('sitaa_public_password_signup_disabled' in lower(pg_get_functiondef(handle_oid))) > 0
      and position('sitaa_unsupported_auth_provider' in lower(pg_get_functiondef(handle_oid))) > 0
      and position('pending_registration' in lower(pg_get_functiondef(handle_oid))) > 0
    ) then 1 else 0 end, true from expected_functions
  union all
  select 'unexpected_0004_completion_definition',
    case when completion_oid is null
      or position('u.email_confirmed_at is not null' in lower(pg_get_functiondef(completion_oid))) = 0
      or position('sitaa_registration_not_pending' in lower(pg_get_functiondef(completion_oid))) = 0
      or position('sitaa_identifier_conflict' in lower(pg_get_functiondef(completion_oid))) = 0
    then 1 else 0 end, true from expected_functions
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
)
select category, affected_rows,
       case when blocking then 'blocking' else 'informational' end classification
from categories order by category;

rollback;
