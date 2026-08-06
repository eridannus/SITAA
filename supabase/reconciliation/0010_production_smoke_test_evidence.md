# Evidencia 0010 — Smoke test productivo de coordinación Auth

## 1. Alcance

Este checkpoint documenta el smoke test de la interfaz productiva desplegada desde el commit exacto `18e40db3254d6c3b73b24dcd4d29ee229498b0e5`. Una autoridad técnica B.1 exacta ejecutó un recorrido controlado de desactivación y reactivación sobre una cuenta institucional estudiantil explícitamente ficticia.

La prueba produjo exclusivamente las mutaciones productivas controladas requeridas para comprobar la coordinación de perfil, Auth y presentación. El caso 20 y los smoke tests productivos quedaron aprobados. Este documento no cierra B.3a: la captura y reconciliación del snapshot canónico post‑0010 permanecen pendientes.

No se versionan nombres, correos, identificadores institucionales, UUID, contraseñas, capturas, hostnames, identificadores de proyecto, tokens, cookies, cabeceras, credenciales, respuestas crudas ni razones administrativas completas.

## 2. Baseline

| Condición | Resultado |
| --- | ---: |
| Estado del perfil | Activo |
| Correo Auth confirmado | Sí |
| Asignaciones vigentes o futuras | 1 |
| Responsabilidades abiertas | 0 |
| Participaciones abiertas | 0 |
| Eventos administrativos previos del objetivo | 0 |

La única asignación estudiantil estaba activa y acotada al programa académico. El usuario ordinario podía abrir dashboard, actividades y perfil, pero no veía Accounts, controles de ciclo de vida ni controles administrativos. Su sesión quedó abierta en `/activities` antes de la suspensión.

## 3. Desactivación

La autoridad B.1 exacta inició una desactivación desde la interfaz SITAA desplegada. La interfaz informó éxito, el perfil pasó de activo a inactivo, `deactivated_at` quedó poblado y el `activated_at` original se preservó.

La asignación no fue borrada ni reescrita: conservó fechas y bandera activa, mientras su presentación cambió de vigente a suspendida por estado de cuenta. Responsabilidades y participaciones abiertas permanecieron en cero. Se añadieron dos eventos append-only exitosos: desactivación del perfil y suspensión Auth.

Al refrescar una vez `/activities`, la sesión ordinaria ya emitida quedó denegada y regresó al login con la condición sanitizada de sesión requerida. Un login fresco durante la suspensión no creó sesión y mostró únicamente el mensaje genérico de credenciales; no reveló la causa del proveedor. La observación directa de Auth confirmó que el usuario y el proveedor Email permanecían presentes, la cuenta estaba bajo ban y la acción administrativa disponible era Unban. No se usó Unban manual.

## 4. Ledger de desactivación

| Campo | Resultado |
| --- | --- |
| `operation_code` | `deactivate` |
| `status` | `succeeded` |
| `completed_stage` | `completed` |
| `attempt_count` | 1 |
| `last_error_code` | `NULL` |
| Solicitante / finalizador | Misma autoridad B.1 exacta |
| Objetivo | Cuenta estudiantil ficticia |
| Referencia de auditoría de perfil / Auth | Presente / Presente |

| Tiempo UTC | Valor |
| --- | --- |
| `requested_at` | `2026-08-06T21:20:02.941854Z` |
| `processing_started_at` | `2026-08-06T21:20:03.149047Z` |
| `auth_synchronized_at` | `2026-08-06T21:20:03.236566Z` |
| `completed_at` | `2026-08-06T21:20:03.236566Z` |
| `updated_at` | `2026-08-06T21:20:03.236566Z` |

Los tiempos fueron monotónicos, los campos finales estuvieron completos y no hubo código de error estable.

## 5. Reactivación

Antes de reactivar, la interfaz mostraba la operación coordinada anterior como completada, sin reintento ni sincronización pendiente. También indicaba que el perfil permanecería inactivo hasta restaurar Auth y validar la finalización SITAA; la asignación y los conteos de dependencias seguían visibles sin cambios.

La reactivación informó éxito. El ban Auth quedó retirado antes de la activación final del perfil; después, el perfil volvió a activo, `deactivated_at` regresó a `NULL` y `activated_at` permaneció intacto. La asignación conservó fila, fechas y bandera activa, y su presentación volvió a vigente.

La historia mostró cuatro eventos append-only totales: perfil desactivado, Auth suspendido, Auth restaurado y perfil reactivado. Los dos eventos nuevos fueron exitosos y usaron la misma razón controlada sanitizada. La observación Auth confirmó el proveedor Email preservado, ausencia del ban y retorno de la acción disponible a Ban user; no se usó Unban manual.

Un login nuevo creó sesión y respetó el `next` existente para volver a `/activities`. En esa ruta volvieron a verse las mismas dos actividades y sus estados de asistencia. La asignación se verificó por separado en el detalle administrativo como preservada y vigente. El usuario ordinario continuó sin Accounts ni controles administrativos. La prueba no afirma que una sesión o refresh token anterior se recupere automáticamente.

## 6. Ledger de reactivación

| Campo | Resultado |
| --- | --- |
| `operation_code` | `reactivate` |
| `status` | `succeeded` |
| `completed_stage` | `completed` |
| `attempt_count` | 1 |
| `last_error_code` | `NULL` |
| Solicitante / finalizador | Misma autoridad B.1 exacta |
| Objetivo | Misma cuenta estudiantil ficticia |
| Referencia de auditoría de perfil / Auth | Presente / Presente |

| Tiempo UTC | Valor |
| --- | --- |
| `requested_at` | `2026-08-06T21:53:53.057464Z` |
| `processing_started_at` | `2026-08-06T21:53:53.224112Z` |
| `auth_synchronized_at` | `2026-08-06T21:53:53.336866Z` |
| `completed_at` | `2026-08-06T21:53:53.393853Z` |
| `updated_at` | `2026-08-06T21:53:53.393853Z` |

El orden aprobado fue `requested_at < processing_started_at < auth_synchronized_at < completed_at = updated_at`. Auth quedó restaurado antes de confirmar la activación final del perfil y no hubo código de error estable.

## 7. Agregado final

| Categoría | Resultado |
| --- | ---: |
| Filas productivas del ledger B.3a | 2 |
| Desactivaciones / reactivaciones | 1 / 1 |
| Filas `succeeded/completed` | 2 |
| Filas no finales / no exitosas | 0 / 0 |
| Intentos totales | 2 |
| Códigos de error estables | 0 |
| Referencias de auditoría de perfil | 2 |
| Referencias de auditoría Auth | 2 |
| Eventos administrativos añadidos al objetivo | 4 |
| Perfil final | Activo |
| Ban Auth final | Ausente |
| Proveedor Auth | Preservado |
| Asignación | Preservada y vigente |
| Actividades y asistencia | Preservadas |
| Controles administrativos ordinarios | Ausentes |

## 8. Sanitización de interfaz

La interfaz no expuso error crudo del proveedor, token, UUID, operation ID, respuesta cruda ni detalle técnico. Los mensajes de login fueron genéricos y no distinguieron entre credenciales incorrectas, cuenta inexistente o cuenta suspendida. El usuario ordinario nunca vio controles administrativos.

## 9. Limitación de telemetría Edge

Durante el recorrido, después de aprobar la desactivación y antes de iniciar la reactivación, se consultó el dashboard Edge. En ese momento todavía mostraba cero invocaciones agregadas y ninguna fila; el propio dashboard advertía que la telemetría podía tardar hasta 24 horas. No se realizó una segunda consulta al finalizar el round trip completo. Por ello, la observación directa de telemetría queda diferida y no se registra como fallo ni como conteo de invocaciones comprobado.

La ejecución queda corroborada por:

- dos filas B.3a finales exitosas;
- `attempt_count = 1` en ambas operaciones;
- referencias de auditoría Auth no nulas;
- ban Auth observado después de desactivar y ausencia del ban después de reactivar;
- eventos exitosos de suspensión y restauración Auth;
- denegación durante la suspensión y login nuevo exitoso después de restaurar;
- ausencia de una ruta heredada 0009 capaz de producir por sí sola esos efectos Auth.

Estas señales independientes acreditan el recorrido sin sobreafirmar una observación directa del contador Edge.

## 10. Estado

- Caso 20: aprobado.
- Smoke tests productivos: aprobados.
- Casos 1–20: aprobados con su atribución correspondiente.
- Snapshot canónico y reconciliación post‑0010: pendientes.
- B.3a: abierta hasta que la reconciliación apruebe.
- Migración 0011: prohibida.
- El proyecto desechable de la matriz debe permanecer disponible hasta el cierre de B.3a.
