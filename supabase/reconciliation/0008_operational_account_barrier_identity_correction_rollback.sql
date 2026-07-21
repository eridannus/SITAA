-- Rollback de 0008: retira B.2a y restaura exactamente el código post-0007.
-- No revierte correcciones de identidad ya confirmadas ni elimina su auditoría.
begin;

do $guard$
declare
  guarded_count integer;
  mismatch_count integer;
  helper_oid oid:=to_regprocedure('public.is_sitaa_operational_account_active()');
  context_oid oid:=to_regprocedure('public.get_admin_identity_correction_context_b2a(uuid)');
  correction_oid oid:=to_regprocedure('public.correct_admin_account_identity_b2a(uuid,text,text,text,text,text,uuid,text)');
  writer_trigger_oid oid:=to_regprocedure('public.enforce_activity_writer_integrity_b2a()');
begin
  if (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relkind='r')<>18
     or (select count(*) from information_schema.columns where table_schema='public')<>165
     or (select count(*) from pg_constraint c join pg_namespace n on n.oid=c.connamespace
         where n.nspname='public' and c.contype in ('p','f','u','c'))<>80
     or (select count(*) from pg_indexes where schemaname='public')<>43
     or (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid
         join pg_namespace n on n.oid=c.relnamespace
         where n.nspname='public' and not t.tgisinternal)<>11
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>51
     or (select count(*) from pg_policies where schemaname='public')<>25
     or helper_oid is null or context_oid is null or correction_oid is null
     or writer_trigger_oid is null
     or not exists (
       select 1 from pg_policies
       where schemaname='public' and tablename='activities'
         and policyname='Active accounts may operate activities'
         and permissive='RESTRICTIVE' and roles='{authenticated}' and cmd='ALL'
         and qual='is_sitaa_operational_account_active()'
         and with_check='is_sitaa_operational_account_active()'
     )
     or not exists (
       select 1 from pg_policies
       where schemaname='public' and tablename='activity_participants'
         and policyname='Active accounts may operate activity participants'
         and permissive='RESTRICTIVE' and roles='{authenticated}' and cmd='ALL'
         and qual='is_sitaa_operational_account_active()'
         and with_check='is_sitaa_operational_account_active()'
     ) then
    raise exception '0008_rollback_contract_incomplete';
  end if;

  if not exists (
       select 1 from pg_proc p
       where p.oid=helper_oid and p.prorettype='boolean'::regtype
         and p.prolang=(select oid from pg_language where lanname='sql')
         and p.provolatile='s' and p.prosecdef
         and p.proconfig=array['search_path=pg_catalog, public']::text[]
         and p.pronargs=0 and coalesce(cardinality(p.proargnames),0)=0
         and p.proallargtypes is null
         and pg_get_function_identity_arguments(p.oid)=''
     )
     or not exists (
       select 1 from pg_proc p
       where p.oid=context_oid
         and p.prolang=(select oid from pg_language where lanname='plpgsql')
         and p.provolatile='s' and p.prosecdef
         and p.proconfig=array['search_path=pg_catalog, public']::text[]
         and p.pronargs=1 and p.prorettype='record'::regtype
         and p.proargnames=array[
           'requested_profile_id','target_profile_id','can_correct','denial_code',
           'account_kind','account_status','is_self',
           'current_or_future_assignment_count','open_responsibility_count',
           'open_participation_count'
         ]::text[]
         and p.proargmodes=array['i','t','t','t','t','t','t','t','t','t']::"char"[]
         and p.proallargtypes=array[
           'uuid'::regtype::oid,'uuid'::regtype::oid,'boolean'::regtype::oid,
           'text'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,
           'boolean'::regtype::oid,'bigint'::regtype::oid,'bigint'::regtype::oid,
           'bigint'::regtype::oid
         ]::oid[]
         and regexp_replace(lower(pg_get_function_identity_arguments(p.oid)),'\s+','','g')
           ='requested_profile_iduuid'
     )
     or not exists (
       select 1 from pg_proc p
       where p.oid=correction_oid
         and p.prolang=(select oid from pg_language where lanname='plpgsql')
         and p.provolatile='v' and p.prosecdef
         and p.proconfig=array['search_path=pg_catalog, public']::text[]
         and p.pronargs=8 and p.prorettype='record'::regtype
         and p.proargnames=array[
           'requested_profile_id','requested_first_names','requested_paternal_surname',
           'requested_maternal_surname','requested_person_type',
           'requested_institutional_id_value','requested_primary_program_id',
           'correction_reason','target_profile_id','audit_event_id',
           'changed_fields','updated_at'
         ]::text[]
         and p.proargmodes=array[
           'i','i','i','i','i','i','i','i','t','t','t','t'
         ]::"char"[]
         and p.proallargtypes=array[
           'uuid'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,
           'text'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,
           'uuid'::regtype::oid,'text'::regtype::oid,'uuid'::regtype::oid,
           'uuid'::regtype::oid,'text[]'::regtype::oid,'timestamptz'::regtype::oid
         ]::oid[]
         and regexp_replace(lower(pg_get_function_identity_arguments(p.oid)),'\s+','','g')
           ='requested_profile_iduuid,requested_first_namestext,requested_paternal_surnametext,requested_maternal_surnametext,requested_person_typetext,requested_institutional_id_valuetext,requested_primary_program_iduuid,correction_reasontext'
     ) then
    raise exception '0008_rollback_new_function_definition_drift';
  end if;

  select count(*) into mismatch_count
  from (values (helper_oid),(context_oid),(correction_oid)) expected(function_oid)
  join pg_proc p on p.oid=expected.function_oid
  where (
    select count(*)
    from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
    left join pg_roles grantee on grantee.oid=acl.grantee
    where acl.privilege_type='EXECUTE'
      and (acl.grantee=p.proowner or grantee.rolname='authenticated')
      and not acl.is_grantable
  )<>2
  or not has_function_privilege('authenticated',p.oid,'EXECUTE')
  or has_function_privilege('anon',p.oid,'EXECUTE')
  or has_function_privilege('service_role',p.oid,'EXECUTE')
  or exists (
    select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
    left join pg_roles grantee on grantee.oid=acl.grantee
    where acl.privilege_type<>'EXECUTE'
       or (acl.grantee<>p.proowner and coalesce(grantee.rolname,'PUBLIC')<>'authenticated')
       or acl.is_grantable
  );
  if mismatch_count<>0 then
    raise exception '0008_rollback_new_function_acl_drift';
  end if;

  select count(*) into guarded_count
  from (values
    ('activity_attendance_deadline(uuid)'),
    ('activity_attendance_open_at(uuid)'),
    ('activity_has_ended(uuid)'),
    ('add_activity_participant(uuid,uuid,text)'),
    ('can_create_activity(text,uuid,uuid,text)'),
    ('can_create_activity(uuid,text)'),
    ('can_delete_activity(uuid)'),
    ('can_edit_activity(uuid)'),
    ('can_manage_activity(text,uuid,uuid,text)'),
    ('can_manage_activity(uuid,text)'),
    ('can_read_activity(uuid)'),
    ('can_update_activity_base(uuid)'),
    ('check_in_activity(text)'),
    ('close_activity_attendance_checkin(uuid)'),
    ('finalize_expired_attendance()'),
    ('generate_three_word_code()'),
    ('get_active_activity_attendance_checkin(uuid)'),
    ('get_activity_attendance_checkin_state(uuid)'),
    ('get_activity_participants(uuid)'),
    ('get_visible_activity_cards()'),
    ('has_active_role(text)'),
    ('has_any_active_role(text[])'),
    ('is_activity_participant(uuid)'),
    ('open_activity_attendance_checkin(uuid)'),
    ('publish_activity(uuid)'),
    ('remove_activity_participant(uuid)'),
    ('search_profiles_for_participation(uuid,text)'),
    ('update_activity_participant_attendance(uuid,text,text)'),
    ('update_activity_participants_attendance_bulk(uuid,uuid[],text,text)')
  ) expected(signature)
  join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
  where lower(p.prosrc) like '%is_sitaa_operational_account_active%';

  if guarded_count<>29 then
    raise exception '0008_rollback_operational_guard_incomplete';
  end if;

  select count(*) into mismatch_count
  from (values
    ('activity_attendance_deadline(uuid)','fa3b7c8ef43aab1a8ede008671b5dc08'),
    ('activity_attendance_open_at(uuid)','ae06ee4eb6cb93d433aed430b6b07e8c'),
    ('activity_has_ended(uuid)','c318afdb983e1a21461fe071b7a4fa95'),
    ('add_activity_participant(uuid,uuid,text)','49ace655e29301b5a2d34438d3689296'),
    ('can_create_activity(text,uuid,uuid,text)','a681afcc9eb243295418bcb048658c3f'),
    ('can_create_activity(uuid,text)','d2b5f611bc457b0533a270302deb0362'),
    ('can_delete_activity(uuid)','0ac0d3ee8eb298048e4e13bff43fd2ef'),
    ('can_edit_activity(uuid)','f6bc990fb143529e32f0164250f28506'),
    ('can_manage_activity(text,uuid,uuid,text)','f1e367150d36b899050e4fec6f1513cc'),
    ('can_manage_activity(uuid,text)','e6f946ff2f3a50bd4ff9dda071488a8a'),
    ('can_read_activity(uuid)','f6bc990fb143529e32f0164250f28506'),
    ('can_update_activity_base(uuid)','0ac0d3ee8eb298048e4e13bff43fd2ef'),
    ('check_in_activity(text)','a52e462d8ff4695a2cff9a6d19bf723f'),
    ('close_activity_attendance_checkin(uuid)','8bb200584cd15cb9cdc4d4d5493d49b2'),
    ('finalize_expired_attendance()','97d5f2afd2600a22567469d5d67e56fb'),
    ('generate_three_word_code()','f206add4d10a0dd7a67536f9bfdfd75f'),
    ('get_active_activity_attendance_checkin(uuid)','da892a66aebc576b635057b6dd8dba3b'),
    ('get_activity_attendance_checkin_state(uuid)','18066a5aaa19da83b02d76e1ec2d632b'),
    ('get_activity_participants(uuid)','eb43eed1cf5e7f78d1e87301dd57a36a'),
    ('get_visible_activity_cards()','38b6f8d1ad3575174f06d43bbe3fecf0'),
    ('has_active_role(text)','0c2fab12561c4b1e0a6580265c96fe2b'),
    ('has_any_active_role(text[])','815a4fb483719737cc99ea62208c4bc5'),
    ('is_activity_participant(uuid)','6c0655c94e0f81bfd70059ece59c4c73'),
    ('open_activity_attendance_checkin(uuid)','dbe86813387d937a5b710aa88b3c5911'),
    ('publish_activity(uuid)','f0fbfce1b8185ee1be65c67443f4f607'),
    ('remove_activity_participant(uuid)','56e63d2e7b4f7f3fa5fee423c224ba13'),
    ('search_profiles_for_participation(uuid,text)','b3e83dab1d94287066970ac275586f36'),
    ('update_activity_participant_attendance(uuid,text,text)','12fda7553b4954f7878d23d7b238673a'),
    ('update_activity_participants_attendance_bulk(uuid,uuid[],text,text)','013f048011b9b617b6af995aeed2fee5')
  ) expected(signature,body_hash)
  left join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
  where p.oid is null
     or md5(regexp_replace(p.prosrc,'\s+','','g'))<>expected.body_hash
     or lower(p.prosrc) not like '%is_sitaa_operational_account_active%';
  if mismatch_count<>0 then
    raise exception '0008_rollback_operational_definition_drift';
  end if;

  select count(*) into mismatch_count
  from (values
    ('activity_attendance_deadline(uuid)'),('activity_attendance_open_at(uuid)'),
    ('activity_has_ended(uuid)'),('add_activity_participant(uuid,uuid,text)'),
    ('can_create_activity(text,uuid,uuid,text)'),('can_create_activity(uuid,text)'),
    ('can_delete_activity(uuid)'),('can_edit_activity(uuid)'),
    ('can_manage_activity(text,uuid,uuid,text)'),('can_manage_activity(uuid,text)'),
    ('can_read_activity(uuid)'),('can_update_activity_base(uuid)'),
    ('check_in_activity(text)'),('close_activity_attendance_checkin(uuid)'),
    ('finalize_expired_attendance()'),('generate_three_word_code()'),
    ('get_active_activity_attendance_checkin(uuid)'),
    ('get_activity_attendance_checkin_state(uuid)'),
    ('get_activity_participants(uuid)'),('get_visible_activity_cards()'),
    ('has_active_role(text)'),('has_any_active_role(text[])'),
    ('is_activity_participant(uuid)'),('open_activity_attendance_checkin(uuid)'),
    ('publish_activity(uuid)'),('remove_activity_participant(uuid)'),
    ('search_profiles_for_participation(uuid,text)'),
    ('update_activity_participant_attendance(uuid,text,text)'),
    ('update_activity_participants_attendance_bulk(uuid,uuid[],text,text)')
  ) expected(signature)
  join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
  where (
    select count(*)
    from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
    left join pg_roles grantee on grantee.oid=acl.grantee
    where acl.privilege_type='EXECUTE'
      and coalesce(grantee.rolname,'PUBLIC') in ('postgres','authenticated','service_role')
      and not acl.is_grantable
  )<>3
  or exists (
    select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
    left join pg_roles grantee on grantee.oid=acl.grantee
    where acl.privilege_type<>'EXECUTE'
       or coalesce(grantee.rolname,'PUBLIC') not in ('postgres','authenticated','service_role')
       or acl.is_grantable
  );
  if mismatch_count<>0 then
    raise exception '0008_rollback_operational_acl_drift';
  end if;

  if not exists (
       select 1 from pg_proc p
       where p.oid=writer_trigger_oid
         and p.prorettype='trigger'::regtype
         and p.prolang=(select oid from pg_language where lanname='plpgsql')
         and p.provolatile='v' and p.prosecdef
         and p.proconfig=array['search_path=pg_catalog, public']::text[]
         and p.pronargs=0 and coalesce(cardinality(p.proargnames),0)=0
         and p.proallargtypes is null
         and pg_get_function_identity_arguments(p.oid)=''
         and md5(regexp_replace(p.prosrc,'\s+','','g'))=
           'f3015ca3f14ada575b19a6d39d1622ea'
         and lower(p.prosrc) like '%sitaa_activity_writer_identity_mismatch%'
         and lower(p.prosrc) like '%sitaa_activity_participant_identity_incompatible%'
         and lower(p.prosrc) like '%for share of profile%'
     )
     or not exists (
       select 1 from pg_trigger trigger_definition
       where trigger_definition.tgrelid='public.activities'::regclass
         and trigger_definition.tgname='enforce_activity_writer_integrity_b2a'
         and not trigger_definition.tgisinternal
         and trigger_definition.tgenabled='O'
         and trigger_definition.tgfoid=writer_trigger_oid
         and trigger_definition.tgtype=23
     )
     or has_function_privilege('authenticated',writer_trigger_oid,'EXECUTE')
     or has_function_privilege('anon',writer_trigger_oid,'EXECUTE')
     or has_function_privilege('service_role',writer_trigger_oid,'EXECUTE')
     or (
       select count(*) from pg_proc p
       cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
       where p.oid=writer_trigger_oid and acl.grantee=p.proowner
         and acl.privilege_type='EXECUTE' and not acl.is_grantable
     )<>1
     or exists (
       select 1 from pg_proc p
       cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
       where p.oid=writer_trigger_oid
         and (acl.grantee<>p.proowner or acl.privilege_type<>'EXECUTE' or acl.is_grantable)
     )
     or not has_table_privilege('authenticated','public.activities','SELECT,INSERT,UPDATE,DELETE')
     or not has_table_privilege('authenticated','public.activity_participants','SELECT')
     or has_table_privilege('authenticated','public.activity_participants','INSERT')
     or has_table_privilege('authenticated','public.activity_participants','UPDATE')
     or has_table_privilege('authenticated','public.activity_participants','DELETE')
     or has_table_privilege('authenticated','public.role_assignments','INSERT')
     or has_table_privilege('authenticated','public.role_assignments','UPDATE')
     or has_table_privilege('authenticated','public.role_assignments','DELETE') then
    raise exception '0008_rollback_writer_integrity_contract_drift';
  end if;

  if (select count(*) from pg_attribute
      where attrelid='public.admin_audit_events'::regclass
        and attnum>0 and not attisdropped)<>9
     or exists (
       with expected(attnum,column_name,type_oid,not_null,default_kind) as (
         values
           (1::smallint,'id','uuid'::regtype::oid,true,'uuid'),
           (2::smallint,'actor_profile_id','uuid'::regtype::oid,true,null),
           (3::smallint,'target_profile_id','uuid'::regtype::oid,true,null),
           (4::smallint,'action_code','text'::regtype::oid,true,null),
           (5::smallint,'outcome','text'::regtype::oid,true,null),
           (6::smallint,'reason','text'::regtype::oid,false,null),
           (7::smallint,'role_assignment_id','uuid'::regtype::oid,false,null),
           (8::smallint,'metadata','jsonb'::regtype::oid,true,'empty_json'),
           (9::smallint,'occurred_at','timestamptz'::regtype::oid,true,'now')
       ), observed as (
         select a.attnum,a.attname,a.atttypid,a.attnotnull,d.oid default_oid,
           regexp_replace(lower(pg_get_expr(d.adbin,d.adrelid,true)),'\s+','','g') default_expression
         from pg_attribute a
         left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum
         where a.attrelid='public.admin_audit_events'::regclass
           and a.attnum>0 and not a.attisdropped
       )
       select 1 from expected e left join observed o on o.attnum=e.attnum
       where o.attnum is null or o.attname<>e.column_name
          or o.atttypid<>e.type_oid or o.attnotnull<>e.not_null
          or (e.default_kind is null and o.default_oid is not null)
          or (e.default_kind='uuid' and coalesce(o.default_expression,'')
            !~ '^(pg_catalog\.)?gen_random_uuid\(\)$')
          or (e.default_kind='empty_json' and coalesce(o.default_expression,'')<>'''{}''::jsonb')
          or (e.default_kind='now' and coalesce(o.default_expression,'')
            !~ '^(pg_catalog\.)?now\(\)$')
     )
     or (select count(*) from pg_constraint
         where conrelid='public.admin_audit_events'::regclass)<>8
     or exists (
       with expected(constraint_name,constraint_definition) as (
         values
           ('admin_audit_events_action_code_check',
             'CHECK (char_length(action_code) >= 1 AND char_length(action_code) <= 100 AND action_code ~ ''^[a-z][a-z0-9]*(_[a-z0-9]+)*$''::text)'),
           ('admin_audit_events_actor_profile_id_fkey',
             'FOREIGN KEY (actor_profile_id) REFERENCES profiles(id) ON DELETE RESTRICT'),
           ('admin_audit_events_metadata_check','CHECK (admin_audit_metadata_is_safe(metadata))'),
           ('admin_audit_events_outcome_check',
             'CHECK (outcome = ANY (ARRAY[''success''::text, ''failure''::text]))'),
           ('admin_audit_events_pkey','PRIMARY KEY (id)'),
           ('admin_audit_events_reason_check',
             'CHECK (reason IS NULL OR reason = btrim(reason) AND char_length(reason) >= 1 AND char_length(reason) <= 1000)'),
           ('admin_audit_events_role_assignment_id_fkey',
             'FOREIGN KEY (role_assignment_id) REFERENCES role_assignments(id) ON DELETE RESTRICT'),
           ('admin_audit_events_target_profile_id_fkey',
             'FOREIGN KEY (target_profile_id) REFERENCES profiles(id) ON DELETE RESTRICT')
       )
       select 1 from expected e
       left join pg_constraint c on c.conrelid='public.admin_audit_events'::regclass
         and c.conname=e.constraint_name
       where c.oid is null or pg_get_constraintdef(c.oid)<>e.constraint_definition
     )
     or not exists (
       select 1 from pg_indexes where schemaname='public'
         and tablename='admin_audit_events'
         and indexname='admin_audit_events_actor_occurred_idx'
         and indexdef='CREATE INDEX admin_audit_events_actor_occurred_idx ON public.admin_audit_events USING btree (actor_profile_id, occurred_at DESC, id DESC)'
     )
     or not exists (
       select 1 from pg_indexes where schemaname='public'
         and tablename='admin_audit_events'
         and indexname='admin_audit_events_target_occurred_idx'
         and indexdef='CREATE INDEX admin_audit_events_target_occurred_idx ON public.admin_audit_events USING btree (target_profile_id, occurred_at DESC, id DESC)'
     )
     or (select count(*) from pg_trigger
         where tgrelid='public.admin_audit_events'::regclass and not tgisinternal)<>2
     or not exists (
       select 1 from pg_trigger
       where tgrelid='public.admin_audit_events'::regclass and not tgisinternal
         and tgname='prevent_admin_audit_event_mutation'
         and tgfoid=to_regprocedure('public.prevent_admin_audit_event_mutation()')
         and tgtype=27 and tgenabled='O'
     )
     or not exists (
       select 1 from pg_trigger
       where tgrelid='public.admin_audit_events'::regclass and not tgisinternal
         and tgname='prevent_admin_audit_event_truncate'
         and tgfoid=to_regprocedure('public.prevent_admin_audit_event_mutation()')
         and tgtype=34 and tgenabled='O'
     )
     or not exists (
       select 1 from pg_class c
       where c.oid='public.admin_audit_events'::regclass and c.relrowsecurity
     )
     or exists (
       select 1 from pg_policies
       where schemaname='public' and tablename='admin_audit_events'
     )
     or has_table_privilege('authenticated','public.admin_audit_events','SELECT')
     or has_table_privilege('authenticated','public.admin_audit_events','INSERT')
     or not has_table_privilege('service_role','public.admin_audit_events','SELECT')
     or not has_table_privilege('service_role','public.admin_audit_events','INSERT')
     or has_table_privilege('service_role','public.admin_audit_events','UPDATE')
     or has_table_privilege('service_role','public.admin_audit_events','DELETE')
     or has_table_privilege('service_role','public.admin_audit_events','TRUNCATE')
     or has_table_privilege('service_role','public.admin_audit_events','REFERENCES')
     or has_table_privilege('service_role','public.admin_audit_events','TRIGGER')
     or has_table_privilege('anon','public.admin_audit_events','SELECT')
     or has_table_privilege('anon','public.admin_audit_events','INSERT')
     or not exists (
       select 1 from pg_class c
       where c.oid='public.admin_audit_events'::regclass
         and (
           select count(*) from aclexplode(c.relacl) acl
           where acl.grantee=c.relowner
             and upper(acl.privilege_type) in (
               'SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN'
             ) and not acl.is_grantable
         )=8
         and (
           select count(*) from aclexplode(c.relacl) acl
           where acl.grantee=(select oid from pg_roles where rolname='service_role')
             and upper(acl.privilege_type) in ('SELECT','INSERT')
             and not acl.is_grantable
         )=2
         and not exists (
           select 1 from aclexplode(c.relacl) acl
           where acl.grantee not in (
             c.relowner,(select oid from pg_roles where rolname='service_role')
           ) or acl.is_grantable
              or (acl.grantee=c.relowner and upper(acl.privilege_type) not in (
                'SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN'
              ))
              or (acl.grantee=(select oid from pg_roles where rolname='service_role')
                and upper(acl.privilege_type) not in ('SELECT','INSERT'))
         )
     )
     or exists (
       select 1 from pg_attribute a
       where a.attrelid='public.admin_audit_events'::regclass
         and a.attnum>0 and not a.attisdropped and a.attacl is not null
         and exists(select 1 from aclexplode(a.attacl))
     ) then
    raise exception '0008_rollback_audit_contract_drift';
  end if;
end;
$guard$;

drop trigger enforce_activity_writer_integrity_b2a on public.activities;
drop function public.enforce_activity_writer_integrity_b2a();
grant insert,update,delete on table public.activity_participants
  to authenticated;

revoke all on function public.correct_admin_account_identity_b2a(uuid,text,text,text,text,text,uuid,text)
  from public, anon, authenticated, service_role;
revoke all on function public.get_admin_identity_correction_context_b2a(uuid)
  from public, anon, authenticated, service_role;

drop function public.correct_admin_account_identity_b2a(uuid,text,text,text,text,text,uuid,text);
drop function public.get_admin_identity_correction_context_b2a(uuid);

drop policy "Active accounts may operate activities" on public.activities;
drop policy "Active accounts may operate activity participants" on public.activity_participants;

-- Restauración exacta post-0007: activity_attendance_deadline(uuid)
CREATE OR REPLACE FUNCTION public.activity_attendance_deadline(target_activity_id uuid)
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select

    (

      (

        coalesce(a.end_date, a.start_date)

        +

        coalesce(a.end_time, a.start_time, time '23:59:59')

      ) at time zone 'America/Mexico_City'

    ) + interval '15 minutes'

  from public.activities a

  where a.id = target_activity_id

    and a.start_date is not null;

$function$;

-- Restauración exacta post-0007: activity_attendance_open_at(uuid)
CREATE OR REPLACE FUNCTION public.activity_attendance_open_at(target_activity_id uuid)
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select

    (

      (

        a.start_date

        +

        coalesce(a.start_time, time '00:00:00')

      ) at time zone 'America/Mexico_City'

    ) - interval '15 minutes'

  from public.activities a

  where a.id = target_activity_id

    and a.start_date is not null

    and a.start_time is not null;

$function$;

-- Restauración exacta post-0007: activity_has_ended(uuid)
CREATE OR REPLACE FUNCTION public.activity_has_ended(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case
    when a.status_code = 'draft' then false
    else coalesce(
      (
        coalesce(a.end_date, a.start_date)::timestamp
        + coalesce(a.end_time, a.start_time, time '23:59:59')
      ) < (now() at time zone 'America/Mexico_City'),
      false
    )
  end
  from public.activities a
  where a.id = target_activity_id;
$function$;

-- Restauración exacta post-0007: add_activity_participant(uuid,uuid,text)
CREATE OR REPLACE FUNCTION public.add_activity_participant(target_activity_id uuid, target_profile_id uuid, target_participant_role_code text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  target_program_id uuid;
  participant_program_id uuid;
  participant_person_type text;
begin
  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para agregar participantes a esta actividad.' using errcode = '42501';
  end if;
  select a.program_id into target_program_id from public.activities a where a.id = target_activity_id;
  if target_program_id is null then
    raise exception 'La actividad no tiene programa académico asignado.' using errcode = 'P0001';
  end if;
  select p.primary_program_id, p.person_type into participant_program_id, participant_person_type
  from public.profiles p where p.id = target_profile_id and p.is_active = true;
  if participant_program_id is null then
    raise exception 'El perfil seleccionado no existe, no está activo o no tiene programa asignado.' using errcode = 'P0001';
  end if;
  if participant_program_id <> target_program_id then
    raise exception 'La persona seleccionada pertenece a otro programa académico.' using errcode = 'P0001';
  end if;
  if not exists (
    select 1 from public.participant_roles pr
    where pr.code = target_participant_role_code and pr.is_active = true
  ) then
    raise exception 'El rol de participante seleccionado no es válido.' using errcode = 'P0001';
  end if;
  if target_participant_role_code = 'responsible' and participant_person_type <> 'professor' then
    raise exception 'Sólo un profesor puede registrarse como responsable de la actividad.' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.activity_participants ap
    where ap.activity_id = target_activity_id and ap.profile_id = target_profile_id
  ) then
    raise exception 'Esta persona ya está registrada como participante en la actividad.' using errcode = '23505';
  end if;
  insert into public.activity_participants (
    activity_id, profile_id, participant_role_code, added_by
  ) values (
    target_activity_id, target_profile_id, target_participant_role_code, auth.uid()
  );
end;
$function$;

-- Restauración exacta post-0007: can_create_activity(text,uuid,uuid,text)
CREATE OR REPLACE FUNCTION public.can_create_activity(target_scope_type text, target_program_id uuid, target_division_id uuid, target_service_type_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select exists (

    select 1

    from public.profiles p

    where p.id = auth.uid()

      and p.is_active = true

      and (

        public.can_manage_activity(

          target_scope_type,

          target_program_id,

          target_division_id,

          target_service_type_code

        )



        or (

          target_scope_type = 'program'

          and target_program_id = p.primary_program_id

          and public.has_any_active_role(array['professor', 'peer_tutor'])

        )

      )

  );

$function$;

-- Restauración exacta post-0007: can_create_activity(uuid,text)
CREATE OR REPLACE FUNCTION public.can_create_activity(target_program_id uuid, target_service_type_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select

    public.has_any_active_role(array[

      'technical_admin',

      'division_tutoring_liaison',

      'division_head',

      'program_head',

      'program_tutoring_lead',

      'program_advising_lead',

      'professor',

      'peer_tutor'

    ])

    or public.can_manage_activity(target_program_id, target_service_type_code);

$function$;

-- Restauración exacta post-0007: can_delete_activity(uuid)
CREATE OR REPLACE FUNCTION public.can_delete_activity(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.activities a
    where a.id = target_activity_id
      and (
        (
          a.status_code = 'draft'
          and a.created_by = auth.uid()
        )
        or (
          a.status_code <> 'draft'
          and public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)
        )
      )
  );
$function$;

-- Restauración exacta post-0007: can_edit_activity(uuid)
CREATE OR REPLACE FUNCTION public.can_edit_activity(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select exists (

    select 1 from public.activities a

    where a.id = target_activity_id

      and (

        (a.status_code = 'draft' and a.created_by = auth.uid())

        or (

          a.status_code <> 'draft'

          and (

            a.created_by = auth.uid()

            or a.responsible_profile_id = auth.uid()

            or public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)

          )

        )

      )

  );

$function$;

-- Restauración exacta post-0007: can_manage_activity(text,uuid,uuid,text)
CREATE OR REPLACE FUNCTION public.can_manage_activity(target_scope_type text, target_program_id uuid, target_division_id uuid, target_service_type_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select exists (

    select 1

    from public.role_assignments ra

    where ra.user_id = auth.uid()

      and ra.is_active = true

      and ra.starts_at <= current_date

      and (ra.ends_at is null or ra.ends_at >= current_date)

      and (

        ra.role_code = 'technical_admin'



        or (

          ra.role_code in ('division_tutoring_liaison', 'division_head')

          and ra.scope_type = 'division'

          and ra.division_id = target_division_id

        )



        or (

          target_scope_type = 'program'

          and ra.role_code = 'program_head'

          and ra.program_id = target_program_id

        )



        or (

          target_scope_type = 'program'

          and ra.role_code = 'program_tutoring_lead'

          and ra.program_id = target_program_id

          and target_service_type_code = 'tutoring'

        )



        or (

          target_scope_type = 'program'

          and ra.role_code = 'program_advising_lead'

          and ra.program_id = target_program_id

          and target_service_type_code = 'advising'

        )

      )

  );

$function$;

-- Restauración exacta post-0007: can_manage_activity(uuid,text)
CREATE OR REPLACE FUNCTION public.can_manage_activity(target_program_id uuid, target_service_type_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select exists (

    select 1

    from public.role_assignments ra

    where ra.user_id = auth.uid()

      and ra.is_active = true

      and ra.starts_at <= current_date

      and (ra.ends_at is null or ra.ends_at >= current_date)

      and (

        ra.role_code = 'technical_admin'

        or ra.role_code = 'division_tutoring_liaison'

        or ra.role_code = 'division_head'

        or (

          ra.role_code = 'program_head'

          and ra.program_id = target_program_id

        )

        or (

          ra.role_code = 'program_tutoring_lead'

          and ra.program_id = target_program_id

          and target_service_type_code = 'tutoring'

        )

        or (

          ra.role_code = 'program_advising_lead'

          and ra.program_id = target_program_id

          and target_service_type_code = 'advising'

        )

      )

  );

$function$;

-- Restauración exacta post-0007: can_read_activity(uuid)
CREATE OR REPLACE FUNCTION public.can_read_activity(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select exists (

    select 1 from public.activities a

    where a.id = target_activity_id

      and (

        (a.status_code = 'draft' and a.created_by = auth.uid())

        or (

          a.status_code <> 'draft'

          and (

            a.created_by = auth.uid()

            or a.responsible_profile_id = auth.uid()

            or public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)

          )

        )

      )

  );

$function$;

-- Restauración exacta post-0007: can_update_activity_base(uuid)
CREATE OR REPLACE FUNCTION public.can_update_activity_base(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.activities a
    where a.id = target_activity_id
      and (
        (
          a.status_code = 'draft'
          and a.created_by = auth.uid()
        )
        or (
          a.status_code <> 'draft'
          and public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)
        )
      )


  );
$function$;

-- Restauración exacta post-0007: check_in_activity(text)
CREATE OR REPLACE FUNCTION public.check_in_activity(checkin_input text)
 RETURNS TABLE(activity_id uuid, activity_title text, attendance_status text, checked_in_at timestamp with time zone, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

declare

  normalized_input text;

  found_token public.activity_checkin_tokens%rowtype;

  participant_id uuid;

  source_value text;

  existing_status text;

  existing_source text;

begin

  perform public.finalize_expired_attendance();



  normalized_input := regexp_replace(

    extensions.unaccent(lower(trim(checkin_input))),

    '\s+',

    '-',

    'g'

  );



  select *

  into found_token

  from public.activity_checkin_tokens t

  where t.is_active = true

    and t.token_type = 'attendance'

    and (t.expires_at is null or t.expires_at > now())

    and (

      t.secret_token = trim(checkin_input)

      or t.code_words = normalized_input

    )

  order by t.opened_at desc

  limit 1;



  if found_token.id is null then

    raise exception 'El código de asistencia no existe o ya fue cerrado.'

      using errcode = 'P0001';

  end if;



  select ap.id, ap.attendance_status, ap.attendance_source

  into participant_id, existing_status, existing_source

  from public.activity_participants ap

  where ap.activity_id = found_token.activity_id

    and ap.profile_id = auth.uid();



  if participant_id is null then

    raise exception 'No estás registrado como participante en esta actividad.'

      using errcode = '42501';

  end if;



  if existing_status = 'attended' then

    return query

    select

      a.id,

      a.title,

      'attended'::text,

      ap.checked_in_at,

      'Tu asistencia ya estaba registrada.'::text

    from public.activities a

    join public.activity_participants ap

      on ap.activity_id = a.id

     and ap.profile_id = auth.uid()

    where a.id = found_token.activity_id;



    return;

  end if;



  if existing_status = 'justified' then

    return query

    select

      a.id,

      a.title,

      existing_status,

      ap.checked_in_at,

      'Tu asistencia está justificada y no puede modificarse con este código.'::text

    from public.activities a

    join public.activity_participants ap

      on ap.activity_id = a.id

     and ap.profile_id = auth.uid()

    where a.id = found_token.activity_id;



    return;

  end if;



  if existing_status = 'absent' and existing_source <> 'system' then

    return query

    select

      a.id,

      a.title,

      existing_status,

      ap.checked_in_at,

      'Tu asistencia ya fue marcada manualmente. Contacta al responsable de la actividad.'::text

    from public.activities a

    join public.activity_participants ap

      on ap.activity_id = a.id

     and ap.profile_id = auth.uid()

    where a.id = found_token.activity_id;



    return;

  end if;



  source_value := case

    when found_token.secret_token = trim(checkin_input) then 'qr'

    else 'code'

  end;



  update public.activity_participants ap

  set

    attendance_status = 'attended',

    attendance_source = source_value,

    checked_in_at = coalesce(ap.checked_in_at, now()),

    attendance_updated_by = auth.uid(),

    attendance_updated_at = now(),

    updated_at = now()

  where ap.id = participant_id;



  return query

  select

    a.id,

    a.title,

    'attended'::text,

    coalesce(ap.checked_in_at, now()),

    'Asistencia registrada correctamente.'::text

  from public.activities a

  join public.activity_participants ap

    on ap.activity_id = a.id

   and ap.profile_id = auth.uid()

  where a.id = found_token.activity_id;

end;

$function$;

-- Restauración exacta post-0007: close_activity_attendance_checkin(uuid)
CREATE OR REPLACE FUNCTION public.close_activity_attendance_checkin(target_activity_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

begin

  if not public.can_edit_activity(target_activity_id) then

    raise exception 'No tienes permiso para cerrar asistencia en esta actividad.'

      using errcode = '42501';

  end if;



  update public.activity_checkin_tokens t

  set

    is_active = false,

    closed_at = now()

  where t.activity_id = target_activity_id

    and t.token_type = 'attendance'

    and t.is_active = true;

end;

$function$;

-- Restauración exacta post-0007: finalize_expired_attendance()
CREATE OR REPLACE FUNCTION public.finalize_expired_attendance()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

declare

  updated_count integer;

begin

  update public.activity_participants ap

  set

    attendance_status = 'absent',

    attendance_source = 'system',

    attendance_updated_by = null,

    attendance_updated_at = now(),

    checked_in_at = null,

    updated_at = now()

  from public.activities a

  where ap.activity_id = a.id

    and ap.attendance_status = 'pending'

    and a.status_code <> 'draft'

    and public.activity_attendance_deadline(a.id) is not null

    and public.activity_attendance_deadline(a.id) <= now();



  get diagnostics updated_count = row_count;



  update public.activity_checkin_tokens t

  set

    is_active = false,

    closed_at = coalesce(t.closed_at, now())

  where t.is_active = true

    and t.token_type = 'attendance'

    and coalesce(t.expires_at, public.activity_attendance_deadline(t.activity_id)) is not null

    and coalesce(t.expires_at, public.activity_attendance_deadline(t.activity_id)) <= now();



  return updated_count;

end;

$function$;

-- Restauración exacta post-0007: generate_three_word_code()
CREATE OR REPLACE FUNCTION public.generate_three_word_code()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

declare

  words text[] := array[

    'sol', 'luna', 'rio', 'nube', 'mesa', 'patio', 'rama', 'luz',

    'casa', 'libro', 'papel', 'azul', 'verde', 'rojo', 'cafe',

    'plaza', 'puerta', 'silla', 'campo', 'flor', 'piedra', 'mar',

    'monte', 'hoja', 'vaso', 'reloj', 'taza', 'cable', 'mapa',

    'canto', 'pluma', 'techo', 'barco', 'foco', 'arena', 'brisa'

  ];

  code text;

begin

  loop

    code :=

      words[1 + floor(random() * array_length(words, 1))::int]

      || '-' ||

      words[1 + floor(random() * array_length(words, 1))::int]

      || '-' ||

      words[1 + floor(random() * array_length(words, 1))::int];



    exit when not exists (

      select 1

      from public.activity_checkin_tokens t

      where t.code_words = code

        and t.is_active = true

    );

  end loop;



  return code;

end;

$function$;

-- Restauración exacta post-0007: get_active_activity_attendance_checkin(uuid)
CREATE OR REPLACE FUNCTION public.get_active_activity_attendance_checkin(target_activity_id uuid)
 RETURNS TABLE(id uuid, activity_id uuid, code_words text, secret_token text, opened_at timestamp with time zone, expires_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

declare

  open_at timestamptz;

  natural_deadline timestamptz;

begin

  perform public.finalize_expired_attendance();



  if not public.can_edit_activity(target_activity_id) then

    raise exception 'No tienes permiso para consultar el código de asistencia de esta actividad.'

      using errcode = '42501';

  end if;



  open_at := public.activity_attendance_open_at(target_activity_id);

  natural_deadline := public.activity_attendance_deadline(target_activity_id);



  if open_at is null or natural_deadline is null then

    update public.activity_checkin_tokens t

    set

      is_active = false,

      closed_at = coalesce(t.closed_at, now())

    where t.activity_id = target_activity_id

      and t.token_type = 'attendance'

      and t.is_active = true;



    return;

  end if;



  if now() < open_at then

    update public.activity_checkin_tokens t

    set

      is_active = false,

      closed_at = coalesce(t.closed_at, now())

    where t.activity_id = target_activity_id

      and t.token_type = 'attendance'

      and t.is_active = true;



    return;

  end if;



  return query

  select

    t.id,

    t.activity_id,

    t.code_words,

    t.secret_token,

    t.opened_at,

    t.expires_at

  from public.activity_checkin_tokens t

  where t.activity_id = target_activity_id

    and t.token_type = 'attendance'

    and t.is_active = true

    and (t.expires_at is null or t.expires_at > now())

  order by t.opened_at desc

  limit 1;

end;

$function$;

-- Restauración exacta post-0007: get_activity_attendance_checkin_state(uuid)
CREATE OR REPLACE FUNCTION public.get_activity_attendance_checkin_state(target_activity_id uuid)
 RETURNS TABLE(can_manage boolean, is_draft boolean, has_schedule boolean, has_active_token boolean, can_open_now boolean, window_status text, opens_at timestamp with time zone, ordinary_closes_at timestamp with time zone, active_expires_at timestamp with time zone, message text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

declare

  v_can_edit boolean;

  v_status_code text;

  v_start_ts timestamp;

  v_end_ts timestamp;

  v_current_ts timestamp := now() at time zone 'America/Mexico_City';

  v_open_ts timestamp;

  v_close_ts timestamp;

  v_active_expires_at timestamptz;

  v_has_active_token boolean;

begin

  select

    public.can_edit_activity(a.id),

    a.status_code,

    (a.start_date::timestamp + a.start_time),

    (coalesce(a.end_date, a.start_date)::timestamp + coalesce(a.end_time, a.start_time))

  into

    v_can_edit,

    v_status_code,

    v_start_ts,

    v_end_ts

  from public.activities a

  where a.id = target_activity_id;



  if v_status_code is null then

    raise exception 'La actividad no existe.'

      using errcode = 'P0001';

  end if;



  if not v_can_edit then

    raise exception 'No tienes permiso para consultar la asistencia de esta actividad.'

      using errcode = '42501';

  end if;



  if v_status_code = 'draft' then

    return query select

      v_can_edit,

      true,

      false,

      false,

      false,

      'draft'::text,

      null::timestamptz,

      null::timestamptz,

      null::timestamptz,

      'No puedes abrir asistencia en una actividad en borrador.'::text;

    return;

  end if;



  if v_start_ts is null or v_end_ts is null then

    return query select

      v_can_edit,

      false,

      false,

      false,

      false,

      'missing_schedule'::text,

      null::timestamptz,

      null::timestamptz,

      null::timestamptz,

      'La actividad necesita fecha y horario completos para abrir asistencia.'::text;

    return;

  end if;



  v_open_ts := v_start_ts - interval '15 minutes';

  v_close_ts := v_end_ts + interval '15 minutes';



  select t.expires_at

  into v_active_expires_at

  from public.activity_checkin_tokens t

  where t.activity_id = target_activity_id

    and t.token_type = 'attendance'

    and t.is_active = true

    and (t.expires_at is null or t.expires_at > now())

    and v_current_ts >= v_open_ts

  order by t.opened_at desc

  limit 1;



  v_has_active_token := v_active_expires_at is not null;



  if v_has_active_token then

    return query select

      v_can_edit,

      false,

      true,

      true,

      true,

      'open'::text,

      v_open_ts at time zone 'America/Mexico_City',

      v_close_ts at time zone 'America/Mexico_City',

      v_active_expires_at,

      'La asistencia está abierta.'::text;

    return;

  end if;



  if v_current_ts < v_open_ts then

    return query select

      v_can_edit,

      false,



      true,

      false,

      false,

      'not_yet_available'::text,

      v_open_ts at time zone 'America/Mexico_City',

      v_close_ts at time zone 'America/Mexico_City',

      null::timestamptz,

      'La asistencia podrá abrirse 15 minutos antes del inicio de la actividad.'::text;

    return;

  end if;



  if v_current_ts <= v_close_ts then

    return query select

      v_can_edit,

      false,

      true,

      false,

      true,

      'available'::text,

      v_open_ts at time zone 'America/Mexico_City',

      v_close_ts at time zone 'America/Mexico_City',

      null::timestamptz,

      'Puedes abrir asistencia para esta actividad.'::text;

    return;

  end if;



  return query select

    v_can_edit,

    false,

    true,

    false,

    true,

    'reopen_available'::text,

    v_open_ts at time zone 'America/Mexico_City',

    v_close_ts at time zone 'America/Mexico_City',

    null::timestamptz,

    'La actividad ya terminó. Puedes reabrir asistencia por 15 minutos.'::text;

end;

$function$;

-- Restauración exacta post-0007: get_activity_participants(uuid)
CREATE OR REPLACE FUNCTION public.get_activity_participants(target_activity_id uuid)
 RETURNS TABLE(id uuid, activity_id uuid, profile_id uuid, participant_role_code text, participant_role_label text, full_name text, email text, person_type text, institutional_id_type text, institutional_id_value text, program_name text, attendance_status text, attendance_source text, checked_in_at timestamp with time zone, attendance_updated_at timestamp with time zone, attendance_notes text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

begin

  if not public.can_edit_activity(target_activity_id) then

    raise exception 'No tienes permiso para consultar la lista de participantes de esta actividad.'

      using errcode = '42501';

  end if;



  return query

  select

    ap.id,

    ap.activity_id,

    ap.profile_id,

    ap.participant_role_code,

    pr.label as participant_role_label,

    p.full_name,

    p.email,

    p.person_type,

    p.institutional_id_type,

    p.institutional_id_value,

    prog.name as program_name,

    ap.attendance_status,

    ap.attendance_source,

    ap.checked_in_at,

    ap.attendance_updated_at,

    ap.attendance_notes,

    ap.created_at

  from public.activity_participants ap

  join public.profiles p on p.id = ap.profile_id

  left join public.participant_roles pr on pr.code = ap.participant_role_code

  left join public.academic_programs prog on prog.id = p.primary_program_id

  where ap.activity_id = target_activity_id

  order by p.full_name;

end;

$function$;

-- Restauración exacta post-0007: get_visible_activity_cards()
CREATE OR REPLACE FUNCTION public.get_visible_activity_cards()
 RETURNS TABLE(id uuid, title text, description text, activity_type_label text, service_type_label text, service_type_code text, modality_label text, status_label text, status_code text, semester_label text, program_label text, location_type_label text, location_detail text, start_date date, start_time time without time zone, end_date date, end_time time without time zone, duration_mode text, responsible_full_name text, viewer_can_edit boolean, viewer_is_participant boolean, viewer_attendance_status text, viewer_attendance_source text, viewer_checked_in_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select

    a.id,

    a.title,

    a.description,

    at.label as activity_type_label,

    st.label as service_type_label,

    a.service_type_code,

    am.label as modality_label,

    ast.label as status_label,

    a.status_code,

    sem.name as semester_label,

    case

      when a.scope_type = 'division' then 'Ambos programas'

      else ap.name

    end as program_label,

    lt.label as location_type_label,

    a.location_detail,

    a.start_date,

    a.start_time,

    a.end_date,

    a.end_time,

    a.duration_mode,

    coalesce(rp.full_name, 'Responsable sin nombre') as responsible_full_name,

    public.can_edit_activity(a.id) as viewer_can_edit,

    public.is_activity_participant(a.id) as viewer_is_participant,

    viewer_participation.attendance_status as viewer_attendance_status,

    viewer_participation.attendance_source as viewer_attendance_source,

    viewer_participation.checked_in_at as viewer_checked_in_at

  from public.activities a

  left join public.activity_types at on at.code = a.activity_type_code

  left join public.service_types st on st.code = a.service_type_code

  left join public.activity_modalities am on am.code = a.modality_code

  left join public.activity_statuses ast on ast.code = a.status_code

  left join public.academic_periods sem on sem.id = a.academic_period_id

  left join public.academic_programs ap on ap.id = a.program_id

  left join public.location_types lt on lt.code = a.location_type_code

  left join public.profiles rp on rp.id = a.responsible_profile_id

  left join public.activity_participants viewer_participation

    on viewer_participation.activity_id = a.id

   and viewer_participation.profile_id = auth.uid()

  where

    (

      a.status_code = 'draft'

      and a.created_by = auth.uid()

    )

    or

    (

      a.status_code <> 'draft'

      and (

        a.created_by = auth.uid()

        or a.responsible_profile_id = auth.uid()

        or public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)

        or public.is_activity_participant(a.id)

      )

    )

  order by a.start_date desc nulls last, a.start_time desc nulls last, a.created_at desc;

$function$;

-- Restauración exacta post-0007: has_active_role(text)
CREATE OR REPLACE FUNCTION public.has_active_role(required_role text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select exists (

    select 1

    from public.role_assignments ra

    where ra.user_id = auth.uid()

      and ra.role_code = required_role

      and ra.is_active = true

      and ra.starts_at <= current_date

      and (ra.ends_at is null or ra.ends_at >= current_date)

  );

$function$;

-- Restauración exacta post-0007: has_any_active_role(text[])
CREATE OR REPLACE FUNCTION public.has_any_active_role(required_roles text[])
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select exists (

    select 1

    from public.role_assignments ra

    where ra.user_id = auth.uid()

      and ra.role_code = any(required_roles)

      and ra.is_active = true

      and ra.starts_at <= current_date

      and (ra.ends_at is null or ra.ends_at >= current_date)

  );

$function$;

-- Restauración exacta post-0007: is_activity_participant(uuid)
CREATE OR REPLACE FUNCTION public.is_activity_participant(target_activity_id uuid)


 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select exists (

    select 1

    from public.activity_participants ap

    where ap.activity_id = target_activity_id

      and ap.profile_id = auth.uid()

  );

$function$;

-- Restauración exacta post-0007: open_activity_attendance_checkin(uuid)
CREATE OR REPLACE FUNCTION public.open_activity_attendance_checkin(target_activity_id uuid)
 RETURNS TABLE(id uuid, activity_id uuid, code_words text, secret_token text, opened_at timestamp with time zone, expires_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

declare

  new_code text;

  new_id uuid;

  open_at timestamptz;

  natural_deadline timestamptz;

  effective_deadline timestamptz;

begin

  perform public.finalize_expired_attendance();



  if not public.can_edit_activity(target_activity_id) then

    raise exception 'No tienes permiso para abrir asistencia en esta actividad.'

      using errcode = '42501';

  end if;



  if exists (

    select 1

    from public.activities a

    where a.id = target_activity_id

      and a.status_code = 'draft'

  ) then

    raise exception 'No puedes abrir asistencia en una actividad en borrador.'

      using errcode = 'P0001';

  end if;



  open_at := public.activity_attendance_open_at(target_activity_id);

  natural_deadline := public.activity_attendance_deadline(target_activity_id);



  if open_at is null or natural_deadline is null then

    raise exception 'La actividad no tiene horario suficiente para abrir asistencia.'

      using errcode = 'P0001';

  end if;



  if now() < open_at then

    raise exception 'La asistencia aún no puede abrirse para esta actividad.'

      using errcode = 'P0001';

  end if;



  effective_deadline := case

    when natural_deadline <= now() then now() + interval '15 minutes'

    else natural_deadline

  end;



  update public.activity_checkin_tokens t

  set

    is_active = false,

    closed_at = now()

  where t.activity_id = target_activity_id

    and t.token_type = 'attendance'

    and t.is_active = true;



  new_code := public.generate_three_word_code();



  insert into public.activity_checkin_tokens (

    activity_id,

    token_type,

    code_words,

    is_active,

    expires_at,

    created_by

  )

  values (

    target_activity_id,

    'attendance',

    new_code,

    true,

    effective_deadline,

    auth.uid()

  )

  returning public.activity_checkin_tokens.id into new_id;



  return query

  select

    t.id,

    t.activity_id,

    t.code_words,

    t.secret_token,

    t.opened_at,

    t.expires_at

  from public.activity_checkin_tokens t

  where t.id = new_id;

end;

$function$;

-- Restauración exacta post-0007: publish_activity(uuid)
CREATE OR REPLACE FUNCTION public.publish_activity(target_activity_id uuid)
 RETURNS TABLE(activity_id uuid, status_code text, academic_period_id uuid, semester_label text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

declare

  target_activity public.activities%rowtype;

  target_period_id uuid;

  target_semester_label text;

  start_value timestamp;

begin

  if auth.uid() is null then

    raise exception 'Debes iniciar sesión para publicar una actividad.' using errcode = '42501';

  end if;



  select a.* into target_activity

  from public.activities a

  where a.id = target_activity_id

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

  if (start_value at time zone 'America/Mexico_City') <= now() then

    raise exception 'La fecha y hora de inicio deben ser posteriores a la hora actual de Ciudad de México.'

      using errcode = '23514';

  end if;



  select period.id, period.name into target_period_id, target_semester_label

  from public.get_academic_period_for_date(target_activity.start_date) period limit 1;

  if target_period_id is null then

    raise exception 'No hay semestre registrado para la fecha de inicio.' using errcode = '23514';

  end if;



  -- El trigger valida el contrato completo en esta misma sentencia. Cualquier

  -- fallo revierte también la asignación de semestre y el cambio de estado.

  update public.activities a

  set academic_period_id = target_period_id,

      status_code = 'scheduled',

      updated_by = auth.uid()

  where a.id = target_activity_id;



  return query

  select target_activity_id, 'scheduled'::text, target_period_id, target_semester_label;

end;

$function$;

-- Restauración exacta post-0007: remove_activity_participant(uuid)
CREATE OR REPLACE FUNCTION public.remove_activity_participant(target_participant_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

declare

  target_activity_id uuid;

begin

  select ap.activity_id

  into target_activity_id

  from public.activity_participants ap

  where ap.id = target_participant_id;



  if target_activity_id is null then

    raise exception 'El participante no existe.'

      using errcode = 'P0001';

  end if;



  if not public.can_edit_activity(target_activity_id) then

    raise exception 'No tienes permiso para quitar participantes de esta actividad.'

      using errcode = '42501';

  end if;



  delete from public.activity_participants

  where id = target_participant_id;

end;

$function$;

-- Restauración exacta post-0007: search_profiles_for_participation(uuid,text)
CREATE OR REPLACE FUNCTION public.search_profiles_for_participation(target_activity_id uuid, search_text text)
 RETURNS TABLE(id uuid, full_name text, email text, person_type text, institutional_id_type text, institutional_id_value text, primary_program_id uuid, program_name text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

declare

  target_program_id uuid;

begin

  if not public.can_edit_activity(target_activity_id) then

    raise exception 'No tienes permiso para buscar participantes para esta actividad.'

      using errcode = '42501';

  end if;



  select a.program_id

  into target_program_id

  from public.activities a

  where a.id = target_activity_id;



  if target_program_id is null then

    raise exception 'La actividad no tiene programa académico asignado.'

      using errcode = 'P0001';

  end if;



  return query

  select

    p.id,

    p.full_name,

    p.email,

    p.person_type,

    p.institutional_id_type,

    p.institutional_id_value,

    p.primary_program_id,

    ap.name as program_name

  from public.profiles p

  left join public.academic_programs ap on ap.id = p.primary_program_id

  where

    p.is_active = true

    and p.primary_program_id = target_program_id

    and length(trim(search_text)) >= 2

    and (

      extensions.unaccent(lower(coalesce(p.full_name, '')))

        like '%' || extensions.unaccent(lower(trim(search_text))) || '%'

      or extensions.unaccent(lower(coalesce(p.email, '')))

        like '%' || extensions.unaccent(lower(trim(search_text))) || '%'

      or extensions.unaccent(lower(coalesce(p.institutional_id_value, '')))

        like '%' || extensions.unaccent(lower(trim(search_text))) || '%'

    )

  order by p.full_name

  limit 20;

end;

$function$;

-- Restauración exacta post-0007: update_activity_participant_attendance(uuid,text,text)
CREATE OR REPLACE FUNCTION public.update_activity_participant_attendance(target_participant_id uuid, new_attendance_status text, new_attendance_notes text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

declare

  target_activity_id uuid;

  natural_deadline timestamptz;

begin

  if new_attendance_status not in ('pending', 'attended', 'absent', 'justified') then

    raise exception 'El estado de asistencia no es válido.' using errcode = 'P0001';

  end if;



  select ap.activity_id into target_activity_id

  from public.activity_participants ap

  where ap.id = target_participant_id;



  if target_activity_id is null then

    raise exception 'El participante no existe.' using errcode = 'P0001';

  end if;

  if not public.can_edit_activity(target_activity_id) then

    raise exception 'No tienes permiso para modificar la asistencia de esta actividad.'

      using errcode = '42501';

  end if;



  if new_attendance_status = 'pending' then

    natural_deadline := public.activity_attendance_deadline(target_activity_id);

    if natural_deadline is null or natural_deadline <= now() then

      raise exception 'La ventana de asistencia ya terminó; el estado Pendiente ya no está disponible.'

        using errcode = 'P0001';

    end if;

  end if;



  update public.activity_participants

  set attendance_status = new_attendance_status,

      attendance_source = 'manual',

      attendance_updated_by = auth.uid(),

      attendance_updated_at = now(),

      attendance_notes = nullif(trim(coalesce(new_attendance_notes, '')), ''),

      checked_in_at = case when new_attendance_status = 'attended' then checked_in_at else null end,

      updated_at = now()

  where id = target_participant_id;

end;

$function$;

-- Restauración exacta post-0007: update_activity_participants_attendance_bulk(uuid,uuid[],text,text)
CREATE OR REPLACE FUNCTION public.update_activity_participants_attendance_bulk(target_activity_id uuid, target_participant_ids uuid[], new_attendance_status text, new_attendance_notes text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

declare

  updated_count integer;

  natural_deadline timestamptz;

begin

  if new_attendance_status not in ('pending', 'attended', 'absent', 'justified') then

    raise exception 'El estado de asistencia no es válido.' using errcode = 'P0001';

  end if;

  if not public.can_edit_activity(target_activity_id) then

    raise exception 'No tienes permiso para modificar la asistencia de esta actividad.'

      using errcode = '42501';

  end if;

  if target_participant_ids is null or array_length(target_participant_ids, 1) is null then

    raise exception 'No se seleccionaron participantes.' using errcode = 'P0001';

  end if;



  if new_attendance_status = 'pending' then

    natural_deadline := public.activity_attendance_deadline(target_activity_id);

    if natural_deadline is null or natural_deadline <= now() then

      raise exception 'La ventana de asistencia ya terminó; el estado Pendiente ya no está disponible.'

        using errcode = 'P0001';

    end if;

  end if;



  update public.activity_participants ap

  set attendance_status = new_attendance_status,

      attendance_source = 'manual',

      attendance_updated_by = auth.uid(),

      attendance_updated_at = now(),

      attendance_notes = nullif(trim(coalesce(new_attendance_notes, '')), ''),

      checked_in_at = case

        when new_attendance_status = 'attended' then coalesce(ap.checked_in_at, now())

        else null

      end,

      updated_at = now()

  where ap.activity_id = target_activity_id

    and ap.id = any(target_participant_ids);



  get diagnostics updated_count = row_count;

  return updated_count;

end;

$function$;

-- Restaurar de manera determinista los ACL post-0007 de las 29 rutinas.
revoke all on function public.activity_attendance_deadline(uuid) from public, anon, authenticated, service_role, postgres;
grant execute on function public.activity_attendance_deadline(uuid) to postgres, authenticated, service_role;
revoke all on function public.activity_attendance_open_at(uuid) from public, anon, authenticated, service_role, postgres;
grant execute on function public.activity_attendance_open_at(uuid) to postgres, authenticated, service_role;
revoke all on function public.activity_has_ended(uuid) from public, anon, authenticated, service_role, postgres;
grant execute on function public.activity_has_ended(uuid) to postgres, authenticated, service_role;
revoke all on function public.add_activity_participant(uuid,uuid,text) from public, anon, authenticated, service_role, postgres;
grant execute on function public.add_activity_participant(uuid,uuid,text) to postgres, authenticated, service_role;
revoke all on function public.can_create_activity(text,uuid,uuid,text) from public, anon, authenticated, service_role, postgres;
grant execute on function public.can_create_activity(text,uuid,uuid,text) to postgres, authenticated, service_role;
revoke all on function public.can_create_activity(uuid,text) from public, anon, authenticated, service_role, postgres;
grant execute on function public.can_create_activity(uuid,text) to postgres, authenticated, service_role;
revoke all on function public.can_delete_activity(uuid) from public, anon, authenticated, service_role, postgres;
grant execute on function public.can_delete_activity(uuid) to postgres, authenticated, service_role;
revoke all on function public.can_edit_activity(uuid) from public, anon, authenticated, service_role, postgres;
grant execute on function public.can_edit_activity(uuid) to postgres, authenticated, service_role;
revoke all on function public.can_manage_activity(text,uuid,uuid,text) from public, anon, authenticated, service_role, postgres;
grant execute on function public.can_manage_activity(text,uuid,uuid,text) to postgres, authenticated, service_role;
revoke all on function public.can_manage_activity(uuid,text) from public, anon, authenticated, service_role, postgres;
grant execute on function public.can_manage_activity(uuid,text) to postgres, authenticated, service_role;
revoke all on function public.can_read_activity(uuid) from public, anon, authenticated, service_role, postgres;
grant execute on function public.can_read_activity(uuid) to postgres, authenticated, service_role;
revoke all on function public.can_update_activity_base(uuid) from public, anon, authenticated, service_role, postgres;
grant execute on function public.can_update_activity_base(uuid) to postgres, authenticated, service_role;
revoke all on function public.check_in_activity(text) from public, anon, authenticated, service_role, postgres;
grant execute on function public.check_in_activity(text) to postgres, authenticated, service_role;
revoke all on function public.close_activity_attendance_checkin(uuid) from public, anon, authenticated, service_role, postgres;
grant execute on function public.close_activity_attendance_checkin(uuid) to postgres, authenticated, service_role;
revoke all on function public.finalize_expired_attendance() from public, anon, authenticated, service_role, postgres;
grant execute on function public.finalize_expired_attendance() to postgres, authenticated, service_role;
revoke all on function public.generate_three_word_code() from public, anon, authenticated, service_role, postgres;
grant execute on function public.generate_three_word_code() to postgres, authenticated, service_role;
revoke all on function public.get_active_activity_attendance_checkin(uuid) from public, anon, authenticated, service_role, postgres;
grant execute on function public.get_active_activity_attendance_checkin(uuid) to postgres, authenticated, service_role;
revoke all on function public.get_activity_attendance_checkin_state(uuid) from public, anon, authenticated, service_role, postgres;
grant execute on function public.get_activity_attendance_checkin_state(uuid) to postgres, authenticated, service_role;
revoke all on function public.get_activity_participants(uuid) from public, anon, authenticated, service_role, postgres;
grant execute on function public.get_activity_participants(uuid) to postgres, authenticated, service_role;
revoke all on function public.get_visible_activity_cards() from public, anon, authenticated, service_role, postgres;
grant execute on function public.get_visible_activity_cards() to postgres, authenticated, service_role;
revoke all on function public.has_active_role(text) from public, anon, authenticated, service_role, postgres;
grant execute on function public.has_active_role(text) to postgres, authenticated, service_role;
revoke all on function public.has_any_active_role(text[]) from public, anon, authenticated, service_role, postgres;
grant execute on function public.has_any_active_role(text[]) to postgres, authenticated, service_role;
revoke all on function public.is_activity_participant(uuid) from public, anon, authenticated, service_role, postgres;
grant execute on function public.is_activity_participant(uuid) to postgres, authenticated, service_role;
revoke all on function public.open_activity_attendance_checkin(uuid) from public, anon, authenticated, service_role, postgres;
grant execute on function public.open_activity_attendance_checkin(uuid) to postgres, authenticated, service_role;
revoke all on function public.publish_activity(uuid) from public, anon, authenticated, service_role, postgres;
grant execute on function public.publish_activity(uuid) to postgres, authenticated, service_role;
revoke all on function public.remove_activity_participant(uuid) from public, anon, authenticated, service_role, postgres;
grant execute on function public.remove_activity_participant(uuid) to postgres, authenticated, service_role;
revoke all on function public.search_profiles_for_participation(uuid,text) from public, anon, authenticated, service_role, postgres;
grant execute on function public.search_profiles_for_participation(uuid,text) to postgres, authenticated, service_role;
revoke all on function public.update_activity_participant_attendance(uuid,text,text) from public, anon, authenticated, service_role, postgres;
grant execute on function public.update_activity_participant_attendance(uuid,text,text) to postgres, authenticated, service_role;
revoke all on function public.update_activity_participants_attendance_bulk(uuid,uuid[],text,text) from public, anon, authenticated, service_role, postgres;
grant execute on function public.update_activity_participants_attendance_bulk(uuid,uuid[],text,text) to postgres, authenticated, service_role;

revoke all on function public.is_sitaa_operational_account_active()
  from public, anon, authenticated, service_role;
drop function public.is_sitaa_operational_account_active();

do $post_rollback$
declare
  mismatch_count integer;
begin
  if (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>47
     or (select count(*) from pg_policies where schemaname='public')<>23
     or (select count(*) from information_schema.columns where table_schema='public')<>165
     or (select count(*) from pg_constraint c join pg_namespace n on n.oid=c.connamespace
         where n.nspname='public' and c.contype in ('p','f','u','c'))<>80
     or (select count(*) from pg_indexes where schemaname='public')<>43
     or (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid
         join pg_namespace n on n.oid=c.relnamespace
         where n.nspname='public' and not t.tgisinternal)<>10 then
    raise exception '0008_rollback_inventory_mismatch';
  end if;

  if to_regprocedure('public.is_sitaa_operational_account_active()') is not null
     or to_regprocedure('public.get_admin_identity_correction_context_b2a(uuid)') is not null
     or to_regprocedure('public.correct_admin_account_identity_b2a(uuid,text,text,text,text,text,uuid,text)') is not null
     or to_regprocedure('public.enforce_activity_writer_integrity_b2a()') is not null
     or exists (
       select 1 from pg_trigger
       where tgrelid='public.activities'::regclass
         and tgname='enforce_activity_writer_integrity_b2a'
         and not tgisinternal
     )
     or exists (
       select 1 from pg_policies
       where schemaname='public'
         and policyname in (
           'Active accounts may operate activities',
           'Active accounts may operate activity participants'
         )
     ) then
    raise exception '0008_rollback_objects_remain';
  end if;

  if (
    select md5(btrim(regexp_replace(lower(p.prosrc),'\s+',' ','g')))
    from pg_proc p
    where p.oid=to_regprocedure('public.activity_attendance_deadline(uuid)')
  ) is distinct from '1f4b283800a8ef76c73ea8c88d19f0ca' then
    raise exception '0008_rollback_hash_normalization_regression';
  end if;

  select count(*) into mismatch_count
  from (values
    ('activity_attendance_deadline(uuid)','1f4b283800a8ef76c73ea8c88d19f0ca'),
    ('activity_attendance_open_at(uuid)','fbda59c4d62ebef5b3f0b09e6e79e5c9'),
    ('activity_has_ended(uuid)','cad09173d39032098ae7dadb119c202e'),
    ('add_activity_participant(uuid,uuid,text)','0da768212cbda95e7b12243df228ea95'),
    ('can_create_activity(text,uuid,uuid,text)','5ded1a27389f15b4bfa0d5d94479bd24'),
    ('can_create_activity(uuid,text)','18a4feaa903de578cdf72530392c8a3b'),
    ('can_delete_activity(uuid)','9b2bdf03d3a4511cf642c31703f387b2'),
    ('can_edit_activity(uuid)','a5765107e77dfb4c2697058b07baa35a'),
    ('can_manage_activity(text,uuid,uuid,text)','77c34655bec048b145daf5f84263daba'),
    ('can_manage_activity(uuid,text)','1e62f4eafb301e5b7e5a1040bcb550e7'),
    ('can_read_activity(uuid)','a5765107e77dfb4c2697058b07baa35a'),
    ('can_update_activity_base(uuid)','9b2bdf03d3a4511cf642c31703f387b2'),
    ('check_in_activity(text)','d62ed8f20e91f13ce6d147666da00531'),
    ('close_activity_attendance_checkin(uuid)','b7d5c58d566ec443ce66d9c01e117048'),
    ('finalize_expired_attendance()','59424db7c07d0b8b86990175e2dd21d7'),
    ('generate_three_word_code()','1cedc853200075a2ec3cf50ff50d1333'),
    ('get_active_activity_attendance_checkin(uuid)','3fac0094d6750c0dd3b6276aa07932a2'),
    ('get_activity_attendance_checkin_state(uuid)','2e8eb442a3ce77d36085aaa94fc6d053'),
    ('get_activity_participants(uuid)','3257ea54e99f258db681c59617672367'),
    ('get_visible_activity_cards()','2fd74e3407a34a19d8908bd7cae68cd3'),
    ('has_active_role(text)','5c9f83e307117edb7aa95e874dc46576'),
    ('has_any_active_role(text[])','be7c62cd70f8ac8e1917c30651bc6100'),
    ('is_activity_participant(uuid)','f32e9c47c6d78891e1aa858007490d05'),
    ('open_activity_attendance_checkin(uuid)','8ed6b92262b08c8f70fcf75726b820b6'),
    ('publish_activity(uuid)','43912ebfc85ce537096a71749f2272da'),
    ('remove_activity_participant(uuid)','b908dd128b24f979d9645c8b76cb62cd'),
    ('search_profiles_for_participation(uuid,text)','07b799b2af7ebc1ee6140b37bc1c64cf'),
    ('update_activity_participant_attendance(uuid,text,text)','a8d51f9ad77800062e3216602d51569a'),
    ('update_activity_participants_attendance_bulk(uuid,uuid[],text,text)','8b86022211acee5d3094a954afec787b')
  ) expected(signature,body_hash)
  left join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
  where p.oid is null
     or md5(btrim(regexp_replace(lower(p.prosrc),'\s+',' ','g')))<>expected.body_hash;
  if mismatch_count<>0 then
    raise exception '0008_rollback_definition_mismatch';
  end if;

  select count(*) into mismatch_count
  from (values
    ('activity_attendance_deadline(uuid)'),
    ('activity_attendance_open_at(uuid)'),
    ('activity_has_ended(uuid)'),
    ('add_activity_participant(uuid,uuid,text)'),
    ('can_create_activity(text,uuid,uuid,text)'),
    ('can_create_activity(uuid,text)'),
    ('can_delete_activity(uuid)'),
    ('can_edit_activity(uuid)'),
    ('can_manage_activity(text,uuid,uuid,text)'),
    ('can_manage_activity(uuid,text)'),
    ('can_read_activity(uuid)'),
    ('can_update_activity_base(uuid)'),
    ('check_in_activity(text)'),
    ('close_activity_attendance_checkin(uuid)'),
    ('finalize_expired_attendance()'),
    ('generate_three_word_code()'),
    ('get_active_activity_attendance_checkin(uuid)'),
    ('get_activity_attendance_checkin_state(uuid)'),
    ('get_activity_participants(uuid)'),
    ('get_visible_activity_cards()'),
    ('has_active_role(text)'),
    ('has_any_active_role(text[])'),
    ('is_activity_participant(uuid)'),
    ('open_activity_attendance_checkin(uuid)'),
    ('publish_activity(uuid)'),
    ('remove_activity_participant(uuid)'),
    ('search_profiles_for_participation(uuid,text)'),
    ('update_activity_participant_attendance(uuid,text,text)'),
    ('update_activity_participants_attendance_bulk(uuid,uuid[],text,text)')
  ) expected(signature)
  join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
  where (
    select count(*)
    from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
    left join pg_roles grantee on grantee.oid=acl.grantee
    where acl.privilege_type='EXECUTE'
      and coalesce(grantee.rolname,'PUBLIC') in ('postgres','authenticated','service_role')
      and not acl.is_grantable
  )<>3
  or exists (
    select 1
    from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
    left join pg_roles grantee on grantee.oid=acl.grantee
    where acl.privilege_type<>'EXECUTE'
       or coalesce(grantee.rolname,'PUBLIC') not in ('postgres','authenticated','service_role')
       or acl.is_grantable
  );
  if mismatch_count<>0 then
    raise exception '0008_rollback_acl_mismatch';
  end if;

  if not has_table_privilege('authenticated','public.activities','SELECT,INSERT,UPDATE,DELETE')
     or not has_table_privilege('authenticated','public.activity_participants','SELECT,INSERT,UPDATE,DELETE')
     or has_table_privilege('authenticated','public.role_assignments','INSERT')
     or has_table_privilege('authenticated','public.role_assignments','UPDATE')
     or has_table_privilege('authenticated','public.role_assignments','DELETE') then
    raise exception '0008_rollback_writer_privilege_restoration_mismatch';
  end if;

  if has_table_privilege('authenticated','public.admin_audit_events','SELECT')
     or has_table_privilege('authenticated','public.admin_audit_events','INSERT')
     or not has_table_privilege('service_role','public.admin_audit_events','SELECT')
     or not has_table_privilege('service_role','public.admin_audit_events','INSERT')
     or has_table_privilege('service_role','public.admin_audit_events','UPDATE')
     or has_table_privilege('service_role','public.admin_audit_events','DELETE') then
    raise exception '0008_rollback_audit_contract_changed';
  end if;
end;
$post_rollback$;

commit;

