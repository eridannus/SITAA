-- 0008_operational_account_barrier_identity_correction.sql
-- Fase B.2a: barrera operativa de cuenta activa y corrección administrativa auditada.
-- Preparada localmente. Requiere revisión; no ejecutar automáticamente en producción.

begin;

-- Preflight bloqueante post-0007. No devuelve PII ni filas operativas.
do $preflight$
declare
  mismatch_count integer;
begin
  if (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relkind='r') <> 18
     or (select count(*) from information_schema.columns where table_schema='public') <> 165
     or (select count(*) from pg_constraint c join pg_namespace n on n.oid=c.connamespace
         where n.nspname='public' and c.contype in ('p','f','u','c')) <> 80
     or (select count(*) from pg_indexes where schemaname='public') <> 43
     or (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid
         join pg_namespace n on n.oid=c.relnamespace
         where n.nspname='public' and not t.tgisinternal) <> 10
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public') <> 47
     or (select count(*) from pg_policies where schemaname='public') <> 23 then
    raise exception '0008_preflight_inventory_mismatch';
  end if;

  with expected(signature) as (
    values
      ('activity_attendance_deadline(uuid)'),
      ('activity_attendance_open_at(uuid)'),
      ('activity_has_ended(uuid)'),
      ('add_activity_participant(uuid,uuid,text)'),
      ('admin_audit_metadata_is_safe(jsonb)'),
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
      ('complete_own_google_registration(text,text,text,text,text,uuid)'),
      ('complete_own_google_registration(text,text,text,uuid)'),
      ('enforce_sitaa_profile_identity()'),
      ('finalize_expired_attendance()'),
      ('generate_three_word_code()'),
      ('get_academic_period_for_date(date)'),
      ('get_active_activity_attendance_checkin(uuid)'),
      ('get_activity_attendance_checkin_state(uuid)'),
      ('get_activity_participants(uuid)'),
      ('get_admin_account_assignments_b1(uuid)'),
      ('get_admin_account_audit_history_b1(uuid,integer,integer)'),
      ('get_admin_account_detail_b1(uuid)'),
      ('get_visible_activity_cards()'),
      ('guard_activity_participant_pending_deadline()'),
      ('handle_sitaa_auth_user_created()'),
      ('has_active_role(text)'),
      ('has_any_active_role(text[])'),
      ('is_activity_participant(uuid)'),
      ('is_b1_account_admin()'),
      ('normalize_sitaa_profile_names()'),
      ('open_activity_attendance_checkin(uuid)'),
      ('prevent_admin_audit_event_mutation()'),
      ('publish_activity(uuid)'),
      ('remove_activity_participant(uuid)'),
      ('search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)'),
      ('search_profiles_for_participation(uuid,text)'),
      ('set_updated_at()'),
      ('sitaa_current_mexico_date()'),
      ('sync_sitaa_profile_email_from_auth()'),
      ('update_activity_participant_attendance(uuid,text,text)'),
      ('update_activity_participants_attendance_bulk(uuid,uuid[],text,text)'),
      ('validate_activity_scheduled_state()')
  ), actual(signature) as (
    select p.oid::regprocedure::text
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
  )
  select count(*) into mismatch_count
  from (
    (select signature from expected except select signature from actual)
    union all
    (select signature from actual except select signature from expected)
  ) differences;
  if mismatch_count <> 0 then
    raise exception '0008_preflight_function_signature_drift';
  end if;

  with expected(signature,body_hash) as (
    values
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
  )
  select count(*) into mismatch_count
  from expected e
  left join pg_proc p on p.oid=to_regprocedure('public.'||e.signature)
  left join pg_language l on l.oid=p.prolang
  where p.oid is null
     or p.prosecdef is not true
     or p.proconfig is distinct from array['search_path=public']::text[]
     or l.lanname not in ('sql','plpgsql')
     or md5(btrim(regexp_replace(lower(p.prosrc),'\s+',' ','g')))<>e.body_hash;
  if mismatch_count<>0 then
    raise exception '0008_preflight_operational_function_drift';
  end if;

  select count(*) into mismatch_count
  from (
    select e.signature
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
    ) e(signature)
    join pg_proc p on p.oid=to_regprocedure('public.'||e.signature)
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
    )
  ) acl_drift;
  if mismatch_count<>0 then
    raise exception '0008_preflight_operational_acl_drift';
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
    raise exception '0008_preflight_conflicting_objects';
  end if;

  if to_regprocedure('public.is_b1_account_admin()') is null
     or to_regprocedure('public.sitaa_current_mexico_date()') is null
     or to_regclass('public.admin_audit_events') is null
     or not exists(select 1 from pg_roles where rolname='service_role' and rolbypassrls) then
    raise exception '0008_preflight_b1_contract_unavailable';
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
    raise exception '0008_preflight_required_rls_disabled';
  end if;

  if exists (
       select 1 from public.profiles p left join auth.users u on u.id=p.id
       where u.id is null
     )
     or exists (
       select 1 from auth.users u left join public.profiles p on p.id=u.id
       where p.id is null
     ) then
    raise exception '0008_preflight_auth_profile_one_to_one_inconsistent';
  end if;

  if not exists (
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
    raise exception '0008_preflight_profile_assignment_fk_drift';
  end if;

  if exists (
    select 1 from public.profiles p
    where (p.account_status='active' and (not p.is_active or p.activated_at is null or p.deactivated_at is not null))
       or (p.account_status='pending_registration' and (p.is_active or p.activated_at is not null or p.deactivated_at is not null))
       or (p.account_status='inactive' and (p.is_active or p.deactivated_at is null))
  ) then
    raise exception '0008_preflight_profile_lifecycle_inconsistent';
  end if;

  if exists (
    select 1 from public.profiles p
    left join public.academic_programs ap on ap.id=p.primary_program_id
    where p.account_kind='institutional'
      and p.account_status in ('active','inactive')
      and (
        p.first_names is null or p.paternal_surname is null
        or p.full_name is null or char_length(p.full_name) not between 2 and 200
        or p.full_name<>concat_ws(' ',p.first_names,p.paternal_surname,p.maternal_surname)
        or p.person_type not in ('student','professor')
        or p.institutional_id_value is null
        or p.institutional_id_value !~ '^[0-9]{1,50}$'
        or ap.id is null or not ap.is_active
        or (p.person_type='student' and p.institutional_id_type<>'student_account')
        or (p.person_type='professor' and p.institutional_id_type<>'worker_number')
      )
  ) then
    raise exception '0008_preflight_institutional_identity_inconsistent';
  end if;

  if exists (
    select 1 from public.profiles p
    where p.account_kind='technical'
      and p.account_status in ('active','inactive')
      and (
        p.first_names is null
        or p.full_name is null or char_length(p.full_name) not between 2 and 200
        or p.full_name<>concat_ws(' ',p.first_names,p.paternal_surname,p.maternal_surname)
        or p.person_type is not null or p.primary_program_id is not null
        or p.institutional_id_type is not null or p.institutional_id_value is not null
      )
  ) then
    raise exception '0008_preflight_technical_identity_inconsistent';
  end if;

  if not has_table_privilege('authenticated','public.activities','SELECT,INSERT,UPDATE,DELETE')
     or not has_table_privilege('authenticated','public.activity_participants','SELECT,INSERT,UPDATE,DELETE')
     or has_table_privilege('authenticated','public.activity_checkin_tokens','SELECT')
     or has_table_privilege('authenticated','public.activity_checkin_tokens','INSERT')
     or has_table_privilege('authenticated','public.activity_checkin_tokens','UPDATE')
     or has_table_privilege('authenticated','public.activity_checkin_tokens','DELETE')
     or not has_table_privilege('authenticated','public.profiles','SELECT')
     or not has_table_privilege('authenticated','public.role_assignments','SELECT') then
    raise exception '0008_preflight_client_grant_drift';
  end if;

  if exists (
       select 1
       from public.activity_participants participant
       join public.activities activity on activity.id=participant.activity_id
       join public.profiles profile on profile.id=participant.profile_id
       left join public.academic_programs program on program.id=profile.primary_program_id
       where profile.primary_program_id is null
          or (activity.scope_type='program'
            and profile.primary_program_id is distinct from activity.program_id)
          or (activity.scope_type='division'
            and program.division_id is distinct from activity.division_id)
          or (participant.participant_role_code='responsible'
            and profile.person_type is distinct from 'professor')
     ) then
    raise exception '0008_preflight_existing_participant_identity_incompatible';
  end if;

  if not exists (
       select 1 from pg_policies where schemaname='public' and tablename='profiles'
       and policyname='Users can read own profile' and cmd='SELECT'
       and permissive='PERMISSIVE' and roles='{authenticated}'
       and qual='(auth.uid() = id)'
     )
     or not exists (
       select 1 from pg_policies where schemaname='public' and tablename='profiles'
       and policyname='Users can update own basic profile' and cmd='UPDATE'
       and permissive='PERMISSIVE' and roles='{authenticated}'
       and qual='(auth.uid() = id)' and with_check='(auth.uid() = id)'
     )
     or not exists (
       select 1 from pg_policies where schemaname='public' and tablename='role_assignments'
       and policyname='Users can read own role assignments' and cmd='SELECT'
       and permissive='PERMISSIVE' and roles='{authenticated}'
       and qual='(auth.uid() = user_id)'
     )
     or (select count(*) from pg_policies where schemaname='public' and tablename='profiles')<>2
     or (select count(*) from pg_policies where schemaname='public' and tablename='role_assignments')<>1
     or (select count(*) from pg_policies where schemaname='public' and tablename='activities')<>4
     or (select count(*) from pg_policies where schemaname='public' and tablename='activity_participants')<>4 then
    raise exception '0008_preflight_policy_drift';
  end if;

  if not exists(select 1 from pg_policies where schemaname='public' and tablename='activities'
       and policyname='Authorized users can create activities' and permissive='PERMISSIVE'
       and roles='{authenticated}' and cmd='INSERT'
       and with_check='((created_by = auth.uid()) AND can_create_activity(scope_type, program_id, division_id, service_type_code))')
     or not exists(select 1 from pg_policies where schemaname='public' and tablename='activities'
       and policyname='Authorized users can delete activities' and permissive='PERMISSIVE'
       and roles='{authenticated}' and cmd='DELETE' and qual='can_delete_activity(id)')
     or not exists(select 1 from pg_policies where schemaname='public' and tablename='activities'
       and policyname='Authorized users can update activities' and permissive='PERMISSIVE'
       and roles='{authenticated}' and cmd='UPDATE'
       and qual='can_update_activity_base(id)' and with_check='can_update_activity_base(id)')
     or not exists(select 1 from pg_policies where schemaname='public' and tablename='activities'
       and policyname='Users can read permitted activities' and permissive='PERMISSIVE'
       and roles='{authenticated}' and cmd='SELECT'
       and qual='(((status_code = ''draft''::text) AND (created_by = auth.uid())) OR ((status_code <> ''draft''::text) AND ((created_by = auth.uid()) OR (responsible_profile_id = auth.uid()) OR is_activity_participant(id) OR can_manage_activity(scope_type, program_id, division_id, service_type_code))))')
     or not exists(select 1 from pg_policies where schemaname='public' and tablename='activity_participants'
       and policyname='Users can add permitted activity participants' and permissive='PERMISSIVE'
       and roles='{authenticated}' and cmd='INSERT' and with_check='can_edit_activity(activity_id)')
     or not exists(select 1 from pg_policies where schemaname='public' and tablename='activity_participants'
       and policyname='Users can delete permitted activity participants' and permissive='PERMISSIVE'
       and roles='{authenticated}' and cmd='DELETE' and qual='can_edit_activity(activity_id)')
     or not exists(select 1 from pg_policies where schemaname='public' and tablename='activity_participants'
       and policyname='Users can read permitted activity participants' and permissive='PERMISSIVE'
       and roles='{authenticated}' and cmd='SELECT'
       and qual='((profile_id = auth.uid()) OR can_read_activity(activity_id))')
     or not exists(select 1 from pg_policies where schemaname='public' and tablename='activity_participants'
       and policyname='Users can update permitted activity participants' and permissive='PERMISSIVE'
       and roles='{authenticated}' and cmd='UPDATE'
       and qual='can_edit_activity(activity_id)' and with_check='can_edit_activity(activity_id)') then
    raise exception '0008_preflight_exact_operational_policy_drift';
  end if;

  with expected(table_name,privilege_type) as (
    values
      ('academic_periods','SELECT'),('academic_programs','SELECT'),
      ('activities','DELETE'),('activities','INSERT'),('activities','SELECT'),('activities','UPDATE'),
      ('activity_modalities','SELECT'),
      ('activity_participants','DELETE'),('activity_participants','INSERT'),
      ('activity_participants','SELECT'),('activity_participants','UPDATE'),
      ('activity_statuses','SELECT'),('activity_types','SELECT'),('attention_categories','SELECT'),
      ('divisions','SELECT'),('location_types','SELECT'),('participant_roles','SELECT'),
      ('profiles','SELECT'),('role_assignments','SELECT'),('roles','SELECT'),
      ('service_types','SELECT'),('system_health','SELECT')
  ), actual as (
    select table_name,privilege_type
    from information_schema.role_table_grants
    where table_schema='public' and grantee='authenticated'
  )
  select count(*) into mismatch_count from (
    (select * from expected except select * from actual)
    union all
    (select * from actual except select * from expected)
  ) differences;
  if mismatch_count<>0 then
    raise exception '0008_preflight_authenticated_table_grant_drift';
  end if;

  if (select count(*) from information_schema.columns
       where table_schema='public' and table_name='admin_audit_events')<>9
     or (select count(*) from pg_constraint
       where conrelid='public.admin_audit_events'::regclass)<>8
     or (select count(*) from pg_trigger
       where tgrelid='public.admin_audit_events'::regclass and not tgisinternal)<>2
     or (select count(*) from pg_policies
       where schemaname='public' and tablename='admin_audit_events')<>0
     or to_regclass('public.admin_audit_events_target_occurred_idx') is null
     or to_regclass('public.admin_audit_events_actor_occurred_idx') is null
     or has_table_privilege('authenticated','public.admin_audit_events','SELECT')
     or has_table_privilege('authenticated','public.admin_audit_events','INSERT')
     or not has_table_privilege('service_role','public.admin_audit_events','SELECT')
     or not has_table_privilege('service_role','public.admin_audit_events','INSERT')
     or has_table_privilege('service_role','public.admin_audit_events','UPDATE')
     or has_table_privilege('service_role','public.admin_audit_events','DELETE')
     or not exists (
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
    raise exception '0008_preflight_0007_audit_contract_drift';
  end if;

  if to_regclass('public.profiles_admin_directory_sort_idx') is null
     or to_regclass('public.profiles_admin_directory_filters_idx') is null
     or to_regprocedure('public.admin_audit_metadata_is_safe(jsonb)') is null
     or to_regprocedure('public.prevent_admin_audit_event_mutation()') is null
     or not exists(select 1 from pg_trigger t join pg_class c on c.oid=t.tgrelid
       join pg_namespace n on n.oid=c.relnamespace
       where n.nspname='auth' and c.relname='users' and t.tgname='on_auth_user_created'
         and not t.tgisinternal)
     or not exists(select 1 from pg_trigger t join pg_class c on c.oid=t.tgrelid
       join pg_namespace n on n.oid=c.relnamespace
       where n.nspname='auth' and c.relname='users' and t.tgname='on_auth_user_updated'
         and not t.tgisinternal) then
    raise exception '0008_preflight_0007_or_registration_object_drift';
  end if;

  if to_regprocedure('public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)') is null
     or to_regprocedure('public.get_admin_account_detail_b1(uuid)') is null
     or to_regprocedure('public.get_admin_account_assignments_b1(uuid)') is null
     or to_regprocedure('public.get_admin_account_audit_history_b1(uuid,integer,integer)') is null
     or not has_function_privilege('authenticated','public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)','EXECUTE')
     or not has_function_privilege('authenticated','public.get_admin_account_detail_b1(uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.get_admin_account_assignments_b1(uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.get_admin_account_audit_history_b1(uuid,integer,integer)','EXECUTE')
     or has_function_privilege('anon','public.get_admin_account_detail_b1(uuid)','EXECUTE')
     or has_function_privilege('service_role','public.get_admin_account_detail_b1(uuid)','EXECUTE')
     or has_function_privilege('authenticated','public.is_b1_account_admin()','EXECUTE') then
    raise exception '0008_preflight_0007_rpc_acl_drift';
  end if;

  if (select count(*) from pg_constraint where conrelid='public.profiles'::regclass
       and conname in (
         'profiles_account_identity_check','profiles_account_kind_check',
         'profiles_account_lifecycle_check','profiles_account_status_check',
         'profiles_first_names_check','profiles_paternal_surname_check',
         'profiles_maternal_surname_check','profiles_full_name_check',
         'profiles_identifier_digits_check','profiles_identifier_length_check',
         'profiles_institutional_id_type_check','profiles_person_type_check',
         'profiles_structured_full_name_check'))<>13
     or to_regclass('public.profiles_institutional_identifier_pair_key') is null
     or has_table_privilege('authenticated','public.profiles','UPDATE')
     or not has_column_privilege('authenticated','public.profiles','first_names','UPDATE')
     or not has_column_privilege('authenticated','public.profiles','paternal_surname','UPDATE')
     or not has_column_privilege('authenticated','public.profiles','maternal_surname','UPDATE')
     or has_column_privilege('authenticated','public.profiles','full_name','UPDATE')
     or has_column_privilege('authenticated','public.profiles','person_type','UPDATE')
     or has_column_privilege('authenticated','public.profiles','primary_program_id','UPDATE') then
    raise exception '0008_preflight_profile_identity_contract_drift';
  end if;

  if (select count(*) from public.roles)<>10
     or not exists(select 1 from public.roles where code='technical_admin')
     or (select count(*) from public.academic_programs where is_active)<1
     or (select count(*) from public.participant_roles where code='responsible')<>1 then
    raise exception '0008_preflight_catalog_contract_mismatch';
  end if;
end;
$preflight$;

create function public.is_sitaa_operational_account_active()
returns boolean
language sql
stable
security definer
set search_path=pg_catalog,public
as $function$
  select auth.uid() is not null
     and (
       select count(*)=1
       from public.profiles p
       where p.id=auth.uid()
         and p.account_status='active'
         and p.is_active=true
     );
$function$;

revoke all on function public.is_sitaa_operational_account_active()
  from public,anon,authenticated,service_role;
grant execute on function public.is_sitaa_operational_account_active()
  to authenticated;

-- Barrera operativa: activity_attendance_deadline(uuid)
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

  where public.is_sitaa_operational_account_active()
    and a.id = target_activity_id

    and a.start_date is not null;

$function$;

-- Barrera operativa: activity_attendance_open_at(uuid)
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

  where public.is_sitaa_operational_account_active()
    and a.id = target_activity_id

    and a.start_date is not null

    and a.start_time is not null;

$function$;

-- Barrera operativa: activity_has_ended(uuid)
CREATE OR REPLACE FUNCTION public.activity_has_ended(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.is_sitaa_operational_account_active() and coalesce((
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
    where a.id = target_activity_id
  ), false);
$function$;

-- Barrera operativa: add_activity_participant(uuid,uuid,text)
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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

  -- El INSERT adquiere ROW EXCLUSIVE al inicio del protocolo para mantener el
  -- mismo orden de bloqueo que la corrección administrativa de identidad.
  lock table public.activity_participants in row exclusive mode;

  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para agregar participantes a esta actividad.' using errcode = '42501';
  end if;
  select a.program_id into target_program_id from public.activities a where a.id = target_activity_id;
  if target_program_id is null then
    raise exception 'La actividad no tiene programa académico asignado.' using errcode = 'P0001';
  end if;
  select p.primary_program_id, p.person_type into participant_program_id, participant_person_type
  from public.profiles p
  where p.id = target_profile_id and p.is_active = true
  for share;
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

-- Barrera operativa: can_create_activity(text,uuid,uuid,text)
CREATE OR REPLACE FUNCTION public.can_create_activity(target_scope_type text, target_program_id uuid, target_division_id uuid, target_service_type_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select public.is_sitaa_operational_account_active() and exists (

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

-- Barrera operativa: can_create_activity(uuid,text)
CREATE OR REPLACE FUNCTION public.can_create_activity(target_program_id uuid, target_service_type_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select public.is_sitaa_operational_account_active() and (
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
    or public.can_manage_activity(target_program_id, target_service_type_code)
  );
$function$;

-- Barrera operativa: can_delete_activity(uuid)
CREATE OR REPLACE FUNCTION public.can_delete_activity(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.is_sitaa_operational_account_active() and exists (
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

-- Barrera operativa: can_edit_activity(uuid)
CREATE OR REPLACE FUNCTION public.can_edit_activity(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select public.is_sitaa_operational_account_active() and exists (

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

-- Barrera operativa: can_manage_activity(text,uuid,uuid,text)
CREATE OR REPLACE FUNCTION public.can_manage_activity(target_scope_type text, target_program_id uuid, target_division_id uuid, target_service_type_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select public.is_sitaa_operational_account_active() and exists (

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

-- Barrera operativa: can_manage_activity(uuid,text)
CREATE OR REPLACE FUNCTION public.can_manage_activity(target_program_id uuid, target_service_type_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select public.is_sitaa_operational_account_active() and exists (

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

-- Barrera operativa: can_read_activity(uuid)
CREATE OR REPLACE FUNCTION public.can_read_activity(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select public.is_sitaa_operational_account_active() and exists (

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

-- Barrera operativa: can_update_activity_base(uuid)
CREATE OR REPLACE FUNCTION public.can_update_activity_base(target_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.is_sitaa_operational_account_active() and exists (
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

-- Barrera operativa: check_in_activity(text)
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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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

-- Barrera operativa: close_activity_attendance_checkin(uuid)
CREATE OR REPLACE FUNCTION public.close_activity_attendance_checkin(target_activity_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

begin
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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

-- Barrera operativa: finalize_expired_attendance()
CREATE OR REPLACE FUNCTION public.finalize_expired_attendance()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

declare

  updated_count integer;

begin
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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

-- Barrera operativa: generate_three_word_code()
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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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

-- Barrera operativa: get_active_activity_attendance_checkin(uuid)
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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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

-- Barrera operativa: get_activity_attendance_checkin_state(uuid)
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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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

-- Barrera operativa: get_activity_participants(uuid)
CREATE OR REPLACE FUNCTION public.get_activity_participants(target_activity_id uuid)
 RETURNS TABLE(id uuid, activity_id uuid, profile_id uuid, participant_role_code text, participant_role_label text, full_name text, email text, person_type text, institutional_id_type text, institutional_id_value text, program_name text, attendance_status text, attendance_source text, checked_in_at timestamp with time zone, attendance_updated_at timestamp with time zone, attendance_notes text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

begin
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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

-- Barrera operativa: get_visible_activity_cards()
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

    public.is_sitaa_operational_account_active()

    and (

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

    )

  order by a.start_date desc nulls last, a.start_time desc nulls last, a.created_at desc;

$function$;

-- Barrera operativa: has_active_role(text)
CREATE OR REPLACE FUNCTION public.has_active_role(required_role text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select public.is_sitaa_operational_account_active() and exists (

    select 1

    from public.role_assignments ra

    where ra.user_id = auth.uid()

      and ra.role_code = required_role

      and ra.is_active = true

      and ra.starts_at <= current_date

      and (ra.ends_at is null or ra.ends_at >= current_date)

  );

$function$;

-- Barrera operativa: has_any_active_role(text[])
CREATE OR REPLACE FUNCTION public.has_any_active_role(required_roles text[])
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select public.is_sitaa_operational_account_active() and exists (

    select 1

    from public.role_assignments ra

    where ra.user_id = auth.uid()

      and ra.role_code = any(required_roles)

      and ra.is_active = true

      and ra.starts_at <= current_date

      and (ra.ends_at is null or ra.ends_at >= current_date)

  );

$function$;

-- Barrera operativa: is_activity_participant(uuid)
CREATE OR REPLACE FUNCTION public.is_activity_participant(target_activity_id uuid)


 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select public.is_sitaa_operational_account_active() and exists (

    select 1

    from public.activity_participants ap

    where ap.activity_id = target_activity_id

      and ap.profile_id = auth.uid()

  );

$function$;

-- Barrera operativa: open_activity_attendance_checkin(uuid)
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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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

-- Barrera operativa: publish_activity(uuid)
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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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

-- Barrera operativa: remove_activity_participant(uuid)
CREATE OR REPLACE FUNCTION public.remove_activity_participant(target_participant_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

declare

  target_activity_id uuid;

begin
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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

-- Barrera operativa: search_profiles_for_participation(uuid,text)
CREATE OR REPLACE FUNCTION public.search_profiles_for_participation(target_activity_id uuid, search_text text)
 RETURNS TABLE(id uuid, full_name text, email text, person_type text, institutional_id_type text, institutional_id_value text, primary_program_id uuid, program_name text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

declare

  target_program_id uuid;

begin
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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

-- Barrera operativa: update_activity_participant_attendance(uuid,text,text)
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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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

-- Barrera operativa: update_activity_participants_attendance_bulk(uuid,uuid[],text,text)
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
  if not public.is_sitaa_operational_account_active() then
    raise exception 'sitaa_operational_account_inactive' using errcode = '42501';
  end if;

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

-- Contexto mínimo y sin PII para elegibilidad y advertencias.
create function public.get_admin_identity_correction_context_b2a(
  requested_profile_id uuid
)
returns table(
  target_profile_id uuid,
  can_correct boolean,
  denial_code text,
  account_kind text,
  account_status text,
  is_self boolean,
  current_or_future_assignment_count bigint,
  open_responsibility_count bigint,
  open_participation_count bigint
)
language plpgsql
stable
security definer
set search_path=pg_catalog,public
as $function$
declare
  target_profile public.profiles%rowtype;
  institutional_today date:=public.sitaa_current_mexico_date();
  assignment_count bigint:=0;
  responsibility_count bigint:=0;
  participation_count bigint:=0;
  allowed boolean;
  denial text;
begin
  if not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode='42501';
  end if;

  select p.* into target_profile
  from public.profiles p
  where p.id=requested_profile_id;

  if not found then
    return;
  end if;

  select count(*) into assignment_count
  from public.role_assignments ra
  where ra.user_id=target_profile.id
    and ra.is_active=true
    and (ra.ends_at is null or ra.ends_at>=institutional_today);

  select count(distinct responsibilities.activity_id) into responsibility_count
  from (
    select a.id as activity_id
    from public.activities a
    where a.responsible_profile_id=target_profile.id
      and (a.status_code='draft' or public.activity_has_ended(a.id) is distinct from true)
    union
    select a.id
    from public.activity_participants participant
    join public.activities a on a.id=participant.activity_id
    where participant.profile_id=target_profile.id
      and participant.participant_role_code='responsible'
      and (a.status_code='draft' or public.activity_has_ended(a.id) is distinct from true)
  ) responsibilities;

  select count(distinct a.id) into participation_count
  from public.activity_participants participant
  join public.activities a on a.id=participant.activity_id
  where participant.profile_id=target_profile.id
    and (a.status_code='draft' or public.activity_has_ended(a.id) is distinct from true);

  allowed:=target_profile.id<>auth.uid()
    and target_profile.account_status in ('active','inactive')
    and target_profile.account_kind in ('institutional','technical');

  denial:=case
    when target_profile.id=auth.uid() then 'self_target'
    when target_profile.account_status='pending_registration' then 'pending_target'
    when target_profile.account_status not in ('active','inactive')
      or target_profile.account_kind not in ('institutional','technical')
      then 'unsupported_target'
    else null
  end;

  return query select
    target_profile.id,
    allowed,
    denial,
    target_profile.account_kind,
    target_profile.account_status,
    target_profile.id=auth.uid(),
    assignment_count,
    responsibility_count,
    participation_count;
end;
$function$;

-- Mutación única, autorizada, bloqueada y auditada.
create function public.correct_admin_account_identity_b2a(
  requested_profile_id uuid,
  requested_first_names text,
  requested_paternal_surname text,
  requested_maternal_surname text,
  requested_person_type text,
  requested_institutional_id_value text,
  requested_primary_program_id uuid,
  correction_reason text
)
returns table(
  target_profile_id uuid,
  audit_event_id uuid,
  changed_fields text[],
  updated_at timestamp with time zone
)
language plpgsql
security definer
set search_path=pg_catalog,public
as $function$
declare
  target_profile public.profiles%rowtype;
  normalized_first_names text;
  normalized_paternal_surname text;
  normalized_maternal_surname text;
  normalized_full_name text;
  normalized_reason text;
  derived_identifier_type text;
  requested_division_id uuid;
  institutional_today date:=public.sitaa_current_mexico_date();
  changed text[]:=array[]::text[];
  persisted_updated_at timestamptz;
  event_id uuid;
begin
  if auth.uid() is null or not public.is_b1_account_admin() then
    raise exception 'sitaa_admin_access_denied' using errcode='42501';
  end if;

  -- Protocolo fijo y corto: las escrituras normales toman ROW EXCLUSIVE y no
  -- pueden cruzar la decisión de dependencias protegida por estos SHARE locks.
  lock table public.role_assignments in share mode;
  lock table public.activities in share mode;
  lock table public.activity_participants in share mode;

  if requested_profile_id=auth.uid() then
    raise exception 'sitaa_identity_self_correction_forbidden' using errcode='42501';
  end if;

  select p.* into target_profile
  from public.profiles p
  where p.id=requested_profile_id
  for update;

  if not found then
    raise exception 'sitaa_identity_target_unavailable' using errcode='P0001';
  end if;
  if target_profile.account_status='pending_registration' then
    raise exception 'sitaa_identity_pending_target' using errcode='P0001';
  end if;
  if target_profile.account_status not in ('active','inactive')
     or target_profile.account_kind not in ('institutional','technical') then
    raise exception 'sitaa_identity_target_unavailable' using errcode='P0001';
  end if;

  normalized_reason:=nullif(
    btrim(regexp_replace(coalesce(correction_reason,''),'\s+',' ','g')),
    ''
  );
  if normalized_reason is null
     or char_length(normalized_reason)<10
     or char_length(normalized_reason)>1000 then
    raise exception 'sitaa_identity_invalid_reason' using errcode='22023';
  end if;

  normalized_first_names:=nullif(
    btrim(regexp_replace(coalesce(requested_first_names,''),'\s+',' ','g')),
    ''
  );
  normalized_paternal_surname:=nullif(
    btrim(regexp_replace(coalesce(requested_paternal_surname,''),'\s+',' ','g')),
    ''
  );
  normalized_maternal_surname:=nullif(
    btrim(regexp_replace(coalesce(requested_maternal_surname,''),'\s+',' ','g')),
    ''
  );
  normalized_full_name:=nullif(
    concat_ws(' ',normalized_first_names,normalized_paternal_surname,normalized_maternal_surname),
    ''
  );

  if normalized_first_names is null
     or char_length(normalized_first_names)>150
     or char_length(normalized_paternal_surname)>150
     or char_length(normalized_maternal_surname)>150
     or char_length(normalized_full_name) not between 2 and 200 then
    raise exception 'sitaa_identity_invalid_name' using errcode='22023';
  end if;

  if target_profile.account_kind='technical' then
    if requested_person_type is not null
       or requested_institutional_id_value is not null
       or requested_primary_program_id is not null then
      raise exception 'sitaa_identity_technical_fields_forbidden' using errcode='22023';
    end if;
  else
    if normalized_paternal_surname is null then
      raise exception 'sitaa_identity_invalid_name' using errcode='22023';
    end if;
    if requested_person_type is null
       or requested_person_type not in ('student','professor') then
      raise exception 'sitaa_identity_invalid_person_type' using errcode='22023';
    end if;
    if requested_institutional_id_value is null
       or requested_institutional_id_value !~ '^[0-9]{1,50}$' then
      raise exception 'sitaa_identity_invalid_identifier' using errcode='22023';
    end if;
    derived_identifier_type:=case
      when requested_person_type='student' then 'student_account'
      else 'worker_number'
    end;

    select program.division_id into requested_division_id
    from public.academic_programs program
    where program.id=requested_primary_program_id
      and program.is_active=true
    for share;
    if not found then
      raise exception 'sitaa_identity_invalid_program' using errcode='22023';
    end if;

    if exists (
      select 1 from public.profiles other_profile
      where other_profile.id<>target_profile.id
        and other_profile.institutional_id_type=derived_identifier_type
        and other_profile.institutional_id_value=requested_institutional_id_value
    ) then
      raise exception 'sitaa_identity_duplicate_identifier' using errcode='23505';
    end if;

    if requested_person_type is distinct from target_profile.person_type then
      if exists (
        select 1 from public.role_assignments ra
        where ra.user_id=target_profile.id
          and ra.is_active=true
          and (ra.ends_at is null or ra.ends_at>=institutional_today)
      ) then
        raise exception 'sitaa_identity_person_type_dependency' using errcode='P0001';
      end if;

      if requested_person_type='student' and exists (
        select 1
        from public.activities a
        where (
          a.responsible_profile_id=target_profile.id
          or exists (
            select 1 from public.activity_participants participant
            where participant.activity_id=a.id
              and participant.profile_id=target_profile.id
              and participant.participant_role_code='responsible'
          )
        )
        and (a.status_code='draft' or public.activity_has_ended(a.id) is distinct from true)
      ) then
        raise exception 'sitaa_identity_person_type_dependency' using errcode='P0001';
      end if;
    end if;

    if requested_primary_program_id is distinct from target_profile.primary_program_id then
      if exists (
        select 1 from public.role_assignments ra
        where ra.user_id=target_profile.id
          and ra.is_active=true
          and (ra.ends_at is null or ra.ends_at>=institutional_today)
          and (
            (ra.program_id is not null and ra.program_id<>requested_primary_program_id)
            or (ra.division_id is not null and ra.division_id<>requested_division_id)
          )
      ) then
        raise exception 'sitaa_identity_program_dependency' using errcode='P0001';
      end if;

      if exists (
        select 1
        from public.activities a
        where (
          a.responsible_profile_id=target_profile.id
          or exists (
            select 1 from public.activity_participants participant
            where participant.activity_id=a.id
              and participant.profile_id=target_profile.id
          )
        )
        and (a.status_code='draft' or public.activity_has_ended(a.id) is distinct from true)
        and (
          (a.scope_type='program' and a.program_id is distinct from requested_primary_program_id)
          or (a.scope_type='division' and a.division_id is distinct from requested_division_id)
        )
      ) then
        raise exception 'sitaa_identity_program_dependency' using errcode='P0001';
      end if;
    end if;
  end if;

  if normalized_first_names is distinct from target_profile.first_names then
    changed:=array_append(changed,'first_names');
  end if;
  if target_profile.account_kind='institutional'
     and derived_identifier_type is distinct from target_profile.institutional_id_type then
    changed:=array_append(changed,'institutional_id_type');
  end if;
  if target_profile.account_kind='institutional'
     and requested_institutional_id_value is distinct from target_profile.institutional_id_value then
    changed:=array_append(changed,'institutional_id_value');
  end if;
  if normalized_maternal_surname is distinct from target_profile.maternal_surname then
    changed:=array_append(changed,'maternal_surname');
  end if;
  if normalized_paternal_surname is distinct from target_profile.paternal_surname then
    changed:=array_append(changed,'paternal_surname');
  end if;
  if target_profile.account_kind='institutional'
     and requested_person_type is distinct from target_profile.person_type then
    changed:=array_append(changed,'person_type');
  end if;
  if target_profile.account_kind='institutional'
     and requested_primary_program_id is distinct from target_profile.primary_program_id then
    changed:=array_append(changed,'primary_program_id');
  end if;

  if coalesce(cardinality(changed),0)=0 then
    raise exception 'sitaa_identity_no_changes' using errcode='22023';
  end if;

  begin
    if target_profile.account_kind='institutional' then
      update public.profiles p
      set first_names=normalized_first_names,
          paternal_surname=normalized_paternal_surname,
          maternal_surname=normalized_maternal_surname,
          person_type=requested_person_type,
          institutional_id_type=derived_identifier_type,
          institutional_id_value=requested_institutional_id_value,
          primary_program_id=requested_primary_program_id,
          updated_at=now()
      where p.id=target_profile.id
      returning p.updated_at into persisted_updated_at;
    else
      update public.profiles p
      set first_names=normalized_first_names,
          paternal_surname=normalized_paternal_surname,
          maternal_surname=normalized_maternal_surname,
          updated_at=now()
      where p.id=target_profile.id
      returning p.updated_at into persisted_updated_at;
    end if;
  exception when unique_violation then
    raise exception 'sitaa_identity_duplicate_identifier' using errcode='23505';
  end;

  insert into public.admin_audit_events(
    actor_profile_id,target_profile_id,action_code,outcome,reason,
    role_assignment_id,metadata
  ) values (
    auth.uid(),target_profile.id,'account_identity_corrected','success',
    normalized_reason,null,
    jsonb_build_object('changed_fields',to_jsonb(changed))
  )
  returning id into event_id;

  return query select target_profile.id,event_id,changed,persisted_updated_at;
end;
$function$;

-- Cierra las escrituras directas de actividad que podrían reconstruir una
-- dependencia incompatible después de una corrección de identidad.
create function public.enforce_activity_writer_integrity_b2a()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog,public
as $function$
declare
  participant record;
begin
  if auth.uid() is not null then
    if tg_op='INSERT' then
      if new.created_by is distinct from auth.uid()
         or new.responsible_profile_id is distinct from auth.uid() then
        raise exception 'sitaa_activity_writer_identity_mismatch' using errcode='42501';
      end if;
      if not public.can_create_activity(
        new.scope_type,new.program_id,new.division_id,new.service_type_code
      ) then
        raise exception 'sitaa_activity_writer_scope_denied' using errcode='42501';
      end if;
    else
      if new.created_by is distinct from old.created_by
         or new.responsible_profile_id is distinct from old.responsible_profile_id then
        raise exception 'sitaa_activity_writer_identity_immutable' using errcode='42501';
      end if;
      if (
        new.scope_type is distinct from old.scope_type
        or new.program_id is distinct from old.program_id
        or new.division_id is distinct from old.division_id
        or new.service_type_code is distinct from old.service_type_code
      ) and not public.can_create_activity(
        new.scope_type,new.program_id,new.division_id,new.service_type_code
      ) then
        raise exception 'sitaa_activity_writer_scope_denied' using errcode='42501';
      end if;
    end if;
  end if;

  if tg_op='UPDATE' and (
    new.scope_type is distinct from old.scope_type
    or new.program_id is distinct from old.program_id
    or new.division_id is distinct from old.division_id
  ) then
    for participant in
      select
        activity_participant.participant_role_code,
        profile.person_type,
        profile.primary_program_id,
        program.division_id
      from public.activity_participants activity_participant
      join public.profiles profile on profile.id=activity_participant.profile_id
      left join public.academic_programs program on program.id=profile.primary_program_id
      where activity_participant.activity_id=new.id
      for share of profile
    loop
      if participant.primary_program_id is null
         or (new.scope_type='program'
           and participant.primary_program_id is distinct from new.program_id)
         or (new.scope_type='division'
           and participant.division_id is distinct from new.division_id)
         or (participant.participant_role_code='responsible'
           and participant.person_type is distinct from 'professor') then
        raise exception 'sitaa_activity_participant_identity_incompatible'
          using errcode='23514';
      end if;
    end loop;
  end if;

  return new;
end;
$function$;

revoke all on function public.enforce_activity_writer_integrity_b2a()
  from public,anon,authenticated,service_role;

create trigger enforce_activity_writer_integrity_b2a
before insert or update on public.activities
for each row execute function public.enforce_activity_writer_integrity_b2a();

-- La aplicación usa exclusivamente RPC para altas, bajas y asistencia.
-- SELECT permanece directo y protegido por RLS; las escrituras ya no pueden
-- omitir las validaciones de add/remove/update.
revoke insert,update,delete on table public.activity_participants
  from authenticated;

revoke all on function public.get_admin_identity_correction_context_b2a(uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.get_admin_identity_correction_context_b2a(uuid)
  to authenticated;

revoke all on function public.correct_admin_account_identity_b2a(
  uuid,text,text,text,text,text,uuid,text
) from public,anon,authenticated,service_role;
grant execute on function public.correct_admin_account_identity_b2a(
  uuid,text,text,text,text,text,uuid,text
) to authenticated;

create policy "Active accounts may operate activities"
on public.activities
as restrictive
for all
to authenticated
using (public.is_sitaa_operational_account_active())
with check (public.is_sitaa_operational_account_active());

create policy "Active accounts may operate activity participants"
on public.activity_participants
as restrictive
for all
to authenticated
using (public.is_sitaa_operational_account_active())
with check (public.is_sitaa_operational_account_active());

do $post_ddl_contract$
declare
  mismatch_count integer;
begin
  if (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public')<>51
     or (select count(*) from pg_policies where schemaname='public')<>25
     or (select count(*) from information_schema.columns where table_schema='public')<>165
     or (select count(*) from pg_constraint c join pg_namespace n on n.oid=c.connamespace
         where n.nspname='public' and c.contype in ('p','f','u','c'))<>80
     or (select count(*) from pg_indexes where schemaname='public')<>43
     or (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid
         join pg_namespace n on n.oid=c.relnamespace
         where n.nspname='public' and not t.tgisinternal)<>11 then
    raise exception '0008_post_ddl_inventory_mismatch';
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
     ) then
    raise exception '0008_post_ddl_policy_contract_mismatch';
  end if;

  if not exists (
       select 1
       from pg_trigger trigger_definition
       where trigger_definition.tgrelid='public.activities'::regclass
         and trigger_definition.tgname='enforce_activity_writer_integrity_b2a'
         and not trigger_definition.tgisinternal
         and trigger_definition.tgenabled='O'
         and trigger_definition.tgfoid=
           to_regprocedure('public.enforce_activity_writer_integrity_b2a()')
         and trigger_definition.tgtype=23
     )
     or not exists (
       select 1 from pg_proc function_definition
       where function_definition.oid=
         to_regprocedure('public.enforce_activity_writer_integrity_b2a()')
         and function_definition.prorettype='trigger'::regtype
         and function_definition.prolang=(
           select oid from pg_language where lanname='plpgsql'
         )
         and function_definition.provolatile='v'
         and function_definition.prosecdef
         and function_definition.proconfig=
           array['search_path=pg_catalog, public']::text[]
         and function_definition.pronargs=0
         and coalesce(cardinality(function_definition.proargnames),0)=0
         and function_definition.proallargtypes is null
         and pg_get_function_identity_arguments(function_definition.oid)=''
         and md5(regexp_replace(function_definition.prosrc,'\s+','','g'))=
           'f3015ca3f14ada575b19a6d39d1622ea'
     ) then
    raise exception '0008_post_ddl_writer_trigger_mismatch';
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
  where lower(p.prosrc) not like '%is_sitaa_operational_account_active%';
  if mismatch_count<>0 then
    raise exception '0008_post_ddl_operational_barrier_incomplete';
  end if;

  if not exists (
       select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
       where n.nspname='public' and p.proname='is_sitaa_operational_account_active'
         and p.pronargs=0 and p.prosecdef and p.provolatile='s'
         and p.proconfig=array['search_path=pg_catalog, public']::text[]
         and p.prorettype='boolean'::regtype
         and coalesce(cardinality(p.proargnames),0)=0
         and p.proallargtypes is null
         and pg_get_function_identity_arguments(p.oid)=''
     )
     or not exists (
       select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
       where n.nspname='public' and p.proname='get_admin_identity_correction_context_b2a'
         and p.pronargs=1 and p.prosecdef and p.provolatile='s'
         and p.proconfig=array['search_path=pg_catalog, public']::text[]
         and p.prorettype='record'::regtype
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
       select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
       where n.nspname='public' and p.proname='correct_admin_account_identity_b2a'
         and p.pronargs=8 and p.prosecdef and p.provolatile='v'
         and p.proconfig=array['search_path=pg_catalog, public']::text[]
         and p.prorettype='record'::regtype
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
    raise exception '0008_post_ddl_new_function_properties_mismatch';
  end if;

  select count(*) into mismatch_count
  from (values
    (to_regprocedure('public.is_sitaa_operational_account_active()')),
    (to_regprocedure('public.get_admin_identity_correction_context_b2a(uuid)')),
    (to_regprocedure('public.correct_admin_account_identity_b2a(uuid,text,text,text,text,text,uuid,text)'))
  ) expected(function_oid)
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
    select 1
    from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
    left join pg_roles grantee on grantee.oid=acl.grantee
    where acl.privilege_type<>'EXECUTE'
       or (acl.grantee<>p.proowner and coalesce(grantee.rolname,'PUBLIC')<>'authenticated')
       or acl.is_grantable
  );
  if mismatch_count<>0 then
    raise exception '0008_post_ddl_new_function_acl_mismatch';
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
    raise exception '0008_post_ddl_existing_acl_changed';
  end if;

  if has_table_privilege('authenticated','public.admin_audit_events','SELECT')
     or has_table_privilege('authenticated','public.admin_audit_events','INSERT')
     or not has_table_privilege('service_role','public.admin_audit_events','SELECT')
     or not has_table_privilege('service_role','public.admin_audit_events','INSERT')
     or has_table_privilege('service_role','public.admin_audit_events','UPDATE')
     or has_table_privilege('service_role','public.admin_audit_events','DELETE') then
    raise exception '0008_post_ddl_audit_acl_changed';
  end if;

  if not has_table_privilege('authenticated','public.activity_participants','SELECT')
     or has_table_privilege('authenticated','public.activity_participants','INSERT')
     or has_table_privilege('authenticated','public.activity_participants','UPDATE')
     or has_table_privilege('authenticated','public.activity_participants','DELETE')
     or not has_table_privilege('authenticated','public.activities','SELECT,INSERT,UPDATE,DELETE')
     or has_function_privilege(
       'authenticated','public.enforce_activity_writer_integrity_b2a()','EXECUTE'
     )
     or has_function_privilege(
       'anon','public.enforce_activity_writer_integrity_b2a()','EXECUTE'
     )
     or has_function_privilege(
       'service_role','public.enforce_activity_writer_integrity_b2a()','EXECUTE'
     )
     or (
       select count(*)
       from pg_proc function_definition
       cross join lateral aclexplode(coalesce(
         function_definition.proacl,
         acldefault('f',function_definition.proowner)
       )) acl
       where function_definition.oid=
         to_regprocedure('public.enforce_activity_writer_integrity_b2a()')
         and acl.grantee=function_definition.proowner
         and acl.privilege_type='EXECUTE'
         and not acl.is_grantable
     )<>1
     or exists (
       select 1
       from pg_proc function_definition
       cross join lateral aclexplode(coalesce(
         function_definition.proacl,
         acldefault('f',function_definition.proowner)
       )) acl
       where function_definition.oid=
         to_regprocedure('public.enforce_activity_writer_integrity_b2a()')
         and (
           acl.grantee<>function_definition.proowner
           or acl.privilege_type<>'EXECUTE'
           or acl.is_grantable
         )
     ) then
    raise exception '0008_post_ddl_writer_acl_mismatch';
  end if;

  if exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public' and table_name in ('activities','activity_participants','admin_audit_events')
      and grantee in ('anon','authenticated','service_role')
      and (
        (table_name='activities' and grantee='authenticated'
          and privilege_type not in ('SELECT','INSERT','UPDATE','DELETE'))
        or (table_name='activity_participants' and grantee='authenticated'
          and privilege_type<>'SELECT')
        or (table_name='admin_audit_events' and grantee='service_role'
          and privilege_type not in ('SELECT','INSERT'))
        or (table_name='admin_audit_events' and grantee in ('anon','authenticated'))
      )
  ) then
    raise exception '0008_post_ddl_direct_table_grant_changed';
  end if;
end;
$post_ddl_contract$;

commit;
