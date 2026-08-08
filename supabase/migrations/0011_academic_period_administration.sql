-- SITAA SEM-01: administración de periodos académicos y resolución automática.
-- Paquete local pendiente de revisión; no ejecutado contra ningún entorno.
--
-- Contrato:
--   * preserva las filas y UUID existentes de academic_periods;
--   * no ejecuta DML sobre activities;
--   * conserva las firmas públicas consumidas por la aplicación;
--   * serializa calendario, publicación y DML relevante de actividades;
--   * no crea ninguna ruta de eliminación o remapeo.

begin;
set transaction isolation level read committed;
set transaction read write;

set local lock_timeout = '5s';
set local statement_timeout = '120s';
set local idle_in_transaction_session_timeout = '120s';
set local timezone = 'UTC';
set local datestyle = 'ISO, YMD';
set local search_path = pg_catalog, public;

-- ---------------------------------------------------------------------------
-- Guarda bloqueante post-0010. No confía en la ejecución del preflight externo.
-- ---------------------------------------------------------------------------

do $baseline_guard$
declare
  observed_count bigint;
  observed_hash text;
begin
  if current_user <> 'postgres' or session_user <> 'postgres' then
    raise exception 'sitaa_0011_owner_required' using errcode = '42501';
  end if;

  if current_setting('transaction_isolation') <> 'read committed' then
    raise exception 'sitaa_0011_read_committed_required' using errcode = '25000';
  end if;

  if current_setting('transaction_read_only') <> 'off' then
    raise exception 'sitaa_0011_read_write_required' using errcode = '25006';
  end if;

  if to_regclass('public.academic_period_audit_events') is not null
     or to_regprocedure('public.list_admin_academic_periods(integer,integer)') is not null
     or to_regprocedure('public.create_admin_academic_period(text,date,date,boolean)') is not null
     or to_regprocedure('public.correct_admin_academic_period(uuid,text,date,date,text)') is not null
     or to_regprocedure('public.activate_admin_academic_period(uuid,text)') is not null
     or to_regprocedure('public.deactivate_admin_academic_period(uuid,text)') is not null then
    raise exception 'sitaa_0011_objects_already_exist' using errcode = '55000';
  end if;

  select count(*) into observed_count
  from pg_catalog.pg_class relation
  join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
  where namespace.nspname = 'public' and relation.relkind in ('r', 'p');
  if observed_count <> 19 then
    raise exception 'sitaa_0011_unexpected_table_baseline' using errcode = '55000';
  end if;

  select count(*) into observed_count
  from information_schema.columns column_info
  where column_info.table_schema = 'public';
  if observed_count <> 183 then
    raise exception 'sitaa_0011_unexpected_column_baseline' using errcode = '55000';
  end if;

  select count(*) into observed_count
  from pg_catalog.pg_constraint constraint_info
  join pg_catalog.pg_class relation on relation.oid = constraint_info.conrelid
  join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
  where namespace.nspname = 'public';
  if observed_count <> 96 then
    raise exception 'sitaa_0011_unexpected_constraint_baseline' using errcode = '55000';
  end if;

  select count(*) into observed_count
  from pg_catalog.pg_indexes index_info
  where index_info.schemaname = 'public';
  if observed_count <> 48 then
    raise exception 'sitaa_0011_unexpected_index_baseline' using errcode = '55000';
  end if;

  select count(*) into observed_count
  from pg_catalog.pg_trigger trigger_info
  join pg_catalog.pg_class relation on relation.oid = trigger_info.tgrelid
  join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
  where namespace.nspname = 'public' and not trigger_info.tgisinternal;
  if observed_count <> 13 then
    raise exception 'sitaa_0011_unexpected_trigger_baseline' using errcode = '55000';
  end if;

  select count(*) into observed_count
  from pg_catalog.pg_proc routine
  join pg_catalog.pg_namespace namespace on namespace.oid = routine.pronamespace
  where namespace.nspname = 'public' and routine.prokind = 'f';
  if observed_count <> 60 then
    raise exception 'sitaa_0011_unexpected_function_baseline' using errcode = '55000';
  end if;

  select count(*) into observed_count
  from pg_catalog.pg_policy policy
  join pg_catalog.pg_class relation on relation.oid = policy.polrelid
  join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
  where namespace.nspname = 'public';
  if observed_count <> 25 then
    raise exception 'sitaa_0011_unexpected_policy_baseline' using errcode = '55000';
  end if;

  if (
    select count(*)
    from information_schema.columns
    where table_schema = 'public' and table_name = 'academic_periods'
  ) <> 9
  or exists (
    (
      select column_name, ordinal_position, data_type, is_nullable, coalesce(column_default, '')
      from information_schema.columns
      where table_schema = 'public' and table_name = 'academic_periods'
    )
    except
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
  ) then
    raise exception 'sitaa_0011_unexpected_academic_period_shape' using errcode = '55000';
  end if;

  if (
    select count(*) from public.academic_periods
  ) <> 5
  or exists (
    (
      select code, name, starts_on, ends_on, is_active, sort_order, created_at, updated_at
      from public.academic_periods
    )
    except
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
  )
  or exists (
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
    except
    select code, name, starts_on, ends_on, is_active, sort_order, created_at, updated_at
    from public.academic_periods
  ) then
    raise exception 'sitaa_0011_unexpected_academic_period_seed' using errcode = '55000';
  end if;

  if (
    select md5(string_agg(
      period.id::text || '|' || period.code,
      E'\n' order by period.code collate "C"
    ))
    from public.academic_periods period
  ) <> '8af9fc114f31320519e894770823cc1d' then
    raise exception 'sitaa_0011_unexpected_academic_period_identity_map' using errcode = '55000';
  end if;

  if exists (
    select 1
    from public.academic_periods period
    where period.code <> 'pilot'
      and (
        period.code !~ '^[0-9]{4}-[12]$'
        or period.starts_on is null
        or period.ends_on is null
        or period.starts_on > period.ends_on
      )
  ) or exists (
    select 1
    from public.academic_periods left_period
    join public.academic_periods right_period
      on left_period.id < right_period.id
     and left_period.is_active and right_period.is_active
     and left_period.code <> 'pilot' and right_period.code <> 'pilot'
     and daterange(left_period.starts_on, left_period.ends_on, '[]')
       && daterange(right_period.starts_on, right_period.ends_on, '[]')
  ) then
    raise exception 'sitaa_0011_existing_period_integrity_failed' using errcode = '55000';
  end if;

  if exists (
    with activity_transition as (
      select
        activity.status_code,
        activity.academic_period_id,
        current_period.id as current_resolution,
        sem01_period.id as proposed_resolution
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
      ) sem01_period on true
    )
    select 1
    from activity_transition
    where (academic_period_id is not null
        and academic_period_id is distinct from proposed_resolution)
      or (academic_period_id is not null
        and current_resolution is distinct from proposed_resolution)
      or (status_code <> 'draft'
        and academic_period_id is distinct from current_resolution)
      or (status_code <> 'draft'
        and current_resolution is distinct from proposed_resolution)
      or (status_code = 'draft'
        and academic_period_id is null
        and current_resolution is not null
        and proposed_resolution is distinct from current_resolution)
  ) then
    raise exception 'sitaa_0011_new_resolver_would_change_existing_activity' using errcode = '55000';
  end if;

  select md5(btrim(regexp_replace(pg_catalog.pg_get_functiondef(
    'public.get_academic_period_for_date(date)'::regprocedure
  ), E'\\s+', ' ', 'g'))) into observed_hash;
  if observed_hash <> 'dd112ebab92161480ffedfe0d094b297' then
    raise exception 'sitaa_0011_unexpected_resolver_definition' using errcode = '55000';
  end if;

  select md5(btrim(regexp_replace(pg_catalog.pg_get_functiondef(
    'public.publish_activity(uuid)'::regprocedure
  ), E'\\s+', ' ', 'g'))) into observed_hash;
  if observed_hash <> '3351926e90e96d49774ae2fed556586d' then
    raise exception 'sitaa_0011_unexpected_publication_definition' using errcode = '55000';
  end if;

  select md5(btrim(regexp_replace(pg_catalog.pg_get_functiondef(
    'public.validate_activity_scheduled_state()'::regprocedure
  ), E'\\s+', ' ', 'g'))) into observed_hash;
  if observed_hash <> '940439094000f003c6e7a531dd46a7d7' then
    raise exception 'sitaa_0011_unexpected_activity_validator_definition' using errcode = '55000';
  end if;

  if not has_table_privilege('authenticated', 'public.academic_periods', 'SELECT')
     or has_table_privilege('authenticated', 'public.academic_periods', 'INSERT')
     or has_table_privilege('authenticated', 'public.academic_periods', 'UPDATE')
     or has_table_privilege('authenticated', 'public.academic_periods', 'DELETE')
     or has_table_privilege('authenticated', 'public.academic_periods', 'TRUNCATE')
     or not has_table_privilege('service_role', 'public.academic_periods', 'SELECT')
     or not has_table_privilege('service_role', 'public.academic_periods', 'INSERT')
     or not has_table_privilege('service_role', 'public.academic_periods', 'UPDATE')
     or not has_table_privilege('service_role', 'public.academic_periods', 'DELETE')
     or not has_table_privilege('service_role', 'public.academic_periods', 'TRUNCATE')
     or not has_function_privilege('authenticated', 'public.get_academic_period_for_date(date)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.publish_activity(uuid)', 'EXECUTE') then
    raise exception 'sitaa_0011_unexpected_acl_baseline' using errcode = '55000';
  end if;

  if md5((select relation.relacl::text from pg_catalog.pg_class relation
      where relation.oid = 'public.academic_periods'::regclass))
       <> '0382c9d760805ac4a3cfd8d6ca8a6951'
     or exists (
       select 1
       from (values
         ('public.get_academic_period_for_date(date)'::regprocedure),
         ('public.publish_activity(uuid)'::regprocedure),
         ('public.validate_activity_scheduled_state()'::regprocedure)
       ) expected(routine_oid)
       join pg_catalog.pg_proc routine on routine.oid = expected.routine_oid
       where md5(routine.proacl::text) <> 'd1707186c8e5f1577bde2338d7541aec'
     ) then
    raise exception 'sitaa_0011_unexpected_exact_acl_baseline' using errcode = '55000';
  end if;

  if exists (
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
      join pg_catalog.pg_class relation on relation.oid = attribute_definition.attrelid
      join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
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
    select 1 from (
      (select * from actual except select * from expected)
      union all
      (select * from expected except select * from actual)
    ) drift
  ) then
    raise exception 'sitaa_0011_unexpected_explicit_column_acl' using errcode = '55000';
  end if;

  if exists (
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
    select 1 from (
      (select * from observed except select * from approved_projection)
      union all
      (select * from approved_projection except select * from observed)
    ) drift
  ) then
    raise exception 'sitaa_0011_unexplained_column_privilege_projection' using errcode = '55000';
  end if;

  if pg_catalog.has_table_privilege('authenticated', 'public.profiles', 'UPDATE')
     or exists (
       select 1
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
     ) then
    raise exception 'sitaa_0011_unexpected_effective_column_privilege' using errcode = '55000';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_opclass operator_class
    join pg_catalog.pg_am access_method on access_method.oid = operator_class.opcmethod
    where access_method.amname = 'gist' and operator_class.opcname = 'range_ops'
  ) then
    raise exception 'sitaa_0011_required_gist_range_support_missing' using errcode = '55000';
  end if;

  if exists (
    select 1
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
  ) then
    raise exception 'sitaa_0011_dangerous_default_acl' using errcode = '55000';
  end if;

  if exists (
    select 1
    from (values ('anon'), ('authenticated'), ('service_role')) required(role_name)
    left join pg_catalog.pg_roles role on role.rolname = required.role_name
    where role.oid is null
  ) then
    raise exception 'sitaa_0011_required_role_missing' using errcode = '55000';
  end if;
end;
$baseline_guard$;

-- Un dominio de lock transaccional para calendario y atribución de actividades.
select pg_catalog.pg_advisory_xact_lock(1397310541, 1101);
lock table public.activities in share row exclusive mode;
lock table public.academic_periods in access exclusive mode;

-- La guarda crítica se repite después de adquirir los locks estructurales.
do $locked_baseline_guard$
begin
  if (select count(*) from public.academic_periods) <> 5
     or exists (
       with expected_period_seed(
         code, name, starts_on, ends_on, is_active, sort_order, created_at, updated_at
       ) as (
         values
           ('pilot'::text, 'Periodo piloto'::text, null::date, null::date, false, 0,
             timestamptz '2026-07-07 21:34:09.731881+00',
             timestamptz '2026-07-08 22:04:07.767746+00'),
           ('2026-1', '2026-1', date '2025-08-11', date '2025-11-28', true, 202601,
             timestamptz '2026-07-08 22:04:07.767746+00',
             timestamptz '2026-07-08 22:04:07.767746+00'),
           ('2026-2', '2026-2', date '2026-02-03', date '2026-05-29', true, 202602,
             timestamptz '2026-07-08 22:04:07.767746+00',
             timestamptz '2026-07-08 22:04:07.767746+00'),
           ('2027-1', '2027-1', date '2026-08-10', date '2026-11-27', true, 202701,
             timestamptz '2026-07-08 22:04:07.767746+00',
             timestamptz '2026-07-08 22:04:07.767746+00'),
           ('2027-2', '2027-2', date '2027-02-02', date '2027-05-28', true, 202702,
             timestamptz '2026-07-08 22:04:07.767746+00',
             timestamptz '2026-07-08 22:04:07.767746+00')
       ), actual_period_seed as (
         select code, name, starts_on, ends_on, is_active, sort_order, created_at, updated_at
         from public.academic_periods
       )
       select 1 from (
         (select * from actual_period_seed except select * from expected_period_seed)
         union all
         (select * from expected_period_seed except select * from actual_period_seed)
       ) difference
     )
     or (
       select md5(string_agg(
         period.id::text || '|' || period.code,
         E'\n' order by period.code collate "C"
       ))
       from public.academic_periods period
     ) <> '8af9fc114f31320519e894770823cc1d'
     or exists (
       select 1
       from public.academic_periods period
       where period.code <> 'pilot'
         and (
           period.code !~ '^[0-9]{4}-[12]$'
           or period.starts_on is null
           or period.ends_on is null
           or period.starts_on > period.ends_on
         )
     )
     or exists (
       select 1
       from public.academic_periods left_period
       join public.academic_periods right_period
         on left_period.id < right_period.id
        and left_period.is_active and right_period.is_active
        and left_period.code <> 'pilot' and right_period.code <> 'pilot'
        and daterange(left_period.starts_on, left_period.ends_on, '[]')
          && daterange(right_period.starts_on, right_period.ends_on, '[]')
     )
     or exists (
       select 1
       from public.academic_periods period
       where period.is_active and period.code <> 'pilot'
       group by period.starts_on
       having count(*) > 1
     ) then
    raise exception 'sitaa_0011_locked_period_baseline_changed' using errcode = '55000';
  end if;

  if exists (
    with activity_transition as (
      select
        activity.status_code,
        activity.academic_period_id,
        current_period.id as current_resolution,
        sem01_period.id as proposed_resolution
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
      ) sem01_period on true
    )
    select 1
    from activity_transition
    where (academic_period_id is not null
        and academic_period_id is distinct from proposed_resolution)
      or (academic_period_id is not null
        and current_resolution is distinct from proposed_resolution)
      or (status_code <> 'draft'
        and academic_period_id is distinct from current_resolution)
      or (status_code <> 'draft'
        and current_resolution is distinct from proposed_resolution)
      or (status_code = 'draft'
        and academic_period_id is null
        and current_resolution is not null
        and proposed_resolution is distinct from current_resolution)
  ) then
    raise exception 'sitaa_0011_locked_activity_resolution_changed' using errcode = '55000';
  end if;
end;
$locked_baseline_guard$;

-- ---------------------------------------------------------------------------
-- Helpers privados de integridad, autoridad, resolución e impacto.
-- ---------------------------------------------------------------------------

create function public.is_exact_sem01_period_admin_0011(requested_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $function$
  select exists (
    select 1
    from public.profiles profile
    join public.role_assignments assignment on assignment.user_id = profile.id
    where profile.id = requested_profile_id
      and profile.account_status = 'active'
      and profile.is_active = true
      and assignment.role_code = 'technical_admin'
      and assignment.scope_type = 'system'
      and assignment.service_area = 'technical'
      and assignment.program_id is null
      and assignment.division_id is null
      and assignment.is_active = true
      and assignment.starts_at <= public.sitaa_current_mexico_date()
      and (
        assignment.ends_at is null
        or assignment.ends_at >= public.sitaa_current_mexico_date()
      )
  );
$function$;

create function public.lock_and_reauthorize_sem01_admin_0011(actor_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
begin
  if current_setting('transaction_isolation') <> 'read committed' then
    raise exception 'sitaa_sem01_read_committed_required'
      using errcode = '25000';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(1397310541, 1101);
  lock table public.academic_periods in share row exclusive mode;

  perform profile.id
  from public.profiles profile
  where profile.id = actor_profile_id
  for update;

  perform assignment.id
  from public.role_assignments assignment
  where assignment.user_id = actor_profile_id
  order by assignment.id
  for update;

  if actor_profile_id is null
     or not public.is_exact_sem01_period_admin_0011(actor_profile_id) then
    raise exception 'sitaa_sem01_admin_access_denied' using errcode = '42501';
  end if;
end;
$function$;

create function public.normalize_sem01_reason_0011(raw_reason text)
returns text
language plpgsql
immutable
set search_path = pg_catalog
as $function$
declare
  normalized_reason text;
begin
  normalized_reason := regexp_replace(btrim(coalesce(raw_reason, '')), '[[:space:]]+', ' ', 'g');
  if char_length(normalized_reason) not between 10 and 1000 then
    raise exception 'sitaa_sem01_invalid_reason' using errcode = '22023';
  end if;
  if normalized_reason ~ '[[:cntrl:]]'
     or normalized_reason ~* '(authorization|bearer|cookie|password|contraseña|secret|token|session|sesión|credential|credencial)' then
    raise exception 'sitaa_sem01_unsafe_reason' using errcode = '22023';
  end if;
  return normalized_reason;
end;
$function$;

create function public.is_sem01_audit_payload_valid_0011(
  requested_action text,
  requested_fields text[],
  requested_old_values jsonb,
  requested_new_values jsonb
)
returns boolean
language sql
immutable
set search_path = pg_catalog
as $function$
  select
    requested_action in ('academic_period_created', 'academic_period_corrected',
      'academic_period_activated', 'academic_period_deactivated')
    and requested_fields is not null
    and cardinality(requested_fields) between 1 and 5
    and (
      select count(*) = count(distinct field_name)
      from unnest(requested_fields) field_name
    )
    and not exists (
      select 1 from unnest(requested_fields) field_name
      where field_name not in ('code', 'name', 'starts_on', 'ends_on', 'is_active')
    )
    and jsonb_typeof(requested_old_values) = 'object'
    and jsonb_typeof(requested_new_values) = 'object'
    and octet_length(requested_old_values::text) <= 4000
    and octet_length(requested_new_values::text) <= 4000
    and not exists (
      select 1 from jsonb_object_keys(requested_old_values) key_name
      where not (key_name = any(requested_fields))
    )
    and not exists (
      select 1 from jsonb_object_keys(requested_new_values) key_name
      where not (key_name = any(requested_fields))
    )
    and (
      (requested_action = 'academic_period_created'
        and requested_old_values = '{}'::jsonb
        and (select count(*) from jsonb_object_keys(requested_new_values)) = cardinality(requested_fields))
      or
      (requested_action <> 'academic_period_created'
        and (select count(*) from jsonb_object_keys(requested_old_values)) = cardinality(requested_fields)
        and (select count(*) from jsonb_object_keys(requested_new_values)) = cardinality(requested_fields))
    );
$function$;

create function public.resolve_academic_period_proposal_0011(
  target_date date,
  mutation_kind text,
  requested_period_id uuid,
  requested_code text,
  requested_name text,
  requested_starts_on date,
  requested_ends_on date,
  requested_is_active boolean
)
returns uuid
language sql
stable
security definer
set search_path = pg_catalog, public
as $function$
  with calendar as (
    select
      period.id,
      period.code,
      period.name,
      period.starts_on,
      period.ends_on,
      period.is_active
    from public.academic_periods period
    where mutation_kind = 'create' or period.id <> requested_period_id

    union all

    select
      requested_period_id,
      requested_code,
      requested_name,
      requested_starts_on,
      requested_ends_on,
      requested_is_active
    where mutation_kind in ('create', 'replace')
  ),
  eligible as (
    select *
    from calendar
    where is_active
      and code <> 'pilot'
      and starts_on is not null
      and ends_on is not null
  ),
  candidate as (
    select period.*
    from eligible period
    where period.starts_on <= target_date
    order by period.starts_on desc, period.code desc, period.id desc
    limit 1
  ),
  bounded as (
    select
      candidate.*,
      (
        select successor.starts_on
        from eligible successor
        where (successor.starts_on, successor.code, successor.id)
          > (candidate.starts_on, candidate.code, candidate.id)
        order by successor.starts_on, successor.code, successor.id
        limit 1
      ) as successor_starts_on
    from candidate
  )
  select case
    when target_date <= coalesce(successor_starts_on - 1, ends_on) then id
    else null::uuid
  end
  from bounded;
$function$;

create function public.diagnose_academic_period_impact_0011(
  mutation_kind text,
  requested_period_id uuid,
  requested_code text,
  requested_name text,
  requested_starts_on date,
  requested_ends_on date,
  requested_is_active boolean
)
returns table(
  activity_count bigint,
  unchanged_count bigint,
  benign_draft_enablement_count bigint,
  stored_attribution_mismatch_count bigint,
  assigned_resolution_change_count bigint,
  non_draft_inconsistent_count bigint,
  non_draft_resolution_change_count bigint,
  resolved_draft_loss_or_switch_count bigint
)
language sql
stable
security definer
set search_path = pg_catalog, public
as $function$
  with impact as (
    select
      activity.status_code,
      activity.academic_period_id,
      current_period.id as current_resolution,
      public.resolve_academic_period_proposal_0011(
        activity.start_date,
        mutation_kind,
        requested_period_id,
        requested_code,
        requested_name,
        requested_starts_on,
        requested_ends_on,
        requested_is_active
      ) as proposed_resolution
    from public.activities activity
    left join lateral public.get_academic_period_for_date(activity.start_date) current_period on true
  )
  select
    count(*)::bigint,
    count(*) filter (where current_resolution is not distinct from proposed_resolution)::bigint,
    count(*) filter (
      where status_code = 'draft'
        and academic_period_id is null
        and current_resolution is null
        and proposed_resolution is not null
    )::bigint,
    count(*) filter (
      where academic_period_id is not null
        and proposed_resolution is distinct from academic_period_id
    )::bigint,
    count(*) filter (
      where academic_period_id is not null
        and current_resolution is distinct from proposed_resolution
    )::bigint,
    count(*) filter (
      where status_code <> 'draft'
        and academic_period_id is distinct from current_resolution
    )::bigint,
    count(*) filter (
      where status_code <> 'draft'
        and current_resolution is distinct from proposed_resolution
    )::bigint,
    count(*) filter (
      where status_code = 'draft'
        and academic_period_id is null
        and current_resolution is not null
        and proposed_resolution is distinct from current_resolution
    )::bigint
  from impact;
$function$;

create function public.acquire_sem01_calendar_lock_0011()
returns trigger
language plpgsql
set search_path = pg_catalog
as $function$
begin
  if current_setting('transaction_isolation') <> 'read committed' then
    raise exception 'sitaa_sem01_read_committed_required'
      using errcode = '25000';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(1397310541, 1101);
  return null;
end;
$function$;

create function public.guard_academic_periods_sem01_0011()
returns trigger
language plpgsql
set search_path = pg_catalog
as $function$
begin
  if tg_op = 'DELETE' or tg_op = 'TRUNCATE' then
    raise exception 'sitaa_sem01_period_delete_forbidden' using errcode = '42501';
  end if;

  if tg_op = 'UPDATE' and new.code is distinct from old.code then
    raise exception 'sitaa_sem01_period_code_immutable' using errcode = '23514';
  end if;

  if new.code = 'pilot' then
    if tg_op = 'INSERT'
       or (new.name, new.starts_on, new.ends_on, new.is_active, new.sort_order)
         is distinct from ('Periodo piloto'::text, null::date, null::date, false, 0) then
      raise exception 'sitaa_sem01_pilot_immutable' using errcode = '23514';
    end if;
    return new;
  end if;

  if new.code !~ '^[0-9]{4}-[12]$' then
    raise exception 'sitaa_sem01_invalid_period_code' using errcode = '22023';
  end if;
  if tg_op = 'INSERT' and new.name is distinct from new.code then
    raise exception 'sitaa_sem01_initial_name_must_match_code' using errcode = '23514';
  end if;
  if new.name is null
     or char_length(new.name) not between 1 and 120
     or new.name is distinct from regexp_replace(btrim(new.name), '[[:space:]]+', ' ', 'g')
     or new.name ~ '[[:cntrl:]]' then
    raise exception 'sitaa_sem01_invalid_period_name' using errcode = '22023';
  end if;
  if new.starts_on is null or new.ends_on is null then
    raise exception 'sitaa_sem01_complete_dates_required' using errcode = '23514';
  end if;
  if new.starts_on > new.ends_on then
    raise exception 'sitaa_sem01_invalid_period_range' using errcode = '23514';
  end if;
  return new;
end;
$function$;

create function public.set_academic_period_updated_at_0011()
returns trigger
language plpgsql
set search_path = pg_catalog
as $function$
begin
  if (to_jsonb(new) - 'updated_at') is distinct from (to_jsonb(old) - 'updated_at') then
    new.updated_at := clock_timestamp();
  else
    new.updated_at := old.updated_at;
  end if;
  return new;
end;
$function$;

create function public.guard_academic_period_audit_append_only_0011()
returns trigger
language plpgsql
set search_path = pg_catalog
as $function$
begin
  raise exception 'sitaa_sem01_audit_append_only' using errcode = '42501';
end;
$function$;

-- ---------------------------------------------------------------------------
-- Integridad física y auditoría dedicada.
-- ---------------------------------------------------------------------------

alter table public.academic_periods
  add constraint academic_periods_sem01_shape_check
  check (
    (
      code = 'pilot'
      and name = 'Periodo piloto'
      and starts_on is null
      and ends_on is null
      and is_active = false
      and sort_order = 0
    )
    or
    (
      code ~ '^[0-9]{4}-[12]$'
      and name is not null
      and char_length(name) between 1 and 120
      and name = regexp_replace(btrim(name), '[[:space:]]+', ' ', 'g')
      and name !~ '[[:cntrl:]]'
      and starts_on is not null
      and ends_on is not null
      and starts_on <= ends_on
    )
  ) not valid;

alter table public.academic_periods
  validate constraint academic_periods_sem01_shape_check;

alter table public.academic_periods
  add constraint academic_periods_active_date_range_excl
  exclude using gist (
    daterange(starts_on, ends_on, '[]') with &&
  )
  where (is_active and code <> 'pilot');

create trigger academic_periods_guard_sem01
before insert or update or delete on public.academic_periods
for each row execute function public.guard_academic_periods_sem01_0011();

create trigger academic_periods_guard_truncate_sem01
before truncate on public.academic_periods
for each statement execute function public.guard_academic_periods_sem01_0011();

create trigger academic_periods_set_updated_at_sem01
before update on public.academic_periods
for each row execute function public.set_academic_period_updated_at_0011();

create table public.academic_period_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_profile_id uuid not null,
  academic_period_id uuid not null,
  period_code text not null,
  action_code text not null,
  outcome text not null default 'success',
  reason text,
  changed_fields text[] not null,
  old_values jsonb not null default '{}'::jsonb,
  new_values jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default clock_timestamp(),
  constraint academic_period_audit_events_actor_fkey
    foreign key (actor_profile_id) references public.profiles(id)
    on update restrict on delete restrict,
  constraint academic_period_audit_events_period_fkey
    foreign key (academic_period_id) references public.academic_periods(id)
    on update restrict on delete restrict,
  constraint academic_period_audit_events_code_check
    check (period_code ~ '^[0-9]{4}-[12]$'),
  constraint academic_period_audit_events_outcome_check
    check (outcome = 'success'),
  constraint academic_period_audit_events_reason_check
    check (
      (action_code = 'academic_period_created' and reason is null)
      or
      (
        action_code <> 'academic_period_created'
        and reason is not null
        and char_length(reason) between 10 and 1000
        and reason = regexp_replace(btrim(reason), '[[:space:]]+', ' ', 'g')
        and reason !~ '[[:cntrl:]]'
        and reason !~* '(authorization|bearer|cookie|password|contraseña|secret|token|session|sesión|credential|credencial)'
      )
    ),
  constraint academic_period_audit_events_payload_check
    check (public.is_sem01_audit_payload_valid_0011(
      action_code, changed_fields, old_values, new_values
    ))
);

create index academic_period_audit_events_period_occurred_idx
  on public.academic_period_audit_events
  (academic_period_id, occurred_at desc, id desc);

create index academic_period_audit_events_actor_occurred_idx
  on public.academic_period_audit_events
  (actor_profile_id, occurred_at desc, id desc);

alter table public.academic_period_audit_events enable row level security;

create trigger academic_period_audit_events_guard_update_delete
before update or delete on public.academic_period_audit_events
for each row execute function public.guard_academic_period_audit_append_only_0011();

create trigger academic_period_audit_events_guard_truncate
before truncate on public.academic_period_audit_events
for each statement execute function public.guard_academic_period_audit_append_only_0011();

create trigger activities_sem01_lock_insert
before insert on public.activities
for each statement execute function public.acquire_sem01_calendar_lock_0011();

create trigger activities_sem01_lock_update
before update of start_date, status_code, academic_period_id on public.activities
for each statement execute function public.acquire_sem01_calendar_lock_0011();

-- ---------------------------------------------------------------------------
-- Resolver compatible: misma firma, mismas columnas y mismos tipos.
-- ---------------------------------------------------------------------------

create or replace function public.get_academic_period_for_date(target_date date)
returns table(id uuid, code text, name text, starts_on date, ends_on date)
language sql
stable
security definer
set search_path = pg_catalog, public
as $function$
  with eligible as (
    select
      period.id,
      period.code,
      period.name,
      period.starts_on,
      period.ends_on
    from public.academic_periods period
    where period.is_active
      and period.code <> 'pilot'
      and period.starts_on is not null
      and period.ends_on is not null
  ),
  candidate as (
    select period.*
    from eligible period
    where period.starts_on <= target_date
    order by period.starts_on desc, period.code desc, period.id desc
    limit 1
  ),
  bounded as (
    select
      candidate.*,
      (
        select successor.starts_on
        from eligible successor
        where (successor.starts_on, successor.code, successor.id)
          > (candidate.starts_on, candidate.code, candidate.id)
        order by successor.starts_on, successor.code, successor.id
        limit 1
      ) as successor_starts_on
    from candidate
  )
  select id, code, name, starts_on, ends_on
  from bounded
  where target_date <= coalesce(successor_starts_on - 1, ends_on);
$function$;

-- Publicación compatible con la aplicación desplegada; el lock compartido se
-- toma antes del FOR UPDATE y el periodo se vuelve a resolver en la transacción.
create or replace function public.publish_activity(target_activity_id uuid)
returns table(activity_id uuid, status_code text, academic_period_id uuid, semester_label text)
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  target_activity public.activities%rowtype;
  target_period_id uuid;
  target_semester_label text;
  start_value timestamp;
  validation_now timestamptz;
begin
  if current_setting('transaction_isolation') <> 'read committed' then
    raise exception 'sitaa_sem01_read_committed_required'
      using errcode = '25000';
  end if;

  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;
  if auth.uid() is null then
    raise exception 'Debes iniciar sesión para publicar una actividad.' using errcode = '42501';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(1397310541, 1101);

  select activity.* into target_activity
  from public.activities activity
  where activity.id = target_activity_id
  for update;

  if not found then
    raise exception 'La actividad no existe o no está disponible.' using errcode = 'P0001';
  end if;
  if target_activity.created_by is distinct from auth.uid() then
    raise exception 'Sólo el creador puede publicar esta actividad.' using errcode = '42501';
  end if;
  if target_activity.status_code <> 'draft' then
    raise exception 'Sólo pueden publicarse actividades en borrador.' using errcode = 'P0001';
  end if;
  if public.can_create_activity(
    target_activity.scope_type,
    target_activity.program_id,
    target_activity.division_id,
    target_activity.service_type_code
  ) is distinct from true then
    raise exception 'Tus asignaciones actuales no permiten publicar esta actividad.'
      using errcode = '42501';
  end if;
  if target_activity.start_date is null or target_activity.start_time is null then
    raise exception 'Indica una fecha y hora de inicio válidas.' using errcode = '23514';
  end if;

  start_value := target_activity.start_date + target_activity.start_time;
  validation_now := clock_timestamp();
  if (start_value at time zone 'America/Mexico_City') <= validation_now then
    raise exception 'La fecha y hora de inicio deben ser posteriores a la hora actual de Ciudad de México.'
      using errcode = '23514';
  end if;

  select period.id, period.name
  into target_period_id, target_semester_label
  from public.get_academic_period_for_date(target_activity.start_date) period
  limit 1;

  if target_period_id is null then
    raise exception 'sitaa_activity_academic_period_unavailable' using errcode = '23514';
  end if;

  update public.activities activity
  set academic_period_id = target_period_id,
      status_code = 'scheduled',
      updated_by = auth.uid()
  where activity.id = target_activity_id;

  return query
  select target_activity_id, 'scheduled'::text, target_period_id, target_semester_label;
end;
$function$;

-- La validación de filas programadas conserva el contrato 0002/0003 y usa el
-- resolver SEM-01. El lock se adquiere previamente mediante trigger statement.
create or replace function public.validate_activity_scheduled_state()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $function$
declare
  expected_period_id uuid;
  start_value timestamp;
  end_value timestamp;
  require_future_start boolean := false;
  trusted_database_role boolean := current_user in ('postgres', 'service_role');
  validation_now timestamptz;
begin
  if tg_op = 'UPDATE' and not trusted_database_role then
    if new.created_by is distinct from old.created_by then
      raise exception 'No se puede cambiar el creador de una actividad.' using errcode = '23514';
    end if;
    if old.status_code <> 'draft' and new.status_code = 'draft' then
      raise exception 'Una actividad publicada no puede volver a borrador.' using errcode = '23514';
    end if;
    if old.status_code = 'draft' and new.status_code = 'scheduled' then
      if auth.uid() is null
         or new.created_by is distinct from auth.uid()
         or public.can_create_activity(
           new.scope_type, new.program_id, new.division_id, new.service_type_code
         ) is distinct from true then
        raise exception 'No tienes permiso para publicar esta actividad.' using errcode = '42501';
      end if;
    end if;
  end if;

  if new.status_code <> 'scheduled' then return new; end if;

  if nullif(btrim(new.title), '') is null then
    raise exception 'Escribe el título de la actividad.' using errcode = '23514';
  end if;
  if length(new.title) > 200 then
    raise exception 'El título no puede exceder 200 caracteres.' using errcode = '23514';
  end if;
  if length(coalesce(new.description, '')) > 5000 then
    raise exception 'La descripción no puede exceder 5000 caracteres.' using errcode = '23514';
  end if;

  if new.scope_type = 'program' then
    if new.program_id is null or new.division_id is null or not exists (
      select 1 from public.academic_programs program
      where program.id = new.program_id and program.division_id = new.division_id
    ) then
      raise exception 'El programa y la división no corresponden al alcance de la actividad.'
        using errcode = '23514';
    end if;
  elsif new.scope_type = 'division' then
    if new.division_id is null or new.program_id is not null then
      raise exception 'El alcance divisional requiere una división y no admite programa.'
        using errcode = '23514';
    end if;
  else
    raise exception 'El alcance de la actividad no es válido.' using errcode = '23514';
  end if;

  if new.activity_type_code is null then raise exception 'Selecciona un tipo de actividad.' using errcode = '23514'; end if;
  if new.service_type_code is null then raise exception 'Selecciona un tipo de servicio.' using errcode = '23514'; end if;
  if new.attention_category_code is null then raise exception 'Selecciona una categoría de atención.' using errcode = '23514'; end if;
  if new.modality_code is null then raise exception 'Selecciona una modalidad.' using errcode = '23514'; end if;
  if new.location_type_code is null then raise exception 'Selecciona un tipo de ubicación.' using errcode = '23514'; end if;
  if nullif(btrim(new.location_detail), '') is null then
    raise exception 'Indica el lugar, aula, enlace o detalle de acceso de la actividad.' using errcode = '23514';
  end if;
  if length(new.location_detail) > 500 then
    raise exception 'El detalle de ubicación no puede exceder 500 caracteres.' using errcode = '23514';
  end if;
  if new.modality_code = 'online' and new.location_type_code <> 'online_space' then
    raise exception 'Una actividad en línea debe usar la ubicación En línea.' using errcode = '23514';
  end if;
  if new.modality_code <> 'online' and new.location_type_code = 'online_space' then
    raise exception 'La ubicación En línea sólo corresponde a la modalidad En línea.' using errcode = '23514';
  end if;

  if new.start_date is null then raise exception 'Indica una fecha de inicio válida.' using errcode = '23514'; end if;
  if new.start_time is null then raise exception 'Indica una hora válida en formato de 24 horas.' using errcode = '23514'; end if;
  if new.duration_mode not in ('one_hour', 'two_hours', 'custom') or new.duration_mode is null then
    raise exception 'Selecciona una duración.' using errcode = '23514';
  end if;
  if new.end_date is null then raise exception 'Indica una fecha de término válida.' using errcode = '23514'; end if;
  if new.end_time is null then raise exception 'Indica una hora de término válida en formato de 24 horas.' using errcode = '23514'; end if;

  start_value := new.start_date + new.start_time;
  end_value := new.end_date + new.end_time;
  if end_value <= start_value then
    raise exception 'El término de la actividad debe ser posterior al inicio.' using errcode = '23514';
  end if;
  if new.duration_mode = 'one_hour' and end_value <> start_value + interval '1 hour' then
    raise exception 'La duración de 1 hora no coincide con la fecha y hora de término.' using errcode = '23514';
  end if;
  if new.duration_mode = 'two_hours' and end_value <> start_value + interval '2 hours' then
    raise exception 'La duración de 2 horas no coincide con la fecha y hora de término.' using errcode = '23514';
  end if;
  if new.responsible_profile_id is null then
    raise exception 'La actividad requiere una persona responsable.' using errcode = '23514';
  end if;

  select period.id into expected_period_id
  from public.get_academic_period_for_date(new.start_date) period limit 1;
  if expected_period_id is null then
    raise exception 'sitaa_activity_academic_period_unavailable' using errcode = '23514';
  end if;
  if new.academic_period_id is distinct from expected_period_id then
    raise exception 'El semestre asignado no corresponde a la fecha de inicio.' using errcode = '23514';
  end if;

  if tg_op = 'INSERT' then
    require_future_start := true;
  elsif old.status_code = 'draft' then
    require_future_start := true;
  end if;
  if require_future_start then
    validation_now := clock_timestamp();
    if (start_value at time zone 'America/Mexico_City') <= validation_now then
      raise exception 'La fecha y hora de inicio deben ser posteriores a la hora actual de Ciudad de México.'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$function$;

-- ---------------------------------------------------------------------------
-- Superficie RPC pública mínima. Toda escritura repite autoridad tras locks.
-- ---------------------------------------------------------------------------

create function public.list_admin_academic_periods(
  result_limit integer default 100,
  result_offset integer default 0
)
returns table(
  id uuid,
  code text,
  name text,
  starts_on date,
  ends_on date,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz,
  activity_reference_count bigint
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $function$
begin
  if auth.uid() is null
     or not public.is_exact_sem01_period_admin_0011(auth.uid()) then
    raise exception 'sitaa_sem01_admin_access_denied' using errcode = '42501';
  end if;
  if result_limit is null or result_limit < 1 or result_limit > 100
     or result_offset is null or result_offset < 0 or result_offset > 10000 then
    raise exception 'sitaa_sem01_invalid_pagination' using errcode = '22023';
  end if;

  return query
  select
    period.id,
    period.code,
    period.name,
    period.starts_on,
    period.ends_on,
    period.is_active,
    period.created_at,
    period.updated_at,
    count(activity.id)::bigint
  from public.academic_periods period
  left join public.activities activity on activity.academic_period_id = period.id
  group by period.id
  order by period.starts_on desc nulls last, period.code desc, period.id desc
  limit result_limit offset result_offset;
end;
$function$;

create function public.create_admin_academic_period(
  requested_code text,
  requested_starts_on date,
  requested_ends_on date,
  requested_is_active boolean default true
)
returns table(
  period_id uuid,
  code text,
  name text,
  starts_on date,
  ends_on date,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz,
  audit_event_id uuid
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  actor_profile_id uuid := auth.uid();
  new_period_id uuid := gen_random_uuid();
  new_audit_event_id uuid;
  impact record;
  persisted public.academic_periods%rowtype;
begin
  if actor_profile_id is null
     or not public.is_exact_sem01_period_admin_0011(actor_profile_id) then
    raise exception 'sitaa_sem01_admin_access_denied' using errcode = '42501';
  end if;
  if requested_code is null or requested_code !~ '^[0-9]{4}-[12]$' then
    raise exception 'sitaa_sem01_invalid_period_code' using errcode = '22023';
  end if;
  if requested_starts_on is null or requested_ends_on is null then
    raise exception 'sitaa_sem01_complete_dates_required' using errcode = '23514';
  end if;
  if requested_starts_on > requested_ends_on then
    raise exception 'sitaa_sem01_invalid_period_range' using errcode = '23514';
  end if;
  if requested_is_active is null then
    raise exception 'sitaa_sem01_active_state_required' using errcode = '22023';
  end if;

  perform public.lock_and_reauthorize_sem01_admin_0011(actor_profile_id);

  if exists (select 1 from public.academic_periods period where period.code = requested_code) then
    raise exception 'sitaa_sem01_period_code_conflict' using errcode = '23505';
  end if;

  select * into impact
  from public.diagnose_academic_period_impact_0011(
    'create', new_period_id, requested_code, requested_code,
    requested_starts_on, requested_ends_on, requested_is_active
  );

  if impact.stored_attribution_mismatch_count > 0
     or impact.assigned_resolution_change_count > 0
     or impact.non_draft_inconsistent_count > 0
     or impact.non_draft_resolution_change_count > 0
     or impact.resolved_draft_loss_or_switch_count > 0 then
    raise exception 'sitaa_sem01_calendar_impact_blocked' using errcode = '23514';
  end if;

  begin
    insert into public.academic_periods(
      id, code, name, starts_on, ends_on, is_active
    ) values (
      new_period_id, requested_code, requested_code,
      requested_starts_on, requested_ends_on, requested_is_active
    ) returning * into persisted;
  exception
    when unique_violation then
      raise exception 'sitaa_sem01_period_code_conflict' using errcode = '23505';
    when exclusion_violation then
      raise exception 'sitaa_sem01_period_overlap' using errcode = '23P01';
  end;

  insert into public.academic_period_audit_events(
    actor_profile_id, academic_period_id, period_code, action_code,
    outcome, reason, changed_fields, old_values, new_values, occurred_at
  ) values (
    actor_profile_id,
    persisted.id,
    persisted.code,
    'academic_period_created',
    'success',
    null,
    array['code', 'name', 'starts_on', 'ends_on', 'is_active']::text[],
    '{}'::jsonb,
    jsonb_build_object(
      'code', persisted.code,
      'name', persisted.name,
      'starts_on', persisted.starts_on,
      'ends_on', persisted.ends_on,
      'is_active', persisted.is_active
    ),
    clock_timestamp()
  ) returning id into new_audit_event_id;

  return query select
    persisted.id, persisted.code, persisted.name,
    persisted.starts_on, persisted.ends_on, persisted.is_active,
    persisted.created_at, persisted.updated_at, new_audit_event_id;
end;
$function$;

create function public.correct_admin_academic_period(
  requested_period_id uuid,
  requested_name text,
  requested_starts_on date,
  requested_ends_on date,
  change_reason text
)
returns table(
  period_id uuid,
  code text,
  name text,
  starts_on date,
  ends_on date,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz,
  audit_event_id uuid
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  actor_profile_id uuid := auth.uid();
  normalized_name text := regexp_replace(btrim(coalesce(requested_name, '')), '[[:space:]]+', ' ', 'g');
  normalized_reason text;
  target_period public.academic_periods%rowtype;
  persisted public.academic_periods%rowtype;
  impact record;
  changed text[] := array[]::text[];
  old_payload jsonb := '{}'::jsonb;
  new_payload jsonb := '{}'::jsonb;
  new_audit_event_id uuid;
begin
  if actor_profile_id is null
     or not public.is_exact_sem01_period_admin_0011(actor_profile_id) then
    raise exception 'sitaa_sem01_admin_access_denied' using errcode = '42501';
  end if;
  normalized_reason := public.normalize_sem01_reason_0011(change_reason);
  if char_length(normalized_name) not between 1 and 120 or normalized_name ~ '[[:cntrl:]]' then
    raise exception 'sitaa_sem01_invalid_period_name' using errcode = '22023';
  end if;
  if requested_starts_on is null or requested_ends_on is null then
    raise exception 'sitaa_sem01_complete_dates_required' using errcode = '23514';
  end if;
  if requested_starts_on > requested_ends_on then
    raise exception 'sitaa_sem01_invalid_period_range' using errcode = '23514';
  end if;

  perform public.lock_and_reauthorize_sem01_admin_0011(actor_profile_id);

  select period.* into target_period
  from public.academic_periods period
  where period.id = requested_period_id
  for update;
  if not found then
    raise exception 'sitaa_sem01_period_not_found' using errcode = 'P0002';
  end if;
  if target_period.code = 'pilot' then
    raise exception 'sitaa_sem01_pilot_immutable' using errcode = '23514';
  end if;

  if target_period.name is distinct from normalized_name then
    changed := array_append(changed, 'name');
    old_payload := old_payload || jsonb_build_object('name', target_period.name);
    new_payload := new_payload || jsonb_build_object('name', normalized_name);
  end if;
  if target_period.starts_on is distinct from requested_starts_on then
    changed := array_append(changed, 'starts_on');
    old_payload := old_payload || jsonb_build_object('starts_on', target_period.starts_on);
    new_payload := new_payload || jsonb_build_object('starts_on', requested_starts_on);
  end if;
  if target_period.ends_on is distinct from requested_ends_on then
    changed := array_append(changed, 'ends_on');
    old_payload := old_payload || jsonb_build_object('ends_on', target_period.ends_on);
    new_payload := new_payload || jsonb_build_object('ends_on', requested_ends_on);
  end if;
  if cardinality(changed) = 0 then
    raise exception 'sitaa_sem01_no_changes' using errcode = '22023';
  end if;

  select * into impact
  from public.diagnose_academic_period_impact_0011(
    'replace', target_period.id, target_period.code, normalized_name,
    requested_starts_on, requested_ends_on, target_period.is_active
  );
  if impact.stored_attribution_mismatch_count > 0
     or impact.assigned_resolution_change_count > 0
     or impact.non_draft_inconsistent_count > 0
     or impact.non_draft_resolution_change_count > 0
     or impact.resolved_draft_loss_or_switch_count > 0 then
    raise exception 'sitaa_sem01_calendar_impact_blocked' using errcode = '23514';
  end if;

  begin
    update public.academic_periods period
    set name = normalized_name,
        starts_on = requested_starts_on,
        ends_on = requested_ends_on
    where period.id = target_period.id
    returning * into persisted;
  exception when exclusion_violation then
    raise exception 'sitaa_sem01_period_overlap' using errcode = '23P01';
  end;

  insert into public.academic_period_audit_events(
    actor_profile_id, academic_period_id, period_code, action_code,
    outcome, reason, changed_fields, old_values, new_values, occurred_at
  ) values (
    actor_profile_id, persisted.id, persisted.code,
    'academic_period_corrected', 'success', normalized_reason,
    changed, old_payload, new_payload, clock_timestamp()
  ) returning id into new_audit_event_id;

  return query select
    persisted.id, persisted.code, persisted.name,
    persisted.starts_on, persisted.ends_on, persisted.is_active,
    persisted.created_at, persisted.updated_at, new_audit_event_id;
end;
$function$;

create function public.activate_admin_academic_period(
  requested_period_id uuid,
  change_reason text
)
returns table(
  period_id uuid,
  code text,
  name text,
  starts_on date,
  ends_on date,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz,
  audit_event_id uuid
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  actor_profile_id uuid := auth.uid();
  normalized_reason text;
  target_period public.academic_periods%rowtype;
  persisted public.academic_periods%rowtype;
  impact record;
  new_audit_event_id uuid;
begin
  if actor_profile_id is null
     or not public.is_exact_sem01_period_admin_0011(actor_profile_id) then
    raise exception 'sitaa_sem01_admin_access_denied' using errcode = '42501';
  end if;
  normalized_reason := public.normalize_sem01_reason_0011(change_reason);
  perform public.lock_and_reauthorize_sem01_admin_0011(actor_profile_id);

  select period.* into target_period
  from public.academic_periods period
  where period.id = requested_period_id
  for update;
  if not found then
    raise exception 'sitaa_sem01_period_not_found' using errcode = 'P0002';
  end if;
  if target_period.code = 'pilot' then
    raise exception 'sitaa_sem01_pilot_immutable' using errcode = '23514';
  end if;
  if target_period.is_active then
    raise exception 'sitaa_sem01_period_already_active' using errcode = '22023';
  end if;

  select * into impact
  from public.diagnose_academic_period_impact_0011(
    'replace', target_period.id, target_period.code, target_period.name,
    target_period.starts_on, target_period.ends_on, true
  );
  if impact.stored_attribution_mismatch_count > 0
     or impact.assigned_resolution_change_count > 0
     or impact.non_draft_inconsistent_count > 0
     or impact.non_draft_resolution_change_count > 0
     or impact.resolved_draft_loss_or_switch_count > 0 then
    raise exception 'sitaa_sem01_calendar_impact_blocked' using errcode = '23514';
  end if;

  begin
    update public.academic_periods period
    set is_active = true
    where period.id = target_period.id
    returning * into persisted;
  exception when exclusion_violation then
    raise exception 'sitaa_sem01_period_overlap' using errcode = '23P01';
  end;

  insert into public.academic_period_audit_events(
    actor_profile_id, academic_period_id, period_code, action_code,
    outcome, reason, changed_fields, old_values, new_values, occurred_at
  ) values (
    actor_profile_id, persisted.id, persisted.code,
    'academic_period_activated', 'success', normalized_reason,
    array['is_active']::text[],
    jsonb_build_object('is_active', false),
    jsonb_build_object('is_active', true),
    clock_timestamp()
  ) returning id into new_audit_event_id;

  return query select
    persisted.id, persisted.code, persisted.name,
    persisted.starts_on, persisted.ends_on, persisted.is_active,
    persisted.created_at, persisted.updated_at, new_audit_event_id;
end;
$function$;

create function public.deactivate_admin_academic_period(
  requested_period_id uuid,
  change_reason text
)
returns table(
  period_id uuid,
  code text,
  name text,
  starts_on date,
  ends_on date,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz,
  audit_event_id uuid
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  actor_profile_id uuid := auth.uid();
  normalized_reason text;
  target_period public.academic_periods%rowtype;
  persisted public.academic_periods%rowtype;
  impact record;
  new_audit_event_id uuid;
begin
  if actor_profile_id is null
     or not public.is_exact_sem01_period_admin_0011(actor_profile_id) then
    raise exception 'sitaa_sem01_admin_access_denied' using errcode = '42501';
  end if;
  normalized_reason := public.normalize_sem01_reason_0011(change_reason);
  perform public.lock_and_reauthorize_sem01_admin_0011(actor_profile_id);

  select period.* into target_period
  from public.academic_periods period
  where period.id = requested_period_id
  for update;
  if not found then
    raise exception 'sitaa_sem01_period_not_found' using errcode = 'P0002';
  end if;
  if target_period.code = 'pilot' then
    raise exception 'sitaa_sem01_pilot_immutable' using errcode = '23514';
  end if;
  if not target_period.is_active then
    raise exception 'sitaa_sem01_period_already_inactive' using errcode = '22023';
  end if;

  select * into impact
  from public.diagnose_academic_period_impact_0011(
    'replace', target_period.id, target_period.code, target_period.name,
    target_period.starts_on, target_period.ends_on, false
  );
  if impact.stored_attribution_mismatch_count > 0
     or impact.assigned_resolution_change_count > 0
     or impact.non_draft_inconsistent_count > 0
     or impact.non_draft_resolution_change_count > 0
     or impact.resolved_draft_loss_or_switch_count > 0 then
    raise exception 'sitaa_sem01_calendar_impact_blocked' using errcode = '23514';
  end if;

  update public.academic_periods period
  set is_active = false
  where period.id = target_period.id
  returning * into persisted;

  insert into public.academic_period_audit_events(
    actor_profile_id, academic_period_id, period_code, action_code,
    outcome, reason, changed_fields, old_values, new_values, occurred_at
  ) values (
    actor_profile_id, persisted.id, persisted.code,
    'academic_period_deactivated', 'success', normalized_reason,
    array['is_active']::text[],
    jsonb_build_object('is_active', true),
    jsonb_build_object('is_active', false),
    clock_timestamp()
  ) returning id into new_audit_event_id;

  return query select
    persisted.id, persisted.code, persisted.name,
    persisted.starts_on, persisted.ends_on, persisted.is_active,
    persisted.created_at, persisted.updated_at, new_audit_event_id;
end;
$function$;

-- ---------------------------------------------------------------------------
-- ACL mínimo y explícito.
-- ---------------------------------------------------------------------------

revoke all privileges on table public.academic_periods from service_role;
grant select on table public.academic_periods to service_role;
revoke insert, update, delete, truncate, references, trigger on table public.academic_periods from authenticated;
grant select on table public.academic_periods to authenticated;
revoke all privileges on table public.academic_periods from public, anon;

revoke all privileges on table public.academic_period_audit_events
  from public, anon, authenticated, service_role;

revoke all on function public.is_exact_sem01_period_admin_0011(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.lock_and_reauthorize_sem01_admin_0011(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.normalize_sem01_reason_0011(text)
  from public, anon, authenticated, service_role;
revoke all on function public.is_sem01_audit_payload_valid_0011(text,text[],jsonb,jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.resolve_academic_period_proposal_0011(date,text,uuid,text,text,date,date,boolean)
  from public, anon, authenticated, service_role;
revoke all on function public.diagnose_academic_period_impact_0011(text,uuid,text,text,date,date,boolean)
  from public, anon, authenticated, service_role;
revoke all on function public.acquire_sem01_calendar_lock_0011()
  from public, anon, authenticated, service_role;
revoke all on function public.guard_academic_periods_sem01_0011()
  from public, anon, authenticated, service_role;
revoke all on function public.set_academic_period_updated_at_0011()
  from public, anon, authenticated, service_role;
revoke all on function public.guard_academic_period_audit_append_only_0011()
  from public, anon, authenticated, service_role;
revoke all on function public.validate_activity_scheduled_state()
  from public, anon, authenticated, service_role;

revoke all on function public.get_academic_period_for_date(date)
  from public, anon, authenticated, service_role;
grant execute on function public.get_academic_period_for_date(date)
  to authenticated, service_role;

revoke all on function public.publish_activity(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.publish_activity(uuid)
  to authenticated, service_role;

revoke all on function public.list_admin_academic_periods(integer,integer)
  from public, anon, authenticated, service_role;
revoke all on function public.create_admin_academic_period(text,date,date,boolean)
  from public, anon, authenticated, service_role;
revoke all on function public.correct_admin_academic_period(uuid,text,date,date,text)
  from public, anon, authenticated, service_role;
revoke all on function public.activate_admin_academic_period(uuid,text)
  from public, anon, authenticated, service_role;
revoke all on function public.deactivate_admin_academic_period(uuid,text)
  from public, anon, authenticated, service_role;

grant execute on function public.list_admin_academic_periods(integer,integer) to authenticated;
grant execute on function public.create_admin_academic_period(text,date,date,boolean) to authenticated;
grant execute on function public.correct_admin_academic_period(uuid,text,date,date,text) to authenticated;
grant execute on function public.activate_admin_academic_period(uuid,text) to authenticated;
grant execute on function public.deactivate_admin_academic_period(uuid,text) to authenticated;

-- ---------------------------------------------------------------------------
-- Postcondiciones exactas antes de COMMIT.
-- ---------------------------------------------------------------------------

do $postconditions$
declare
  expected_signature text;
  observed_count bigint;
begin
  foreach expected_signature in array array[
    'public.list_admin_academic_periods(integer,integer)',
    'public.create_admin_academic_period(text,date,date,boolean)',
    'public.correct_admin_academic_period(uuid,text,date,date,text)',
    'public.activate_admin_academic_period(uuid,text)',
    'public.deactivate_admin_academic_period(uuid,text)',
    'public.get_academic_period_for_date(date)',
    'public.publish_activity(uuid)'
  ] loop
    if to_regprocedure(expected_signature) is null then
      raise exception 'sitaa_0011_missing_expected_function' using errcode = '55000';
    end if;
  end loop;

  if to_regclass('public.academic_period_audit_events') is null
     or not exists (
       select 1 from pg_catalog.pg_constraint
       where conrelid = 'public.academic_periods'::regclass
         and conname = 'academic_periods_active_date_range_excl'
         and contype = 'x'
     )
     or not exists (
       select 1 from pg_catalog.pg_trigger
       where tgrelid = 'public.activities'::regclass
         and tgname = 'activities_sem01_lock_insert'
         and not tgisinternal
     )
     or not exists (
       select 1 from pg_catalog.pg_trigger
       where tgrelid = 'public.activities'::regclass
         and tgname = 'activities_sem01_lock_update'
         and not tgisinternal
     ) then
    raise exception 'sitaa_0011_missing_expected_object' using errcode = '55000';
  end if;

  if (select count(*) from public.academic_periods) <> 5
     or not exists (
       select 1 from public.academic_periods
       where code = 'pilot' and not is_active
         and starts_on is null and ends_on is null
     ) then
    raise exception 'sitaa_0011_seed_preservation_failed' using errcode = '55000';
  end if;

  if has_table_privilege('authenticated', 'public.academic_periods', 'INSERT')
     or has_table_privilege('authenticated', 'public.academic_periods', 'UPDATE')
     or has_table_privilege('authenticated', 'public.academic_periods', 'DELETE')
     or has_table_privilege('service_role', 'public.academic_periods', 'INSERT')
     or has_table_privilege('service_role', 'public.academic_periods', 'UPDATE')
     or has_table_privilege('service_role', 'public.academic_periods', 'DELETE')
     or has_table_privilege('authenticated', 'public.academic_period_audit_events', 'SELECT')
     or has_table_privilege('service_role', 'public.academic_period_audit_events', 'INSERT') then
    raise exception 'sitaa_0011_excessive_table_privilege' using errcode = '55000';
  end if;

  if has_function_privilege('anon', 'public.list_admin_academic_periods(integer,integer)', 'EXECUTE')
     or exists (
       select 1
       from pg_catalog.pg_proc routine
       cross join lateral pg_catalog.aclexplode(
         coalesce(routine.proacl, pg_catalog.acldefault('f', routine.proowner))
       ) privilege
       where routine.oid = 'public.create_admin_academic_period(text,date,date,boolean)'::regprocedure
         and privilege.grantee = 0
         and privilege.privilege_type = 'EXECUTE'
     )
     or not has_function_privilege('authenticated', 'public.create_admin_academic_period(text,date,date,boolean)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.is_exact_sem01_period_admin_0011(uuid)', 'EXECUTE') then
    raise exception 'sitaa_0011_unexpected_function_privilege' using errcode = '55000';
  end if;

  if (select count(*) from public.academic_period_audit_events) <> 0 then
    raise exception 'sitaa_0011_migration_created_audit_history' using errcode = '55000';
  end if;

  select count(*) into observed_count
  from pg_catalog.pg_class relation
  join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
  where namespace.nspname = 'public' and relation.relkind in ('r', 'p');
  if observed_count <> 20
     or (select count(*) from information_schema.columns where table_schema = 'public') <> 194
     or (select count(*) from pg_catalog.pg_constraint constraint_info
       join pg_catalog.pg_class relation on relation.oid = constraint_info.conrelid
       join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
       where namespace.nspname = 'public') <> 105
     or (select count(*) from pg_catalog.pg_indexes where schemaname = 'public') <> 52
     or (select count(*) from pg_catalog.pg_trigger trigger_info
       join pg_catalog.pg_class relation on relation.oid = trigger_info.tgrelid
       join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
       where namespace.nspname = 'public' and not trigger_info.tgisinternal) <> 20
     or (select count(*) from pg_catalog.pg_proc routine
       join pg_catalog.pg_namespace namespace on namespace.oid = routine.pronamespace
       where namespace.nspname = 'public' and routine.prokind = 'f') <> 75
     or (select count(*) from pg_catalog.pg_policy policy
       join pg_catalog.pg_class relation on relation.oid = policy.polrelid
       join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
       where namespace.nspname = 'public') <> 25
     or (select count(*) from pg_catalog.pg_class relation
       join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
       where namespace.nspname = 'public'
         and relation.relkind in ('r', 'p') and relation.relrowsecurity) <> 20 then
    raise exception 'sitaa_0011_unexpected_post_schema_inventory' using errcode = '55000';
  end if;
end;
$postconditions$;

commit;
