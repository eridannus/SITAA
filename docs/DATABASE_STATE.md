# Estado reconciliado de la base de datos

**Fecha de cierre documental:** 2026-07-20.

**Snapshot vivo comparado:** `2026-07-21T00:16:03Z`, estado `SUCCESS`.

La fuente de verdad histórica y evolutiva es la cadena aplicada y verificada:

1. `0001_baseline_current_schema.sql`: baseline reconciliada.
2. `0002_database_security_and_integrity.sql`: seguridad, publicación y privilegios mínimos.
3. `0003_fix_draft_temporal_lifecycle.sql`: ciclo temporal de borradores.
4. `0004_identity_registration_foundation.sql`: identidad y registro institucional.
5. `0005_fix_google_oauth_user_creation.sql`: secuencia de alta Google.
6. `0006_structured_person_names.sql`: nombres personales estructurados y `full_name` derivado.
7. `0007_admin_account_directory_audit.sql`: directorio administrativo B.1 de sólo lectura y bitácora append-only.

La comparación fue local contra los artefactos ya generados en `supabase/reconciliation/live/`. No se conectó a Supabase ni se ejecutó SQL durante este cierre.

## Inventario posterior a 0007

| Categoría | Cantidad |
| --- | ---: |
| Tablas públicas | 18 |
| Columnas | 165 |
| Restricciones PK, FK, UNIQUE o CHECK | 80 |
| Índices, incluidos los respaldados por restricciones | 43 |
| Triggers sobre tablas públicas | 10 |
| Funciones y firmas públicas | 47 |
| Políticas RLS | 23 |
| Tablas con RLS habilitado | 18 |
| Filas de semillas en catálogos controlados | 51 |
| Grants de rutinas | 125 |
| Grants de tablas publicados por `information_schema` | 270 |
| Grants de secuencia | 6 |
| Entradas ACL expandidas | 436 |

Frente al snapshot posterior a 0006, 0007 añade exactamente una tabla, nueve columnas, ocho restricciones, cinco índices, dos triggers, ocho firmas y una tabla con RLS. Los deltas de privilegio son +13 grants de rutina, +9 grants de tabla publicados por `information_schema`, cero de secuencia y +23 entradas ACL expandidas. El delta de tabla es +9 porque `information_schema.table_privileges` no representa `MAINTAIN`; la ACL expandida sí lo incluye y confirma diez entradas nuevas de tabla.

## Contratos vivos posteriores a 0007

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
- RLS permanece habilitado en las 18 tablas y las 23 políticas no cambiaron.
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

## Resultado de reconciliación

| Diferencia observada | Clasificación |
| --- | --- |
| Objetos acumulados de 0002–0006 | Coincidencia exacta o semántica con la cadena acumulada |
| Tabla, restricciones, índices, triggers, funciones, RLS y ACL de 0007 | Coincidencia exacta o semántica con 0007 |
| Omisión textual de `SECURITY INVOKER` y representación de `MAINTAIN` entre `information_schema` y ACL expandida | Diferencia ambiental inocua |
| Timestamp, token aleatorio `\restrict` y formato producido por `pg_dump`/`psql` | Diferencia ambiental inocua |
| Backfill revisado de nombres y separación ya documentada entre cuentas técnica y académica | Diferencia controlada de datos operativos; no se exporta |

**Deriva inexplicada:** ninguna en esquema, funciones, triggers, políticas, privilegios efectivos, ACL, catálogos o restricciones.

El detalle probatorio está en `supabase/reconciliation/0007_post_apply_reconciliation.md`.

## Pendientes conocidos

- **A-02:** `technical_admin` mantiene acceso académico amplio a contenido publicado. **Deferred intentionally until user, role and permission administration is designed.**
- Las mutaciones administrativas B.2/B.3, roles V2/Fase C, filtros/reportes futuros, retiro de A-02 y check-in abierto siguen sus fases documentadas.
- Reportes y exportaciones CSV/PDF permanecen como trabajo futuro.
- Overloads heredados, `activities.updated_by`, `starts_at`/`ends_at`, alcance divisional y `token_type = 'registration'` permanecen reservados o pendientes de análisis.

## Inmutabilidad y siguiente migración

`0001`–`0007` forman historia aplicada, verificada y reconciliada y no se reescriben. 0007 es inmutable y Fase B.1 está operativa y cerrada dentro de su alcance de sólo lectura. No existe deriva inexplicada.

`0008_operational_account_barrier_identity_correction.sql` está preparada localmente para Fase B.2a, pero no aplicada. Propone una barrera operativa independiente del JWT y corrección de identidad auditada sin alterar Auth, roles ni historia. Una dependencia es abierta sólo si está en borrador o aún no termina según el cálculo post-0007 en `America/Mexico_City`; una actividad no borrador ya terminada es histórica y no bloquea correcciones posteriores.

La revisión local de 0008 añade precondiciones exactas de RLS, correspondencia Auth/profile, FK y ACL; distingue el ACL de tabla, `attacl` explícito vacío, la proyección table-derived legítima de `column_privileges` y el acceso efectivo equivalente al privilegio de tabla; serializa dependencias en orden fijo; bloquea actor/objetivo por UUID y reautoriza después de esperar; cierra el DML cliente directo de participantes; protege las escrituras directas de actividades mediante trigger, incluida la prohibición cliente de pasar de histórica a abierta; valida firmas PostgREST y hashes exactos de las cuatro funciones nuevas; e independiza el verificador del calendario real mediante fixtures namespaced. Las pruebas concurrentes de revocación/desactivación permanecen documentadas pero no ejecutadas y requieren un entorno desechable completo. Todo continúa sin verificación PostgreSQL hasta la secuencia coordinada de aplicación.

El primer preflight remoto de 0008 fue de sólo lectura y revirtió correctamente, pero informó `registration_trigger_drift = 1` por un falso positivo en nombres locales. El segundo intento también fue de sólo lectura, pero abortó antes de producir categorías con `expression contains variables of more than one relation`: `pg_get_expr` no puede decompilar un `tgqual` que referencia simultáneamente `OLD` y `NEW`. No hubo cambios vivos. El contrato local usa ahora `pg_get_triggerdef` y conserva exactamente `on_sitaa_auth_user_created` y `on_sitaa_auth_user_email_changed` sobre `auth.users`; una nueva reejecución permanece pendiente y 0008 continúa sin aplicar.

Esta preparación no cambia el inventario vivo post-0007 ni su snapshot autoritativo. Sólo después de aprobar preflight, desplegar la aplicación compatible, aplicar 0008, ejecutar el verificador, completar smoke tests y regenerar el snapshot podrá reconciliarse el nuevo inventario esperado de 51 funciones, 11 triggers y 25 políticas. Los totales de privilegios previstos son 132 grants de rutina, 267 de tabla, 6 de secuencia y 440 ACL expandidas; todavía no son evidencia viva.

Todo cambio futuro de base de datos debe crear una migración nueva, incluir verificación y rollback cuando corresponda, aplicarse manualmente, regenerar el snapshot después de cambios significativos y reconciliarlo contra la cadena completa.
