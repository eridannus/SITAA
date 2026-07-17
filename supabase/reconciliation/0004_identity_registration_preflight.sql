-- Preflight de sólo lectura para SITAA 0004.
-- Ejecutar contra el proyecto objetivo antes de revisar/aplicar la migración.
-- La salida contiene únicamente categorías y conteos; no expone PII.

begin transaction read only;

select 'duplicate_identifier_pair' as category, count(*) as affected_rows
from (
  select institutional_id_type, institutional_id_value
  from public.profiles
  where institutional_id_type is not null and institutional_id_value is not null
  group by institutional_id_type, institutional_id_value
  having count(*) > 1
) duplicates
union all
select 'identifier_not_digits', count(*)
from public.profiles
where institutional_id_value is not null and institutional_id_value !~ '^[0-9]+$'
union all
select 'prototype_placeholder_identifier', count(*)
from public.profiles
where institutional_id_value ~* '^(TEST-|SITAA-|000[123]-)'
union all
select 'missing_identity_component', count(*)
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
select 'possible_technical_operator', count(distinct p.id)
from public.profiles p
join public.role_assignments ra on ra.user_id = p.id
where ra.role_code = 'technical_admin'
union all
select 'profile_without_auth_user', count(*)
from public.profiles p
left join auth.users u on u.id = p.id
where u.id is null
union all
select 'auth_email_missing', count(*)
from public.profiles p
join auth.users u on u.id = p.id
where u.email is null
union all
select 'auth_profile_email_mismatch', count(*)
from public.profiles p
join auth.users u on u.id = p.id
where u.email is not null and lower(btrim(u.email)) <> lower(btrim(p.email))
order by category;

-- Resumen de estados Auth que determina el backfill de account_status.
select
  case
    when p.is_active = false then 'will_be_inactive'
    when u.email_confirmed_at is null then 'will_be_pending_verification'
    else 'will_be_active'
  end as projected_account_status,
  count(*) as profiles
from public.profiles p
join auth.users u on u.id = p.id
group by 1
order by 1;

rollback;

-- Remediación previa obligatoria:
-- 1. sustituir identificadores de prueba por valores sintéticos únicos y sólo
--    numéricos, o recrear las cuentas descartables después de 0004;
-- 2. resolver duplicados por (tipo, valor), perfiles incompletos y diferencias
--    Auth/profile mediante revisión humana;
-- 3. no retirar signos ni inventar identificadores con SQL automático;
-- 4. no convertir automáticamente a technical una cuenta que hoy tenga
--    technical_admin: el bootstrap se revisará por separado.
