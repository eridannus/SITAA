-- Rollback manual de SITAA 0003.
--
-- Restaura las definiciones exactas posteriores a 0002. Esto restaura también
-- el defecto conocido: un borrador con fecha provisional pasada puede volver a
-- quedar bloqueado por activity_has_ended. No usa CASCADE ni modifica filas.

begin;

create or replace function public.activity_has_ended(target_activity_id uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $$
  select coalesce(
    (
      coalesce(a.end_date, a.start_date)::timestamp
      + coalesce(a.end_time, a.start_time, time '23:59:59')
    ) < (now() at time zone 'America/Mexico_City'),
    false
  )
  from public.activities a
  where a.id = target_activity_id;
$$;

create or replace function public.can_update_activity_base(target_activity_id uuid)
returns boolean language sql stable security definer set search_path to 'public'
as $$
  select exists (
    select 1 from public.activities a
    where a.id = target_activity_id
      and (
        (
          a.status_code = 'draft'
          and a.created_by = auth.uid()
          and not public.activity_has_ended(a.id)
        )
        or (
          a.status_code <> 'draft'
          and public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)
        )
      )
  );
$$;

create or replace function public.can_delete_activity(target_activity_id uuid)
returns boolean language sql stable security definer set search_path to 'public'
as $$
  select exists (
    select 1 from public.activities a
    where a.id = target_activity_id
      and (
        (
          a.status_code = 'draft'
          and a.created_by = auth.uid()
          and not public.activity_has_ended(a.id)
        )
        or (
          a.status_code <> 'draft'
          and public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)
        )
      )
  );
$$;

commit;
