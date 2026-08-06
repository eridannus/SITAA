# Evidencia Hosted Auth de concurrencia y límites de 0010

## Alcance

Este checkpoint resume una única ejecución aprobada de la matriz Hosted Auth de concurrencia y límites en un proyecto Supabase desechable, nunca en producción. Completa los límites hospedados restantes y la matriz real multisesión de concurrencia, leases y pérdida de autoridad de B.3a. No cierra B.3a por sí solo.

Los archivos fuente `*.local.txt` permanecen locales, ignorados por Git y no deben versionarse. Este documento conserva únicamente resultados agregados, sanitizados y verificables.

## Versiones y cronología

| Elemento | Valor |
| --- | --- |
| Arnés | `2026-08-05-hosted-auth-concurrency-boundaries-v8` |
| Node.js | `v24.18.0` |
| Supabase JS | `2.110.1` |
| Baseline aprobada | `2026-08-06T18:01:34.383Z` |
| Inicio irreversible | `2026-08-06T18:02:49.678Z` |
| Matriz completada | `2026-08-06T18:08:38.489Z` |

Sólo se registran tiempos UTC presentes en la evidencia final sanitizada; no se infieren tiempos intermedios ausentes.

## Integridad de la evidencia

| Fuente local | Estado | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| `b3a_matrix_hosted_auth_concurrency_boundaries.local.txt` | Predecesora v7 rechazada y preservada | 601 | `b022d7c1dcb1eb7278d0c7b6d87e8917d2a409d74405d5a5400906441f899755` |
| `b3a_matrix_hosted_auth_concurrency_boundaries_v8.local.txt` | Evidencia principal v8 aprobada | 1797 | `c150a18ac429f206735f38569ae43c69f62cba35ceeb02f6e683e440b065f829` |
| `b3a_matrix_hosted_auth_concurrency_boundaries_v8_postcheck.local.txt` | Postcheck v8 aprobado | 595 | `567e9d9c1f23a18780dbb281ec00ba77f7f69f9bc97f9edc0aad9260a7acd507` |

El artefacto `b3a_matrix_hosted_auth_concurrency_boundaries_v8_failure.local.txt` está ausente. No quedó postcheck de la predecesora v7, publicación temporal `.next` ni directorio `.sitaa-b3a-concurrency-runtime-*`. La ejecución no modificó el estado Git visible.

La evidencia principal contiene exactamente una aprobación final y ningún rechazo; el postcheck contiene su aprobación final y ningún rechazo. La predecesora v7 no se elimina, reescribe ni reclasifica.

## Predecesora y normalización de la fixture

La ejecución v7 ya había aprobado los límites hospedados de los casos 17 y 18 cuando se detuvo en el primer escenario concurrente con el código estable `advisory_observer_timeout`. Su evidencia se conserva como antecedente rechazado.

Un diagnóstico posterior de sólo lectura encontró que la Authority D sintética y desechable tenía cuatro campos de texto administrados por el proveedor representados como SQL `NULL` en vez de cadena vacía:

- `confirmation_token`;
- `email_change`;
- `email_change_token_new`;
- `recovery_token`.

El primer transporte de reparación fue rechazado por `psql` debido al transporte UTF-8 de Windows PowerShell antes de aceptar cualquier escritura. Un segundo intento acotado usó un archivo SQL UTF-8 sin BOM y normalizó únicamente esos cuatro campos para esa fila Auth sintética y desechable.

El postcheck de reparación confirmó cuatro valores `NULL` y cero cadenas vacías antes de la normalización, y cero valores `NULL` y cuatro cadenas vacías después. Los demás agregados Auth, perfiles, asignaciones, operaciones, auditoría, triggers, evidencia predecesora, runtime y Git permanecieron iguales.

Esta normalización fue mantenimiento de una fixture desechable. No fue una migración SITAA, cambio de esquema, cambio de aplicación o Edge, reparación de datos de producción ni recomendación general para modificar filas Auth administradas por Supabase.

Un probe Auth Admin posterior y de sólo lectura aprobó cuatro usuarios Auth únicos: Admin A, Admin B y Target C con detalle e identidad de correo, y Authority D validada por separado sin identidades. No modificó evidencia, runtime ni Git.

## Límites Hosted aprobados

### Caso 17 — usuarios ordinarios

En la fase PostgreSQL transaccional, las fixtures ordinarias de profesor y alumno quedaron denegadas en las superficies B.3a y no modificaron el ledger ni la auditoría. De forma separada, Target C autenticado pero sin autoridad B.1 fue rechazado en `start` y `retry` por la ruta Hosted. El perfil objetivo, el ledger y la auditoría conservaron sus hashes; el postcheck final confirmó también la identidad Auth del objetivo.

### Caso 18 — `service_role`

`service_role` no pudo leer ni mutar directamente `admin_auth_operations`; dentro de B.3a conservó únicamente las RPC aprobadas de claim y registro de resultado. Esto no modificó su ACL histórico `SELECT`/`INSERT` sobre `admin_audit_events`, sin `UPDATE`, `DELETE` ni `TRUNCATE`. Los casos 17 y 18 quedan aprobados por esta ejecución, no pendientes.

## Concurrencia y recuperación aprobadas

- El mismo `request_id` con payload normalizado idéntico devolvió la misma operación de forma idempotente.
- El mismo `request_id` con payload diferente fue rechazado.
- Solicitudes diferentes contra el mismo objetivo quedaron serializadas.
- Se observó espera real por advisory lock y el waiter inició antes de que el holder liberara el lock.
- `processing_started_at` se capturó después de adquirir el lock; `updated_at` permaneció monotónico y el orden de la operación más reciente fue correcto.
- Un lease fresco no fue recuperado prematuramente y pudo recuperarse después de cinco minutos.
- Un intento obsoleto fue rechazado y el intento vigente fue aceptado.
- La pérdida de autoridad mientras se esperaba el lock hizo fallar cerrados claim, record y replay final.
- Otra autoridad B.1 exacta recuperó la operación sincronizada.
- Auth se invocó exactamente una vez y no se repitió durante la recuperación.
- Solicitante y finalizador permanecieron diferenciados cuando correspondía.

## Postcheck agregado final

| Comprobación | Resultado |
| --- | ---: |
| Usuarios Auth | 4 |
| Identidades Auth | 3 |
| Perfiles | 4 |
| Asignaciones de rol | 3 |
| Autoridad B.1 exacta activa | 2/2 |
| Target C activo | Sí |
| Target C con ban | No |
| Asignaciones de Target C | 0 |
| Operaciones B.3a | 6 |
| Operaciones `succeeded/completed` | 6 |
| Operaciones no finales | 0 |
| Operaciones no exitosas | 0 |
| Eventos administrativos B.3a | 12 |
| Eventos Auth de fallo | 0 |
| Eventos Auth de éxito | 6 |
| Asignaciones administrativas baseline preservadas | Sí |
| Authority D sintética activa | No |
| Leases activos | 0 |
| Workers vivos | 0 |
| Handler Auth | `CANONICAL` |
| Transacción de sólo lectura | Sí |
| `ROLLBACK` | Sí |
| Postcheck final | Aprobado |

Estos valores describen únicamente la ejecución desechable. No sustituyen el snapshot vivo canónico ni permiten inferir el inventario post‑0010.

## Sanitización y limitaciones

La evidencia versionada no contiene secretos, credenciales, correos, UUID, URI, tokens, cookies, cabeceras, metadata cruda, razones administrativas completas ni errores del proveedor sin sanitizar.

`terminal_failure` permanece como estado sintético y transaccional del modelo SQL; esta matriz no aprobó una categoría Hosted terminal del proveedor. El comportamiento observado es evidencia empírica de esta ejecución concreta y no una garantía universal de Supabase.

La primera operación Auth real ya había revocado definitivamente la elegibilidad del rollback 0010. El rollback permanece prohibido.

## Gates restantes

- Caso 19 parcial: faltan revisar bundles de producción, variables visibles de Vercel y logs productivos.
- Caso 20 parcial: evidencia, auditoría y salida del arnés están sanitizadas, pero faltan la observación de la interfaz desplegada y los smoke tests hospedados.
- Los smoke tests de producción permanecen pendientes.
- Debe generarse el snapshot canónico post‑0010 y reconciliarse contra las migraciones 0001–0010.
- B.3a permanece abierta y todavía no debe crearse 0011.
- B.3b y Fase C quedan fuera de este checkpoint.
