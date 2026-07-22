# Estado reconciliado de la base de datos

**Fecha de actualización documental:** 2026-07-22.

**Snapshot vivo comparado:** `2026-07-22T01:46:13Z`, estado `SUCCESS`.

La fuente de verdad histórica y evolutiva comprende `0001`–`0008`, aplicadas, verificadas, reconciliadas e inmutables:

1. `0001_baseline_current_schema.sql`: baseline reconciliada.
2. `0002_database_security_and_integrity.sql`: seguridad, publicación y privilegios mínimos.
3. `0003_fix_draft_temporal_lifecycle.sql`: ciclo temporal de borradores.
4. `0004_identity_registration_foundation.sql`: identidad y registro institucional.
5. `0005_fix_google_oauth_user_creation.sql`: secuencia de alta Google.
6. `0006_structured_person_names.sql`: nombres personales estructurados y `full_name` derivado.
7. `0007_admin_account_directory_audit.sql`: directorio administrativo B.1 de sólo lectura y bitácora append-only.
8. `0008_operational_account_barrier_identity_correction.sql`: barrera operativa y corrección administrativa B.2a; aplicada, verificada, probada, reconciliada e inmutable.

La comparación fue local contra los artefactos ya generados en `supabase/reconciliation/live/`. No se conectó a Supabase ni se ejecutó SQL durante este cierre.

## Inventario vivo posterior a 0008

| Categoría | Cantidad |
| --- | ---: |
| Tablas públicas | 18 |
| Columnas | 165 |
| Restricciones PK, FK, UNIQUE o CHECK | 80 |
| Índices, incluidos los respaldados por restricciones | 43 |
| Triggers sobre tablas públicas | 11 |
| Funciones y firmas públicas | 51 |
| Políticas RLS | 25 |
| Tablas con RLS habilitado | 18 |
| Filas de semillas en catálogos controlados | 51 |
| Grants de rutinas | 132 |
| Grants de tablas publicados por `information_schema` | 267 |
| Grants de secuencia | 6 |
| Entradas ACL expandidas | 440 |

Frente al snapshot posterior a 0007, 0008 no cambia tablas, columnas, restricciones, índices, semillas ni estados RLS. Añade exactamente un trigger, cuatro firmas y dos políticas restrictivas. Los deltas de privilegio son +7 grants de rutina, −3 grants de tabla publicados por `information_schema`, cero de secuencia y +4 entradas ACL expandidas. La representación de `MAINTAIN` sigue documentada, pero no explica ningún delta nuevo de 0008.

## Contratos vivos posteriores a 0008

- `first_names`, `paternal_surname` y `maternal_surname` existen como `text`; el apellido materno admite `NULL`.
- Los componentes estructurados son autoritativos y `normalize_sitaa_profile_names()` deriva `full_name` de forma determinista.
- Una cuenta institucional `active|inactive` exige nombre(s), apellido paterno, programa e identificador coherente; una técnica exige nombre(s) y puede omitir apellidos.
- Un perfil institucional `pending_registration` permanece incompleto hasta la finalización autenticada.
- `enforce_sitaa_profile_identity()` permite autoservicio sólo de los tres componentes del nombre y protege los campos administrativos.
- La firma de seis argumentos de `complete_own_google_registration` es la única firma de finalización ejecutable por `authenticated`; la firma anterior permanece sin acceso del cliente.
- `handle_sitaa_auth_user_created()` conserva las rutas Google pendiente y técnica confiable; `sync_sitaa_profile_email_from_auth()` permanece instalada.
- El snapshot especializado enumera triggers de tablas `public`; los triggers sobre `auth.users` se comprobaron mediante el preflight y el verificador transaccional aprobados.

El snapshot de tablas y ACL no captura ACL de columna (`pg_attribute.attacl`). La autorización exacta de `UPDATE (first_names, paternal_surname, maternal_surname)` y el rechazo de `full_name` o campos administrativos quedaron comprobados por el verificador 0006 ejecutado bajo `SET LOCAL ROLE authenticated`. Esta limitación de cobertura no altera el privilegio efectivo ni constituye deriva.

`admin_audit_events` está implementada con nueve columnas, referencias restrictivas, cuatro validaciones, RLS sin políticas de cliente, dos triggers append-only y ACL mínimo. Las cuatro RPC B.1 exigen la autoridad exacta `technical_admin/system/technical`, minimizan sus proyecciones y no mutan cuentas, Auth ni roles. Los helpers privados y el validador de metadata conservan los ACL verificados por 0007.

## Protecciones acumuladas conservadas

- Los borradores sólo son visibles para `created_by`; `technical_admin` no amplía la lectura de borradores ajenos.
- La publicación exige estado programado completo y protege `created_by` y la transición de estado.
- El creador puede corregir o eliminar su borrador provisional conforme a 0003.
- Participación, asistencia manual y masiva, expiración, reapertura y check-in QR/enlace/código conservan sus funciones y triggers.
- Google crea exactamente un perfil pendiente; signup público por contraseña, proveedores no soportados y metadata inválida se rechazan atómicamente.
- `PUBLIC` y `anon` no tienen `EXECUTE` sobre funciones SITAA; `anon` conserva sólo lectura de `system_health`.
- RLS permanece habilitado en las 18 tablas. Las 23 políticas post-0007 no cambiaron y 0008 añadió exactamente dos políticas `RESTRICTIVE` de cuenta activa sobre `activities` y `activity_participants`.
- Los 11 catálogos controlados conservan 51 filas; no se exportaron datos operativos o personales.

## Evidencia de aplicación y verificación acumulada

- El preflight reportó cero filas en todas las categorías bloqueantes.
- La migración terminó con `COMMIT` y la aplicación compatible fue desplegada.
- El verificador transaccional terminó con código de salida 0 y `ROLLBACK`; las fixtures sintéticas no persistieron.
- El arnés fue corregido para conceder a `authenticated` sólo `SELECT` sobre `pg_temp.sitaa_0006_cases` y `EXECUTE` sobre sus dos helpers temporales. Esos grants desaparecen con la sesión/transacción y no cambian producción ni la migración aplicada.
- Los smoke tests de producción confirmaron registro, edición y representación de nombres estructurados.
- Para 0007, el preflight aprobó todos los bloqueos, la migración terminó en `COMMIT` y la aplicación compatible fue desplegada.
- La primera ejecución del verificador 0007 falló antes de crear fixtures por un defecto de normalización del arnés. La corrección no cambió objetos vivos; la reejecución terminó con `ROLLBACK` y sin efectos persistentes.
- Los smoke tests B.1 aprobaron autoridad exacta, rechazo de usuarios ordinarios, búsqueda, filtros, lista, detalle, asignaciones V1 e historial sanitizado sin mutaciones.
- Para 0008, el preflight final aprobó sus 35 categorías bloqueantes, la migración terminó con `COMMIT` y el verificador final aprobó con `ROLLBACK` sin persistir fixtures ni grants temporales.
- Los smoke tests B.2a aprobaron corrección de identidad, auditoría sanitizada y, después del ajuste exclusivo de aplicación, administración de participantes/asistencia por el responsable histórico entre programas.

## Resultado de reconciliación

| Diferencia observada | Clasificación |
| --- | --- |
| Tablas, columnas, restricciones, índices y semillas | Sin cambio frente a post-0007; coincidencia exacta |
| Un trigger, cuatro firmas y dos políticas de 0008 | Cambio estructural esperado de 0008 |
| +7 grants de rutina, −3 grants de tabla y +4 ACL expandidas | Cambio de privilegio esperado de 0008 |
| Omisión textual de `SECURITY INVOKER` y representación de `MAINTAIN` entre `information_schema` y ACL expandida | Diferencia ambiental inocua |
| Timestamp, token aleatorio `\restrict` y formato producido por `pg_dump`/`psql` | Diferencia ambiental inocua |
| Backfill revisado de nombres y separación ya documentada entre cuentas técnica y académica | Diferencia controlada de datos operativos; no se exporta |

**Deriva inexplicada:** ninguna en esquema, funciones, triggers, políticas, privilegios efectivos, ACL, catálogos o restricciones.

El detalle probatorio está en `supabase/reconciliation/0008_post_apply_reconciliation.md`.

## Pendientes conocidos

- **A-02:** `technical_admin` mantiene acceso académico amplio a contenido publicado. **Deferred intentionally until user, role and permission administration is designed.**
- Las operaciones administrativas B.2b/B.3, roles V2/Fase C, filtros/reportes futuros, retiro de A-02 y check-in abierto siguen sus fases documentadas.
- Reportes y exportaciones CSV/PDF permanecen como trabajo futuro.
- Overloads heredados, `activities.updated_by`, `starts_at`/`ends_at`, alcance divisional y `token_type = 'registration'` permanecen reservados o pendientes de análisis.

## Inmutabilidad y siguiente migración

`0001`–`0008` forman historia aplicada, verificada y reconciliada y no se reescriben. 0007 cerró Fase B.1 y 0008 cierra Fase B.2a dentro de sus alcances aprobados. El snapshot post-0008 no presenta deriva inexplicada.

`0008_operational_account_barrier_identity_correction.sql` fue aplicada con `COMMIT` después de aprobar el preflight y publicar la aplicación compatible. Es inmutable. Implementa una barrera operativa independiente del JWT y corrección de identidad auditada sin alterar Auth, roles ni historia. Una dependencia es abierta sólo si está en borrador o aún no termina según el cálculo temporal en `America/Mexico_City`; una actividad no borrador ya terminada es histórica y no bloquea correcciones posteriores.

0008 añade precondiciones exactas de RLS, correspondencia Auth/profile, FK y ACL; distingue el ACL de tabla, `attacl` explícito vacío, la proyección table-derived legítima de `column_privileges` y el acceso efectivo equivalente al privilegio de tabla; serializa dependencias en orden fijo; bloquea actor/objetivo por UUID y reautoriza después de esperar; cierra el DML cliente directo de participantes; protege las escrituras directas de actividades mediante trigger, incluida la prohibición cliente de pasar de histórica a abierta; y valida firmas PostgREST y hashes exactos de las cuatro funciones nuevas. Las pruebas concurrentes de revocación/desactivación permanecen documentadas pero no ejecutadas y requieren un entorno desechable completo.

El primer preflight remoto de 0008 terminó con un falso positivo por nombres; el segundo abortó porque `pg_get_expr` no puede decompilar `OLD` y `NEW`; el tercero expuso el cast `::text` añadido por `pg_get_triggerdef`. La cuarta ejecución, ya corregida, devolvió las 40 categorías, dejó sus 35 bloqueos en cero y terminó con `ROLLBACK`. La aplicación compatible se publicó y 0008 se aplicó después.

La primera ejecución del verificador 0008 abortó al invocar directamente bajo `authenticated` el helper privado owner-only `is_b1_account_admin()`; la denegación `42501` fue correcta. La segunda aprobó esa corrección, los contratos anteriores, las fixtures, los rechazos y siete mutaciones RPC, pero abortó porque las postcondiciones crudas de perfiles ajenos, auditoría e historia permanecían bajo RLS/ACL de `authenticated`. Ambas transacciones se descartaron sin persistir fixtures, correcciones, grants, auditoría ni cambios operativos. La segunda corrección local conserva las superficies cliente bajo `authenticated` y mueve la inspección cruda al owner, incluida una secuencia histórica owner/cliente/owner.

La tercera ejecución del verificador aprobó y terminó con `ROLLBACK`. El smoke test de corrección de identidad y auditoría sanitizada aprobó; después se detectó que la página y las acciones de participantes ocultaban controles a un responsable histórico cuyo programa principal fue corregido. El contrato vivo `can_edit_activity(uuid)` sí autorizaba por creador o `responsible_profile_id`; la aplicación pasó a consumir esa decisión autoritativa y la reejecución del smoke test aprobó sin requerir una migración nueva.

El directorio `supabase/reconciliation/live/` es evidencia autoritativa post-0008 y no debe editarse manualmente. Los inventarios de 51 funciones, 11 triggers, 25 políticas, 132 grants de rutina, 267 de tabla, 6 de secuencia y 440 ACL expandidas son conteos vivos observados. `0009` es el siguiente número disponible.

Todo cambio futuro de base de datos debe crear una migración nueva, incluir verificación y rollback cuando corresponda, aplicarse manualmente, regenerar el snapshot después de cambios significativos y reconciliarlo contra la cadena completa.

## Estado previsto por 0009 (no aplicado)

0009 conserva intacto el modelo físico y añade tres funciones B.2b. El estado esperado posterior sería 54 funciones, 137 grants de rutina y 445 ACL expandidas; los demás inventarios permanecerían en 18/165/80/43/11/25/51 para tablas/columnas/restricciones/índices/triggers/políticas/semillas. Estos conteos son un contrato previsto, no evidencia viva, hasta regenerar el snapshot.

El primer preflight remoto de 0009 devolvió las 26 categorías y terminó con `ROLLBACK`, pero no fue aprobado por cuatro falsos positivos del arnés. Un diagnóstico adicional de sólo lectura confirmó el estado post-0008. Después de alinear las comparaciones con el snapshot canónico, el preflight independiente corregido devolvió nuevamente las 26 filas, dejó sus 19 bloqueos en cero y terminó con `ROLLBACK`; quedó aprobado. La aplicación compatible B.2b se desplegó antes del intento de migración.

Dos intentos de migración fallaron de forma segura antes del DDL. El primero se detuvo al compilar el `DO $preflight$` por un `EXISTS` exterior sin cerrar. Tras corregirlo, el segundo entró al preflight y se detuvo al calcular la línea base default ACL porque `pg_default_acl.defaclobjtype` se concatenaba sin conversión explícita de su tipo interno `"char"` a `text`. Ambos intentos alcanzaron sólo `BEGIN`, los dos `SET LOCAL` y, en el segundo caso, el preflight; ninguno llegó a `CREATE FUNCTION`, `REVOKE`, `GRANT`, la guarda post-DDL o `COMMIT`. No se creó objeto 0009 alguno y no fue necesario ejecutar el rollback. La corrección `defaclobjtype::text` permanece local y un tercer intento controlado está pendiente. 0009 sigue no aplicada, B.2b no está cerrada y B.3/Fase C continúan pendientes.
