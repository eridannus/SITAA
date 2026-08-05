# Evidencia Hosted Auth failure/recovery de 0010

## Alcance

Este checkpoint resume una única ejecución aprobada de la matriz failure/recovery en un proyecto Supabase desechable, nunca en producción. Usó un Target C sintético ya aprovisionado, Admin A como solicitante y Admin B como recuperador. Cubre los casos 13, 14 y 15 del plan 0010; no constituye el cierre total de B.3a.

## Versiones y cronología

- Arnés: `2026-08-04-hosted-auth-failure-recovery-v11`.
- Procedencia de Target C: `2026-08-04-b3a-failure-target-bootstrap-v7`.
- Node.js: `v24.18.0`.
- Supabase JS: `2.110.1`.
- Baseline aprobada: `2026-08-05T01:09:51.987Z`.
- Contrato de Target C aprobado: `2026-08-05T01:10:56.694Z`.
- Confirmación irreversible iniciada: `2026-08-05T01:31:37.710Z`.
- Fallo Auth inyectado: `2026-08-05T01:31:40.203Z`.
- Recuperación del fallo Auth: `2026-08-05T01:31:48.000Z`.
- Auth de reactivación sincronizado: `2026-08-05T01:31:55.500Z`.
- Fallo controlado de finalización: `2026-08-05T01:31:59.865Z`.
- Recuperación por Admin B completada: `2026-08-05T01:32:04.935Z`.
- Matriz completada: `2026-08-05T01:32:05.999Z`.

## Integridad de la evidencia

| Fuente local | Bytes | SHA-256 |
| --- | ---: | --- |
| Evidencia principal failure/recovery | 2167 | `cf5653456e1ce1fca8b106bb4fb492f276f1f758eff10a3a643f88b13c743c8c` |
| Postcheck failure/recovery | 542 | `3404ddcd6f9c028a28f9db21a38d2dfb70c60f0c94fb9f38277ff55ca6e0e1c7` |

Los archivos fuente `b3a_matrix_hosted_auth_failure_recovery.local.txt` y `b3a_matrix_hosted_auth_failure_recovery_postcheck.local.txt` permanecen locales, ignorados por Git y no deben versionarse. Este documento conserva sólo evidencia agregada y sanitizada.

La verificación independiente posterior aprobó `FAILURE_RECOVERY_EVIDENCE_CONTRACT`, `FAILURE_RECOVERY_EVIDENCE_SANITIZATION` y `FAILURE_RECOVERY_EVIDENCE_GITIGNORE`; confirmó `CONFIRMATION_REPAIR_FILE|ABSENT`. No se encontró ningún marcador `REJECTED`.

## Baseline aprobada

- Baseline failure/recovery aprobada.
- Target C preaprovisionado y reutilizado con procedencia bootstrap v7 aprobada.
- Contrato Auth de Target C aprobado.
- Target C con cero asignaciones.
- Sesiones de Admin A y Admin B renovadas antes de la matriz.
- Confirmación irreversible aceptada.

## Caso 13 — fallo Auth inyectado

- Se preparó una operación de desactivación.
- El intento 1 registró el fallo controlado estable `auth_temporarily_unavailable` como `retryable_failure` y preservó la etapa `profile_suspended`.
- Un reintento posterior completó la misma operación sin repetir el evento de perfil: el conteo permaneció en uno.
- No se persistieron eventos Auth de fallo y se añadió un solo evento Auth de éxito.
- Aprobaron `PREPARE_REQUEST_ID_SAME_PAYLOAD_REPLAY`, `PREPARE_REQUEST_ID_PAYLOAD_CONFLICT`, `PREPARE_TARGET_NONFINAL_BUSY` y `RETRY_IDEMPOTENCY`.
- Aprobaron los replays `start` y `retry` de la operación ya completada.
- `AUTH_REPEATED_DURING_COMPLETED_REPLAYS=false`.

La inyección fue controlada. Este resultado no afirma que cualquier error real o futuro de Supabase sea reintentable ni generaliza la taxonomía del proveedor.

## Caso 14 — fallo de finalización

- La reactivación sincronizó Auth una sola vez.
- La confirmación de correo de Target C se alteró temporalmente sólo para provocar el fallo controlado.
- El segundo intento de finalización recibió el código estable `auth_unconfirmed`.
- La operación permaneció en `processing/auth_synchronized`.
- El fallo ocurrió después del único cambio Auth y la recuperación posterior no repitió Auth.

La alteración temporal de la confirmación fue una fixture desechable del ensayo. No es una función de producto ni un comportamiento operativo normal.

## Caso 15 — recuperación por segundo administrador

- Admin B completó la operación iniciada por Admin A.
- Admin A permaneció como solicitante y Admin B quedó como finalizador.
- `AUTH_CALLS_FOR_REACTIVATION=1`.
- `AUTH_REPEATED_DURING_RECOVERY=false`.
- `activated_at` e identidad Auth permanecieron preservados.
- La confirmación del correo fue restaurada.
- El archivo local de reparación quedó ausente.

## Postcheck final

| Comprobación | Resultado |
| --- | ---: |
| Auth users | 3 |
| Auth identities | 3 |
| Perfiles | 3 |
| Asignaciones de rol | 2 |
| Autoridad B.1 exacta | 2/2 |
| Target C activo | Sí |
| Ban Auth de Target C | No |
| Asignaciones de Target C | 0 |
| Operaciones B.3a | 4 |
| Operaciones `succeeded/completed` | 4 |
| Operaciones no finales | 0 |
| Operaciones no exitosas | 0 |
| Eventos administrativos esperados | 8 |
| Eventos Auth de fallo | 0 |
| Nuevos eventos Auth de éxito | 2 |
| Correo de Target C confirmado | Sí |
| Handler Auth canónico | Sí |
| Postcheck `READ ONLY` | Sí |
| `ROLLBACK` final | Sí |
| Matriz | Aprobada |

## Límites y pendientes

- Casos 13–15: aprobados por esta matriz v11.
- Caso 16: cubierto por el verificador PostgreSQL anterior, no por esta ejecución.
- Casos 17 y 18: pendientes.
- Caso 19: parcial; evidencia local y sanitización aprobadas, pero faltan bundles de producción, variables visibles de Vercel y logs productivos.
- Caso 20: parcial; evidencia, auditoría y salida del arnés sanitizadas, pero faltan la verificación completa de interfaz y los smoke tests hospedados.
- Permanecen pendientes la concurrencia multisesión, la espera real por advisory lock, el reloj posterior al lock, el lease fresco y su recuperación después de cinco minutos, los límites Hosted Auth, los smoke tests y la reconciliación post-0010.
- `terminal_failure` continúa siendo un estado sintético/transaccional del modelo SQL, no un resultado Hosted Auth empírico.
- B.3a permanece abierta y todavía no debe crearse 0011.

Este checkpoint documenta una ejecución concreta y desechable. No garantiza semántica futura de Supabase ni sustituye el snapshot vivo canónico post-0009.
