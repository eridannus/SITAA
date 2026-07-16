-- ROLLBACK MANUAL DE EMERGENCIA PARA SITAA 0002
--
-- Fuente: 0001_baseline_current_schema.sql y snapshots vivos reconciliados.
-- Revisar antes de ejecutar y coordinar con el despliegue de la aplicación, pues la
-- versión adaptada depende de public.publish_activity(uuid).
--
-- Este rollback restaura únicamente objetos, políticas y grants cambiados por 0002.
-- No elimina datos de aplicación ni puede deshacer datos producidos mientras 0002
-- estuvo activa. No usa CASCADE.

begin;

drop trigger if exists validate_activities_scheduled_state on public.activities;
drop function if exists public.publish_activity(uuid);
drop function if exists public.validate_activity_scheduled_state();

-- -----------------------------------------------------------------------------
-- Helpers baseline
-- -----------------------------------------------------------------------------

create or replace function public.can_delete_activity(target_activity_id uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $$
  select exists (
    select 1
    from public.activities a
    where a.id = target_activity_id
      and (
        public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)
        or (
          (a.created_by = auth.uid() or a.responsible_profile_id = auth.uid())
          and a.status_code = 'draft'
          and not public.activity_has_ended(a.id)
        )
      )
  );
$$;

create or replace function public.can_edit_activity(target_activity_id uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $$
  select exists (
    select 1
    from public.activities a
    where a.id = target_activity_id
      and (
        a.created_by = auth.uid()
        or a.responsible_profile_id = auth.uid()
        or public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)
      )
  );
$$;

create or replace function public.can_read_activity(target_activity_id uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $$
  select exists (
    select 1
    from public.activities a
    where a.id = target_activity_id
      and (
        a.created_by = auth.uid()
        or a.responsible_profile_id = auth.uid()
        or public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)
      )
  );
$$;

create or replace function public.can_update_activity_base(target_activity_id uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $$
  select exists (
    select 1
    from public.activities a
    where a.id = target_activity_id
      and (
        public.can_manage_activity(a.scope_type, a.program_id, a.division_id, a.service_type_code)
        or (
          (a.created_by = auth.uid() or a.responsible_profile_id = auth.uid())
          and a.status_code = 'draft'
          and not public.activity_has_ended(a.id)
        )
      )
  );
$$;

drop policy if exists "Users can read permitted activities" on public.activities;
create policy "Users can read permitted activities"
on public.activities for select to authenticated
using (
  created_by = auth.uid()
  or responsible_profile_id = auth.uid()
  or public.is_activity_participant(id)
  or public.can_manage_activity(scope_type, program_id, division_id, service_type_code)
);

drop policy if exists "Users can read permitted activity participants" on public.activity_participants;
create policy "Users can read permitted activity participants"
on public.activity_participants for select to authenticated
using (profile_id = auth.uid() or public.can_read_activity(activity_id));

-- -----------------------------------------------------------------------------
-- RPC de asistencia baseline
-- -----------------------------------------------------------------------------

create or replace function public.update_activity_participant_attendance(
  target_participant_id uuid,
  new_attendance_status text,
  new_attendance_notes text default null::text
)
returns void
language plpgsql security definer set search_path to 'public'
as $$
declare
  target_activity_id uuid;
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
$$;

create or replace function public.update_activity_participants_attendance_bulk(
  target_activity_id uuid,
  target_participant_ids uuid[],
  new_attendance_status text,
  new_attendance_notes text default null::text
)
returns integer
language plpgsql security definer set search_path to 'public'
as $$
declare
  updated_count integer;
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
$$;

-- -----------------------------------------------------------------------------
-- Grants baseline explícitos
-- -----------------------------------------------------------------------------

grant execute on function public.activity_attendance_deadline(uuid) to public, anon;
grant execute on function public.activity_attendance_open_at(uuid) to public, anon;
grant execute on function public.activity_has_ended(uuid) to public, anon;
grant execute on function public.add_activity_participant(uuid, uuid, text) to public, anon;
grant execute on function public.can_create_activity(uuid, text) to public, anon;
grant execute on function public.can_create_activity(text, uuid, uuid, text) to public, anon;
grant execute on function public.can_delete_activity(uuid) to public, anon;
grant execute on function public.can_edit_activity(uuid) to public, anon;
grant execute on function public.can_manage_activity(uuid, text) to public, anon;
grant execute on function public.can_manage_activity(text, uuid, uuid, text) to public, anon;
grant execute on function public.can_read_activity(uuid) to public, anon;
grant execute on function public.can_update_activity_base(uuid) to public, anon;
grant execute on function public.check_in_activity(text) to public, anon;
grant execute on function public.close_activity_attendance_checkin(uuid) to public, anon;
grant execute on function public.finalize_expired_attendance() to public, anon;
grant execute on function public.generate_three_word_code() to public, anon;
grant execute on function public.get_academic_period_for_date(date) to public, anon;
grant execute on function public.get_active_activity_attendance_checkin(uuid) to public, anon;
grant execute on function public.get_activity_attendance_checkin_state(uuid) to public, anon;
grant execute on function public.get_activity_participants(uuid) to public, anon;
grant execute on function public.get_visible_activity_cards() to public, anon;
grant execute on function public.has_active_role(text) to public, anon;
grant execute on function public.has_any_active_role(text[]) to public, anon;
grant execute on function public.is_activity_participant(uuid) to public, anon;
grant execute on function public.open_activity_attendance_checkin(uuid) to public, anon;
grant execute on function public.remove_activity_participant(uuid) to public, anon;
grant execute on function public.search_profiles_for_participation(uuid, text) to public, anon;
grant execute on function public.set_updated_at() to public, anon;
grant execute on function public.update_activity_participant_attendance(uuid, text, text) to public, anon;
grant execute on function public.update_activity_participants_attendance_bulk(uuid, uuid[], text, text) to public, anon;

grant all privileges on table
  public.academic_periods,
  public.academic_programs,
  public.activities,
  public.activity_checkin_tokens,
  public.activity_modalities,
  public.activity_participants,
  public.activity_statuses,
  public.activity_types,
  public.attention_categories,
  public.divisions,
  public.location_types,
  public.participant_roles,
  public.profiles,
  public.role_assignments,
  public.roles,
  public.service_types,
  public.system_health
to anon, authenticated;

grant all privileges on sequence public.system_health_id_seq to anon, authenticated;

-- Los grants de postgres/service_role y el comportamiento de technical_admin no
-- fueron modificados por 0002 ni por este rollback.
commit;
