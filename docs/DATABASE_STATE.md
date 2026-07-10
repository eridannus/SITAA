# Estado conocido de base de datos

**Estado:** reconciliado parcialmente contra snapshots vivos de Supabase.

Este documento resume el estado capturado desde los snapshots ubicados en `supabase/reconciliation/`. La baseline `supabase/migrations/0001_baseline_current_schema.sql` fue generada desde esos archivos. La reconciliación es parcial porque los snapshots disponibles cubren columnas, funciones y políticas RLS, pero no incluyen constraints, índices, triggers, grants ni datos semilla.

## Snapshots usados

- `live_columns_snapshot.json`: columnas públicas capturadas desde `information_schema.columns`.
- `live_functions_snapshot.json`: funciones públicas capturadas con `pg_get_functiondef`.
- `live_policies_snapshot.json`: políticas RLS públicas capturadas desde `pg_policies`.
- `live_snapshot_queries.sql`: consultas usadas para generar los snapshots.

## Tablas capturadas por columnas

- `public.academic_periods`
- `public.academic_programs`
- `public.activities`
- `public.activity_checkin_tokens`
- `public.activity_modalities`
- `public.activity_participants`
- `public.activity_statuses`
- `public.activity_types`
- `public.attention_categories`
- `public.divisions`
- `public.location_types`

## Tablas mencionadas por políticas pero pendientes de columnas

- `public.participant_roles`
- `public.profiles`
- `public.role_assignments`
- `public.roles`
- `public.service_types`
- `public.system_health`

Estas tablas aparecen en políticas RLS o en módulos conocidos, pero no tienen definición de columnas en el snapshot disponible. No se reconstruyeron en la baseline para evitar inventar SQL.

## Módulos conocidos

### Health check

Existe una verificación básica de conexión con Supabase mediante una tabla pública de salud del sistema. Su política aparece en el snapshot, pero sus columnas no fueron capturadas.

### Roles y asignaciones de rol

Las políticas mencionan `roles` y `role_assignments`. SITAA usa roles mediante asignaciones múltiples y acotadas, pero las columnas de estas tablas no están en el snapshot de columnas.

### Perfiles

Las políticas mencionan `profiles`. El modelo documentado conserva identidad institucional estable, pero sus columnas no están en el snapshot de columnas y deben reconciliarse contra Supabase vivo.

### Divisiones y programas académicos

`divisions` y `academic_programs` sí fueron capturadas por columnas. Se requieren constraints y relaciones reales para completar la baseline reproductible.

### Periodos académicos / semestres

`academic_periods` sí fue capturada por columnas. Las funciones de semestre fueron preservadas desde el snapshot de funciones.

### Catálogos operativos

Se capturaron por columnas: `activity_types`, `attention_categories`, `activity_modalities`, `activity_statuses` y `location_types`. `service_types` y `participant_roles` aparecen en políticas, pero no en columnas.

### Actividades

`activities` fue capturada por columnas. Las funciones relacionadas con visibilidad, edición, borrador/publicación, horarios y asistencia fueron preservadas desde el snapshot de funciones.

### Participantes de actividad

`activity_participants` fue capturada por columnas e incluye campos de asistencia manual, fuente, notas y marcas de actualización.

### Asistencia manual

La baseline preserva columnas de asistencia en `activity_participants` y funciones RPC relacionadas con actualización individual y masiva.

### Tokens de asistencia por QR/código

`activity_checkin_tokens` fue capturada por columnas. Las funciones de abrir, cerrar, consultar y registrar asistencia por token/código fueron preservadas desde el snapshot de funciones.

### Expiración y reapertura de asistencia

Las funciones de ventana de apertura, deadline, expiración perezosa y reapertura fueron preservadas desde `live_functions_snapshot.json`.

## Pendientes de reconciliación

- Primary keys, foreign keys, unique constraints y check constraints.
- Índices.
- Triggers, incluyendo actualización automática de `updated_at` si aplica.
- Grants y permisos de ejecución de funciones.
- Datos semilla mínimos de catálogos.
- Columnas reales de tablas mencionadas por políticas pero ausentes en `live_columns_snapshot.json`.
