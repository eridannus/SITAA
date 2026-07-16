# Estado reconciliado de la base de datos

**Estado:** reconciliado contra el snapshot vivo completo de Supabase generado el 16 de julio de 2026.

La fuente autoritativa es `supabase/reconciliation/live/live_schema.sql`, verificada con los snapshots especializados de tablas, columnas, constraints, índices, triggers, funciones, políticas y semillas. La baseline resultante es `supabase/migrations/0001_baseline_current_schema.sql`.

## Resultado de validación

- 10 archivos esperados presentes y no vacíos.
- 17 tablas públicas.
- 151 columnas.
- 61 constraints PK, FK, UNIQUE o CHECK.
- 37 índices, incluidos los respaldados implícitamente por constraints.
- 4 triggers.
- 30 funciones públicas.
- 23 políticas RLS.
- 17 tablas con RLS habilitado.
- 51 filas de semillas en 11 catálogos controlados.
- Sin diferencias estructurales entre `live_schema.sql` y los snapshots especializados.
- Sin credenciales, mojibake ni datos personales u operativos en las semillas.

## Tablas públicas reconciliadas

- `academic_periods`
- `academic_programs`
- `activities`
- `activity_checkin_tokens`
- `activity_modalities`
- `activity_participants`
- `activity_statuses`
- `activity_types`
- `attention_categories`
- `divisions`
- `location_types`
- `participant_roles`
- `profiles`
- `role_assignments`
- `roles`
- `service_types`
- `system_health`

## Funciones reconciliadas

Se preservaron las 30 firmas vivas:

- `activity_attendance_deadline(uuid)`
- `activity_attendance_open_at(uuid)`
- `activity_has_ended(uuid)`
- `add_activity_participant(uuid,uuid,text)`
- `can_create_activity(text,uuid,uuid,text)`
- `can_create_activity(uuid,text)`
- `can_delete_activity(uuid)`
- `can_edit_activity(uuid)`
- `can_manage_activity(text,uuid,uuid,text)`
- `can_manage_activity(uuid,text)`
- `can_read_activity(uuid)`
- `can_update_activity_base(uuid)`
- `check_in_activity(text)`
- `close_activity_attendance_checkin(uuid)`
- `finalize_expired_attendance()`
- `generate_three_word_code()`
- `get_academic_period_for_date(date)`
- `get_active_activity_attendance_checkin(uuid)`
- `get_activity_attendance_checkin_state(uuid)`
- `get_activity_participants(uuid)`
- `get_visible_activity_cards()`
- `has_active_role(text)`
- `has_any_active_role(text[])`
- `is_activity_participant(uuid)`
- `open_activity_attendance_checkin(uuid)`
- `remove_activity_participant(uuid)`
- `search_profiles_for_participation(uuid,text)`
- `set_updated_at()`
- `update_activity_participant_attendance(uuid,text,text)`
- `update_activity_participants_attendance_bulk(uuid,uuid[],text,text)`

## Triggers y políticas

Los triggers reconciliados son:

- `activities.set_activities_updated_at`
- `activity_participants.set_activity_participants_updated_at`
- `profiles.set_profiles_updated_at`
- `role_assignments.set_role_assignments_updated_at`

Las 23 políticas RLS cubren `academic_periods`, `academic_programs`, `activities`, `activity_modalities`, `activity_participants`, `activity_statuses`, `activity_types`, `attention_categories`, `divisions`, `location_types`, `participant_roles`, `profiles`, `role_assignments`, `roles`, `service_types` y `system_health`.

## Catálogos reproducibles

La baseline incluye semillas verificadas para `divisions`, `academic_programs`, `roles`, `academic_periods`, `activity_types`, `service_types`, `attention_categories`, `activity_modalities`, `activity_statuses`, `location_types` y `participant_roles`. La inserción respeta primero la dependencia de `academic_programs` hacia `divisions`.

## Alcance y pendiente verificable

El esquema vivo depende de `extensions.unaccent`, por lo que la baseline crea esa extensión en el esquema `extensions`. `gen_random_uuid()` forma parte del PostgreSQL vivo capturado.

El dump se produjo con `--no-privileges` y no existe un snapshot independiente de grants. Por ello, los grants administrados por Supabase siguen pendientes de reconciliación explícita para una instalación PostgreSQL ajena a Supabase. No se inventaron grants en `0001`.
