# Evidencia de la matriz Hosted Auth central de 0010

## Alcance y entorno

La matriz Hosted Auth central B.3a se ejecutó una sola vez el 3 de agosto de 2026 en un proyecto Supabase desechable, con dos sesiones independientes de una cuenta objetivo sintética. El ensayo cubrió la coordinación central de suspensión y restauración entre SITAA y Auth; no fue una ejecución en producción ni cerró la matriz completa de veinte casos.

La evidencia versionada en este documento es un resumen sanitizado. Los archivos fuente `*.local.txt` permanecen locales, ignorados por Git y no deben añadirse al repositorio.

## Versiones y tiempos

| Elemento | Valor |
| --- | --- |
| Arnés | `2026-08-03-hosted-auth-core-v4` |
| Node.js | `v24.18.0` |
| Supabase JS | `2.110.1` |
| Inicio de matriz | `2026-08-03T21:21:09.817Z` |
| Desactivación completada | `2026-08-03T21:29:06.969Z` |
| Reactivación completada | `2026-08-03T21:29:10.604Z` |
| Fin de matriz | `2026-08-03T21:29:12.504Z` |

## Integridad de la evidencia local

| Nombre lógico | Bytes | SHA-256 |
| --- | ---: | --- |
| Evidencia central Hosted Auth | 2008 | `55315c6e4b9c34278d920f231bac48c7349a1f9da3b0d3d7e2516c90e2ea7cac` |
| Postcheck final de sólo lectura | 333 | `29c38e45dd6b8b5ae3aec4dd57380aef46c1ed198e89be03b1a45477ed49a389` |

## Baseline sanitizada

Antes de la confirmación irreversible se aprobaron el login administrativo, dos logins y dos sesiones independientes del objetivo, `getUser`, las RPC base y la renovación de ambas sesiones. La base contenía dos usuarios y dos identidades con contrato uno a uno válido, y la autoridad B.1 final era `2/2`. El conteo de operaciones reales B.3a era cero y el rollback todavía era elegible.

## Suspensión observada

Después de la confirmación irreversible, la desactivación se completó, el ban Auth quedó activo y la elegibilidad del rollback se revocó. Para las dos sesiones objetivo se observó:

- los JWT emitidos antes de la suspensión fueron rechazados con el código sanitizado `user_banned`;
- los refresh tokens anteriores fueron rechazados con `user_banned`;
- dos intentos de login nuevo durante la suspensión fueron rechazados con `user_banned`;
- las operaciones protegidas de SITAA intentadas con los dos tokens quedaron denegadas (`2/2`).

La evidencia persistida no distingue si cada denegación ocurrió en el gateway Auth o en la base. El verificador PostgreSQL demuestra por separado la barrera de perfil inactivo; la ejecución hospedada demuestra que ninguno de los dos tokens obtuvo acceso.

`user_banned` es el resultado empírico de esta ejecución hospedada concreta. No constituye una garantía permanente para todas las versiones futuras de Supabase.

## Restauración observada

La reactivación se completó, el ban Auth se eliminó y un login fresco posterior fue aprobado. Los dos refresh tokens emitidos antes de la suspensión continuaron rechazados con `user_banned`; por tanto, una cuenta reactivada debe iniciar una sesión nueva y no debe esperar que una pestaña o refresh token anterior recupere acceso automáticamente.

El ensayo confirmó la preservación de `activated_at`, asignaciones, historia operativa e identidad Auth. La autoridad B.1 final permaneció `2/2` y la auditoría sanitizada fue aprobada.

## Postcheck final exacto

| Comprobación | Resultado |
| --- | --- |
| `READ_ONLY_TRANSACTION` | `true` |
| `ROLLBACK` | `true` |
| `PROFILE_ACTIVE` | `1` |
| `AUTH_BAN_CLEARED` | `true` |
| `COMPLETED_OPERATIONS` | `2` |
| `EXPECTED_AUDIT_EVENTS` | `4` |
| `NON_SUCCEEDED_OPERATIONS` | `0` |
| `AUTH_FAILURE_EVENTS` | `0` |
| `AUTH_USERS` | `2` |
| `AUTH_IDENTITIES` | `2` |
| `AUTH_IDENTITY_CONTRACT` | `true` |
| `B1_ACTIVE_AUTHORITY` | `2/2` |

## Sanitización y rollback

Los dos archivos locales fueron revisados y no contienen correos, UUID, tokens, claves, contraseñas, URI, cookies, cabeceras `Authorization`, metadata sensible ni errores crudos. Este resumen tampoco incorpora identificadores del proyecto, datos de conexión ni motivos administrativos completos.

La primera operación Auth B.3a real dejó historia coordinada en el ledger y en la auditoría. Desde ese momento, el rollback 0010 quedó definitivamente prohibido por diseño y no debe ejecutarse.

## Limitaciones y pruebas pendientes

La matriz central aprobó los casos 1–12 del plan. El caso 16 ya estaba cubierto por el verificador PostgreSQL. El caso 19 quedó parcial: la evidencia, la salida del arnés y la auditoría están sanitizadas, pero faltan bundles, variables y logs productivos. El caso 20 también quedó parcial: la auditoría, la evidencia y la salida del arnés están sanitizadas, pero falta observar la interfaz desplegada mediante smoke test hospedado. Esto no debilita el resultado `AUTH_AUDIT_SANITIZATION|APPROVED` de la matriz central.

Permanecen pendientes los casos 13–15, 17–18 y el cierre de 19 y 20, además de timeout de `processing`, concurrencia real de dos sesiones, reutilización de `request_id` con payload igual y distinto, pérdida de autoridad tras esperar locks, replays de aplicación por pérdida de respuesta, smoke tests de producción y snapshot/reconciliación post‑0010. B.3a continúa abierta.
