-- Preflight independiente de sólo lectura para SITAA 0006.
-- La salida normal contiene exclusivamente categorías y conteos agregados.

begin transaction read only;

with function_oids as (
  select
    to_regprocedure('public.complete_own_google_registration(text,text,text,uuid)') as completion_oid,
    to_regprocedure('public.complete_own_google_registration(text,text,text,text,text,uuid)') as structured_completion_oid,
    to_regprocedure('public.handle_sitaa_auth_user_created()') as auth_handler_oid,
    to_regprocedure('public.enforce_sitaa_profile_identity()') as profile_enforcer_oid
), definitions as (
  select
    f.*,
    case when completion_oid is null then '' else lower(pg_get_functiondef(completion_oid)) end as completion_def,
    case when auth_handler_oid is null then '' else lower(pg_get_functiondef(auth_handler_oid)) end as auth_handler_def,
    case when profile_enforcer_oid is null then '' else lower(pg_get_functiondef(profile_enforcer_oid)) end as profile_enforcer_def,
    case when profile_enforcer_oid is null then null else (
      select p.prosecdef from pg_proc p where p.oid = profile_enforcer_oid
    ) end as profile_enforcer_is_definer
  from function_oids f
), categories(category, affected_rows, classification) as (
  select 'missing_structured_name_column', count(*), 'blocking'
  from (values ('first_names'), ('paternal_surname'), ('maternal_surname')) expected(column_name)
  where not exists (
    select 1 from information_schema.columns c
    where c.table_schema = 'public' and c.table_name = 'profiles'
      and c.column_name = expected.column_name and c.data_type = 'text'
  )
  union all
  select 'active_or_inactive_without_first_names', count(*), 'blocking'
  from public.profiles p
  where p.account_status in ('active', 'inactive') and nullif(btrim(p.first_names), '') is null
  union all
  select 'institutional_without_paternal_surname', count(*), 'blocking'
  from public.profiles p
  where p.account_kind = 'institutional' and p.account_status in ('active', 'inactive')
    and nullif(btrim(p.paternal_surname), '') is null
  union all
  select 'pending_with_partial_structured_identity', count(*), 'blocking'
  from public.profiles p
  where p.account_status = 'pending_registration'
    and (p.first_names is not null or p.paternal_surname is not null or p.maternal_surname is not null)
  union all
  select 'structured_component_too_long', count(*), 'blocking'
  from public.profiles p
  where coalesce(char_length(regexp_replace(btrim(p.first_names), '\s+', ' ', 'g')), 0) > 150
     or coalesce(char_length(regexp_replace(btrim(p.paternal_surname), '\s+', ' ', 'g')), 0) > 150
     or coalesce(char_length(regexp_replace(btrim(p.maternal_surname), '\s+', ' ', 'g')), 0) > 150
  union all
  select 'derived_full_name_too_long', count(*), 'blocking'
  from public.profiles p
  where p.first_names is not null and char_length(concat_ws(' ',
    nullif(regexp_replace(btrim(coalesce(p.first_names, '')), '\s+', ' ', 'g'), ''),
    nullif(regexp_replace(btrim(coalesce(p.paternal_surname, '')), '\s+', ' ', 'g'), ''),
    nullif(regexp_replace(btrim(coalesce(p.maternal_surname, '')), '\s+', ' ', 'g'), '')
  )) > 200
  union all
  select 'full_name_requires_resynchronization', count(*), 'informational'
  from public.profiles p
  where p.first_names is not null and p.full_name is distinct from concat_ws(' ',
    nullif(regexp_replace(btrim(coalesce(p.first_names, '')), '\s+', ' ', 'g'), ''),
    nullif(regexp_replace(btrim(coalesce(p.paternal_surname, '')), '\s+', ' ', 'g'), ''),
    nullif(regexp_replace(btrim(coalesce(p.maternal_surname, '')), '\s+', ' ', 'g'), '')
  )
  union all
  select 'missing_post_0005_completion_function', (completion_oid is null)::int, 'blocking' from definitions
  union all
  select 'unexpected_post_0005_completion_definition',
    (completion_oid is not null and not (
      completion_def like '%security definer%'
      and completion_def like '%set search_path to ''pg_catalog'', ''public'', ''auth''%'
      and completion_def like '%requested_full_name%'
      and completion_def like '%sitaa_google_identity_required%'
      and completion_def like '%sitaa_google_identity_email_mismatch%'
      and completion_def like '%sitaa_google_email_not_verified%'
      and completion_def like '%sitaa_registration_not_pending%'
      and completion_def like '%sitaa_identifier_conflict%'
      and completion_def not like '%requested_first_names%'
    ))::int, 'blocking' from definitions
  union all
  select 'missing_post_0005_auth_trigger_function', (auth_handler_oid is null)::int, 'blocking' from definitions
  union all
  select 'unexpected_post_0005_auth_trigger_definition',
    (auth_handler_oid is not null and not (
      auth_handler_def like '%security definer%'
      and auth_handler_def like '%set search_path to ''pg_catalog'', ''public'', ''auth''%'
      and auth_handler_def like '%if is_google then%'
      and auth_handler_def like '%pending_registration%'
      and auth_handler_def like '%provisional_name%'
      and auth_handler_def like '%sitaa_unverified_technical_email%'
      and auth_handler_def like '%sitaa_public_password_signup_disabled%'
      and auth_handler_def like '%sitaa_unsupported_auth_provider%'
      and auth_handler_def like '%sitaa_missing_or_invalid_account_metadata%'
      and auth_handler_def not like '%sitaa_google_email_not_verified%'
    ))::int, 'blocking' from definitions
  union all
  select 'unexpected_post_0005_profile_enforcement_definition',
    (profile_enforcer_oid is null or not (
      profile_enforcer_is_definer = false
      and profile_enforcer_def like '%set search_path to ''pg_catalog'', ''public''%'
      and profile_enforcer_def like '%to_jsonb(new) - ''full_name'' - ''updated_at''%'
      and profile_enforcer_def like '%sólo puedes actualizar tu nombre completo.%'
      and profile_enforcer_def not like '%first_names%'
      and profile_enforcer_def not like '%paternal_surname%'
    ))::int, 'blocking' from definitions
  union all
  select 'missing_post_0005_auth_trigger', count(*), 'blocking'
  from (values
    ('on_sitaa_auth_user_created', 'handle_sitaa_auth_user_created'),
    ('on_sitaa_auth_user_email_changed', 'sync_sitaa_profile_email_from_auth')
  ) expected(trigger_name, function_name)
  where not exists (
    select 1 from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_proc p on p.oid = t.tgfoid
    where not t.tgisinternal and n.nspname = 'auth' and c.relname = 'users'
      and t.tgname = expected.trigger_name and p.proname = expected.function_name
  )
  union all
  select 'missing_post_0005_profile_trigger', count(*), 'blocking'
  from (values
    ('enforce_sitaa_profile_identity', 'enforce_sitaa_profile_identity'),
    ('set_profiles_updated_at', 'set_updated_at')
  ) expected(trigger_name, function_name)
  where not exists (
    select 1 from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_proc p on p.oid = t.tgfoid
    where not t.tgisinternal and n.nspname = 'public' and c.relname = 'profiles'
      and t.tgname = expected.trigger_name and p.proname = expected.function_name
  )
  union all
  select 'unexpected_completion_privileges',
    ((completion_oid is null)
      or not has_function_privilege('authenticated', completion_oid, 'EXECUTE')
      or has_function_privilege('anon', completion_oid, 'EXECUTE')
      or exists (
        select 1 from pg_proc p
        cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
        where p.oid = completion_oid and acl.grantee = 0 and acl.privilege_type = 'EXECUTE'
      )
      or structured_completion_oid is not null)::int,
    'blocking'
  from definitions
  union all
  select 'unexpected_profile_update_privileges',
    ((not has_column_privilege('authenticated', 'public.profiles', 'full_name', 'UPDATE'))
      or has_table_privilege('authenticated', 'public.profiles', 'UPDATE')
      or exists (
        select 1 from pg_attribute a
        where a.attrelid = 'public.profiles'::regclass and a.attnum > 0 and not a.attisdropped
          and a.attname <> 'full_name'
          and has_column_privilege('authenticated', 'public.profiles', a.attname, 'UPDATE')
      ))::int,
    'blocking'
)
select category, affected_rows, classification
from categories
order by case classification when 'blocking' then 0 else 1 end, category;

-- Consulta privada opcional para operación, deliberadamente deshabilitada:
-- select id from public.profiles where account_status in ('active','inactive')
--   and nullif(btrim(first_names), '') is null;

rollback;
