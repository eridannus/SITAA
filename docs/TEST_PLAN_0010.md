# Plan de pruebas 0010 — Coordinación Auth B.3a

## Estado y alcance

Este plan separa evidencia local, PostgreSQL, Edge, Auth hospedado y producción. En esta preparación:

- 0010 no está aplicada;
- el preflight y el verificador PostgreSQL no se han ejecutado;
- la Edge Function no está desplegada ni se ha invocado;
- no se ejecutó ninguna operación Auth Admin;
- no se ha probado suspensión, refresh, JWT ni restauración en Supabase hospedado;
- B.3a permanece abierta y la prueba Auth desechable es bloqueante antes de producción.

La revisión local previa a aplicación detectó y corrigió defectos del arnés y del contrato todavía no desplegado: el verificador esperaba `sitaa_account_lifecycle_pending_target_forbidden` aunque la implementación emitía `sitaa_account_lifecycle_pending_target`; el guard aceptaba implícitamente un writer `NULL`; la consulta de `request_id` precedía al advisory lock; contexto y claim discrepaban para `processing/auth_synchronized`; y la Edge no validaba de forma total las filas ni el replay final. Estas correcciones son sólo diseño y pruebas estáticas locales: no constituyen evidencia PostgreSQL ni Auth hospedada.

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

Validar inventario post‑0009 18/165/80/43/11/54/25/18/51, privilegios 137/267/6/445, hashes, ACL, Auth/perfil, triggers, B.1, B.2a, B.2b, auditoría, semillas y ausencia de objetos 0010. Guardar resultado sanitizado antes de considerar la aplicación.

## 3. Migración y verificador transaccional

Después de publicar una aplicación compatible y aprobar el preflight:

1. aplicar 0010 una sola vez y exigir `COMMIT` posterior a la guarda post‑DDL;
2. ejecutar `0010_coordinated_auth_session_suspension_verify.sql`;
3. exigir `ROLLBACK` final y comprobar que no persisten fixtures, operaciones, auditoría o grants temporales.

El verificador debe cubrir forma exacta de tabla, restricciones, índices, RLS sin políticas, triggers, firmas/argumentos/columnas de retorno, propiedades de función, ACL sin grant option y regresiones 0001–0009. Bajo roles reales debe probar:

- mutación 0009 directa denegada a `authenticated` con `42501`;
- usuarios ordinarios, objetivo, pendiente, administrador malformado/inactivo y autoacción denegados;
- último administrador protegido;
- request ID idempotente y conflicto rechazado;
- una sola operación no final por objetivo;
- writer ausente, vacío o desconocido rechazado en `INSERT`/`UPDATE`, limpieza del writer después de cada DML aprobado y `DELETE`/`TRUNCATE` siempre prohibidos;
- allowlist exacta de columnas por writer `prepare|claim|record|finalize` y matriz completa de estado/etapa/evidencia;
- desactivación llega una vez a `profile_suspended` y su reintento no duplica evento B.2b;
- reactivación preparada no activa el perfil;
- éxito Auth simulado llega a `auth_synchronized` y finaliza una sola vez;
- recuperación inmediata de `processing/auth_synchronized` sin repetir Auth, lease fresco no sincronizado no reclamable y replay de operaciones finales;
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
- persistencia, refresh y detección URL deshabilitados en el cliente privilegiado;
- adaptador usa `updateUserById()`, no `signOut()` sin JWT objetivo;
- respuestas/logs sólo con operación, fase, código y timestamp sanitizados;
- ninguna razón, cabecera, JWT, cookie, correo, nombre o payload de proveedor en logs.

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

También verificar fallo terminal, recuperación después de timeout de `processing`, dos solicitudes concurrentes al mismo objetivo y request ID repetido con payload distinto. Registrar versiones SDK/runtime, tiempos UTC, respuestas sanitizadas y resultado observado; nunca tokens o credenciales.

### Pruebas multisesión reservadas y no ejecutadas

En una base desechable, dos sesiones deben usar simultáneamente el mismo `request_id` y payload normalizado. La primera adquiere el advisory lock; la segunda espera y, al continuar, devuelve exactamente el mismo `operation_id` en vez de una violación UNIQUE. Repetir con payload distinto y exigir `sitaa_auth_operation_request_id_conflict`. Otra pareja de sesiones debe comprobar lease fresco, recuperación después de cinco minutos y recuperación inmediata de `processing/auth_synchronized`. El verificador de una sola transacción cubre reutilización determinista y conflicto, pero no demuestra espera real ni orden intersesión. Ninguna de estas pruebas se ejecutó durante este hardening.

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
