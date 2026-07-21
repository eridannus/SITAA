-- Preflight de sólo lectura para 0008. Devuelve únicamente conteos agregados.
begin;
set transaction read only;

with
expected_signatures(signature) as (
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
),
expected_operational(signature,body_hash) as (
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
),
expected_authenticated_grants(table_name,privilege_type) as (
  values
    ('academic_periods','SELECT'),
    ('academic_programs','SELECT'),
    ('activities','DELETE'),
    ('activities','INSERT'),
    ('activities','SELECT'),
    ('activities','UPDATE'),
    ('activity_modalities','SELECT'),
    ('activity_participants','DELETE'),
    ('activity_participants','INSERT'),
    ('activity_participants','SELECT'),
    ('activity_participants','UPDATE'),
    ('activity_statuses','SELECT'),
    ('activity_types','SELECT'),
    ('attention_categories','SELECT'),
    ('divisions','SELECT'),
    ('location_types','SELECT'),
    ('participant_roles','SELECT'),
    ('profiles','SELECT'),
    ('role_assignments','SELECT'),
    ('roles','SELECT'),
    ('service_types','SELECT'),
    ('system_health','SELECT')
),
actual_signatures(signature) as (
  select p.oid::regprocedure::text
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
),
signature_differences as (
  (select signature from expected_signatures except select signature from actual_signatures)
  union all
  (select signature from actual_signatures except select signature from expected_signatures)
),
operational_definition_drift as (
  select e.signature
  from expected_operational e
  left join pg_proc p on p.oid=to_regprocedure('public.'||e.signature)
  left join pg_language l on l.oid=p.prolang
  where p.oid is null
     or p.prosecdef is not true
     or p.proconfig is distinct from array['search_path=public']::text[]
     or l.lanname not in ('sql','plpgsql')
     or md5(btrim(regexp_replace(lower(p.prosrc),'\s+',' ','g')))<>e.body_hash
),
operational_acl_drift as (
  select e.signature
  from expected_operational e
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
),
actual_authenticated_grants(table_name,privilege_type) as (
  select table_name,privilege_type
  from information_schema.role_table_grants
  where table_schema='public' and grantee='authenticated'
),
grant_differences as (
  (select * from expected_authenticated_grants except select * from actual_authenticated_grants)
  union all
  (select * from actual_authenticated_grants except select * from expected_authenticated_grants)
),
post_0007_privilege_inventory(routine_grants,table_grants,sequence_grants,expanded_acl) as (
  select
    (select count(*) from information_schema.routine_privileges
     where routine_schema='public'),
    (select count(*) from information_schema.table_privileges
     where table_schema='public'),
    (select count(*)
     from pg_class c join pg_namespace n on n.oid=c.relnamespace
     cross join lateral aclexplode(coalesce(c.relacl,acldefault('S',c.relowner))) acl
     where n.nspname='public' and c.relkind='S'),
    (
      (select count(*)
       from pg_proc p join pg_namespace n on n.oid=p.pronamespace
       cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
       where n.nspname='public' and p.prokind in ('f','p'))
      +
      (select count(*)
       from pg_class c join pg_namespace n on n.oid=c.relnamespace
       cross join lateral aclexplode(coalesce(
         c.relacl,
         case when c.relkind='S' then acldefault('S',c.relowner)
              else acldefault('r',c.relowner) end
       )) acl
       where n.nspname='public' and c.relkind in ('r','p','v','m','S'))
    )
),
expected_registration_trigger(trigger_name,function_oid,event_type,uses_email_column) as (
  values
    (
      'on_sitaa_auth_user_created',
      to_regprocedure('public.handle_sitaa_auth_user_created()'),
      5::smallint,
      false
    ),
    (
      'on_sitaa_auth_user_email_changed',
      to_regprocedure('public.sync_sitaa_profile_email_from_auth()'),
      17::smallint,
      true
    )
),
registration_trigger_contract_drift(aggregate_count) as (
  select
    (
      select count(*)
      from expected_registration_trigger expected
      where (
        select count(*)
        from pg_trigger trigger_definition
        where not trigger_definition.tgisinternal
          and trigger_definition.tgname=expected.trigger_name
      )<>1
      or (
        select count(*)
        from pg_trigger trigger_definition
        where not trigger_definition.tgisinternal
          and trigger_definition.tgname=expected.trigger_name
          and trigger_definition.tgrelid=to_regclass('auth.users')
          and trigger_definition.tgenabled='O'
          and trigger_definition.tgfoid=expected.function_oid
          and trigger_definition.tgtype=expected.event_type
          and (
            (
              not expected.uses_email_column
              and cardinality(trigger_definition.tgattr::smallint[])=0
              and trigger_definition.tgqual is null
            )
            or (
              expected.uses_email_column
              and cardinality(trigger_definition.tgattr::smallint[])=1
              and (
                select count(*)
                from unnest(trigger_definition.tgattr::smallint[]) as update_attribute(attnum)
                join pg_attribute attribute_definition
                  on attribute_definition.attrelid=trigger_definition.tgrelid
                 and attribute_definition.attnum=update_attribute.attnum
                 and attribute_definition.attname='email'
                 and not attribute_definition.attisdropped
              )=1
              and regexp_replace(
                lower(pg_get_expr(
                  trigger_definition.tgqual,
                  trigger_definition.tgrelid,
                  true
                )),
                '[[:space:]()]',
                '',
                'g'
              )='old.emailisdistinctfromnew.email'
            )
          )
      )<>1
    )
    +
    (
      select count(*)
      from pg_trigger trigger_definition
      where not trigger_definition.tgisinternal
        and (
          trigger_definition.tgfoid=
            to_regprocedure('public.handle_sitaa_auth_user_created()')
          or trigger_definition.tgfoid=
            to_regprocedure('public.sync_sitaa_profile_email_from_auth()')
        )
        and not (
          (
            trigger_definition.tgname='on_sitaa_auth_user_created'
            and trigger_definition.tgrelid=to_regclass('auth.users')
            and trigger_definition.tgfoid=
              to_regprocedure('public.handle_sitaa_auth_user_created()')
          )
          or (
            trigger_definition.tgname='on_sitaa_auth_user_email_changed'
            and trigger_definition.tgrelid=to_regclass('auth.users')
            and trigger_definition.tgfoid=
              to_regprocedure('public.sync_sitaa_profile_email_from_auth()')
          )
        )
    )
),
checks(category,classification,aggregate_count) as (
  select 'post_0007_inventory','blocking',
    case when
      (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
       where n.nspname='public' and c.relkind='r')=18
      and (select count(*) from information_schema.columns where table_schema='public')=165
      and (select count(*) from pg_constraint c join pg_namespace n on n.oid=c.connamespace
           where n.nspname='public' and c.contype in ('p','f','u','c'))=80
      and (select count(*) from pg_indexes where schemaname='public')=43
      and (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid
           join pg_namespace n on n.oid=c.relnamespace
           where n.nspname='public' and not t.tgisinternal)=10
      and (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
           where n.nspname='public')=47
      and (select count(*) from pg_policies where schemaname='public')=23
      then 0 else 1 end
  union all select 'post_0007_privilege_inventory_drift','blocking',
    case when routine_grants=125 and table_grants=270
      and sequence_grants=6 and expanded_acl=436 then 0 else 1 end
    from post_0007_privilege_inventory
  union all select 'public_function_signature_drift','blocking',(select count(*) from signature_differences)
  union all select 'operational_function_definition_drift','blocking',(select count(*) from operational_definition_drift)
  union all select 'operational_function_acl_drift','blocking',(select count(*) from operational_acl_drift)
  union all select 'authenticated_table_grant_drift','blocking',(select count(*) from grant_differences)
  union all select 'participant_table_acl_drift','blocking',
    case when exists (
      select 1
      from pg_class table_definition
      where table_definition.oid='public.activity_participants'::regclass
        and (select count(*) from aclexplode(table_definition.relacl) acl
          where acl.grantee=table_definition.relowner
            and upper(acl.privilege_type) in (
              'SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN'
            ) and not acl.is_grantable)=8
        and (select count(*) from aclexplode(table_definition.relacl) acl
          where acl.grantee=(select oid from pg_roles where rolname='service_role')
            and upper(acl.privilege_type) in (
              'SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN'
            ) and not acl.is_grantable)=8
        and (select count(*) from aclexplode(table_definition.relacl) acl
          where acl.grantee=(select oid from pg_roles where rolname='authenticated')
            and upper(acl.privilege_type) in ('SELECT','INSERT','UPDATE','DELETE')
            and not acl.is_grantable)=4
        and not exists (
          select 1 from aclexplode(table_definition.relacl) acl
          where acl.is_grantable
             or acl.grantee not in (
               table_definition.relowner,
               (select oid from pg_roles where rolname='service_role'),
               (select oid from pg_roles where rolname='authenticated')
             )
             or (acl.grantee=table_definition.relowner and upper(acl.privilege_type) not in (
               'SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN'
             ))
             or (acl.grantee=(select oid from pg_roles where rolname='service_role')
               and upper(acl.privilege_type) not in (
                 'SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN'
               ))
             or (acl.grantee=(select oid from pg_roles where rolname='authenticated')
               and upper(acl.privilege_type) not in ('SELECT','INSERT','UPDATE','DELETE'))
        )
    ) then 0 else 1 end
  union all select 'checkin_token_direct_client_access','blocking',
    (select count(*) from information_schema.role_table_grants
     where table_schema='public' and table_name='activity_checkin_tokens'
       and grantee in ('anon','authenticated'))
  union all select 'conflicting_0008_objects','blocking',
    (case when to_regprocedure('public.is_sitaa_operational_account_active()') is not null then 1 else 0 end
     +case when to_regprocedure('public.get_admin_identity_correction_context_b2a(uuid)') is not null then 1 else 0 end
     +case when to_regprocedure('public.correct_admin_account_identity_b2a(uuid,text,text,text,text,text,uuid,text)') is not null then 1 else 0 end
     +case when to_regprocedure('public.enforce_activity_writer_integrity_b2a()') is not null then 1 else 0 end
     +(select count(*) from pg_trigger where tgrelid='public.activities'::regclass
       and tgname='enforce_activity_writer_integrity_b2a' and not tgisinternal)
     +(select count(*) from pg_policies where schemaname='public' and policyname in (
       'Active accounts may operate activities','Active accounts may operate activity participants')))
  union all select 'required_rls_disabled','blocking',
    (select count(*)
     from (values
       ('profiles'),('role_assignments'),('activities'),
       ('activity_participants'),('admin_audit_events')
     ) required(table_name)
     left join pg_class c on c.oid=to_regclass('public.'||required.table_name)
     where c.oid is null or not c.relrowsecurity)
  union all select 'auth_profile_one_to_one_inconsistency','blocking',
    ((select count(*) from public.profiles p left join auth.users u on u.id=p.id where u.id is null)
     +(select count(*) from auth.users u left join public.profiles p on p.id=u.id where p.id is null))
  union all select 'profile_auth_fk_drift','blocking',
    case when exists(
      select 1 from pg_constraint c
      where c.conrelid='public.profiles'::regclass
        and c.conname='profiles_id_fkey' and c.contype='f'
        and pg_get_constraintdef(c.oid)='FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE'
    ) then 0 else 1 end
  union all select 'role_assignment_profile_fk_drift','blocking',
    case when exists(
      select 1 from pg_constraint c
      where c.conrelid='public.role_assignments'::regclass
        and c.conname='role_assignments_user_id_fkey' and c.contype='f'
        and pg_get_constraintdef(c.oid)='FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE'
    ) then 0 else 1 end
  union all select 'orphan_role_assignment_user_ids','blocking',
    (select count(*) from public.role_assignments ra
     left join public.profiles p on p.id=ra.user_id where p.id is null)
  union all select 'activity_policy_drift','blocking',
    case when (select count(*) from pg_policies where schemaname='public' and tablename='activities'
      and permissive='PERMISSIVE' and roles='{authenticated}')=4
      and exists(select 1 from pg_policies where schemaname='public' and tablename='activities'
        and policyname='Authorized users can create activities' and cmd='INSERT'
        and with_check='((created_by = auth.uid()) AND can_create_activity(scope_type, program_id, division_id, service_type_code))')
      and exists(select 1 from pg_policies where schemaname='public' and tablename='activities'
        and policyname='Authorized users can delete activities' and cmd='DELETE' and qual='can_delete_activity(id)')
      and exists(select 1 from pg_policies where schemaname='public' and tablename='activities'
        and policyname='Authorized users can update activities' and cmd='UPDATE'
        and qual='can_update_activity_base(id)' and with_check='can_update_activity_base(id)')
      and exists(select 1 from pg_policies where schemaname='public' and tablename='activities'
        and policyname='Users can read permitted activities' and cmd='SELECT'
        and qual='(((status_code = ''draft''::text) AND (created_by = auth.uid())) OR ((status_code <> ''draft''::text) AND ((created_by = auth.uid()) OR (responsible_profile_id = auth.uid()) OR is_activity_participant(id) OR can_manage_activity(scope_type, program_id, division_id, service_type_code))))')
      then 0 else 1 end
  union all select 'participant_policy_drift','blocking',
    case when (select count(*) from pg_policies where schemaname='public' and tablename='activity_participants'
      and permissive='PERMISSIVE' and roles='{authenticated}')=4
      and exists(select 1 from pg_policies where schemaname='public' and tablename='activity_participants'
        and policyname='Users can add permitted activity participants' and cmd='INSERT' and with_check='can_edit_activity(activity_id)')
      and exists(select 1 from pg_policies where schemaname='public' and tablename='activity_participants'
        and policyname='Users can delete permitted activity participants' and cmd='DELETE' and qual='can_edit_activity(activity_id)')
      and exists(select 1 from pg_policies where schemaname='public' and tablename='activity_participants'
        and policyname='Users can read permitted activity participants' and cmd='SELECT'
        and qual='((profile_id = auth.uid()) OR can_read_activity(activity_id))')
      and exists(select 1 from pg_policies where schemaname='public' and tablename='activity_participants'
        and policyname='Users can update permitted activity participants' and cmd='UPDATE'
        and qual='can_edit_activity(activity_id)' and with_check='can_edit_activity(activity_id)')
      then 0 else 1 end
  union all select 'own_profile_policy_drift','blocking',
    case when (select count(*) from pg_policies
        where schemaname='public' and tablename='profiles')=2
      and exists(select 1 from pg_policies where schemaname='public' and tablename='profiles'
      and policyname='Users can read own profile' and permissive='PERMISSIVE'
      and roles='{authenticated}' and cmd='SELECT' and qual='(auth.uid() = id)')
      and exists(select 1 from pg_policies where schemaname='public' and tablename='profiles'
      and policyname='Users can update own basic profile' and permissive='PERMISSIVE'
      and roles='{authenticated}' and cmd='UPDATE' and qual='(auth.uid() = id)'
      and with_check='(auth.uid() = id)') then 0 else 1 end
  union all select 'own_assignment_policy_drift','blocking',
    case when (select count(*) from pg_policies
        where schemaname='public' and tablename='role_assignments')=1
      and exists(select 1 from pg_policies where schemaname='public' and tablename='role_assignments'
      and policyname='Users can read own role assignments' and permissive='PERMISSIVE'
      and roles='{authenticated}' and cmd='SELECT' and qual='(auth.uid() = user_id)') then 0 else 1 end
  union all select 'profile_lifecycle_inconsistency','blocking',
    (select count(*) from public.profiles p
     where (p.account_status='active' and (not p.is_active or p.activated_at is null or p.deactivated_at is not null))
        or (p.account_status='pending_registration' and (p.is_active or p.activated_at is not null or p.deactivated_at is not null))
        or (p.account_status='inactive' and (p.is_active or p.deactivated_at is null)))
  union all select 'institutional_identity_inconsistency','blocking',
    (select count(*) from public.profiles p
     left join public.academic_programs program on program.id=p.primary_program_id
     where p.account_kind='institutional' and p.account_status in ('active','inactive')
       and (p.first_names is null or p.paternal_surname is null
         or p.full_name is null or char_length(p.full_name) not between 2 and 200
         or p.full_name<>concat_ws(' ',p.first_names,p.paternal_surname,p.maternal_surname)
         or p.person_type not in ('student','professor')
         or p.institutional_id_value is null or p.institutional_id_value !~ '^[0-9]{1,50}$'
         or program.id is null or not program.is_active
         or (p.person_type='student' and p.institutional_id_type<>'student_account')
         or (p.person_type='professor' and p.institutional_id_type<>'worker_number')))
  union all select 'technical_identity_inconsistency','blocking',
    (select count(*) from public.profiles p
     where p.account_kind='technical' and p.account_status in ('active','inactive')
       and (p.first_names is null
         or p.full_name is null or char_length(p.full_name) not between 2 and 200
         or p.full_name<>concat_ws(' ',p.first_names,p.paternal_surname,p.maternal_surname)
          or p.person_type is not null or p.primary_program_id is not null
          or p.institutional_id_type is not null or p.institutional_id_value is not null))
  union all select 'participant_identity_dependency_inconsistency','blocking',
    (select count(*)
     from public.activity_participants participant
     join public.activities activity on activity.id=participant.activity_id
     join public.profiles profile on profile.id=participant.profile_id
     left join public.academic_programs program on program.id=profile.primary_program_id
     where (
       activity.status_code='draft'
       or not coalesce(
         (
           coalesce(activity.end_date,activity.start_date)::timestamp
           + coalesce(activity.end_time,activity.start_time,time '23:59:59')
         ) < (now() at time zone 'America/Mexico_City'),
         false
       )
     )
     and (
       profile.primary_program_id is null
       or (activity.scope_type='program'
         and profile.primary_program_id is distinct from activity.program_id)
       or (activity.scope_type='division'
         and program.division_id is distinct from activity.division_id)
       or (participant.participant_role_code='responsible'
          and profile.person_type is distinct from 'professor')
      ))
  union all select 'participant_explicit_column_acl_drift','blocking',
    (select count(*)
     from pg_attribute attribute_definition
     cross join lateral aclexplode(attribute_definition.attacl) acl
     where attribute_definition.attrelid='public.activity_participants'::regclass
       and attribute_definition.attnum>0
       and not attribute_definition.attisdropped)
  union all select 'participant_unexplained_column_privilege_drift','blocking',
    (with table_derived as (
         select coalesce(grantee_role.rolname,'PUBLIC')::text grantee,
           attribute_definition.attname::text column_name,
           upper(table_acl.privilege_type)::text privilege_type,
           case when pg_has_role(
             table_acl.grantee,table_definition.relowner,'USAGE'
           ) or table_acl.is_grantable then 'YES' else 'NO' end is_grantable
       from pg_class table_definition
       join pg_attribute attribute_definition
         on attribute_definition.attrelid=table_definition.oid
        and attribute_definition.attnum>0
        and not attribute_definition.attisdropped
       cross join lateral aclexplode(coalesce(
         table_definition.relacl,
         acldefault('r',table_definition.relowner)
       )) table_acl
       left join pg_roles grantee_role on grantee_role.oid=table_acl.grantee
       where table_definition.oid='public.activity_participants'::regclass
         and upper(table_acl.privilege_type) in ('SELECT','INSERT','UPDATE','REFERENCES')
     ), observed as (
         select grantee::text,column_name::text,
           upper(privilege_type::text) privilege_type,is_grantable::text
       from information_schema.column_privileges
       where table_schema='public' and table_name='activity_participants'
     )
     select count(*) from (
       select * from observed
       except
       select * from table_derived
     ) unexplained)
  union all select 'participant_effective_column_privilege_drift','blocking',
    (select count(*)
     from pg_attribute attribute_definition
     cross join (
       select role_definition.oid role_oid from pg_roles role_definition
       union all select 0::oid
     ) actor
     cross join (values ('SELECT'),('INSERT'),('UPDATE'),('REFERENCES')) permission(privilege_type)
     where attribute_definition.attrelid='public.activity_participants'::regclass
       and attribute_definition.attnum>0
       and not attribute_definition.attisdropped
       and (
         coalesce(has_column_privilege(
           actor.role_oid,attribute_definition.attrelid,
           attribute_definition.attnum,permission.privilege_type
         ),false) is distinct from coalesce(has_table_privilege(
           actor.role_oid,attribute_definition.attrelid,permission.privilege_type
         ),false)
         or (
           actor.role_oid in (
             0::oid,(select oid from pg_roles where rolname='anon')
           )
           and coalesce(has_table_privilege(
             actor.role_oid,attribute_definition.attrelid,permission.privilege_type
           ),false)
         )
       ))
  union all select 'profile_identity_constraint_drift','blocking',
    case when (select count(*) from pg_constraint
      where conrelid='public.profiles'::regclass and conname in (
        'profiles_account_identity_check','profiles_account_kind_check',
        'profiles_account_lifecycle_check','profiles_account_status_check',
        'profiles_first_names_check','profiles_paternal_surname_check',
        'profiles_maternal_surname_check','profiles_full_name_check',
        'profiles_identifier_digits_check','profiles_identifier_length_check',
        'profiles_institutional_id_type_check','profiles_person_type_check',
        'profiles_structured_full_name_check'))=13
      and to_regclass('public.profiles_institutional_identifier_pair_key') is not null
      then 0 else 1 end
  union all select 'profile_column_privilege_drift','blocking',
    case when has_column_privilege('authenticated','public.profiles','first_names','UPDATE')
      and has_column_privilege('authenticated','public.profiles','paternal_surname','UPDATE')
      and has_column_privilege('authenticated','public.profiles','maternal_surname','UPDATE')
      and not has_column_privilege('authenticated','public.profiles','full_name','UPDATE')
      and not has_column_privilege('authenticated','public.profiles','person_type','UPDATE')
      and not has_column_privilege('authenticated','public.profiles','primary_program_id','UPDATE')
      then 0 else 1 end
  union all select 'b1_audit_contract_drift','blocking',
    case when to_regclass('public.admin_audit_events') is not null
      and (select count(*) from information_schema.columns
        where table_schema='public' and table_name='admin_audit_events')=9
      and (select count(*) from pg_policies
        where schemaname='public' and tablename='admin_audit_events')=0
      and not has_table_privilege('authenticated','public.admin_audit_events','SELECT')
      and not has_table_privilege('authenticated','public.admin_audit_events','INSERT')
      and has_table_privilege('service_role','public.admin_audit_events','SELECT')
      and has_table_privilege('service_role','public.admin_audit_events','INSERT')
      and not has_table_privilege('service_role','public.admin_audit_events','UPDATE')
      and not has_table_privilege('service_role','public.admin_audit_events','DELETE')
      then 0 else 1 end
  union all select 'b1_audit_exact_acl_drift','blocking',
    case when exists(
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
    ) then 0 else 1 end
  union all select 'b1_exact_object_drift','blocking',
    case when (select count(*) from pg_constraint
        where conrelid='public.admin_audit_events'::regclass)=8
      and (select count(*) from pg_trigger
        where tgrelid='public.admin_audit_events'::regclass and not tgisinternal)=2
      and to_regclass('public.admin_audit_events_target_occurred_idx') is not null
      and to_regclass('public.admin_audit_events_actor_occurred_idx') is not null
      and to_regclass('public.profiles_admin_directory_sort_idx') is not null
      and to_regclass('public.profiles_admin_directory_filters_idx') is not null
      and to_regprocedure('public.admin_audit_metadata_is_safe(jsonb)') is not null
      and to_regprocedure('public.prevent_admin_audit_event_mutation()') is not null
      and to_regprocedure('public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)') is not null
      and to_regprocedure('public.get_admin_account_detail_b1(uuid)') is not null
      and to_regprocedure('public.get_admin_account_assignments_b1(uuid)') is not null
      and to_regprocedure('public.get_admin_account_audit_history_b1(uuid,integer,integer)') is not null
      then 0 else 1 end
  union all select 'b1_authority_contract_drift','blocking',
    case when to_regprocedure('public.is_b1_account_admin()') is not null
      and to_regprocedure('public.sitaa_current_mexico_date()') is not null
      and not has_function_privilege('authenticated','public.is_b1_account_admin()','EXECUTE')
      and has_function_privilege('authenticated','public.get_admin_account_detail_b1(uuid)','EXECUTE')
      then 0 else 1 end
  union all select 'b1_rpc_acl_drift','blocking',
    case when has_function_privilege('authenticated','public.search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)','EXECUTE')
      and has_function_privilege('authenticated','public.get_admin_account_detail_b1(uuid)','EXECUTE')
      and has_function_privilege('authenticated','public.get_admin_account_assignments_b1(uuid)','EXECUTE')
      and has_function_privilege('authenticated','public.get_admin_account_audit_history_b1(uuid,integer,integer)','EXECUTE')
      and not has_function_privilege('anon','public.get_admin_account_detail_b1(uuid)','EXECUTE')
      and not has_function_privilege('service_role','public.get_admin_account_detail_b1(uuid)','EXECUTE')
      and not has_function_privilege('authenticated','public.is_b1_account_admin()','EXECUTE')
      then 0 else 1 end
  union all select 'registration_trigger_drift','blocking',
    (select aggregate_count from registration_trigger_contract_drift)
  union all select 'service_role_bypass_missing','blocking',
    case when exists(select 1 from pg_roles where rolname='service_role' and rolbypassrls)
      then 0 else 1 end
  union all select 'required_catalog_contract_drift','blocking',
    case when (select count(*) from public.roles)=10
      and exists(select 1 from public.roles where code='technical_admin')
      and (select count(*) from public.academic_programs where is_active)>0
      and exists(select 1 from public.participant_roles where code='responsible' and is_active)
      then 0 else 1 end
  union all select 'inactive_profiles_with_current_or_future_assignments','informational',
    (select count(distinct p.id) from public.profiles p
      join public.role_assignments ra on ra.user_id=p.id
      where p.account_status='inactive' and ra.is_active
        and (ra.ends_at is null or ra.ends_at>=public.sitaa_current_mexico_date()))
  union all select 'profiles_with_open_responsibilities','informational',
    (select count(distinct a.responsible_profile_id) from public.activities a
      where a.status_code='draft'
         or not coalesce(
           (
             coalesce(a.end_date,a.start_date)::timestamp
             + coalesce(a.end_time,a.start_time,time '23:59:59')
           ) < (now() at time zone 'America/Mexico_City'),
           false
         ))
  union all select 'profiles_with_open_participations','informational',
    (select count(distinct participant.profile_id)
      from public.activity_participants participant
      join public.activities a on a.id=participant.activity_id
      where a.status_code='draft'
         or not coalesce(
           (
             coalesce(a.end_date,a.start_date)::timestamp
             + coalesce(a.end_time,a.start_time,time '23:59:59')
           ) < (now() at time zone 'America/Mexico_City'),
           false
         ))
  union all select 'historical_participant_identity_inconsistency','informational',
    (select count(*)
     from public.activity_participants participant
     join public.activities activity on activity.id=participant.activity_id
     join public.profiles profile on profile.id=participant.profile_id
     left join public.academic_programs program on program.id=profile.primary_program_id
     where activity.status_code<>'draft'
       and coalesce(
         (
           coalesce(activity.end_date,activity.start_date)::timestamp
           + coalesce(activity.end_time,activity.start_time,time '23:59:59')
         ) < (now() at time zone 'America/Mexico_City'),
         false
       )
       and (
         profile.primary_program_id is null
         or (activity.scope_type='program'
           and profile.primary_program_id is distinct from activity.program_id)
         or (activity.scope_type='division'
           and program.division_id is distinct from activity.division_id)
         or (participant.participant_role_code='responsible'
           and profile.person_type is distinct from 'professor')
       ))
  union all select 'institutional_profiles_potentially_dependency_blocked','informational',
    (select count(distinct p.id)
      from public.profiles p
      left join public.role_assignments ra on ra.user_id=p.id and ra.is_active
        and (ra.ends_at is null or ra.ends_at>=public.sitaa_current_mexico_date())
      left join public.activity_participants participant
        on participant.profile_id=p.id
        and exists (
          select 1 from public.activities participant_activity
          where participant_activity.id=participant.activity_id
            and (
              participant_activity.status_code='draft'
              or not coalesce(
                (
                  coalesce(participant_activity.end_date,participant_activity.start_date)::timestamp
                  + coalesce(participant_activity.end_time,participant_activity.start_time,time '23:59:59')
                ) < (now() at time zone 'America/Mexico_City'),
                false
              )
            )
        )
      left join public.activities responsible
        on responsible.responsible_profile_id=p.id
        and (
          responsible.status_code='draft'
          or not coalesce(
            (
              coalesce(responsible.end_date,responsible.start_date)::timestamp
              + coalesce(responsible.end_time,responsible.start_time,time '23:59:59')
            ) < (now() at time zone 'America/Mexico_City'),
            false
          )
        )
      where p.account_kind='institutional'
        and (ra.id is not null or participant.id is not null or responsible.id is not null))
)
select category,classification,aggregate_count
from checks
order by case classification when 'blocking' then 0 else 1 end,category;

rollback;
