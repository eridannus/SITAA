-- Verificador transaccional de 0008.
-- Usa sólo fixtures sintéticos, no persiste privilegios ni datos y termina en ROLLBACK.
begin;
set local time zone 'UTC';

-- Contrato estático: inventario, nuevas funciones, ACL, RLS y matriz operativa.
do $static_contract$
declare
  helper_oid oid:=to_regprocedure('public.is_sitaa_operational_account_active()');
  context_oid oid:=to_regprocedure('public.get_admin_identity_correction_context_b2a(uuid)');
  correction_oid oid:=to_regprocedure('public.correct_admin_account_identity_b2a(uuid,text,text,text,text,text,uuid,text)');
  mismatch_count integer;
  correction_source text;
  participant_writer_source text;
begin
  if (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relkind='r')<>18
     or (select count(*) from information_schema.columns where table_schema='public')<>165
     or (select count(*) from pg_constraint c join pg_namespace n on n.oid=c.connamespace
         where n.nspname='public' and c.contype in ('p','f','u','c'))<>80
     or (select count(*) from pg_indexes where schemaname='public')<>43
     or (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid
         join pg_namespace n on n.oid=c.relnamespace
         where n.nspname='public' and not t.tgisinternal)<>10
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public')<>50
     or (select count(*) from pg_policies where schemaname='public')<>25 then
    raise exception '0008_verify_inventory_mismatch';
  end if;

  if helper_oid is null or context_oid is null or correction_oid is null then
    raise exception '0008_verify_new_function_missing';
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
         and lower(p.prosrc) like '%account_status=''active''%'
         and lower(p.prosrc) like '%is_active=true%'
         and lower(p.prosrc) like '%count(*)=1%'
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
         and lower(p.prosrc) like '%is_b1_account_admin()%'
         and lower(p.prosrc) like '%sitaa_current_mexico_date()%'
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
         and lower(p.prosrc) like '%for update%'
         and lower(p.prosrc) like '%account_identity_corrected%'
         and lower(p.prosrc) like '%changed_fields%'
     ) then
    raise exception '0008_verify_new_function_definition_mismatch';
  end if;

  select count(*) into mismatch_count
  from (values
    (helper_oid),(context_oid),(correction_oid)
  ) expected(function_oid)
  where (
    select count(*)
    from aclexplode(coalesce((select proacl from pg_proc where oid=expected.function_oid),
      acldefault('f',(select proowner from pg_proc where oid=expected.function_oid)))) acl
    left join pg_roles grantee on grantee.oid=acl.grantee
    where acl.privilege_type='EXECUTE'
      and (acl.grantee=(select proowner from pg_proc where oid=expected.function_oid)
        or grantee.rolname='authenticated')
      and not acl.is_grantable
  )<>2
  or not has_function_privilege('authenticated',expected.function_oid,'EXECUTE')
  or has_function_privilege('anon',expected.function_oid,'EXECUTE')
  or has_function_privilege('service_role',expected.function_oid,'EXECUTE')
  or exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
    left join pg_roles grantee on grantee.oid=acl.grantee
    where p.oid=expected.function_oid
      and (acl.privilege_type<>'EXECUTE'
        or (acl.grantee<>p.proowner and coalesce(grantee.rolname,'PUBLIC')<>'authenticated')
        or acl.is_grantable)
  );
  if mismatch_count<>0 then
    raise exception '0008_verify_new_function_acl_mismatch';
  end if;

  select lower(prosrc) into correction_source from pg_proc where oid=correction_oid;
  select lower(prosrc) into participant_writer_source
  from pg_proc where oid=to_regprocedure('public.add_activity_participant(uuid,uuid,text)');
  if position('lock table public.role_assignments in share mode' in correction_source)=0
     or position('lock table public.activities in share mode' in correction_source)=0
     or position('lock table public.activity_participants in share mode' in correction_source)=0
     or position('lock table public.role_assignments in share mode' in correction_source)
       >=position('lock table public.activities in share mode' in correction_source)
     or position('lock table public.activities in share mode' in correction_source)
       >=position('lock table public.activity_participants in share mode' in correction_source)
     or position('lock table public.activity_participants in share mode' in correction_source)
       >=position('for update' in correction_source)
     or participant_writer_source not like '%lock table public.activity_participants in row exclusive mode%'
     or participant_writer_source not like '%for share%'
     or position('lock table public.activity_participants in row exclusive mode' in participant_writer_source)
       >=position('for share' in participant_writer_source) then
    raise exception '0008_verify_dependency_lock_protocol_mismatch';
  end if;

  if exists (
    select 1
    from (values
      ('profiles'),('role_assignments'),('activities'),
      ('activity_participants'),('admin_audit_events')
    ) required(table_name)
    left join pg_class c on c.oid=to_regclass('public.'||required.table_name)
    where c.oid is null or not c.relrowsecurity
  ) then
    raise exception '0008_verify_required_rls_disabled';
  end if;

  if exists (
       select 1 from public.profiles p left join auth.users u on u.id=p.id
       where u.id is null
     )
     or exists (
       select 1 from auth.users u left join public.profiles p on p.id=u.id
       where p.id is null
     )
     or not exists (
       select 1 from pg_constraint c
       where c.conrelid='public.profiles'::regclass
         and c.conname='profiles_id_fkey' and c.contype='f'
         and pg_get_constraintdef(c.oid)='FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE'
     )
     or not exists (
       select 1 from pg_constraint c
       where c.conrelid='public.role_assignments'::regclass
         and c.conname='role_assignments_user_id_fkey' and c.contype='f'
         and pg_get_constraintdef(c.oid)='FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE'
     )
     or exists (
       select 1 from public.role_assignments ra
       left join public.profiles p on p.id=ra.user_id where p.id is null
     ) then
    raise exception '0008_verify_auth_profile_or_fk_contract_mismatch';
  end if;

  if not exists (
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
     )
     or (select count(*) from pg_policies where schemaname='public' and tablename='activities')<>5
     or (select count(*) from pg_policies where schemaname='public' and tablename='activity_participants')<>5 then
    raise exception '0008_verify_restrictive_policy_mismatch';
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
    raise exception '0008_verify_guarded_definition_mismatch';
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
    select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
    left join pg_roles grantee on grantee.oid=acl.grantee
    where acl.privilege_type<>'EXECUTE'
       or coalesce(grantee.rolname,'PUBLIC') not in ('postgres','authenticated','service_role')
       or acl.is_grantable
  );
  if mismatch_count<>0 then
    raise exception '0008_verify_guarded_acl_changed';
  end if;

  -- Las 47 firmas post-0007 quedan clasificadas: 29 con barrera y 18 exentas.
  if exists (
    with expected(signature,disposition) as (
      values
      ('activity_attendance_deadline(uuid)','guarded'),
      ('activity_attendance_open_at(uuid)','guarded'),
      ('activity_has_ended(uuid)','guarded'),
      ('add_activity_participant(uuid,uuid,text)','guarded'),
      ('can_create_activity(text,uuid,uuid,text)','guarded'),
      ('can_create_activity(uuid,text)','guarded'),
      ('can_delete_activity(uuid)','guarded'),
      ('can_edit_activity(uuid)','guarded'),
      ('can_manage_activity(text,uuid,uuid,text)','guarded'),
      ('can_manage_activity(uuid,text)','guarded'),
      ('can_read_activity(uuid)','guarded'),
      ('can_update_activity_base(uuid)','guarded'),
      ('check_in_activity(text)','guarded'),
      ('close_activity_attendance_checkin(uuid)','guarded'),
      ('finalize_expired_attendance()','guarded'),
      ('generate_three_word_code()','guarded'),
      ('get_active_activity_attendance_checkin(uuid)','guarded'),
      ('get_activity_attendance_checkin_state(uuid)','guarded'),
      ('get_activity_participants(uuid)','guarded'),
      ('get_visible_activity_cards()','guarded'),
      ('has_active_role(text)','guarded'),
      ('has_any_active_role(text[])','guarded'),
      ('is_activity_participant(uuid)','guarded'),
      ('open_activity_attendance_checkin(uuid)','guarded'),
      ('publish_activity(uuid)','guarded'),
      ('remove_activity_participant(uuid)','guarded'),
      ('search_profiles_for_participation(uuid,text)','guarded'),
      ('update_activity_participant_attendance(uuid,text,text)','guarded'),
      ('update_activity_participants_attendance_bulk(uuid,uuid[],text,text)','guarded'),
      ('admin_audit_metadata_is_safe(jsonb)','exempt'),
      ('complete_own_google_registration(text,text,text,text,text,uuid)','exempt'),
      ('complete_own_google_registration(text,text,text,uuid)','exempt'),
      ('enforce_sitaa_profile_identity()','exempt'),
      ('get_academic_period_for_date(date)','exempt'),
      ('get_admin_account_assignments_b1(uuid)','exempt'),
      ('get_admin_account_audit_history_b1(uuid,integer,integer)','exempt'),
      ('get_admin_account_detail_b1(uuid)','exempt'),
      ('guard_activity_participant_pending_deadline()','exempt'),
      ('handle_sitaa_auth_user_created()','exempt'),
      ('is_b1_account_admin()','exempt'),
      ('normalize_sitaa_profile_names()','exempt'),
      ('prevent_admin_audit_event_mutation()','exempt'),
      ('search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)','exempt'),
      ('set_updated_at()','exempt'),
      ('sitaa_current_mexico_date()','exempt'),
      ('sync_sitaa_profile_email_from_auth()','exempt'),
      ('validate_activity_scheduled_state()','exempt')
    ), live as (
      select p.oid::regprocedure::text signature
      from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.proname not in (
        'is_sitaa_operational_account_active',
        'get_admin_identity_correction_context_b2a',
        'correct_admin_account_identity_b2a'
      )
    )
    select 1 from (
      (select signature from expected except select signature from live)
      union all
      (select signature from live except select signature from expected)
    ) uncovered
  ) then
    raise exception '0008_verify_authorization_matrix_incomplete';
  end if;

  if has_table_privilege('authenticated','public.activity_checkin_tokens','SELECT')
     or has_table_privilege('authenticated','public.activity_checkin_tokens','INSERT')
     or has_table_privilege('authenticated','public.activity_checkin_tokens','UPDATE')
     or has_table_privilege('authenticated','public.activity_checkin_tokens','DELETE')
     or has_table_privilege('authenticated','public.admin_audit_events','SELECT')
     or has_table_privilege('authenticated','public.admin_audit_events','INSERT')
     or not has_table_privilege('service_role','public.admin_audit_events','SELECT')
     or not has_table_privilege('service_role','public.admin_audit_events','INSERT')
     or has_table_privilege('service_role','public.admin_audit_events','UPDATE')
     or has_table_privilege('service_role','public.admin_audit_events','DELETE') then
    raise exception '0008_verify_direct_privilege_drift';
  end if;

  if not exists (
    select 1 from pg_class c
    where c.oid='public.admin_audit_events'::regclass and c.relrowsecurity
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
      and not exists(
        select 1 from aclexplode(c.relacl) acl
        where acl.grantee not in (
          c.relowner,(select oid from pg_roles where rolname='service_role')
        )
           or acl.is_grantable
           or (acl.grantee=c.relowner and upper(acl.privilege_type) not in (
             'SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN'
           ))
           or (acl.grantee=(select oid from pg_roles where rolname='service_role')
             and upper(acl.privilege_type) not in ('SELECT','INSERT'))
      )
      and not exists(
        select 1 from pg_attribute a
        where a.attrelid=c.oid and a.attnum>0 and not a.attisdropped
          and a.attacl is not null and exists(select 1 from aclexplode(a.attacl))
      )
  ) then
    raise exception '0008_verify_audit_exact_acl_mismatch';
  end if;

  if to_regprocedure('public.complete_own_google_registration(text,text,text,text,text,uuid)') is null
     or to_regprocedure('public.get_admin_account_detail_b1(uuid)') is null
     or to_regprocedure('public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)') is null
     or to_regprocedure('public.get_admin_account_assignments_b1(uuid)') is null
     or to_regprocedure('public.get_admin_account_audit_history_b1(uuid,integer,integer)') is null
     or not exists (
       select 1 from pg_trigger t join pg_class c on c.oid=t.tgrelid
       join pg_namespace n on n.oid=c.relnamespace
       where n.nspname='auth' and c.relname='users' and not t.tgisinternal
         and t.tgname in ('on_auth_user_created','on_auth_user_updated')
     )
     or exists (
       select 1 from information_schema.columns
       where table_schema='public' and table_name='role_assignments'
         and column_name in ('revoked_by','revoked_at','administrative_notes','status')
     ) then
    raise exception '0008_verify_registration_b1_or_phase_boundary_drift';
  end if;
end;
$static_contract$;

-- Fixtures sintéticos.
create temporary table sitaa_0008_context(
  run_marker text not null,
  institutional_today date not null,
  division_a uuid not null,
  division_b uuid not null,
  program_a uuid not null,
  program_b uuid not null,
  inactive_program uuid not null,
  academic_period_id uuid not null,
  academic_period_code text not null,
  academic_period_start date not null,
  academic_period_end date not null,
  fixture_activity_date date not null,
  academic_period_sort_order integer not null,
  activity_draft uuid not null,
  activity_scheduled uuid not null
) on commit drop;

insert into sitaa_0008_context(
  run_marker,institutional_today,division_a,division_b,program_a,program_b,
  inactive_program,academic_period_id,academic_period_code,
  academic_period_start,academic_period_end,fixture_activity_date,
  academic_period_sort_order,activity_draft,activity_scheduled
)
select
  'v8'||replace(seed::text,'-',''),
  public.sitaa_current_mexico_date(),
  gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),
  gen_random_uuid(),period_id,
  'v8s_'||left(replace(seed::text,'-',''),24),
  period_start,period_start+120,period_start+10,
  1000000000+mod(abs(hashtext(seed::text)::bigint),1000000000)::integer,
  gen_random_uuid(),gen_random_uuid()
from (
  select
    seed,
    gen_random_uuid() period_id,
    greatest(
      public.sitaa_current_mexico_date()+365,
      coalesce(
        (select max(ends_on) from public.academic_periods where ends_on is not null),
        public.sitaa_current_mexico_date()
      )+31
    ) period_start
  from (select gen_random_uuid() seed) generated_seed
) generated;

insert into public.divisions(id,code,name)
select division_a,'v8da_'||left(replace(division_a::text,'-',''),16),'División sintética A 0008'
from sitaa_0008_context
union all
select division_b,'v8db_'||left(replace(division_b::text,'-',''),16),'División sintética B 0008'
from sitaa_0008_context;

insert into public.academic_programs(id,division_id,code,name,is_active)
select program_a,division_a,'v8pa_'||left(replace(program_a::text,'-',''),16),'Programa sintético A 0008',true from sitaa_0008_context
union all
select program_b,division_b,'v8pb_'||left(replace(program_b::text,'-',''),16),'Programa sintético B 0008',true from sitaa_0008_context
union all
select inactive_program,division_a,'v8pi_'||left(replace(inactive_program::text,'-',''),16),'Programa inactivo sintético 0008',false from sitaa_0008_context;

insert into public.academic_periods(
  id,code,name,starts_on,ends_on,is_active,sort_order
)
select
  academic_period_id,academic_period_code,
  'Semestre sintético '||academic_period_code,
  academic_period_start,academic_period_end,true,academic_period_sort_order
from sitaa_0008_context;

do $academic_period_fixture_contract$
begin
  if not exists (
    select 1
    from pg_temp.sitaa_0008_context fixture
    join lateral public.get_academic_period_for_date(fixture.fixture_activity_date) resolved
      on resolved.id=fixture.academic_period_id
  ) then
    raise exception '0008_verify_synthetic_academic_period_resolution_failed';
  end if;
end;
$academic_period_fixture_contract$;

create temporary table sitaa_0008_cases(
  label text primary key,
  id uuid not null unique,
  email text not null unique,
  identifier text null unique
) on commit drop;

create function pg_temp.case_id(target_label text)
returns uuid language sql stable set search_path=pg_temp as $$
  select id from sitaa_0008_cases where label=target_label
$$;
create function pg_temp.case_email(target_label text)
returns text language sql stable set search_path=pg_temp as $$
  select email from sitaa_0008_cases where label=target_label
$$;
create function pg_temp.case_identifier(target_label text)
returns text language sql stable set search_path=pg_temp as $$
  select identifier from sitaa_0008_cases where label=target_label
$$;
create function pg_temp.set_request_user(target_label text)
returns void language plpgsql set search_path=pg_temp,pg_catalog as $$
declare target_id uuid:=pg_temp.case_id(target_label);
begin
  perform set_config('request.jwt.claim.sub',target_id::text,true);
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub',target_id,'role','authenticated')::text,true);
end;
$$;

revoke all on function pg_temp.case_id(text),pg_temp.case_email(text),
  pg_temp.case_identifier(text),pg_temp.set_request_user(text) from public,anon;
grant select on table pg_temp.sitaa_0008_cases,pg_temp.sitaa_0008_context to authenticated;
grant execute on function pg_temp.case_id(text),pg_temp.case_email(text),
  pg_temp.case_identifier(text),pg_temp.set_request_user(text) to authenticated;

create function pg_temp.create_case(
  target_label text,
  target_kind text,
  target_person text default null,
  target_status text default 'active',
  target_program_slot text default 'a',
  target_confirmed boolean default true
)
returns uuid language plpgsql
set search_path=public,auth,pg_temp,pg_catalog
as $$
declare
  target_id uuid:=gen_random_uuid();
  marker text:=(select run_marker from sitaa_0008_context);
  target_email text:=replace(target_label,'_','-')||'-'||marker||'@example.invalid';
  target_program uuid:=case target_program_slot
    when 'a' then (select program_a from sitaa_0008_context)
    when 'b' then (select program_b from sitaa_0008_context)
    else null end;
  numeric_seed text:=translate(replace(target_id::text,'-',''),'abcdef','012345');
  identifier_value text;
  app_metadata jsonb;
begin
  if target_kind='institutional' then identifier_value:=numeric_seed; end if;
  app_metadata:=case
    when target_kind='technical' then jsonb_build_object(
      'sitaa_account_kind','technical','sitaa_first_names','Soporte sintético'
    )
    else jsonb_build_object('provider','google','providers',jsonb_build_array('google'))
  end;

  insert into sitaa_0008_cases values(target_label,target_id,target_email,identifier_value);
  insert into auth.users(
    id,aud,role,email,encrypted_password,email_confirmed_at,
    raw_app_meta_data,raw_user_meta_data,created_at,updated_at
  ) values(
    target_id,'authenticated','authenticated',target_email,'',
    case when target_confirmed then now() else null end,
    app_metadata,jsonb_build_object('name','Cuenta sintética 0008'),now(),now()
  );

  if target_status='pending_registration' then
    return target_id;
  end if;

  if target_kind='technical' then
    update public.profiles set
      first_names='Soporte sintético',paternal_surname=null,maternal_surname=null,
      full_name='Soporte sintético',account_kind='technical',account_status=target_status,
      person_type=null,primary_program_id=null,institutional_id_type=null,
      institutional_id_value=null,is_active=(target_status='active'),
      activated_at=now(),deactivated_at=case when target_status='inactive' then now() else null end
    where id=target_id;
  else
    update public.profiles set
      first_names='Persona sintética',paternal_surname='Prueba',maternal_surname=null,
      full_name='Persona sintética Prueba',account_kind='institutional',
      account_status=target_status,person_type=target_person,
      primary_program_id=target_program,
      institutional_id_type=case when target_person='student' then 'student_account' else 'worker_number' end,
      institutional_id_value=identifier_value,is_active=(target_status='active'),
      activated_at=now(),deactivated_at=case when target_status='inactive' then now() else null end
    where id=target_id;
  end if;
  return target_id;
end;
$$;

select pg_temp.create_case('admin_exact','technical');
select pg_temp.create_case('admin_bad_scope','technical');
select pg_temp.create_case('admin_inactive','technical',null,'inactive');
select pg_temp.create_case('active_professor','institutional','professor');
select pg_temp.create_case('active_student','institutional','student');
select pg_temp.create_case('pending_user','institutional',null,'pending_registration');
select pg_temp.create_case('target_institutional','institutional','student');
select pg_temp.create_case('target_inactive','institutional','professor','inactive');
select pg_temp.create_case('target_technical','technical');
select pg_temp.create_case('target_pending','institutional',null,'pending_registration');
select pg_temp.create_case('target_current_role','institutional','student');
select pg_temp.create_case('target_future_role','institutional','student');
select pg_temp.create_case('target_historical_role','institutional','student');
select pg_temp.create_case('target_program_dependency','institutional','professor');
select pg_temp.create_case('target_division_dependency','institutional','professor');
select pg_temp.create_case('target_open_responsible','institutional','professor');
select pg_temp.create_case('target_program_responsible','institutional','professor');
select pg_temp.create_case('target_program_participant','institutional','professor');
select pg_temp.create_case('target_history_only','institutional','student');
select pg_temp.create_case('duplicate_holder','institutional','student');
select pg_temp.create_case('google_pending','institutional',null,'pending_registration',null,true);

insert into public.role_assignments(
  user_id,role_code,scope_type,service_area,division_id,program_id,
  starts_at,ends_at,is_active,assigned_by
)
values
(pg_temp.case_id('admin_exact'),'technical_admin','system','technical',null,null,
  (select institutional_today from sitaa_0008_context),null,true,pg_temp.case_id('admin_exact')),
(pg_temp.case_id('admin_bad_scope'),'technical_admin','own','technical',null,null,
  (select institutional_today from sitaa_0008_context),null,true,pg_temp.case_id('admin_exact')),
(pg_temp.case_id('admin_inactive'),'technical_admin','system','technical',null,null,
  (select institutional_today from sitaa_0008_context),null,true,pg_temp.case_id('admin_exact')),
(pg_temp.case_id('active_professor'),'professor','program','both',null,
  (select program_a from sitaa_0008_context),(select institutional_today from sitaa_0008_context),null,true,pg_temp.case_id('admin_exact')),
(pg_temp.case_id('active_student'),'student','own','both',null,null,
  (select institutional_today from sitaa_0008_context),null,true,pg_temp.case_id('admin_exact')),
(pg_temp.case_id('target_current_role'),'student','own','both',null,null,
  (select institutional_today from sitaa_0008_context),null,true,pg_temp.case_id('admin_exact')),
(pg_temp.case_id('target_future_role'),'student','own','both',null,null,
  (select institutional_today+5 from sitaa_0008_context),null,true,pg_temp.case_id('admin_exact')),
(pg_temp.case_id('target_historical_role'),'student','own','both',null,null,
  (select institutional_today-20 from sitaa_0008_context),(select institutional_today-1 from sitaa_0008_context),true,pg_temp.case_id('admin_exact')),
(pg_temp.case_id('target_program_dependency'),'professor','program','both',null,
  (select program_a from sitaa_0008_context),(select institutional_today from sitaa_0008_context),null,true,pg_temp.case_id('admin_exact')),
(pg_temp.case_id('target_division_dependency'),'division_tutoring_liaison','division','both',
  (select division_a from sitaa_0008_context),null,
  (select institutional_today from sitaa_0008_context),null,true,pg_temp.case_id('admin_exact'));

insert into public.activities(
  id,title,description,academic_period_id,program_id,activity_type_code,service_type_code,
  attention_category_code,modality_code,status_code,location_type_code,
  location_detail,start_date,start_time,end_date,end_time,duration_mode,
  scope_type,division_id,responsible_profile_id,created_by
)
select activity_draft,'Actividad sintética borrador',null,
  academic_period_id,
  program_a,'group_activity','tutoring',
  'disciplinary','in_person','draft','classroom','Aula sintética',
  fixture_activity_date,time '10:00',fixture_activity_date,time '11:00','one_hour',
  'program',division_a,pg_temp.case_id('active_professor'),pg_temp.case_id('active_professor')
from sitaa_0008_context
union all
select activity_scheduled,'Actividad sintética programada',null,
  academic_period_id,
  program_a,'group_activity','tutoring',
  'disciplinary','in_person','scheduled','classroom','Aula sintética',
  fixture_activity_date,time '12:00',fixture_activity_date,time '13:00','one_hour',
  'program',division_a,pg_temp.case_id('active_professor'),pg_temp.case_id('active_professor')
from sitaa_0008_context;

do $scheduled_academic_period_contract$
begin
  if not exists (
    select 1
    from public.activities activity
    join pg_temp.sitaa_0008_context fixture
      on activity.id=fixture.activity_scheduled
    where activity.academic_period_id=fixture.academic_period_id
      and activity.start_date=fixture.fixture_activity_date
  ) then
    raise exception '0008_verify_scheduled_academic_period_fixture_mismatch';
  end if;
end;
$scheduled_academic_period_contract$;

insert into public.activity_participants(activity_id,profile_id,participant_role_code,added_by)
select activity_scheduled,pg_temp.case_id('active_student'),'student',pg_temp.case_id('active_professor')
from sitaa_0008_context;

insert into public.activities(
  title,program_id,activity_type_code,service_type_code,attention_category_code,
  modality_code,status_code,location_type_code,location_detail,start_date,start_time,
  end_date,end_time,duration_mode,scope_type,division_id,responsible_profile_id,created_by
)
select 'Responsabilidad abierta para tipo',program_a,'group_activity','tutoring','disciplinary',
  'in_person','draft','classroom','Aula sintética',institutional_today+2,time '10:00',
  institutional_today+2,time '11:00','one_hour','program',division_a,
  pg_temp.case_id('target_open_responsible'),pg_temp.case_id('target_open_responsible')
from sitaa_0008_context
union all
select 'Responsabilidad abierta para programa',program_a,'group_activity','tutoring','disciplinary',
  'in_person','draft','classroom','Aula sintética',institutional_today+2,time '12:00',
  institutional_today+2,time '13:00','one_hour','program',division_a,
  pg_temp.case_id('target_program_responsible'),pg_temp.case_id('target_program_responsible')
from sitaa_0008_context
union all
select 'Participación abierta para programa',program_a,'group_activity','tutoring','disciplinary',
  'in_person','draft','classroom','Aula sintética',institutional_today+2,time '14:00',
  institutional_today+2,time '15:00','one_hour','program',division_a,
  pg_temp.case_id('active_professor'),pg_temp.case_id('active_professor')
from sitaa_0008_context;

insert into public.activity_participants(activity_id,profile_id,participant_role_code,added_by)
select a.id,pg_temp.case_id('target_program_participant'),'support',pg_temp.case_id('admin_exact')
from public.activities a where a.title='Participación abierta para programa';

-- Referencia histórica completada: no debe bloquear una corrección futura.
insert into public.activities(
  title,program_id,activity_type_code,service_type_code,attention_category_code,
  modality_code,status_code,location_type_code,location_detail,start_date,start_time,
  end_date,end_time,duration_mode,scope_type,division_id,responsible_profile_id,created_by
)
select 'Actividad histórica sintética',program_a,'group_activity','tutoring','disciplinary',
  'in_person','completed','classroom','Aula sintética',institutional_today-10,time '10:00',
  institutional_today-10,time '11:00','one_hour','program',division_a,
  pg_temp.case_id('target_history_only'),pg_temp.case_id('target_history_only')
from sitaa_0008_context;

-- Preservar instantáneas de objetos que la corrección nunca debe modificar.
create temporary table sitaa_0008_snapshots as
select 'roles'::text category,coalesce(jsonb_agg(to_jsonb(ra) order by ra.id),'[]'::jsonb) payload
from public.role_assignments ra
where ra.user_id in (
  pg_temp.case_id('target_institutional'),pg_temp.case_id('target_inactive'),
  pg_temp.case_id('target_technical'),pg_temp.case_id('target_current_role'),
  pg_temp.case_id('target_future_role'),pg_temp.case_id('target_historical_role'),
  pg_temp.case_id('target_program_dependency'),pg_temp.case_id('target_division_dependency'),
  pg_temp.case_id('target_open_responsible'),pg_temp.case_id('target_program_responsible'),
  pg_temp.case_id('target_program_participant'),pg_temp.case_id('target_history_only')
)
union all
select 'activities',coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]'::jsonb)
from public.activities a
where a.responsible_profile_id in (
  pg_temp.case_id('target_institutional'),pg_temp.case_id('target_inactive'),
  pg_temp.case_id('target_technical'),pg_temp.case_id('target_current_role'),
  pg_temp.case_id('target_future_role'),pg_temp.case_id('target_historical_role'),
  pg_temp.case_id('target_program_dependency'),pg_temp.case_id('target_division_dependency'),
  pg_temp.case_id('target_open_responsible'),pg_temp.case_id('target_program_responsible'),
  pg_temp.case_id('target_program_participant'),pg_temp.case_id('target_history_only')
)
union all
select 'participants',coalesce(jsonb_agg(to_jsonb(ap) order by ap.id),'[]'::jsonb)
from public.activity_participants ap
where ap.profile_id in (
  pg_temp.case_id('target_institutional'),pg_temp.case_id('target_inactive'),
  pg_temp.case_id('target_technical'),pg_temp.case_id('target_current_role'),
  pg_temp.case_id('target_future_role'),pg_temp.case_id('target_historical_role'),
  pg_temp.case_id('target_program_dependency'),pg_temp.case_id('target_division_dependency'),
  pg_temp.case_id('target_open_responsible'),pg_temp.case_id('target_program_responsible'),
  pg_temp.case_id('target_program_participant'),pg_temp.case_id('target_history_only')
);
grant select on table pg_temp.sitaa_0008_snapshots to authenticated;

-- Barrera operativa: usuario activo, invalidación inmediata y restauración.
select pg_temp.set_request_user('active_professor');
set local role authenticated;
do $active_contract$
begin
  if not public.is_sitaa_operational_account_active()
     or not exists(select 1 from public.activities)
     or not exists(select 1 from public.get_visible_activity_cards())
     or public.activity_attendance_deadline(
       (select activity_scheduled from pg_temp.sitaa_0008_context)
     ) is null then
    raise exception '0008_verify_active_operational_access_failed';
  end if;
end;
$active_contract$;
reset role;

update public.profiles
set account_status='inactive',is_active=false,deactivated_at=now()
where id=pg_temp.case_id('active_professor');

select pg_temp.set_request_user('active_professor');
set local role authenticated;
do $inactive_barrier$
declare
  before_roles jsonb;
  after_roles jsonb;
  affected integer;
  rejected boolean;
  state text;
begin
  select coalesce(jsonb_agg(to_jsonb(ra) order by ra.id),'[]'::jsonb)
  into before_roles from public.role_assignments ra
  where ra.user_id=pg_temp.case_id('active_professor');

  if public.is_sitaa_operational_account_active()
     or exists(select 1 from public.activities)
     or exists(select 1 from public.activity_participants)
     or exists(select 1 from public.get_visible_activity_cards())
     or exists(select 1 from public.get_activity_participants(
       (select activity_scheduled from pg_temp.sitaa_0008_context)
     ))
     or public.activity_attendance_deadline(
       (select activity_scheduled from pg_temp.sitaa_0008_context)
     ) is not null
     or public.can_edit_activity((select activity_scheduled from pg_temp.sitaa_0008_context)) then
    raise exception '0008_verify_inactive_read_barrier_failed';
  end if;

  update public.activities set title='No permitido'
  where id=(select activity_draft from pg_temp.sitaa_0008_context);
  get diagnostics affected=row_count;
  if affected<>0 then raise exception '0008_verify_inactive_activity_update_allowed'; end if;

  delete from public.activities
  where id=(select activity_draft from pg_temp.sitaa_0008_context);
  get diagnostics affected=row_count;
  if affected<>0 then raise exception '0008_verify_inactive_activity_delete_allowed'; end if;

  update public.activity_participants set attendance_notes='No permitido'
  where activity_id=(select activity_scheduled from pg_temp.sitaa_0008_context);
  get diagnostics affected=row_count;
  if affected<>0 then raise exception '0008_verify_inactive_participant_update_allowed'; end if;

  delete from public.activity_participants
  where activity_id=(select activity_scheduled from pg_temp.sitaa_0008_context);
  get diagnostics affected=row_count;
  if affected<>0 then raise exception '0008_verify_inactive_participant_delete_allowed'; end if;

  rejected:=false;
  begin
    insert into public.activities(
      title,responsible_profile_id,created_by,status_code,scope_type,
      program_id,division_id
    ) values(
      'Inserción no permitida',pg_temp.case_id('active_professor'),
      pg_temp.case_id('active_professor'),'draft','program',
      (select program_a from pg_temp.sitaa_0008_context),
      (select division_a from pg_temp.sitaa_0008_context)
    );
  exception when others then
    get stacked diagnostics state=returned_sqlstate;
    rejected:=state='42501';
  end;
  if not rejected then raise exception '0008_verify_inactive_activity_insert_allowed'; end if;

  rejected:=false;
  begin
    insert into public.activity_participants(
      activity_id,profile_id,participant_role_code,added_by
    ) values(
      (select activity_scheduled from pg_temp.sitaa_0008_context),
      pg_temp.case_id('active_professor'),'responsible',
      pg_temp.case_id('active_professor')
    );
  exception when others then
    get stacked diagnostics state=returned_sqlstate;
    rejected:=state='42501';
  end;
  if not rejected then raise exception '0008_verify_inactive_participant_insert_allowed'; end if;

  rejected:=false;
  begin
    perform public.add_activity_participant(
      (select activity_scheduled from pg_temp.sitaa_0008_context),
      pg_temp.case_id('active_student'),'student'
    );
  exception when others then
    get stacked diagnostics state=returned_sqlstate;
    rejected:=state='42501';
  end;
  if not rejected then raise exception '0008_verify_inactive_rpc_mutation_allowed'; end if;

  if (select count(*) from public.profiles where id=pg_temp.case_id('active_professor'))<>1
     or (select count(*) from public.role_assignments
         where user_id=pg_temp.case_id('active_professor'))<1 then
    raise exception '0008_verify_account_status_lookup_broken';
  end if;

  select coalesce(jsonb_agg(to_jsonb(ra) order by ra.id),'[]'::jsonb)
  into after_roles from public.role_assignments ra
  where ra.user_id=pg_temp.case_id('active_professor');
  if before_roles is distinct from after_roles then
    raise exception '0008_verify_barrier_changed_roles';
  end if;
end;
$inactive_barrier$;
reset role;

update public.profiles
set account_status='active',is_active=true,deactivated_at=null
where id=pg_temp.case_id('active_professor');

select pg_temp.set_request_user('active_professor');
set local role authenticated;
do $reactivation_fixture$
begin
  if not public.is_sitaa_operational_account_active()
     or not exists(select 1 from public.activities)
     or not exists(select 1 from public.get_visible_activity_cards()) then
    raise exception '0008_verify_fixture_reactivation_failed';
  end if;
end;
$reactivation_fixture$;
reset role;

-- Pendiente: mismo cierre operativo; administrador exacto: A-02 preservado.
select pg_temp.set_request_user('pending_user');
set local role authenticated;
do $pending_barrier$
begin
  if public.is_sitaa_operational_account_active()
     or exists(select 1 from public.activities)
     or exists(select 1 from public.activity_participants)
     or exists(select 1 from public.get_visible_activity_cards()) then
    raise exception '0008_verify_pending_barrier_failed';
  end if;
end;
$pending_barrier$;
reset role;

select pg_temp.set_request_user('admin_exact');
set local role authenticated;
do $admin_a02_and_b1$
begin
  if not public.is_sitaa_operational_account_active()
     or not public.is_b1_account_admin()
     or not exists(select 1 from public.get_visible_activity_cards())
     or not exists(select 1 from public.get_admin_account_detail_b1(pg_temp.case_id('target_institutional'))) then
    raise exception '0008_verify_active_admin_regression';
  end if;
end;
$admin_a02_and_b1$;
reset role;

select pg_temp.set_request_user('admin_bad_scope');
set local role authenticated;
do $malformed_admin$
declare rejected boolean:=false; state text;
begin
  if public.is_b1_account_admin() then raise exception '0008_verify_malformed_admin_accepted'; end if;
  begin
    perform public.get_admin_identity_correction_context_b2a(pg_temp.case_id('target_institutional'));
  exception when others then
    get stacked diagnostics state=returned_sqlstate;
    rejected:=state='42501';
  end;
  if not rejected then raise exception '0008_verify_malformed_admin_context_allowed'; end if;

  rejected:=false;
  begin
    perform public.correct_admin_account_identity_b2a(
      pg_temp.case_id('target_institutional'),'Persona','Prueba',null,
      'student','0008000024',(select program_a from pg_temp.sitaa_0008_context),
      'Razón administrativa válida'
    );
  exception when others then
    get stacked diagnostics state=returned_sqlstate;
    rejected:=state='42501';
  end;
  if not rejected then raise exception '0008_verify_malformed_admin_mutation_allowed'; end if;
end;
$malformed_admin$;
reset role;

-- Privacidad: estudiante participante ve sólo su actividad publicada, nunca el borrador.
select pg_temp.set_request_user('active_student');
set local role authenticated;
do $privacy_regression$
begin
  if exists(
       select 1 from public.get_visible_activity_cards()
       where id=(select activity_draft from pg_temp.sitaa_0008_context)
     )
     or not exists(
       select 1 from public.get_visible_activity_cards()
       where id=(select activity_scheduled from pg_temp.sitaa_0008_context)
     )
     or exists(
       select 1 from public.get_activity_participants(
         (select activity_scheduled from pg_temp.sitaa_0008_context)
       )
     ) then
    raise exception '0008_verify_draft_or_participant_privacy_regression';
  end if;
  if not exists(select 1 from public.activity_types where code='group_activity') then
    raise exception '0008_verify_reference_catalog_regression';
  end if;
end;
$privacy_regression$;
reset role;

-- La finalización Google pendiente permanece disponible bajo su contrato existente.
create function pg_temp.insert_google_identity(target_label text)
returns void language plpgsql
set search_path=auth,pg_temp,pg_catalog,information_schema
as $$
declare
  target_id uuid:=pg_temp.case_id(target_label);
  provider_key text:='google-'||target_label||'-0008';
  payload jsonb:=jsonb_build_object(
    'sub',provider_key,'email',pg_temp.case_email(target_label),'email_verified',true
  );
begin
  if exists(select 1 from information_schema.columns
      where table_schema='auth' and table_name='identities' and column_name='provider_id') then
    execute 'insert into auth.identities(provider_id,user_id,identity_data,provider,last_sign_in_at,created_at,updated_at) values($1,$2,$3,''google'',now(),now(),now())'
      using provider_key,target_id,payload;
  else
    execute 'insert into auth.identities(id,user_id,identity_data,provider,last_sign_in_at,created_at,updated_at) values($1,$2,$3,''google'',now(),now(),now())'
      using provider_key,target_id,payload;
  end if;
end;
$$;
select pg_temp.insert_google_identity('google_pending');
select pg_temp.set_request_user('google_pending');
set local role authenticated;
select public.complete_own_google_registration(
  'student','Persona','Pendiente',null,'0008000001',
  (select program_a from pg_temp.sitaa_0008_context)
);
reset role;
do $pending_completion_preserved$
begin
  if not exists(
    select 1 from public.profiles
    where id=pg_temp.case_id('google_pending')
      and account_status='active' and is_active
  ) then
    raise exception '0008_verify_google_completion_regression';
  end if;
end;
$pending_completion_preserved$;

-- Helper de rechazo: invoca como authenticated y compara la proyección B.1 antes/después.
create function pg_temp.expect_correction_rejection(
  target_label text,
  requested_first text,
  requested_paternal text,
  requested_maternal text,
  requested_person text,
  requested_identifier text,
  requested_program uuid,
  requested_reason text,
  expected_fragment text
)
returns void language plpgsql
set search_path=public,pg_temp,pg_catalog
as $$
declare
  before_detail jsonb;
  after_detail jsonb;
  audit_before bigint;
  audit_after bigint;
  rejected boolean:=false;
  actual_message text;
begin
  select to_jsonb(detail) into before_detail
  from public.get_admin_account_detail_b1(pg_temp.case_id(target_label)) detail;
  select count(*) into audit_before
  from public.get_admin_account_audit_history_b1(pg_temp.case_id(target_label),50,0);

  begin
    perform public.correct_admin_account_identity_b2a(
      pg_temp.case_id(target_label),requested_first,requested_paternal,requested_maternal,
      requested_person,requested_identifier,requested_program,requested_reason
    );
  exception when others then
    rejected:=true;
    get stacked diagnostics actual_message=message_text;
  end;

  if not rejected or position(expected_fragment in coalesce(actual_message,''))=0 then
    raise exception '0008_verify_unexpected_rejection_contract';
  end if;
  if actual_message ~* '(check constraint|profiles_[a-z0-9_]*_check)' then
    raise exception '0008_verify_raw_constraint_error_leaked';
  end if;

  select to_jsonb(detail) into after_detail
  from public.get_admin_account_detail_b1(pg_temp.case_id(target_label)) detail;
  select count(*) into audit_after
  from public.get_admin_account_audit_history_b1(pg_temp.case_id(target_label),50,0);
  if before_detail is distinct from after_detail or audit_before<>audit_after then
    raise exception '0008_verify_rejected_correction_not_atomic';
  end if;
end;
$$;
grant execute on function pg_temp.expect_correction_rejection(
  text,text,text,text,text,text,uuid,text,text
) to authenticated;

-- Contexto autoriza antes de consultar objetivo y entrega sólo agregados.
select pg_temp.set_request_user('active_student');
set local role authenticated;
do $unauthorized_indistinguishable$
declare
  state_existing text;
  state_missing text;
begin
  begin
    perform public.get_admin_identity_correction_context_b2a(pg_temp.case_id('target_institutional'));
  exception when others then get stacked diagnostics state_existing=returned_sqlstate; end;
  begin
    perform public.get_admin_identity_correction_context_b2a(gen_random_uuid());
  exception when others then get stacked diagnostics state_missing=returned_sqlstate; end;
  if state_existing<>'42501' or state_missing<>'42501' then
    raise exception '0008_verify_context_target_disclosure';
  end if;
end;
$unauthorized_indistinguishable$;
reset role;

select pg_temp.set_request_user('admin_inactive');
set local role authenticated;
do $inactive_admin_denied$
declare state text;
begin
  begin
    perform public.get_admin_identity_correction_context_b2a(pg_temp.case_id('target_institutional'));
  exception when others then get stacked diagnostics state=returned_sqlstate; end;
  if state<>'42501' then raise exception '0008_verify_inactive_admin_allowed'; end if;
end;
$inactive_admin_denied$;
reset role;

select pg_temp.set_request_user('admin_exact');
set local role authenticated;
do $context_contract$
declare
  row_count integer;
begin
  if not exists(
       select 1 from public.get_admin_identity_correction_context_b2a(
         pg_temp.case_id('target_institutional')
       ) where can_correct and account_kind='institutional' and account_status='active'
         and not is_self
     )
     or not exists(
       select 1 from public.get_admin_identity_correction_context_b2a(
         pg_temp.case_id('target_inactive')
       ) where can_correct and account_status='inactive'
     )
     or not exists(
       select 1 from public.get_admin_identity_correction_context_b2a(
         pg_temp.case_id('target_technical')
       ) where can_correct and account_kind='technical'
     )
     or not exists(
       select 1 from public.get_admin_identity_correction_context_b2a(
         pg_temp.case_id('target_pending')
       ) where not can_correct and denial_code='pending_target'
     )
     or not exists(
       select 1 from public.get_admin_identity_correction_context_b2a(
         pg_temp.case_id('admin_exact')
       ) where not can_correct and denial_code='self_target'
     ) then
    raise exception '0008_verify_context_eligibility_mismatch';
  end if;

  select count(*) into row_count
  from public.get_admin_identity_correction_context_b2a(gen_random_uuid());
  if row_count<>0 then raise exception '0008_verify_context_missing_target_disclosed'; end if;

  if not exists(
    select 1 from public.get_admin_identity_correction_context_b2a(
      pg_temp.case_id('target_current_role')
    ) where current_or_future_assignment_count=1
  ) then raise exception '0008_verify_context_dependency_count_mismatch'; end if;
end;
$context_contract$;

-- Rechazos controlados y atómicos.
select pg_temp.expect_correction_rejection(
  'admin_exact','Soporte','Propio',null,null,null,null,
  'Razón administrativa válida','sitaa_identity_self_correction_forbidden'
);
select pg_temp.expect_correction_rejection(
  'target_pending','Persona','Pendiente',null,'student','0008000002',
  (select program_a from pg_temp.sitaa_0008_context),
  'Razón administrativa válida','sitaa_identity_pending_target'
);
select pg_temp.expect_correction_rejection(
  'target_institutional',null,'Prueba',null,'student','0008000003',
  (select program_a from pg_temp.sitaa_0008_context),
  'Razón administrativa válida','sitaa_identity_invalid_name'
);
select pg_temp.expect_correction_rejection(
  'target_institutional','Persona','Prueba',null,null,'0008000003',
  (select program_a from pg_temp.sitaa_0008_context),
  'Razón administrativa válida','sitaa_identity_invalid_person_type'
);
select pg_temp.expect_correction_rejection(
  'target_technical','X',null,null,null,null,null,
  'Razón administrativa válida','sitaa_identity_invalid_name'
);
select pg_temp.expect_correction_rejection(
  'target_institutional',E'\n\t  ',E'\n Prueba\t',null,'student','0008000003',
  (select program_a from pg_temp.sitaa_0008_context),
  'Razón administrativa válida','sitaa_identity_invalid_name'
);
select pg_temp.expect_correction_rejection(
  'target_institutional','Persona','Prueba',null,'student','ABC',
  (select program_a from pg_temp.sitaa_0008_context),
  'Razón administrativa válida','sitaa_identity_invalid_identifier'
);
select pg_temp.expect_correction_rejection(
  'target_institutional','Persona','Prueba',null,'student',
  pg_temp.case_identifier('duplicate_holder'),
  (select program_a from pg_temp.sitaa_0008_context),
  'Razón administrativa válida','sitaa_identity_duplicate_identifier'
);
select pg_temp.expect_correction_rejection(
  'target_institutional','Persona','Prueba',null,'student','0008000004',
  (select inactive_program from pg_temp.sitaa_0008_context),
  'Razón administrativa válida','sitaa_identity_invalid_program'
);
select pg_temp.expect_correction_rejection(
  'target_technical','Soporte','Prueba',null,'student','0008000005',
  (select program_a from pg_temp.sitaa_0008_context),
  'Razón administrativa válida','sitaa_identity_technical_fields_forbidden'
);
select pg_temp.expect_correction_rejection(
  'target_institutional','Persona',null,null,'student','0008000006',
  (select program_a from pg_temp.sitaa_0008_context),
  'Razón administrativa válida','sitaa_identity_invalid_name'
);
select pg_temp.expect_correction_rejection(
  'target_institutional',E'\n  Persona\t sintética  \n',E'\t Prueba \n',null,'student',
  pg_temp.case_identifier('target_institutional'),
  (select program_a from pg_temp.sitaa_0008_context),
  'Razón administrativa válida','sitaa_identity_no_changes'
);
select pg_temp.expect_correction_rejection(
  'target_institutional','Persona','Prueba',null,'student','0008000007',
  (select program_a from pg_temp.sitaa_0008_context),
  'corta','sitaa_identity_invalid_reason'
);
select pg_temp.expect_correction_rejection(
  'target_institutional','Persona','Prueba',null,'student','0008000020',
  (select program_a from pg_temp.sitaa_0008_context),
  null,'sitaa_identity_invalid_reason'
);
select pg_temp.expect_correction_rejection(
  'target_institutional','Persona','Prueba',null,'student','0008000021',
  (select program_a from pg_temp.sitaa_0008_context),
  '   ','sitaa_identity_invalid_reason'
);
select pg_temp.expect_correction_rejection(
  'target_institutional','Persona','Prueba',null,'student','0008000022',
  (select program_a from pg_temp.sitaa_0008_context),
  repeat('x',1001),'sitaa_identity_invalid_reason'
);
select pg_temp.expect_correction_rejection(
  'target_current_role','Persona','Prueba',null,'professor','0008000008',
  (select program_a from pg_temp.sitaa_0008_context),
  'Razón administrativa válida','sitaa_identity_person_type_dependency'
);
select pg_temp.expect_correction_rejection(
  'target_future_role','Persona','Prueba',null,'professor','0008000009',
  (select program_a from pg_temp.sitaa_0008_context),
  'Razón administrativa válida','sitaa_identity_person_type_dependency'
);
select pg_temp.expect_correction_rejection(
  'target_program_dependency','Persona','Prueba',null,'professor','0008000010',
  (select program_b from pg_temp.sitaa_0008_context),
  'Razón administrativa válida','sitaa_identity_program_dependency'
);
select pg_temp.expect_correction_rejection(
  'target_division_dependency','Persona','Prueba',null,'professor','0008000016',
  (select program_b from pg_temp.sitaa_0008_context),
  'Razón administrativa válida','sitaa_identity_program_dependency'
);
select pg_temp.expect_correction_rejection(
  'target_open_responsible','Persona','Prueba',null,'student','0008000017',
  (select program_a from pg_temp.sitaa_0008_context),
  'Razón administrativa válida','sitaa_identity_person_type_dependency'
);
select pg_temp.expect_correction_rejection(
  'target_program_responsible','Persona','Prueba',null,'professor','0008000018',
  (select program_b from pg_temp.sitaa_0008_context),
  'Razón administrativa válida','sitaa_identity_program_dependency'
);
select pg_temp.expect_correction_rejection(
  'target_program_participant','Persona','Prueba',null,'professor','0008000019',
  (select program_b from pg_temp.sitaa_0008_context),
  'Razón administrativa válida','sitaa_identity_program_dependency'
);

do $missing_target_mutation$
declare actual_message text;
begin
  begin
    perform public.correct_admin_account_identity_b2a(
      gen_random_uuid(),'Persona','Inexistente',null,'student','0008000023',
      (select program_a from pg_temp.sitaa_0008_context),
      'Razón administrativa válida'
    );
  exception when others then get stacked diagnostics actual_message=message_text; end;
  if position('sitaa_identity_target_unavailable' in coalesce(actual_message,''))=0 then
    raise exception '0008_verify_missing_target_contract';
  end if;
end;
$missing_target_mutation$;

-- Éxitos: institucional, técnico, inactivo, histórico y cambios no bloqueados.
select * from public.correct_admin_account_identity_b2a(
  pg_temp.case_id('target_institutional'),E'\n  María\t  José  \n',E'\tD''Ángelo\n',E' López\t',
  'student','0008000011',(select program_b from pg_temp.sitaa_0008_context),
  E'\n  Corrección\t  verificada   con fuente institucional  \n'
);
select * from public.correct_admin_account_identity_b2a(
  pg_temp.case_id('target_technical'),'Soporte','Técnico',null,
  null,null,null,'Corrección técnica verificada'
);
select * from public.correct_admin_account_identity_b2a(
  pg_temp.case_id('target_inactive'),'Cuenta','Inactiva','Corregida',
  'professor','0008000012',(select program_a from pg_temp.sitaa_0008_context),
  'Corrección de identidad inactiva'
);
select * from public.correct_admin_account_identity_b2a(
  pg_temp.case_id('target_historical_role'),'Histórica','Persona',null,
  'professor','0008000013',(select program_a from pg_temp.sitaa_0008_context),
  'Cambio permitido por asignación vencida'
);
select * from public.correct_admin_account_identity_b2a(
  pg_temp.case_id('target_history_only'),'Historial','Conservado',null,
  'student','0008000014',(select program_b from pg_temp.sitaa_0008_context),
  'Cambio permitido por actividad histórica'
);
select * from public.correct_admin_account_identity_b2a(
  pg_temp.case_id('target_current_role'),'Nombre','Corregido',null,
  'student',pg_temp.case_identifier('target_current_role'),
  (select program_a from pg_temp.sitaa_0008_context),
  'Corrección de nombre sin alterar dependencias'
);
select * from public.correct_admin_account_identity_b2a(
  pg_temp.case_id('target_current_role'),'Nombre','Corregido',null,
  'student','0008000015',(select program_a from pg_temp.sitaa_0008_context),
  'Corrección de identificador sin alterar dependencias'
);

do $successful_corrections$
declare
  event_count bigint;
  metadata_value jsonb;
begin
  if not exists(
       select 1 from public.profiles
       where id=pg_temp.case_id('target_institutional')
         and first_names='María José' and paternal_surname='D''Ángelo'
         and maternal_surname='López' and full_name='María José D''Ángelo López'
         and person_type='student' and institutional_id_type='student_account'
         and institutional_id_value='0008000011'
         and primary_program_id=(select program_b from pg_temp.sitaa_0008_context)
     ) then
    raise exception '0008_verify_institutional_correction_failed';
  end if;

  if not exists(
       select 1 from public.profiles
       where id=pg_temp.case_id('target_technical')
         and first_names='Soporte' and paternal_surname='Técnico'
         and person_type is null and institutional_id_type is null
         and institutional_id_value is null and primary_program_id is null
     ) then
    raise exception '0008_verify_technical_correction_failed';
  end if;

  if not exists(
       select 1 from public.profiles
       where id=pg_temp.case_id('target_inactive')
         and account_status='inactive' and not is_active
         and deactivated_at is not null
     ) then
    raise exception '0008_verify_inactive_lifecycle_changed';
  end if;

  select count(*) into event_count
  from public.admin_audit_events
  where action_code='account_identity_corrected'
    and target_profile_id=pg_temp.case_id('target_institutional');
  if event_count<>1 then raise exception '0008_verify_audit_event_count'; end if;

  select metadata into metadata_value
  from public.admin_audit_events
  where action_code='account_identity_corrected'
    and target_profile_id=pg_temp.case_id('target_institutional');

  if metadata_value<>jsonb_build_object(
       'changed_fields',
       to_jsonb(array[
         'first_names','institutional_id_value','maternal_surname',
         'paternal_surname','primary_program_id'
       ]::text[])
     )
     or metadata_value ?| array[
       'email','old_value','new_value','institutional_id_value','role','activity'
     ] then
    raise exception '0008_verify_audit_metadata_not_minimal';
  end if;

  if not exists(
       select 1 from public.admin_audit_events
       where target_profile_id=pg_temp.case_id('target_institutional')
         and actor_profile_id=pg_temp.case_id('admin_exact')
         and action_code='account_identity_corrected' and outcome='success'
         and reason='Corrección verificada con fuente institucional'
         and role_assignment_id is null
     ) then
    raise exception '0008_verify_audit_contract_mismatch';
  end if;

  if not exists(
       select 1 from public.get_admin_account_audit_history_b1(
         pg_temp.case_id('target_institutional'),50,0
       ) where action_code='account_identity_corrected'
         and outcome='success'
         and reason='Corrección verificada con fuente institucional'
     ) then
    raise exception '0008_verify_b1_sanitized_history_regression';
  end if;
end;
$successful_corrections$;
reset role;

-- El RPC directo sigue denegado para usuarios ordinarios.
select pg_temp.set_request_user('active_student');
set local role authenticated;
do $ordinary_mutation_denied$
declare state text;
begin
  begin
    perform public.correct_admin_account_identity_b2a(
      pg_temp.case_id('target_institutional'),'Otro','Nombre',null,
      'student','0008000016',(select program_b from pg_temp.sitaa_0008_context),
      'Razón administrativa válida'
    );
  exception when others then get stacked diagnostics state=returned_sqlstate; end;
  if state<>'42501' then raise exception '0008_verify_ordinary_mutation_allowed'; end if;
end;
$ordinary_mutation_denied$;
reset role;

-- Integridad final: dependencias, Auth, historia y auditoría append-only.
do $preservation_contract$
declare
  current_payload jsonb;
  old_email text;
  old_auth_count bigint;
  rejected boolean:=false;
begin
  select payload into current_payload from sitaa_0008_snapshots where category='roles';
  if current_payload is distinct from (
    select coalesce(jsonb_agg(to_jsonb(ra) order by ra.id),'[]'::jsonb)
    from public.role_assignments ra
    where ra.user_id in (
      pg_temp.case_id('target_institutional'),pg_temp.case_id('target_inactive'),
      pg_temp.case_id('target_technical'),pg_temp.case_id('target_current_role'),
      pg_temp.case_id('target_future_role'),pg_temp.case_id('target_historical_role'),
      pg_temp.case_id('target_program_dependency'),pg_temp.case_id('target_division_dependency'),
      pg_temp.case_id('target_open_responsible'),pg_temp.case_id('target_program_responsible'),
      pg_temp.case_id('target_program_participant'),pg_temp.case_id('target_history_only')
    )
  ) then raise exception '0008_verify_roles_changed'; end if;

  select payload into current_payload from sitaa_0008_snapshots where category='activities';
  if current_payload is distinct from (
    select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]'::jsonb)
    from public.activities a
    where a.responsible_profile_id in (
      pg_temp.case_id('target_institutional'),pg_temp.case_id('target_inactive'),
      pg_temp.case_id('target_technical'),pg_temp.case_id('target_current_role'),
      pg_temp.case_id('target_future_role'),pg_temp.case_id('target_historical_role'),
      pg_temp.case_id('target_program_dependency'),pg_temp.case_id('target_division_dependency'),
      pg_temp.case_id('target_open_responsible'),pg_temp.case_id('target_program_responsible'),
      pg_temp.case_id('target_program_participant'),pg_temp.case_id('target_history_only')
    )
  ) then raise exception '0008_verify_activities_changed'; end if;

  select payload into current_payload from sitaa_0008_snapshots where category='participants';
  if current_payload is distinct from (
    select coalesce(jsonb_agg(to_jsonb(ap) order by ap.id),'[]'::jsonb)
    from public.activity_participants ap
    where ap.profile_id in (
      pg_temp.case_id('target_institutional'),pg_temp.case_id('target_inactive'),
      pg_temp.case_id('target_technical'),pg_temp.case_id('target_current_role'),
      pg_temp.case_id('target_future_role'),pg_temp.case_id('target_historical_role'),
      pg_temp.case_id('target_program_dependency'),pg_temp.case_id('target_division_dependency'),
      pg_temp.case_id('target_open_responsible'),pg_temp.case_id('target_program_responsible'),
      pg_temp.case_id('target_program_participant'),pg_temp.case_id('target_history_only')
    )
  ) then raise exception '0008_verify_participants_changed'; end if;

  select email into old_email from public.profiles where id=pg_temp.case_id('target_institutional');
  select count(*) into old_auth_count from auth.users where id=pg_temp.case_id('target_institutional');
  if old_email<>pg_temp.case_email('target_institutional') or old_auth_count<>1 then
    raise exception '0008_verify_auth_link_or_email_changed';
  end if;

  begin
    update public.admin_audit_events set outcome='failure'
    where action_code='account_identity_corrected'
      and target_profile_id=pg_temp.case_id('target_institutional');
  exception when others then rejected:=true; end;
  if not rejected then raise exception '0008_verify_audit_not_append_only'; end if;
end;
$preservation_contract$;

-- El ROLLBACK elimina fixtures, concesiones temporales y todos los cambios.
rollback;
