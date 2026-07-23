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

El snapshot vigente posterior a 0009 fue generado en `2026-07-22T23:32:46Z`. La reconciliación confirmó 18 tablas, 165 columnas, 80 constraints, 43 índices, 11 triggers públicos, 54 firmas de función, 25 políticas, 18 tablas con RLS y 51 filas de semillas. Los privilegios suman 137 grants de rutina, 267 de tabla publicados por `information_schema`, 6 de secuencia y 445 entradas ACL expandidas. `live_acl.sql` incluye `MAINTAIN`, privilegio que `information_schema.table_privileges` no publica; esta diferencia de representación permanece documentada y no constituye deriva. No se encontraron inconsistencias entre el esquema principal y los snapshots especializados. Los índices de PK y UNIQUE se consideran representados por sus constraints aunque no aparezcan como sentencias `CREATE INDEX` independientes en el dump.

La comparación contra `0001`–`0009` no encontró deriva inexplicada. Los informes `0008_post_apply_reconciliation.md` y `0009_post_apply_reconciliation.md` registran las comparaciones estructurales, funcionales, RLS, privilegios, catálogos y diferencias controladas. `live_triggers.sql` cubre tablas de `public`; los triggers de `auth.users` se verifican mediante los preflight, guardas y verificadores transaccionales aprobados. Las ACL por columna no forman parte de estos artefactos; los verificadores 0006, 0008 y 0009 comprobaron el `UPDATE` acotado de nombres y la ausencia de ampliaciones de privilegio.

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

La cadena reconciliada actual es `0001`–`0009`. 0007 cerró Fase B.1, 0008 cerró Fase B.2a y 0009 cerró Fase B.2b dentro de sus alcances aprobados. Los artefactos de `live/` son la evidencia autoritativa post-0009 y no se editan manualmente.

0008 fue aplicada para B.2a después de aprobar su preflight y publicar la aplicación compatible; la migración es inmutable. Sus artefactos son `0008_operational_account_barrier_identity_correction_{preflight,verify,rollback}.sql` y `docs/TEST_PLAN_0008.md`. El preflight distingue dependencias abiertas de historia terminada. Para `activity_participants`, separa el ACL de tabla, el ACL explícito de columna en `pg_attribute.attacl`, la proyección table-derived de `information_schema.column_privileges` y el acceso efectivo de `has_column_privilege`; las filas legítimas derivadas de tabla no se tratan como grants explícitos. El verificador final conserva `ROLLBACK` y el rollback preserva toda corrección/auditoría confirmada. Los cuatro cuerpos nuevos tienen hashes exactos en migración, verificador y guard predestructivo. Las pruebas manuales de concurrencia que pueden confirmar historia requieren un entorno desechable completo, no limpieza de auditoría append-only.

La primera ejecución remota del preflight 0008 terminó con un falso positivo por nombres; la segunda abortó antes de las categorías porque `pg_get_expr` no decompila el `WHEN` con `OLD` y `NEW`; la tercera aisló el cast `::text` emitido por `pg_get_triggerdef`. La cuarta ejecución corregida aprobó las 35 categorías bloqueantes y terminó con `ROLLBACK`. La migración no contiene DDL sobre esos triggers.

La primera ejecución del verificador post-aplicación abortó porque el arnés llamó directamente bajo `authenticated` a `is_b1_account_admin()`, helper privado owner-only; la denegación `42501` fue correcta. La segunda aprobó esa corrección, los contratos previos, fixtures, rechazos y siete mutaciones RPC, pero abortó porque las postcondiciones crudas de perfiles, auditoría e historia continuaban dentro del intervalo `authenticated`. Ambas transacciones se descartaron sin persistencia. La versión final conserva las pruebas públicas/DML en rol cliente, valida allí la historia B.1 sanitizada y restablece owner para estado y auditoría crudos; aprobó con `ROLLBACK`. Los smoke tests finales y la reconciliación post-0008 aprobaron.

El inventario vivo post-0009 es 18/165/80/43/11/54/25/18/51 para tablas/columnas/restricciones/índices/triggers/funciones/políticas/tablas con RLS/semillas. Los privilegios observados son 137 grants de rutina, 267 de tabla, 6 de secuencia y 445 ACL expandidas. El delta frente a post-0008 coincide exactamente con 0009: +3 firmas, +5 grants de rutina y +5 ACL, sin cambio físico, de políticas, RLS, grants de tabla/secuencia o semillas. `0010` es el siguiente número disponible.

Los artefactos `0009_admin_account_lifecycle_transitions_{preflight,verify,rollback}.sql` cerraron B.2b. El preflight devuelve categorías/conteos y terminó en `ROLLBACK`; el verificador usó fixtures sintéticas y terminó en `ROLLBACK` sin persistencia; el rollback no fue ejecutado y permanece como contrato protegido que sólo elimina las tres funciones 0009, sin revertir transiciones o auditoría ya confirmadas.

El primer preflight remoto 0009 devolvió 26 filas, terminó con `ROLLBACK` y no fue aprobado por cuatro falsos positivos. Un diagnóstico separado de sólo lectura confirmó los contratos post-0008. Tras alinear las comparaciones canónicas, el preflight corregido devolvió nuevamente 26 filas, dejó sus 19 bloqueos en cero y terminó con `ROLLBACK`; quedó aprobado. La aplicación compatible se desplegó antes de intentar la migración.

Los intentos 1 y 2 fallaron antes del DDL: primero por el `EXISTS` exterior sin cerrar y después por concatenar `pg_default_acl.defaclobjtype` (`pg_catalog."char"`) sin `::text`. Ambas transacciones se descartaron sin persistencia. El intento 3 aprobó preflight, DDL, ACL, guarda post-DDL y `COMMIT`; el verificador final aprobó con `ROLLBACK`, los smoke tests aprobaron y el informe `0009_post_apply_reconciliation.md` confirmó el snapshot `2026-07-22T23:32:46Z` sin deriva inexplicada. 0009 es inmutable, B.2b está cerrada, 0010 es el siguiente número y B.3/Fase C permanecen pendientes.

## Aplicación 0010 y verificador aprobado

`0010_coordinated_auth_session_suspension_{preflight,verify,rollback}.sql` acompaña la migración B.3a aplicada. El preflight es de sólo lectura y compara el contrato post‑0009; el verificador usa fixtures sintéticas y simula resultados Auth sin invocar Auth Admin; el rollback sólo es elegible mientras no exista ninguna operación ni evento B.3a real.

El primer preflight remoto 0010 devolvió 34 filas, terminó con `ROLLBACK` y código de salida 0 y no cambió objetos o datos. No fue aprobado: 29 de 30 categorías bloqueantes fueron cero, mientras `dangerous_default_acl` devolvió 50. Un diagnóstico adicional de sólo lectura, también con `ROLLBACK` y código 0, confirmó `postgres` como `current_user` y `session_user` y cinco grupos estándar de diez filas: `postgres/public`, `postgres/storage`, `supabase_admin/graphql`, `supabase_admin/graphql_public` y `supabase_admin/public`.

El predicado anterior era demasiado amplio. La corrección sólo inspecciona defaults creados por `postgres`, globales o de `public`, para tablas y funciones, y bloquea grantees que no formen parte de la allowlist normalizada por 0010. Las secuencias y los defaults de otros propietarios o esquemas no se consumen. No se alteró ningún privilegio predeterminado: 0010 conserva la revocación explícita y dinámica del ledger, las ACL exactas de funciones y la captura/comparación del hash completo de `pg_default_acl`.

La reejecución corregida quedó aprobada: devolvió exactamente 34 filas, dejó sus 30 categorías bloqueantes en cero y produjo `dangerous_default_acl = 0`. Sus cuatro conteos informativos fueron `active_exact_b1_administrators = 1`, `existing_b2b_lifecycle_events = 4`, `inactive_accounts = 0` e `inactive_accounts_with_active_or_future_assignments = 0`. Terminó con `ROLLBACK`, código 0 y sin `ERROR`; no expuso UUID, filas operativas, PII, credenciales, tokens o secretos y no cambió objetos, filas o privilegios.

La aplicación compatible fue desplegada correctamente, la Edge Function está `ACTIVE` y 0010 fue aplicada; el registro local termina en `COMMIT`. La Edge no se invocó, no hubo Auth Admin ni una operación real B.3a. El primer verificador hospedado terminó con código 3 en `restore_failure_finalize`: la función emitió el contrato correcto `42501/sitaa_account_lifecycle_auth_unconfirmed`, mientras el arnés esperaba `P0001`. No alcanzó el `ROLLBACK` final y la desconexión de `psql` descartó la transacción abierta. Un diagnóstico de sólo lectura confirmó ledger existente, seis funciones B.3a, cero filas de operación y cero eventos Auth B.3a; terminó con `ROLLBACK` y código 0.

El handler corregido usa `insufficient_privilege` y exige el SQLSTATE y mensaje exactos. La reejecución completó todos los escenarios, imprimió exactamente un `ROLLBACK` final, terminó con código 0, no produjo `ERROR` y no persistió fixtures, privilegios temporales, operaciones o auditoría. El verificador PostgreSQL quedó aprobado.

El snapshot autoritativo continúa siendo post‑0009 y no debe incorporar 0010 hasta completar la prueba Auth desechable, los smoke tests y una nueva reconciliación. Las semánticas hospedadas de `ban_duration`, JWT, refresh tokens y restauración con `ban_duration = 'none'` siguen sin verificar; B.3a continúa abierta y no se debe crear 0011. El rollback no se ejecutó y sólo conserva elegibilidad mientras no exista la primera operación o evento Auth B.3a real.
