# Cierre de reconciliación posterior a 0010

**Fecha de reconciliación:** 2026-08-06 (`America/Mexico_City`)

**Snapshot:** `2026-08-06T23:33:15Z`

**Estado declarado:** `SUCCESS`

**Cadena incluida:** `0001 + 0002 + 0003 + 0004 + 0005 + 0006 + 0007 + 0008 + 0009 + 0010`

**Resultado:** reconciliado sin deriva inexplicada; Fase B.3a cerrada dentro de su alcance aprobado.

## 1. Alcance y reconciliación exclusivamente local

Este informe compara el snapshot post‑0009 conservado en `HEAD` con los catorce artefactos post‑0010 ya generados en la copia de trabajo, la migración 0010 inmutable, su verificador final corregido y los checkpoints Hosted Auth y productivos aprobados. Durante esta reconciliación no se estableció conexión con Supabase o PostgreSQL, no se ejecutó SQL, no se invocó `psql`, `pg_dump`, Supabase CLI, Auth Admin ni la Edge Function, y no se regeneró o editó ningún artefacto de `live/`.

La comparación estructural usa las versiones post‑0009 de Git como línea base y clasifica cada alta, revocación o diferencia de representación. No se infiere estado operativo desde el snapshot estructural.

## 2. Integridad del snapshot

Los catorce artefactos obligatorios existen, no están vacíos y decodifican como UTF-8 estricto. El metadata declara exactamente:

- generación UTC `2026-08-06T23:33:15Z`;
- estado `SUCCESS`;
- propósito exclusivo de reconciliación sin escrituras remotas;
- `pg_dump` como herramienta de esquema, versión 18.4;
- `psql` 18.4;
- `client_encoding = UTF8`;
- esquema `public` solamente y dump `schema-only`;
- exclusión de ownership y privilegios en el dump principal;
- las cuatro capturas obligatorias de privilegios;
- semillas limitadas a catálogos SITAA controlados.

No existe resultado parcial o de fallo, marcador de conflicto, URI PostgreSQL, contraseña, JWT, cookie, cabecera `Authorization`, clave secreta, clave privada o secreto OAuth. No hay `COPY` de perfiles, asignaciones, actividades, participantes, asistencia, ledger o auditoría. Las únicas filas exportadas son las 51 de los once catálogos controlados.

`live_columns.sql` conserva tabs finales canónicos cuando el último campo TSV está vacío y `live_functions.sql` conserva el whitespace multilínea del deparser PostgreSQL. Ambos son evidencia cruda y no se recortaron ni normalizaron.

### Huellas SHA-256 de la evidencia viva

| Artefacto | SHA-256 |
| --- | --- |
| `live_schema.sql` | `4b374bc1b183fb7638e6f23b3e18054020e73e62cd19754770781666c5412de0` |
| `live_tables.sql` | `b07c54fdf4bf1d81f8124d662a1bcc56bc73724348fde46e264d1bd179693b9a` |
| `live_columns.sql` | `04eaacf0222a8fb2d1ff16806c2bd8a8eab45fce5a27349aef268f9d1b1124a3` |
| `live_constraints.sql` | `4b553392f3fc497a02439014e864a28191fefcb73f3aa4ee696fbb2c7f3092d5` |
| `live_indexes.sql` | `5049ed28a50f5d093960298d25eff8cd8dd70ae4a230f76921ea3d5125f12280` |
| `live_triggers.sql` | `bdbc8b0fc2799f1f7b0a687aad43344546b2350780110316b11c094244dae03a` |
| `live_functions.sql` | `4751b1281784d21faea926ab031d33b4567e58402550350a014db9b13133ffb7` |
| `live_policies.sql` | `b85eb2db46264611fa299387cbae2b20c0fbdfb3bf5cfbec50075563cfbfbbfd` |
| `live_routine_privileges.sql` | `1bb3d43787674783172c4141840c8b421c8129fc06b4ce3a367bdda97bc51664` |
| `live_table_privileges.sql` | `9feb9cf11b1324f258203edd556e6d867b6f1710189d897ccba9c362528e21e7` |
| `live_sequence_privileges.sql` | `766f7fec6f054f790fe4aa824933c57858747876da8bd983c2b2715ff2bfe281` |
| `live_acl.sql` | `61f61a650bdced95b70e5696a03e83cffab2e77963cd79e6a132f066cfc7da5c` |
| `live_seed_catalogs.sql` | `a616d8e427e574a7584464bfa8c231d74626b878934b646228e0208967adbb71` |
| `live_snapshot_metadata.txt` | `82bc0f0302fe5aa772aea06827a6aae3bcbccd9ad93bd040a6337e208f4e243f` |

La huella SHA-256 de la migración aplicada e inmutable `0010_coordinated_auth_session_suspension.sql` es `d7354dd40c1696a02574cb2d72e81d016ce5419e4164641bd731c841251f493a`.

## 3. Inventario post‑0009 frente a post‑0010

Los conteos se derivaron de forma independiente de los artefactos nuevos y después se compararon con la guarda post-DDL y el verificador 0010.

| Categoría | Post‑0009 | Post‑0010 | Delta observado | Delta esperado | Clasificación |
| --- | ---: | ---: | ---: | ---: | --- |
| Tablas públicas | 18 | 19 | +1 | +1 | Alta esperada de 0010 |
| Columnas | 165 | 183 | +18 | +18 | Tabla B.3a esperada |
| Restricciones PK/FK/UNIQUE/CHECK | 80 | 96 | +16 | +16 | Contrato del ledger |
| Índices | 43 | 48 | +5 | +5 | Contrato del ledger |
| Triggers no internos sobre tablas públicas | 11 | 13 | +2 | +2 | Guardas del ledger |
| Firmas de función públicas | 54 | 60 | +6 | +6 | Funciones B.3a |
| Políticas RLS | 25 | 25 | 0 | 0 | Contrato conservado |
| Tablas públicas con RLS habilitado | 18 | 19 | +1 | +1 | Ledger protegido |
| Filas de catálogos controlados | 51 | 51 | 0 | 0 | Contrato conservado |
| Grants de rutina | 137 | 147 | +10 | +10 | Once altas y una revocación |
| Grants de tabla publicados por `information_schema` | 267 | 274 | +7 | +7 | Owner del ledger |
| Grants de secuencia | 6 | 6 | 0 | 0 | Contrato conservado |
| Entradas ACL expandidas | 445 | 463 | +18 | +18 | Funciones, ledger y revocación |

Las 96 restricciones se descomponen en 19 PK, 35 FK, 5 UNIQUE y 37 CHECK. Las 19 tablas tienen RLS habilitado y ninguna fuerza RLS.

## 4. Nueva tabla `admin_auth_operations`

La única tabla nueva es `public.admin_auth_operations`. Sus columnas, en orden, son:

| Posición | Columna | Tipo | Nulable | Default |
| ---: | --- | --- | --- | --- |
| 1 | `id` | `uuid` | No | `gen_random_uuid()` |
| 2 | `request_id` | `uuid` | No | — |
| 3 | `requested_by_profile_id` | `uuid` | No | — |
| 4 | `completed_by_profile_id` | `uuid` | Sí | — |
| 5 | `target_profile_id` | `uuid` | No | — |
| 6 | `operation_code` | `text` | No | — |
| 7 | `status` | `text` | No | `'open'::text` |
| 8 | `completed_stage` | `text` | No | `'prepared'::text` |
| 9 | `reason` | `text` | No | — |
| 10 | `attempt_count` | `integer` | No | `0` |
| 11 | `last_error_code` | `text` | Sí | — |
| 12 | `profile_audit_event_id` | `uuid` | Sí | — |
| 13 | `auth_audit_event_id` | `uuid` | Sí | — |
| 14 | `requested_at` | `timestamp with time zone` | No | `now()` |
| 15 | `processing_started_at` | `timestamp with time zone` | Sí | — |
| 16 | `auth_synchronized_at` | `timestamp with time zone` | Sí | — |
| 17 | `completed_at` | `timestamp with time zone` | Sí | — |
| 18 | `updated_at` | `timestamp with time zone` | No | `now()` |

Las dieciséis restricciones son una PK sobre `id`, una UNIQUE sobre `request_id`, cinco FK `ON DELETE RESTRICT` hacia `profiles(id)` o `admin_audit_events(id)` y nueve CHECK: operación, estado, etapa, razón, conteo de intentos, código de error estable, relación operación/etapa, matriz evidencia/estado y matriz timestamp/estado.

Las cinco FK restrictivas son `admin_auth_operations_requested_by_profile_id_fkey`, `admin_auth_operations_completed_by_profile_id_fkey` y `admin_auth_operations_target_profile_id_fkey` hacia `profiles(id)`, más `admin_auth_operations_profile_audit_event_id_fkey` y `admin_auth_operations_auth_audit_event_id_fkey` hacia `admin_audit_events(id)`. Los nueve CHECK son `admin_auth_operations_operation_check`, `admin_auth_operations_status_check`, `admin_auth_operations_stage_check`, `admin_auth_operations_reason_check`, `admin_auth_operations_attempt_check`, `admin_auth_operations_error_check`, `admin_auth_operations_stage_operation_check`, `admin_auth_operations_evidence_check` y `admin_auth_operations_timestamp_check`. Sus definiciones decompiladas coinciden con las matrices y allowlists de 0010.

Los cinco índices son:

- `admin_auth_operations_pkey`;
- `admin_auth_operations_request_id_key`;
- `admin_auth_operations_target_status_idx`;
- `admin_auth_operations_actor_requested_idx`;
- `admin_auth_operations_one_nonfinal_target_uidx`.

La restricción `request_id` usa físicamente `admin_auth_operations_request_id_key`; no existe el índice duplicado heredado `admin_auth_operations_request_id_uidx`. El índice parcial único incluye exclusivamente `open`, `processing` y `retryable_failure`.

La tabla tiene RLS habilitado y no forzado, cero políticas cliente y cero ACL explícito de columna. Sus ocho entradas ACL directas pertenecen sólo a `postgres`: `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER` y `MAINTAIN`. No existe privilegio directo para `PUBLIC`, `anon`, `authenticated`, `service_role` u otro grantee.

## 5. Triggers y guarda de estado

La tabla tiene exactamente dos triggers no internos:

- `guard_admin_auth_operation_b3a`: `BEFORE INSERT OR DELETE OR UPDATE`, por fila, dirigido a `guard_admin_auth_operation_b3a()`;
- `guard_admin_auth_operation_truncate_b3a`: `BEFORE TRUNCATE`, por sentencia, dirigido a la misma función.

El hash del trigger owner-only coincide con 0010. Su contrato deniega operaciones destructivas, exige un writer interno conocido y aplica la allowlist de columnas y transiciones correspondiente a `prepare`, `claim`, `record` o `finalize`. No se añadió una ruta DML cliente o de servicio directo.

## 6. Seis funciones B.3a

No existe sobrecarga inesperada. Las seis funciones pertenecen a `postgres`, usan PL/pgSQL, son `SECURITY DEFINER` y fijan `search_path = pg_catalog, public`.

| Firma | Volatilidad | Argumentos de identidad | Resultado, en orden | Hash normalizado |
| --- | --- | --- | --- | --- |
| `guard_admin_auth_operation_b3a()` | `VOLATILE` | ninguno | `trigger` | `b4f997c0089a103737539c380c0c05d1` |
| `get_admin_account_auth_lifecycle_context_b3a(uuid)` | `STABLE` | `requested_profile_id uuid` | `target_profile_id uuid`, `account_kind text`, `account_status text`, `is_self boolean`, `can_deactivate boolean`, `can_reactivate boolean`, `denial_code text`, `has_exact_b1_assignment boolean`, `active_exact_b1_admin_count bigint`, `current_or_future_assignment_count bigint`, `open_responsibility_count bigint`, `open_participation_count bigint`, `b3a_available boolean`, `current_operation_id uuid`, `operation_code text`, `operation_status text`, `completed_stage text`, `attempt_count integer`, `retryable boolean`, `last_error_code text`, `operation_updated_at timestamp with time zone`, `can_retry_or_finalize boolean` | `44fd317ebc207cbf572551835fb9be7d` |
| `prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)` | `VOLATILE` | `requested_profile_id uuid`, `requested_transition text`, `transition_reason text`, `request_id uuid` | `operation_id uuid`, `target_profile_id uuid`, `operation_code text`, `status text`, `completed_stage text`, `attempt_count integer`, `retryable boolean`, `last_error_code text`, `updated_at timestamp with time zone` | `2d8d580677411110fb9255fcced4c715` |
| `finalize_admin_account_auth_reactivation_b3a(uuid)` | `VOLATILE` | `requested_operation_id uuid` | `operation_id uuid`, `target_profile_id uuid`, `status text`, `completed_stage text`, `profile_audit_event_id uuid`, `auth_audit_event_id uuid`, `completed_at timestamp with time zone` | `496707f95d11ca6d9b75c1b3f43a3c6b` |
| `claim_admin_auth_operation_b3a(uuid,uuid)` | `VOLATILE` | `requested_operation_id uuid`, `caller_profile_id uuid` | `operation_id uuid`, `target_profile_id uuid`, `operation_code text`, `status text`, `completed_stage text`, `attempt_count integer`, `retryable boolean`, `last_error_code text`, `updated_at timestamp with time zone`, `claimed boolean` | `f100545d885836bdfcc6c6f71063f709` |
| `record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text)` | `VOLATILE` | `requested_operation_id uuid`, `caller_profile_id uuid`, `claimed_attempt_count integer`, `requested_result text`, `stable_error_code text` | `operation_id uuid`, `target_profile_id uuid`, `operation_code text`, `status text`, `completed_stage text`, `attempt_count integer`, `retryable boolean`, `last_error_code text`, `updated_at timestamp with time zone` | `0aa2e5f2d1399b086b7223dc7193c61a` |

Los tipos de retorno completos coinciden con la guarda post-DDL y el verificador. El hash agregado del mapa ordenado de las 60 firmas y cuerpos normalizados es `aced4bb933e27f11c4b40b2d60802484`.

## 7. ACL de funciones y revocación del mutador B.2b

Las funciones nuevas introducen once filas en `information_schema.routine_privileges`:

- trigger: owner solamente;
- contexto, preparación y finalización: owner más `authenticated`;
- claim y record: owner más `service_role`.

`live_acl.sql` confirma las mismas once entradas directas sin grant option. `PUBLIC`, `anon` y cualquier grantee inesperado carecen de ejecución; `authenticated` y `service_role` aparecen únicamente en las superficies previstas.

`transition_admin_account_lifecycle_b2b(uuid,text,text)` conserva cuerpo, firma, owner, lenguaje, volatilidad, seguridad y `search_path`. Su única diferencia es la revocación deliberada de `authenticated`: ahora tiene exactamente una entrada `EXECUTE` owner-only; `anon`, `authenticated` y `service_role` no lo ejecutan directamente.

Las once altas y esta revocación producen el delta neto de +10, de 137 a 147 grants de rutina. Los otros 53 objetos funcionales preexistentes conservan cuerpo, metadata y ACL.

## 8. ACL de tabla, secuencia y ACL expandida

`information_schema.table_privileges` añade siete filas owner para `admin_auth_operations`: no publica `MAINTAIN`. `live_acl.sql` sí expande esa capacidad y muestra ocho filas owner para la tabla. No se alteró privilegio de ninguna tabla preexistente.

Los seis privilegios de `system_health_id_seq` permanecen byte por byte iguales a post‑0009. El esquema usa UUID en sus tablas operativas nuevas; 0010 no introduce secuencia ni amplía acceso a la existente.

El ACL expandido añade once filas de función y ocho de tabla, y elimina la fila `authenticated` del mutador B.2b: +18 netas, de 445 a 463. La diferencia entre siete filas de `information_schema` y ocho ACL de tabla es exclusivamente la representación de `MAINTAIN` en PostgreSQL 18.

Las ACL explícitas por columna no forman parte de estos catorce artefactos. Su preservación se atribuye a la guarda post-DDL y al verificador 0010, que conservaron el hash del mapa previo; no se presenta como observación directa del snapshot especializado.

## 9. RLS y políticas

Las diecinueve tablas públicas tienen RLS habilitado y ninguna usa RLS forzado. Las 25 políticas existentes son byte por byte iguales a post‑0009. `admin_auth_operations` no tiene política: ningún cliente puede seleccionar o mutar el ledger mediante RLS.

La ausencia de una política sobre el ledger es deliberada y coincide con su ACL owner-only. El acceso confiable se limita a las funciones aprobadas y vuelve a validar autoridad o caller según el contrato B.3a.

## 10. Preservación del esquema anterior

Las dieciocho tablas preexistentes, sus 165 columnas, 80 restricciones, 43 índices, once triggers y configuración RLS conservan registros semánticamente idénticos a post‑0009. Las 25 políticas, los grants de tablas preexistentes y los grants de secuencia no cambian.

Las 54 funciones preexistentes conservan cuerpos y metadata. Sus ACL permanecen iguales salvo la revocación deliberada del mutador B.2b. Los contratos B.1, B.2a y B.2b no cambian fuera de esa frontera prevista. Los triggers de `auth.users` quedan fuera del snapshot limitado a `public`; su preservación se atribuye exclusivamente a los preflight, guardas y verificadores aprobados, no a estos artefactos vivos.

## 11. Catálogos controlados

Las 51 filas son idénticas a post‑0009 y pertenecen a los mismos once catálogos: `roles`, `divisions`, `academic_programs`, `academic_periods`, `activity_types`, `service_types`, `attention_categories`, `activity_modalities`, `activity_statuses`, `location_types` y `participant_roles`.

No se añadió catálogo de roles V2 ni capacidad de Fase C. El hash del artefacto de semillas permanece `a616d8e427e574a7584464bfa8c231d74626b878934b646228e0208967adbb71`.

## 12. Evidencia estructural frente a evidencia operativa

El smoke test productivo generó dos operaciones B.3a finales y cuatro eventos administrativos. El snapshot estructural no exporta sus filas y este informe no afirma haber observado su contenido.

La estructura, las funciones, RLS, políticas, privilegios y catálogos se sustentan por los catorce artefactos vivos. La existencia y estado final de las operaciones reales se sustentan separadamente por `0010_production_smoke_test_evidence.md`, la observación productiva del ledger y las observaciones Auth documentadas.

## 13. Generación y aceptación local del snapshot

Tres capturas de sólo lectura completaron correctamente en las herramientas de base, pero sus wrappers locales de aceptación las rechazaron:

1. una advertencia LF→CRLF enviada a stderr fue promovida por Windows PowerShell a `NativeCommandError` terminante;
2. el transporte mediante `Start-Process` rechazó el control sin conservar un diagnóstico útil;
3. el diagnóstico completo identificó whitespace final canónico en campos TSV vacíos y definiciones multilínea PostgreSQL.

Cada captura rechazada restauró desde un backup temporal el snapshot post‑0009 exacto. Un intento adicional limitado al baseline se detuvo antes de solicitar la URI porque una salida Git exitosa y vacía no pudo enlazarse a un parámetro. Ninguno de estos eventos fue un fallo de PostgreSQL, `pg_dump`, `psql` o Supabase.

La ejecución final aprobó doce artefactos sujetos a estilo y preservó `live_columns.sql` y `live_functions.sql` como artefactos canónicos crudos. Los catorce aprobaron UTF-8 estricto, contenido no vacío, ausencia de conflictos, sanitización, rutas autorizadas y hashes. La generación terminó en `2026-08-06T23:33:15Z` sin escritura remota.

## 14. Clasificación completa de diferencias

| Diferencia | Clasificación |
| --- | --- |
| +1 tabla, +18 columnas y +16 restricciones | Ledger B.3a esperado |
| +5 índices y +2 triggers | Integridad, serialización y guarda esperadas |
| +6 firmas públicas | Funciones B.3a esperadas |
| +1 tabla con RLS y 0 políticas nuevas | Frontera owner-only esperada |
| +11 grants de rutina y −1 grant B.2b | ACL funcional exacto de 0010 |
| +7 grants de tabla y +8 ACL de tabla | Owner del ledger; `MAINTAIN` sólo en ACL expandida |
| +18 ACL expandidas netas | Once funciones + ocho ledger − una B.2b |
| Políticas, secuencias y catálogos sin cambio | Contratos previos conservados |
| Cuerpos/metadata previos sin cambio | Contrato funcional post‑0009 conservado |
| Token aleatorio `\restrict`/`\unrestrict` de `pg_dump` | Diferencia ambiental inocua |
| Timestamp del metadata | Evidencia de la nueva captura aprobada |
| Whitespace crudo en columnas y funciones | Representación canónica preservada |

**Deriva inexplicada:** ninguna.

## 15. Cierre

0010 está aplicada, inmutable, verificada, probada en los checkpoints Hosted Auth y productivo, y reconciliada. Los casos 1–20 están aprobados y B.3a queda cerrada dentro de su alcance aprobado.

El rollback 0010 permanece revocado y prohibido permanentemente porque existe historia B.3a real. B.3b y Fase C continúan pendientes. `0011` es el siguiente número de migración disponible, pero no se crea en este ticket.

El proyecto desechable de la matriz podrá retirarse únicamente después de que el commit de este cierre se publique y se verifique. Esta reconciliación no realiza ese commit, push o retiro.
