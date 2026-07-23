# Plan de pruebas 0010 — Coordinación Auth B.3a

## Estado y alcance

Este plan separa evidencia local, PostgreSQL, Edge, Auth hospedado y producción. En esta preparación:

- 0010 no está aplicada;
- el preflight y el verificador PostgreSQL no se han ejecutado;
- la Edge Function no está desplegada ni se ha invocado;
- no se ejecutó ninguna operación Auth Admin;
- no se ha probado suspensión, refresh, JWT ni restauración en Supabase hospedado;
- B.3a permanece abierta y la prueba Auth desechable es bloqueante antes de producción.

La revisión local previa a aplicación detectó y corrigió defectos del arnés y del contrato todavía no desplegado: el verificador usaba un nombre obsoleto para el rechazo de objetivo pendiente, mientras la implementación emitía el contrato canónico `sitaa_account_lifecycle_pending_target`; el guard aceptaba implícitamente un writer `NULL`; la consulta de `request_id` precedía al advisory lock; contexto y claim discrepaban para `processing/auth_synchronized`; y la Edge no validaba de forma total las filas ni el replay final. Estas correcciones son sólo diseño y pruebas estáticas locales: no constituyen evidencia PostgreSQL ni Auth hospedada.

Una segunda revisión recibió un paquete desactualizado respecto del repositorio canónico: contenía hashes anteriores en verificador/rollback, carecía del lock de auditoría, conservaba resultados terminales en el adaptador y mostraba archivos de aplicación B.2b. La captura obligatoria previa a esta corrección confirmó que el árbol canónico ya tenía sincronizados esos elementos. Antes de cualquier ejecución se añadió el cercado por intento, el reloj de pared posterior a locks y la inmutabilidad estricta de evidencia. No se ejecutaron preflight, SQL, Edge Function ni Auth Admin.

La revisión final del catálogo corrigió antes de cualquier ejecución la identidad física de `request_id`: la restricción `admin_auth_operations_request_id_key` crea y usa el índice del mismo nombre, sin `UNIQUE USING INDEX` ni un índice duplicado. También hizo total la validación de transición, alineó el preflight embebido con toda la superficie bloqueante independiente y completó los mapas canónicos predestructivos y post-rollback. Estas correcciones siguen siendo exclusivamente locales y estáticas.

Una revisión posterior detectó acceso crudo a tablas protegidas dentro de intervalos del verificador ejecutados como `authenticated` o `service_role`, un baseline ACL predestructivo de rollback que todavía exigía el mapa completo post‑0009 y la pérdida de resultados estables enviados por Edge con HTTP 403/409. El arnés quedó separado por fases: los roles cliente sólo invocan RPC aprobadas o escriben resultados sanitizados en `pg_temp`; toda postcondición cruda y toda regresión del trigger del ledger se ejecuta como owner después de `RESET ROLE`. El rollback distingue funciones preexistentes sin cambios, el mutador 0009 owner-only y las seis funciones 0010. La aplicación reutiliza el parser exacto también para el cuerpo JSON de `FunctionsHttpError`, sin activar el fallback 0009 ante errores Edge. No se ejecutaron PostgreSQL, preflight, Edge Function ni operaciones Auth Admin.

El verificador SQL demuestra contratos de base y simula resultados controlados; no demuestra la semántica hospedada de `ban_duration`, sesiones o refresh tokens.

## 1. Validación estática y local

Ejecutar sin conexión a Supabase:

```text
npm run check:text
npm run check:ui
npm run check:permissions
npm run check:lifecycle
npm run check:auth-lifecycle
npm run check:sql:0009
npm run check:sql:0010
node --check scripts/check-auth-lifecycle-b3a.mjs
node --check scripts/check-sql-0010.mjs
npm run lint
npm run build
git diff --check
```

Comprobar además:

- migraciones y artefactos 0001–0009 sin cambios;
- snapshot y reportes previos sin cambios;
- ningún 0011;
- ninguna referencia a secretos fuera del paquete Edge y documentación explícita;
- `.env.example` sin `service_role` o secret key;
- sin cliente privilegiado bajo `app/`, `components/` o `lib/`;
- SQL con transacciones, delimitadores y cierres correctos;
- código y documentación en UTF‑8, sin PII sintética distinta de `.invalid`.

Si Deno o el runtime Edge local no está disponible, registrar esa ausencia y no instalar herramientas globales. La validación estática no sustituye el type-check de Edge.

## 2. Preflight PostgreSQL

En una ventana de mantenimiento revisada, ejecutar primero `0010_coordinated_auth_session_suspension_preflight.sql`:

- debe devolver todas las categorías ordenadas;
- toda categoría `blocking` debe tener conteo cero;
- debe terminar con `ROLLBACK`;
- no debe mostrar UUID, PII, secretos ni filas operativas.

Validar inventario post‑0009 18/165/80/43/11/54/25/18/51, privilegios 137/267/6/445, firmas/cuerpos/metadata de las 54 funciones, ACL nominal exacto de funciones/tablas/secuencias, tres grants explícitos de columna de nombres propios, Auth/perfil, triggers, B.1, B.2a, B.2b, auditoría, semillas y ausencia de objetos 0010. Los hashes nominales se derivaron del snapshot vivo canónico post‑0009 ya versionado; no se regeneró ni modificó. El default ACL no tiene un hash canónico inventado: se bloquean defaults peligrosos y la migración captura su hash completo para exigir preservación exacta post-DDL. Guardar resultado sanitizado antes de considerar la aplicación.

## 3. Migración y verificador transaccional

Después de publicar una aplicación compatible y aprobar el preflight:

1. aplicar 0010 una sola vez y exigir `COMMIT` posterior a la guarda post‑DDL;
2. ejecutar `0010_coordinated_auth_session_suspension_verify.sql`;
3. exigir `ROLLBACK` final y comprobar que no persisten fixtures, operaciones, auditoría o grants temporales.

El verificador debe cubrir forma exacta de tabla, restricciones, índices, RLS sin políticas, triggers, firmas/argumentos/columnas de retorno, propiedades de función, ACL sin grant option y regresiones 0001–0009. Los cinco índices deben ser exactamente `admin_auth_operations_actor_requested_idx`, `admin_auth_operations_one_nonfinal_target_uidx`, `admin_auth_operations_pkey`, `admin_auth_operations_request_id_key` y `admin_auth_operations_target_status_idx`. La restricción única de `request_id` debe apuntar mediante `conindid` al índice `_key`, que debe ser único, válido, listo, no primario, no parcial, sin expresión y contener únicamente `request_id`; no puede existir otro índice de esa columna.

La disciplina de roles del verificador es bloqueante:

- `authenticated` sólo invoca contexto, preparación y finalización B.3a, además de las dos denegaciones ACL deliberadas y escrituras expresamente concedidas a superficies `pg_temp`;
- `service_role` sólo invoca claim/result, la denegación directa deliberada y superficies `pg_temp`;
- toda lectura de perfiles, Auth, asignaciones, ledger, auditoría, actividades, participantes, timestamps, hashes y UUID de evidencia ocurre después de `RESET ROLE`;
- las mutaciones directas que prueban el trigger de `admin_auth_operations` se ejecutan como owner con `sitaa.b3a_writer` local y se limpian inmediatamente;
- `scripts/check-sql-0010.mjs` debe auditar cada intervalo de rol, aceptar únicamente los dos bloques negativos exactos y reportar cero referencias no autorizadas.

Bajo roles reales debe probar:

- mutación 0009 directa denegada a `authenticated` con `42501`;
- usuarios ordinarios, objetivo, pendiente, administrador malformado/inactivo y autoacción denegados;
- transición `NULL`, vacía, desconocida y en mayúsculas rechazada por la RPC pública con SQLSTATE `22023`, mensaje exacto `sitaa_account_lifecycle_invalid_transition` y cero cambios de perfil, ledger o auditoría;
- último administrador protegido;
- request ID idempotente y conflicto rechazado;
- una sola operación no final por objetivo;
- writer ausente, vacío o desconocido rechazado en `INSERT`/`UPDATE`, limpieza del writer después de cada DML aprobado y `DELETE`/`TRUNCATE` siempre prohibidos;
- allowlist exacta de columnas por writer `prepare|claim|record|finalize` y matriz completa de estado/etapa/evidencia;
- desactivación llega una vez a `profile_suspended` y su reintento no duplica evento B.2b;
- reactivación preparada no activa el perfil;
- éxito Auth simulado llega a `auth_synchronized` y finaliza una sola vez;
- recuperación inmediata de `processing/auth_synchronized` sin repetir Auth, lease fresco no sincronizado no reclamable y replay de operaciones finales;
- cercado de resultado con `claimed_attempt_count`: un intento anterior recibe `sitaa_auth_operation_stale_attempt` sin cambiar ledger, auditoría ni timestamps, y el intento vigente puede continuar;
- timestamps monotónicos con un único `clock_timestamp()` capturado después de los locks en cada mutación; `now()`/`current_timestamp` no son relojes autoritativos de lease;
- UUID y timestamps de evidencia no reemplazables después de adquirir valor, fallo terminal imposible tras `auth_synchronized` y fallo reintentable de finalización que conserva la evidencia Auth original;
- selección de la operación más reciente antes de derivar el estado, de modo que un éxito posterior suprima un fallo terminal anterior;
- rechazo explícito de resultado `NULL`, códigos `NULL`, código en éxito y códigos fuera de allowlist;
- reintento por un segundo administrador exacto, con actor Auth igual al ejecutor real y actor B.2b igual a quien realizó la transición de perfil;
- un segundo administrador exacto puede finalizar;
- pérdida de autoridad antes de finalizar falla cerrado;
- fallo Auth deja desactivación inactiva;
- fallo posterior a restauración Auth deja reactivación inactiva;
- fallos retryable/terminal del modelo SQL, allowlist de error y auditoría minimizada; el adaptador hospedado provisional emite sólo `retryable_failure` hasta validar una categoría terminal y su recuperación;
- preservación de Auth, identidad, asignaciones, actividades, participantes, asistencia e historia;
- ausencia de mutación de roles y de comportamiento B.3b.

## 4. Validación local de Edge Function

Type-check del paquete Edge con el mecanismo local soportado. Sin invocarlo contra proyectos:

- `verify_jwt = true`, POST JSON y límite de 16 KiB;
- campos exactos para `start` y `retry`;
- actor derivado exclusivamente del JWT verificado;
- cliente de usuario para preparación/finalización y cliente privilegiado confinado para claim/result/Auth Admin;
- `attempt_count` devuelto por claim se envía sin transformación al RPC de resultado y la respuesta debe devolver el mismo intento;
- persistencia, refresh y detección URL deshabilitados en el cliente privilegiado;
- adaptador usa `updateUserById()`, no `signOut()` sin JWT objetivo;
- respuestas/logs sólo con operación, fase, código y timestamp sanitizados;
- ninguna razón, cabecera, JWT, cookie, correo, nombre o payload de proveedor en logs.
- el adaptador Next.js conserva cuerpos estables válidos de HTTP 403/409 mediante `FunctionsHttpError.context.json()` leído una sola vez y el mismo parser exacto usado para HTTP 200;
- cuerpos HTTP malformados y errores `FunctionsRelayError`, `FunctionsFetchError` o desconocidos fallan cerrados como `trusted_boundary_unavailable`, sin analizar `error.message`;
- ningún error Edge, sea de negocio o transporte, activa el fallback 0009; éste depende únicamente de la ausencia explícita de la RPC de contexto B.3a.

## 5. Matriz Auth hospedada desechable — obligatoria

Usar un proyecto desechable, un objetivo sintético sin datos reales y dos sesiones/dispositivos independientes. Descartar el entorno completo al terminar; no borrar selectivamente auditoría append-only de producción.

| # | Prueba | Evidencia requerida |
| ---: | --- | --- |
| 1 | Login base | Login del objetivo sintético exitoso antes de suspender. |
| 2 | Refresh base | Ambas sesiones renuevan antes de suspender. |
| 3 | JWT existente | Registrar, sin asumir, si cada JWT ya emitido continúa siendo aceptado inmediatamente después. |
| 4 | Refresh suspendido | Registrar el comportamiento de refresh en ambas sesiones tras suspender. |
| 5 | Login nuevo suspendido | Registrar el resultado de un login fresco. |
| 6 | Segunda sesión | Registrar independientemente el resultado del segundo dispositivo. |
| 7 | Barrera SITAA | Probar que operaciones SITAA se niegan de inmediato por perfil inactivo, cualquiera que sea el JWT. |
| 8 | Restauración | Aplicar el valor aislado `ban_duration = 'none'` y registrar el resultado real. |
| 9 | Refresh anterior restaurado | Registrar si refresh tokens anteriores vuelven o no a funcionar. |
| 10 | Login nuevo restaurado | Probar un login fresco posterior a restauración. |
| 11 | `activated_at` | Confirmar que conserva el valor original. |
| 12 | Historia | Confirmar asignaciones y toda historia operativa sin cambios. |
| 13 | Fallo Auth inyectado | Reintentar y demostrar idempotencia sin segundo evento de ciclo. |
| 14 | Fallo de finalización | Tras éxito Auth, reintentar y demostrar que no repite Auth. |
| 15 | Recuperación por segundo admin | Otra autoridad B.1 exacta completa una operación varada. |
| 16 | ACL 0009 | `authenticated` recibe `42501` al invocar la mutación 0009. |
| 17 | Usuarios ordinarios | Profesor/alumno no preparan, reclaman, registran, finalizan ni reintentan. |
| 18 | Límite `service_role` | No accede al ledger; sólo ejecuta claim/result aprobados. |
| 19 | Ausencia de secretos | Revisar bundles, variables Vercel visibles y logs sin secreto. |
| 20 | Sanitización | Interfaz y auditoría no muestran error Auth crudo. |

También verificar recuperación después de timeout de `processing`, dos solicitudes concurrentes al mismo objetivo y request ID repetido con payload distinto. El fallo `terminal_failure` se prueba sólo como estado sintético y transaccional del modelo SQL. El adaptador hospedado provisional debe producir únicamente `retryable_failure`; esta matriz no exige ni acepta una salida terminal hospedada. Una categoría terminal hospedada sólo podrá introducirse después de contar con evidencia empírica en un proyecto desechable, una clasificación estable del proveedor y un camino de recuperación del operador aprobado. Registrar versiones SDK/runtime, tiempos UTC, respuestas sanitizadas y resultado observado; nunca tokens o credenciales.

### Pruebas multisesión reservadas y no ejecutadas

En una base desechable, dos sesiones deben usar simultáneamente el mismo `request_id` y payload normalizado. La primera adquiere el advisory lock; la segunda espera y, al continuar, devuelve exactamente el mismo `operation_id` en vez de una violación UNIQUE. Repetir con payload distinto y exigir `sitaa_auth_operation_request_id_conflict`.

Otra pareja de sesiones debe iniciar la transacción de la sesión que espera antes de que el holder libere el lock. Al continuar, el waiter debe capturar tiempo de pared posterior al lock: `processing_started_at` no puede quedar retrodatado, la operación más reciente debe conservar el orden correcto y un lease recién adquirido no puede parecer vencido ni reclamarse prematuramente. Repetir la recuperación después de cinco minutos y la recuperación inmediata de `processing/auth_synchronized`. El verificador de una sola transacción cubre reutilización, conflicto, cercado de intentos y monotonicidad local, pero no demuestra espera real ni orden intersesión. Ninguna de estas pruebas se ejecutó durante este hardening.

### Matriz de pérdida de autoridad tras espera — reservada y no ejecutada

Estas pruebas requieren dos sesiones en una base PostgreSQL/Supabase desechable:

| Escenario | Sesión A | Sesión B | Resultado exigido |
| --- | --- | --- | --- |
| Claim | Inicia `claim` con autoridad B.1 y espera el advisory lock. | Retiene el lock, desactiva A y confirma. | A recibe `42501/sitaa_admin_access_denied`; `attempt_count`, estado y timestamps quedan intactos. |
| Persistencia de resultado | Con intento reclamado, inicia `record` y espera. | Adquiere primero el lock, desactiva A y confirma. | A recibe `42501`; no se inserta evento Auth ni cambia el ledger. |
| Replay final | Solicita replay de una operación ya `succeeded` y espera. | Retiene el lock, desactiva A y confirma. | A recibe `42501`, nunca la fila final. |
| Recuperación | Ya perdió autoridad y deja una operación varada. | Otra autoridad B.1 exacta reclama/finaliza. | Se recupera sin repetir trabajo Auth después de `auth_synchronized`. |

El verificador transaccional sólo demuestra denegación determinista cuando el actor ya está inactivo/no es B.1 exacto al invocar, ausencia de mutación y recuperación por otro administrador. No prueba la espera intersesión.

### Contrato exacto de respuestas Edge

El parser debe aceptar únicamente matrices discriminadas:

- `completed`: `account_deactivated` o `account_reactivated`, siempre con UUID;
- `terminal_failure`: código terminal SQL permitido, siempre con UUID;
- `pending`: código de una operación existente con UUID, o fallo previo a conocer la operación sólo para la allowlist que admite `null`;
- `rejected`: código exacto de solicitud, autenticación o preparación y `operationId = null`.

Debe rechazar llaves adicionales, códigos/estados desconocidos, UUID ausente donde corresponda y cualquier cruce entre código y estado. La Server Action exige además que `deactivate` termine en `account_deactivated` y `reactivate` en `account_reactivated`; un `state = completed` aislado nunca autoriza redirección.

## 6. Smoke tests de producción

Sólo después de aprobar las fases anteriores y desplegar la Edge Function:

- autoridad B.1 ve contexto y operación sanitizada;
- desactivar bloquea SITAA de inmediato, conserva datos y muestra sincronización pendiente/completa con precisión;
- reactivar no habilita SITAA antes de finalizar;
- reintentos conservan request/operation ID y no duplican auditoría;
- un usuario ordinario no ve ni ejecuta controles;
- incompatibilidad pre‑0010 usa sólo el fallback explícito; post‑0010 nunca cae a 0009 ante error Edge;
- navegador y Vercel no exponen secreto ni cliente privilegiado.

## 7. Criterio de cierre

B.3a sólo puede cerrarse cuando exista evidencia aprobada de preflight, `COMMIT`, verificador con `ROLLBACK`, despliegue Edge, matriz Auth desechable completa, smoke tests y snapshot post‑0010 reconciliado. Hasta entonces:

- no afirmar invalidación de JWT, refresh o restauración;
- no usar la función en producción;
- no describir 0010 como aplicada;
- no crear 0011;
- B.3b y Fase C permanecen fuera de alcance.

El rollback 0010 sólo puede considerarse antes de la primera operación o evento B.3a real; después queda prohibido por diseño.
Antes de revisar historia, el rollback adquiere `ACCESS EXCLUSIVE NOWAIT` primero sobre `admin_auth_operations` y después sobre `admin_audit_events`; mantiene ambos locks durante la guarda completa, las dos comprobaciones históricas y la eliminación controlada.
Su guarda predestructiva exige 135 entradas y hash `5c2ce865124e0669c787d12fe4c46b59` para las funciones preexistentes sin el mutador 0009 ni las seis funciones 0010, una única entrada `EXECUTE` no delegable del owner para el mutador 0009 y la matriz exacta de las seis funciones 0010. El mapa completo post‑0009 de 137 entradas y hash `4ea1d04b7d1b1632fd5ce01a1dc83e05` se exige únicamente después de retirar 0010 y restaurar `authenticated` sobre el mutador 0009.
