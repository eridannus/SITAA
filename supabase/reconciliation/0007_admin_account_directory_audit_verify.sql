-- Verificador transaccional 0007. Sólo usa identidades sintéticas y termina en ROLLBACK.
begin;

-- Contrato estático de objetos, RLS, firmas, search_path y privilegios.
do $static_contract$
declare
  rpc regprocedure;
  mexico_date_helper regprocedure := to_regprocedure('public.sitaa_current_mexico_date()');
  authority_helper regprocedure := to_regprocedure('public.is_b1_account_admin()');
  metadata_helper regprocedure := to_regprocedure('public.admin_audit_metadata_is_safe(jsonb)');
  mutation_helper regprocedure := to_regprocedure('public.prevent_admin_audit_event_mutation()');
  audit_table regclass := to_regclass('public.admin_audit_events');
  authority_definition text;
  search_definition text;
  assignments_definition text;
  metadata_definition text;
  mutation_definition text;
begin
  if mexico_date_helper is null
     or not exists (
       select 1
       from pg_proc p
       where p.oid = mexico_date_helper
         and p.prorettype = 'date'::regtype
         and p.provolatile = 's'
         and p.prosecdef = false
         and p.prolang = (select oid from pg_language where lanname = 'sql')
         and coalesce(p.proconfig, '{}'::text[]) = array['search_path=pg_catalog']::text[]
         and lower(pg_get_functiondef(p.oid)) like '%america/mexico_city%'
     )
     or exists (
       select 1
       from pg_proc p
       cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
       where p.oid = mexico_date_helper
         and acl.privilege_type = 'EXECUTE'
         and (
           acl.grantee = 0
           or acl.grantee = (select oid from pg_roles where rolname = 'anon')
           or acl.grantee = (select oid from pg_roles where rolname = 'authenticated')
           or acl.grantee = (select oid from pg_roles where rolname = 'service_role')
         )
     ) then
    raise exception '0007: helper privado de fecha institucional inválido.';
  end if;

  authority_definition := lower(pg_get_functiondef(authority_helper));
  search_definition := lower(pg_get_functiondef(
    'public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)'::regprocedure
  ));
  assignments_definition := lower(pg_get_functiondef(
    'public.get_admin_account_assignments_b1(uuid)'::regprocedure
  ));
  metadata_definition := lower(pg_get_functiondef(metadata_helper));
  mutation_definition := lower(pg_get_functiondef(mutation_helper));
  if authority_definition not like '%public.sitaa_current_mexico_date()%'
     or authority_definition ~ '\mcurrent_date\M'
     or search_definition not like '%public.sitaa_current_mexico_date()%'
     or search_definition ~ '\mcurrent_date\M'
     or assignments_definition not like '%public.sitaa_current_mexico_date()%'
     or assignments_definition ~ '\mcurrent_date\M'
     or metadata_definition !~ 'octet_length\(candidate::text\)\s*>\s*16384' then
    raise exception '0007: contrato temporal o límite de metadata no coincide con la migración.';
  end if;

  if audit_table is null then
    raise exception '0007: falta public.admin_audit_events.';
  end if;

  -- Esquema físico exacto: nueve columnas, en el orden y con los defaults de 0007.
  if (select count(*) from pg_attribute where attrelid = audit_table and attnum > 0 and not attisdropped) <> 9
     or exists (
       with expected(attnum, column_name, type_oid, not_null, default_kind) as (
         values
           (1::smallint, 'id', 'uuid'::regtype::oid, true, 'uuid'),
           (2::smallint, 'actor_profile_id', 'uuid'::regtype::oid, true, null),
           (3::smallint, 'target_profile_id', 'uuid'::regtype::oid, true, null),
           (4::smallint, 'action_code', 'text'::regtype::oid, true, null),
           (5::smallint, 'outcome', 'text'::regtype::oid, true, null),
           (6::smallint, 'reason', 'text'::regtype::oid, false, null),
           (7::smallint, 'role_assignment_id', 'uuid'::regtype::oid, false, null),
           (8::smallint, 'metadata', 'jsonb'::regtype::oid, true, 'empty_json'),
           (9::smallint, 'occurred_at', 'timestamptz'::regtype::oid, true, 'now')
       ), observed as (
         select a.attnum, a.attname, a.atttypid, a.attnotnull, d.oid as default_oid,
           regexp_replace(lower(pg_get_expr(d.adbin, d.adrelid, true)), '\s+', '', 'g') as default_expression
         from pg_attribute a
         left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
         where a.attrelid = audit_table and a.attnum > 0 and not a.attisdropped
       )
       select 1
       from expected e
       left join observed o on o.attnum = e.attnum
       where o.attnum is null
          or o.attname <> e.column_name
          or o.atttypid <> e.type_oid
          or o.attnotnull <> e.not_null
          or (e.default_kind is null and o.default_oid is not null)
          or (e.default_kind = 'uuid' and coalesce(o.default_expression, '') !~ '^(pg_catalog\.)?gen_random_uuid\(\)$')
          or (e.default_kind = 'empty_json' and coalesce(o.default_expression, '') <> '''{}''::jsonb')
          or (e.default_kind = 'now' and coalesce(o.default_expression, '') !~ '^(pg_catalog\.)?now\(\)$')
     ) then
    raise exception '0007: columnas, orden, tipos, nulabilidad o defaults de admin_audit_events inválidos.';
  end if;

  -- Una PK exacta y tres FK exactas, todas restrictivas.
  if (select count(*) from pg_constraint where conrelid = audit_table and contype = 'p') <> 1
     or not exists (
       select 1 from pg_constraint c
       where c.conrelid = audit_table and c.contype = 'p'
         and c.conkey = array[(select attnum from pg_attribute where attrelid = audit_table and attname = 'id')]::smallint[]
     )
     or (select count(*) from pg_constraint where conrelid = audit_table and contype = 'f') <> 3
     or exists (
       with expected(local_column, referenced_table, referenced_column) as (
         values
           ('actor_profile_id', 'public.profiles'::regclass, 'id'),
           ('target_profile_id', 'public.profiles'::regclass, 'id'),
           ('role_assignment_id', 'public.role_assignments'::regclass, 'id')
       )
       select 1 from expected e
       where not exists (
         select 1
         from pg_constraint c
         where c.conrelid = audit_table
           and c.contype = 'f'
           and c.confrelid = e.referenced_table
           and c.confdeltype = 'r'
           and c.conkey = array[(select attnum from pg_attribute where attrelid = audit_table and attname = e.local_column)]::smallint[]
           and c.confkey = array[(select attnum from pg_attribute where attrelid = e.referenced_table and attname = e.referenced_column)]::smallint[]
       )
     ) then
    raise exception '0007: PK o referencias restrictivas de admin_audit_events inválidas.';
  end if;

  -- Cuatro CHECK exactos y con semántica real, no sólo por nombre.
  if (select count(*) from pg_constraint where conrelid = audit_table and contype = 'c') <> 4
     or (select count(*) from pg_constraint where conrelid = audit_table and contype = 'c'
           and conname in ('admin_audit_events_action_code_check','admin_audit_events_outcome_check',
             'admin_audit_events_reason_check','admin_audit_events_metadata_check')) <> 4
     or not exists (
       select 1 from pg_constraint c
       cross join lateral (
         select replace(regexp_replace(lower(pg_get_constraintdef(c.oid, true)), '\s+', '', 'g'), '::text', '') value
       ) normalized
       where c.conrelid = audit_table and c.conname = 'admin_audit_events_action_code_check'
         and position('char_length(action_code)>=1' in normalized.value) > 0
         and position('char_length(action_code)<=100' in normalized.value) > 0
         and position('action_code~''^[a-z][a-z0-9]*(_[a-z0-9]+)*$''' in normalized.value) > 0
         and replace(replace(normalized.value, '(', ''), ')', '')
           = 'checkchar_lengthaction_code>=1andchar_lengthaction_code<=100andaction_code~''^[a-z][a-z0-9]*_[a-z0-9]+*$'''
     )
     or not exists (
       select 1 from pg_constraint c
       cross join lateral (
         select replace(replace(replace(regexp_replace(lower(pg_get_constraintdef(c.oid, true)), '\s+', '', 'g'), '::text', ''), '(', ''), ')', '') value
       ) normalized
       where c.conrelid = audit_table and c.conname = 'admin_audit_events_outcome_check'
         and normalized.value = 'checkoutcome=anyarray[''success'',''failure'']'
     )
     or not exists (
       select 1 from pg_constraint c
       cross join lateral (
         select regexp_replace(lower(pg_get_constraintdef(c.oid, true)), '\s+', '', 'g') value
       ) normalized
       where c.conrelid = audit_table and c.conname = 'admin_audit_events_reason_check'
         and position('reasonisnull' in normalized.value) > 0
         and position('reason=btrim(reason)' in normalized.value) > 0
         and position('char_length(reason)>=1' in normalized.value) > 0
         and position('char_length(reason)<=1000' in normalized.value) > 0
         and replace(replace(normalized.value, '(', ''), ')', '')
           = 'checkreasonisnullorreason=btrimreasonandchar_lengthreason>=1andchar_lengthreason<=1000'
     )
     or not exists (
         select 1 from pg_constraint c
       where c.conrelid = audit_table and c.conname = 'admin_audit_events_metadata_check'
         and regexp_replace(lower(pg_get_constraintdef(c.oid, true)), '\s+', '', 'g')
           like '%admin_audit_metadata_is_safe(metadata)%'
         and replace(replace(regexp_replace(lower(pg_get_constraintdef(c.oid, true)), '\s+', '', 'g'), '(', ''), ')', '')
           in ('checkadmin_audit_metadata_is_safemetadata','checkpublic.admin_audit_metadata_is_safemetadata')
         and exists (
           select 1 from pg_depend d
           where d.classid = 'pg_constraint'::regclass and d.objid = c.oid
             and d.refclassid = 'pg_proc'::regclass and d.refobjid = metadata_helper
         )
     ) then
    raise exception '0007: restricciones CHECK exactas de admin_audit_events inválidas.';
  end if;

  -- Los cuatro índices introducidos deben conservar claves, orden y propiedades físicas.
  if exists (
    with expected(index_name, table_oid, columns_in_order, directions) as (
      values
        ('admin_audit_events_target_occurred_idx', audit_table, array['target_profile_id','occurred_at','id']::text[], array['asc','desc','desc']::text[]),
        ('admin_audit_events_actor_occurred_idx', audit_table, array['actor_profile_id','occurred_at','id']::text[], array['asc','desc','desc']::text[]),
        ('profiles_admin_directory_sort_idx', 'public.profiles'::regclass, array['paternal_surname','maternal_surname','first_names','id']::text[], array['asc','asc','asc','asc']::text[]),
        ('profiles_admin_directory_filters_idx', 'public.profiles'::regclass, array['account_status','account_kind','person_type','primary_program_id']::text[], array['asc','asc','asc','asc']::text[])
    )
    select 1
    from expected e
    left join pg_class ic on ic.relname = e.index_name
      and ic.relnamespace = (select oid from pg_namespace where nspname = 'public')
    left join pg_index i on i.indexrelid = ic.oid
    left join pg_am am on am.oid = ic.relam
    where i.indexrelid is null
       or i.indrelid <> e.table_oid
       or am.amname <> 'btree'
       or i.indisunique
       or not i.indisvalid
       or not i.indisready
       or i.indpred is not null
       or i.indexprs is not null
       or i.indnkeyatts <> cardinality(e.columns_in_order)
       or i.indnatts <> cardinality(e.columns_in_order)
       or array(
         select a.attname::text
         from unnest(i.indkey::smallint[]) with ordinality key_column(attnum, ordinality_position)
         join pg_attribute a on a.attrelid = i.indrelid and a.attnum = key_column.attnum
         order by key_column.ordinality_position
       ) <> e.columns_in_order
       or array(
         select case when (index_option::integer & 1) = 1 then 'desc' else 'asc' end
         from unnest(i.indoption::smallint[]) with ordinality option_column(index_option, ordinality_position)
         order by option_column.ordinality_position
       ) <> e.directions
  ) then
    raise exception '0007: definición semántica de índices B.1 inválida.';
  end if;

  -- Dos triggers exactos: mutación por fila y TRUNCATE por sentencia.
  if (select count(*) from pg_trigger where tgrelid = audit_table and not tgisinternal) <> 2
     or not exists (
       select 1 from pg_trigger
       where tgrelid = audit_table and not tgisinternal
         and tgname = 'prevent_admin_audit_event_mutation'
         and tgfoid = mutation_helper and tgtype = 27 and tgenabled = 'O'
     )
     or not exists (
       select 1 from pg_trigger
       where tgrelid = audit_table and not tgisinternal
         and tgname = 'prevent_admin_audit_event_truncate'
         and tgfoid = mutation_helper and tgtype = 34 and tgenabled = 'O'
     ) then
    raise exception '0007: triggers append-only, eventos o granularidad inválidos.';
  end if;

  -- RLS y ACL completos de tabla/columnas: sólo owner y service_role en el ACL directo.
  if not exists(select 1 from pg_roles where rolname='service_role' and rolbypassrls=true)
     or not exists (
       select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relname = 'admin_audit_events' and c.relrowsecurity
     )
     or exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'admin_audit_events')
     or exists (
       select 1
       from (values ('anon'),('authenticated')) client(role_name)
       cross join (values ('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),('REFERENCES'),('TRIGGER'),('MAINTAIN')) privilege(privilege_name)
       where has_table_privilege(client.role_name, audit_table, privilege.privilege_name)
     )
     or not has_table_privilege('service_role','public.admin_audit_events','SELECT')
     or not has_table_privilege('service_role','public.admin_audit_events','INSERT')
     or has_table_privilege('service_role','public.admin_audit_events','UPDATE')
     or has_table_privilege('service_role','public.admin_audit_events','DELETE')
     or has_table_privilege('service_role','public.admin_audit_events','TRUNCATE')
     or has_table_privilege('service_role','public.admin_audit_events','REFERENCES')
     or has_table_privilege('service_role','public.admin_audit_events','TRIGGER')
     or has_table_privilege('service_role','public.admin_audit_events','MAINTAIN')
     or exists (
       select 1
       from pg_class c
       cross join lateral aclexplode(c.relacl) acl
       where c.oid = audit_table
         and acl.grantee = (select oid from pg_roles where rolname = 'service_role')
         and (upper(acl.privilege_type) not in ('SELECT','INSERT') or acl.is_grantable)
     )
     or (select count(*) from pg_class c cross join lateral aclexplode(c.relacl) acl
           where c.oid = audit_table
             and acl.grantee = (select oid from pg_roles where rolname = 'service_role')) <> 2
     or exists (
       select 1 from pg_class c
       cross join lateral aclexplode(c.relacl) acl
       where c.oid = audit_table
         and acl.grantee not in (c.relowner, (select oid from pg_roles where rolname='service_role'))
     )
     or exists (
       select 1
       from pg_attribute a
       where a.attrelid = audit_table and a.attnum > 0 and not a.attisdropped
         and a.attacl is not null
         and exists (select 1 from aclexplode(a.attacl))
     )
     or exists (
       select 1
       from pg_attribute a
       cross join (values ('anon'),('authenticated')) client(role_name)
       cross join (values ('SELECT'),('INSERT'),('UPDATE'),('REFERENCES')) privilege(privilege_name)
       where a.attrelid = audit_table and a.attnum > 0 and not a.attisdropped
         and has_column_privilege(client.role_name, audit_table, a.attname, privilege.privilege_name)
     )
     or exists (
       select 1
       from pg_attribute a
       cross join (values ('UPDATE'),('REFERENCES')) privilege(privilege_name)
       where a.attrelid = audit_table and a.attnum > 0 and not a.attisdropped
         and has_column_privilege('service_role', audit_table, a.attname, privilege.privilege_name)
     ) then
    raise exception '0007: contrato RLS o privilegios de admin_audit_events inválido.';
  end if;

  -- Firmas nominales exactas para PostgREST: entradas y TABLE outputs en orden.
  if regexp_replace(lower(pg_get_function_identity_arguments(
       'public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)'::regprocedure)), '\s+', '', 'g')
       <> 'search_texttext,program_filteruuid,account_kind_filtertext,account_status_filtertext,person_type_filtertext,role_code_filtertext,service_area_filtertext,scope_type_filtertext,page_numberinteger,page_sizeinteger'
     or regexp_replace(lower(pg_get_function_result(
       'public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)'::regprocedure)), '\s+', '', 'g')
       <> 'table(profile_iduuid,first_namestext,paternal_surnametext,maternal_surnametext,full_nametext,emailtext,account_kindtext,account_statustext,person_typetext,primary_program_iduuid,primary_program_nametext,institutional_id_typetext,masked_institutional_idtext,current_assignment_countbigint,total_countbigint)'
     or regexp_replace(lower(pg_get_function_identity_arguments(
       'public.get_admin_account_detail_b1(uuid)'::regprocedure)), '\s+', '', 'g')
       <> 'target_profile_iduuid'
     or regexp_replace(lower(pg_get_function_result(
       'public.get_admin_account_detail_b1(uuid)'::regprocedure)), '\s+', '', 'g')
       <> 'table(profile_iduuid,first_namestext,paternal_surnametext,maternal_surnametext,full_nametext,emailtext,account_kindtext,account_statustext,person_typetext,institutional_id_typetext,institutional_id_valuetext,primary_program_iduuid,primary_program_nametext,activated_attimestampwithtimezone,deactivated_attimestampwithtimezone,auth_email_confirmedboolean)'
     or regexp_replace(lower(pg_get_function_identity_arguments(
       'public.get_admin_account_assignments_b1(uuid)'::regprocedure)), '\s+', '', 'g')
       <> 'target_profile_iduuid'
     or regexp_replace(lower(pg_get_function_result(
       'public.get_admin_account_assignments_b1(uuid)'::regprocedure)), '\s+', '', 'g')
       <> 'table(iduuid,role_codetext,role_labeltext,scope_typetext,service_areatext,division_iduuid,division_nametext,program_iduuid,program_nametext,starts_atdate,ends_atdate,is_activeboolean,assigned_byuuid,created_attimestampwithtimezone,presentation_statustext)'
     or regexp_replace(lower(pg_get_function_identity_arguments(
       'public.get_admin_account_audit_history_b1(uuid,integer,integer)'::regprocedure)), '\s+', '', 'g')
       <> 'requested_profile_iduuid,result_limitinteger,result_offsetinteger'
     or regexp_replace(lower(pg_get_function_result(
       'public.get_admin_account_audit_history_b1(uuid,integer,integer)'::regprocedure)), '\s+', '', 'g')
       <> 'table(iduuid,actor_profile_iduuid,actor_display_nametext,target_profile_iduuid,action_codetext,outcometext,reasontext,role_assignment_iduuid,occurred_attimestampwithtimezone)' then
    raise exception '0007: firma nominal, tipos u orden de columnas RPC inválidos.';
  end if;

  foreach rpc in array array[
    'public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)'::regprocedure,
    'public.get_admin_account_detail_b1(uuid)'::regprocedure,
    'public.get_admin_account_assignments_b1(uuid)'::regprocedure,
    'public.get_admin_account_audit_history_b1(uuid,integer,integer)'::regprocedure
  ] loop
    if not has_function_privilege('authenticated', rpc, 'EXECUTE')
       or has_function_privilege('anon', rpc, 'EXECUTE')
       or has_function_privilege('service_role', rpc, 'EXECUTE')
       or exists (
         select 1 from aclexplode((select coalesce(proacl, acldefault('f', proowner)) from pg_proc where oid = rpc))
         where grantee = 0 and privilege_type = 'EXECUTE'
       )
       or (select not prosecdef from pg_proc where oid = rpc)
       or lower(pg_get_functiondef(rpc)) not like '%set search_path%pg_catalog%public%'
       or (select count(*) from pg_proc p cross join lateral aclexplode(p.proacl) acl
             where p.oid = rpc and acl.privilege_type = 'EXECUTE') <> 2
       or exists (
         select 1 from pg_proc p cross join lateral aclexplode(p.proacl) acl
         where p.oid = rpc and acl.privilege_type = 'EXECUTE'
           and acl.grantee not in (p.proowner, (select oid from pg_roles where rolname='authenticated'))
       )
       or not exists (
         select 1 from pg_proc p cross join lateral aclexplode(p.proacl) acl
         where p.oid = rpc and acl.privilege_type = 'EXECUTE'
           and acl.grantee = (select oid from pg_roles where rolname='authenticated')
           and not acl.is_grantable
       ) then
      raise exception '0007: privilegio, SECURITY DEFINER o search_path inválido para %.', rpc;
    end if;
  end loop;

  -- Propiedades semánticas exactas de los helpers privados.
  if authority_helper is null
     or not exists (
       select 1 from pg_proc p
       where p.oid = authority_helper and p.prorettype = 'boolean'::regtype
         and p.provolatile = 's' and p.prosecdef
         and coalesce(p.proconfig, '{}'::text[]) = array['search_path=pg_catalog, public']::text[]
     )
     or authority_definition not like '%auth.uid()%'
     or authority_definition not like '%p.account_status = ''active''%'
     or authority_definition not like '%p.is_active = true%'
     or authority_definition not like '%ra.role_code = ''technical_admin''%'
     or authority_definition not like '%ra.scope_type = ''system''%'
     or authority_definition not like '%ra.service_area = ''technical''%'
     or authority_definition not like '%ra.program_id is null%'
     or authority_definition not like '%ra.division_id is null%'
     or authority_definition not like '%ra.is_active = true%'
     or authority_definition not like '%ra.starts_at <= public.sitaa_current_mexico_date()%'
     or authority_definition not like '%ra.ends_at >= public.sitaa_current_mexico_date()%' then
    raise exception '0007: definición del helper de autoridad B.1 inválida.';
  end if;

  if metadata_helper is null
     or not exists (
       select 1 from pg_proc p
       where p.oid = metadata_helper and p.prorettype = 'boolean'::regtype
         and p.provolatile = 'i' and not p.prosecdef
         and coalesce(p.proconfig, '{}'::text[]) = array['search_path=pg_catalog, public']::text[]
     )
     or metadata_definition not like '%jsonb_typeof(candidate) <> ''object''%'
     or metadata_definition !~ 'octet_length\(candidate::text\)\s*>\s*16384'
     or metadata_definition not like '%jsonb_object_keys(candidate)%'
     or metadata_definition not like '%regexp_replace(lower(key_name), ''[^a-z0-9]+'', '''', ''g'')%'
     or metadata_definition not like '%password|passwd|token|cookie|secret|authorization|credential|recovery|session|bearer|apikey%' then
    raise exception '0007: definición del validador de metadata inválida.';
  end if;

  if mutation_helper is null
     or not exists (
       select 1 from pg_proc p
       where p.oid = mutation_helper and p.prorettype = 'trigger'::regtype and p.prosecdef
          and p.prolang = (select oid from pg_language where lanname = 'plpgsql')
          and coalesce(p.proconfig, '{}'::text[]) = array['search_path=pg_catalog, public']::text[]
          and btrim(regexp_replace(lower(p.prosrc), '\s+', ' ', 'g'))
            = 'begin raise exception ''sitaa_admin_audit_is_append_only'' using errcode = ''55000''; end;'
      )
     or mutation_definition not like '%raise exception ''sitaa_admin_audit_is_append_only'' using errcode = ''55000''%' then
    raise exception '0007: definición del helper append-only inválida.';
  end if;

  -- Regresión del arnés: pg_proc.prosrc puede conservar saltos de línea externos.
  if btrim(regexp_replace(lower(E'\nbegin\n  raise exception ''sitaa_admin_audit_is_append_only''\n    using errcode = ''55000'';\nend;\n'), '\s+', ' ', 'g'))
       <> 'begin raise exception ''sitaa_admin_audit_is_append_only'' using errcode = ''55000''; end;' then
    raise exception '0007: normalización estática de fuente PL/pgSQL inválida.';
  end if;

  -- ACL owner-only de helpers que nunca deben ser ejecutables por clientes.
  if exists (
        select 1
        from unnest(array[mexico_date_helper, authority_helper, mutation_helper]) helper(function_oid)
        cross join (values ('anon'),('authenticated'),('service_role')) client(role_name)
       where has_function_privilege(client.role_name, helper.function_oid, 'EXECUTE')
     )
     or exists (
       select 1
       from pg_proc p
       cross join lateral aclexplode(p.proacl) acl
        where p.oid in (mexico_date_helper, authority_helper, mutation_helper)
          and acl.privilege_type = 'EXECUTE' and acl.grantee <> p.proowner
      ) then
    raise exception '0007: ACL de helper privado inválido.';
  end if;

  -- El validador de metadata admite únicamente propietario y service_role.
  if has_function_privilege('anon', metadata_helper, 'EXECUTE')
     or has_function_privilege('authenticated', metadata_helper, 'EXECUTE')
     or not has_function_privilege('service_role', metadata_helper, 'EXECUTE')
     or exists (
       select 1
       from pg_proc p
       cross join lateral aclexplode(p.proacl) acl
       where p.oid = metadata_helper
          and acl.privilege_type='EXECUTE'
          and acl.grantee not in (
            p.proowner,
            (select oid from pg_roles where rolname='service_role')
          )
      )
     or (select count(*) from pg_proc p cross join lateral aclexplode(p.proacl) acl
           where p.oid = metadata_helper and acl.privilege_type = 'EXECUTE') <> 2
     or exists (
        select 1 from pg_proc p cross join lateral aclexplode(p.proacl) acl
        where p.oid = metadata_helper and acl.privilege_type = 'EXECUTE' and acl.is_grantable
      ) then
    raise exception '0007: ACL del validador de metadata inválido.';
  end if;

  if lower(pg_get_function_result('public.get_admin_account_detail_b1(uuid)'::regprocedure))
       ~ '(email_confirmed_at|raw_|token|password|cookie|identity_data)'
     or lower(pg_get_function_result('public.get_admin_account_assignments_b1(uuid)'::regprocedure))
       ~ '(revoked_by|revoked_at|administrative_notes)'
     or lower(pg_get_function_result('public.get_admin_account_audit_history_b1(uuid,integer,integer)'::regprocedure))
       ~ '(^|[ ,])metadata([ ,]|$)' then
    raise exception '0007: una proyección RPC expone campos fuera de B.1.';
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'role_assignments'
      and column_name in ('revoked_by','revoked_at','administrative_notes','status')
  ) then
    raise exception '0007: el esquema V1 fue sustituido indebidamente por semántica de Fase C.';
  end if;
end;
$static_contract$;

set local time zone 'UTC';

create temporary table sitaa_0007_context (
  run_id uuid not null,
  run_marker text not null,
  wildcard_marker text not null,
  identifier_seed text not null,
  institutional_today date not null,
  division_id uuid not null,
  program_id uuid not null
) on commit drop;
with generated as (select gen_random_uuid() run_id)
insert into sitaa_0007_context
select run_id,
  'v7' || replace(run_id::text,'-',''),
  'v7' || replace(run_id::text,'-','') || E'%_\\ruta',
  translate(replace(run_id::text,'-',''),'abcdef','012345'),
  (current_timestamp at time zone 'America/Mexico_City')::date,
  gen_random_uuid(), gen_random_uuid()
from generated;

set local time zone 'Pacific/Kiritimati';

do $institutional_date_contract$
declare
  expected_date date := (
    select institutional_today from pg_temp.sitaa_0007_context limit 1
  );
begin
  if current_setting('TimeZone') <> 'Pacific/Kiritimati'
     or public.sitaa_current_mexico_date() is distinct from expected_date
     or public.sitaa_current_mexico_date() is distinct from
       (current_timestamp at time zone 'America/Mexico_City')::date then
    raise exception '0007: la fecha institucional depende de la zona horaria de sesión.';
  end if;
end;
$institutional_date_contract$;

insert into public.divisions (id, code, name)
select division_id, 'v7d_' || left(replace(division_id::text,'-',''), 16), 'División sintética 0007'
from sitaa_0007_context;
insert into public.academic_programs (id, division_id, code, name, is_active)
select program_id, division_id, 'v7p_' || left(replace(program_id::text,'-',''), 16), 'Programa sintético 0007', true
from sitaa_0007_context;

create temporary table sitaa_0007_cases (
  label text primary key,
  id uuid not null unique,
  email text not null unique,
  institutional_identifier text null unique
) on commit drop;

create function pg_temp.case_id(target_label text)
returns uuid language sql stable set search_path = pg_temp as $$
  select id from sitaa_0007_cases where label = target_label
$$;
create function pg_temp.case_email(target_label text)
returns text language sql stable set search_path = pg_temp as $$
  select email from sitaa_0007_cases where label = target_label
$$;
create function pg_temp.case_identifier(target_label text)
returns text language sql stable set search_path = pg_temp as $$
  select institutional_identifier from sitaa_0007_cases where label = target_label
$$;
create function pg_temp.run_marker()
returns text language sql stable set search_path = pg_temp as $$
  select run_marker from sitaa_0007_context limit 1
$$;
create function pg_temp.wildcard_marker()
returns text language sql stable set search_path = pg_temp as $$
  select wildcard_marker from sitaa_0007_context limit 1
$$;
create function pg_temp.set_request_user(target_label text)
returns void language plpgsql set search_path = pg_temp, pg_catalog as $$
declare target_id uuid := pg_temp.case_id(target_label);
begin
  perform set_config('request.jwt.claim.sub', target_id::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', target_id, 'role', 'authenticated')::text, true);
end;
$$;

revoke all on function pg_temp.case_id(text) from public, anon;
revoke all on function pg_temp.case_email(text) from public, anon;
revoke all on function pg_temp.case_identifier(text) from public, anon;
revoke all on function pg_temp.run_marker() from public, anon;
revoke all on function pg_temp.wildcard_marker() from public, anon;
revoke all on function pg_temp.set_request_user(text) from public, anon;
grant select on table pg_temp.sitaa_0007_cases, pg_temp.sitaa_0007_context to authenticated;
grant execute on function pg_temp.case_id(text), pg_temp.case_email(text),
  pg_temp.case_identifier(text), pg_temp.run_marker(), pg_temp.wildcard_marker(),
  pg_temp.set_request_user(text) to authenticated;

create function pg_temp.create_case(
  target_label text,
  target_kind text,
  target_person text default null,
  target_status text default 'active',
  target_confirmed boolean default true
)
returns uuid
language plpgsql
set search_path = public, auth, pg_temp, pg_catalog
as $$
declare
  target_id uuid := gen_random_uuid();
  target_run_marker text := (select run_marker from sitaa_0007_context limit 1);
  target_email text := replace(target_label, '_', '-') || '-' || target_run_marker || '@example.invalid';
  target_program uuid := (select program_id from sitaa_0007_context limit 1);
  case_number integer := (select count(*) + 1 from sitaa_0007_cases);
  target_identifier text;
  app_metadata jsonb;
begin
  if target_kind <> 'technical' then
    target_identifier := (select identifier_seed from sitaa_0007_context limit 1)
      || lpad(case_number::text,3,'0');
  end if;
  if target_kind = 'technical' then
    app_metadata := jsonb_build_object(
      'sitaa_account_kind','technical',
      'sitaa_first_names','Soporte ' || target_run_marker
    );
  else
    app_metadata := jsonb_build_object('provider','google','providers',jsonb_build_array('google'));
  end if;
  insert into sitaa_0007_cases
  values (target_label, target_id, target_email, target_identifier);
  insert into auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values (
    target_id, 'authenticated', 'authenticated', target_email, '',
    case when target_confirmed then now() else null end,
    app_metadata, jsonb_build_object('name','Cuenta sintética'), now(), now()
  );

  if target_kind = 'technical' then
    update public.profiles set
      first_names = 'Soporte ' || target_run_marker, paternal_surname = null, maternal_surname = null,
      full_name = 'Soporte ' || target_run_marker, account_kind = 'technical',
      account_status = target_status, person_type = null, primary_program_id = null,
      institutional_id_type = null, institutional_id_value = null,
      is_active = (target_status = 'active'), activated_at = now(),
      deactivated_at = case when target_status = 'inactive' then now() else null end
    where id = target_id;
  else
    update public.profiles set
      first_names = case when target_label = 'target_account'
        then (select wildcard_marker from sitaa_0007_context limit 1)
        else 'Persona ' || target_run_marker end,
      paternal_surname = case when target_label = 'target_account' then 'Única' else 'Sintética' end,
      maternal_surname = 'Prueba',
      full_name = case when target_label = 'target_account'
        then (select wildcard_marker from sitaa_0007_context limit 1) || ' Única Prueba'
        else 'Persona ' || target_run_marker || ' Sintética Prueba' end,
      account_kind = 'institutional', account_status = target_status,
      person_type = target_person, primary_program_id = target_program,
      institutional_id_type = case when target_person = 'student' then 'student_account' else 'worker_number' end,
      institutional_id_value = target_identifier,
      is_active = (target_status = 'active'), activated_at = now(),
      deactivated_at = case when target_status = 'inactive' then now() else null end
    where id = target_id;
  end if;
  return target_id;
end;
$$;

select pg_temp.create_case('admin_exact','technical');
select pg_temp.create_case('ordinary_student','institutional','student');
select pg_temp.create_case('ordinary_professor','institutional','professor');
select pg_temp.create_case('admin_bad_scope','technical');
select pg_temp.create_case('admin_bad_service','technical');
select pg_temp.create_case('admin_bad_program','technical');
select pg_temp.create_case('admin_bad_division','technical');
select pg_temp.create_case('admin_future','technical');
select pg_temp.create_case('admin_expired','technical');
select pg_temp.create_case('admin_inactive_assignment','technical');
select pg_temp.create_case('admin_start_today','technical');
select pg_temp.create_case('admin_end_today','technical');
select pg_temp.create_case('admin_inactive','technical',null,'inactive');
select pg_temp.create_case('target_account','institutional','student');
select pg_temp.create_case('same_row_target','institutional','professor');
select pg_temp.create_case('google_confirmed','institutional','student','active',false);
select pg_temp.create_case('google_mismatch','institutional','student','active',false);
select pg_temp.create_case('unconfirmed','institutional','student','active',false);

insert into public.role_assignments (
  user_id, role_code, scope_type, service_area, division_id, program_id,
  starts_at, ends_at, is_active, assigned_by
)
values
  (pg_temp.case_id('admin_exact'),'technical_admin','system','technical',null,null,(select institutional_today from sitaa_0007_context),null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('ordinary_student'),'student','own','both',null,null,(select institutional_today from sitaa_0007_context),null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('ordinary_professor'),'professor','program','both',null,(select program_id from sitaa_0007_context),(select institutional_today from sitaa_0007_context),null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_bad_scope'),'technical_admin','own','technical',null,null,(select institutional_today from sitaa_0007_context),null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_bad_service'),'technical_admin','system','both',null,null,(select institutional_today from sitaa_0007_context),null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_bad_program'),'technical_admin','program','technical',null,(select program_id from sitaa_0007_context),(select institutional_today from sitaa_0007_context),null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_bad_division'),'technical_admin','division','technical',(select division_id from sitaa_0007_context),null,(select institutional_today from sitaa_0007_context),null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_future'),'technical_admin','system','technical',null,null,(select institutional_today + 1 from sitaa_0007_context),null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_expired'),'technical_admin','system','technical',null,null,(select institutional_today - 2 from sitaa_0007_context),(select institutional_today - 1 from sitaa_0007_context),true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_inactive_assignment'),'technical_admin','system','technical',null,null,(select institutional_today from sitaa_0007_context),null,false,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_start_today'),'technical_admin','system','technical',null,null,(select institutional_today from sitaa_0007_context),null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_end_today'),'technical_admin','system','technical',null,null,(select institutional_today - 1 from sitaa_0007_context),(select institutional_today from sitaa_0007_context),true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('admin_inactive'),'technical_admin','system','technical',null,null,(select institutional_today from sitaa_0007_context),null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('target_account'),'student','own','both',null,null,(select institutional_today from sitaa_0007_context),null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('same_row_target'),'professor','program','advising',null,(select program_id from sitaa_0007_context),(select institutional_today from sitaa_0007_context),null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('same_row_target'),'peer_tutor','own','tutoring',null,null,(select institutional_today from sitaa_0007_context),null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('target_account'),'peer_tutor','own','tutoring',null,null,(select institutional_today + 1 from sitaa_0007_context),null,true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('target_account'),'professor','program','advising',null,(select program_id from sitaa_0007_context),(select institutional_today - 3 from sitaa_0007_context),(select institutional_today - 1 from sitaa_0007_context),true,pg_temp.case_id('admin_exact')),
  (pg_temp.case_id('target_account'),'student','own','both',null,null,(select institutional_today from sitaa_0007_context),null,false,pg_temp.case_id('admin_exact'));

create function pg_temp.insert_google_identity(target_label text, identity_email text)
returns void language plpgsql set search_path = auth, pg_temp, pg_catalog, information_schema as $$
declare
  target_id uuid := pg_temp.case_id(target_label);
  provider_key text := 'google-' || target_label || '-' || pg_temp.run_marker();
  payload jsonb := jsonb_build_object('sub',provider_key,'email',identity_email,'email_verified',true);
begin
  if exists (select 1 from information_schema.columns
    where table_schema='auth' and table_name='identities' and column_name='provider_id') then
    execute 'insert into auth.identities (provider_id,user_id,identity_data,provider,last_sign_in_at,created_at,updated_at) values ($1,$2,$3,''google'',now(),now(),now())'
      using provider_key,target_id,payload;
  else
    execute 'insert into auth.identities (id,user_id,identity_data,provider,last_sign_in_at,created_at,updated_at) values ($1,$2,$3,''google'',now(),now(),now())'
      using provider_key,target_id,payload;
  end if;
end;
$$;
select pg_temp.insert_google_identity('google_confirmed',pg_temp.case_email('google_confirmed'));
select pg_temp.insert_google_identity(
  'google_mismatch',
  'different-' || pg_temp.run_marker() || '@example.invalid'
);

insert into public.admin_audit_events (
  actor_profile_id, target_profile_id, action_code, outcome, reason, metadata
) values (
  pg_temp.case_id('admin_exact'), pg_temp.case_id('target_account'),
  'synthetic_verification', 'success', 'Evento sintético transaccional',
  jsonb_build_object('context','0007 verifier')
);

-- Contrato funcional de service_role: sólo inserta/consulta y alcanza el CHECK seguro.
grant select on table pg_temp.sitaa_0007_cases to service_role;
grant execute on function pg_temp.case_id(text) to service_role;
set local role service_role;
do $service_role_contract$
declare rejected boolean;
begin
  insert into public.admin_audit_events(
    actor_profile_id,target_profile_id,action_code,outcome,metadata
  ) values (
    pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),
    'service_role_safe_insert','success',jsonb_build_object('source','service_role_verifier')
  );
  if not exists (
    select 1 from public.admin_audit_events
    where action_code='service_role_safe_insert'
      and actor_profile_id=pg_temp.case_id('admin_exact')
      and target_profile_id=pg_temp.case_id('target_account')
  ) then
    raise exception '0007: service_role no pudo consultar su inserción válida.';
  end if;

  rejected := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'service_unsafe_key','failure',jsonb_build_object('accessToken','x'));
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: service_role aceptó metadata sensible.'; end if;

  rejected := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'service_non_object','failure','[]'::jsonb);
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: service_role aceptó metadata no objeto.'; end if;

  rejected := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'service_oversized','failure',jsonb_build_object('context',repeat('x',17000)));
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: service_role aceptó metadata sobredimensionada.'; end if;

  rejected := false;
  begin update public.admin_audit_events set reason='Prohibido';
  exception when insufficient_privilege then rejected := true; end;
  if not rejected then raise exception '0007: service_role obtuvo UPDATE.'; end if;
  rejected := false;
  begin delete from public.admin_audit_events;
  exception when insufficient_privilege then rejected := true; end;
  if not rejected then raise exception '0007: service_role obtuvo DELETE.'; end if;
  rejected := false;
  begin truncate public.admin_audit_events;
  exception when insufficient_privilege then rejected := true; end;
  if not rejected then raise exception '0007: service_role obtuvo TRUNCATE.'; end if;
end;
$service_role_contract$;
reset role;

-- Casos 2 a 5: toda identidad sin el contrato exacto recibe el mismo 42501.
create function pg_temp.expect_denied(target_label text)
returns void language plpgsql set search_path = public, pg_temp, pg_catalog as $$
declare
  denied boolean;
  requested_id uuid;
begin
  perform pg_temp.set_request_user(target_label);
  denied := false;
  begin
    perform * from public.search_admin_accounts_b1(
      pg_temp.run_marker(),null,null,null,null,null,null,null,1,20
    );
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then
    raise exception '0007: % obtuvo acceso a search_admin_accounts_b1.',target_label;
  end if;

  foreach requested_id in array array[pg_temp.case_id('target_account'),gen_random_uuid()] loop
    denied := false;
    begin perform * from public.get_admin_account_detail_b1(requested_id);
    exception when insufficient_privilege then denied := true; end;
    if not denied then
      raise exception '0007: % distinguió existencia mediante detalle.',target_label;
    end if;

    denied := false;
    begin perform * from public.get_admin_account_assignments_b1(requested_id);
    exception when insufficient_privilege then denied := true; end;
    if not denied then
      raise exception '0007: % distinguió existencia mediante asignaciones.',target_label;
    end if;

    denied := false;
    begin perform * from public.get_admin_account_audit_history_b1(
      requested_profile_id=>requested_id,result_limit=>50,result_offset=>0
    );
    exception when insufficient_privilege then denied := true; end;
    if not denied then
      raise exception '0007: % distinguió existencia mediante auditoría.',target_label;
    end if;
  end loop;
end;
$$;
select pg_temp.expect_denied('ordinary_student');
select pg_temp.expect_denied('ordinary_professor');
select pg_temp.expect_denied('admin_bad_scope');
select pg_temp.expect_denied('admin_bad_service');
select pg_temp.expect_denied('admin_bad_program');
select pg_temp.expect_denied('admin_bad_division');
select pg_temp.expect_denied('admin_future');
select pg_temp.expect_denied('admin_expired');
select pg_temp.expect_denied('admin_inactive_assignment');
select pg_temp.expect_denied('admin_inactive');

-- Los límites de fecha de la asignación son inclusivos.
select pg_temp.set_request_user('admin_start_today');
set local role authenticated;
do $$ begin
  if not exists(select 1 from public.search_admin_accounts_b1(
    pg_temp.run_marker() || '%',null,null,null,null,null,null,null,1,1
  )) then
    raise exception '0007: starts_at del día actual no fue inclusivo.';
  end if;
end $$;
reset role;
select pg_temp.set_request_user('admin_end_today');
set local role authenticated;
do $$ begin
  if not exists(select 1 from public.search_admin_accounts_b1(
    pg_temp.run_marker() || '%',null,null,null,null,null,null,null,1,1
  )) then
    raise exception '0007: ends_at del día actual no fue inclusivo.';
  end if;
end $$;
reset role;

-- Casos autorizados 1 y 6 a 15.
select pg_temp.set_request_user('admin_exact');
set local role authenticated;

do $authorized_cases$
declare
  target_id uuid := pg_temp.case_id('target_account');
  program_value uuid := (select program_id from pg_temp.sitaa_0007_context limit 1);
  today_value date := (select institutional_today from pg_temp.sitaa_0007_context limit 1);
  result_count bigint;
  masked_value text;
  expected_identifier text := pg_temp.case_identifier('target_account');
  rejected boolean;
begin
  select count(*) into result_count from public.search_admin_accounts_b1(
    pg_temp.run_marker() || '%',null,null,null,null,null,null,null,1,20
  );
  if result_count <> 1 then raise exception '0007: el porcentaje no fue tratado literalmente.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(
    pg_temp.run_marker() || '%_',null,null,null,null,null,null,null,1,20
  );
  if result_count <> 1 then raise exception '0007: porcentaje y guion bajo no fueron literales.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(
    pg_temp.wildcard_marker(),null,null,null,null,null,null,null,1,20
  );
  if result_count <> 1 then raise exception '0007: la barra inversa no fue tratada de forma segura.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(
    pg_temp.run_marker() || '%%',null,null,null,null,null,null,null,1,20
  );
  if result_count <> 0 then raise exception '0007: un patrón de comodines amplió el directorio.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(
    pg_temp.case_email('target_account'),null,null,null,null,null,null,null,1,20
  );
  if result_count <> 1 then raise exception '0007: la búsqueda por correo falló.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(
    expected_identifier,null,null,null,null,null,null,null,1,20
  );
  if result_count <> 1 then raise exception '0007: la búsqueda por identificador falló.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(null,null,null,null,null,null,null,null,1,20);
  if result_count <> 0 then raise exception '0007: el estado sin criterios expuso el directorio.'; end if;

  select count(*) into result_count from public.search_admin_accounts_b1(null,program_value,null,null,null,null,null,null,1,20);
  if result_count < 1 then raise exception '0007: filtro de programa falló.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(null,null,'technical',null,null,null,null,null,1,20);
  if result_count < 1 then raise exception '0007: filtro de tipo de cuenta falló.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(null,null,null,'inactive',null,null,null,null,1,20);
  if result_count < 1 then raise exception '0007: filtro de estado falló.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(null,null,null,null,'student',null,null,null,1,20);
  if result_count < 1 then raise exception '0007: filtro de persona falló.'; end if;
  select count(*) into result_count from public.search_admin_accounts_b1(null,null,null,null,null,'student','both','own',1,20);
  if result_count < 1 then raise exception '0007: filtros de asignación actual fallaron.'; end if;

  select count(*) into result_count from public.search_admin_accounts_b1(null,null,null,null,null,'professor','tutoring',null,1,20)
  where profile_id = pg_temp.case_id('same_row_target');
  if result_count <> 0 then raise exception '0007: rol y servicio combinaron filas distintas.'; end if;

  rejected := false;
  begin perform * from public.search_admin_accounts_b1(pg_temp.run_marker(),null,null,null,null,null,null,null,0,20);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: page_number inválido fue aceptado.'; end if;
  rejected := false;
  begin perform * from public.search_admin_accounts_b1(pg_temp.run_marker(),null,null,null,null,null,null,null,1,51);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: page_size mayor a 50 fue aceptado.'; end if;
  rejected := false;
  begin perform * from public.search_admin_accounts_b1(pg_temp.run_marker(),null,null,null,null,null,null,null,1,0);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: page_size cero fue aceptado.'; end if;
  rejected := false;
  begin perform * from public.search_admin_accounts_b1(pg_temp.run_marker(),null,null,null,null,null,null,null,1,-1);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: page_size negativo fue aceptado.'; end if;

  rejected := false;
  begin perform * from public.search_admin_accounts_b1(pg_temp.run_marker(),null,null,null,null,null,null,null,null,20);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: page_number NULL fue aceptado.'; end if;
  rejected := false;
  begin perform * from public.search_admin_accounts_b1(pg_temp.run_marker(),null,null,null,null,null,null,null,1,null);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: page_size NULL fue aceptado.'; end if;
  rejected := false;
  begin perform * from public.search_admin_accounts_b1(pg_temp.run_marker(),null,null,null,null,null,null,null,-1,20);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: page_number negativo fue aceptado.'; end if;
  rejected := false;
  begin perform * from public.search_admin_accounts_b1(pg_temp.run_marker(),null,null,null,null,null,null,null,1000001,20);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: page_number superior al máximo fue aceptado.'; end if;
  perform * from public.search_admin_accounts_b1(pg_temp.run_marker(),null,null,null,null,null,null,null,1000000,50);

  select masked_institutional_id into masked_value
  from public.search_admin_accounts_b1(expected_identifier,null,null,null,null,null,null,null,1,20)
  where profile_id = target_id;
  if masked_value = expected_identifier
     or right(masked_value,4) <> right(expected_identifier,4) then
    raise exception '0007: el identificador de lista no está enmascarado.';
  end if;

  if not exists (
    select 1 from public.get_admin_account_detail_b1(target_id)
    where institutional_id_value = expected_identifier
      and auth_email_confirmed is true
  ) then raise exception '0007: detalle completo o resumen Auth mínimo incorrecto.'; end if;

  if not exists(select 1 from public.get_admin_account_detail_b1(pg_temp.case_id('google_confirmed')) where auth_email_confirmed)
     or exists(select 1 from public.get_admin_account_detail_b1(pg_temp.case_id('google_mismatch')) where auth_email_confirmed)
     or exists(select 1 from public.get_admin_account_detail_b1(pg_temp.case_id('unconfirmed')) where auth_email_confirmed) then
    raise exception '0007: el resumen booleano de confirmación Google no coincide con el contrato vivo.';
  end if;

  if not exists (
    select 1 from public.get_admin_account_assignments_b1(target_id)
    where presentation_status = 'current'
  ) then raise exception '0007: clasificación V1 de asignación incorrecta.'; end if;
  if (select count(distinct presentation_status) from public.get_admin_account_assignments_b1(target_id)
      where presentation_status in ('current','future','expired','inactive')) <> 4
     or not exists (
       select 1 from public.get_admin_account_assignments_b1(target_id)
       where presentation_status = 'future' and starts_at = today_value + 1
     )
     or not exists (
       select 1 from public.get_admin_account_assignments_b1(target_id)
       where presentation_status = 'expired' and ends_at = today_value - 1
     )
     or not exists(select 1 from public.get_admin_account_assignments_b1(pg_temp.case_id('admin_inactive'))
       where presentation_status='suspended_by_account_status') then
    raise exception '0007: faltan estados de presentación V1.';
  end if;

  if not exists (
    select 1 from public.get_admin_account_audit_history_b1(requested_profile_id => target_id,result_limit => 50,result_offset => 0)
    where action_code = 'synthetic_verification' and reason = 'Evento sintético transaccional'
  ) then raise exception '0007: historial sanitizado no devolvió el evento sintético.'; end if;

  foreach result_count in array array[0,-1,51,1000001] loop
    rejected := false;
    begin perform * from public.get_admin_account_audit_history_b1(target_id,result_count::integer,0);
    exception when invalid_parameter_value then rejected := true; end;
    if not rejected then raise exception '0007: result_limit inválido fue aceptado: %.',result_count; end if;
  end loop;
  rejected := false;
  begin perform * from public.get_admin_account_audit_history_b1(target_id,null,0);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: result_limit NULL fue aceptado.'; end if;
  foreach result_count in array array[-1,1000001] loop
    rejected := false;
    begin perform * from public.get_admin_account_audit_history_b1(target_id,50,result_count::integer);
    exception when invalid_parameter_value then rejected := true; end;
    if not rejected then raise exception '0007: result_offset inválido fue aceptado: %.',result_count; end if;
  end loop;
  rejected := false;
  begin perform * from public.get_admin_account_audit_history_b1(target_id,50,null);
  exception when invalid_parameter_value then rejected := true; end;
  if not rejected then raise exception '0007: result_offset NULL fue aceptado.'; end if;
  perform * from public.get_admin_account_audit_history_b1(target_id,50,1000000);
end;
$authorized_cases$;

-- Casos 16: sin acceso directo a la bitácora.
do $direct_table_denial$
declare denied boolean;
begin
  denied := false;
  begin perform count(*) from public.admin_audit_events;
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception '0007: authenticated leyó directamente la bitácora.'; end if;
  denied := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'forbidden_insert','failure');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception '0007: authenticated insertó directamente en la bitácora.'; end if;
  denied := false;
  begin update public.admin_audit_events set reason='Prohibido';
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception '0007: authenticated actualizó directamente la bitácora.'; end if;
  denied := false;
  begin delete from public.admin_audit_events;
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception '0007: authenticated eliminó directamente de la bitácora.'; end if;
  denied := false;
  begin truncate public.admin_audit_events;
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception '0007: authenticated truncó directamente la bitácora.'; end if;
end;
$direct_table_denial$;

reset role;

-- Casos 17 y 18: append-only y metadata segura, aun para ejecución privilegiada.
do $audit_integrity$
declare rejected boolean;
begin
  rejected := false;
  begin update public.admin_audit_events set reason = 'Cambio prohibido';
  exception when object_not_in_prerequisite_state then rejected := true; end;
  if not rejected then raise exception '0007: UPDATE de bitácora fue aceptado.'; end if;

  rejected := false;
  begin delete from public.admin_audit_events;
  exception when object_not_in_prerequisite_state then rejected := true; end;
  if not rejected then raise exception '0007: DELETE de bitácora fue aceptado.'; end if;

  rejected := false;
  begin truncate public.admin_audit_events;
  exception when object_not_in_prerequisite_state then rejected := true; end;
  if not rejected then raise exception '0007: TRUNCATE de bitácora fue aceptado.'; end if;

  rejected := false;
  begin
    insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values (pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'unsafe_metadata','failure','{"access_token":"prohibido"}'::jsonb);
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: metadata sensible fue aceptada.'; end if;

  rejected := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'unsafe_camel','failure',jsonb_build_object('accessToken','x'));
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: accessToken fue aceptado.'; end if;
  rejected := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'unsafe_dash','failure',jsonb_build_object('refresh-token','x'));
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: refresh-token fue aceptado.'; end if;
  rejected := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'unsafe_auth','failure',jsonb_build_object('authorizationHeader','x'));
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: authorizationHeader fue aceptado.'; end if;
  rejected := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'unsafe_recovery','failure',jsonb_build_object('recoveryLink','x'));
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: recoveryLink fue aceptado.'; end if;
  rejected := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'unsafe_secret','failure',jsonb_build_object('clientSecretValue','x'));
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: clientSecretValue fue aceptado.'; end if;

  insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
  values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'safe_metadata','success',jsonb_build_object('source','verifier'));

  rejected := false;
  begin insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values(pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'non_object','failure','[]'::jsonb);
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: metadata no objeto fue aceptada.'; end if;

  rejected := false;
  begin
    insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,metadata)
    values (pg_temp.case_id('admin_exact'),pg_temp.case_id('target_account'),'oversized_metadata','failure',jsonb_build_object('context',repeat('x',17000)));
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception '0007: metadata sobredimensionada fue aceptada.'; end if;
end;
$audit_integrity$;

-- Caso 19: RLS propio permanece sin ampliación transversal.
select pg_temp.set_request_user('ordinary_student');
set local role authenticated;
do $own_rls$
begin
  if (select count(*) from public.profiles) <> 1
     or not exists (select 1 from public.profiles where id = pg_temp.case_id('ordinary_student'))
     or exists (select 1 from public.profiles where id = pg_temp.case_id('target_account'))
     or exists (select 1 from public.role_assignments where user_id <> pg_temp.case_id('ordinary_student')) then
    raise exception '0007: las políticas propias de perfiles o asignaciones cambiaron.';
  end if;
end;
$own_rls$;
reset role;

-- Caso 20: regresiones estáticas esenciales 0002–0006.
do $regressions$
declare draft_definition text := lower(pg_get_functiondef('public.get_visible_activity_cards()'::regprocedure));
begin
  if to_regprocedure('public.publish_activity(uuid)') is null
     or to_regprocedure('public.add_activity_participant(uuid,uuid,text)') is null
     or to_regprocedure('public.update_activity_participant_attendance(uuid,text,text)') is null
     or to_regprocedure('public.open_activity_attendance_checkin(uuid)') is null
     or to_regprocedure('public.check_in_activity(text)') is null
     or to_regprocedure('public.complete_own_google_registration(text,text,text,text,text,uuid)') is null
     or to_regprocedure('public.normalize_sitaa_profile_names()') is null
     or not has_column_privilege('authenticated','public.profiles','first_names','UPDATE')
     or not has_column_privilege('authenticated','public.profiles','paternal_surname','UPDATE')
     or not has_column_privilege('authenticated','public.profiles','maternal_surname','UPDATE')
     or has_column_privilege('authenticated','public.profiles','full_name','UPDATE')
     or not has_table_privilege('authenticated','public.role_assignments','SELECT')
     or has_table_privilege('authenticated','public.role_assignments','UPDATE')
     or not has_function_privilege('authenticated','public.complete_own_google_registration(text,text,text,text,text,uuid)','EXECUTE')
     or has_function_privilege('anon','public.complete_own_google_registration(text,text,text,text,text,uuid)','EXECUTE')
     or has_function_privilege('authenticated','public.complete_own_google_registration(text,text,text,uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.add_activity_participant(uuid,uuid,text)','EXECUTE')
     or has_function_privilege('anon','public.add_activity_participant(uuid,uuid,text)','EXECUTE')
     or not has_function_privilege('authenticated','public.update_activity_participant_attendance(uuid,text,text)','EXECUTE')
     or not has_function_privilege('authenticated','public.open_activity_attendance_checkin(uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.check_in_activity(text)','EXECUTE')
     or draft_definition not like '%status_code = ''draft''%'
     or draft_definition not like '%created_by = auth.uid()%'
     or not exists (
       select 1 from pg_trigger t where t.tgrelid = 'public.profiles'::regclass
         and t.tgname in ('enforce_sitaa_profile_identity','normalize_sitaa_profile_names')
       group by t.tgrelid having count(*) = 2
     ) then
    raise exception '0007: regresión detectada en contratos 0002–0006.';
  end if;
end;
$regressions$;

rollback;
