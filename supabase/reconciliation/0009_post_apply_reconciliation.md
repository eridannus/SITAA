# Cierre de reconciliación posterior a 0009

**Fecha de reconciliación:** 2026-07-22 (`America/Mexico_City`)

**Snapshot:** `2026-07-22T23:32:46Z`

**Estado declarado:** `SUCCESS`

**Cadena incluida:** `0001 + 0002 + 0003 + 0004 + 0005 + 0006 + 0007 + 0008 + 0009`

**Resultado:** reconciliado sin deriva inexplicada; Fase B.2b cerrada dentro de su alcance aprobado.

Este informe compara localmente el snapshot post-0008 conservado en `HEAD` con el conjunto vivo post-0009 ya generado, la migración 0009 inmutable y el contrato final de su verificador. No se estableció conexión con Supabase, no se ejecutó SQL, no se invocó `psql`, `pg_dump`, Supabase CLI ni el script de snapshot, y no se regeneró ni editó ningún artefacto vivo durante la reconciliación.

## Integridad del snapshot

Los 14 artefactos obligatorios existen, tienen contenido y son UTF-8 estricto. El metadata declara generación UTC `2026-07-22T23:32:46Z`, estado `SUCCESS`, propósito exclusivo de reconciliación sin escrituras remotas, `pg_dump 18.4`, `psql 18.4`, `client_encoding = UTF8`, esquema `public` solamente, dump de esquema sin ownership ni privilegios, cuatro capturas separadas de privilegios y semillas limitadas a catálogos controlados. `.gitkeep` y el metadato oculto `desktop.ini` son infraestructura del directorio; no existe otro resultado, temporal o diagnóstico dentro de `live/`.

No se encontró marcador de fallo o publicación parcial. El literal controlado `failure` de una restricción de auditoría no es un estado del snapshot. Tampoco se encontraron URI de conexión, contraseñas, tokens, cookies, JWT, claves API o secretos OAuth. El dump es sólo esquema y no contiene `COPY` de perfiles, asignaciones, actividades, participantes, check-in o auditoría; el único contenido de filas está en los once catálogos aprobados y suma 51 registros. No se exponen filas de personas ni datos operativos.

### Huellas SHA-256 de la evidencia viva

| Artefacto | SHA-256 |
| --- | --- |
| `live_schema.sql` | `319428399ef835d1dfe21c65d21354402b7dc377c1194a6b743a52b8984aa1fa` |
| `live_tables.sql` | `030587f4d2ca22c160a3603851a2f4d1c6555c127fcbffe8a4e90cfbce01a147` |
| `live_columns.sql` | `59ed2ccd538345bf27b00944a77fd8cbedecd806081903cbc2aa83477fb1344b` |
| `live_constraints.sql` | `ef78721a26298617d1e8e47ea04899844222f6e929fa3845124d4824228d11d8` |
| `live_indexes.sql` | `3dd63abd41aa855d6067a71ae019907bff774254ca106e6443980cd8d203e8cc` |
| `live_triggers.sql` | `0dc9534f7858e8e1ae617831d85f1fdc3d522cc6dc53c17bd7a93374b302ac59` |
| `live_functions.sql` | `34defe0e750bd4f855bf36762e402a07267b1d4d4e17d524faaa18605f89cfa5` |
| `live_policies.sql` | `b85eb2db46264611fa299387cbae2b20c0fbdfb3bf5cfbec50075563cfbfbbfd` |
| `live_routine_privileges.sql` | `ceb9c88471f4c54ef8cee85063c3066412837f5fcaf102c9f8503fa64cfd590a` |
| `live_table_privileges.sql` | `8a8c0cab0e0a98fb846a53258f9a1378ad086c861d3cd8313d6eecb8ab1c1ac9` |
| `live_sequence_privileges.sql` | `766f7fec6f054f790fe4aa824933c57858747876da8bd983c2b2715ff2bfe281` |
| `live_acl.sql` | `3f8216a776302c9d966ea5f45d214b6147df594461ffe6f27204ceb499279712` |
| `live_seed_catalogs.sql` | `a616d8e427e574a7584464bfa8c231d74626b878934b646228e0208967adbb71` |
| `live_snapshot_metadata.txt` | `d9dfdc5eb4f7263174196dcb0a3852dd17d55d27275aac63acf51d565f5e943e` |

La huella SHA-256 de la migración aplicada e inmutable `0009_admin_account_lifecycle_transitions.sql` es `c525998b028d5d0f8f7eed6803444b4a8e529e478c7846e8894227a65593b922`.

## Inventario post-0008 frente a post-0009

| Categoría | Post-0008 | Post-0009 | Delta observado | Delta esperado | Clasificación |
| --- | ---: | ---: | ---: | ---: | --- |
| Tablas públicas | 18 | 18 | 0 | 0 | Sin cambio físico |
| Columnas | 165 | 165 | 0 | 0 | Sin cambio físico |
| Restricciones PK/FK/UNIQUE/CHECK | 80 | 80 | 0 | 0 | Sin cambio físico |
| Índices | 43 | 43 | 0 | 0 | Sin cambio físico |
| Triggers no internos sobre tablas públicas | 11 | 11 | 0 | 0 | Contrato conservado |
| Firmas de función públicas | 51 | 54 | +3 | +3 | Cambio esperado de 0009 |
| Políticas RLS | 25 | 25 | 0 | 0 | Contrato conservado |
| Tablas públicas con RLS habilitado | 18 | 18 | 0 | 0 | Contrato conservado |
| Semillas controladas | 51 | 51 | 0 | 0 | Contrato conservado |
| Grants de rutina | 132 | 137 | +5 | +5 | Cambio esperado de privilegios |
| Grants de tabla publicados por `information_schema` | 267 | 267 | 0 | 0 | Contrato conservado |
| Grants de secuencia | 6 | 6 | 0 | 0 | Contrato conservado |
| Entradas ACL expandidas | 440 | 445 | +5 | +5 | Cambio esperado de privilegios |

Las 80 restricciones se descomponen en 18 PK, 30 FK, 4 UNIQUE y 28 CHECK. Las 18 tablas tienen RLS habilitado y ninguna usa RLS forzado.

## Preservación del esquema físico

`live_tables.sql`, `live_columns.sql`, `live_constraints.sql`, `live_indexes.sql`, `live_triggers.sql`, `live_policies.sql`, `live_table_privileges.sql`, `live_sequence_privileges.sql` y `live_seed_catalogs.sql` no aparecen modificados en Git respecto de post-0008 y sus conjuntos de filas normalizados son idénticos. La comparación del blob Git con el checkout puede diferir sólo por CRLF/LF, sin diferencia semántica. No se añadió ni cambió tabla, columna, restricción, índice, trigger, política, secuencia, RLS o semilla.

El cambio en `live_schema.sql` contiene exclusivamente las tres funciones 0009 y el token aleatorio `\restrict`/`\unrestrict` generado por `pg_dump`. No existe DDL físico adicional.

## Tres funciones B.2b

No existe sobrecarga adicional de ninguna firma. Las 51 firmas post-0008 conservan exactamente definición, metadata y ACL.

### Helper privado

`is_exact_b1_account_admin_profile_b2b(uuid)` recibe `requested_profile_id uuid`, devuelve `boolean`, pertenece a `postgres`, usa SQL, es `STABLE SECURITY DEFINER` y fija `search_path = pg_catalog, public`. Su hash normalizado es `104d16a531ea53a5b4908102322097dc`. Su ACL expandida contiene sólo `EXECUTE` del owner, sin grant option; `PUBLIC`, `anon`, `authenticated`, `service_role` y grantees personalizados no tienen ejecución directa.

### RPC de contexto

`get_admin_account_lifecycle_context_b2b(uuid)` recibe `requested_profile_id uuid`. Devuelve, en orden: `target_profile_id uuid`, `account_kind text`, `account_status text`, `is_self boolean`, `can_deactivate boolean`, `can_reactivate boolean`, `denial_code text`, `has_exact_b1_assignment boolean`, `active_exact_b1_admin_count bigint`, `current_or_future_assignment_count bigint`, `open_responsibility_count bigint` y `open_participation_count bigint`. Pertenece a `postgres`, usa PL/pgSQL, es `STABLE SECURITY DEFINER`, fija `search_path = pg_catalog, public` y su hash es `6e7c8bb5e2dcf99fce6a75e03e07c309`. Sólo owner y `authenticated` ejecutan; no hay grant option delegado.

### RPC de mutación

`transition_admin_account_lifecycle_b2b(uuid,text,text)` recibe, en orden, `requested_profile_id uuid`, `requested_transition text` y `transition_reason text`. Devuelve `target_profile_id uuid`, `audit_event_id uuid`, `previous_status text`, `new_status text`, `changed_fields text[]` y `updated_at timestamptz`. Pertenece a `postgres`, usa PL/pgSQL, es `VOLATILE SECURITY DEFINER`, fija `search_path = pg_catalog, public` y su hash es `7f940968051ff1b844443f6c76b561c3`. Sólo owner y `authenticated` ejecutan; no hay grant option delegado.

El hash agregado del mapa de las 54 firmas y cuerpos es `71f9763d702e95e4eede51a4a4611694`.

## Privilegios de rutina y ACL expandida

Las cinco filas nuevas son exactamente:

- owner sobre el helper privado;
- owner y `authenticated` sobre la RPC de contexto;
- owner y `authenticated` sobre la RPC de mutación.

`information_schema.routine_privileges` representa la capacidad inherente del owner como `is_grantable = YES`; `live_acl.sql` expande el ACL directo de las cinco filas con `is_grantable = false`. Ningún cliente recibe grant option, `PUBLIC`, `anon` y `service_role` no reciben acceso a las funciones 0009, y no aparece otro grantee. El delta +5 de grants y +5 de ACL coincide exactamente con la migración.

## Privilegios de tabla, secuencia y columnas

Los 267 grants de tabla y los 6 de secuencia son semánticamente idénticos a post-0008. `admin_audit_events` conserva para `service_role` sólo `SELECT` e `INSERT`; no existe política de cliente sobre su contenido crudo y sus triggers siguen bloqueando `UPDATE`, `DELETE` y `TRUNCATE`. `authenticated` conserva sólo `SELECT` sobre `activity_participants`, sin `INSERT`, `UPDATE` o `DELETE`, y sólo `SELECT` de tabla sobre `profiles`.

El snapshot especializado no exporta directamente `pg_attribute.attacl`; por ello los tres `UPDATE` de nombres estructurados exclusivamente por columna se consideran evidencia de la guarda ejecutada de la migración y del verificador final, no observación directa de estos 14 archivos. Del mismo modo, los privilegios predeterminados quedaron protegidos por la guarda post-DDL aprobada, pero no se presentan como observados directamente por el snapshot público.

## Catálogos controlados

Las 51 filas y su hash `2e450238768fbe9889470864a1832486` permanecen sin cambio: `roles`, `divisions`, `academic_programs`, `academic_periods`, `activity_types`, `service_types`, `attention_categories`, `activity_modalities`, `activity_statuses`, `location_types` y `participant_roles`. No existe catálogo, rol V2 o capacidad de Fase C adicional.

## RLS, políticas y fronteras de seguridad

Las 18 tablas públicas conservan RLS. Las dos políticas restrictivas 0008, `Active accounts may operate activities` y `Active accounts may operate activity participants`, permanecen sobre `authenticated`; la desactivación B.2b activa esa barrera independientemente de la edad del JWT. No se añadió política administrativa sobre auditoría, perfiles o asignaciones.

0009 no cambió usuarios, identidades, triggers ni handlers de Auth. Los triggers canónicos de `auth.users` están fuera del snapshot limitado a `public` y fueron cubiertos por el preflight aprobado, la guarda atómica de la migración y el verificador. La aplicación sigue sin Auth Admin y sin cliente `service_role`. B.2b no revoca físicamente refresh tokens o sesiones y no implementa roles V2/Fase C. A-02 continúa diferida intencionalmente hasta diseñar la administración de usuarios, roles y permisos.

## Preflight e intentos de migración

El primer preflight independiente expuso cuatro falsos positivos del arnés; un diagnóstico separado de sólo lectura confirmó la línea base post-0008. La versión corregida devolvió 26 filas, dejó las 19 categorías bloqueantes en cero, terminó con `ROLLBACK` y fue aprobada. La aplicación compatible se desplegó antes de aplicar SQL.

El intento 1 falló antes del DDL por un `EXISTS` exterior sin cerrar en el preflight embebido. El intento 2 superó la sintaxis, pero falló antes del DDL al concatenar `pg_default_acl.defaclobjtype` sin convertir su tipo interno `"char"` a `text`. Ambas transacciones se descartaron sin objeto persistente y no requirieron rollback. El intento 3 ejecutó el preflight embebido, creó las tres funciones, normalizó ACL, aprobó la guarda atómica post-DDL y llegó a `COMMIT`. Desde ese momento 0009 es inmutable.

## Verificador y smoke tests

El verificador transaccional final completó contratos, fixtures y aserciones y terminó con `ROLLBACK`; no persistió fixture, grant, transición, cambio de estado ni evento sintético.

Los smoke tests aprobados comprobaron visibilidad y controles sólo para autoridad B.1 exacta, desactivación y reactivación de una cuenta institucional de prueba, efecto inmediato de la barrera 0008 sobre una sesión existente, preservación de identidad/asignaciones/actividad/historia, evento append-only minimizado y recuperación exclusiva de asignaciones todavía activas, válidas y vigentes. Autotransición, registro pendiente, profesor, estudiante y no administrador permanecieron denegados o sin controles. No se registra identidad, razón ni fila operativa de las pruebas.

## Concurrencia

La matriz manual de varias sesiones no fue ejecutada y no se presenta como evidencia observada. Permanece restringida a una rama, clon o base desechable completa; no se ejecutará limpiando auditoría append-only ni datos referenciados. Su ausencia no sustituye ni invalida la serialización verificada por el contrato transaccional.

## Clasificación completa de diferencias

| Diferencia | Clasificación |
| --- | --- |
| +3 firmas públicas | Cambio funcional esperado de 0009 |
| +5 grants de rutina y +5 ACL expandidas | Cambio de privilegios esperado de 0009 |
| Tablas, columnas, restricciones, índices, triggers, políticas, RLS, grants de tabla/secuencia y semillas sin cambio | Contrato post-0008 conservado |
| Timestamp del snapshot y token aleatorio `\restrict`/`\unrestrict` | Diferencia ambiental inocua |
| CRLF/LF, espacios finales y formato emitidos por `psql`/`pg_dump` | Diferencia de representación inocua del artefacto generado |
| Omisión textual opcional de `SECURITY INVOKER` | Diferencia de representación; la seguridad se evalúa semánticamente |
| `MAINTAIN` visible en ACL expandida y no en `information_schema.table_privileges` | Diferencia conocida de representación PostgreSQL |

**Deriva inexplicada:** ninguna.

## Conclusión

El estado vivo queda reconciliado contra `0001`–`0009` sin diferencia no explicada. Las migraciones 0001–0009 están aplicadas, verificadas, reconciliadas e inmutables. Fase B.2b queda cerrada dentro de su alcance aprobado: desactivación/reactivación administrativa auditada, preservación de identidad e historia y aplicación inmediata de la barrera operativa existente.

`0010` es el siguiente número de migración disponible. B.3 —operaciones Auth y revocación física coordinada de sesiones— y Fase C —asignación, revocación, transferencia y delegación de roles— permanecen pendientes.
