-- Preflight de sólo lectura para SITAA 0004.
-- Ejecutar contra el proyecto objetivo antes de revisar/aplicar la migración.
-- La salida normal contiene únicamente categorías y conteos; no expone PII.
-- Las categorías marcadas blocking deben quedar en cero antes de aplicar 0004.

begin transaction read only;

with categories as (
  select 'duplicate_identifier_pair'::text as category, count(*)::bigint as affected_rows, true as blocking
  from (
    select institutional_id_type, institutional_id_value
    from public.profiles
    where institutional_id_type is not null and institutional_id_value is not null
    group by institutional_id_type, institutional_id_value
    having count(*) > 1
  ) duplicates
  union all
  select 'identifier_not_digits', count(*), true
  from public.profiles
  where institutional_id_value is not null and institutional_id_value !~ '^[0-9]+$'
  union all
  select 'identifier_too_long', count(*), true
  from public.profiles
  where institutional_id_value is not null and char_length(institutional_id_value) > 50
  union all
  select 'missing_institutional_identity', count(*), true
  from public.profiles
  where person_type is null
     or institutional_id_type is null
     or institutional_id_value is null
     or primary_program_id is null
     or nullif(btrim(full_name), '') is null
     or nullif(btrim(email), '') is null
  union all
  select 'invalid_full_name', count(*), true
  from public.profiles
  where nullif(btrim(full_name), '') is null
     or char_length(regexp_replace(btrim(full_name), '\s+', ' ', 'g')) not between 2 and 200
     or full_name is distinct from regexp_replace(btrim(full_name), '\s+', ' ', 'g')
  union all
  select 'invalid_profile_email', count(*), true
  from public.profiles
  where nullif(btrim(email), '') is null
     or char_length(btrim(email)) > 254
     or email is distinct from lower(btrim(email))
  union all
  select 'invalid_person_type', count(*), true
  from public.profiles
  where person_type is not null and person_type not in ('student', 'worker')
  union all
  select 'person_identifier_mismatch', count(*), true
  from public.profiles
  where not (
    (person_type = 'student' and institutional_id_type = 'student_account')
    or (person_type = 'worker' and institutional_id_type = 'worker_number')
  )
  union all
  select 'missing_academic_program', count(*), true
  from public.profiles p
  left join public.academic_programs ap on ap.id = p.primary_program_id
  where p.primary_program_id is null or ap.id is null
  union all
  select 'profile_without_auth_user', count(*), true
  from public.profiles p
  left join auth.users u on u.id = p.id
  where u.id is null
  union all
  select 'auth_user_without_profile', count(*), true
  from auth.users u
  left join public.profiles p on p.id = u.id
  where p.id is null
  union all
  select 'auth_email_missing', count(*), true
  from public.profiles p
  join auth.users u on u.id = p.id
  where nullif(btrim(u.email), '') is null
  union all
  select 'auth_profile_email_mismatch', count(*), true
  from public.profiles p
  join auth.users u on u.id = p.id
  where nullif(btrim(u.email), '') is not null
    and nullif(btrim(p.email), '') is not null
    and lower(btrim(u.email)) <> lower(btrim(p.email))
  union all
  select 'active_profile_without_confirmed_auth_email', count(*), true
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.is_active = true and u.email_confirmed_at is null
  union all
  select 'unexpected_auth_user_trigger', count(*), true
  from pg_trigger t
  where t.tgrelid = 'auth.users'::regclass and not t.tgisinternal
  union all
  select 'invalid_projected_lifecycle', count(*), true
  from (
    select
      u.id as auth_id,
      case
        when u.id is null then null
        when p.is_active = false then 'inactive'
        when u.email_confirmed_at is null then 'pending_verification'
        else 'active'
      end as projected_status,
      case when p.is_active = true and u.email_confirmed_at is not null then true else false end as projected_is_active,
      case when p.is_active = true and u.email_confirmed_at is not null then u.email_confirmed_at else null end as projected_activated_at,
      case when p.is_active = false then coalesce(p.updated_at, p.created_at, current_timestamp) else null end as projected_deactivated_at
    from public.profiles p
    left join auth.users u on u.id = p.id
  ) projected
  where auth_id is null
     or not (
       (projected_status = 'active' and projected_is_active and projected_activated_at is not null and projected_deactivated_at is null)
       or (projected_status = 'pending_verification' and not projected_is_active and projected_activated_at is null and projected_deactivated_at is null)
       or (projected_status = 'inactive' and not projected_is_active and projected_deactivated_at is not null)
     )
  union all
  select 'possible_technical_operator', count(distinct p.id), false
  from public.profiles p
  join public.role_assignments ra on ra.user_id = p.id
  where ra.role_code = 'technical_admin'
  union all
  select 'inactive_profile_without_timestamps', count(*), false
  from public.profiles p
  where p.is_active = false and p.updated_at is null and p.created_at is null
)
select
  category,
  affected_rows,
  case when blocking then 'blocking' else 'informational' end as classification
from categories
order by category;

-- Inventario obligatorio de triggers no internos en auth.users. 0004 no tiene
-- allow-list de triggers heredados: cualquier fila aquí bloquea la aplicación
-- hasta que se revise su definición y se prepare una restauración exacta.
select
  t.tgname as trigger_name,
  case t.tgenabled
    when 'O' then 'enabled'
    when 'D' then 'disabled'
    when 'R' then 'replica'
    when 'A' then 'always'
    else t.tgenabled::text
  end as enabled_state,
  pg_get_triggerdef(t.oid, true) as trigger_definition,
  format('%I.%I(%s)', n.nspname, p.proname, pg_get_function_identity_arguments(p.oid)) as function_identity
from pg_trigger t
join pg_proc p on p.oid = t.tgfoid
join pg_namespace n on n.oid = p.pronamespace
where t.tgrelid = 'auth.users'::regclass
  and not t.tgisinternal
order by t.tgname;

-- Resumen de estados que 0004 proyectaría. La categoría activa sin confirmación
-- es bloqueante aunque su proyección técnica pueda cumplir pending_verification:
-- no se retira acceso existente de manera silenciosa.
select
  case
    when u.id is null then 'blocked_missing_auth_user'
    when p.is_active = false then 'inactive'
    when u.email_confirmed_at is not null then 'active'
    else 'blocked_active_without_confirmed_email'
  end as projected_account_status,
  count(*) as profiles
from public.profiles p
left join auth.users u on u.id = p.id
group by 1
order by 1;

rollback;

-- Consultas privadas para operador: permanecen deshabilitadas para evitar que
-- la salida ordinaria revele identidad. Copiarlas a una sesión administrativa
-- controlada sólo después de revisar los conteos anteriores.
--
-- Perfiles problemáticos:
-- select p.id, p.email, p.full_name, p.person_type, p.institutional_id_type,
--        p.institutional_id_value, p.primary_program_id, p.is_active,
--        p.created_at, p.updated_at, u.email_confirmed_at
-- from public.profiles p
-- left join auth.users u on u.id = p.id
-- where u.id is null
--    or (p.is_active = true and u.email_confirmed_at is null)
--    or p.institutional_id_value !~ '^[0-9]+$'
--    or char_length(p.institutional_id_value) > 50
--    or p.person_type is null
--    or p.primary_program_id is null
-- order by p.created_at nulls last;
--
-- Auth users sin profile:
-- select u.id, u.email, u.created_at, u.email_confirmed_at,
--        u.raw_user_meta_data, u.raw_app_meta_data
-- from auth.users u
-- left join public.profiles p on p.id = u.id
-- where p.id is null
-- order by u.created_at nulls last;

-- Remediación previa obligatoria:
-- 1. para auth_user_without_profile, inspeccione la cuenta privadamente; elimínela
--    sólo si es desechable y está confirmado, o reconstruya el profile con
--    información institucional verificada. Nunca infiera persona, programa o ID;
-- 2. confirme administrativamente el correo Auth de perfiles activos, desactive
--    explícitamente una cuenta desechable o recréela; nunca asigne fecha ficticia;
-- 3. resuelva duplicados, longitudes, normalización, perfiles incompletos y
--    diferencias Auth/profile mediante revisión humana;
-- 4. no retire signos ni invente identificadores con SQL automático;
-- 5. no convierta automáticamente a technical una cuenta con technical_admin;
-- 6. si existe un trigger no interno en auth.users, documente su definición y
--    prepare una restauración exacta antes de modificar esta migración.
