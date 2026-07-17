# Historial de cambios de base de datos

Los cambios SQL anteriores a la baseline fueron aplicados manualmente durante el prototipo. Desde la baseline reconciliada, cada cambio se conserva como una migración numerada en el repositorio.

## 0001_baseline_current_schema.sql — baseline reconciliada

- Fecha: 2026-07-16.
- Estado: baseline reconciliada; no se aplicó sobre la base viva porque sus objetos ya existían por el historial manual del prototipo.
- Fuentes: snapshot completo generado con `pg_dump 18.4` y `psql 18.4` en modo de sólo lectura.
- Inventario original: 17 tablas, 151 columnas, 61 restricciones, 37 índices, 4 triggers, 30 funciones, 23 políticas RLS y 51 filas de semillas controladas.
- Alcance: tablas, columnas, restricciones, índices, funciones, triggers, RLS, políticas y catálogos reproducibles.
- Advertencia: no debe ejecutarse a ciegas contra el proyecto vivo.

Esta baseline sustituyó el intento anterior basado en snapshots JSON incompletos. La versión anterior nunca fue una migración administrada.

## Ampliación del snapshot de privilegios — 2026-07-16

- Se añadieron `live_routine_privileges.sql`, `live_table_privileges.sql`, `live_sequence_privileges.sql` y `live_acl.sql`.
- Las fuentes son vistas `information_schema` y ACL expandidas de `pg_proc` y `pg_class`.
- Todas las consultas se ejecutan en transacciones de sólo lectura y los archivos se publican como conjunto atómico.
- La evidencia permitió definir y después verificar los grants mínimos de 0002.

## 0002_database_security_and_integrity.sql — aplicada y verificada

- Fecha de aplicación y verificación: 2026-07-16.
- Propósito: aislar borradores por creador, impedir asistencia pendiente vencida, publicar actividades completas transaccionalmente y reducir privilegios cliente.
- Funciones reemplazadas: helpers de lectura/edición de actividades y RPC individual/masiva de asistencia.
- Objetos nuevos: `publish_activity(uuid)`, `validate_activity_scheduled_state()`, `guard_activity_participant_pending_deadline()` y dos triggers asociados.
- Políticas: lectura de actividades y participantes alineada con privacidad de borradores.
- Privilegios: sin `EXECUTE` de `PUBLIC`/`anon`; `anon` sólo lee `system_health`; `authenticated` no accede directamente a tokens ni a la secuencia.
- Verificación: `supabase/reconciliation/0002_database_security_and_integrity_verify.sql`, completada sin desviaciones.
- Rollback manual: `supabase/reconciliation/0002_database_security_and_integrity_rollback.sql`.
- Plan de pruebas: `docs/TEST_PLAN_0002.md`.
- Smoke tests: aprobados para privacidad de borradores, publicación, bloqueo, participantes, asistencia y check-in QR/código.
- Decisión diferida: no restringe `technical_admin` sobre contenido publicado.

## 0003_fix_draft_temporal_lifecycle.sql — aplicada y verificada

- Fecha de aplicación y verificación: 2026-07-16.
- Propósito: impedir que fecha u hora provisional bloquee un borrador propio.
- Funciones reemplazadas: `activity_has_ended(uuid)`, `can_update_activity_base(uuid)` y `can_delete_activity(uuid)`.
- Datos: no reescribe ni elimina filas.
- Compatibilidad: conserva publicación, privacidad, privilegios y ciclo de contenido publicado definidos por 0002.
- Verificación: `supabase/reconciliation/0003_fix_draft_temporal_lifecycle_verify.sql`; nueve resultados verdaderos y `ROLLBACK` final esperado.
- Rollback manual: `supabase/reconciliation/0003_fix_draft_temporal_lifecycle_rollback.sql`.
- Plan de pruebas: `docs/TEST_PLAN_0003.md`.
- Smoke tests: aprobados para edición/eliminación de borradores incompletos o pasados y rechazo de publicación inválida con retroalimentación por campo.

## Reconciliación posterior a 0003 — 2026-07-16

- Snapshot comparado: `2026-07-17T00:21:06Z`, según `live_snapshot_metadata.txt`.
- Cadena reconciliada: `0001 + 0002 + 0003`.
- Inventario vivo: 17 tablas, 151 columnas, 61 restricciones, 37 índices, 6 triggers, 33 funciones, 23 políticas y 51 semillas controladas.
- Privilegios vivos: 99 grants de rutina, 262 de tabla, 6 de secuencia y 401 entradas ACL expandidas.
- Resultado: sin deriva inexplicada.
- Diferencias ambientales inocuas: fecha del snapshot y valor aleatorio `\restrict` emitido por `pg_dump`.
- Los enlaces QR y de check-in fueron probados manualmente con el dominio canónico de producción.

## Flujo obligatorio a partir de 0004

El siguiente número permitido es `0004`. Todo cambio futuro debe:

1. revisar `0001` y todas las migraciones posteriores;
2. crear una nueva migración numerada, sin reescribir `0001`, `0002` o `0003`;
3. incluir verificación y rollback cuando sea apropiado;
4. aplicarse manualmente a Supabase;
5. regenerar el snapshot vivo después de cambios significativos;
6. comparar el estado vivo contra la cadena completa;
7. actualizar este changelog.

Los snapshots bajo `supabase/reconciliation/live/` son evidencia de reconciliación, no migraciones ejecutables.

## 0004_identity_registration_foundation.sql — aplicada

- Fecha de creación: 2026-07-17.
- Propósito: formalizar `institutional|technical`, `student|professor`, estados `pending_registration|active|inactive`, identificadores como texto y registro público Google OAuth.
- Reutiliza las columnas actuales de identidad; añade `account_kind`, `account_status`, `activated_at`, `deactivated_at` e `academic_programs.is_active`.
- Unicidad: par `(institutional_id_type, institutional_id_value)`; se permiten valores iguales entre tipos diferentes.
- Auth: trigger atómico para Google nuevo, sincronización de correo y soporte confiable de cuentas técnicas; signup público por contraseña queda rechazado y nunca se crean roles.
- Registro: Google crea un perfil pendiente; la identidad institucional se captura después de autenticar y se completa con un RPC transaccional exclusivo de `authenticated`. No hay tabla de intents ni escritura anónima.
- Autoservicio: UPDATE directo de `profiles` limitado a `full_name`.
- Preflight: `supabase/reconciliation/0004_identity_registration_preflight.sql`.
- Preflight Google: bloquea huérfanos Auth/profile, límites incompatibles, dependencias de `pending_verification` y triggers no documentados; email/password y OAuth existentes se reportan como informativos.
- Verificación: fixtures Google, proveedores rechazados, finalización autenticada, límites, duplicados, estados, roles y regresiones; termina con `ROLLBACK`.
- Rollback manual: `supabase/reconciliation/0004_identity_registration_rollback.sql`, exige revisión explícita.
- Plan: `docs/TEST_PLAN_0004.md`.
- Aplicación coordinada: aprobar preflight, aplicar 0004, desplegar inmediatamente la aplicación compatible, verificar y regenerar snapshot.
- Estado: aplicada. La prueba OAuth posterior reveló el contrato prematuro de `email_confirmed_at`, corregido por la 0005 pendiente.

## 0005_fix_google_oauth_user_creation.sql — creada, no aplicada

- Fecha de creación: 2026-07-17.
- Estado previo: 0004 ya aplicada; Google Cloud y Supabase configurados.
- Evidencia: Supabase registró SQLSTATE `23514`, `sitaa_google_email_not_verified`, durante el `INSERT` real de `auth.users`. El `25P02` posterior fue consecuencia. La reversión no dejó Auth users, identities, profiles ni enlaces que limpiar.
- Corrección: el trigger Google admite `email_confirmed_at=null` durante el alta temprana y crea sólo el perfil pendiente, inactivo e incompleto.
- Frontera final: `complete_own_google_registration` exige identidad Google enlazada, correo coincidente y verificación final antes de activar.
- Aplicación: las rutas y el server action de registro rechazan cuentas ya autenticadas; el callback incorpora diagnósticos sanitizados por etapa.
- Artefactos: preflight read-only, verificador transaccional, rollback manual y `docs/TEST_PLAN_0005.md`.
