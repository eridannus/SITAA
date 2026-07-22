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

El snapshot vigente posterior a 0008 fue generado en `2026-07-22T01:46:13Z`. La reconciliación confirmó 18 tablas, 165 columnas, 80 constraints, 43 índices, 11 triggers públicos, 51 firmas de función, 25 políticas y 51 filas de semillas. Los privilegios suman 132 grants de rutina, 267 de tabla publicados por `information_schema`, 6 de secuencia y 440 entradas ACL expandidas. `live_acl.sql` incluye `MAINTAIN`, privilegio que `information_schema.table_privileges` no publica; esta diferencia de representación permanece documentada y no constituye deriva. No se encontraron inconsistencias entre el esquema principal y los snapshots especializados. Los índices de PK y UNIQUE se consideran representados por sus constraints aunque no aparezcan como sentencias `CREATE INDEX` independientes en el dump.

La comparación contra `0001`–`0008` no encontró deriva inexplicada. El informe `0008_post_apply_reconciliation.md` registra la comparación estructural, funcional, RLS, privilegios, catálogos y diferencias controladas. `live_triggers.sql` cubre tablas de `public`; los triggers de `auth.users` se verifican mediante los preflight y verificadores transaccionales aprobados. Las ACL por columna no forman parte de estos artefactos; los verificadores 0006 y 0008 comprobaron respectivamente el `UPDATE` acotado de nombres y la ausencia de grants explícitos de columna que amplíen `activity_participants`.

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

La cadena reconciliada actual es `0001`–`0008`. 0007 cerró Fase B.1 y 0008 cerró Fase B.2a dentro de sus alcances aprobados. Los artefactos de `live/` son la evidencia autoritativa post-0008 y no se editan manualmente.

0008 fue aplicada para B.2a después de aprobar su preflight y publicar la aplicación compatible; la migración es inmutable. Sus artefactos son `0008_operational_account_barrier_identity_correction_{preflight,verify,rollback}.sql` y `docs/TEST_PLAN_0008.md`. El preflight distingue dependencias abiertas de historia terminada. Para `activity_participants`, separa el ACL de tabla, el ACL explícito de columna en `pg_attribute.attacl`, la proyección table-derived de `information_schema.column_privileges` y el acceso efectivo de `has_column_privilege`; las filas legítimas derivadas de tabla no se tratan como grants explícitos. El verificador final conserva `ROLLBACK` y el rollback preserva toda corrección/auditoría confirmada. Los cuatro cuerpos nuevos tienen hashes exactos en migración, verificador y guard predestructivo. Las pruebas manuales de concurrencia que pueden confirmar historia requieren un entorno desechable completo, no limpieza de auditoría append-only.

La primera ejecución remota del preflight 0008 terminó con un falso positivo por nombres; la segunda abortó antes de las categorías porque `pg_get_expr` no decompila el `WHEN` con `OLD` y `NEW`; la tercera aisló el cast `::text` emitido por `pg_get_triggerdef`. La cuarta ejecución corregida aprobó las 35 categorías bloqueantes y terminó con `ROLLBACK`. La migración no contiene DDL sobre esos triggers.

La primera ejecución del verificador post-aplicación abortó porque el arnés llamó directamente bajo `authenticated` a `is_b1_account_admin()`, helper privado owner-only; la denegación `42501` fue correcta. La segunda aprobó esa corrección, los contratos previos, fixtures, rechazos y siete mutaciones RPC, pero abortó porque las postcondiciones crudas de perfiles, auditoría e historia continuaban dentro del intervalo `authenticated`. Ambas transacciones se descartaron sin persistencia. La versión final conserva las pruebas públicas/DML en rol cliente, valida allí la historia B.1 sanitizada y restablece owner para estado y auditoría crudos; aprobó con `ROLLBACK`. Los smoke tests finales y la reconciliación post-0008 aprobaron.

El inventario vivo post-0008 es 18/165/80/43/11/51/25/51 para tablas/columnas/restricciones/índices/triggers/funciones/políticas/semillas. Los privilegios observados son 132 grants de rutina, 267 de tabla, 6 de secuencia y 440 ACL expandidas. El delta frente a post-0007 coincide exactamente con 0008: +1 trigger, +4 firmas, +2 políticas, +7 rutina, −3 tabla y +4 ACL netas, sin cambio físico ni semillas. `0009` es el siguiente número disponible.

Los artefactos `0009_admin_account_lifecycle_transitions_{preflight,verify,rollback}.sql` están preparados para B.2b. El preflight sólo devuelve categorías/conteos y termina en `ROLLBACK`; el verificador usa fixtures sintéticas dentro de una transacción y termina en `ROLLBACK`; el rollback elimina únicamente las tres funciones 0009 y no revierte transiciones ni auditoría ya confirmadas. Nada de lo anterior se ha ejecutado contra Supabase.
