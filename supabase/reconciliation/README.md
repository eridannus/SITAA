# Reconciliación de Supabase

Este directorio contiene snapshots de sólo lectura usados para comparar la base de datos viva con las migraciones versionadas. Los snapshots son insumos de reconciliación y no deben ejecutarse directamente.

## Artefactos del snapshot vivo

El flujo genera el siguiente conjunto. Todos los artefactos, incluidas las cuatro capturas de privilegios, son obligatorios para considerar completo un snapshot.

- `live_schema.sql`: esquema `public` obtenido con `pg_dump --schema-only --no-owner --no-privileges`.
- `live_tables.sql`: tablas, tipo de relación y estado RLS.
- `live_columns.sql`: tipos, UDT, nulabilidad, defaults y metadatos de longitud o precisión.
- `live_constraints.sql`: PK, FK, UNIQUE y CHECK con definición completa.
- `live_indexes.sql`: definiciones de `pg_indexes`, incluidos índices implícitos de constraints.
- `live_triggers.sql`: definiciones completas de triggers no internos.
- `live_functions.sql`: firmas, argumentos y definiciones completas.
- `live_policies.sql`: políticas RLS con modo, roles, comando, `USING` y `WITH CHECK`.
- `live_routine_privileges.sql`: privilegios efectivos publicados por `information_schema.routine_privileges` para rutinas de `public`.
- `live_table_privileges.sql`: privilegios de tablas y vistas de `public`, con concedente, receptor y capacidad de delegación.
- `live_sequence_privileges.sql`: ACL expandida de secuencias de `public`, incluidos privilegios predeterminados del propietario.
- `live_acl.sql`: inventario expandido de `pg_proc.proacl` y `pg_class.relacl` para funciones, procedimientos, tablas, vistas, vistas materializadas y secuencias.
- `live_seed_catalogs.sql`: filas JSON de catálogos controlados.
- `live_snapshot_metadata.txt`: fecha UTC, versiones y estado de generación.

El snapshot vigente posterior a 0007 fue generado en `2026-07-21T00:16:03Z`. La reconciliación confirmó 18 tablas, 165 columnas, 80 constraints, 43 índices, 10 triggers públicos, 47 firmas de función, 23 políticas y 51 filas de semillas. Los privilegios suman 125 grants de rutina, 270 de tabla publicados por `information_schema`, 6 de secuencia y 436 entradas ACL expandidas. `live_acl.sql` incluye además `MAINTAIN` del propietario de la nueva tabla, privilegio que `information_schema.table_privileges` no publica; esta diferencia explica el delta de tabla +9 frente a diez entradas ACL nuevas. No se encontraron inconsistencias entre el esquema principal y los snapshots especializados. Los índices de PK y UNIQUE se consideran representados por sus constraints aunque no aparezcan como sentencias `CREATE INDEX` independientes en el dump.

La comparación contra `0001`–`0007` no encontró deriva inexplicada. El informe `0007_post_apply_reconciliation.md` registra la comparación estructural, funcional, RLS, privilegios, catálogos y diferencias controladas. `live_triggers.sql` cubre tablas de `public`; los triggers de `auth.users` se verifican mediante los preflight y verificadores transaccionales aprobados. Las ACL por columna no forman parte de estos artefactos; el verificador 0006 comprobó el `UPDATE` acotado de nombres bajo el rol `authenticated` y el verificador 0007 comprobó los grants directos de su tabla y funciones.

Los antiguos snapshots JSON de columnas, funciones y políticas quedan conservados como antecedente, pero fueron sustituidos como fuente autoritativa por este conjunto completo bajo `supabase/reconciliation/live/`.

## Flujo recomendado en Windows

Configura `SUPABASE_DB_URL` como secreto de la sesión y ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pull-supabase-snapshot.ps1
```

La resolución de herramientas sigue este orden:

1. `pg_dump` y `psql` nativos desde `PATH`.
2. `C:\Program Files\PostgreSQL\18\bin`.
3. Supabase CLI sólo como respaldo final cuando falta `pg_dump`; `psql` sigue siendo obligatorio para el conjunto completo.

Con las herramientas nativas disponibles no se evalúa ni invoca Supabase CLI. El script se guarda como UTF-8 con BOM para que Windows PowerShell 5.1 interprete correctamente los mensajes en español; los archivos SQL se generan directamente en UTF-8 sin transformaciones manuales.

Las cuatro capturas de privilegios son obligatorias. Cada una se genera con `psql` dentro de una transacción `read only`: dos consultan `information_schema`, una expande ACL de secuencias y la última reconcilia ACL de `pg_proc` y `pg_class`. Los artefactos registran identidades de objetos, concedentes, receptores y privilegios; nunca incluyen la URI de conexión.

## Semillas permitidas

`live_seed_catalogs.sql` se limita a:

- `roles`
- `divisions`
- `academic_programs`
- `academic_periods`
- `activity_types`
- `service_types`
- `attention_categories`
- `activity_modalities`
- `activity_statuses`
- `location_types`
- `participant_roles`

No se exportan usuarios, perfiles, asignaciones de rol, actividades, participantes, asistencia, tokens ni otros datos operativos o de prueba.

## Seguridad y manejo de fallos

- La URI sólo existe como secreto de entorno; no se imprime ni persiste.
- `psql` usa transacciones `read only` y el proceso establece PostgreSQL en modo de sólo lectura.
- Todos los archivos se generan primero en un directorio temporal.
- Si un comando falla, incluido cualquiera de los cuatro snapshots de privilegios, el temporal se elimina, el metadata registra `FAILURE` y no se publican archivos parciales.
- El flujo no aplica migraciones, no modifica la base viva y no repara historial remoto.

Después de generar un snapshot, se valida su integridad y se compara con `0001` y todas las migraciones posteriores. Los archivos de privilegios son evidencia para definir o verificar grants mínimos; no contienen ni ejecutan sentencias `GRANT` o `REVOKE`. Aplicar SQL a Supabase permanece como un paso separado y manual.

La cadena reconciliada actual es `0001`–`0007`. 0007 está aplicada, verificada, probada en producción y reconciliada; Fase B.1 está operativa dentro de su alcance de sólo lectura. Los artefactos de `live/` son la evidencia autoritativa post-0007 y no se editan manualmente.

0008 está preparada localmente para B.2a y permanece pendiente: no aplicada, no verificada en PostgreSQL, sin smoke tests y no reconciliada. Sus artefactos son `0008_operational_account_barrier_identity_correction_{preflight,verify,rollback}.sql` y `docs/TEST_PLAN_0008.md`. El preflight es de sólo lectura y distingue dependencias abiertas de historia terminada mediante el cálculo temporal post-0007. Para `activity_participants`, separa el ACL de tabla, el ACL explícito de columna en `pg_attribute.attacl`, la proyección table-derived de `information_schema.column_privileges` y el acceso efectivo de `has_column_privilege`; las filas legítimas derivadas de tabla no se tratan como grants explícitos. El verificador termina con `ROLLBACK` y el rollback preserva toda corrección/auditoría ya confirmada. Los cuatro cuerpos nuevos tienen hashes exactos en migración, verificador y guard predestructivo. Las pruebas manuales de concurrencia que pueden confirmar historia requieren un entorno desechable completo, no limpieza de auditoría append-only. Ninguno de estos archivos es un snapshot vivo ni debe presentarse como evidencia de aplicación.

La primera ejecución remota del preflight 0008 terminó con `ROLLBACK` y mostró un único bloqueo `registration_trigger_drift = 1`; fue un falso positivo porque el artefacto local buscaba nombres no canónicos. El segundo intento de sólo lectura abortó antes de devolver categorías con `expression contains variables of more than one relation`: el arnés usó indebidamente `pg_get_expr` sobre el `WHEN` con `OLD` y `NEW`. La revisión local valida ahora `on_sitaa_auth_user_created` y `on_sitaa_auth_user_email_changed` mediante catálogos y reconstruye ese único `WHEN` con `pg_get_triggerdef(oid, false)`. La migración sólo preserva y verifica los triggers; no contiene DDL sobre ellos. Los resultados temporales no forman parte de la reconciliación y una nueva reejecución corregida está pendiente.

El inventario hipotético post-0008 es 18/165/80/43/11/51/25/51 para tablas/columnas/restricciones/índices/triggers/funciones/políticas/semillas. A partir de la representación post-0007, los privilegios esperados son 132 grants de rutina, 267 de tabla, 6 de secuencia y 440 ACL expandidas; estos totales sólo podrán confirmarse con un nuevo snapshot tras la aplicación coordinada.
