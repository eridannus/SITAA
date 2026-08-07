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

El snapshot vivo canónico fue generado en `2026-08-06T23:33:15Z` después de aplicar 0010. La reconciliación confirmó 19 tablas, 183 columnas, 96 constraints, 48 índices, 13 triggers públicos, 60 firmas de función, 25 políticas, 19 tablas con RLS y 51 filas de semillas. Los privilegios suman 147 grants de rutina, 274 de tabla publicados por `information_schema`, 6 de secuencia y 463 entradas ACL expandidas. `live_acl.sql` incluye `MAINTAIN`, privilegio que `information_schema.table_privileges` no publica; esta diferencia de representación permanece documentada y no constituye deriva. No se encontraron inconsistencias entre el esquema principal y los snapshots especializados. Los índices de PK y UNIQUE se consideran representados por sus constraints aunque no aparezcan como sentencias `CREATE INDEX` independientes en el dump.

La comparación contra `0001`–`0010` no encontró deriva inexplicada. Los informes `0008_post_apply_reconciliation.md`, `0009_post_apply_reconciliation.md` y `0010_post_apply_reconciliation.md` registran las comparaciones estructurales, funcionales, RLS, privilegios, catálogos y diferencias controladas. `live_triggers.sql` cubre tablas de `public`; los triggers de `auth.users` se verifican mediante los preflight, guardas y verificadores transaccionales aprobados. Las ACL por columna no forman parte de estos artefactos; los verificadores 0006, 0008, 0009 y 0010 comprobaron el `UPDATE` acotado de nombres y la ausencia de ampliaciones de privilegio.

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

Con las herramientas nativas disponibles no se evalúa ni invoca Supabase CLI. El script se guarda como UTF-8 con BOM para que Windows PowerShell 5.1 interprete correctamente los mensajes en español; los archivos SQL se generan directamente en UTF-8 sin transformaciones manuales. `live_columns.sql` y `live_functions.sql` preservan el whitespace canónico crudo emitido por PostgreSQL: no deben recortarse, normalizarse ni reformatearse manualmente. Los controles de UTF-8 estricto, contenido no vacío, sanitización, rutas autorizadas y hashes continúan aplicándose a los catorce artefactos.

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

La cadena reconciliada actual es `0001`–`0010`. 0007 cerró Fase B.1, 0008 cerró Fase B.2a, 0009 cerró Fase B.2b y 0010 cerró Fase B.3a dentro de sus alcances aprobados. Los artefactos de `live/` son la evidencia autoritativa post‑0010 y no se editan manualmente. B.3b y Fase C permanecen pendientes; `0011` es el siguiente número disponible, pero no se ha creado.

0008 fue aplicada para B.2a después de aprobar su preflight y publicar la aplicación compatible; la migración es inmutable. Sus artefactos son `0008_operational_account_barrier_identity_correction_{preflight,verify,rollback}.sql` y `docs/TEST_PLAN_0008.md`. El preflight distingue dependencias abiertas de historia terminada. Para `activity_participants`, separa el ACL de tabla, el ACL explícito de columna en `pg_attribute.attacl`, la proyección table-derived de `information_schema.column_privileges` y el acceso efectivo de `has_column_privilege`; las filas legítimas derivadas de tabla no se tratan como grants explícitos. El verificador final conserva `ROLLBACK` y el rollback preserva toda corrección/auditoría confirmada. Los cuatro cuerpos nuevos tienen hashes exactos en migración, verificador y guard predestructivo. Las pruebas manuales de concurrencia que pueden confirmar historia requieren un entorno desechable completo, no limpieza de auditoría append-only.

La primera ejecución remota del preflight 0008 terminó con un falso positivo por nombres; la segunda abortó antes de las categorías porque `pg_get_expr` no decompila el `WHEN` con `OLD` y `NEW`; la tercera aisló el cast `::text` emitido por `pg_get_triggerdef`. La cuarta ejecución corregida aprobó las 35 categorías bloqueantes y terminó con `ROLLBACK`. La migración no contiene DDL sobre esos triggers.

La primera ejecución del verificador post-aplicación abortó porque el arnés llamó directamente bajo `authenticated` a `is_b1_account_admin()`, helper privado owner-only; la denegación `42501` fue correcta. La segunda aprobó esa corrección, los contratos previos, fixtures, rechazos y siete mutaciones RPC, pero abortó porque las postcondiciones crudas de perfiles, auditoría e historia continuaban dentro del intervalo `authenticated`. Ambas transacciones se descartaron sin persistencia. La versión final conserva las pruebas públicas/DML en rol cliente, valida allí la historia B.1 sanitizada y restablece owner para estado y auditoría crudos; aprobó con `ROLLBACK`. Los smoke tests finales y la reconciliación post-0008 aprobaron.

El inventario vivo post-0009 es 18/165/80/43/11/54/25/18/51 para tablas/columnas/restricciones/índices/triggers/funciones/políticas/tablas con RLS/semillas. Los privilegios observados son 137 grants de rutina, 267 de tabla, 6 de secuencia y 445 ACL expandidas. El delta frente a post-0008 coincide exactamente con 0009: +3 firmas, +5 grants de rutina y +5 ACL, sin cambio físico, de políticas, RLS, grants de tabla/secuencia o semillas. En el cierre post-0009, `0010` era el siguiente número disponible.

Los artefactos `0009_admin_account_lifecycle_transitions_{preflight,verify,rollback}.sql` cerraron B.2b. El preflight devuelve categorías/conteos y terminó en `ROLLBACK`; el verificador usó fixtures sintéticas y terminó en `ROLLBACK` sin persistencia; el rollback no fue ejecutado y permanece como contrato protegido que sólo elimina las tres funciones 0009, sin revertir transiciones o auditoría ya confirmadas.

El primer preflight remoto 0009 devolvió 26 filas, terminó con `ROLLBACK` y no fue aprobado por cuatro falsos positivos. Un diagnóstico separado de sólo lectura confirmó los contratos post-0008. Tras alinear las comparaciones canónicas, el preflight corregido devolvió nuevamente 26 filas, dejó sus 19 bloqueos en cero y terminó con `ROLLBACK`; quedó aprobado. La aplicación compatible se desplegó antes de intentar la migración.

Los intentos 1 y 2 fallaron antes del DDL: primero por el `EXISTS` exterior sin cerrar y después por concatenar `pg_default_acl.defaclobjtype` (`pg_catalog."char"`) sin `::text`. Ambas transacciones se descartaron sin persistencia. El intento 3 aprobó preflight, DDL, ACL, guarda post-DDL y `COMMIT`; el verificador final aprobó con `ROLLBACK`, los smoke tests aprobaron y el informe `0009_post_apply_reconciliation.md` confirmó el snapshot `2026-07-22T23:32:46Z` sin deriva inexplicada. En ese cierre post-0009, 0009 era inmutable, B.2b estaba cerrada, `0010` era el siguiente número y B.3/Fase C permanecían pendientes.

## Aplicación 0010 y verificador aprobado

`0010_coordinated_auth_session_suspension_{preflight,verify,rollback}.sql` acompaña la migración B.3a aplicada. El preflight es de sólo lectura y compara el contrato post‑0009; el verificador usa fixtures sintéticas y simula resultados Auth sin invocar Auth Admin; el rollback sólo es elegible mientras no exista ninguna operación ni evento B.3a real.

El primer preflight remoto 0010 devolvió 34 filas, terminó con `ROLLBACK` y código de salida 0 y no cambió objetos o datos. No fue aprobado: 29 de 30 categorías bloqueantes fueron cero, mientras `dangerous_default_acl` devolvió 50. Un diagnóstico adicional de sólo lectura, también con `ROLLBACK` y código 0, confirmó `postgres` como `current_user` y `session_user` y cinco grupos estándar de diez filas: `postgres/public`, `postgres/storage`, `supabase_admin/graphql`, `supabase_admin/graphql_public` y `supabase_admin/public`.

El predicado anterior era demasiado amplio. La corrección sólo inspecciona defaults creados por `postgres`, globales o de `public`, para tablas y funciones, y bloquea grantees que no formen parte de la allowlist normalizada por 0010. Las secuencias y los defaults de otros propietarios o esquemas no se consumen. No se alteró ningún privilegio predeterminado: 0010 conserva la revocación explícita y dinámica del ledger, las ACL exactas de funciones y la captura/comparación del hash completo de `pg_default_acl`.

La reejecución corregida quedó aprobada: devolvió exactamente 34 filas, dejó sus 30 categorías bloqueantes en cero y produjo `dangerous_default_acl = 0`. Sus cuatro conteos informativos fueron `active_exact_b1_administrators = 1`, `existing_b2b_lifecycle_events = 4`, `inactive_accounts = 0` e `inactive_accounts_with_active_or_future_assignments = 0`. Terminó con `ROLLBACK`, código 0 y sin `ERROR`; no expuso UUID, filas operativas, PII, credenciales, tokens o secretos y no cambió objetos, filas o privilegios.

La aplicación compatible fue desplegada correctamente, la Edge Function quedó `ACTIVE` y 0010 fue aplicada; el registro local termina en `COMMIT`. Antes de la matriz central, el primer verificador hospedado terminó con código 3 en `restore_failure_finalize`: la función emitió el contrato correcto `42501/sitaa_account_lifecycle_auth_unconfirmed`, mientras el arnés esperaba `P0001`. No alcanzó el `ROLLBACK` final y la desconexión de `psql` descartó la transacción abierta. Un diagnóstico de sólo lectura confirmó entonces ledger existente, seis funciones B.3a, cero filas de operación y cero eventos Auth B.3a; terminó con `ROLLBACK` y código 0.

El handler corregido usa `insufficient_privilege` y exige el SQLSTATE y mensaje exactos. La reejecución completó todos los escenarios, imprimió exactamente un `ROLLBACK` final, terminó con código 0, no produjo `ERROR` y no persistió fixtures, privilegios temporales, operaciones o auditoría. El verificador PostgreSQL quedó aprobado.

## Checkpoint Hosted Auth central 0010

`0010_hosted_auth_core_evidence.md` conserva el resumen sanitizado de la matriz central ejecutada el 3 de agosto de 2026 en un proyecto desechable. Los archivos `b3a_matrix_hosted_auth_core.local.txt` y `b3a_matrix_hosted_auth_core_postcheck.local.txt` son evidencia local no versionada e ignorada por Git; el resumen conserva sus tamaños y SHA-256 sin copiar datos identificables ni secretos.

La matriz aprobó la suspensión/restauración central y produjo las primeras operaciones y eventos B.3a reales, por lo que el rollback 0010 quedó definitivamente revocado. Sus resultados sobre `user_banned`, refresh tokens y login posterior son evidencia empírica de esa ejecución, no una garantía universal del proveedor. En ese checkpoint los casos de fallos todavía estaban pendientes; el checkpoint failure/recovery posterior se documenta por separado. B.3a sigue abierta.

El snapshot vivo canónico bajo `live/` continúa siendo post‑0009. El snapshot post‑0010 no debe inferirse a partir del checkpoint ni editarse manualmente: debe generarse mediante el flujo canónico de snapshot y reconciliarse antes de actualizar el inventario. No se debe crear 0011 mientras permanezcan abiertos esos gates.

## Checkpoint Hosted Auth failure/recovery 0010

`0010_hosted_auth_failure_recovery_evidence.md` conserva el resumen sanitizado de la ejecución failure/recovery v11 que aprobó los casos 13–15 en un proyecto desechable. Los archivos `b3a_matrix_hosted_auth_failure_recovery.local.txt` y `b3a_matrix_hosted_auth_failure_recovery_postcheck.local.txt` son fuentes locales no versionadas e ignoradas por Git; el checkpoint conserva sus tamaños, SHA-256, versiones, timestamps y resultados agregados sin copiar datos crudos.

La matriz comprobó un fallo Auth controlado y su reintento idempotente, un fallo de finalización posterior a `auth_synchronized` sin repetir Auth y la recuperación por una segunda autoridad B.1 exacta. Solicitante y finalizador permanecieron diferenciados. Sus códigos estables y el comportamiento observado describen sólo esa ejecución; no son una garantía universal de Supabase.

Los dos `*.local.txt` no deben añadirse a Git. El markdown es un resumen documental, no sustituye las fuentes locales ni el snapshot vivo. Los casos 17–18 y la concurrencia se aprobaron después mediante el checkpoint separado de límites y concurrencia v8. En el cierre de failure/recovery, la reconciliación post‑0010, el cierre de 19–20 y los smoke tests seguían pendientes. `live/` continúa siendo el snapshot canónico post‑0009; B.3a permanece abierta y no debe crearse 0011.

## Checkpoint Hosted Auth de concurrencia y límites 0010

`0010_hosted_auth_concurrency_boundaries_evidence.md` conserva el resumen sanitizado de la ejecución v8 que aprobó los casos 17–18 y la matriz multisesión de concurrencia, advisory locks, leases, pérdida de autoridad y recuperación sincronizada en un proyecto desechable. La ejecución observó serialización real, idempotencia del mismo `request_id`, rechazo de payload conflictivo, espera por lock, cercado de intentos y recuperación por otra autoridad B.1 exacta sin repetir Auth.

La fuente v7 `b3a_matrix_hosted_auth_concurrency_boundaries.local.txt` permanece como evidencia predecesora rechazada y preservada. La pareja final aprobada corresponde a `b3a_matrix_hosted_auth_concurrency_boundaries_v8.local.txt` y `b3a_matrix_hosted_auth_concurrency_boundaries_v8_postcheck.local.txt`; el artefacto v8 de fallo está ausente. Todas esas fuentes locales siguen ignoradas por Git y no deben versionarse. El markdown nuevo es el único resumen versionado y sanitizado.

La normalización de cuatro campos de texto administrados por el proveedor se limitó a una Authority D sintética y desechable; no fue migración, cambio de esquema, reparación de producción ni recomendación general sobre `auth.users`. El probe Auth Admin posterior fue de sólo lectura y aprobó el inventario fixture requerido.

Estos archivos locales no son un snapshot ni permiten inferir el estado vivo post‑0010. `live/` conserva el snapshot canónico post‑0009 hasta ejecutar el flujo normal de captura y reconciliación. El caso 19 fue aprobado posteriormente mediante la auditoría productiva de ausencia de secretos y el caso 20 mediante el smoke test productivo. La reconciliación post‑0010 sigue pendiente; B.3a permanece abierta y no debe crearse 0011.

## Auditoría productiva de ausencia de secretos 0010

`0010_production_secret_audit_evidence.md` conserva el resumen versionado y sanitizado de la auditoría que aprobó el caso 19 sobre el commit `5df156ec0616da8823f6f13be41c2df11ea85537`. Integra la observación por el operador de nombres y alcances de variables Vercel, agregados de logs Production y la auditoría automatizada de artefactos locales y recursos productivos servidos anónimamente.

Las capturas de pantalla, los valores de variables, los recursos descargados y las salidas temporales de auditoría no se versionan. El checkpoint sólo conserva nombres públicos, alcances, conteos y resultados sanitizados; no contiene credenciales, datos personales ni extractos de bundles o source maps.

Este resumen no reemplaza el snapshot vivo canónico ni permite inferir el inventario post‑0010. Al cerrar la auditoría del caso 19, el caso 20, los smoke tests de la interfaz desplegada y la captura/reconciliación post‑0010 continuaban pendientes. El checkpoint productivo posterior actualiza ese estado sin reescribir la evidencia histórica.

## Smoke test productivo de coordinación Auth 0010

`0010_production_smoke_test_evidence.md` conserva el resumen versionado y sanitizado del recorrido productivo controlado que aprobó el caso 20 sobre el commit desplegado `18e40db3254d6c3b73b24dcd4d29ee229498b0e5`. Una autoridad B.1 exacta desactivó y reactivó una cuenta institucional estudiantil ficticia; el checkpoint documenta únicamente estados, conteos y tiempos UTC sanitizados.

Las capturas de pantalla, nombres, correos, identificadores, UUID, razones completas y respuestas crudas no se versionan. El resultado aprobó los smoke tests productivos, la coordinación de perfil y Auth, la denegación durante la suspensión, la restauración mediante una sesión nueva y la preservación de asignación, actividades, asistencia e historia.

Este checkpoint no sustituye el snapshot vivo canónico ni permite inferir el inventario estructural post‑0010. Los casos 1–20 y los smoke tests están aprobados; la captura y reconciliación post‑0010 permanecen pendientes. B.3a continúa abierta, el proyecto desechable debe conservarse hasta su cierre y no debe crearse 0011.

## Reconciliación posterior a 0010

El snapshot `2026-08-06T23:33:15Z` fue comparado localmente contra el estado post‑0009 de `HEAD`, la migración 0010 inmutable y su verificador corregido. El informe `0010_post_apply_reconciliation.md` confirma el inventario `19/183/96/48/13/60/25/19/51`, los privilegios `147/274/6/463` y cero deriva inexplicada.

El delta observado corresponde exclusivamente a `admin_auth_operations`, sus 18 columnas, 16 restricciones, 5 índices, 2 triggers, RLS sin políticas cliente, las seis funciones B.3a y sus ACL exactas, junto con la revocación prevista de `authenticated` sobre el mutador B.2b. Políticas, privilegios de secuencia y 51 filas de catálogos controlados permanecen idénticos a post‑0009. B.3a queda cerrada; B.3b y Fase C continúan pendientes. `0011` es el siguiente número de migración disponible y no fue creado durante esta reconciliación.
