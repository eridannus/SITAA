-- Preflight de sólo lectura para SITAA 0004 (Google OAuth).
-- Ejecutar antes de aplicar 0004. La salida normal contiene sólo conteos.
-- La revisión final no depende de tablas o escrituras de registro previas a OAuth.

begin transaction read only;

with categories as (
  select 'duplicate_identifier_pair'::text category, count(*)::bigint affected_rows, true blocking
  from (
    select institutional_id_type, institutional_id_value from public.profiles
    where institutional_id_type is not null and institutional_id_value is not null
    group by institutional_id_type, institutional_id_value having count(*) > 1
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
       or coalesce(p.updated_at, p.created_at) is null
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
)
select category, affected_rows,
       case when blocking then 'blocking' else 'informational' end classification
from categories order by category;

-- Cualquier trigger no interno debe revisarse antes de aplicar 0004.
select
  t.tgname trigger_name,
  pg_get_triggerdef(t.oid, true) trigger_definition,
  format('%I.%I(%s)', n.nspname, p.proname,
         pg_get_function_identity_arguments(p.oid)) function_identity
from pg_trigger t
join pg_proc p on p.oid = t.tgfoid
join pg_namespace n on n.oid = p.pronamespace
where t.tgrelid = 'auth.users'::regclass and not t.tgisinternal
order by t.tgname;

-- Proyección determinista: 0004 conserva el booleano vivo existente.
select case when p.is_active then 'active' else 'inactive' end projected_account_status,
       count(*) profiles
from public.profiles p group by 1 order by 1;

rollback;

-- Consultas privadas para remediación deliberada; no forman parte de la salida
-- ordinaria porque muestran PII.
--
-- Auth users sin profile:
-- select u.id, u.email, u.created_at, u.raw_app_meta_data
-- from auth.users u left join public.profiles p on p.id = u.id
-- where p.id is null order by u.created_at;
--
-- Profiles sin Auth user:
-- select p.id, p.email, p.full_name, p.created_at
-- from public.profiles p left join auth.users u on u.id = p.id
-- where u.id is null order by p.created_at;
--
-- Remediación: inspeccionar privadamente; eliminar sólo cuentas sintéticas
-- confirmadas como desechables. En cualquier otro caso, reconstruir desde
-- información institucional verificada, sin inferir persona, programa ni ID.
