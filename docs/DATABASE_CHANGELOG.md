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

`0001`–`0007` están aplicadas, verificadas y reconciliadas. `0008` está aplicada e inmutable, con reejecución del verificador y reconciliación pendientes. `0009` es el siguiente número disponible. Todo cambio futuro debe:

1. revisar `0001` y todas las migraciones posteriores;
2. crear una nueva migración numerada, sin reescribir `0001`–`0008`;
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
- Resultado: Fase B.1 cerrada y operativa; 0007 es inmutable y 0008 queda como siguiente número disponible.

## Reconciliación posterior a 0007 — 2026-07-20

- Inventario vivo: 18 tablas, 165 columnas, 80 restricciones, 43 índices, 10 triggers públicos, 47 firmas de función, 23 políticas y 51 semillas controladas.
- Privilegios vivos: 125 grants de rutina, 270 grants de tabla publicados por `information_schema`, 6 de secuencia y 436 entradas ACL expandidas.
- Delta post-0006: +1 tabla, +9 columnas, +8 restricciones, +5 índices, +2 triggers, +8 funciones, +13 grants de rutina, +9 grants de tabla publicados y +23 entradas ACL.
- Representación: `MAINTAIN` aparece en ACL expandida, pero no en `information_schema.table_privileges`; por ello el delta publicado de tabla es +9 aunque la ACL confirma diez entradas nuevas de tabla.
- Diferencias ambientales: timestamp, token aleatorio `\restrict`, omisión textual opcional de `SECURITY INVOKER` y formato de `pg_dump`/`psql`.
- Resultado: sin deriva inexplicada; políticas, secuencias, catálogos y objetos post-0006 no modificados por 0007 permanecen intactos.

## 0008_operational_account_barrier_identity_correction.sql — aplicada; reejecución del verificador pendiente

- Fase B.2a preparada y aplicada sobre el snapshot post-0007 `2026-07-21T00:16:03Z`; ese snapshot sigue siendo la última evidencia reconciliada y todavía no representa los objetos vivos post-0008.
- Añade un helper privado de cuenta operativa activa, dos políticas RLS restrictivas, guardas explícitas en 29 rutinas operativas y dos RPC de corrección administrativa.
- No añade tablas, columnas, índices, restricciones ni semillas. Añade un trigger público y cuatro firmas de función; retira a `authenticated` los grants directos `INSERT`, `UPDATE` y `DELETE` de `activity_participants`.
- Inventario esperado tras aplicación: 18 tablas, 165 columnas, 80 restricciones, 43 índices, 11 triggers públicos, 51 firmas de función, 25 políticas y 51 semillas.
- Privilegios esperados: 132 grants de rutina, 267 grants de tabla publicados por `information_schema`, 6 de secuencia y 440 entradas ACL expandidas. El delta post-0007 es +7 de rutina, −3 de tabla y +4 ACL netas: tres RPC/helper nuevas tienen owner + `authenticated`, el trigger nuevo es owner-only y el DML directo de participantes queda cerrado.
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
- Corrección local del verificador: separa la semántica privada bajo owner, la denegación ACL directa bajo `authenticated` y la autorización interna mediante RPC B.1/B.2a `SECURITY DEFINER`. La reejecución del verificador, los smoke tests, el snapshot post-0008 y la reconciliación `0001`–`0008` permanecen pendientes.
- 0001–0008 son migraciones aplicadas e inmutables. 0009 es el siguiente número disponible, pero este defecto exclusivo del arnés no requiere una migración nueva. Durante esta corrección local no se conectó a Supabase ni se ejecutó SQL.
