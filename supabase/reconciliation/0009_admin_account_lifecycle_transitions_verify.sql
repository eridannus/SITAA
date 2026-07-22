-- Verificador transaccional 0009. No persiste fixtures ni eventos.
begin;

do $static_contract$
declare
  context_oid oid:=to_regprocedure('public.get_admin_account_lifecycle_context_b2b(uuid)');
  mutation_oid oid:=to_regprocedure('public.transition_admin_account_lifecycle_b2b(uuid,text,text)');
  helper_oid oid:=to_regprocedure('public.is_exact_b1_account_admin_profile_b2b(uuid)');
  mismatch_count integer;
begin
  if helper_oid is null or context_oid is null or mutation_oid is null then
    raise exception '0009_verify_missing_function';
  end if;
  if (select count(*) from information_schema.tables where table_schema='public' and table_type='BASE TABLE')<>18
     or (select count(*) from information_schema.columns where table_schema='public')<>165
     or (select count(*) from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname='public' and c.contype in ('p','f','u','c'))<>80
     or (select count(*) from pg_indexes where schemaname='public')<>43
     or (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal)<>11
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>54
     or (select count(*) from pg_policies where schemaname='public')<>25
     or (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and c.relrowsecurity)<>18
     or (select count(*) from information_schema.routine_privileges where routine_schema='public')<>137
     or (select count(*) from information_schema.table_privileges where table_schema='public')<>267
     or (select count(*) from information_schema.usage_privileges where object_schema='public' and object_type='SEQUENCE')<>6
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public')+(select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault(case when c.relkind='S' then 's'::"char" else 'r'::"char" end,c.relowner))) a where n.nspname='public' and c.relkind in ('r','p','v','m','S'))<>445 then
    raise exception '0009_verify_inventory_mismatch';
  end if;
  if exists (
    select 1 from pg_proc p
    where p.oid in (helper_oid,context_oid,mutation_oid)
      and (not p.prosecdef or p.proconfig<>array['search_path=pg_catalog, public']::text[])
  ) then
    raise exception '0009_verify_function_security_mismatch';
  end if;
  if has_function_privilege('anon',context_oid,'EXECUTE')
     or has_function_privilege('anon',mutation_oid,'EXECUTE')
     or has_function_privilege('service_role',context_oid,'EXECUTE')
     or has_function_privilege('service_role',mutation_oid,'EXECUTE')
     or has_function_privilege('authenticated',helper_oid,'EXECUTE')
     or not has_function_privilege('authenticated',context_oid,'EXECUTE')
     or not has_function_privilege('authenticated',mutation_oid,'EXECUTE')
     or exists (
       select 1 from pg_proc p
       cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
       where p.oid in (helper_oid,context_oid,mutation_oid)
         and acl.privilege_type='EXECUTE'
         and (
           p.oid=helper_oid and acl.grantee<>p.proowner
           or p.oid in (context_oid,mutation_oid)
             and acl.grantee not in (p.proowner,'authenticated'::regrole)
         )
     ) then
    raise exception '0009_verify_function_acl_mismatch';
  end if;
  if pg_get_function_result(context_oid)<>
    'TABLE(target_profile_id uuid, account_kind text, account_status text, is_self boolean, can_deactivate boolean, can_reactivate boolean, denial_code text, has_exact_b1_assignment boolean, active_exact_b1_admin_count bigint, current_or_future_assignment_count bigint, open_responsibility_count bigint, open_participation_count bigint)'
     or pg_get_function_result(mutation_oid)<>
    'TABLE(target_profile_id uuid, audit_event_id uuid, previous_status text, new_status text, changed_fields text[], updated_at timestamp with time zone)' then
    raise exception '0009_verify_result_contract_mismatch';
  end if;
  if (select p.provolatile<>'s' or pg_get_function_identity_arguments(p.oid)<>'requested_profile_id uuid' from pg_proc p where p.oid=helper_oid)
     or (select p.provolatile<>'s' or pg_get_function_identity_arguments(p.oid)<>'requested_profile_id uuid' from pg_proc p where p.oid=context_oid)
     or (select p.provolatile<>'v' or pg_get_function_identity_arguments(p.oid)<>'requested_profile_id uuid, requested_transition text, transition_reason text' from pg_proc p where p.oid=mutation_oid) then
    raise exception '0009_verify_function_signature_mismatch';
  end if;
  select count(*) into mismatch_count
  from (values
    ('is_exact_b1_account_admin_profile_b2b(uuid)','104d16a531ea53a5b4908102322097dc'),
    ('get_admin_account_lifecycle_context_b2b(uuid)','6e7c8bb5e2dcf99fce6a75e03e07c309'),
    ('transition_admin_account_lifecycle_b2b(uuid,text,text)','0080f41a2cd78576763ebb5d5128996e')
  ) expected(signature,body_hash)
  left join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
  where p.oid is null or md5(regexp_replace(p.prosrc,'\s+','','g'))<>expected.body_hash;
  if mismatch_count<>0 then
    raise exception '0009_verify_function_body_mismatch';
  end if;
  select count(*) into mismatch_count
  from (values
    ('is_sitaa_operational_account_active()','f85f733578f09c0f7466af7e18a90f4c'),
    ('get_admin_identity_correction_context_b2a(uuid)','83932d04ff8f1b33793e8c7a49bb8e68'),
    ('correct_admin_account_identity_b2a(uuid,text,text,text,text,text,uuid,text)','ce05cbc529473c070953e765e3ee05b2'),
    ('enforce_activity_writer_integrity_b2a()','c58bd04859f1e2a044fcca58d3333e3c'),
    ('is_b1_account_admin()','0486f72652abc79ed3d1334704d55fbe')
  ) expected(signature,body_hash)
  left join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
  where p.oid is null or md5(regexp_replace(p.prosrc,'\s+','','g'))<>expected.body_hash;
  if mismatch_count<>0 then
    raise exception '0009_verify_prior_function_contract_mismatch';
  end if;
end;
$static_contract$;

create temporary table sitaa_0009_context(
  run_marker text not null,
  program_id uuid not null,
  invalid_program_id uuid not null,
  division_id uuid not null,
  activity_id uuid not null,
  institutional_today date not null
) on commit drop;
insert into sitaa_0009_context
select substr(replace(gen_random_uuid()::text,'-',''),1,12),program.id,
  gen_random_uuid(),program.division_id,gen_random_uuid(),
  public.sitaa_current_mexico_date()
from public.academic_programs program
where program.is_active=true
order by program.id
limit 1;

do $fixture_prerequisite$
begin
  if (select count(*) from sitaa_0009_context)<>1 then
    raise exception '0009_verify_active_program_fixture_missing';
  end if;
end;
$fixture_prerequisite$;

insert into public.academic_programs(id,division_id,code,name,is_active)
select invalid_program_id,division_id,'sitaa-0009-'||run_marker,
  'Programa sintético 0009',true
from pg_temp.sitaa_0009_context;

create temporary table sitaa_0009_cases(
  label text primary key,
  id uuid not null unique,
  email text not null unique,
  identifier text null unique
) on commit drop;
create temporary table sitaa_0009_results(
  transition text primary key,
  target_profile_id uuid not null,
  audit_event_id uuid not null,
  previous_status text not null,
  new_status text not null,
  changed_fields text[] not null,
  updated_at timestamptz not null
) on commit drop;

create function pg_temp.case_id(target_label text)
returns uuid language sql stable set search_path=pg_temp as $$
  select id from sitaa_0009_cases where label=target_label
$$;
create function pg_temp.set_request_user(target_label text)
returns void language plpgsql set search_path=pg_temp,pg_catalog as $$
declare target_id uuid:=pg_temp.case_id(target_label);
begin
  perform set_config('request.jwt.claim.sub',target_id::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',target_id,'role','authenticated')::text,true);
end;
$$;
grant select on table pg_temp.sitaa_0009_cases to authenticated;
grant select on table pg_temp.sitaa_0009_context to authenticated;
grant select,insert on table pg_temp.sitaa_0009_results to authenticated;
grant execute on function pg_temp.case_id(text),pg_temp.set_request_user(text) to authenticated;

create function pg_temp.create_case(
  target_label text,
  target_kind text,
  target_person text default null,
  target_status text default 'active',
  target_confirmed boolean default true
)
returns uuid language plpgsql
set search_path=public,auth,pg_temp,pg_catalog
as $$
declare
  target_id uuid:=gen_random_uuid();
  marker text:=(select run_marker from sitaa_0009_context);
  target_email text:=replace(target_label,'_','-')||'-'||marker||'@example.invalid';
  target_identifier text:=case when target_kind='institutional'
    then '9'||substr((('x'||substr(md5(target_id::text),1,15))::bit(60)::bigint)::text,1,15)
    else null end;
begin
  insert into sitaa_0009_cases values(target_label,target_id,target_email,target_identifier);
  insert into auth.users(
    id,aud,role,email,encrypted_password,email_confirmed_at,
    raw_app_meta_data,raw_user_meta_data,created_at,updated_at
  ) values(
    target_id,'authenticated','authenticated',target_email,'',
    case when target_confirmed then now() else null end,
    case when target_kind='technical'
      then jsonb_build_object('sitaa_account_kind','technical','sitaa_first_names','Soporte 0009')
      else jsonb_build_object('provider','google','providers',jsonb_build_array('google')) end,
    jsonb_build_object('name','Cuenta sintética 0009'),now(),now()
  );

  if target_kind='institutional' and target_status<>'pending_registration' then
    update public.profiles set
      first_names='Persona',paternal_surname='Prueba',maternal_surname=null,
      full_name='Persona Prueba',account_kind='institutional',
      account_status=target_status,person_type=target_person,
      primary_program_id=(select program_id from sitaa_0009_context),
      institutional_id_type=case when target_person='student' then 'student_account' else 'worker_number' end,
      institutional_id_value=target_identifier,is_active=(target_status='active'),
      activated_at=now(),deactivated_at=case when target_status='inactive' then now() else null end
    where id=target_id;
  elsif target_kind='technical' and target_status='inactive' then
    update public.profiles set account_status='inactive',is_active=false,
      deactivated_at=now() where id=target_id;
  end if;
  return target_id;
end;
$$;

select pg_temp.create_case('admin_a','technical');
select pg_temp.create_case('admin_b','technical');
select pg_temp.create_case('admin_malformed','technical');
select pg_temp.create_case('admin_inactive','technical',null,'inactive');
select pg_temp.create_case('ordinary','institutional','professor');
select pg_temp.create_case('ordinary_student','institutional','student');
select pg_temp.create_case('active_target','institutional','professor');
select pg_temp.create_case('inactive_target','institutional','professor','inactive');
select pg_temp.create_case('active_technical','technical');
select pg_temp.create_case('inactive_technical','technical',null,'inactive');
select pg_temp.create_case('inactive_unconfirmed','institutional','student','inactive',false);
select pg_temp.create_case('inactive_invalid_identity','institutional','student','inactive');
select pg_temp.create_case('pending_target','institutional',null,'pending_registration');
select pg_temp.create_case('invalid_lifecycle','technical',null,'inactive');
update public.profiles
set activated_at=null
where id=pg_temp.case_id('invalid_lifecycle');
update public.profiles
set primary_program_id=(select invalid_program_id from pg_temp.sitaa_0009_context)
where id=pg_temp.case_id('inactive_invalid_identity');
update public.academic_programs
set is_active=false
where id=(select invalid_program_id from pg_temp.sitaa_0009_context);

insert into public.role_assignments(
  user_id,role_code,scope_type,service_area,division_id,program_id,
  starts_at,ends_at,is_active,assigned_by
) values
(pg_temp.case_id('admin_a'),'technical_admin','system','technical',null,null,
 (select institutional_today from sitaa_0009_context),null,true,pg_temp.case_id('admin_a')),
(pg_temp.case_id('admin_b'),'technical_admin','system','technical',null,null,
 (select institutional_today from sitaa_0009_context),null,true,pg_temp.case_id('admin_a')),
(pg_temp.case_id('admin_b'),'technical_admin','system','technical',null,null,
 (select institutional_today from sitaa_0009_context),null,true,pg_temp.case_id('admin_b')),
(pg_temp.case_id('admin_malformed'),'technical_admin','own','technical',null,null,
 (select institutional_today from sitaa_0009_context),null,true,pg_temp.case_id('admin_a')),
(pg_temp.case_id('admin_inactive'),'technical_admin','system','technical',null,null,
 (select institutional_today from sitaa_0009_context),null,true,pg_temp.case_id('admin_a')),
(pg_temp.case_id('active_target'),'professor','program','both',null,
 (select program_id from sitaa_0009_context),
 (select institutional_today from sitaa_0009_context),null,true,pg_temp.case_id('admin_a')),
(pg_temp.case_id('active_target'),'professor','program','both',null,
 (select program_id from sitaa_0009_context),
 (select institutional_today+5 from sitaa_0009_context),null,true,pg_temp.case_id('admin_a')),
(pg_temp.case_id('active_target'),'professor','program','both',null,
 (select program_id from sitaa_0009_context),
 (select institutional_today-20 from sitaa_0009_context),
 (select institutional_today-1 from sitaa_0009_context),true,pg_temp.case_id('admin_a')),
(pg_temp.case_id('active_target'),'professor','program','both',null,
 (select program_id from sitaa_0009_context),
 (select institutional_today from sitaa_0009_context),null,false,pg_temp.case_id('admin_a'));

insert into public.activities(
  id,title,status_code,program_id,scope_type,division_id,
  responsible_profile_id,created_by
) select activity_id,'Actividad sintética 0009','draft',program_id,'program',division_id,
  pg_temp.case_id('active_target'),pg_temp.case_id('active_target')
from pg_temp.sitaa_0009_context;

insert into public.activity_participants(
  activity_id,profile_id,participant_role_code,added_by
) select activity_id,pg_temp.case_id('active_target'),'responsible',pg_temp.case_id('admin_a')
from pg_temp.sitaa_0009_context;

create temporary table sitaa_0009_invariants(
  object_name text primary key,
  object_hash text not null
) on commit drop;
insert into sitaa_0009_invariants values
('auth_user',(select md5(row_to_json(auth_user)::text) from auth.users auth_user where auth_user.id=pg_temp.case_id('active_target'))),
('auth_identities',(select md5(coalesce(string_agg(row_to_json(identity_row)::text,'|' order by identity_row.id::text),'')) from auth.identities identity_row where identity_row.user_id=pg_temp.case_id('active_target'))),
('identity',(select md5(jsonb_build_object('id',profile.id,'email',profile.email,'account_kind',profile.account_kind,'first_names',profile.first_names,'paternal_surname',profile.paternal_surname,'maternal_surname',profile.maternal_surname,'full_name',profile.full_name,'person_type',profile.person_type,'institutional_id_type',profile.institutional_id_type,'institutional_id_value',profile.institutional_id_value,'primary_program_id',profile.primary_program_id)::text) from public.profiles profile where profile.id=pg_temp.case_id('active_target'))),
('assignments',(select md5(coalesce(string_agg(row_to_json(assignment)::text,'|' order by assignment.id),'')) from public.role_assignments assignment where assignment.user_id=pg_temp.case_id('active_target'))),
('activities',(select md5(coalesce(string_agg(row_to_json(activity)::text,'|' order by activity.id),'')) from public.activities activity where activity.id=(select activity_id from sitaa_0009_context))),
('participants',(select md5(coalesce(string_agg(row_to_json(participant)::text,'|' order by participant.id),'')) from public.activity_participants participant where participant.activity_id=(select activity_id from sitaa_0009_context)));

-- Actor ordinario: ni contexto ni mutación atraviesan la autorización interna.
select pg_temp.set_request_user('ordinary');
set local role authenticated;
do $ordinary_denied$
declare
  actor_label text;
  missing_target uuid:=gen_random_uuid();
begin
  foreach actor_label in array array['ordinary','ordinary_student','admin_malformed','admin_inactive'] loop
    perform pg_temp.set_request_user(actor_label);
    begin
      perform public.get_admin_account_lifecycle_context_b2b(pg_temp.case_id('active_target'));
      raise exception '0009_verify_expected_context_denial';
    exception when insufficient_privilege then
      if sqlerrm<>'sitaa_admin_access_denied' then raise; end if;
    end;
    begin
      perform public.get_admin_account_lifecycle_context_b2b(missing_target);
      raise exception '0009_verify_expected_missing_context_denial';
    exception when insufficient_privilege then
      if sqlerrm<>'sitaa_admin_access_denied' then raise; end if;
    end;
    begin
      perform public.transition_admin_account_lifecycle_b2b(
        pg_temp.case_id('active_target'),'deactivate','Motivo sintético válido 0009'
      );
      raise exception '0009_verify_expected_mutation_denial';
    exception when insufficient_privilege then
      if sqlerrm<>'sitaa_admin_access_denied' then raise; end if;
    end;
  end loop;
end;
$ordinary_denied$;
reset role;

select pg_temp.set_request_user('admin_a');
set local role authenticated;

do $context_contract$
declare context_row record;
begin
  select * into context_row
  from public.get_admin_account_lifecycle_context_b2b(pg_temp.case_id('active_target'));
  if context_row.target_profile_id is distinct from pg_temp.case_id('active_target')
     or not context_row.can_deactivate or context_row.can_reactivate
     or context_row.current_or_future_assignment_count<>2
     or context_row.active_exact_b1_admin_count<>2
     or context_row.open_responsibility_count<>1
     or context_row.open_participation_count<>1
     or context_row.denial_code is not null then
    raise exception '0009_verify_active_context_failed';
  end if;

  select * into context_row
  from public.get_admin_account_lifecycle_context_b2b(pg_temp.case_id('inactive_target'));
  if context_row.can_deactivate or not context_row.can_reactivate
     or context_row.denial_code is not null then
    raise exception '0009_verify_inactive_context_failed';
  end if;

  select * into context_row
  from public.get_admin_account_lifecycle_context_b2b(pg_temp.case_id('active_technical'));
  if not context_row.can_deactivate or context_row.can_reactivate then
    raise exception '0009_verify_active_technical_context_failed';
  end if;

  select * into context_row
  from public.get_admin_account_lifecycle_context_b2b(pg_temp.case_id('inactive_technical'));
  if context_row.can_deactivate or not context_row.can_reactivate then
    raise exception '0009_verify_inactive_technical_context_failed';
  end if;

  select * into context_row
  from public.get_admin_account_lifecycle_context_b2b(pg_temp.case_id('admin_inactive'));
  if not context_row.has_exact_b1_assignment or not context_row.can_reactivate then
    raise exception '0009_verify_inactive_exact_admin_context_failed';
  end if;

  select * into context_row
  from public.get_admin_account_lifecycle_context_b2b(pg_temp.case_id('pending_target'));
  if context_row.can_deactivate or context_row.can_reactivate
     or context_row.denial_code<>'pending_target' then
    raise exception '0009_verify_pending_context_failed';
  end if;

  select * into context_row
  from public.get_admin_account_lifecycle_context_b2b(pg_temp.case_id('invalid_lifecycle'));
  if context_row.can_deactivate or context_row.can_reactivate
     or context_row.denial_code<>'invalid_lifecycle' then
    raise exception '0009_verify_invalid_lifecycle_context_failed';
  end if;

  select * into context_row
  from public.get_admin_account_lifecycle_context_b2b(pg_temp.case_id('inactive_invalid_identity'));
  if context_row.can_deactivate or context_row.can_reactivate
     or context_row.denial_code<>'invalid_identity' then
    raise exception '0009_verify_invalid_identity_context_failed';
  end if;

  select * into context_row
  from public.get_admin_account_lifecycle_context_b2b(pg_temp.case_id('admin_a'));
  if not context_row.is_self or context_row.denial_code<>'self_forbidden' then
    raise exception '0009_verify_self_context_failed';
  end if;
end;
$context_contract$;

do $input_contract$
begin
  begin
    perform public.transition_admin_account_lifecycle_b2b(pg_temp.case_id('active_target'),'disable','Motivo sintético válido 0009');
    raise exception '0009_verify_expected_invalid_transition';
  exception when invalid_parameter_value then
    if sqlerrm<>'sitaa_account_lifecycle_invalid_transition' then raise; end if;
  end;
  begin
    perform public.transition_admin_account_lifecycle_b2b(pg_temp.case_id('active_target'),'deactivate','corto');
    raise exception '0009_verify_expected_invalid_reason';
  exception when invalid_parameter_value then
    if sqlerrm<>'sitaa_account_lifecycle_invalid_reason' then raise; end if;
  end;
  begin
    perform public.transition_admin_account_lifecycle_b2b(pg_temp.case_id('active_target'),null,'Motivo sintético válido 0009');
    raise exception '0009_verify_expected_null_transition';
  exception when invalid_parameter_value then
    if sqlerrm<>'sitaa_account_lifecycle_invalid_transition' then raise; end if;
  end;
  begin
    perform public.transition_admin_account_lifecycle_b2b(pg_temp.case_id('active_target'),'deactivate','   ');
    raise exception '0009_verify_expected_blank_reason';
  exception when invalid_parameter_value then
    if sqlerrm<>'sitaa_account_lifecycle_invalid_reason' then raise; end if;
  end;
  begin
    perform public.transition_admin_account_lifecycle_b2b(pg_temp.case_id('active_target'),'deactivate',repeat('x',1001));
    raise exception '0009_verify_expected_long_reason';
  exception when invalid_parameter_value then
    if sqlerrm<>'sitaa_account_lifecycle_invalid_reason' then raise; end if;
  end;
  begin
    perform public.transition_admin_account_lifecycle_b2b(pg_temp.case_id('active_target'),'reactivate','Motivo sintético válido 0009');
    raise exception '0009_verify_expected_active_state_conflict';
  exception when object_not_in_prerequisite_state then
    if sqlerrm<>'sitaa_account_lifecycle_state_conflict' then raise; end if;
  end;
  begin
    perform public.transition_admin_account_lifecycle_b2b(pg_temp.case_id('inactive_target'),'deactivate','Motivo sintético válido 0009');
    raise exception '0009_verify_expected_inactive_state_conflict';
  exception when object_not_in_prerequisite_state then
    if sqlerrm<>'sitaa_account_lifecycle_state_conflict' then raise; end if;
  end;
  begin
    perform public.transition_admin_account_lifecycle_b2b(pg_temp.case_id('admin_a'),'deactivate','Motivo sintético válido 0009');
    raise exception '0009_verify_expected_self_denial';
  exception when insufficient_privilege then
    if sqlerrm<>'sitaa_account_lifecycle_self_forbidden' then raise; end if;
  end;
end;
$input_contract$;

do $direct_acl_denial_contract$
begin
  begin
    update public.profiles set account_status=account_status
    where id=pg_temp.case_id('active_target');
    raise exception '0009_verify_expected_direct_profile_denial';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.admin_audit_events(
      actor_profile_id,target_profile_id,action_code,outcome,reason,metadata
    ) values (
      pg_temp.case_id('admin_a'),pg_temp.case_id('active_target'),
      'account_deactivated','success','Motivo sintético inválido','{}'::jsonb
    );
    raise exception '0009_verify_expected_direct_audit_denial';
  exception when insufficient_privilege then null;
  end;
end;
$direct_acl_denial_contract$;

do $deactivate_reactivate_contract$
declare
  result_row record;
  context_row record;
begin
  select * into result_row from public.transition_admin_account_lifecycle_b2b(
    pg_temp.case_id('active_target'),'deactivate',E'  Motivo\t sintético   válido de desactivación  '
  );
  if result_row.previous_status<>'active' or result_row.new_status<>'inactive'
     or result_row.changed_fields<>array['account_status','deactivated_at','is_active']::text[] then
    raise exception '0009_verify_deactivation_failed';
  end if;
  insert into pg_temp.sitaa_0009_results values(
    'deactivate',result_row.target_profile_id,result_row.audit_event_id,
    result_row.previous_status,result_row.new_status,result_row.changed_fields,
    result_row.updated_at
  );
  select * into context_row
  from public.get_admin_account_lifecycle_context_b2b(pg_temp.case_id('active_target'));
  if context_row.account_status<>'inactive' or not context_row.can_reactivate then
    raise exception '0009_verify_deactivation_projection_failed';
  end if;
  begin
    perform public.transition_admin_account_lifecycle_b2b(
      pg_temp.case_id('active_target'),'deactivate','Motivo sintético válido duplicado'
    );
    raise exception '0009_verify_expected_duplicate_state_conflict';
  exception when object_not_in_prerequisite_state then
    if sqlerrm<>'sitaa_account_lifecycle_state_conflict' then raise; end if;
  end;
  perform pg_temp.set_request_user('active_target');
  if public.can_edit_activity((select activity_id from pg_temp.sitaa_0009_context)) then
    raise exception '0009_verify_inactive_operational_barrier_failed';
  end if;
  perform pg_temp.set_request_user('admin_a');

  select * into result_row from public.transition_admin_account_lifecycle_b2b(
    pg_temp.case_id('active_target'),'reactivate','Motivo sintético válido de reactivación'
  );
  if result_row.previous_status<>'inactive' or result_row.new_status<>'active'
     or result_row.changed_fields<>array['account_status','deactivated_at','is_active']::text[] then
    raise exception '0009_verify_reactivation_failed';
  end if;
  insert into pg_temp.sitaa_0009_results values(
    'reactivate',result_row.target_profile_id,result_row.audit_event_id,
    result_row.previous_status,result_row.new_status,result_row.changed_fields,
    result_row.updated_at
  );
  perform pg_temp.set_request_user('active_target');
  if not public.can_edit_activity((select activity_id from pg_temp.sitaa_0009_context)) then
    raise exception '0009_verify_reactivation_authorization_failed';
  end if;
  perform pg_temp.set_request_user('admin_a');
  if (select count(*) from public.get_admin_account_assignments_b1(pg_temp.case_id('active_target')) assignment where assignment.presentation_status='current')<>1
     or (select count(*) from public.get_admin_account_assignments_b1(pg_temp.case_id('active_target')) assignment where assignment.presentation_status='future')<>1
     or (select count(*) from public.get_admin_account_assignments_b1(pg_temp.case_id('active_target')) assignment where assignment.presentation_status='expired')<>1
     or (select count(*) from public.get_admin_account_assignments_b1(pg_temp.case_id('active_target')) assignment where assignment.presentation_status='inactive')<>1 then
    raise exception '0009_verify_assignment_presentation_preservation_failed';
  end if;
  if (select count(*) from public.get_admin_account_audit_history_b1(
        pg_temp.case_id('active_target'),50,0
      ) history
      where history.action_code in ('account_deactivated','account_reactivated'))<>2 then
    raise exception '0009_verify_sanitized_audit_history_failed';
  end if;
end;
$deactivate_reactivate_contract$;

do $additional_lifecycle_contract$
declare
  result_row record;
  target_label text;
  context_row record;
begin
  select * into result_row from public.transition_admin_account_lifecycle_b2b(
    pg_temp.case_id('active_technical'),'deactivate','Motivo técnico válido de desactivación'
  );
  if result_row.previous_status<>'active' or result_row.new_status<>'inactive' then
    raise exception '0009_verify_technical_deactivation_failed';
  end if;
  perform public.transition_admin_account_lifecycle_b2b(
    pg_temp.case_id('active_technical'),'reactivate','Motivo técnico válido de reactivación'
  );

  foreach target_label in array array['inactive_target','inactive_technical','admin_inactive'] loop
    select * into result_row from public.transition_admin_account_lifecycle_b2b(
      pg_temp.case_id(target_label),'reactivate','Motivo sintético válido de reactivación'
    );
    if result_row.previous_status<>'inactive' or result_row.new_status<>'active' then
      raise exception '0009_verify_additional_reactivation_failed:%',target_label;
    end if;
    if target_label='admin_inactive' then
      select * into context_row
      from public.get_admin_account_lifecycle_context_b2b(pg_temp.case_id(target_label));
      if not context_row.has_exact_b1_assignment or not context_row.can_deactivate then
        raise exception '0009_verify_exact_admin_authority_restoration_failed';
      end if;
    end if;
    perform public.transition_admin_account_lifecycle_b2b(
      pg_temp.case_id(target_label),'deactivate','Motivo sintético válido de restauración'
    );
  end loop;
end;
$additional_lifecycle_contract$;

do $negative_mutation_contract$
begin
  begin
    perform public.transition_admin_account_lifecycle_b2b(pg_temp.case_id('pending_target'),'deactivate','Motivo sintético válido 0009');
    raise exception '0009_verify_expected_pending_denial';
  exception when raise_exception then
    if sqlerrm<>'sitaa_account_lifecycle_pending_target' then raise; end if;
  end;
  begin
    perform public.transition_admin_account_lifecycle_b2b(pg_temp.case_id('inactive_invalid_identity'),'reactivate','Motivo sintético válido 0009');
    raise exception '0009_verify_expected_invalid_identity_denial';
  exception when check_violation then
    if sqlerrm<>'sitaa_account_lifecycle_invalid_identity' then raise; end if;
  end;
  begin
    perform public.transition_admin_account_lifecycle_b2b(pg_temp.case_id('inactive_unconfirmed'),'reactivate','Motivo sintético válido 0009');
    raise exception '0009_verify_expected_unconfirmed_denial';
  exception when insufficient_privilege then
    if sqlerrm<>'sitaa_account_lifecycle_auth_unconfirmed' then raise; end if;
  end;
  begin
    perform public.transition_admin_account_lifecycle_b2b(gen_random_uuid(),'deactivate','Motivo sintético válido 0009');
    raise exception '0009_verify_expected_missing_target';
  exception when raise_exception then
    if sqlerrm<>'sitaa_account_lifecycle_target_unavailable' then raise; end if;
  end;
end;
$negative_mutation_contract$;

reset role;

-- No hay auditoría de fallos y la bitácora sigue append-only.
do $final_contract$
begin
  begin
    update public.admin_audit_events set reason='Mutación prohibida'
    where id=(select audit_event_id from pg_temp.sitaa_0009_results where transition='deactivate');
    raise exception '0009_verify_expected_audit_update_denial';
  exception when object_not_in_prerequisite_state then
    if sqlerrm<>'sitaa_admin_audit_is_append_only' then raise; end if;
  end;
  begin
    delete from public.admin_audit_events
    where id=(select audit_event_id from pg_temp.sitaa_0009_results where transition='deactivate');
    raise exception '0009_verify_expected_audit_delete_denial';
  exception when object_not_in_prerequisite_state then
    if sqlerrm<>'sitaa_admin_audit_is_append_only' then raise; end if;
  end;
  if exists(select 1 from public.admin_audit_events where target_profile_id in (pg_temp.case_id('pending_target'),pg_temp.case_id('inactive_unconfirmed')) and action_code in ('account_deactivated','account_reactivated')) then
    raise exception '0009_verify_failure_audit_leak';
  end if;
  if (select count(*) from public.profiles where id in (select id from pg_temp.sitaa_0009_cases))<>(select count(*) from pg_temp.sitaa_0009_cases) then
    raise exception '0009_verify_fixture_profile_loss';
  end if;
  if not exists(select 1 from public.profiles where id=pg_temp.case_id('active_target') and account_status='active' and is_active and activated_at is not null and deactivated_at is null)
     or (select count(*) from public.role_assignments where user_id=pg_temp.case_id('active_target'))<>4
     or (select count(*) from public.admin_audit_events where target_profile_id=pg_temp.case_id('active_target') and action_code in ('account_deactivated','account_reactivated'))<>2
     or not exists(
       select 1 from public.admin_audit_events event
       join pg_temp.sitaa_0009_results result on result.audit_event_id=event.id
       where result.transition='deactivate'
         and event.action_code='account_deactivated' and event.outcome='success'
         and event.reason='Motivo sintético válido de desactivación'
         and event.role_assignment_id is null
         and event.metadata=jsonb_build_object('changed_fields',to_jsonb(array['account_status','deactivated_at','is_active']::text[]))
     )
     or not exists(
       select 1 from public.admin_audit_events event
       join pg_temp.sitaa_0009_results result on result.audit_event_id=event.id
       where result.transition='reactivate'
         and event.action_code='account_reactivated' and event.outcome='success'
         and event.reason='Motivo sintético válido de reactivación'
         and event.role_assignment_id is null
         and event.metadata=jsonb_build_object('changed_fields',to_jsonb(array['account_status','deactivated_at','is_active']::text[]))
     ) then
    raise exception '0009_verify_owner_postconditions_failed';
  end if;
  if exists (
    with current_invariants(object_name,object_hash) as (
      values
      ('auth_user',(select md5(row_to_json(auth_user)::text) from auth.users auth_user where auth_user.id=pg_temp.case_id('active_target'))),
      ('auth_identities',(select md5(coalesce(string_agg(row_to_json(identity_row)::text,'|' order by identity_row.id::text),'')) from auth.identities identity_row where identity_row.user_id=pg_temp.case_id('active_target'))),
      ('identity',(select md5(jsonb_build_object('id',profile.id,'email',profile.email,'account_kind',profile.account_kind,'first_names',profile.first_names,'paternal_surname',profile.paternal_surname,'maternal_surname',profile.maternal_surname,'full_name',profile.full_name,'person_type',profile.person_type,'institutional_id_type',profile.institutional_id_type,'institutional_id_value',profile.institutional_id_value,'primary_program_id',profile.primary_program_id)::text) from public.profiles profile where profile.id=pg_temp.case_id('active_target'))),
      ('assignments',(select md5(coalesce(string_agg(row_to_json(assignment)::text,'|' order by assignment.id),'')) from public.role_assignments assignment where assignment.user_id=pg_temp.case_id('active_target'))),
      ('activities',(select md5(coalesce(string_agg(row_to_json(activity)::text,'|' order by activity.id),'')) from public.activities activity where activity.id=(select activity_id from sitaa_0009_context))),
      ('participants',(select md5(coalesce(string_agg(row_to_json(participant)::text,'|' order by participant.id),'')) from public.activity_participants participant where participant.activity_id=(select activity_id from sitaa_0009_context)))
    )
    select 1 from pg_temp.sitaa_0009_invariants baseline
    join current_invariants current_value using(object_name)
    where baseline.object_hash<>current_value.object_hash
  ) then
    raise exception '0009_verify_preservation_contract_failed';
  end if;
end;
$final_contract$;

rollback;
