-- Phase B.3a: coordinación fail-closed entre ciclo de vida SITAA y Supabase Auth.
-- Preparada localmente; requiere preflight, revisión y aplicación manual controlada.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';
set local time zone 'UTC';
set local datestyle to 'ISO, MDY';

-- Preflight bloqueante post-0009. No modifica objetos antes de completar todas
-- las comprobaciones y no inspecciona secretos ni devuelve datos personales.
do $preflight$
declare
  mismatch_count integer := 0;
  expected_function_hash text := '71f9763d702e95e4eede51a4a4611694';
begin
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
     or (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public')+
        (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault(case when c.relkind='S' then 's'::"char" else 'r'::"char" end,c.relowner))) a where n.nspname='public' and c.relkind in ('r','p','v','m','S'))<>445 then
    raise exception 'sitaa_0010_preflight_inventory_mismatch' using errcode='55000';
  end if;

  if (select md5(coalesce(string_agg(p.oid::regprocedure::text||':'||md5(regexp_replace(p.prosrc,'\s+','','g')),'|' order by p.oid::regprocedure::text),''))
      from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>expected_function_hash then
    raise exception 'sitaa_0010_preflight_function_map_mismatch' using errcode='55000';
  end if;

  select count(*) into mismatch_count
  from (values
    ('is_exact_b1_account_admin_profile_b2b(uuid)','104d16a531ea53a5b4908102322097dc'),
    ('get_admin_account_lifecycle_context_b2b(uuid)','6e7c8bb5e2dcf99fce6a75e03e07c309'),
    ('transition_admin_account_lifecycle_b2b(uuid,text,text)','7f940968051ff1b844443f6c76b561c3'),
    ('is_sitaa_operational_account_active()','f85f733578f09c0f7466af7e18a90f4c'),
    ('is_b1_account_admin()','0486f72652abc79ed3d1334704d55fbe')
  ) expected(signature,body_hash)
  left join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
  where p.oid is null or md5(regexp_replace(p.prosrc,'\s+','','g'))<>expected.body_hash;
  if mismatch_count<>0 then
    raise exception 'sitaa_0010_preflight_prior_function_mismatch' using errcode='55000';
  end if;

  if not has_function_privilege('authenticated','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or has_function_privilege('anon','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or has_function_privilege('service_role','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or not has_function_privilege('authenticated','public.get_admin_account_lifecycle_context_b2b(uuid)','EXECUTE') then
    raise exception 'sitaa_0010_preflight_0009_acl_mismatch' using errcode='55000';
  end if;

  if to_regclass('public.admin_audit_events') is null
     or (select count(*) from information_schema.columns where table_schema='public' and table_name='admin_audit_events')<>9
     or (select count(*) from pg_trigger where tgrelid='public.admin_audit_events'::regclass and not tgisinternal)<>2
     or not (select relrowsecurity from pg_class where oid='public.admin_audit_events'::regclass)
     or (select count(*) from pg_policies where schemaname='public' and tablename='admin_audit_events')<>0
     or has_table_privilege('authenticated','public.admin_audit_events','SELECT')
     or not has_table_privilege('service_role','public.admin_audit_events','SELECT')
     or not has_table_privilege('service_role','public.admin_audit_events','INSERT') then
    raise exception 'sitaa_0010_preflight_audit_contract_mismatch' using errcode='55000';
  end if;

  if not exists(select 1 from pg_roles where rolname='service_role' and rolbypassrls)
     or (select count(*) from public.profiles p left join auth.users u on u.id=p.id where u.id is null)>0
     or (select count(*) from auth.users u left join public.profiles p on p.id=u.id where p.id is null)>0
     or (select count(*) from public.profiles where not (
       account_status='active' and is_active and activated_at is not null and deactivated_at is null
       or account_status='pending_registration' and not is_active and activated_at is null and deactivated_at is null
       or account_status='inactive' and not is_active and activated_at is not null and deactivated_at is not null))>0 then
    raise exception 'sitaa_0010_preflight_identity_or_role_mismatch' using errcode='55000';
  end if;

  if (select count(*) from pg_trigger t where not t.tgisinternal and t.tgname='on_sitaa_auth_user_created' and t.tgrelid='auth.users'::regclass and t.tgfoid=to_regprocedure('public.handle_sitaa_auth_user_created()'))<>1
     or (select count(*) from pg_trigger t where not t.tgisinternal and t.tgname='on_sitaa_auth_user_email_changed' and t.tgrelid='auth.users'::regclass and t.tgfoid=to_regprocedure('public.sync_sitaa_profile_email_from_auth()'))<>1 then
    raise exception 'sitaa_0010_preflight_auth_trigger_mismatch' using errcode='55000';
  end if;

  if to_regclass('public.admin_auth_operations') is not null
     or exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in (
       'guard_admin_auth_operation_b3a','get_admin_account_auth_lifecycle_context_b3a',
       'prepare_admin_account_auth_lifecycle_b3a','finalize_admin_account_auth_reactivation_b3a',
       'claim_admin_auth_operation_b3a','record_admin_auth_operation_result_b3a')) then
    raise exception 'sitaa_0010_preflight_conflicting_object' using errcode='55000';
  end if;

  if not (
    with controlled_seed_rows(catalog,row_json) as (
      select 'academic_periods',to_jsonb(s)::text from public.academic_periods s union all
      select 'academic_programs',to_jsonb(s)::text from public.academic_programs s union all
      select 'activity_modalities',to_jsonb(s)::text from public.activity_modalities s union all
      select 'activity_statuses',to_jsonb(s)::text from public.activity_statuses s union all
      select 'activity_types',to_jsonb(s)::text from public.activity_types s union all
      select 'attention_categories',to_jsonb(s)::text from public.attention_categories s union all
      select 'divisions',to_jsonb(s)::text from public.divisions s union all
      select 'location_types',to_jsonb(s)::text from public.location_types s union all
      select 'participant_roles',to_jsonb(s)::text from public.participant_roles s union all
      select 'roles',to_jsonb(s)::text from public.roles s union all
      select 'service_types',to_jsonb(s)::text from public.service_types s
    ) select count(*)=51 and md5(string_agg(catalog||E'\t'||row_json,E'\n' order by catalog,row_json))='2e450238768fbe9889470864a1832486' from controlled_seed_rows
  ) then
    raise exception 'sitaa_0010_preflight_seed_mismatch' using errcode='55000';
  end if;
end;
$preflight$;

create table public.admin_auth_operations (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  requested_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  completed_by_profile_id uuid null references public.profiles(id) on delete restrict,
  target_profile_id uuid not null references public.profiles(id) on delete restrict,
  operation_code text not null,
  status text not null default 'open',
  completed_stage text not null default 'prepared',
  reason text not null,
  attempt_count integer not null default 0,
  last_error_code text null,
  profile_audit_event_id uuid null references public.admin_audit_events(id) on delete restrict,
  auth_audit_event_id uuid null references public.admin_audit_events(id) on delete restrict,
  requested_at timestamptz not null default now(),
  processing_started_at timestamptz null,
  auth_synchronized_at timestamptz null,
  completed_at timestamptz null,
  updated_at timestamptz not null default now(),
  constraint admin_auth_operations_operation_check check (operation_code in ('deactivate','reactivate')),
  constraint admin_auth_operations_status_check check (status in ('open','processing','retryable_failure','succeeded','terminal_failure')),
  constraint admin_auth_operations_stage_check check (completed_stage in ('prepared','profile_suspended','auth_synchronized','completed')),
  constraint admin_auth_operations_reason_check check (
    reason=btrim(regexp_replace(reason,'\s+',' ','g')) and char_length(reason) between 10 and 1000
  ),
  constraint admin_auth_operations_attempt_check check (attempt_count>=0),
  constraint admin_auth_operations_error_check check (last_error_code is null or last_error_code in (
    'auth_temporarily_unavailable','auth_rate_limited','auth_user_not_found',
    'auth_update_rejected','unsupported_auth_contract','database_finalize_pending'
  )),
  constraint admin_auth_operations_stage_operation_check check (
    operation_code='deactivate' or completed_stage<>'profile_suspended'
  ),
  constraint admin_auth_operations_evidence_check check (
    completed_stage='prepared'
    or operation_code='reactivate' and completed_stage='auth_synchronized'
    or profile_audit_event_id is not null
  ),
  constraint admin_auth_operations_timestamp_check check (
    updated_at>=requested_at
    and (processing_started_at is null or processing_started_at>=requested_at)
    and (auth_synchronized_at is null or auth_synchronized_at>=requested_at)
    and (completed_at is null or completed_at>=requested_at)
    and (status not in ('succeeded','terminal_failure') or completed_at is not null)
    and (status not in ('open','processing','retryable_failure') or completed_at is null)
    and (completed_stage not in ('auth_synchronized','completed') or auth_synchronized_at is not null)
    and (completed_stage<>'completed' or status='succeeded')
    and (status not in ('retryable_failure','terminal_failure') or last_error_code is not null)
    and (status in ('retryable_failure','terminal_failure') or last_error_code is null)
    and (status<>'terminal_failure' or auth_audit_event_id is not null)
    and (status<>'succeeded' or profile_audit_event_id is not null and auth_audit_event_id is not null)
  )
);

create unique index admin_auth_operations_request_id_uidx
  on public.admin_auth_operations(request_id);
alter table public.admin_auth_operations
  add constraint admin_auth_operations_request_id_key
  unique using index admin_auth_operations_request_id_uidx;
create index admin_auth_operations_target_status_idx
  on public.admin_auth_operations(target_profile_id,status,updated_at desc);
create index admin_auth_operations_actor_requested_idx
  on public.admin_auth_operations(requested_by_profile_id,requested_at desc,id desc);
create unique index admin_auth_operations_one_nonfinal_target_uidx
  on public.admin_auth_operations(target_profile_id)
  where status in ('open','processing','retryable_failure');

alter table public.admin_auth_operations enable row level security;
revoke all on table public.admin_auth_operations from public,anon,authenticated,service_role;

create function public.guard_admin_auth_operation_b3a()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog,public
as $function$
declare
  writer text:=current_setting('sitaa.b3a_writer',true);
  old_rank integer;
  new_rank integer;
begin
  if tg_op in ('DELETE','TRUNCATE') then
    raise exception 'sitaa_auth_operation_destructive_change_forbidden' using errcode='42501';
  end if;
  if writer not in ('prepare','claim','record','finalize') then
    raise exception 'sitaa_auth_operation_writer_forbidden' using errcode='42501';
  end if;
  if tg_op='INSERT' then
    if writer<>'prepare' or new.status<>'open' or new.completed_stage<>'prepared'
       or new.attempt_count<>0 or new.completed_by_profile_id is not null
       or new.last_error_code is not null or new.profile_audit_event_id is not null
       or new.auth_audit_event_id is not null or new.processing_started_at is not null
       or new.auth_synchronized_at is not null or new.completed_at is not null then
      raise exception 'sitaa_auth_operation_invalid_initial_state' using errcode='23514';
    end if;
    return new;
  end if;

  if row(old.id,old.request_id,old.requested_by_profile_id,old.target_profile_id,old.operation_code,old.reason,old.requested_at)
     is distinct from row(new.id,new.request_id,new.requested_by_profile_id,new.target_profile_id,new.operation_code,new.reason,new.requested_at) then
    raise exception 'sitaa_auth_operation_identity_immutable' using errcode='23514';
  end if;
  if old.status in ('succeeded','terminal_failure') then
    raise exception 'sitaa_auth_operation_final_state_immutable' using errcode='23514';
  end if;
  if not (
    old.status='open' and new.status in ('open','processing')
    or old.status='retryable_failure' and new.status='processing'
    or old.status='processing' and new.status in ('processing','retryable_failure','succeeded','terminal_failure')
  ) then
    raise exception 'sitaa_auth_operation_status_transition_forbidden' using errcode='23514';
  end if;
  old_rank:=case old.completed_stage when 'prepared' then 1 when 'profile_suspended' then 2 when 'auth_synchronized' then 3 else 4 end;
  new_rank:=case new.completed_stage when 'prepared' then 1 when 'profile_suspended' then 2 when 'auth_synchronized' then 3 else 4 end;
  if new_rank<old_rank or new.attempt_count<old.attempt_count
     or new.updated_at<old.updated_at
     or old.processing_started_at is not null and new.processing_started_at<old.processing_started_at
     or old.completed_by_profile_id is not null and new.completed_by_profile_id is null
     or old.profile_audit_event_id is not null and new.profile_audit_event_id is null
     or old.auth_audit_event_id is not null and new.auth_audit_event_id is null
     or old.auth_synchronized_at is not null and new.auth_synchronized_at is null
     or old.completed_at is not null and new.completed_at is null then
    raise exception 'sitaa_auth_operation_regression_forbidden' using errcode='23514';
  end if;
  if writer='claim' and not (
       new.status='processing' and new.attempt_count=old.attempt_count+1
       and new.completed_stage=old.completed_stage and new.processing_started_at>=old.updated_at
     ) then
    raise exception 'sitaa_auth_operation_invalid_claim' using errcode='23514';
  elsif writer<>'claim' and new.attempt_count<>old.attempt_count then
    raise exception 'sitaa_auth_operation_attempt_change_forbidden' using errcode='23514';
  end if;
  if writer='record' and old.status<>'processing' then
    raise exception 'sitaa_auth_operation_not_processing' using errcode='55000';
  end if;
  if writer='finalize' and not (
    old.operation_code='reactivate' and old.status='processing'
    and old.completed_stage='auth_synchronized' and new.status='succeeded'
    and new.completed_stage='completed'
  ) then
    raise exception 'sitaa_auth_operation_invalid_finalization' using errcode='23514';
  end if;
  return new;
end;
$function$;
revoke all on function public.guard_admin_auth_operation_b3a() from public,anon,authenticated,service_role;

create trigger guard_admin_auth_operation_b3a
before insert or update or delete on public.admin_auth_operations
for each row execute function public.guard_admin_auth_operation_b3a();
create trigger guard_admin_auth_operation_truncate_b3a
before truncate on public.admin_auth_operations
for each statement execute function public.guard_admin_auth_operation_b3a();

create function public.get_admin_account_auth_lifecycle_context_b3a(requested_profile_id uuid)
returns table(
  target_profile_id uuid,account_kind text,account_status text,is_self boolean,
  can_deactivate boolean,can_reactivate boolean,denial_code text,
  has_exact_b1_assignment boolean,active_exact_b1_admin_count bigint,
  current_or_future_assignment_count bigint,open_responsibility_count bigint,
  open_participation_count bigint,b3a_available boolean,open_operation_id uuid,
  operation_code text,operation_status text,completed_stage text,attempt_count integer,
  retryable boolean,last_error_code text,operation_updated_at timestamptz,
  can_retry_or_finalize boolean
)
language plpgsql
stable
security definer
set search_path=pg_catalog,public
as $function$
declare
  actor_id uuid:=auth.uid();
  base record;
  operation_row public.admin_auth_operations%rowtype;
begin
  if actor_id is null or not public.is_exact_b1_account_admin_profile_b2b(actor_id) then
    raise exception 'sitaa_admin_access_denied' using errcode='42501';
  end if;
  select * into base from public.get_admin_account_lifecycle_context_b2b(requested_profile_id);
  if not found then return; end if;
  select operation.* into operation_row
  from public.admin_auth_operations operation
  where operation.target_profile_id=requested_profile_id
    and operation.status<>'succeeded'
  order by (operation.status in ('open','processing','retryable_failure')) desc,
    operation.updated_at desc,operation.id desc limit 1;
  return query select base.target_profile_id,base.account_kind,base.account_status,
    base.is_self,base.can_deactivate,base.can_reactivate,base.denial_code,
    base.has_exact_b1_assignment,base.active_exact_b1_admin_count,
    base.current_or_future_assignment_count,base.open_responsibility_count,
    base.open_participation_count,true,
    operation_row.id,operation_row.operation_code,operation_row.status,
    operation_row.completed_stage,coalesce(operation_row.attempt_count,0),
    operation_row.status='retryable_failure',operation_row.last_error_code,
    operation_row.updated_at,
    operation_row.id is not null and (
      operation_row.status in ('open','retryable_failure')
      or operation_row.status='processing' and (
        operation_row.completed_stage='auth_synchronized'
        or operation_row.processing_started_at<=now()-interval '5 minutes'
      )
    );
end;
$function$;

create function public.prepare_admin_account_auth_lifecycle_b3a(
  requested_profile_id uuid,requested_transition text,transition_reason text,request_id uuid
)
returns table(
  operation_id uuid,target_profile_id uuid,operation_code text,status text,
  completed_stage text,attempt_count integer,retryable boolean,
  last_error_code text,updated_at timestamptz
)
language plpgsql
volatile
security definer
set search_path=pg_catalog,public
as $function$
declare
  actor_id uuid:=auth.uid();
  normalized_reason text:=nullif(btrim(regexp_replace(coalesce(transition_reason,''),'\s+',' ','g')),'');
  existing public.admin_auth_operations%rowtype;
  base record;
  lifecycle_result record;
begin
  if actor_id is null or not public.is_exact_b1_account_admin_profile_b2b(actor_id) then
    raise exception 'sitaa_admin_access_denied' using errcode='42501';
  end if;
  if request_id is null then raise exception 'sitaa_auth_operation_request_id_required' using errcode='22023'; end if;
  if requested_transition not in ('deactivate','reactivate') then raise exception 'sitaa_account_lifecycle_invalid_transition' using errcode='22023'; end if;
  if normalized_reason is null or char_length(normalized_reason) not between 10 and 1000 then raise exception 'sitaa_account_lifecycle_invalid_reason' using errcode='22023'; end if;
  if actor_id=requested_profile_id then raise exception 'sitaa_account_lifecycle_self_forbidden' using errcode='42501'; end if;

  select operation.* into existing from public.admin_auth_operations operation where operation.request_id=$4 for update;
  if found then
    if existing.requested_by_profile_id<>actor_id or existing.target_profile_id<>requested_profile_id
       or existing.operation_code<>requested_transition or existing.reason<>normalized_reason then
      raise exception 'sitaa_auth_operation_request_id_conflict' using errcode='23505';
    end if;
    return query select existing.id,existing.target_profile_id,existing.operation_code,
      existing.status,existing.completed_stage,existing.attempt_count,
      existing.status='retryable_failure',existing.last_error_code,existing.updated_at;
    return;
  end if;

  perform pg_advisory_xact_lock(1397310529,9002);
  if not public.is_exact_b1_account_admin_profile_b2b(actor_id) then
    raise exception 'sitaa_admin_access_denied' using errcode='42501';
  end if;
  select * into base from public.get_admin_account_lifecycle_context_b2b(requested_profile_id);
  if not found then raise exception 'sitaa_account_lifecycle_target_unavailable' using errcode='P0001'; end if;
  if base.account_status='pending_registration' then raise exception 'sitaa_account_lifecycle_pending_target' using errcode='P0001'; end if;
  if requested_transition='deactivate' and not base.can_deactivate
     or requested_transition='reactivate' and not base.can_reactivate then
    if base.denial_code='last_admin' then raise exception 'sitaa_account_lifecycle_last_admin_forbidden' using errcode='55000'; end if;
    if base.denial_code='invalid_identity' then raise exception 'sitaa_account_lifecycle_invalid_identity' using errcode='23514'; end if;
    if base.denial_code='auth_unconfirmed' then raise exception 'sitaa_account_lifecycle_auth_unconfirmed' using errcode='42501'; end if;
    raise exception 'sitaa_account_lifecycle_state_conflict' using errcode='55000';
  end if;
  if exists(select 1 from public.admin_auth_operations operation where operation.target_profile_id=requested_profile_id and operation.status in ('open','processing','retryable_failure')) then
    raise exception 'sitaa_auth_operation_target_busy' using errcode='55000';
  end if;

  perform set_config('sitaa.b3a_writer','prepare',true);
  insert into public.admin_auth_operations(
    request_id,requested_by_profile_id,target_profile_id,operation_code,reason
  ) values($4,actor_id,requested_profile_id,requested_transition,normalized_reason)
  returning * into existing;

  if requested_transition='deactivate' then
    select * into lifecycle_result from public.transition_admin_account_lifecycle_b2b(
      requested_profile_id,'deactivate',normalized_reason
    );
    perform set_config('sitaa.b3a_writer','prepare',true);
    update public.admin_auth_operations operation set
      completed_stage='profile_suspended',profile_audit_event_id=lifecycle_result.audit_event_id,
      updated_at=now()
    where operation.id=existing.id returning * into existing;
  end if;
  return query select existing.id,existing.target_profile_id,existing.operation_code,
    existing.status,existing.completed_stage,existing.attempt_count,false,
    existing.last_error_code,existing.updated_at;
end;
$function$;

create function public.claim_admin_auth_operation_b3a(
  requested_operation_id uuid,caller_profile_id uuid
)
returns table(
  operation_id uuid,target_profile_id uuid,operation_code text,
  completed_stage text,attempt_count integer
)
language plpgsql
volatile
security definer
set search_path=pg_catalog,public
as $function$
declare operation_row public.admin_auth_operations%rowtype;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'sitaa_service_boundary_required' using errcode='42501'; end if;
  if caller_profile_id is null or not public.is_exact_b1_account_admin_profile_b2b(caller_profile_id) then raise exception 'sitaa_admin_access_denied' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(1397310529,9002);
  select operation.* into operation_row from public.admin_auth_operations operation where operation.id=requested_operation_id for update;
  if not found then raise exception 'sitaa_auth_operation_unavailable' using errcode='P0001'; end if;
  if operation_row.status in ('succeeded','terminal_failure') then raise exception 'sitaa_auth_operation_final' using errcode='55000'; end if;
  if operation_row.status='processing' and operation_row.processing_started_at>now()-interval '5 minutes' then raise exception 'sitaa_auth_operation_already_processing' using errcode='55P03'; end if;
  perform set_config('sitaa.b3a_writer','claim',true);
  update public.admin_auth_operations operation set status='processing',
    attempt_count=operation.attempt_count+1,processing_started_at=now(),
    last_error_code=null,updated_at=now()
  where operation.id=operation_row.id returning * into operation_row;
  return query select operation_row.id,operation_row.target_profile_id,
    operation_row.operation_code,operation_row.completed_stage,operation_row.attempt_count;
end;
$function$;

create function public.record_admin_auth_operation_result_b3a(
  requested_operation_id uuid,caller_profile_id uuid,requested_result text,stable_error_code text
)
returns table(
  operation_id uuid,status text,completed_stage text,attempt_count integer,
  retryable boolean,last_error_code text,updated_at timestamptz
)
language plpgsql
volatile
security definer
set search_path=pg_catalog,public
as $function$
declare operation_row public.admin_auth_operations%rowtype; event_id uuid; action text;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'sitaa_service_boundary_required' using errcode='42501'; end if;
  if caller_profile_id is null or not public.is_exact_b1_account_admin_profile_b2b(caller_profile_id) then raise exception 'sitaa_admin_access_denied' using errcode='42501'; end if;
  if requested_result not in ('auth_succeeded','retryable_failure','terminal_failure') then raise exception 'sitaa_auth_operation_invalid_result' using errcode='22023'; end if;
  if requested_result='retryable_failure' and stable_error_code not in ('auth_temporarily_unavailable','auth_rate_limited','database_finalize_pending')
     or requested_result='terminal_failure' and stable_error_code not in ('auth_user_not_found','auth_update_rejected','unsupported_auth_contract')
     or requested_result='auth_succeeded' and stable_error_code is not null then
    raise exception 'sitaa_auth_operation_invalid_error_code' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(1397310529,9002);
  select operation.* into operation_row from public.admin_auth_operations operation where operation.id=requested_operation_id for update;
  if not found or operation_row.status<>'processing' then raise exception 'sitaa_auth_operation_not_processing' using errcode='55000'; end if;
  perform set_config('sitaa.b3a_writer','record',true);

  if requested_result='auth_succeeded' then
    if operation_row.operation_code='deactivate' then
      if operation_row.completed_stage<>'profile_suspended' then raise exception 'sitaa_auth_operation_stage_conflict' using errcode='55000'; end if;
      insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,reason,role_assignment_id,metadata)
      values(operation_row.requested_by_profile_id,operation_row.target_profile_id,'account_auth_suspended','success',operation_row.reason,null,
        jsonb_build_object('operation_id',operation_row.id,'operation_code',operation_row.operation_code,'changed_fields',jsonb_build_array('auth_access')))
      returning id into event_id;
      update public.admin_auth_operations operation set status='succeeded',completed_stage='completed',
        auth_audit_event_id=event_id,auth_synchronized_at=now(),completed_at=now(),
        completed_by_profile_id=caller_profile_id,last_error_code=null,updated_at=now()
      where operation.id=operation_row.id returning * into operation_row;
    else
      if operation_row.completed_stage<>'prepared' then raise exception 'sitaa_auth_operation_stage_conflict' using errcode='55000'; end if;
      update public.admin_auth_operations operation set completed_stage='auth_synchronized',
        auth_synchronized_at=now(),last_error_code=null,updated_at=now()
      where operation.id=operation_row.id returning * into operation_row;
    end if;
  elsif requested_result='retryable_failure' then
    update public.admin_auth_operations operation set status='retryable_failure',
      last_error_code=stable_error_code,updated_at=now()
    where operation.id=operation_row.id returning * into operation_row;
  else
    action:=case when operation_row.operation_code='deactivate' then 'account_auth_suspension_failed' else 'account_auth_restoration_failed' end;
    insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,reason,role_assignment_id,metadata)
    values(operation_row.requested_by_profile_id,operation_row.target_profile_id,action,'failure',operation_row.reason,null,
      jsonb_build_object('operation_id',operation_row.id,'operation_code',operation_row.operation_code,'error_code',stable_error_code))
    returning id into event_id;
    update public.admin_auth_operations operation set status='terminal_failure',
      auth_audit_event_id=event_id,last_error_code=stable_error_code,
      completed_at=now(),completed_by_profile_id=caller_profile_id,updated_at=now()
    where operation.id=operation_row.id returning * into operation_row;
  end if;
  return query select operation_row.id,operation_row.status,operation_row.completed_stage,
    operation_row.attempt_count,operation_row.status='retryable_failure',
    operation_row.last_error_code,operation_row.updated_at;
end;
$function$;

create function public.finalize_admin_account_auth_reactivation_b3a(requested_operation_id uuid)
returns table(
  operation_id uuid,target_profile_id uuid,status text,completed_stage text,
  profile_audit_event_id uuid,auth_audit_event_id uuid,completed_at timestamptz
)
language plpgsql
volatile
security definer
set search_path=pg_catalog,public
as $function$
declare actor_id uuid:=auth.uid(); operation_row public.admin_auth_operations%rowtype; lifecycle_result record; event_id uuid;
begin
  if actor_id is null or not public.is_exact_b1_account_admin_profile_b2b(actor_id) then raise exception 'sitaa_admin_access_denied' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(1397310529,9002);
  select operation.* into operation_row from public.admin_auth_operations operation where operation.id=requested_operation_id for update;
  if not found or operation_row.operation_code<>'reactivate' or operation_row.status<>'processing' or operation_row.completed_stage<>'auth_synchronized' then
    raise exception 'sitaa_auth_operation_not_ready_to_finalize' using errcode='55000';
  end if;
  if not public.is_exact_b1_account_admin_profile_b2b(actor_id) then raise exception 'sitaa_admin_access_denied' using errcode='42501'; end if;
  select * into lifecycle_result from public.transition_admin_account_lifecycle_b2b(operation_row.target_profile_id,'reactivate',operation_row.reason);
  insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,reason,role_assignment_id,metadata)
  values(actor_id,operation_row.target_profile_id,'account_auth_restored','success',operation_row.reason,null,
    jsonb_build_object('operation_id',operation_row.id,'operation_code',operation_row.operation_code,'changed_fields',jsonb_build_array('auth_access')))
  returning id into event_id;
  perform set_config('sitaa.b3a_writer','finalize',true);
  update public.admin_auth_operations operation set status='succeeded',completed_stage='completed',
    profile_audit_event_id=lifecycle_result.audit_event_id,auth_audit_event_id=event_id,
    completed_by_profile_id=actor_id,completed_at=now(),last_error_code=null,updated_at=now()
  where operation.id=operation_row.id returning * into operation_row;
  return query select operation_row.id,operation_row.target_profile_id,operation_row.status,
    operation_row.completed_stage,operation_row.profile_audit_event_id,
    operation_row.auth_audit_event_id,operation_row.completed_at;
end;
$function$;

alter function public.guard_admin_auth_operation_b3a() owner to postgres;
alter function public.get_admin_account_auth_lifecycle_context_b3a(uuid) owner to postgres;
alter function public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid) owner to postgres;
alter function public.finalize_admin_account_auth_reactivation_b3a(uuid) owner to postgres;
alter function public.claim_admin_auth_operation_b3a(uuid,uuid) owner to postgres;
alter function public.record_admin_auth_operation_result_b3a(uuid,uuid,text,text) owner to postgres;

revoke all on function public.get_admin_account_auth_lifecycle_context_b3a(uuid) from public,anon,authenticated,service_role;
revoke all on function public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid) from public,anon,authenticated,service_role;
revoke all on function public.finalize_admin_account_auth_reactivation_b3a(uuid) from public,anon,authenticated,service_role;
revoke all on function public.claim_admin_auth_operation_b3a(uuid,uuid) from public,anon,authenticated,service_role;
revoke all on function public.record_admin_auth_operation_result_b3a(uuid,uuid,text,text) from public,anon,authenticated,service_role;
grant execute on function public.get_admin_account_auth_lifecycle_context_b3a(uuid) to authenticated;
grant execute on function public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid) to authenticated;
grant execute on function public.finalize_admin_account_auth_reactivation_b3a(uuid) to authenticated;
grant execute on function public.claim_admin_auth_operation_b3a(uuid,uuid) to service_role;
grant execute on function public.record_admin_auth_operation_result_b3a(uuid,uuid,text,text) to service_role;

-- 0010 elimina la invocación cliente directa del mutador B.2b.
revoke all on function public.transition_admin_account_lifecycle_b2b(uuid,text,text)
  from public,anon,authenticated,service_role;

-- Guardia post-DDL: todo el contrato debe estar presente antes del COMMIT.
do $post_ddl$
declare function_oid regprocedure;
begin
  if to_regclass('public.admin_auth_operations') is null
     or (select count(*) from information_schema.columns where table_schema='public' and table_name='admin_auth_operations')<>18
     or (select string_agg(column_name||':'||data_type||':'||is_nullable,'|' order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='admin_auth_operations')<>
       'id:uuid:NO|request_id:uuid:NO|requested_by_profile_id:uuid:NO|completed_by_profile_id:uuid:YES|target_profile_id:uuid:NO|operation_code:text:NO|status:text:NO|completed_stage:text:NO|reason:text:NO|attempt_count:integer:NO|last_error_code:text:YES|profile_audit_event_id:uuid:YES|auth_audit_event_id:uuid:YES|requested_at:timestamp with time zone:NO|processing_started_at:timestamp with time zone:YES|auth_synchronized_at:timestamp with time zone:YES|completed_at:timestamp with time zone:YES|updated_at:timestamp with time zone:NO'
     or (select count(*) from pg_constraint where conrelid='public.admin_auth_operations'::regclass)<>16
     or (select count(*) from pg_indexes where schemaname='public' and tablename='admin_auth_operations')<>5
     or (select count(*) from pg_trigger where tgrelid='public.admin_auth_operations'::regclass and not tgisinternal)<>2
     or not (select relrowsecurity from pg_class where oid='public.admin_auth_operations'::regclass)
     or (select count(*) from pg_policies where schemaname='public' and tablename='admin_auth_operations')<>0 then
    raise exception 'sitaa_0010_post_ddl_table_contract_mismatch';
  end if;
  if exists(select 1 from (values('PUBLIC'),('anon'),('authenticated'),('service_role')) r(role_name)
    where has_table_privilege(r.role_name,'public.admin_auth_operations','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')) then
    raise exception 'sitaa_0010_post_ddl_table_acl_mismatch';
  end if;
  foreach function_oid in array array[
    'public.guard_admin_auth_operation_b3a()'::regprocedure,
    'public.get_admin_account_auth_lifecycle_context_b3a(uuid)'::regprocedure,
    'public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)'::regprocedure,
    'public.finalize_admin_account_auth_reactivation_b3a(uuid)'::regprocedure,
    'public.claim_admin_auth_operation_b3a(uuid,uuid)'::regprocedure,
    'public.record_admin_auth_operation_result_b3a(uuid,uuid,text,text)'::regprocedure
  ] loop
     if not (select p.prosecdef and p.proconfig=array['search_path=pg_catalog, public']::text[] and pg_get_userbyid(p.proowner)='postgres' and l.lanname='plpgsql' from pg_proc p join pg_language l on l.oid=p.prolang where p.oid=function_oid) then
       raise exception 'sitaa_0010_post_ddl_function_contract_mismatch:%',function_oid;
     end if;
  end loop;
  if exists (
    select 1 from (values
      ('guard_admin_auth_operation_b3a()','43660b1265d2a648a84e85bef18185b1'),
      ('get_admin_account_auth_lifecycle_context_b3a(uuid)','cf48187f1d6f0f90f76c85a1a4f245c7'),
      ('prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)','5079a57ba8f237a5ebb890357e090c14'),
      ('claim_admin_auth_operation_b3a(uuid,uuid)','20154250d73d4ae51d8004d5d8287ad0'),
      ('record_admin_auth_operation_result_b3a(uuid,uuid,text,text)','33a344c12fa1878fe18cede103246dea'),
      ('finalize_admin_account_auth_reactivation_b3a(uuid)','573cf1c366f0995cdc81ad0c57b31d44')
    ) expected(signature,body_hash)
    left join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
    where p.oid is null or md5(regexp_replace(p.prosrc,'\s+','','g'))<>expected.body_hash
  ) then
    raise exception 'sitaa_0010_post_ddl_function_body_mismatch';
  end if;
  if exists (
       with expected(function_oid,grantee) as (
         values
           ('public.guard_admin_auth_operation_b3a()'::regprocedure::oid,'postgres'::regrole::oid),
           ('public.get_admin_account_auth_lifecycle_context_b3a(uuid)'::regprocedure::oid,'postgres'::regrole::oid),
           ('public.get_admin_account_auth_lifecycle_context_b3a(uuid)'::regprocedure::oid,'authenticated'::regrole::oid),
           ('public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)'::regprocedure::oid,'postgres'::regrole::oid),
           ('public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)'::regprocedure::oid,'authenticated'::regrole::oid),
           ('public.finalize_admin_account_auth_reactivation_b3a(uuid)'::regprocedure::oid,'postgres'::regrole::oid),
           ('public.finalize_admin_account_auth_reactivation_b3a(uuid)'::regprocedure::oid,'authenticated'::regrole::oid),
           ('public.claim_admin_auth_operation_b3a(uuid,uuid)'::regprocedure::oid,'postgres'::regrole::oid),
           ('public.claim_admin_auth_operation_b3a(uuid,uuid)'::regprocedure::oid,'service_role'::regrole::oid),
           ('public.record_admin_auth_operation_result_b3a(uuid,uuid,text,text)'::regprocedure::oid,'postgres'::regrole::oid),
           ('public.record_admin_auth_operation_result_b3a(uuid,uuid,text,text)'::regprocedure::oid,'service_role'::regrole::oid)
       ), actual(function_oid,grantee) as (
         select p.oid,acl.grantee
         from pg_proc p
         cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
         where p.oid in (select expected.function_oid from expected)
           and acl.privilege_type='EXECUTE' and not acl.is_grantable
       )
       (select * from expected except select * from actual)
       union all
       (select * from actual except select * from expected)
     )
     or exists (
       select 1
       from pg_proc p
       cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
       where p.oid in (
         'public.guard_admin_auth_operation_b3a()'::regprocedure,
         'public.get_admin_account_auth_lifecycle_context_b3a(uuid)'::regprocedure,
         'public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)'::regprocedure,
         'public.finalize_admin_account_auth_reactivation_b3a(uuid)'::regprocedure,
         'public.claim_admin_auth_operation_b3a(uuid,uuid)'::regprocedure,
         'public.record_admin_auth_operation_result_b3a(uuid,uuid,text,text)'::regprocedure
       ) and (acl.privilege_type<>'EXECUTE' or acl.is_grantable)
     )
     or has_function_privilege('authenticated','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or has_function_privilege('anon','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or has_function_privilege('service_role','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
     or (select count(*) from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where p.oid='public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure and acl.privilege_type='EXECUTE' and acl.grantee=p.proowner and not acl.is_grantable)<>1
     or exists(select 1 from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where p.oid='public.transition_admin_account_lifecycle_b2b(uuid,text,text)'::regprocedure and (acl.privilege_type<>'EXECUTE' or acl.grantee<>p.proowner or acl.is_grantable)) then
     raise exception 'sitaa_0010_post_ddl_acl_mismatch';
  end if;
  if (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')<>60
     or (select count(*) from information_schema.tables where table_schema='public' and table_type='BASE TABLE')<>19
     or (select count(*) from pg_policies where schemaname='public')<>25
     or (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and c.relrowsecurity)<>19 then
    raise exception 'sitaa_0010_post_ddl_inventory_mismatch';
  end if;
end;
$post_ddl$;

commit;
