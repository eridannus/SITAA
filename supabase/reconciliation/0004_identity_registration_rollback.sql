-- Rollback manual de emergencia para SITAA 0004 (Google OAuth).
-- No elimina usuarios Auth, profiles ni identidades Google. Requiere revisión.

begin;

do $operator_review$
begin
  if current_setting('sitaa.rollback_0004_reviewed', true) is distinct from 'yes' then
    raise exception 'Rollback 0004 detenido: falta revisión explícita de cuentas creadas bajo 0004.';
  end if;
  if exists (
    select 1 from public.profiles
    where account_kind = 'technical' or account_status = 'pending_registration'
  ) then
    raise exception 'Rollback 0004 detenido: existen cuentas que no pueden mapearse con seguridad a 0003.';
  end if;
end;
$operator_review$;

drop trigger if exists on_sitaa_auth_user_created on auth.users;
drop trigger if exists on_sitaa_auth_user_email_changed on auth.users;
drop trigger if exists enforce_sitaa_profile_identity on public.profiles;

revoke all on function public.complete_own_google_registration(text) from public, anon, authenticated;
revoke all on function public.create_registration_intent(text, text, text, uuid) from public, anon, authenticated;
drop function if exists public.complete_own_google_registration(text);
drop function if exists public.create_registration_intent(text, text, text, uuid);
drop function if exists public.sync_sitaa_profile_email_from_auth();
drop function if exists public.handle_sitaa_auth_user_created();
drop function if exists public.enforce_sitaa_profile_identity();

revoke all on table public.registration_intents from public, anon, authenticated;
drop table if exists public.registration_intents;

drop policy if exists "Public can read active academic programs" on public.academic_programs;
revoke select on table public.academic_programs from anon;

revoke update (full_name) on table public.profiles from authenticated;
grant select, update on table public.profiles to authenticated;

drop index if exists public.profiles_institutional_identifier_pair_key;
alter table public.profiles drop constraint if exists profiles_account_lifecycle_check;
alter table public.profiles drop constraint if exists profiles_account_identity_check;
alter table public.profiles drop constraint if exists profiles_email_check;
alter table public.profiles drop constraint if exists profiles_full_name_check;
alter table public.profiles drop constraint if exists profiles_identifier_length_check;
alter table public.profiles drop constraint if exists profiles_identifier_digits_check;
alter table public.profiles drop constraint if exists profiles_institutional_id_type_check;
alter table public.profiles drop constraint if exists profiles_person_type_check;
alter table public.profiles drop constraint if exists profiles_account_status_check;
alter table public.profiles drop constraint if exists profiles_account_kind_check;

update public.profiles
set person_type = case when person_type = 'professor' then 'worker' else person_type end,
    is_active = account_status = 'active';

alter table public.profiles alter column is_active set default true;
alter table public.profiles
  add constraint profiles_institutional_id_type_check
    check (institutional_id_type is null or institutional_id_type in ('student_account', 'worker_number')),
  add constraint profiles_person_identifier_consistency_check
    check (
      person_type is null or institutional_id_type is null
      or (person_type = 'student' and institutional_id_type = 'student_account')
      or (person_type = 'worker' and institutional_id_type = 'worker_number')
    ),
  add constraint profiles_person_type_check
    check (person_type is null or person_type in ('student', 'worker'));

alter table public.profiles
  drop column if exists deactivated_at,
  drop column if exists activated_at,
  drop column if exists account_status,
  drop column if exists account_kind;

alter table public.academic_programs drop column if exists is_active;

create or replace function public.add_activity_participant(
  target_activity_id uuid,
  target_profile_id uuid,
  target_participant_role_code text
) returns void
language plpgsql
security definer
set search_path = public
as $function$
declare
  target_program_id uuid;
  participant_program_id uuid;
  participant_person_type text;
begin
  if not public.can_edit_activity(target_activity_id) then
    raise exception 'No tienes permiso para agregar participantes a esta actividad.' using errcode = '42501';
  end if;
  select a.program_id into target_program_id from public.activities a where a.id = target_activity_id;
  if target_program_id is null then
    raise exception 'La actividad no tiene programa académico asignado.' using errcode = 'P0001';
  end if;
  select p.primary_program_id, p.person_type
  into participant_program_id, participant_person_type
  from public.profiles p
  where p.id = target_profile_id and p.is_active = true;
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
  if target_participant_role_code = 'responsible' and participant_person_type <> 'worker' then
    raise exception 'Sólo un trabajador puede registrarse como responsable de la actividad.' using errcode = 'P0001';
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

revoke all on function public.add_activity_participant(uuid, uuid, text) from public, anon;
grant execute on function public.add_activity_participant(uuid, uuid, text) to authenticated;

commit;

-- No reversible automáticamente:
-- - las identidades Google vinculadas en auth.identities permanecen;
-- - los Auth users y profiles permanecen;
-- - el trigger de alta Google y los intents dejan de existir;
-- - pgcrypto no se elimina porque puede ser compartida por otras capacidades.
