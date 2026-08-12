# Estado reconciliado de la base de datos

**Actualización documental:** 2026-08-06.
**Snapshot vivo canónico:** `2026-08-06T23:33:15Z`, estado `SUCCESS`.

La cadena `0001`–`0010` está aplicada, verificada y reconciliada sin deriva inexplicada; todas sus migraciones son inmutables. Los casos 1–20 y los smoke tests productivos están aprobados con su atribución correspondiente. El snapshot canónico bajo `supabase/reconciliation/live/` representa el estado estructural post‑0010 y cierra B.3a dentro de su alcance aprobado.

`0011_academic_period_administration.sql` está asignada a `SEM-01` y fue aplicada correctamente en producción el 2026-08-12. El primer intento del verificador fue rechazado y conserva valor histórico únicamente; la segunda ejecución del verificador corregido aprobó el conjunto exacto de casos 1–51 y terminó con su propio `ROLLBACK` explícito. El script de rollback de la migración no fue ejecutado. SEM-01 continúa activo: el arnés multisesión, el snapshot/reconciliación post-0011 y `/admin/periods` siguen pendientes.

El snapshot vivo rastreado continúa siendo la evidencia canónica reconciliada post-0010 hasta que se regenere y revise. Por ello, este documento no infiere el inventario físico post-0011 a partir de la migración aplicada.

## Cadena aplicada

1. `0001_baseline_current_schema.sql`: baseline reconciliada.
2. `0002_database_security_and_integrity.sql`: seguridad, publicación y privilegios mínimos.
3. `0003_fix_draft_temporal_lifecycle.sql`: ciclo temporal de borradores.
4. `0004_identity_registration_foundation.sql`: identidad y registro institucional.
5. `0005_fix_google_oauth_user_creation.sql`: alta por Google OAuth.
6. `0006_structured_person_names.sql`: nombres estructurados y `full_name` derivado.
7. `0007_admin_account_directory_audit.sql`: directorio B.1 de sólo lectura y auditoría append-only.
8. `0008_operational_account_barrier_identity_correction.sql`: barrera de cuenta activa y corrección de identidad B.2a.
9. `0009_admin_account_lifecycle_transitions.sql`: desactivación/reactivación auditada B.2b.
10. `0010_coordinated_auth_session_suspension.sql`: coordinación B.3a entre ciclo de vida SITAA y Auth; aplicada, verificada, probada y reconciliada; B.3a cerrada.

## Inventario vivo posterior a 0010

| Categoría | Cantidad |
| --- | ---: |
| Tablas públicas | 19 |
| Columnas | 183 |
| Restricciones PK, FK, UNIQUE o CHECK | 96 |
| Índices, incluidos los respaldados por restricciones | 48 |
| Triggers sobre tablas públicas | 13 |
| Funciones y firmas públicas | 60 |
| Políticas RLS | 25 |
| Tablas con RLS habilitado | 19 |
| Filas en catálogos controlados | 51 |
| Grants de rutinas | 147 |
| Grants de tablas publicados por `information_schema` | 274 |
| Grants de secuencias | 6 |
| Entradas ACL expandidas | 463 |

La línea base histórica post‑0009 era `18/165/80/43/11/54/25/18/51` y `137/267/6/445`. El delta post‑0010 observado es exactamente `+1/+18/+16/+5/+2/+6/0/+1/0` y `+10/+7/0/+18`: corresponde a la tabla `admin_auth_operations`, sus objetos dependientes, las seis funciones B.3a y la revocación prevista del mutador B.2b. No existe deriva inexplicada.

## Contratos acumulados vigentes

- Cada `auth.users` aceptado corresponde a un único perfil SITAA; Google crea un perfil `pending_registration` y la finalización institucional autenticada lo activa.
- Los componentes estructurados del nombre son autoritativos y `full_name` es compatibilidad derivada.
- `admin_audit_events` conserva nueve columnas, RLS sin políticas de cliente y protección append-only.
- B.1 exige `technical_admin/system/technical` exacto; B.2a conserva esa autoridad, la barrera operativa independiente del JWT y la corrección de identidad auditada.
- B.2b permite desactivar o reactivar cuentas elegibles, protege el último administrador exacto, conserva `activated_at`, asignaciones e historia y genera auditoría minimizada.
- Una cuenta inactiva no puede operar SITAA aunque conserve un JWT técnicamente válido.
- 0009, por sí sola, no usa Auth Admin ni revoca sesiones físicas; 0010 añade la coordinación hospedada mediante el límite Edge confiable.
- RLS continúa habilitado en las 19 tablas y `PUBLIC`/`anon` no ejecutan funciones SITAA; `anon` conserva únicamente la lectura deliberada de `system_health`.
- Catálogos, actividades, participantes y asistencia preservan sus contratos acumulados.

Las matrices manuales de concurrencia B.2a/B.2b siguen sin ejecutarse y no constituyen evidencia de producción.

## 0010 aplicada, verificada, probada y reconciliada

`0010_coordinated_auth_session_suspension.sql` fue aplicada y el registro local termina en `COMMIT`. Añade:

- `admin_auth_operations`, ledger sin políticas cliente para coordinar perfil y Auth;
- cinco RPC B.3a públicas o de servicio y un trigger de estado owner-only;
- retiro de `EXECUTE` directo de `authenticated` sobre la mutación B.2b;
- una Edge Function autenticada como único límite para Auth Admin y `service_role`;
- reintentos idempotentes que reanudan desde la última etapa persistida;
- cercado por intento para impedir que un resultado Auth tardío se aplique a un claim posterior;
- timestamps autoritativos de reloj de pared posteriores a los locks e inmutabilidad estricta de evidencia;
- evidencia administrativa minimizada y separación explícita entre la transición del perfil y la sincronización Auth.

La barrera 0008 sigue siendo el límite operativo inmediato. La coordinación no simula atomicidad entre PostgreSQL y Auth: desactivar primero bloquea el perfil y después intenta suspender Auth; reactivar primero restaura Auth y sólo entonces activa el perfil. El modelo SQL conserva estados recuperables y terminales sanitizados, pero el adaptador hospedado provisional emite únicamente fallos reintentables hasta verificar una taxonomía terminal y un camino de recuperación. Nunca se persisten errores crudos.

La reconciliación del snapshot `2026-08-06T23:33:15Z` confirmó la tabla de 18 columnas, 16 restricciones, 5 índices, 2 triggers, RLS habilitado y cero políticas cliente. Sus siete privilegios publicados por `information_schema` y ocho ACL expandidas —incluido `MAINTAIN`— pertenecen exclusivamente al owner. Las seis funciones B.3a son `SECURITY DEFINER` con `search_path = pg_catalog, public` y ACL exactas: contexto, preparación y finalización para owner más `authenticated`; claim y record para owner más `service_role`; trigger owner-only. El mutador B.2b quedó owner-only. Las 25 políticas, los 6 grants de secuencia y las 51 filas de catálogos controlados permanecieron idénticos a post‑0009.

El primer preflight remoto se ejecutó en una transacción de sólo lectura, devolvió sus 34 filas y terminó con `ROLLBACK` y código 0. No fue aprobado: 29 de 30 categorías bloqueantes fueron cero, pero `dangerous_default_acl` devolvió 50. El diagnóstico posterior, también de sólo lectura y cerrado con `ROLLBACK`/código 0, identificó cinco grupos estándar de diez filas: `postgres/public`, `postgres/storage`, `supabase_admin/graphql`, `supabase_admin/graphql_public` y `supabase_admin/public`. Ninguna de estas ejecuciones cambió objetos, filas o privilegios predeterminados.

La categoría corregida exige ejecutor y sesión `postgres`; inspecciona sólo defaults creados por `postgres`, globales o de `public`, para tablas y funciones, y bloquea grantees fuera de la allowlist que 0010 normaliza expresamente. Los defaults de secuencia, otros esquemas y otros propietarios quedan fuera porque no pueden inicializar los objetos creados por 0010. La captura y comparación del hash completo de `pg_default_acl` permanece intacta.

La segunda ejecución corregida quedó aprobada: devolvió exactamente 34 filas, dejó las 30 categorías bloqueantes en cero y produjo `dangerous_default_acl = 0`. Sus cuatro conteos informativos fueron `active_exact_b1_administrators = 1`, `existing_b2b_lifecycle_events = 4`, `inactive_accounts = 0` e `inactive_accounts_with_active_or_future_assignments = 0`. Terminó con `ROLLBACK`, código 0 y sin `ERROR`; no expuso UUID, datos operativos, PII, credenciales, tokens o secretos y no cambió ningún objeto, fila o privilegio.

Antes de la matriz central, la aplicación compatible se había desplegado y la Edge Function figuraba `ACTIVE` sin invocaciones registradas. El primer verificador hospedado terminó con código de salida 3 en `restore_failure_finalize`: la función devolvió correctamente `42501/sitaa_account_lifecycle_auth_unconfirmed`, pero el arnés intentaba capturarlo con `raise_exception`, condición reservada para `P0001`. No imprimió el `ROLLBACK` final; la desconexión de `psql` descartó la transacción abierta. En ese momento todavía no se había ejecutado Auth Admin ni una operación real B.3a.

El diagnóstico posterior al aborto confirmó que el ledger existe, hay seis funciones B.3a, el ledger tiene cero filas y existen cero eventos de auditoría Auth B.3a. Terminó con `ROLLBACK` y código de salida 0; no sobrevivió ningún fixture del primer intento.

La reejecución usó `insufficient_privilege` y validó de forma conjunta SQLSTATE `42501` y el mensaje estable. Completó todos los escenarios, imprimió exactamente un `ROLLBACK` final, terminó con código de salida 0 y no produjo líneas `ERROR`. El verificador PostgreSQL quedó aprobado sin persistir fixtures, privilegios temporales, operaciones o auditoría.

## Matriz Hosted Auth central aprobada

La matriz central se ejecutó una sola vez el 3 de agosto de 2026 en un proyecto desechable. La evidencia sanitizada está resumida en `supabase/reconciliation/0010_hosted_auth_core_evidence.md`. Durante la suspensión, los JWT de dos sesiones, sus refresh tokens y dos logins nuevos fueron rechazados con `user_banned`; las operaciones protegidas de SITAA intentadas con los dos tokens quedaron denegadas (`2/2`). Después de restaurar Auth, un login fresco funcionó y los refresh tokens anteriores continuaron rechazados. Estas semánticas son resultados empíricos de esa ejecución hospedada, no garantías universales para versiones futuras del proveedor.

El postcheck final registró:

- dos operaciones completadas y cuatro eventos de auditoría esperados;
- cero operaciones no exitosas y cero eventos Auth de fallo;
- perfil objetivo activo y ban Auth eliminado;
- dos usuarios y dos identidades preservados, con contrato de identidad válido;
- autoridad B.1 final `2/2`;
- transacción de sólo lectura y `ROLLBACK` aprobados.

También quedaron preservados `activated_at`, las asignaciones, la historia operativa y la identidad Auth. La primera operación real revocó definitivamente la elegibilidad del rollback 0010.

## Matriz Hosted Auth failure/recovery v11 aprobada para 13–15

La matriz failure/recovery se ejecutó una sola vez en el mismo tipo de entorno desechable y reutilizó un Target C sintético con procedencia bootstrap v7. El checkpoint sanitizado está en `supabase/reconciliation/0010_hosted_auth_failure_recovery_evidence.md`.

- Caso 13: un fallo Auth controlado y reintentable preservó `profile_suspended`; el reintento completó la misma operación sin duplicar el evento de perfil ni repetir Auth durante los replays finales.
- Caso 14: después de una única sincronización Auth, un fallo controlado `auth_unconfirmed` conservó `processing/auth_synchronized`; la recuperación no repitió Auth.
- Caso 15: Admin B completó la operación solicitada por Admin A; solicitante y finalizador permanecieron diferenciados y la reactivación acumuló una sola llamada Auth.

El postcheck aprobó 3 usuarios Auth, 3 identidades, 3 perfiles, 2 asignaciones, autoridad B.1 `2/2`, Target C activo y sin ban ni asignaciones, 4 operaciones B.3a completadas, 8 eventos administrativos esperados, 0 operaciones no finales o no exitosas, 0 eventos Auth de fallo y 2 nuevos eventos Auth de éxito. Terminó en `READ ONLY` con `ROLLBACK`. Estos conteos describen la ejecución desechable; no sustituyen ni permiten inferir un snapshot vivo post‑0010.

La ejecución no convierte `auth_temporarily_unavailable`, `auth_unconfirmed` ni el comportamiento observado del proveedor en garantías universales. El caso 16 sigue atribuido al verificador PostgreSQL. Los casos 17–18 y la concurrencia multisesión se aprobaron después mediante la matriz v8; el caso 19 fue aprobado posteriormente mediante la auditoría productiva de ausencia de secretos y el caso 20 mediante el smoke test productivo. En el cierre de aquel checkpoint, el snapshot/reconciliación post‑0010 todavía permanecía pendiente.

## Matriz Hosted Auth de concurrencia y límites v8 aprobada

El checkpoint sanitizado `supabase/reconciliation/0010_hosted_auth_concurrency_boundaries_evidence.md` documenta una ejecución aprobada en el proyecto desechable. La evidencia v7 rechazada permanece como predecesora inmutable después de detenerse con `advisory_observer_timeout`. Antes de reanudar, una transacción estrecha normalizó cuatro campos de texto administrados por el proveedor únicamente en la Authority D sintética; el primer transporte había sido rechazado por `psql` sin aceptar escritura. Esta limpieza de fixture no fue migración, reparación de producción ni cambio de aplicación o Edge. Un probe Auth Admin posterior de sólo lectura aprobó el inventario sintético requerido.

La matriz v8 aprobó:

- caso 17: en PostgreSQL transaccional, las fixtures ordinarias de profesor y alumno quedaron denegadas en las superficies B.3a sin mutar ledger ni auditoría; de forma separada, Target C autenticado sin autoridad B.1 fue rechazado en `start` y `retry` por la ruta Hosted, se conservaron los hashes de perfil, ledger y auditoría, y el postcheck confirmó la identidad Auth del objetivo;
- caso 18: `service_role` no leyó ni mutó directamente `admin_auth_operations`; dentro de B.3a conservó únicamente las RPC aprobadas de claim/result, sin cambiar su ACL histórico `SELECT`/`INSERT` sobre `admin_audit_events` ni concederle `UPDATE`, `DELETE` o `TRUNCATE`;
- idempotencia del mismo `request_id` y payload normalizado, rechazo del payload conflictivo y serialización de solicitudes distintas contra el mismo objetivo;
- espera real por advisory lock, tiempos posteriores al lock, monotonicidad, orden de operación, lease fresco y recuperación después de cinco minutos;
- rechazo del intento obsoleto, aceptación del vigente y pérdida de autoridad fail-closed en claim, record y replay final;
- recuperación por otra autoridad B.1 exacta con una sola llamada Auth y sin repetición durante la recuperación.

El postcheck agregado final fue:

| Categoría | Resultado |
| --- | ---: |
| Usuarios Auth | 4 |
| Identidades Auth | 3 |
| Perfiles | 4 |
| Asignaciones de rol | 3 |
| Autoridad B.1 exacta activa | 2/2 |
| Target C activo / con ban / asignaciones | Sí / No / 0 |
| Operaciones B.3a | 6 |
| Operaciones `succeeded/completed` | 6 |
| Operaciones no finales / no exitosas | 0 / 0 |
| Eventos administrativos B.3a | 12 |
| Eventos Auth de fallo / éxito | 0 / 6 |
| Asignaciones administrativas baseline preservadas | Sí |
| Authority D sintética activa | No |
| Leases activos / workers vivos | 0 / 0 |
| Handler Auth | `CANONICAL` |
| Transacción de sólo lectura / `ROLLBACK` / postcheck | Sí / Sí / Aprobado |

Estos agregados pertenecen a la ejecución desechable y no sustituían el snapshot vivo post‑0010, que todavía estaba pendiente en aquel checkpoint.

## Auditoría productiva de ausencia de secretos aprobada para el caso 19

El checkpoint sanitizado `supabase/reconciliation/0010_production_secret_audit_evidence.md` documenta la auditoría sobre el commit `5df156ec0616da8823f6f13be41c2df11ea85537`. La revisión del operador confirmó tres variables públicas de proyecto con sus alcances, cero variables compartidas y cero nombres visibles de credenciales privilegiadas o de base de datos. En logs Production de la última hora observó 7 solicitudes HTTP 200 —3 a `/` y 4 a `/register`—, sin mensajes, warnings, errores, fatales ni hallazgos sensibles visibles.

La auditoría automatizada aprobó 22 artefactos de navegador locales (958637 bytes), 532 artefactos de servidor (31959047 bytes), 14 respuestas de rutas productivas (199327 bytes), 12 recursos estáticos remotos (702568 bytes) y 11 recursos JavaScript remotos. Encontró cero JWT privilegiados, cero secretos prohibidos y cero clientes privilegiados de primera parte. Las 280 apariciones de `service_role` y 8 de `SUPABASE_SECRET_KEY` en source maps de servidor fueron texto de dependencias sin valores asociados, sin ocurrencia de primera parte, navegador o recurso remoto; no son filtraciones.

Esta evidencia no mutó producción, no autenticó usuarios, no operó Supabase y no reemplaza el snapshot vivo. El primer build local fue bloqueado por la restricción del entorno Codex al escribir `.next/trace-build`; una repetición autorizada terminó con código 0 y no modificó archivos rastreados o staged ni los package files.

## Smoke test productivo de coordinación Auth aprobado para el caso 20

El checkpoint sanitizado `supabase/reconciliation/0010_production_smoke_test_evidence.md` documenta el recorrido controlado sobre el commit desplegado `18e40db3254d6c3b73b24dcd4d29ee229498b0e5`. Una autoridad B.1 exacta desactivó y reactivó una cuenta institucional estudiantil ficticia. La suspensión coordinada negó la sesión existente y un login fresco; la restauración Auth precedió a la activación final y permitió una sesión nueva.

La prueba dejó dos filas productivas finales en el ledger B.3a: una desactivación y una reactivación, ambas `succeeded/completed`, con un intento cada una, cero códigos de error estables, dos referencias de auditoría de perfil, dos referencias Auth y cuatro eventos append-only para el objetivo. La asignación, las actividades, la asistencia, la identidad y la historia permanecieron conservadas; el perfil terminó activo y sin ban.

Estas dos filas operativas no forman parte del inventario estructural. El snapshot post‑0010 excluye ledger y auditoría operativos; su existencia y estado final permanecen sustentados por la evidencia separada del smoke test y las observaciones Auth. La telemetría directa del dashboard Edge permanecía diferida; el checkpoint no afirma un conteo de invocaciones observado.

## Pendientes

- **A-02:** `technical_admin` mantiene acceso académico amplio a contenido publicado. **Deferred intentionally until user, role and permission administration is designed.**
- El paquete 0010 exige casts `::text` al serializar campos internos `char` de catálogo y revalida B.1 después de los locks en todas sus RPC mutables. Su verificador PostgreSQL está aprobado, pero no demuestra por sí solo la semántica hospedada de Auth.
- B.3a está cerrada: verificador, casos 1–20, smoke tests y reconciliación post‑0010 están aprobados.
- B.3b, administración de roles/Fase C, retiro de A-02, paneles especializados, formularios dinámicos, reportes y exportaciones continúan pendientes.
- `0011` está asignada a `SEM-01`, aplicada en producción y aprobada por su verificador transaccional de casos 1–51; el arnés multisesión y la reconciliación post-0011 permanecen pendientes.

## Evidencia y rollback

Los resultados de aplicación y verificación de 0009 están en `supabase/reconciliation/0009_post_apply_reconciliation.md`; el cierre estructural de 0010 está en `supabase/reconciliation/0010_post_apply_reconciliation.md`. Los snapshots vivos no se editan manualmente.

La matriz central produjo las primeras operaciones y eventos Auth B.3a reales. Las matrices failure/recovery v11 y concurrencia/límites v8 ampliaron la evidencia sin alterar esa decisión. La historia coordinada no puede eliminarse: el rollback 0010 quedó revocado y está prohibido por diseño. No se ejecutó durante este checkpoint documental.
