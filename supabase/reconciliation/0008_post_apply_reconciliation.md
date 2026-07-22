# Cierre de reconciliación posterior a 0008

**Fecha de reconciliación:** 2026-07-21 (`America/Mexico_City`)

**Snapshot:** `2026-07-22T01:46:13Z`

**Estado declarado:** `SUCCESS`

**Cadena incluida:** `0001 + 0002 + 0003 + 0004 + 0005 + 0006 + 0007 + 0008`

**Resultado:** reconciliado sin deriva inexplicada; Fase B.2a cerrada dentro de su alcance aprobado.

Este informe compara localmente el snapshot post-0007 del commit `fc197ba` con el conjunto vivo post-0008 ya generado, la migración 0008 inmutable y el contrato final de su verificador. No se estableció conexión con Supabase, no se ejecutó SQL, no se invocó `psql`, `pg_dump`, Supabase CLI ni el script de snapshot, y no se regeneró ni editó ningún artefacto vivo.

## Integridad del snapshot

Los 14 artefactos obligatorios existen, tienen contenido, forman una secuencia de publicación coherente y están codificados como UTF-8 estricto. El metadata se escribió al final del conjunto y declara:

- generación UTC `2026-07-22T01:46:13Z`;
- estado `SUCCESS` y propósito exclusivo de reconciliación sin escrituras remotas;
- `pg_dump 18.4` y `psql 18.4` nativos;
- `client_encoding = UTF8`;
- dump principal limitado a `public`, sólo esquema, sin ownership ni privilegios;
- cuatro capturas separadas de privilegios;
- semillas limitadas a catálogos controlados y exclusión de datos operativos/personales.

No hay archivos parciales o de tamaño cero, resultados de diagnóstico adicionales ni marcador de fallo del proceso. La palabra controlada `failure` que aparece en una restricción del resultado de auditoría no es un marcador de generación. No se encontraron URI de conexión, contraseñas, tokens, cookies, JWT, claves API, secretos OAuth, correos, identificadores ni filas de usuarios, perfiles, asignaciones, actividades, participantes, asistencia, tokens de check-in o auditoría administrativa.

### Huellas SHA-256 de la evidencia viva

| Artefacto | SHA-256 |
| --- | --- |
| `live_schema.sql` | `43079f2f71f78aaa6d311ff0b19f07597c14737385b20533fa81ddf04beda5ad` |
| `live_tables.sql` | `030587f4d2ca22c160a3603851a2f4d1c6555c127fcbffe8a4e90cfbce01a147` |
| `live_columns.sql` | `59ed2ccd538345bf27b00944a77fd8cbedecd806081903cbc2aa83477fb1344b` |
| `live_constraints.sql` | `ef78721a26298617d1e8e47ea04899844222f6e929fa3845124d4824228d11d8` |
| `live_indexes.sql` | `3dd63abd41aa855d6067a71ae019907bff774254ca106e6443980cd8d203e8cc` |
| `live_triggers.sql` | `0dc9534f7858e8e1ae617831d85f1fdc3d522cc6dc53c17bd7a93374b302ac59` |
| `live_functions.sql` | `b1e2002ba32382b29e249467d18f984040de0c6b0d571a166985a3121eacd490` |
| `live_policies.sql` | `b85eb2db46264611fa299387cbae2b20c0fbdfb3bf5cfbec50075563cfbfbbfd` |
| `live_routine_privileges.sql` | `4bee2ef0065e2587ff0cbcb9a0539529b246710df83d1e89117773e7947eb4e1` |
| `live_table_privileges.sql` | `8a8c0cab0e0a98fb846a53258f9a1378ad086c861d3cd8313d6eecb8ab1c1ac9` |
| `live_sequence_privileges.sql` | `766f7fec6f054f790fe4aa824933c57858747876da8bd983c2b2715ff2bfe281` |
| `live_acl.sql` | `28869346ece672937838e0016913f27d782447f61b26a7ed7aac7d89d8b72e90` |
| `live_seed_catalogs.sql` | `a616d8e427e574a7584464bfa8c231d74626b878934b646228e0208967adbb71` |
| `live_snapshot_metadata.txt` | `e373b0d906dd8a7ec1ede0985eba32bd9a4730017c56c7b4bfc15e58b2a68452` |

La huella SHA-256 de la migración aplicada e inmutable `0008_operational_account_barrier_identity_correction.sql` es `9e5f05ef02f81e62a31e19ad4c7a693f323c0a4936cbf816fd3757295fb11c17`.

## Inventario post-0007 frente a post-0008

| Categoría | Post-0007 | Post-0008 | Delta observado | Delta esperado | Clasificación |
| --- | ---: | ---: | ---: | ---: | --- |
| Tablas públicas | 18 | 18 | 0 | 0 | Sin cambio físico |
| Columnas | 165 | 165 | 0 | 0 | Sin cambio físico |
| Restricciones PK/FK/UNIQUE/CHECK | 80 | 80 | 0 | 0 | Sin cambio físico |
| Índices, incluidos los respaldados por restricciones | 43 | 43 | 0 | 0 | Sin cambio físico |
| Triggers no internos sobre tablas públicas | 10 | 11 | +1 | +1 | Cambio esperado de 0008 |
| Firmas de función públicas | 47 | 51 | +4 | +4 | Cambio esperado de 0008 |
| Políticas RLS | 23 | 25 | +2 | +2 | Cambio esperado de 0008 |
| Tablas públicas con RLS habilitado | 18 | 18 | 0 | 0 | Contrato conservado |
| Semillas controladas | 51 | 51 | 0 | 0 | Contrato conservado |
| Grants de rutina | 125 | 132 | +7 | +7 | Cambio esperado de privilegios |
| Grants de tabla publicados por `information_schema` | 270 | 267 | −3 | −3 | Cambio esperado de privilegios |
| Grants de secuencia | 6 | 6 | 0 | 0 | Contrato conservado |
| Entradas ACL expandidas | 436 | 440 | +4 | +4 | Delta neto esperado |

Las 80 restricciones se descomponen en 18 PK, 30 FK, 4 UNIQUE y 28 CHECK. Las 18 tablas tienen RLS habilitado y ninguna usa RLS forzado. No cambió ninguna de esas filas respecto de post-0007.

## Tablas, columnas, restricciones e índices

`live_tables.sql`, `live_columns.sql`, `live_constraints.sql` y `live_indexes.sql` son idénticos a la evidencia post-0007. En particular:

- `profiles` conserva el contrato post-0007;
- `role_assignments` conserva su estructura V1 y no incorpora revocación/delegación de Fase C;
- `activities` y `activity_participants` conservan columnas y restricciones;
- `admin_audit_events` conserva exactamente su forma física 0007;
- no aparecen campos nuevos de ciclo de cuenta, capacidades reservadas ni roles de catálogo.

0008 no crea tablas, columnas, restricciones, índices o secuencias. Su barrera y corrección se implementan en funciones, políticas, trigger y ACL.

## Funciones y contratos

### Cuatro firmas nuevas

| Firma | Contrato vivo | ACL directo |
| --- | --- | --- |
| `is_sitaa_operational_account_active()` | `boolean`; SQL, `STABLE`, `SECURITY DEFINER`, `search_path = pg_catalog, public` | owner + `authenticated` |
| `get_admin_identity_correction_context_b2a(uuid)` | entrada `requested_profile_id`; salidas en orden: `target_profile_id uuid`, `can_correct boolean`, `denial_code text`, `account_kind text`, `account_status text`, `is_self boolean`, `current_or_future_assignment_count bigint`, `open_responsibility_count bigint`, `open_participation_count bigint`; PL/pgSQL, `STABLE`, `SECURITY DEFINER`, `search_path = pg_catalog, public` | owner + `authenticated` |
| `correct_admin_account_identity_b2a(uuid,text,text,text,text,text,uuid,text)` | 8 entradas nominales; tabla `target_profile_id`, `audit_event_id`, `changed_fields`, `updated_at`; PL/pgSQL, `VOLATILE`, `SECURITY DEFINER`, `search_path = pg_catalog, public` | owner + `authenticated` |
| `enforce_activity_writer_integrity_b2a()` | `trigger`; PL/pgSQL, `VOLATILE`, `SECURITY DEFINER`, `search_path = pg_catalog, public` | sólo owner |

No existe otra sobrecarga de estas funciones. `PUBLIC`, `anon` y `service_role` no reciben `EXECUTE` directo sobre las cuatro; `authenticated` no tiene grant option. Los cuerpos normalizados coinciden con los hashes exactos del verificador final: `f85f733578f09c0f7466af7e18a90f4c`, `83932d04ff8f1b33793e8c7a49bb8e68`, `ce05cbc529473c070953e765e3ee05b2` y `c58bd04859f1e2a044fcca58d3333e3c`, respectivamente.

### Veintinueve firmas reforzadas

Las siguientes firmas post-0007 permanecen con firma y ACL exactos, pero sus cuerpos incorporan la barrera de cuenta activa esperada: `activity_attendance_deadline(uuid)`, `activity_attendance_open_at(uuid)`, `activity_has_ended(uuid)`, `add_activity_participant(uuid,uuid,text)`, las dos sobrecargas de `can_create_activity`, `can_delete_activity(uuid)`, `can_edit_activity(uuid)`, las dos sobrecargas de `can_manage_activity`, `can_read_activity(uuid)`, `can_update_activity_base(uuid)`, `check_in_activity(text)`, `close_activity_attendance_checkin(uuid)`, `finalize_expired_attendance()`, `generate_three_word_code()`, `get_active_activity_attendance_checkin(uuid)`, `get_activity_attendance_checkin_state(uuid)`, `get_activity_participants(uuid)`, `get_visible_activity_cards()`, `has_active_role(text)`, `has_any_active_role(text[])`, `is_activity_participant(uuid)`, `open_activity_attendance_checkin(uuid)`, `publish_activity(uuid)`, `remove_activity_participant(uuid)`, `search_profiles_for_participation(uuid,text)`, `update_activity_participant_attendance(uuid,text,text)` y `update_activity_participants_attendance_bulk(uuid,uuid[],text,text)`.

Los 29 hashes vivos, después de eliminar whitespace con el mismo dominio usado por el verificador, coinciden exactamente con el mapa final de 0008. No falta ninguna firma y no existe una sobrecarga extra.

### Dieciocho firmas exentas y conservadas

Permanecen sin cambio de cuerpo, metadata o ACL: `admin_audit_metadata_is_safe(jsonb)`, `complete_own_google_registration(text,text,text,text,text,uuid)`, `complete_own_google_registration(text,text,text,uuid)`, `enforce_sitaa_profile_identity()`, `get_academic_period_for_date(date)`, `get_admin_account_assignments_b1(uuid)`, `get_admin_account_audit_history_b1(uuid,integer,integer)`, `get_admin_account_detail_b1(uuid)`, `guard_activity_participant_pending_deadline()`, `handle_sitaa_auth_user_created()`, `is_b1_account_admin()`, `normalize_sitaa_profile_names()`, `prevent_admin_audit_event_mutation()`, `search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)`, `set_updated_at()`, `sitaa_current_mexico_date()`, `sync_sitaa_profile_email_from_auth()` y `validate_activity_scheduled_state()`.

`is_b1_account_admin()` continúa owner-only. Las RPC B.1/B.2a `SECURITY DEFINER` lo invocan internamente; `authenticated` no tiene `EXECUTE` directo. `admin_audit_metadata_is_safe(jsonb)` conserva su excepción controlada para `service_role`. La auditoría sigue append-only y 0008 no altera los triggers canónicos de `auth.users`.

## Trigger de integridad

El único trigger nuevo es `public.activities.enforce_activity_writer_integrity_b2a`: `BEFORE INSERT OR UPDATE`, por fila, habilitado y conectado exactamente a `public.enforce_activity_writer_integrity_b2a()`. No existe duplicado y ninguno de los diez triggers post-0007 desapareció o cambió.

El cuerpo vivo conserva el contrato de 0008: impide sustituir silenciosamente creador o responsable, revalida alcance y compatibilidad de participantes, y prohíbe a un cliente autenticado reabrir una actividad histórica. Un writer confiable que reabra historia también debe revalidar responsabilidad y participantes.

## RLS y políticas

Las 18 tablas públicas conservan RLS habilitado. Las 23 políticas post-0007 permanecen semánticamente idénticas. Las dos políticas nuevas son exactamente:

- `Active accounts may operate activities` sobre `public.activities`;
- `Active accounts may operate activity participants` sobre `public.activity_participants`.

Ambas son `RESTRICTIVE`, para `authenticated`, comando `ALL`, y usan `is_sitaa_operational_account_active()` tanto en `USING` como en `WITH CHECK`. No se añadió política administrativa directa a `profiles`, `role_assignments` o `admin_audit_events`; esta última sigue sin política cliente.

## Privilegios y ACL

Los tres objetos nuevos invocables suman seis grants de rutina —owner + `authenticated`— y el trigger owner-only suma uno: +7. En `activity_participants`, `authenticated` conserva sólo `SELECT`; se retiraron `INSERT`, `UPDATE` y `DELETE`: −3 grants de tabla. No hay acceso de `anon`/`PUBLIC`, grantee personalizado ni grant option delegado. El propietario conserva el contrato completo y `service_role` conserva su contrato confiable completo.

El verificador 0008 complementa la evidencia del snapshot para ACL de columna: `pg_attribute.attacl` debe estar vacío, las filas de `information_schema.column_privileges` deben derivarse del ACL de tabla y `has_column_privilege` no puede superar `has_table_privilege`. No se observó un delta de secuencia y las seis entradas existentes son irrelevantes para el esquema UUID sin identidades nuevas.

Los totales vivos 132/267/6/440 y su delta +7/−3/0/+4 coinciden exactamente. `MAINTAIN` puede aparecer en ACL expandida sin publicarse en `information_schema.table_privileges`; es una diferencia de representación PostgreSQL conocida, no un privilegio faltante.

## Catálogos y frontera de datos

Las 51 semillas controladas son idénticas a post-0007: 5 semestres, 2 programas, 3 modalidades, 6 estados, 5 tipos de actividad, 5 categorías, 1 división, 7 ubicaciones, 5 roles de participante, 10 roles institucionales y 2 servicios.

No se exportaron Auth users, identidades, perfiles, asignaciones, actividades, participantes, asistencia, tokens, auditoría, motivos de corrección, identificadores, nombres o correos. No se incorporó un rol nuevo ni una capacidad V2/reservada.

## Aplicación, verificador y smoke tests

- El preflight final devolvió sus 40 categorías, con 35 bloqueos en cero, y terminó con `ROLLBACK`.
- La aplicación compatible se publicó antes de aplicar la migración.
- 0008 terminó con `COMMIT` y su artefacto es inmutable.
- Dos intentos del verificador fueron descartados íntegramente por defectos del arnés: primero una llamada cliente al helper owner-only y después postcondiciones crudas todavía bajo `authenticated`.
- El verificador final separó correctamente límites owner/cliente, aprobó el contrato estructural y funcional y terminó con `ROLLBACK`; no persistieron fixtures, grants temporales, correcciones o auditoría sintética.
- Los smoke tests aprobaron la corrección de identidad y el evento append-only sanitizado.
- El defecto de composición exclusivo de aplicación para un responsable histórico entre programas se corrigió: participantes/asistencia usan `can_edit_activity(uuid)`, datos base usan `can_update_activity_base(uuid)` y eliminación usa `can_delete_activity(uuid)`. Valores `NULL` o inválidos fallan cerrados; borradores y alumnos no reciben controles administrativos; las mutaciones de participantes permanecen en RPC y no existe writer directo de `activity_participants`.
- La reejecución del smoke test de responsable histórico aprobó. `npm run check:permissions` forma parte del contrato de build.

El verificador transaccional y el contrato estático aprobaron. La matriz manual de concurrencia en dos sesiones no se ejecutó en producción y no se afirma observación manual de concurrencia PostgreSQL; permanece restringida a un entorno desechable completo y no bloquea este cierre.

## Clasificación completa de diferencias

| Diferencia | Clasificación |
| --- | --- |
| +1 trigger, +4 firmas y +2 políticas | Cambio estructural esperado de 0008 |
| +7 grants de rutina, −3 grants de tabla y +4 ACL netas | Cambio de privilegio esperado de 0008 |
| Cuerpos reforzados de 29 funciones con firma/ACL conservados | Cambio funcional esperado de 0008 |
| Tablas, columnas, restricciones, índices, RLS físico, secuencias y semillas sin cambio | Contrato post-0007 conservado |
| Timestamp del snapshot y token aleatorio `\restrict`/`\unrestrict` | Diferencia ambiental inocua |
| Omisión textual opcional de `SECURITY INVOKER` | Diferencia de representación inocua; la autoridad se valida semánticamente con `pg_proc.prosecdef` |
| `MAINTAIN` visible en ACL expandida pero no en `information_schema.table_privileges` | Diferencia de representación PostgreSQL inocua |
| Espacios finales, saltos CRLF y formato emitidos por `psql`/`pg_dump` | Diferencia ambiental inocua del artefacto generado |
| Datos operativos posteriores al snapshot anterior | Diferencia controlada no exportada ni inspeccionada |

**Deriva inexplicada:** ninguna.

## Conclusión

El estado vivo queda reconciliado contra `0001`–`0008` sin diferencias no explicadas. 0008 está aplicada, verificada, probada, reconciliada e inmutable. Fase B.2a queda cerrada dentro de su alcance aprobado: barrera operativa de cuenta activa, corrección administrativa auditada de identidad, cierre del DML cliente de participantes e integridad de writers de actividades.

Las migraciones 0001–0008 son historia inmutable. `0009` es el siguiente número disponible; B.2b, B.3 y Fase C siguen pendientes y cualquier cambio posterior requiere una migración nueva.
