-- SITAA 0003: ciclo temporal provisional de borradores.
--
-- Esta migración no reescribe actividades. Corrige funciones de autorización y
-- temporalidad para que una fecha u hora provisional nunca bloquee un borrador.
-- La validación de publicación de 0002 permanece sin cambios.

begin;

-- Un borrador no ha ocurrido: su calendario todavía es provisional. Para otros
-- estados se conserva exactamente la comparación de Ciudad de México vigente.
create or replace function public.activity_has_ended(target_activity_id uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $$
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
$$;

-- El creador siempre puede corregir su borrador, con independencia de sus
-- valores temporales provisionales. Los estados publicados conservan la
-- corrección administrativa definida por can_manage_activity.
create or replace function public.can_update_activity_base(target_activity_id uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $$
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
$$;

-- La eliminación sigue el mismo ciclo: borrador propio o contenido publicado
-- administrable. responsible_profile_id, participantes y gestores no amplían el
-- acceso a un borrador ajeno.
create or replace function public.can_delete_activity(target_activity_id uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $$
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
$$;

commit;
