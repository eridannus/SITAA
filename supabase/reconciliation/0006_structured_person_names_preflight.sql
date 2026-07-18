-- Preflight de sólo lectura para SITAA 0006.
-- La salida normal contiene únicamente conteos; no expone identidad personal.

begin transaction read only;

select
  count(*) filter (
    where account_status in ('active', 'inactive') and nullif(btrim(first_names), '') is null
  ) as cuentas_sin_nombres,
  count(*) filter (
    where account_kind = 'institutional' and account_status in ('active', 'inactive')
      and nullif(btrim(paternal_surname), '') is null
  ) as institucionales_sin_apellido_paterno,
  count(*) filter (
    where account_status = 'pending_registration'
      and (first_names is not null or paternal_surname is not null or maternal_surname is not null)
  ) as pendientes_con_identidad_parcial,
  count(*) filter (
    where coalesce(char_length(regexp_replace(btrim(first_names), '\s+', ' ', 'g')), 0) > 150
       or coalesce(char_length(regexp_replace(btrim(paternal_surname), '\s+', ' ', 'g')), 0) > 150
       or coalesce(char_length(regexp_replace(btrim(maternal_surname), '\s+', ' ', 'g')), 0) > 150
       or char_length(concat_ws(' ',
         nullif(regexp_replace(btrim(coalesce(first_names, '')), '\s+', ' ', 'g'), ''),
         nullif(regexp_replace(btrim(coalesce(paternal_surname, '')), '\s+', ' ', 'g'), ''),
         nullif(regexp_replace(btrim(coalesce(maternal_surname, '')), '\s+', ' ', 'g'), '')
       )) > 200
  ) as componentes_fuera_de_limite,
  count(*) filter (
    where first_names is not null
      and full_name is distinct from concat_ws(' ',
        nullif(regexp_replace(btrim(first_names), '\s+', ' ', 'g'), ''),
        nullif(regexp_replace(btrim(paternal_surname), '\s+', ' ', 'g'), ''),
        nullif(regexp_replace(btrim(maternal_surname), '\s+', ' ', 'g'), '')
      )
  ) as nombres_compatibilidad_por_sincronizar
from public.profiles;

select
  (to_regprocedure('public.complete_own_google_registration(text,text,text,uuid)') is not null)::int as rpc_post_0005,
  (to_regprocedure('public.handle_sitaa_auth_user_created()') is not null)::int as trigger_auth_post_0005,
  (to_regprocedure('public.enforce_sitaa_profile_identity()') is not null)::int as proteccion_profile_post_0005;

rollback;
