-- Verificación posterior de SITAA 0002.
-- Archivo de sólo lectura: las consultas de desviaciones deben devolver cero filas.

begin transaction read only;

-- 1. Función pública y guards internos: todos deben existir.
select
  to_regprocedure('public.publish_activity(uuid)') is not null as publish_activity_exists,
  to_regprocedure('public.validate_activity_scheduled_state()') is not null as scheduled_validator_exists,
  to_regprocedure('public.guard_activity_participant_pending_deadline()') is not null
    as participant_pending_guard_exists;

-- 2. Los dos triggers deben devolver una fila habilitada cada uno.
select c.relname as table_name, t.tgname, t.tgenabled, pg_get_triggerdef(t.oid, true) as definition
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and (
    (c.relname = 'activities' and t.tgname = 'validate_activities_scheduled_state')
    or (
      c.relname = 'activity_participants'
      and t.tgname = 'guard_activity_participants_pending_deadline'
    )
  )
  and not t.tgisinternal;

-- 3. Revisar helpers y políticas; la rama draft debe exigir created_by = auth.uid().
select p.oid::regprocedure as helper, pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('can_read_activity', 'can_edit_activity', 'can_update_activity_base', 'can_delete_activity')
order by p.proname;

select tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public'
  and (
    (tablename = 'activities' and policyname = 'Users can read permitted activities')
    or (tablename = 'activity_participants' and policyname = 'Users can read permitted activity participants')
  )
order by tablename, policyname;

-- Las cuatro columnas deben ser true.
select
  position('status_code = ''draft''' in pg_get_functiondef('public.can_read_activity(uuid)'::regprocedure)) > 0
    and position('created_by = auth.uid()' in pg_get_functiondef('public.can_read_activity(uuid)'::regprocedure)) > 0
    as can_read_draft_creator_only,
  position('status_code = ''draft''' in pg_get_functiondef('public.can_edit_activity(uuid)'::regprocedure)) > 0
    and position('created_by = auth.uid()' in pg_get_functiondef('public.can_edit_activity(uuid)'::regprocedure)) > 0
    as can_edit_draft_creator_only,
  position('status_code = ''draft''' in pg_get_functiondef('public.can_update_activity_base(uuid)'::regprocedure)) > 0
    and position('created_by = auth.uid()' in pg_get_functiondef('public.can_update_activity_base(uuid)'::regprocedure)) > 0
    as can_update_draft_creator_only,
  position('status_code = ''draft''' in pg_get_functiondef('public.can_delete_activity(uuid)'::regprocedure)) > 0
    and position('created_by = auth.uid()' in pg_get_functiondef('public.can_delete_activity(uuid)'::regprocedure)) > 0
    as can_delete_draft_creator_only;


-- 4. La transición directa y publish_activity deben exigir creador y permiso actual.
select
  position('new.created_by is distinct from old.created_by' in lower(
    pg_get_functiondef('public.validate_activity_scheduled_state()'::regprocedure)
  )) > 0 as creator_is_immutable,
  position('old.status_code <> ''draft'' and new.status_code = ''draft''' in lower(
    pg_get_functiondef('public.validate_activity_scheduled_state()'::regprocedure)
  )) > 0 as published_cannot_return_to_draft,
  position('can_create_activity' in lower(
    pg_get_functiondef('public.validate_activity_scheduled_state()'::regprocedure)
  )) > 0
  and position('is distinct from true' in lower(
    pg_get_functiondef('public.validate_activity_scheduled_state()'::regprocedure)
  )) > 0 as direct_publish_rechecks_permission,
  position('target_activity.created_by is distinct from auth.uid()' in lower(
    pg_get_functiondef('public.publish_activity(uuid)'::regprocedure)
  )) > 0 as rpc_uses_null_safe_creator_check,
  position('is distinct from true' in lower(
    pg_get_functiondef('public.publish_activity(uuid)'::regprocedure)
  )) > 0 as rpc_denies_null_permission;
-- 5. Ambas RPC de asistencia deben validar la frontera inclusiva y usar el error acordado.
select p.oid::regprocedure as routine,
  position('activity_attendance_deadline' in pg_get_functiondef(p.oid)) > 0 as checks_deadline,
  position('natural_deadline <= now()' in lower(pg_get_functiondef(p.oid))) > 0
    as exact_deadline_is_expired,
  position('La ventana de asistencia ya terminó; el estado Pendiente ya no está disponible.' in pg_get_functiondef(p.oid)) > 0
    as has_expected_error
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('update_activity_participant_attendance', 'update_activity_participants_attendance_bulk')
order by p.proname;

-- 6. El guard directo de participantes debe usar la misma frontera y error.
select
  position('new.attendance_status is distinct from old.attendance_status' in lower(definition)) > 0
    as only_guards_status_transition,
  position('natural_deadline <= now()' in lower(definition)) > 0 as exact_deadline_is_expired,
  position('La ventana de asistencia ya terminó; el estado Pendiente ya no está disponible.' in definition) > 0
    as has_expected_error
from (
  select pg_get_functiondef('public.guard_activity_participant_pending_deadline()'::regprocedure) as definition
) guard;

-- 7. No debe existir una fila scheduled incompatible.
select a.id
from public.activities a
left join lateral public.get_academic_period_for_date(a.start_date) expected_period on true
where a.status_code = 'scheduled'
  and (
    nullif(btrim(a.title), '') is null
    or length(a.title) > 200
    or length(coalesce(a.description, '')) > 5000
    or a.scope_type is null
    or a.scope_type not in ('program', 'division')
    or (
      a.scope_type = 'program'
      and not exists (
        select 1 from public.academic_programs ap
        where ap.id = a.program_id and ap.division_id = a.division_id
      )
    )
    or (a.scope_type = 'division' and (a.division_id is null or a.program_id is not null))
    or a.activity_type_code is null
    or a.service_type_code is null
    or a.attention_category_code is null
    or a.modality_code is null
    or a.location_type_code is null
    or nullif(btrim(a.location_detail), '') is null
    or a.start_date is null or a.start_time is null
    or a.end_date is null or a.end_time is null
    or a.duration_mode is null or a.duration_mode not in ('one_hour', 'two_hours', 'custom')
    or (
      a.start_date is not null and a.start_time is not null
      and a.end_date is not null and a.end_time is not null
      and (a.end_date + a.end_time) <= (a.start_date + a.start_time)
    )
    or (
      a.duration_mode = 'one_hour'
      and (a.end_date + a.end_time) <> (a.start_date + a.start_time + interval '1 hour')
    )
    or (
      a.duration_mode = 'two_hours'
      and (a.end_date + a.end_time) <> (a.start_date + a.start_time + interval '2 hours')
    )
    or (a.modality_code = 'online' and a.location_type_code <> 'online_space')
    or (a.modality_code <> 'online' and a.location_type_code = 'online_space')
    or a.academic_period_id is distinct from expected_period.id
  );

-- 8. EXECUTE: las tres consultas de desviaciones deben devolver cero filas.
select p.oid::regprocedure as unexpectedly_executable_by_anon
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and has_function_privilege('anon', p.oid, 'EXECUTE');

select distinct p.oid::regprocedure as unexpectedly_executable_by_public
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
where n.nspname = 'public'
  and acl.grantee = 0
  and acl.privilege_type = 'EXECUTE';

-- authenticated conserva las 30 firmas baseline y publish_activity; los dos
-- guards internos no requieren EXECUTE de cliente.
select p.oid::regprocedure as missing_authenticated_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname not in (
    'validate_activity_scheduled_state',
    'guard_activity_participant_pending_deadline'
  )
  and not has_function_privilege('authenticated', p.oid, 'EXECUTE');

select
  has_function_privilege('authenticated', 'public.publish_activity(uuid)', 'EXECUTE') as authenticated_can_publish,
  has_function_privilege('service_role', 'public.publish_activity(uuid)', 'EXECUTE') as service_role_can_publish,
  not has_function_privilege('anon', 'public.publish_activity(uuid)', 'EXECUTE') as anon_cannot_publish;

-- 9. anon: resultado esperado, una sola fila system_health/SELECT.
select table_name, privilege_type
from information_schema.table_privileges
where table_schema = 'public' and grantee = 'anon'
order by table_name, privilege_type;

-- 10. Contrato directo exacto de authenticated: debe devolver cero filas.
with expected(table_name, privilege_type) as (
  values
    ('academic_periods', 'SELECT'), ('academic_programs', 'SELECT'),
    ('activity_modalities', 'SELECT'), ('activity_statuses', 'SELECT'),
    ('activity_types', 'SELECT'), ('attention_categories', 'SELECT'),
    ('divisions', 'SELECT'), ('location_types', 'SELECT'),
    ('participant_roles', 'SELECT'), ('roles', 'SELECT'), ('service_types', 'SELECT'),
    ('system_health', 'SELECT'),
    ('profiles', 'SELECT'), ('profiles', 'UPDATE'),
    ('role_assignments', 'SELECT'),
    ('activities', 'SELECT'), ('activities', 'INSERT'), ('activities', 'UPDATE'), ('activities', 'DELETE'),
    ('activity_participants', 'SELECT'), ('activity_participants', 'INSERT'),
    ('activity_participants', 'UPDATE'), ('activity_participants', 'DELETE')
), actual as (
  select table_name, privilege_type
  from information_schema.table_privileges
  where table_schema = 'public' and grantee = 'authenticated'
), missing as (
  select 'missing'::text as deviation, e.table_name, e.privilege_type from expected e
  except
  select 'missing', a.table_name, a.privilege_type from actual a
), extra as (
  select 'extra'::text as deviation, a.table_name, a.privilege_type from actual a
  except
  select 'extra', e.table_name, e.privilege_type from expected e
), deviations as (
  select * from missing
  union all
  select * from extra
)
select * from deviations order by deviation, table_name, privilege_type;

-- Todas las columnas deben ser false.
select
  has_table_privilege('authenticated', 'public.activity_checkin_tokens', 'SELECT')
    or has_table_privilege('authenticated', 'public.activity_checkin_tokens', 'INSERT')
    or has_table_privilege('authenticated', 'public.activity_checkin_tokens', 'UPDATE')
    or has_table_privilege('authenticated', 'public.activity_checkin_tokens', 'DELETE')
    as authenticated_has_token_table_access,
  has_table_privilege('authenticated', 'public.activities', 'TRUNCATE')
    or has_table_privilege('authenticated', 'public.activities', 'REFERENCES')
    or has_table_privilege('authenticated', 'public.activities', 'TRIGGER')
    or has_table_privilege('authenticated', 'public.activities', 'MAINTAIN')
    as authenticated_has_activity_utility_privilege,
  has_table_privilege('authenticated', 'public.activity_participants', 'TRUNCATE')
    or has_table_privilege('authenticated', 'public.activity_participants', 'REFERENCES')
    or has_table_privilege('authenticated', 'public.activity_participants', 'TRIGGER')
    or has_table_privilege('authenticated', 'public.activity_participants', 'MAINTAIN')
    as authenticated_has_participant_utility_privilege;

-- Debe devolver cero filas: ningún rol cliente conserva privilegios utilitarios
-- sobre ninguna tabla pública. MAINTAIN se verifica fuera de information_schema.
select roles.role_name, c.relname as table_name, privileges.privilege_name
from (values ('anon'::text), ('authenticated'::text)) roles(role_name)
cross join pg_class c
join pg_namespace n on n.oid = c.relnamespace
cross join (values
  ('TRUNCATE'::text), ('REFERENCES'::text), ('TRIGGER'::text), ('MAINTAIN'::text)
) privileges(privilege_name)
where n.nspname = 'public'
  and c.relkind in ('r', 'p', 'v', 'm', 'f')
  and has_table_privilege(roles.role_name, c.oid, privileges.privilege_name)
order by roles.role_name, c.relname, privileges.privilege_name;

-- 11. Secuencia: las seis celdas deben ser false.
select role_name,
  has_sequence_privilege(role_name, 'public.system_health_id_seq', 'SELECT') as can_select,
  has_sequence_privilege(role_name, 'public.system_health_id_seq', 'UPDATE') as can_update,
  has_sequence_privilege(role_name, 'public.system_health_id_seq', 'USAGE') as can_use
from (values ('anon'::text), ('authenticated'::text)) roles(role_name);

-- 12. A-02 diferido: debe ser true; no concede acceso, sólo confirma que 0002 no
-- retiró technical_admin de la autorización sobre contenido publicado.
select position(
  'technical_admin'
  in pg_get_functiondef('public.can_manage_activity(text,uuid,uuid,text)'::regprocedure)
) > 0 as technical_admin_intentionally_preserved;

rollback;
