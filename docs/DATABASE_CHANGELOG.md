# Historial de cambios de base de datos

Los cambios SQL anteriores a la baseline fueron aplicados manualmente durante el prototipo.

## 0001_baseline_current_schema.sql — baseline reconciliada

- Fecha: 2026-07-16.
- Propósito: capturar el estado vivo completo de Supabase y establecer el punto de partida para instalaciones nuevas y migraciones futuras.
- Fuentes: los 10 archivos bajo `supabase/reconciliation/live/`, generados mediante `pg_dump 18.4` y `psql 18.4` en modo de sólo lectura.
- Objetos: 17 tablas, 151 columnas, 61 constraints, 37 índices, 4 triggers, 30 funciones, RLS para 17 tablas, 23 políticas y 51 filas de semillas controladas.
- Aplicado en Supabase desde el repositorio: no. El estado ya existe por cambios manuales del prototipo.
- Seguridad: la baseline no debe ejecutarse a ciegas contra la base viva actual.
- Pendiente verificable: regenerar el snapshot vivo con el flujo ampliado para capturar grants y ACL; el dump de esquema permanece deliberadamente en `--no-privileges`.

Esta versión sustituye completamente el intento anterior de `0001`, construido desde snapshots JSON incompletos. La versión anterior nunca fue aplicada como migración administrada y ya no es autoritativa.

## Ampliación del snapshot de privilegios — 2026-07-16

- El flujo PowerShell incorpora `live_routine_privileges.sql`, `live_table_privileges.sql`, `live_sequence_privileges.sql` y `live_acl.sql`.
- Las fuentes son `information_schema.routine_privileges`, `information_schema.table_privileges`, ACL de secuencias y la expansión de `pg_proc.proacl`/`pg_class.relacl`.
- Todas las consultas se ejecutan en transacciones de sólo lectura y primero escriben a un directorio temporal.
- La generación completa falla si falta cualquiera de los cuatro artefactos; no se publican snapshots parciales.
- Este cambio no modifica la baseline ni aplica privilegios a Supabase. La evidencia quedará reconciliada cuando se ejecute nuevamente el script con `SUPABASE_DB_URL` disponible.

## Regla para cambios posteriores

`0001` queda fija después de esta reconciliación y sólo puede corregirse ante un defecto comprobado de la baseline. Todo cambio nuevo se registra de forma incremental:

- `0002_short_description.sql`
- `0003_short_description.sql`
- y así sucesivamente.

La migración debe crearse antes o junto con el SQL aplicado a Supabase. Si se ejecuta manualmente en Supabase SQL Editor, el archivo versionado y esta bitácora se actualizan en el mismo cambio.

Formato para nuevas entradas:

### 0002_short_description.sql

- Fecha:
- Propósito:
- Objetos afectados:
- Aplicado en Supabase:
- Observaciones:

## Flujo de snapshots

En Windows se usa:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pull-supabase-snapshot.ps1
```

El flujo no aplica cambios remotos. Genera artefactos de reconciliación en `supabase/reconciliation/live/`, que deben validarse antes de preparar una migración.

## 0002_database_security_and_integrity.sql — consolidación aplicada

- Fecha: 2026-07-16.
- Propósito: aislar borradores por creador, impedir asistencia pendiente vencida, publicar actividades completas de forma transaccional y aplicar privilegios mínimos confirmados.
- Objetos reemplazados: `can_read_activity`, `can_edit_activity`, `can_update_activity_base`, `can_delete_activity`, dos RPC de actualización de asistencia y dos políticas SELECT.
- Objetos nuevos: `publish_activity(uuid)`, `validate_activity_scheduled_state()`, trigger `validate_activities_scheduled_state`, `guard_activity_participant_pending_deadline()` y trigger `guard_activity_participants_pending_deadline`.
- Privilegios: se propone retirar `EXECUTE` de `PUBLIC`/`anon`, dejar a `anon` sólo `system_health.SELECT`, reconstruir el contrato directo de `authenticated` y retirar la secuencia de roles cliente.
- Verificación: `supabase/reconciliation/0002_database_security_and_integrity_verify.sql`.
- Rollback manual: `supabase/reconciliation/0002_database_security_and_integrity_rollback.sql`.
- Plan de pruebas: `docs/TEST_PLAN_0002.md`.
- Aplicado y verificado en Supabase: **sí**.
- Observaciones: el preflight aborta ante filas `scheduled` incompatibles; no corrige ni elimina datos. La publicación directa revalida creador y permiso vigente, `created_by` no cambia, una actividad publicada no vuelve a borrador y ningún `UPDATE` directo puede restaurar `pending` vencido. A-02 permanece diferido y no se restringe `technical_admin` sobre contenido publicado.

## 0003_fix_draft_temporal_lifecycle.sql — temporalidad provisional de borradores

- Fecha: 2026-07-16.
- Propósito: impedir que fechas u horas provisionales bloqueen un borrador propio.
- Objetos reemplazados: `activity_has_ended(uuid)`, `can_update_activity_base(uuid)` y `can_delete_activity(uuid)`.
- Datos: no reescribe ni elimina filas; los borradores atrapados se recuperan al cambiar la evaluación de los helpers.
- Compatibilidad: conserva privacidad de borradores, validación de publicación, privilegios mínimos, `technical_admin` sobre contenido publicado y controles de asistencia de 0002.
- Verificación: `supabase/reconciliation/0003_fix_draft_temporal_lifecycle_verify.sql`.
- Rollback manual: `supabase/reconciliation/0003_fix_draft_temporal_lifecycle_rollback.sql`.
- Plan de pruebas: `docs/TEST_PLAN_0003.md`.
- Aplicado en Supabase: **no**.
