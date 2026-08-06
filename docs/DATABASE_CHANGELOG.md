# Historial de cambios de base de datos

Los cambios SQL anteriores a la baseline fueron aplicados manualmente durante el prototipo. Desde la baseline reconciliada, cada cambio se conserva como una migración numerada en el repositorio.

## 0001_baseline_current_schema.sql — baseline reconciliada

- Fecha: 2026-07-16.
- Estado: baseline reconciliada; no se aplicó sobre la base viva porque sus objetos ya existían por el historial manual del prototipo.
- Fuentes: snapshot completo generado con `pg_dump 18.4` y `psql 18.4` en modo de sólo lectura.
- Inventario original: 17 tablas, 151 columnas, 61 restricciones, 37 índices, 4 triggers, 30 funciones, 23 políticas RLS y 51 filas de semillas controladas.
- Alcance: tablas, columnas, restricciones, índices, funciones, triggers, RLS, políticas y catálogos reproducibles.
- Advertencia: no debe ejecutarse a ciegas contra el proyecto vivo.

Esta baseline sustituyó el intento anterior basado en snapshots JSON incompletos. La versión anterior nunca fue una migración administrada.

## Ampliación del snapshot de privilegios — 2026-07-16

- Se añadieron `live_routine_privileges.sql`, `live_table_privileges.sql`, `live_sequence_privileges.sql` y `live_acl.sql`.
- Las fuentes son vistas `information_schema` y ACL expandidas de `pg_proc` y `pg_class`.
- Todas las consultas se ejecutan en transacciones de sólo lectura y los archivos se publican como conjunto atómico.
- La evidencia permitió definir y después verificar los grants mínimos de 0002.

## 0002_database_security_and_integrity.sql — aplicada y verificada

- Fecha de aplicación y verificación: 2026-07-16.
- Propósito: aislar borradores por creador, impedir asistencia pendiente vencida, publicar actividades completas transaccionalmente y reducir privilegios cliente.
- Funciones reemplazadas: helpers de lectura/edición de actividades y RPC individual/masiva de asistencia.
- Objetos nuevos: `publish_activity(uuid)`, `validate_activity_scheduled_state()`, `guard_activity_participant_pending_deadline()` y dos triggers asociados.
- Políticas: lectura de actividades y participantes alineada con privacidad de borradores.
- Privilegios: sin `EXECUTE` de `PUBLIC`/`anon`; `anon` sólo lee `system_health`; `authenticated` no accede directamente a tokens ni a la secuencia.
- Verificación: `supabase/reconciliation/0002_database_security_and_integrity_verify.sql`, completada sin desviaciones.
- Rollback manual: `supabase/reconciliation/0002_database_security_and_integrity_rollback.sql`.
- Plan de pruebas: `docs/TEST_PLAN_0002.md`.
- Smoke tests: aprobados para privacidad de borradores, publicación, bloqueo, participantes, asistencia y check-in QR/código.
- Decisión diferida: no restringe `technical_admin` sobre contenido publicado.

## 0003_fix_draft_temporal_lifecycle.sql — aplicada y verificada

- Fecha de aplicación y verificación: 2026-07-16.
- Propósito: impedir que fecha u hora provisional bloquee un borrador propio.
- Funciones reemplazadas: `activity_has_ended(uuid)`, `can_update_activity_base(uuid)` y `can_delete_activity(uuid)`.
- Datos: no reescribe ni elimina filas.
- Compatibilidad: conserva publicación, privacidad, privilegios y ciclo de contenido publicado definidos por 0002.
- Verificación: `supabase/reconciliation/0003_fix_draft_temporal_lifecycle_verify.sql`; nueve resultados verdaderos y `ROLLBACK` final esperado.
- Rollback manual: `supabase/reconciliation/0003_fix_draft_temporal_lifecycle_rollback.sql`.
- Plan de pruebas: `docs/TEST_PLAN_0003.md`.
- Smoke tests: aprobados para edición/eliminación de borradores incompletos o pasados y rechazo de publicación inválida con retroalimentación por campo.

## Reconciliación posterior a 0003 — 2026-07-16

- Snapshot comparado: `2026-07-17T00:21:06Z`, según `live_snapshot_metadata.txt`.
- Cadena reconciliada: `0001 + 0002 + 0003`.
- Inventario vivo: 17 tablas, 151 columnas, 61 restricciones, 37 índices, 6 triggers, 33 funciones, 23 políticas y 51 semillas controladas.
- Privilegios vivos: 99 grants de rutina, 262 de tabla, 6 de secuencia y 401 entradas ACL expandidas.
- Resultado: sin deriva inexplicada.
- Diferencias ambientales inocuas: fecha del snapshot y valor aleatorio `\restrict` emitido por `pg_dump`.
- Los enlaces QR y de check-in fueron probados manualmente con el dominio canónico de producción.

## Flujo obligatorio para cambios posteriores

`0001`–`0010` están aplicadas e inmutables. `0001`–`0009` están verificadas y reconciliadas. Para `0010`, el verificador PostgreSQL está aprobado e incluye el caso 16; la matriz Hosted Auth central aprobó 1–12, failure/recovery v11 aprobó 13–15, concurrencia/límites v8 aprobó 17–18 y la auditoría productiva de ausencia de secretos aprobó el caso 19. El caso 20 continúa parcial; faltan smoke tests y reconciliación post‑0010. B.3a permanece abierta y no se debe crear `0011`. Todo cambio futuro debe:

1. revisar `0001` y todas las migraciones posteriores;
2. crear una nueva migración numerada, sin reescribir `0001`–`0010`;
3. incluir verificación y rollback cuando sea apropiado;
4. aplicarse manualmente a Supabase;
5. regenerar el snapshot vivo después de cambios significativos;
6. comparar el estado vivo contra la cadena completa;
7. actualizar este changelog.

Los snapshots bajo `supabase/reconciliation/live/` son evidencia de reconciliación, no migraciones ejecutables.

## 0004_identity_registration_foundation.sql — aplicada y verificada

- Fecha de creación: 2026-07-17.
- Propósito: formalizar `institutional|technical`, `student|professor`, estados `pending_registration|active|inactive`, identificadores como texto y registro público Google OAuth.
- Reutiliza las columnas actuales de identidad; añade `account_kind`, `account_status`, `activated_at`, `deactivated_at` e `academic_programs.is_active`.
- Unicidad: par `(institutional_id_type, institutional_id_value)`; se permiten valores iguales entre tipos diferentes.
- Auth: trigger atómico para Google nuevo, sincronización de correo y soporte confiable de cuentas técnicas; signup público por contraseña queda rechazado y nunca se crean roles.
- Registro: Google crea un perfil pendiente; la identidad institucional se captura después de autenticar y se completa con un RPC transaccional exclusivo de `authenticated`. No hay tabla de intents ni escritura anónima.
- Autoservicio: UPDATE directo de `profiles` limitado a `full_name`.
- Preflight: `supabase/reconciliation/0004_identity_registration_preflight.sql`.
- Preflight Google: bloquea huérfanos Auth/profile, límites incompatibles, dependencias de `pending_verification` y triggers no documentados; email/password y OAuth existentes se reportan como informativos.
- Verificación: fixtures Google, proveedores rechazados, finalización autenticada, límites, duplicados, estados, roles y regresiones; termina con `ROLLBACK`.
- Rollback manual: `supabase/reconciliation/0004_identity_registration_rollback.sql`, exige revisión explícita.
- Plan: `docs/TEST_PLAN_0004.md`.
- Aplicación coordinada: aprobar preflight, aplicar 0004, desplegar inmediatamente la aplicación compatible, verificar y regenerar snapshot.
- Estado: aplicada; preflight y verificador transaccional aprobados. La prueba OAuth posterior reveló el contrato prematuro de `email_confirmed_at`, sustituido únicamente en ese punto por 0005, sin rollback de 0004.

## 0005_fix_google_oauth_user_creation.sql — aplicada y verificada

- Fecha de creación: 2026-07-17.
- Estado previo: 0004 ya aplicada; Google Cloud y Supabase configurados.
- Evidencia: Supabase registró SQLSTATE `23514`, `sitaa_google_email_not_verified`, durante el `INSERT` real de `auth.users`. El `25P02` posterior fue consecuencia. La reversión no dejó Auth users, identities, profiles ni enlaces que limpiar.
- Corrección: el trigger Google admite `email_confirmed_at=null` durante el alta temprana y crea sólo el perfil pendiente, inactivo e incompleto.
- Frontera final: `complete_own_google_registration` exige identidad Google enlazada, correo coincidente y verificación final antes de activar.
- Aplicación: las rutas y el server action de registro rechazan cuentas ya autenticadas; el callback incorpora diagnósticos sanitizados por etapa.
- Artefactos: preflight read-only, verificador transaccional, rollback manual y `docs/TEST_PLAN_0005.md`.
- Estado: preflight aprobado, migración aplicada y verificador transaccional aprobado con `ROLLBACK` final de fixtures sintéticos.
- Smoke tests: alta Google real, perfil pendiente, selección de identidad, finalización de profesor y exclusión de cuentas activas de `/register` aprobados.
- Resultado: el defecto temporal de `auth.users.email_confirmed_at` quedó resuelto y no hubo filas Auth fallidas que limpiar.

## Reconciliación posterior a 0005 — 2026-07-17

- Snapshot comparado: `2026-07-17T23:20:07Z`, estado `SUCCESS`.
- Cadena reconciliada: `0001 + 0002 + 0003 + 0004 + 0005`.
- Inventario vivo: 17 tablas, 156 columnas, 68 restricciones, 38 índices, 7 triggers públicos, 37 firmas de función, 23 políticas y 51 semillas controladas.
- Privilegios vivos: 108 grants de rutina, 261 de tabla, 6 de secuencia y 409 entradas ACL expandidas.
- Resultado: sin deriva inexplicada; informe en `supabase/reconciliation/0005_post_apply_reconciliation.md`.
- Datos operativos: se documentó de forma genérica una separación administrativa única entre cuenta técnica y cuenta académica. No se convirtió en migración reutilizable.
- Fase A: cerrada y operativa. Las fases B–F permanecen pendientes.

## 0006_structured_person_names.sql — aplicada y verificada

- Formaliza las columnas preexistentes `first_names`, `paternal_surname` y `maternal_surname` como autoridad del nombre personal.
- Mantiene `full_name` como compatibilidad derivada mediante trigger; no lo elimina ni divide nombres históricos.
- Añade una firma estructurada del RPC de finalización Google, retira `EXECUTE` del overload post-0005 y protege la edición propia mediante grants de columna y trigger.
- El preflight expone sólo categorías y conteos; valida datos, definiciones, triggers y privilegios del contrato post‑0005. La migración repite internamente toda condición bloqueante.
- El verificador transaccional cubre límites de nombres e identificadores, identidad Google, programas, ciclo de cuenta, edición propia, ACL y regresiones 0002–0005; termina con `ROLLBACK`.
- El rollback revoca primero los permisos 0006, restaura el contrato post‑0005 sin borrar columnas ni valores y se autoverifica antes de confirmar.
- Incluye `docs/TEST_PLAN_0006.md`, alineado con los contratos de preflight, verificación y rollback.
- Estado: preflight aprobado, migración confirmada con `COMMIT`, aplicación compatible desplegada, verificador aprobado con código de salida 0 y `ROLLBACK`, y smoke tests de producción aprobados.
- Corrección del arnés: grants temporales y acotados de `SELECT` sobre la tabla de lookup y `EXECUTE` sobre sus dos helpers; desaparecen con la sesión/transacción y no cambian ningún objeto o privilegio persistente.
- Resultado: nombres estructurados operativos; `full_name` permanece como compatibilidad derivada. Reportes y exportaciones CSV/PDF siguen pendientes.

## Reconciliación posterior a 0006 — 2026-07-18

- Snapshot comparado: `2026-07-18T04:05:40Z`, estado `SUCCESS`.
- Cadena reconciliada: `0001 + 0002 + 0003 + 0004 + 0005 + 0006`.
- Inventario vivo: 17 tablas, 156 columnas, 72 restricciones, 38 índices, 8 triggers públicos, 39 firmas de función, 23 políticas y 51 semillas controladas.
- Privilegios vivos: 112 grants de rutina, 261 de tabla, 6 de secuencia y 413 entradas ACL expandidas.
- Resultado: sin deriva inexplicada; informe en `supabase/reconciliation/0006_post_apply_reconciliation.md`.
- Diferencias ambientales: timestamp/formato, omisión semánticamente equivalente de `SECURITY INVOKER` y representación ACL de `MAINTAIN`.
- Diferencias operativas controladas: backfill revisado de nombres y separación administrativa previamente documentada; no se exportaron datos personales.
- Contrato visual: `docs/DESIGN_SYSTEM.md` es obligatorio para toda la aplicación y `npm run check:ui` forma parte de la validación.
- El cierre original dejó `0007` disponible; la Fase B.1 se aplicó posteriormente y su cierre intermedio se documenta en el apartado siguiente.

## 0007_admin_account_directory_audit.sql — aplicada, verificada y reconciliada

- Implementa el directorio administrativo de sólo lectura y `admin_audit_events` append-only.
- Añade autorización exacta B.1, cuatro RPC minimizadas, índices de consulta, RLS sin políticas cliente, ACL explícito `service_role` sólo `SELECT`/`INSERT` y triggers contra `UPDATE`, `DELETE` y `TRUNCATE` del historial.
- La revisión local endureció paginación nula/acotada, búsqueda literal de comodines, metadata sensible normalizada, confirmación Google resumida y recuperación del total en páginas fuera de rango.
- La revisión final hizo determinista el `EXECUTE` de `service_role` sobre el validador de metadata, exige `rolbypassrls=true` y usa fixtures UUID sin colisiones; el verificador cubre funcionalmente ese rol y niega las cuatro RPC a cada actor no autorizado.
- La corrección final incorpora el helper privado `sitaa_current_mexico_date()`: toda vigencia B.1 usa fechas inclusivas de `America/Mexico_City` y deja de depender de la zona horaria de sesión. El verificador cambia deliberadamente la sesión a `Pacific/Kiritimati` para probar el contrato.
- El límite único de metadata queda fijado en 16 384 bytes en migración, verificador, rollback y documentación.
- El cierre local del verificador añadió aserciones exactas de columnas/defaults, PK/FK/CHECK, cuatro índices, dos triggers, ACL de tabla/columna/función, firmas completas de las cuatro RPC y semántica de helpers privados. También eliminó una asignación duplicada de la fixture `admin_inactive`.
- La corrección ACL final revoca explícitamente `PUBLIC`, `anon`, `authenticated` y `service_role` antes de conceder los únicos `EXECUTE` permitidos, añade una guarda post-DDL atómica y alinea verificador y rollback. Ninguna función 0007 depende de privilegios por defecto.
- El cierre de seguridad del rollback fija `READ COMMITTED` y adquiere `ACCESS EXCLUSIVE NOWAIT` antes del guard completo y del control de vacío. Así, la actividad concurrente aborta el intento y ningún `INSERT` de auditoría puede confirmar entre la comprobación y `DROP TABLE`.
- Artefactos coordinados: migración, preflight de sólo lectura, verificador transaccional con `ROLLBACK`, rollback manual protegido y `docs/TEST_PLAN_0007.md`.
- No modifica 0001–0006.
- Estado de aplicación: preflight aprobado, migración confirmada con `COMMIT` y aplicación compatible publicada.
- Primera verificación: falló antes de crear fixtures porque el arnés recortaba `p.prosrc` antes de colapsar espacios. Un diagnóstico de sólo lectura confirmó la definición y los ACL correctos de los objetos persistentes.
- Corrección del arnés: la comparación usa `btrim(regexp_replace(lower(p.prosrc), '\s+', ' ', 'g'))`, incluye una regresión sintética y separa los errores de definición y ACL por helper. La migración aplicada permanece inmutable.
- Verificación final: el verificador corregido terminó correctamente con `ROLLBACK`; no persistieron fixtures ni grants temporales.
- Smoke tests: el administrador técnico exacto accede; profesor y alumno ordinarios no acceden; búsqueda, filtros, lista, detalle, asignaciones V1 e historial sanitizado funcionan sin controles de mutación.
- Snapshot: conjunto completo generado en `2026-07-21T00:16:03Z`, estado `SUCCESS`, con `pg_dump 18.4`, `psql 18.4`, UTF-8 y cuatro artefactos de privilegios.
- Reconciliación: `0001`–`0007` no presenta deriva inexplicada; informe en `supabase/reconciliation/0007_post_apply_reconciliation.md`.
- Resultado en ese cierre: Fase B.1 cerrada y operativa; 0007 quedó inmutable y 0008 quedó disponible para la fase posterior, ya cerrada en el apartado de reconciliación post-0008.

## Reconciliación posterior a 0007 — 2026-07-20

- Inventario vivo: 18 tablas, 165 columnas, 80 restricciones, 43 índices, 10 triggers públicos, 47 firmas de función, 23 políticas y 51 semillas controladas.
- Privilegios vivos: 125 grants de rutina, 270 grants de tabla publicados por `information_schema`, 6 de secuencia y 436 entradas ACL expandidas.
- Delta post-0006: +1 tabla, +9 columnas, +8 restricciones, +5 índices, +2 triggers, +8 funciones, +13 grants de rutina, +9 grants de tabla publicados y +23 entradas ACL.
- Representación: `MAINTAIN` aparece en ACL expandida, pero no en `information_schema.table_privileges`; por ello el delta publicado de tabla es +9 aunque la ACL confirma diez entradas nuevas de tabla.
- Diferencias ambientales: timestamp, token aleatorio `\restrict`, omisión textual opcional de `SECURITY INVOKER` y formato de `pg_dump`/`psql`.
- Resultado: sin deriva inexplicada; políticas, secuencias, catálogos y objetos post-0006 no modificados por 0007 permanecen intactos.

## 0008_operational_account_barrier_identity_correction.sql — aplicada, verificada y reconciliada

- Fase B.2a fue preparada y aplicada sobre el snapshot post-0007 `2026-07-21T00:16:03Z`; el snapshot post-0008 `2026-07-22T01:46:13Z` es ahora la evidencia viva reconciliada.
- Añade un helper privado de cuenta operativa activa, dos políticas RLS restrictivas, guardas explícitas en 29 rutinas operativas y dos RPC de corrección administrativa.
- No añade tablas, columnas, índices, restricciones ni semillas. Añade un trigger público y cuatro firmas de función; retira a `authenticated` los grants directos `INSERT`, `UPDATE` y `DELETE` de `activity_participants`.
- Inventario vivo confirmado: 18 tablas, 165 columnas, 80 restricciones, 43 índices, 11 triggers públicos, 51 firmas de función, 25 políticas y 51 semillas.
- Privilegios vivos confirmados: 132 grants de rutina, 267 grants de tabla publicados por `information_schema`, 6 de secuencia y 440 entradas ACL expandidas. El delta post-0007 es +7 de rutina, −3 de tabla y +4 ACL netas: tres RPC/helper nuevas tienen owner + `authenticated`, el trigger nuevo es owner-only y el DML directo de participantes queda cerrado.
- Artefactos coordinados: migración ahora inmutable, preflight de sólo lectura, verificador transaccional, rollback conservador y `docs/TEST_PLAN_0008.md`.
- Revisión final local: identificadores y actividades fixture libres de colisiones/lookups nominales; denegaciones esperadas verificadas por SQLSTATE y mensaje; DML cliente de participantes retirado; trigger de integridad para writers de actividades y transición histórica; guard predestructivo del rollback ampliado al contrato completo y hashes exactos de las cuatro funciones nuevas.
- Revisión previa a aplicación: fixture de semestre independiente del calendario, normalización whitespace y límites controlados, locks de dependencias en orden fijo, preflight RLS/Auth/FK/ACL completo, firmas PostgREST y ACL de funciones exactos, y rollback alineado al hash normalizado de `prosrc`.
- Las dependencias se consideran abiertas sólo si la actividad es borrador o todavía no terminó según fecha/hora de Ciudad de México; las incompatibilidades históricas terminadas no bloquean el preflight y una escritura cliente no puede reabrirlas silenciosamente.
- Cierre final de autorización: el preflight bloquea `attacl`, filas de columna no explicadas o privilegios efectivos superiores al ACL de tabla sobre `activity_participants`; el estado post-DDL exige owner y `service_role` completos, `authenticated` sólo `SELECT` de tabla y cero ACL explícito de columna. Las filas table-derived de `information_schema.column_privileges` permanecen y se comparan exactamente con `SELECT`/`INSERT`/`UPDATE`/`REFERENCES` del ACL de tabla. El verificador incorpora una regresión temporal de grant por columna y el rollback comprueba el contrato antes de destruir y después de restaurar.
- La corrección administrativa captura al actor una vez, conserva la autorización inicial y repite la autoridad B.1 después de locks de dependencias y de un lock conjunto actor/objetivo ordenado por UUID. El hash normalizado actualizado del cuerpo es `ce05cbc529473c070953e765e3ee05b2`; las pruebas manuales de concurrencia permanecen pendientes.
- Las cuatro pruebas de autoridad en dos sesiones sólo podrán ejecutarse en una base local, rama Supabase o clon desechable que se descarte/restaure por completo. No se propone borrar eventos `account_identity_corrected`, deshabilitar triggers append-only, retirar FK ni eliminar actores/objetivos referenciados para limpiar producción.
- Primer preflight remoto: ejecución de sólo lectura con `ROLLBACK` y código 0; todas las categorías bloqueantes fueron cero salvo `registration_trigger_drift = 1`. Fue un falso positivo causado por dos nombres locales incorrectos, no deriva del esquema vivo. Los conteos informativos fueron dos dependencias potenciales y una responsabilidad abierta; no autorizaron aplicación.
- Primera corrección previa a aplicación: preflight independiente, preflight embebido, guarda post-DDL y verificador pasaron a exigir por catálogo los triggers canónicos `on_sitaa_auth_user_created` y `on_sitaa_auth_user_email_changed`, incluidas unicidad, relación, evento, timing, columnas, predicado, habilitación y función por OID. 0008 no modifica esos triggers; esta versión se evaluó en el segundo intento.
- Segundo preflight remoto: la transacción de sólo lectura abortó antes de devolver categorías con `expression contains variables of more than one relation`; `ON_ERROR_STOP=1` cerró la ejecución y no persistió cambios. La causa fue `pg_get_expr(tgqual, tgrelid, ...)` sobre un `WHEN` que referencia `OLD` y `NEW`, no deriva viva. Los cuatro sitios del arnés pasaron a usar `pg_get_triggerdef(oid, false)`; esa versión se evaluó en el tercer intento.
- Tercer preflight remoto: devolvió las 40 categorías y terminó con `ROLLBACK`; todos los bloqueos fueron cero salvo `registration_trigger_drift = 1`. El diagnóstico canónico confirmó conteos 1/1 para ambos nombres y pares handler/trigger, y cero handlers inesperados. El falso positivo restante fue el cast `::text` añadido por el deparser. Los cuatro controles aíslan ahora `WHEN`, eliminan exclusivamente `::text` y comparan por igualdad; el verificador añade cinco casos sintéticos.
- Preflight aprobado: la reejecución corregida devolvió las 40 categorías, con sus 35 bloqueos en cero, y terminó con `ROLLBACK`; los conteos informativos permanecieron no bloqueantes.
- Aplicación: la versión compatible B.2a fue publicada y 0008 terminó con `COMMIT`. La migración está aplicada y es inmutable.
- Primera ejecución del verificador: superó los controles estáticos y avanzó hasta las fixtures, pero abortó al invocar directamente `is_b1_account_admin()` bajo `authenticated`. El helper es owner-only y PostgreSQL denegó correctamente `EXECUTE` con SQLSTATE `42501`; la transacción abortada se descartó y no persistieron fixtures, grants temporales, eventos de auditoría ni cambios operativos.
- Segunda ejecución del verificador: aprobó la regresión del helper privado, los contratos estructurales, las fixtures, los rechazos controlados y siete correcciones de identidad por RPC. Abortó después con `0008_verify_institutional_correction_failed` porque las lecturas crudas de perfiles ajenos, auditoría y frontera histórica aún se ejecutaban bajo `authenticated`; RLS/ACL ocultaron correctamente esas superficies. La transacción se descartó sin persistir fixtures, correcciones, grants ni eventos.
- Segunda corrección local del verificador: conserva RPC y DML cliente bajo `authenticated`, valida allí la proyección B.1 sanitizada, restablece el rol antes de inspeccionar perfiles/auditoría crudos y divide la reapertura histórica en precondiciones owner, intento cliente y atomicidad owner. Añade diagnósticos focalizados y una auditoría estática de límites de rol; la reejecución posterior aprobó.
- Verificación final: el verificador con límites owner/cliente corregidos aprobó y terminó con `ROLLBACK`; no persistieron fixtures, correcciones, grants temporales ni auditoría sintética.
- Smoke test B.2a: la corrección de identidad y el evento append-only sanitizado aprobaron. El escenario de responsabilidad histórica entre programas expuso una compuerta de aplicación que recalculaba el programa actual, aunque `can_edit_activity(uuid)` autorizaba correctamente al creador/responsable. La interfaz y las acciones pasaron a consumir la RPC autoritativa; la reejecución aprobó sin ampliar RLS ni ACL.
- 0001–0008 son migraciones aplicadas e inmutables. 0009 es el siguiente número disponible. Durante la reconciliación local no se conectó a Supabase ni se ejecutó SQL.

## Reconciliación posterior a 0008 — 2026-07-21

- Snapshot comparado: `2026-07-22T01:46:13Z`, estado `SUCCESS`, generado con `pg_dump 18.4`, `psql 18.4` y UTF-8.
- Cadena reconciliada: `0001 + 0002 + 0003 + 0004 + 0005 + 0006 + 0007 + 0008`.
- Inventario vivo: 18 tablas, 165 columnas, 80 restricciones, 43 índices, 11 triggers públicos, 51 firmas de función, 25 políticas, RLS en 18 tablas y 51 semillas controladas.
- Privilegios vivos: 132 grants de rutina, 267 grants de tabla publicados por `information_schema`, 6 de secuencia y 440 entradas ACL expandidas.
- Delta post-0007: 0 tablas, 0 columnas, 0 restricciones, 0 índices, +1 trigger, +4 firmas, +2 políticas, 0 semillas, +7 grants de rutina, −3 de tabla, 0 de secuencia y +4 entradas ACL.
- Resultado: sin deriva inexplicada; informe en `supabase/reconciliation/0008_post_apply_reconciliation.md`.
- Cierre: 0008 queda aplicada, verificada, probada, reconciliada e inmutable; Fase B.2a queda cerrada dentro de su alcance aprobado y 0009 es el siguiente número disponible.

## 0009_admin_account_lifecycle_transitions.sql — aplicada, verificada y reconciliada

- Se preparó `0009_admin_account_lifecycle_transitions.sql` con tres funciones: autoridad B.1 exacta por perfil, contexto de elegibilidad sin PII y transición auditada de desactivación/reactivación.
- El delta previsto es 0 tablas, 0 columnas, 0 restricciones, 0 índices, 0 triggers, +3 funciones, 0 políticas, 0 semillas, +5 grants de rutina, 0 grants de tabla/secuencia y +5 ACL expandidas.
- Se añadieron preflight de sólo lectura, verificador transaccional, rollback protegido y `TEST_PLAN_0009.md`. Las pruebas reales de dos sesiones quedan reservadas a un entorno desechable.
- La revisión final separó estrictamente fases cliente/owner del verificador, hizo relativos a la línea base viva los conteos de administradores, incorporó un allocator temporal sin colisiones y añadió el lock `FOR SHARE` del programa institucional durante reactivación.
- Las seis superficies de contrato verifican exactamente 51 semillas controladas (cardinales por catálogo y hash canónico), y los diagnósticos informativos de dependencias usan la frontera temporal pura 0008.
- El primer preflight remoto fue de sólo lectura, devolvió 26 filas, terminó con `ROLLBACK` y no fue aprobado por cuatro categorías no nulas. Un diagnóstico también de sólo lectura confirmó que no había deriva sustantiva post-0008 y terminó con `ROLLBACK`.
- Se corrigió el arnés local para usar la representación pretty canónica de restricciones y del mapa público de triggers, las seis ACL exactas de secuencia mediante `pg_class`/`aclexplode`, el mapa post-0008 de diecinueve grants de tabla `authenticated` y la definición pretty exacta de `admin_audit_events_action_code_check`. El parser especializado Auth conserva el modo no pretty controlado.
- La reejecución corregida del preflight devolvió 26 filas, dejó las 19 categorías bloqueantes en cero, terminó con `ROLLBACK` y fue aprobada. La aplicación compatible B.2b se desplegó antes del intento de migración.
- El primer intento de migración falló al compilar el `DO $preflight$` embebido porque la rama del helper B.1 privado no cerraba su `EXISTS` exterior antes del siguiente `UNION ALL`. Sólo se alcanzaron `BEGIN` y los dos `SET LOCAL`; no hubo DDL, objetos 0009, grants, guarda post-DDL ni `COMMIT`. La transacción se descartó y no se ejecutó rollback.
- Después de corregir la sintaxis, el segundo intento entró al preflight embebido y falló al capturar el hash pre-DDL de `pg_default_acl`: `defaclobjtype` tiene tipo interno `pg_catalog."char"` y se concatenaba sin `::text`. Sólo alcanzó `BEGIN`, los dos `SET LOCAL` y el preflight; no hubo DDL, objetos 0009, `REVOKE`, `GRANT`, guarda post-DDL ni `COMMIT`. La transacción no confirmada se descartó y no se ejecutó rollback.
- El tercer intento aprobó el preflight embebido, creó las tres funciones, normalizó ACL, aprobó la guarda atómica post-DDL y terminó con `COMMIT`; 0009 quedó aplicada e inmutable.
- El verificador final completó contratos, fixtures y aserciones y terminó con `ROLLBACK`; no persistió fixture, grant, transición, estado o evento sintético.
- Los smoke tests aprobaron autoridad exacta, desactivación/reactivación institucional, barrera operativa sobre sesión existente, preservación de identidad/historia, auditoría minimizada y denegaciones. La matriz manual multisesión no fue ejecutada y permanece limitada a un entorno desechable.
- Snapshot post-0009: `2026-07-22T23:32:46Z`, estado `SUCCESS`, 18/165/80/43/11/54/25/18/51 y privilegios 137/267/6/445. El delta es +3 funciones, +5 grants de rutina y +5 ACL; no existe deriva inexplicada.
- Cierre: 0001–0009 son inmutables, B.2b está cerrada, `0010` es el siguiente número disponible y B.3/Fase C permanecen pendientes.

## 0010_coordinated_auth_session_suspension.sql — aplicada; verificador aprobado

- Fecha de preparación: 2026-07-22.
- Añade `admin_auth_operations`, su estado controlado, cinco RPC B.3a y un trigger owner-only; no modifica cuerpos 0001–0009.
- Retira únicamente el futuro `EXECUTE` directo de `authenticated` sobre `transition_admin_account_lifecycle_b2b(uuid,text,text)`; el contexto 0009 permanece disponible.
- Incluye preflight de sólo lectura, verificador transaccional sin Auth Admin, rollback protegido, Edge Function autenticada, adaptador Auth aislado y `TEST_PLAN_0010.md`.
- La aplicación mantiene un fallback 0009 temporal únicamente cuando la ausencia del contrato B.3a se confirma explícitamente; después de 0010, cualquier fallo del límite confiable falla cerrado.
- En la fase de preparación todavía no se había comprobado contra Supabase hospedado el valor tipado `ban_duration = 'none'`. Se ejecutaron dos preflight de sólo lectura y el diagnóstico acotado.
- Hardening local previo a aplicación: se alineó el error de objetivo pendiente con `sitaa_account_lifecycle_pending_target`/`P0001`; writer GUC nulo-seguro y limpiado; DML por writer con allowlist exacta; lookup de `request_id` posterior al advisory lock; selección de operación actual sin descartar éxitos; recuperación inmediata de `auth_synchronized`; validación total de resultados y parsers Edge estrictos.
- La evidencia Auth usa al ejecutor real del intento. El adaptador provisional no emite `terminal_failure` para 400/401/403/404/422 ni errores desconocidos; toda persistencia de resultado se valida antes de responder. El rollback bloquea ledger y auditoría con `ACCESS EXCLUSIVE NOWAIT` antes de la guarda completa.
- La segunda revisión llegó con un paquete desactualizado respecto del árbol canónico: hashes anteriores, rollback sin lock de auditoría, adaptador terminal y aplicación B.2b. La captura previa confirmó que esos defectos ya no estaban en el repositorio; no se ejecutó preflight ni SQL.
- Antes de aplicar 0010 se añadió la firma de resultado de cinco argumentos con `claimed_attempt_count`, rechazo estable `sitaa_auth_operation_stale_attempt`, tiempos de pared posteriores a locks e inmutabilidad estricta de UUID/timestamps de evidencia. El verificador sintético cubre intento tardío sin mutación, reemplazo de evidencia, terminal posterior a sync y continuación válida.
- El preflight independiente amplía la línea base con hashes nominales derivados del snapshot post‑0009 ya versionado: metadata de 54 funciones, 137 ACL de función, 302 ACL de tabla/vista, 6 ACL de secuencia y los tres grants explícitos de columna de nombres. `pg_default_acl` conserva la frontera aprobada: detección acotada de defaults relevantes no mitigados y captura transaccional completa para comprobar que el DDL no lo modifica.
- Corrección final previa a aplicación: `request_id` se declara con la restricción e índice únicos `admin_auth_operations_request_id_key`, verificados por `conindid` y forma exacta de `pg_index`; desaparece el acoplamiento con un índice de nombre distinto. La RPC de preparación rechaza de forma total `NULL`, vacío, desconocidos y mayúsculas sin mutación. El preflight embebido replica toda categoría y hash bloqueante independiente antes de capturar el baseline, y el rollback exige los mapas canónicos completos de metadata y ACL tanto antes de destruir como después de restaurar.
- Corrección de revisión sin ejecución: se retiraron de los intervalos `authenticated`/`service_role` todas las postcondiciones crudas; los roles cliente conservan sólo RPC aprobadas, superficies temporales sanitizadas y dos denegaciones ACL exactas, mientras owner ejecuta las comprobaciones y mutaciones de trigger. El rollback usa el baseline ACL predestructivo dividido de 135 entradas (`5c2ce865124e0669c787d12fe4c46b59`), mutador 0009 owner-only y seis funciones 0010; el mapa completo de 137 entradas se reserva al estado post-rollback. La aplicación conserva resultados Edge estables 403/409 mediante `FunctionsHttpError` y falla cerrada para errores de transporte o cuerpos inválidos, sin activar el fallback 0009.
- Totales post‑0010 previstos y exigidos localmente: 19 tablas, 183 columnas, 96 restricciones, 48 índices, 13 triggers públicos no internos, 60 funciones, 25 políticas, 19 tablas con RLS, 51 semillas, 147 grants de rutina, 274 grants de tabla PostgreSQL 18, 6 grants de secuencia y 463 entradas ACL expandidas.
- El snapshot vivo continúa siendo post‑0009 (`2026-07-22T23:32:46Z`); no se regeneró ni se editó.
- Hardening final local, aún sin ejecución: se corrigieron cinco serializaciones de campos internos `char` de catálogos PostgreSQL con `::text` explícito (`provolatile` en dos hashes y `tgenabled` en migración, verificador y rollback). Claim, persistencia de resultado y finalización repiten la autoridad B.1 después del advisory lock y del row lock, antes de cualquier replay, lectura de estado o mutación.
- La frontera Edge conserva `42501/sitaa_admin_access_denied` como `authorization_lost/pending` con UUID cuando la operación ya existe. El parser aplica una matriz discriminada exacta de código/estado/UUID y la acción exige que el código final coincida con la transición solicitada.
- Primera evidencia remota 0010: el preflight de sólo lectura devolvió 34 filas; 29 de 30 categorías bloqueantes fueron cero y `dangerous_default_acl` devolvió 50. Terminó con `ROLLBACK` y código 0, no cambió objetos o datos y no fue aprobado.
- Diagnóstico de default ACL: también terminó con `ROLLBACK` y código 0; confirmó `current_user = postgres`, `session_user = postgres` y cinco grupos de diez filas (`postgres/public`, `postgres/storage`, `supabase_admin/graphql`, `supabase_admin/graphql_public`, `supabase_admin/public`). El predicado anterior mezclaba propietarios/esquemas ajenos y defaults de secuencia.
- Corrección del preflight: `dangerous_default_acl` sólo considera defaults de `postgres`, globales o de `public`, para tablas/funciones, y bloquea grantees fuera de `PUBLIC`, `anon`, `authenticated`, `service_role` y el owner. No se ejecutó `ALTER DEFAULT PRIVILEGES`; la normalización ACL de tabla/funciones y el hash completo de `pg_default_acl` permanecen obligatorios.
- Segunda evidencia remota 0010 aprobada: el preflight corregido devolvió exactamente 34 filas, dejó sus 30 categorías bloqueantes en cero y produjo `dangerous_default_acl = 0`. Los cuatro conteos informativos fueron `active_exact_b1_administrators = 1`, `existing_b2b_lifecycle_events = 4`, `inactive_accounts = 0` e `inactive_accounts_with_active_or_future_assignments = 0`. Terminó con `ROLLBACK`, código 0 y sin `ERROR`; no expuso UUID, filas operativas, PII, credenciales, tokens o secretos y no cambió objetos, filas o privilegios.
- Antes de la matriz central, la aplicación compatible se había desplegado correctamente, la Edge Function figuraba `ACTIVE` y aún no había sido invocada. 0010 ya se había aplicado y su registro local terminaba en `COMMIT`; en ese momento no se había ejecutado Auth Admin ni una operación real B.3a.
- El primer verificador hospedado terminó con código de salida 3 en `restore_failure_finalize`: el contrato real emitió `42501/sitaa_account_lifecycle_auth_unconfirmed`, pero el arnés usó `exception when raise_exception`, que sólo captura `P0001`. No alcanzó el `ROLLBACK` final y la desconexión de `psql` descartó la transacción abierta; el fallo corresponde al arnés, no a la migración aplicada.
- Corrección posterior sin ejecución remota: `restore_failure_finalize` captura `insufficient_privilege` y exige SQLSTATE `42501` y mensaje estable exactos. El checker añade fixture negativa del handler anterior, fixture positiva del corregido y auditoría de los contratos `P0001`, `42501`, `22023`, `23505`, `23514` y `55000`.
- Diagnóstico posterior al aborto: `ledger_exists = true`, seis funciones B.3a, cero filas del ledger y cero eventos de auditoría Auth B.3a; terminó con `ROLLBACK` y código 0. Confirmó que 0010 siguió aplicada y que ningún fixture, operación o evento sobrevivió.
- Verificador corregido aprobado: completó todos los escenarios con el handler exacto `insufficient_privilege/42501`, imprimió exactamente un `ROLLBACK` final, terminó con código 0 y no produjo líneas `ERROR`. No persistió fixtures, privilegios temporales, operaciones ni auditoría.
- Estado al cerrar el verificador: el gate PostgreSQL estaba aprobado y todavía no se había ejecutado suspensión/restauración real ni Auth Admin. La matriz Hosted Auth central posterior se documenta a continuación; B.3a permanece abierta por los casos restantes, smoke tests y reconciliación post‑0010.

## Matriz Hosted Auth central de 0010 — 2026-08-03

- Se ejecutó una sola vez en un proyecto Supabase desechable, no en producción, con el arnés `2026-08-03-hosted-auth-core-v4`, Node.js `v24.18.0` y Supabase JS `2.110.1`.
- La evidencia central local tiene 2008 bytes y SHA-256 `55315c6e4b9c34278d920f231bac48c7349a1f9da3b0d3d7e2516c90e2ea7cac`; el postcheck local tiene 333 bytes y SHA-256 `29c38e45dd6b8b5ae3aec4dd57380aef46c1ed198e89be03b1a45477ed49a389`.
- La baseline aprobó dos sesiones independientes, login, `getUser`, refresh y RPC base, con cero operaciones B.3a antes de la confirmación irreversible.
- La suspensión se completó: el ban quedó activo y ambas sesiones, sus refresh tokens y dos logins nuevos fueron rechazados con `user_banned`; las operaciones protegidas de SITAA intentadas con los dos tokens quedaron denegadas (`2/2`).
- La restauración se completó: el ban se eliminó y un login fresco fue aprobado; los refresh tokens anteriores continuaron rechazados. Esta semántica es evidencia empírica de la ejecución concreta y no una garantía futura del proveedor.
- Se preservaron identidad Auth, `activated_at`, asignaciones e historia operativa. El postcheck registró dos operaciones completadas, cuatro eventos esperados, cero operaciones no exitosas, cero eventos Auth de fallo, perfil activo, dos usuarios, dos identidades, contrato de identidad válido y autoridad B.1 `2/2`; terminó en transacción de sólo lectura con `ROLLBACK`.
- La evidencia, la salida del arnés y la auditoría fueron revisadas sin correos, UUID, tokens, claves, contraseñas, URI, cookies, cabeceras `Authorization`, metadata sensible ni errores crudos. El resumen versionado está en `supabase/reconciliation/0010_hosted_auth_core_evidence.md`; los dos `*.local.txt` continúan ignorados por Git.
- La primera operación real revocó definitivamente la elegibilidad del rollback 0010.
- B.3a sigue abierta: faltan fallos inyectados, fallo de finalización, recuperación por otro administrador, usuarios ordinarios y `service_role` en el límite hospedado, cierre de ausencia de secretos, timeout, concurrencia, conflictos/replays de `request_id`, pérdida de autoridad tras locks, smoke tests y reconciliación post‑0010.

## Matriz Hosted Auth failure/recovery de 0010 — 2026-08-05 UTC

- Se ejecutó una sola vez en un proyecto Supabase desechable, nunca en producción, con el arnés `2026-08-04-hosted-auth-failure-recovery-v11`, bootstrap Target C v7, Node.js `v24.18.0` y Supabase JS `2.110.1`.
- La evidencia principal local tiene 2167 bytes y SHA-256 `cf5653456e1ce1fca8b106bb4fb492f276f1f758eff10a3a643f88b13c743c8c`; el postcheck local tiene 542 bytes y SHA-256 `3404ddcd6f9c028a28f9db21a38d2dfb70c60f0c94fb9f38277ff55ca6e0e1c7`.
- Caso 13 aprobado: el fallo Auth controlado `auth_temporarily_unavailable` dejó la operación en `retryable_failure/profile_suspended`; el reintento completó la misma operación con un solo evento de perfil, cero eventos Auth de fallo, un nuevo evento Auth de éxito y replays idempotentes sin repetir Auth.
- Caso 14 aprobado: una reactivación sincronizó Auth una sola vez; la fixture temporal de confirmación provocó `auth_unconfirmed` en el segundo intento de finalización y conservó `processing/auth_synchronized`; la recuperación posterior no repitió Auth.
- Caso 15 aprobado: Admin B recuperó la operación iniciada por Admin A; solicitante y finalizador permanecieron diferenciados, `AUTH_CALLS_FOR_REACTIVATION=1`, no se repitió Auth, y se preservaron `activated_at` e identidad Auth.
- Aprobaron los contratos de replay con el mismo payload, conflicto con payload distinto, objetivo con operación no final, idempotencia de retry y replays `start`/`retry` de una operación completada.
- Postcheck exacto: 3 usuarios Auth, 3 identidades, 3 perfiles, 2 asignaciones, autoridad B.1 `2/2`, Target C activo/sin ban/sin asignaciones, 4 operaciones B.3a completadas, 0 no finales, 0 no exitosas, 8 eventos administrativos esperados, 0 eventos Auth de fallo y 2 nuevos eventos Auth de éxito; correo confirmado, handler canónico, `READ ONLY`, `ROLLBACK` y matriz aprobados.
- El archivo de reparación de confirmación quedó ausente. Las dos evidencias `*.local.txt` permanecen ignoradas por Git; el resumen versionado y sanitizado está en `supabase/reconciliation/0010_hosted_auth_failure_recovery_evidence.md`.
- Los códigos observados pertenecen a inyecciones controladas y no generalizan errores reales o futuros de Supabase. `terminal_failure` continúa limitado al modelo SQL sintético/transaccional.
- En el cierre de la matriz failure/recovery, B.3a permanecía abierta: 17–18, concurrencia multisesión, espera real por locks, leases y límites hospedados todavía estaban pendientes; 19–20 eran parciales y también faltaban smoke tests y reconciliación post‑0010. El caso 16 conservaba su atribución al verificador PostgreSQL. La matriz v8 posterior actualiza este estado sin reescribir aquel historial.

## Matriz Hosted Auth de concurrencia y límites de 0010 — 2026-08-06 UTC

- La ejecución v7 había aprobado los límites hospedados de los casos 17–18 y se detuvo durante el primer escenario concurrente con `advisory_observer_timeout`. Su evidencia de 601 bytes y SHA-256 `b022d7c1dcb1eb7278d0c7b6d87e8917d2a409d74405d5a5400906441f899755` permanece preservada como predecesora rechazada; no existe postcheck v7.
- Un diagnóstico de sólo lectura encontró cuatro campos de texto administrados por el proveedor en SQL `NULL` dentro de la Authority D sintética y desechable: `confirmation_token`, `email_change`, `email_change_token_new` y `recovery_token`.
- El primer transporte de reparación fue rechazado por `psql` debido a la codificación del transporte Windows PowerShell antes de aceptar cualquier escritura. Un segundo intento usó un archivo SQL UTF-8 sin BOM y una transacción acotada para normalizar exclusivamente esos cuatro campos a cadena vacía en esa única fila sintética.
- El postcheck de la normalización aprobó cuatro `NULL` y cero cadenas vacías antes, y cero `NULL` y cuatro cadenas vacías después. Los demás agregados Auth, perfiles, asignaciones, operaciones, auditoría, triggers, evidencia predecesora, runtime y Git permanecieron iguales. Fue limpieza de fixture desechable, no migración SITAA, cambio de esquema, cambio de aplicación/Edge, reparación de producción ni recomendación general sobre datos Auth administrados por Supabase.
- Un probe Auth Admin posterior y de sólo lectura aprobó cuatro usuarios Auth únicos: Admin A, Admin B y Target C con detalle e identidad de correo, y Authority D validada por separado sin identidades; no alteró evidencia, runtime o Git.
- La matriz reanudada v8 aprobó los casos 17–18, idempotencia y conflicto de `request_id`, serialización por objetivo, siete observaciones obligatorias de espera por advisory lock, tiempos posteriores al lock, monotonicidad, orden de operación, lease fresco y recuperación a cinco minutos, cercado de intentos, pérdida de autoridad fail-closed y recuperación sincronizada por otra autoridad exacta sin repetir Auth.
- Evidencia v8 final: `b3a_matrix_hosted_auth_concurrency_boundaries_v8.local.txt`, 1797 bytes, SHA-256 `c150a18ac429f206735f38569ae43c69f62cba35ceeb02f6e683e440b065f829`.
- Postcheck v8 final: `b3a_matrix_hosted_auth_concurrency_boundaries_v8_postcheck.local.txt`, 595 bytes, SHA-256 `567e9d9c1f23a18780dbb281ec00ba77f7f69f9bc97f9edc0aad9260a7acd507`. El artefacto v8 de fallo está ausente; no sobrevivieron `.next` ni directorios runtime.
- Postcheck agregado: 4 usuarios Auth, 3 identidades, 4 perfiles, 3 asignaciones, autoridad B.1 `2/2`, Target C activo/sin ban/sin asignaciones, 6 operaciones completadas, 0 no finales o no exitosas, 12 eventos administrativos, 0 eventos Auth de fallo, 6 eventos Auth de éxito, Authority D inactiva, 0 leases y 0 workers; handler canónico, transacción de sólo lectura, `ROLLBACK` y postcheck aprobados.
- El resumen sanitizado versionado está en `supabase/reconciliation/0010_hosted_auth_concurrency_boundaries_evidence.md`. Las fuentes locales v7/v8 continúan ignoradas por Git y no sustituyen el snapshot vivo.
- Estado posterior: casos 1–12 aprobados por la matriz central, 13–15 por failure/recovery v11, 16 por el verificador PostgreSQL y 17–18 por concurrencia/límites v8; 19–20 parciales; smoke tests y snapshot/reconciliación post‑0010 pendientes. B.3a permanece abierta, el rollback 0010 continúa revocado y todavía no debe crearse 0011.

## Auditoría productiva de ausencia de secretos de 0010 — 2026-08-06 UTC

- Se auditó exactamente el commit `5df156ec0616da8823f6f13be41c2df11ea85537` mediante la versión `2026-08-06-case19-v1`.
- La revisión del operador en Vercel confirmó `NEXT_PUBLIC_SITE_URL` en Production, `NEXT_PUBLIC_SUPABASE_ANON_KEY` y `NEXT_PUBLIC_SUPABASE_URL` en Production y Preview, cero variables compartidas y cero nombres visibles de credenciales privilegiadas o de base de datos. Los valores no se revelaron ni copiaron.
- En Production, con Preview excluido y ventana de última hora, se observaron 7 solicitudes HTTP 200: 3 `GET /` y 4 `GET /register`. Hubo cero warnings, errores y fatales; Messages estaba vacío y no se observó información sensible.
- La auditoría automatizada aprobó 22 recursos de navegador locales (958637 bytes), 532 artefactos de servidor (31959047 bytes), 14 respuestas de rutas remotas (199327 bytes), 12 recursos estáticos remotos (702568 bytes) y 11 recursos JavaScript remotos.
- Los clasificadores devolvieron cero JWT privilegiados, cero secretos prohibidos y cero clientes privilegiados de primera parte. Las 280 apariciones de `service_role` y 8 de `SUPABASE_SECRET_KEY` en source maps de servidor pertenecían a dependencias, no tenían valores asociados y no aparecieron en código de primera parte, JavaScript de navegador ni recursos remotos; no constituyeron filtraciones.
- El primer `npm run build` fue bloqueado por el sandbox de Codex al escribir `.next/trace-build`; fue una restricción del entorno, no un fallo del proyecto. La repetición autorizada terminó con código 0, aprobó Next.js, TypeScript y los checkers integrados, preservó `.next/static` y dejó cero cambios tracked o staged, con `package.json` y `package-lock.json` intactos.
- `npm run check:auth-lifecycle` devolvió `Límite confiable Auth B.3a: OK`, `npm run check:text` devolvió `Integridad de texto: OK` y `git diff --check` terminó con salida vacía. El runtime temporal y los recursos descargados quedaron ausentes; no hubo mutación remota, autenticación, operación Supabase, commit ni push.
- El resumen sanitizado versionado está en `supabase/reconciliation/0010_production_secret_audit_evidence.md`. Las capturas, valores de variables, recursos descargados y salidas temporales no se versionan.
- El caso 19 quedó aprobado. El caso 20, los smoke tests de la interfaz desplegada y el snapshot/reconciliación post‑0010 siguen pendientes. B.3a permanece abierta, el proyecto desechable de la matriz debe conservarse hasta su cierre y no debe crearse 0011.
