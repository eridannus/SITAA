-- Consultas de auditoría arquitectónica de SITAA.
-- Sólo lectura: no aplican cambios ni muestran credenciales.
-- Las consultas sobre datos operativos devuelven únicamente conteos agregados.

-- 1. Inventario de tablas públicas y estado RLS.
select
  n.nspname as schema_name,
  c.relname as relation_name,
  c.relkind,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_catalog.pg_class c
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r', 'p', 'v', 'm')
order by c.relkind, c.relname;

-- 2. Conteos generales de objetos públicos.
select 'tables' as object_type, count(*)::bigint as object_count
from pg_catalog.pg_class c
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind in ('r', 'p')
union all
select 'columns', count(*)::bigint
from information_schema.columns
where table_schema = 'public'
union all
select 'constraints', count(*)::bigint
from pg_catalog.pg_constraint con
join pg_catalog.pg_namespace n on n.oid = con.connamespace
where n.nspname = 'public'
union all
select 'indexes', count(*)::bigint
from pg_catalog.pg_indexes
where schemaname = 'public'
union all
select 'functions', count(*)::bigint
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
union all
select 'policies', count(*)::bigint
from pg_catalog.pg_policies
where schemaname = 'public'
union all
select 'user_triggers', count(*)::bigint
from pg_catalog.pg_trigger t
join pg_catalog.pg_class c on c.oid = t.tgrelid
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and not t.tgisinternal
order by object_type;

-- 3. Columnas, nulabilidad, valores predeterminados y metadatos de tipo.
select
  table_name,
  ordinal_position,
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default,
  character_maximum_length,
  numeric_precision,
  numeric_scale,
  datetime_precision
from information_schema.columns
where table_schema = 'public'
order by table_name, ordinal_position;

-- 4. Funciones, firmas, volatilidad, seguridad y configuración de sesión.
select
  p.oid::regprocedure::text as function_signature,
  pg_catalog.pg_get_function_arguments(p.oid) as arguments,
  pg_catalog.pg_get_function_result(p.oid) as result_type,
  case p.provolatile when 'i' then 'immutable' when 's' then 'stable' else 'volatile' end as volatility,
  p.prosecdef as security_definer,
  p.proconfig as session_configuration,
  l.lanname as language
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
join pg_catalog.pg_language l on l.oid = p.prolang
where n.nspname = 'public'
order by p.proname, p.oid::regprocedure::text;

-- 5. Definiciones completas para revisión manual de parámetros, retornos y lógica.
select
  p.oid::regprocedure::text as function_signature,
  pg_catalog.pg_get_functiondef(p.oid) as function_definition
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
order by p.proname, p.oid::regprocedure::text;

-- 6. Nombres de función con más de una firma.
select
  p.proname as function_name,
  count(*) as signature_count,
  array_agg(p.oid::regprocedure::text order by p.oid::regprocedure::text) as signatures
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
group by p.proname
having count(*) > 1
order by p.proname;

-- 7. Funciones SECURITY DEFINER sin search_path explícito.
select
  p.oid::regprocedure::text as function_signature,
  p.proconfig as session_configuration
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosecdef
  and not exists (
    select 1
    from unnest(coalesce(p.proconfig, array[]::text[])) as setting
    where setting like 'search_path=%'
  )
order by function_signature;

-- 8. Dependencias registradas de las funciones públicas.
select
  p.oid::regprocedure::text as function_signature,
  d.deptype,
  pg_catalog.pg_describe_object(d.refclassid, d.refobjid, d.refobjsubid) as referenced_object
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
join pg_catalog.pg_depend d on d.classid = 'pg_proc'::regclass and d.objid = p.oid
where n.nspname = 'public'
order by function_signature, referenced_object;

-- 9. Privilegios efectivos de rutinas; completar la reconciliación de grants.
select
  routine_schema,
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
order by routine_name, grantee, privilege_type;

-- 10. Privilegios efectivos de tablas; no incluye filas operativas.
select
  table_schema,
  table_name,
  grantee,
  privilege_type
from information_schema.table_privileges
where table_schema = 'public'
order by table_name, grantee, privilege_type;

-- 11. Políticas RLS por tabla y comando.
select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_catalog.pg_policies
where schemaname = 'public'
order by tablename, cmd, policyname;

-- 12. Tablas con RLS habilitado que no tienen políticas directas.
select
  n.nspname as schema_name,
  c.relname as table_name
from pg_catalog.pg_class c
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r', 'p')
  and c.relrowsecurity
  and not exists (
    select 1
    from pg_catalog.pg_policies p
    where p.schemaname = n.nspname and p.tablename = c.relname
  )
order by c.relname;

-- 13. Cobertura de comandos RLS por tabla.
select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  count(p.policyname) filter (where p.cmd in ('SELECT', 'ALL')) as select_policies,
  count(p.policyname) filter (where p.cmd in ('INSERT', 'ALL')) as insert_policies,
  count(p.policyname) filter (where p.cmd in ('UPDATE', 'ALL')) as update_policies,
  count(p.policyname) filter (where p.cmd in ('DELETE', 'ALL')) as delete_policies
from pg_catalog.pg_class c
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
left join pg_catalog.pg_policies p on p.schemaname = n.nspname and p.tablename = c.relname
where n.nspname = 'public' and c.relkind in ('r', 'p')
group by c.relname, c.relrowsecurity
order by c.relname;

-- 14. Restricciones completas y sus definiciones.
select
  con.conrelid::regclass::text as table_name,
  con.conname as constraint_name,
  case con.contype
    when 'p' then 'primary_key'
    when 'f' then 'foreign_key'
    when 'u' then 'unique'
    when 'c' then 'check'
    when 'x' then 'exclusion'
    else con.contype::text
  end as constraint_type,
  pg_catalog.pg_get_constraintdef(con.oid, true) as definition
from pg_catalog.pg_constraint con
join pg_catalog.pg_namespace n on n.oid = con.connamespace
where n.nspname = 'public'
order by table_name, constraint_type, constraint_name;

-- 15. Claves foráneas sin un índice válido que empiece por sus columnas.
select
  con.conrelid::regclass::text as table_name,
  con.conname as foreign_key_name,
  pg_catalog.pg_get_constraintdef(con.oid, true) as definition
from pg_catalog.pg_constraint con
join pg_catalog.pg_namespace n on n.oid = con.connamespace
where n.nspname = 'public'
  and con.contype = 'f'
  and not exists (
    select 1
    from pg_catalog.pg_index idx
    where idx.indrelid = con.conrelid
      and idx.indisvalid
      and (idx.indkey::smallint[])[0:cardinality(con.conkey) - 1] = con.conkey
  )
order by table_name, foreign_key_name;

-- 16. Definiciones completas de índices.
select schemaname, tablename, indexname, indexdef
from pg_catalog.pg_indexes
where schemaname = 'public'
order by tablename, indexname;

-- 17. Pares de índices donde las columnas clave de uno son prefijo del otro.
with public_indexes as (
  select
    idx.indexrelid,
    idx.indrelid,
    idx.indkey::smallint[] as key_columns,
    idx.indnkeyatts,
    idx.indpred,
    ci.relname as index_name,
    ct.relname as table_name
  from pg_catalog.pg_index idx
  join pg_catalog.pg_class ci on ci.oid = idx.indexrelid
  join pg_catalog.pg_class ct on ct.oid = idx.indrelid
  join pg_catalog.pg_namespace n on n.oid = ct.relnamespace
  where n.nspname = 'public' and idx.indisvalid
)
select
  left_index.table_name,
  left_index.index_name as shorter_index,
  right_index.index_name as longer_index,
  pg_catalog.pg_get_expr(left_index.indpred, left_index.indrelid) as shorter_predicate,
  pg_catalog.pg_get_expr(right_index.indpred, right_index.indrelid) as longer_predicate
from public_indexes left_index
join public_indexes right_index
  on right_index.indrelid = left_index.indrelid
 and right_index.indexrelid <> left_index.indexrelid
 and left_index.indnkeyatts <= right_index.indnkeyatts
 and left_index.key_columns[0:left_index.indnkeyatts - 1] = right_index.key_columns[0:left_index.indnkeyatts - 1]
where left_index.index_name < right_index.index_name
order by left_index.table_name, shorter_index, longer_index;

-- 18. Triggers de usuario y funciones asociadas.
select
  c.relname as table_name,
  t.tgname as trigger_name,
  p.oid::regprocedure::text as trigger_function,
  pg_catalog.pg_get_triggerdef(t.oid, true) as trigger_definition
from pg_catalog.pg_trigger t
join pg_catalog.pg_class c on c.oid = t.tgrelid
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
join pg_catalog.pg_proc p on p.oid = t.tgfoid
where n.nspname = 'public' and not t.tgisinternal
order by c.relname, t.tgname;

-- 19. Tablas con updated_at pero sin trigger que invoque set_updated_at().
select col.table_name
from information_schema.columns col
where col.table_schema = 'public'
  and col.column_name = 'updated_at'
  and not exists (
    select 1
    from pg_catalog.pg_trigger t
    join pg_catalog.pg_class c on c.oid = t.tgrelid
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    join pg_catalog.pg_proc p on p.oid = t.tgfoid
    where n.nspname = col.table_schema
      and c.relname = col.table_name
      and not t.tgisinternal
      and p.proname = 'set_updated_at'
  )
order by col.table_name;

-- 20. Conteo de grupos con identificador institucional duplicado, sin mostrar valores.
select count(*) as duplicate_institutional_identifier_groups
from (
  select institutional_id_type, institutional_id_value
  from public.profiles
  where institutional_id_type is not null
    and nullif(btrim(institutional_id_value), '') is not null
  group by institutional_id_type, institutional_id_value
  having count(*) > 1
) duplicates;

-- 21. Conteo de asignaciones activas equivalentes duplicadas, sin mostrar usuarios.
select count(*) as duplicate_active_role_assignment_groups
from (
  select user_id, role_code, scope_type, service_area, division_id, program_id, starts_at, ends_at
  from public.role_assignments
  where is_active
  group by user_id, role_code, scope_type, service_area, division_id, program_id, starts_at, ends_at
  having count(*) > 1
) duplicates;

-- 22. Asignaciones con dimensiones residuales o inconsistentes.
select
  count(*) filter (where scope_type = 'own' and (division_id is not null or program_id is not null)) as invalid_own_scope,
  count(*) filter (where scope_type = 'program' and program_id is null) as program_scope_without_program,
  count(*) filter (where scope_type = 'division' and division_id is null) as division_scope_without_division,
  count(*) filter (where scope_type = 'division' and program_id is not null) as division_scope_with_program,
  count(*) filter (where scope_type = 'system' and (division_id is not null or program_id is not null)) as invalid_system_scope
from public.role_assignments;

-- 23. Actividades publicadas con campos operativos incompletos.
select count(*) as incomplete_published_activities
from public.activities a
where a.status_code <> 'draft'
  and (
    nullif(btrim(a.title), '') is null
    or a.scope_type is null
    or a.division_id is null
    or (a.scope_type = 'program' and a.program_id is null)
    or a.activity_type_code is null
    or a.service_type_code is null
    or a.attention_category_code is null
    or a.modality_code is null
    or a.location_type_code is null
    or nullif(btrim(a.location_detail), '') is null
    or a.start_date is null
    or a.start_time is null
    or a.duration_mode is null
    or a.end_date is null
    or a.end_time is null
  );

-- 24. Divergencia entre fecha/hora separadas y timestamps de compatibilidad.
select
  count(*) filter (
    where start_date is not null and start_time is not null
      and starts_at is distinct from ((start_date + start_time) at time zone 'America/Mexico_City')
  ) as divergent_start_timestamps,
  count(*) filter (
    where end_date is not null and end_time is not null
      and ends_at is distinct from ((end_date + end_time) at time zone 'America/Mexico_City')
  ) as divergent_end_timestamps
from public.activities;

-- 25. Semestres asignados que no coinciden con la frontera starts_on vigente.
select count(*) as activities_with_mismatched_semester
from public.activities a
left join lateral (
  select ap.id
  from public.academic_periods ap
  where ap.is_active
    and ap.starts_on is not null
    and ap.starts_on <= a.start_date
  order by ap.starts_on desc
  limit 1
) expected on true
where a.start_date is not null
  and a.academic_period_id is distinct from expected.id;

-- 26. Semestres activos con la misma frontera de inicio.
select count(*) as duplicated_active_semester_boundaries
from (
  select starts_on
  from public.academic_periods
  where is_active and starts_on is not null
  group by starts_on
  having count(*) > 1
) duplicates;

-- 27. Asistencias pendientes cuyo plazo natural ya venció.
select count(*) as expired_pending_attendance
from public.activity_participants participant
join public.activities activity on activity.id = participant.activity_id
where participant.attendance_status = 'pending'
  and activity.status_code <> 'draft'
  and public.activity_attendance_deadline(activity.id) is not null
  and public.activity_attendance_deadline(activity.id) <= now();

-- 28. Combinaciones de estado/fuente y timestamps potencialmente inconsistentes.
select
  count(*) filter (where attendance_status = 'attended' and checked_in_at is null) as attended_without_checkin_time,
  count(*) filter (where attendance_status <> 'attended' and checked_in_at is not null) as non_attended_with_checkin_time,
  count(*) filter (where attendance_source = 'manual' and attendance_updated_by is null) as manual_without_editor,
  count(*) filter (where attendance_source = 'system' and attendance_updated_by is not null) as system_with_editor
from public.activity_participants;

-- 29. Estado agregado de tokens activos, cerrados y vencidos.
select
  count(*) filter (where is_active) as active_tokens,
  count(*) filter (where is_active and expires_at <= now()) as active_but_expired_tokens,
  count(*) filter (where not is_active and closed_at is null) as inactive_without_closed_time,
  count(*) filter (where token_type = 'registration') as reserved_registration_tokens
from public.activity_checkin_tokens;

-- 30. Actividades con referencias de catálogo huérfanas. Sólo conteos.
select 'activity_type_code' as reference_name, count(*) as orphan_count
from public.activities a left join public.activity_types c on c.code = a.activity_type_code
where a.activity_type_code is not null and c.code is null
union all
select 'service_type_code', count(*)
from public.activities a left join public.service_types c on c.code = a.service_type_code
where a.service_type_code is not null and c.code is null
union all
select 'attention_category_code', count(*)
from public.activities a left join public.attention_categories c on c.code = a.attention_category_code
where a.attention_category_code is not null and c.code is null
union all
select 'modality_code', count(*)
from public.activities a left join public.activity_modalities c on c.code = a.modality_code
where a.modality_code is not null and c.code is null
union all
select 'location_type_code', count(*)
from public.activities a left join public.location_types c on c.code = a.location_type_code
where a.location_type_code is not null and c.code is null
union all
select 'status_code', count(*)
from public.activities a left join public.activity_statuses c on c.code = a.status_code
where a.status_code is not null and c.code is null
union all
select 'participant_role_code', count(*)
from public.activity_participants a left join public.participant_roles c on c.code = a.participant_role_code
where a.participant_role_code is not null and c.code is null
union all
select 'role_code', count(*)
from public.role_assignments a left join public.roles c on c.code = a.role_code
where a.role_code is not null and c.code is null
order by reference_name;

-- 31. Conteo de borradores por vía de acceso potencial bajo la política actual.
-- No muestra usuarios ni actividades; ayuda a dimensionar A-01 antes de corregir RLS.
select
  count(*) filter (where responsible_profile_id is distinct from created_by) as drafts_with_distinct_responsible,
  count(*) filter (
    where exists (
      select 1 from public.activity_participants participant
      where participant.activity_id = activity.id
    )
  ) as drafts_with_participants
from public.activities activity
where activity.status_code = 'draft';
