-- SEM-01 / 0011: preflight independiente de sólo lectura.
-- Ejecutar manualmente y revisar todas las categorías antes de aplicar 0011.

begin;
set transaction read only;
set local statement_timeout = '120s';
set local lock_timeout = '5s';
set local timezone = 'UTC';
set local datestyle = 'ISO, YMD';
set local search_path = pg_catalog, public;

with
expected_period_columns(column_name, ordinal_position, data_type, is_nullable, column_default) as (
  values
    ('id', 1, 'uuid', 'NO', 'gen_random_uuid()'),
    ('code', 2, 'text', 'NO', ''),
    ('name', 3, 'text', 'NO', ''),
    ('starts_on', 4, 'date', 'YES', ''),
    ('ends_on', 5, 'date', 'YES', ''),
    ('is_active', 6, 'boolean', 'NO', 'true'),
    ('sort_order', 7, 'integer', 'NO', '0'),
    ('created_at', 8, 'timestamp with time zone', 'NO', 'now()'),
    ('updated_at', 9, 'timestamp with time zone', 'NO', 'now()')
),
actual_period_columns as (
  select column_name, ordinal_position, data_type, is_nullable, coalesce(column_default, '')
  from information_schema.columns
  where table_schema = 'public' and table_name = 'academic_periods'
),
expected_period_constraints(constraint_name, constraint_type, definition) as (
  values
    ('academic_periods_code_key', 'u', 'UNIQUE (code)'),
    ('academic_periods_pkey', 'p', 'PRIMARY KEY (id)')
),
actual_period_constraints as (
  select constraint_info.conname, constraint_info.contype::text,
    pg_catalog.pg_get_constraintdef(constraint_info.oid, true)
  from pg_catalog.pg_constraint constraint_info
  where constraint_info.conrelid = 'public.academic_periods'::regclass
),
expected_period_seed(code, name, starts_on, ends_on, is_active, sort_order, created_at, updated_at) as (
  values
    ('pilot'::text, 'Periodo piloto'::text, null::date, null::date, false, 0,
      timestamptz '2026-07-07 21:34:09.731881+00', timestamptz '2026-07-08 22:04:07.767746+00'),
    ('2026-1', '2026-1', date '2025-08-11', date '2025-11-28', true, 202601,
      timestamptz '2026-07-08 22:04:07.767746+00', timestamptz '2026-07-08 22:04:07.767746+00'),
    ('2026-2', '2026-2', date '2026-02-03', date '2026-05-29', true, 202602,
      timestamptz '2026-07-08 22:04:07.767746+00', timestamptz '2026-07-08 22:04:07.767746+00'),
    ('2027-1', '2027-1', date '2026-08-10', date '2026-11-27', true, 202701,
      timestamptz '2026-07-08 22:04:07.767746+00', timestamptz '2026-07-08 22:04:07.767746+00'),
    ('2027-2', '2027-2', date '2027-02-02', date '2027-05-28', true, 202702,
      timestamptz '2026-07-08 22:04:07.767746+00', timestamptz '2026-07-08 22:04:07.767746+00')
),
actual_period_seed as (
  select code, name, starts_on, ends_on, is_active, sort_order, created_at, updated_at
  from public.academic_periods
),
activity_resolution as (
  select
    activity.status_code,
    activity.academic_period_id,
    resolved.id as resolved_period_id
  from public.activities activity
  left join lateral public.get_academic_period_for_date(activity.start_date) resolved on true
),
sem01_activity_resolution as (
  select
    activity.status_code,
    activity.academic_period_id,
    current_period.id as current_resolution,
    sem01_resolution.id as proposed_resolution
  from public.activities activity
  left join lateral public.get_academic_period_for_date(activity.start_date) current_period on true
  left join lateral (
    with eligible as (
      select period.*
      from public.academic_periods period
      where period.is_active and period.code <> 'pilot'
        and period.starts_on is not null and period.ends_on is not null
    ),
    candidate as (
      select period.* from eligible period
      where period.starts_on <= activity.start_date
      order by period.starts_on desc, period.code desc, period.id desc
      limit 1
    )
    select candidate.id
    from candidate
    where activity.start_date <= coalesce((
      select successor.starts_on - 1
      from eligible successor
      where (successor.starts_on, successor.code, successor.id)
        > (candidate.starts_on, candidate.code, candidate.id)
      order by successor.starts_on, successor.code, successor.id
      limit 1
    ), candidate.ends_on)
  ) sem01_resolution on true
),
results(category, kind, observed_count, expected_count, detail) as (
  select 'baseline_public_tables', 'blocking',
    (select count(*) from pg_catalog.pg_class relation
      join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
      where namespace.nspname = 'public' and relation.relkind in ('r', 'p')),
    19::bigint, 'Mapa canónico post-0010 de tablas públicas'
  union all
  select 'baseline_public_columns', 'blocking',
    (select count(*) from information_schema.columns where table_schema = 'public'),
    183, 'Mapa canónico post-0010 de columnas públicas'
  union all
  select 'baseline_public_constraints', 'blocking',
    (select count(*) from pg_catalog.pg_constraint constraint_info
      join pg_catalog.pg_class relation on relation.oid = constraint_info.conrelid
      join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
      where namespace.nspname = 'public'),
    96, 'Mapa canónico post-0010 de restricciones públicas'
  union all
  select 'baseline_public_indexes', 'blocking',
    (select count(*) from pg_catalog.pg_indexes where schemaname = 'public'),
    48, 'Mapa canónico post-0010 de índices públicos'
  union all
  select 'baseline_public_triggers', 'blocking',
    (select count(*) from pg_catalog.pg_trigger trigger_info
      join pg_catalog.pg_class relation on relation.oid = trigger_info.tgrelid
      join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
      where namespace.nspname = 'public' and not trigger_info.tgisinternal),
    13, 'Mapa canónico post-0010 de triggers públicos'
  union all
  select 'baseline_public_functions', 'blocking',
    (select count(*) from pg_catalog.pg_proc routine
      join pg_catalog.pg_namespace namespace on namespace.oid = routine.pronamespace
      where namespace.nspname = 'public' and routine.prokind = 'f'),
    60, 'Mapa canónico post-0010 de funciones públicas'
  union all
  select 'baseline_public_policies', 'blocking',
    (select count(*) from pg_catalog.pg_policy policy
      join pg_catalog.pg_class relation on relation.oid = policy.polrelid
      join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
      where namespace.nspname = 'public'),
    25, 'Mapa canónico post-0010 de políticas RLS'
  union all
  select 'academic_period_column_map', 'blocking',
    (select count(*) from (
      (select * from expected_period_columns except select * from actual_period_columns)
      union all
      (select * from actual_period_columns except select * from expected_period_columns)
    ) difference),
    0, 'Las nueve columnas deben coincidir exactamente'
  union all
  select 'academic_period_constraint_map', 'blocking',
    (select count(*) from (
      (select * from expected_period_constraints except select * from actual_period_constraints)
      union all
      (select * from actual_period_constraints except select * from expected_period_constraints)
    ) difference),
    0, 'Antes de 0011 sólo existen PK y unicidad de code'
  union all
  select 'academic_period_index_map', 'blocking',
    (select count(*) from pg_catalog.pg_indexes
      where schemaname = 'public' and tablename = 'academic_periods'
        and indexname not in ('academic_periods_code_key', 'academic_periods_pkey')),
    0, 'No debe existir un índice SEM-01 previo'
  union all
  select 'academic_period_trigger_map', 'blocking',
    (select count(*) from pg_catalog.pg_trigger
      where tgrelid = 'public.academic_periods'::regclass and not tgisinternal),
    0, 'La línea base no tiene triggers de academic_periods'
  union all
  select 'academic_period_seed_map', 'blocking',
    (select count(*) from (
      (select * from expected_period_seed except select * from actual_period_seed)
      union all
      (select * from actual_period_seed except select * from expected_period_seed)
    ) difference),
    0, 'Cinco filas canónicas sin exponer UUID ni datos operativos'
  union all
  select 'academic_period_id_code_map', 'blocking',
    case when (
      select md5(string_agg(
        period.id::text || '|' || period.code,
        E'\n' order by period.code collate "C"
      ))
      from public.academic_periods period
    ) = '8af9fc114f31320519e894770823cc1d' then 0 else 1 end,
    0, 'La huella sanitizada conserva el UUID histórico asociado a cada código'
  union all
  select 'academic_period_identity_and_timestamps', 'blocking',
    (select count(*) from public.academic_periods
      where id is null or created_at is null or updated_at is null or updated_at < created_at),
    0, 'UUID y timestamps de todas las filas deben estar presentes y coherentes'
  union all
  select 'pilot_exact_preservation', 'blocking',
    (select count(*) from public.academic_periods
      where code = 'pilot'
        and (name, starts_on, ends_on, is_active, sort_order)
          is distinct from ('Periodo piloto'::text, null::date, null::date, false, 0)),
    0, 'pilot debe conservarse inactivo y con fechas nulas'
  union all
  select 'ordinary_period_integrity', 'blocking',
    (select count(*) from public.academic_periods
      where code <> 'pilot' and (
        code !~ '^[0-9]{4}-[12]$' or starts_on is null or ends_on is null or starts_on > ends_on
      )),
    0, 'Las filas ordinarias actuales deben aceptar las nuevas restricciones'
  union all
  select 'active_period_overlap', 'blocking',
    (select count(*) from public.academic_periods left_period
      join public.academic_periods right_period
        on left_period.id < right_period.id
       and left_period.is_active and right_period.is_active
       and left_period.code <> 'pilot' and right_period.code <> 'pilot'
       and daterange(left_period.starts_on, left_period.ends_on, '[]')
         && daterange(right_period.starts_on, right_period.ends_on, '[]')),
    0, 'No debe existir traslape activo previo'
  union all
  select 'active_equal_starts_on', 'blocking',
    (select count(*) from (
      select starts_on from public.academic_periods
      where is_active and code <> 'pilot'
      group by starts_on having count(*) > 1
    ) duplicated),
    0, 'No debe existir frontera inicial activa duplicada'
  union all
  select 'resolver_definition', 'blocking',
    case when md5(btrim(regexp_replace(pg_catalog.pg_get_functiondef(
      'public.get_academic_period_for_date(date)'::regprocedure
    ), E'\\s+', ' ', 'g'))) = 'dd112ebab92161480ffedfe0d094b297' then 0 else 1 end,
    0, 'Definición exacta reconciliada post-0010'
  union all
  select 'publication_definition', 'blocking',
    case when md5(btrim(regexp_replace(pg_catalog.pg_get_functiondef(
      'public.publish_activity(uuid)'::regprocedure
    ), E'\\s+', ' ', 'g'))) = '3351926e90e96d49774ae2fed556586d' then 0 else 1 end,
    0, 'Definición exacta reconciliada post-0010'
  union all
  select 'activity_validator_definition', 'blocking',
    case when md5(btrim(regexp_replace(pg_catalog.pg_get_functiondef(
      'public.validate_activity_scheduled_state()'::regprocedure
    ), E'\\s+', ' ', 'g'))) = '940439094000f003c6e7a531dd46a7d7' then 0 else 1 end,
    0, 'Definición exacta reconciliada post-0010'
  union all
  select 'visible_cards_definition', 'blocking',
    case when md5(btrim(regexp_replace(pg_catalog.pg_get_functiondef(
      'public.get_visible_activity_cards()'::regprocedure
    ), E'\\s+', ' ', 'g'))) = '81b01c213f2ba8d3644459ce67f01da5' then 0 else 1 end,
    0, 'La proyección de tarjetas no será reemplazada'
  union all
  select 'activity_period_fk', 'blocking',
    case when exists (
      select 1 from pg_catalog.pg_constraint
      where conrelid = 'public.activities'::regclass
        and conname = 'activities_academic_period_id_fkey'
        and pg_catalog.pg_get_constraintdef(oid, true) =
          'FOREIGN KEY (academic_period_id) REFERENCES academic_periods(id)'
    ) then 0 else 1 end,
    0, 'La FK restrictiva actual debe permanecer'
  union all
  select 'activity_trigger_contract', 'blocking',
    (select count(*) from pg_catalog.pg_trigger
      where tgrelid = 'public.activities'::regclass and not tgisinternal
        and tgname not in (
          'enforce_activity_writer_integrity_b2a',
          'set_activities_updated_at',
          'validate_activities_scheduled_state'
        )),
    0, 'No debe existir un trigger de actividad no reconciliado'
  union all
  select 'stored_activity_attribution_consistency', 'blocking',
    (select count(*) from activity_resolution
      where academic_period_id is not null
        and academic_period_id is distinct from resolved_period_id),
    0, 'Atribuciones almacenadas deben concordar con el calendario vigente'
  union all
  select 'non_draft_activity_consistency', 'blocking',
    (select count(*) from activity_resolution
      where status_code <> 'draft'
        and academic_period_id is distinct from resolved_period_id),
    0, 'Ninguna actividad no borrador puede partir inconsistente'
  union all
  select 'sem01_resolver_existing_attribution_impact', 'blocking',
    (select count(*) from sem01_activity_resolution
      where (academic_period_id is not null
          and academic_period_id is distinct from proposed_resolution)
        or (academic_period_id is not null
          and current_resolution is distinct from proposed_resolution)
        or (status_code <> 'draft'
          and academic_period_id is distinct from current_resolution)
        or (status_code <> 'draft'
          and current_resolution is distinct from proposed_resolution)),
    0, 'La semántica nueva no puede cambiar atribuciones existentes al aplicarse'
  union all
  select 'sem01_resolver_resolved_draft_loss_or_switch', 'blocking',
    (select count(*) from sem01_activity_resolution
      where status_code = 'draft'
        and academic_period_id is null
        and current_resolution is not null
        and proposed_resolution is distinct from current_resolution),
    0, 'Un borrador resoluble sin atribución no puede perder ni cambiar su resolución'
  union all
  select 'unassigned_unresolved_drafts', 'informational',
    (select count(*) from activity_resolution
      where status_code = 'draft' and academic_period_id is null and resolved_period_id is null),
    null::bigint, 'Conteo sanitizado de borradores potencialmente habilitables'
  union all
  select 'academic_period_reference_count', 'informational',
    (select count(*) from public.activities where academic_period_id is not null),
    null::bigint, 'Conteo agregado; no expone filas de actividad'
  union all
  select 'rls_and_reference_policy', 'blocking',
    case when (
      select relation.relrowsecurity and not relation.relforcerowsecurity
      from pg_catalog.pg_class relation
      where relation.oid = 'public.academic_periods'::regclass
    ) and exists (
      select 1 from pg_catalog.pg_policy policy
      where policy.polrelid = 'public.academic_periods'::regclass
        and policy.polname = 'Authenticated users can read academic periods'
        and policy.polcmd = 'r'
        and policy.polroles = array[(select oid from pg_catalog.pg_roles where rolname = 'authenticated')]
    ) then 0 else 1 end,
    0, 'RLS y lectura de referencia autenticada deben coincidir'
  union all
  select 'academic_period_acl', 'blocking',
    case when (
      select md5(relation.relacl::text)
      from pg_catalog.pg_class relation
      where relation.oid = 'public.academic_periods'::regclass
    ) = '0382c9d760805ac4a3cfd8d6ca8a6951' then 0 else 1 end,
    0, 'ACL exacta relevante antes de retirar DML directo de service_role'
  union all
  select 'resolver_and_publication_acl', 'blocking',
    case when (
      select count(*)
      from (values
        ('public.get_academic_period_for_date(date)'::regprocedure),
        ('public.publish_activity(uuid)'::regprocedure),
        ('public.validate_activity_scheduled_state()'::regprocedure)
      ) expected(routine_oid)
      join pg_catalog.pg_proc routine on routine.oid = expected.routine_oid
      where md5(routine.proacl::text) = 'd1707186c8e5f1577bde2338d7541aec'
    ) = 3 then 0 else 1 end,
    0, 'Las firmas consumidas conservarán EXECUTE intencional'
  union all
  select 'unexpected_explicit_column_acl', 'blocking',
    (
      with actual(
        table_name, column_name, grantor_name, grantee_name,
        privilege_type, is_grantable
      ) as (
        select
          relation.relname::text,
          attribute_definition.attname::text,
          pg_catalog.pg_get_userbyid(expanded.grantor)::text,
          case when expanded.grantee = 0 then 'PUBLIC'
            else pg_catalog.pg_get_userbyid(expanded.grantee)::text end,
          expanded.privilege_type::text,
          expanded.is_grantable
        from pg_catalog.pg_attribute attribute_definition
        join pg_catalog.pg_class relation
          on relation.oid = attribute_definition.attrelid
        join pg_catalog.pg_namespace namespace
          on namespace.oid = relation.relnamespace
        cross join lateral pg_catalog.aclexplode(attribute_definition.attacl) expanded
        where namespace.nspname = 'public'
          and attribute_definition.attnum > 0
          and not attribute_definition.attisdropped
          and attribute_definition.attacl is not null
      ), expected(
        table_name, column_name, grantor_name, grantee_name,
        privilege_type, is_grantable
      ) as (
        values
          ('profiles','first_names','postgres','authenticated','UPDATE',false),
          ('profiles','paternal_surname','postgres','authenticated','UPDATE',false),
          ('profiles','maternal_surname','postgres','authenticated','UPDATE',false)
      )
      select count(*) from (
        (select * from actual except select * from expected)
        union all
        (select * from expected except select * from actual)
      ) drift
    ),
    0, 'attacl explícita debe coincidir bidireccionalmente con las tres columnas de nombre'
  union all
  select 'unexplained_column_privilege_projection', 'blocking',
    (
      with table_projection as (
        select
          pg_catalog.pg_get_userbyid(table_acl.grantor)::text grantor_name,
          case when table_acl.grantee = 0 then 'PUBLIC'
            else pg_catalog.pg_get_userbyid(table_acl.grantee)::text end grantee_name,
          relation.relname::text table_name,
          attribute_definition.attname::text column_name,
          table_acl.privilege_type::text privilege_type,
          case when (
            (table_acl.grantee <> 0 and pg_catalog.pg_has_role(
              table_acl.grantee, relation.relowner, 'USAGE'
            )) or table_acl.is_grantable
          ) then 'YES' else 'NO' end is_grantable
        from pg_catalog.pg_class relation
        join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
        join pg_catalog.pg_attribute attribute_definition
          on attribute_definition.attrelid = relation.oid
         and attribute_definition.attnum > 0
         and not attribute_definition.attisdropped
        cross join lateral pg_catalog.aclexplode(coalesce(
          relation.relacl, pg_catalog.acldefault('r', relation.relowner)
        )) table_acl
        where namespace.nspname = 'public'
          and relation.relkind in ('r', 'p', 'v', 'm')
          and table_acl.privilege_type in ('SELECT','INSERT','UPDATE','REFERENCES')
      ), explicit_projection as (
        select
          pg_catalog.pg_get_userbyid(column_acl.grantor)::text grantor_name,
          case when column_acl.grantee = 0 then 'PUBLIC'
            else pg_catalog.pg_get_userbyid(column_acl.grantee)::text end grantee_name,
          relation.relname::text table_name,
          attribute_definition.attname::text column_name,
          column_acl.privilege_type::text privilege_type,
          case when (
            (column_acl.grantee <> 0 and pg_catalog.pg_has_role(
              column_acl.grantee, relation.relowner, 'USAGE'
            )) or column_acl.is_grantable
          ) then 'YES' else 'NO' end is_grantable
        from pg_catalog.pg_attribute attribute_definition
        join pg_catalog.pg_class relation on relation.oid = attribute_definition.attrelid
        join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
        cross join lateral pg_catalog.aclexplode(attribute_definition.attacl) column_acl
        where namespace.nspname = 'public'
          and attribute_definition.attnum > 0
          and not attribute_definition.attisdropped
          and attribute_definition.attacl is not null
          and column_acl.privilege_type in ('SELECT','INSERT','UPDATE','REFERENCES')
      ), approved_projection as (
        select * from table_projection
        union
        select * from explicit_projection
      ), observed as (
        select
          grantor::text grantor_name,
          grantee::text grantee_name,
          table_name::text,
          column_name::text,
          privilege_type::text,
          is_grantable::text
        from information_schema.column_privileges
        where table_schema = 'public'
      )
      select count(*) from (
        (select * from observed except select * from approved_projection)
        union all
        (select * from approved_projection except select * from observed)
      ) drift
    ),
    0, 'column_privileges debe explicarse por ACL de tabla o attacl explícita'
  union all
  select 'unexpected_effective_column_privilege', 'blocking',
    (
      select count(*)
      from pg_catalog.pg_attribute attribute_definition
      join pg_catalog.pg_class relation on relation.oid = attribute_definition.attrelid
      join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
      cross join (
        values
          (0::oid),
          ('anon'::regrole::oid),
          ('authenticated'::regrole::oid),
          ('service_role'::regrole::oid)
      ) actor(role_oid)
      cross join (values ('SELECT'),('INSERT'),('UPDATE'),('REFERENCES')) permission(privilege_type)
      where namespace.nspname = 'public'
        and relation.relkind in ('r', 'p', 'v', 'm')
        and attribute_definition.attnum > 0
        and not attribute_definition.attisdropped
        and coalesce(pg_catalog.has_column_privilege(
          actor.role_oid, relation.oid, attribute_definition.attnum,
          permission.privilege_type
        ), false) is distinct from (
          coalesce(pg_catalog.has_table_privilege(
            actor.role_oid, relation.oid, permission.privilege_type
          ), false)
          or (
            actor.role_oid = 'authenticated'::regrole::oid
            and relation.oid = 'public.profiles'::regclass
            and attribute_definition.attname in (
              'first_names', 'paternal_surname', 'maternal_surname'
            )
            and permission.privilege_type = 'UPDATE'
          )
        )
    ) + case when pg_catalog.has_table_privilege(
      'authenticated', 'public.profiles', 'UPDATE'
    ) then 1 else 0 end,
    0, 'Acceso efectivo debe ser ACL de tabla más UPDATE de tres columnas de nombre'
  union all
  select 'dangerous_default_acl', 'blocking',
    case when current_user::text <> 'postgres' or session_user::text <> 'postgres' then 1
    else (
      select count(*)
      from pg_catalog.pg_default_acl default_acl
      cross join lateral pg_catalog.aclexplode(default_acl.defaclacl) expanded
      where default_acl.defaclrole = 'postgres'::regrole
        and (
          default_acl.defaclnamespace = 0
          or default_acl.defaclnamespace = 'public'::regnamespace
        )
        and default_acl.defaclobjtype::text in ('r', 'f')
        and expanded.grantee not in (
          0,
          'anon'::regrole,
          'authenticated'::regrole,
          'service_role'::regrole,
          'postgres'::regrole
        )
    ) end,
    0, 'Defaults postgres/public no pueden conceder a grantees no reconciliados'
  union all
  select 'required_roles', 'blocking',
    (select count(*) from (values ('anon'), ('authenticated'), ('service_role')) required(role_name)
      left join pg_catalog.pg_roles role on role.rolname = required.role_name
      where role.oid is null),
    0, 'Roles requeridos por ACL deben existir'
  union all
  select 'gist_range_support', 'blocking',
    case when exists (
      select 1 from pg_catalog.pg_opclass operator_class
      join pg_catalog.pg_am access_method on access_method.oid = operator_class.opcmethod
      where access_method.amname = 'gist' and operator_class.opcname = 'range_ops'
    ) then 0 else 1 end,
    0, 'La exclusión usa soporte daterange/GiST ya disponible'
  union all
  select 'unexpected_0011_objects', 'blocking',
    (
      case when to_regclass('public.academic_period_audit_events') is null then 0 else 1 end
      + case when to_regprocedure('public.list_admin_academic_periods(integer,integer)') is null then 0 else 1 end
      + case when to_regprocedure('public.create_admin_academic_period(text,date,date,boolean)') is null then 0 else 1 end
      + case when to_regprocedure('public.correct_admin_academic_period(uuid,text,date,date,text)') is null then 0 else 1 end
      + case when to_regprocedure('public.activate_admin_academic_period(uuid,text)') is null then 0 else 1 end
      + case when to_regprocedure('public.deactivate_admin_academic_period(uuid,text)') is null then 0 else 1 end
    )::bigint,
    0, 'Ningún objeto de 0011 debe existir antes de aplicar'
  union all
  select 'rollback_initial_eligibility', 'informational', 1, 1,
    'Línea base lógica intacta y sin evidencia SEM-01 previa'
)
select
  category,
  kind,
  observed_count,
  expected_count,
  case
    when kind = 'informational' then 'INFORMATIONAL'
    when observed_count is not distinct from expected_count then 'PASS'
    else 'BLOCK'
  end as status,
  detail
from results
order by case kind when 'blocking' then 0 else 1 end, category;

rollback;
