# Privilegios efectivos de la base de datos

> Este documento describe el estado vivo del prototipo reconciliado. No es SQL ejecutable, no concede ni revoca privilegios y no sustituye una migración revisada.

## Fuentes y alcance

Evidencia de sólo lectura:

- `live_routine_privileges.sql`: `information_schema.routine_privileges`.
- `live_table_privileges.sql`: `information_schema.table_privileges`.
- `live_sequence_privileges.sql`: ACL expandida de secuencias.
- `live_acl.sql`: ACL expandida de `pg_proc.proacl` y `pg_class.relacl`.

Inventario: 30 funciones, 17 tablas y una secuencia; 150 grants de rutina, 476 grants de tabla, 12 grants de secuencia y 706 entradas ACL expandidas. No se observaron credenciales, datos personales ni datos operativos.

## Matriz compacta por categoría

| Categoría | Acceso observado | Acceso pretendido | Desviación | Cambio mínimo propuesto |
| --- | --- | --- | --- | --- |
| 30 funciones públicas | `EXECUTE`: `PUBLIC`, `anon`, `authenticated`, `postgres`, `service_role` | RPC actuales para `authenticated`; administración para `postgres`/`service_role` | `PUBLIC` y `anon` sobran en 30/30 | Retirar `EXECUTE` de `PUBLIC` y `anon` |
| RPC administrativos de participantes/asistencia | Mismos cinco receptores | `authenticated` con autorización interna | Ejecutables anónimamente, aunque siete rechazan por `auth.uid()`/`can_edit_activity` | Retirar `PUBLIC`/`anon`; conservar validación interna |
| `finalize_expired_attendance()` | Mismos cinco receptores | Invocación autenticada/interna | `anon`/`PUBLIC` pueden activar una mutación global vencida sin control interno | Retirar `PUBLIC`/`anon`; conservar `authenticated` mientras la aplicación lo llame |
| Tablas sensibles | Ocho privilegios ACL para `anon`, `authenticated`, `postgres`, `service_role` | Acceso por RLS y RPC según tabla | Grants de cliente mucho más amplios; `TRUNCATE`/`MAINTAIN` no son permisos por fila | Reducir `anon`; retirar utilitarios de `authenticated`; tokens sólo por RPC |
| Catálogos y semestres (11 tablas) | Ocho privilegios ACL para los cuatro roles | `SELECT` de `authenticated` | Escritura/administración concedida a clientes | Dejar `SELECT` autenticado; retirar el resto a roles cliente |
| `system_health` | Ocho privilegios ACL para los cuatro roles | `SELECT` anónimo y autenticado | `anon` tiene siete privilegios innecesarios | Dejar sólo `SELECT` a `anon`; mantener lectura autenticada |
| `system_health_id_seq` | `SELECT`, `UPDATE`, `USAGE` para los cuatro roles | Administración; clientes no insertan | `anon`/`authenticated` no la necesitan | Retirar los tres privilegios de roles cliente |
| `postgres` | Acceso total y capacidad de delegación donde corresponde | Propietario | Sin desviación confirmada | Conservar |
| `service_role` | Acceso total sin capacidad de delegación | Administración de confianza | Sin desviación confirmada; no se usa en la aplicación | Conservar y proteger su secreto |
| `authenticator` | Sin grant directo observado | Rol de conexión, no de datos | No puede evaluarse herencia sin `pg_auth_members` | No añadir grants directos |
| Otros roles | Ninguno observado | Ninguno definido | Sin desviación | Ninguno |

En las tablas, `information_schema` informa `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES` y `TRIGGER`. La ACL coincide con todas esas combinaciones y añade `MAINTAIN`. No existen grants de tabla o secuencia para `PUBLIC`.

## Privilegios de rutinas

Cada una de las 30 firmas tiene exactamente cinco receptores de `EXECUTE`. Las ACL son explícitas: no hay filas con `<default>`, por lo que el acceso de `PUBLIC` no es sólo un efecto implícito no materializado.

### RPC de mutación

| RPC | Autorización interna | Resultado de un llamador anónimo | Evaluación |
| --- | --- | --- | --- |
| `add_activity_participant(uuid,uuid,text)` | `can_edit_activity` y validación de programa/rol | Rechazado | Grant anónimo innecesario |
| `remove_activity_participant(uuid)` | `can_edit_activity` | Rechazado | Grant anónimo innecesario |
| `update_activity_participant_attendance(uuid,text,text)` | `can_edit_activity` | Rechazado | Grant anónimo innecesario |
| `update_activity_participants_attendance_bulk(uuid,uuid[],text,text)` | `can_edit_activity` | Rechazado | Grant anónimo innecesario |
| `open_activity_attendance_checkin(uuid)` | `can_edit_activity`, estado y horario | Rechazado | Grant anónimo innecesario |
| `close_activity_attendance_checkin(uuid)` | `can_edit_activity` | Rechazado | Grant anónimo innecesario |
| `check_in_activity(text)` | Participante con `profile_id = auth.uid()` | Rechazado después de buscar el token | Grant anónimo innecesario y posible oráculo de validez |
| `finalize_expired_attendance()` | Ninguna validación de llamador | Ejecuta finalización global vencida | Exceso prioritario |

La capacidad de invocar una función y la autorización dentro de su cuerpo son controles distintos. Mantener ambos niveles es necesario: grants mínimos reducen superficie; validación interna protege incluso a usuarios autenticados que no tienen permiso sobre el objeto objetivo.

### Grants suficientes y faltantes

- `authenticated` tiene `EXECUTE` sobre todos los RPC usados por la aplicación y los helpers usados por RLS.
- No falta un grant para el funcionamiento actual.
- Funciones internas como `generate_three_word_code()` y `set_updated_at()` también son ejecutables por `authenticated`; retirar ese acceso puede ser correcto, pero debe esperar la verificación de consumidores externos y no es requisito del 0002 inicial.
- Las firmas heredadas conservan `EXECUTE` autenticado; no deben eliminarse ni restringirse todavía sólo porque la aplicación actual no las llame.

## Privilegios de tablas

### Tablas sensibles

`profiles`, `role_assignments`, `activities`, `activity_participants` y `activity_checkin_tokens` conceden los ocho privilegios ACL a `anon` y `authenticated`. No hay grant a `PUBLIC`.

RLS evita que `anon` lea o modifique filas porque no existen políticas anónimas para esas tablas. Esto significa que el snapshot no confirma exposición directa de filas. No obstante:

- `TRUNCATE` no expresa autorización por fila.
- `MAINTAIN`, `TRIGGER` y `REFERENCES` no son necesarios para clientes de la aplicación.
- `activity_checkin_tokens` no tiene políticas directas y se consume mediante RPC; el acceso de tabla autenticado es innecesario.

### Catálogos

Tablas de lectura autenticada:

- `academic_periods`
- `academic_programs`
- `activity_modalities`
- `activity_statuses`
- `activity_types`
- `attention_categories`
- `divisions`
- `location_types`
- `participant_roles`
- `roles`
- `service_types`

Las políticas permiten únicamente SELECT a `authenticated`, pero los grants incluyen escritura y capacidades utilitarias para `anon` y `authenticated`. El acceso mínimo vigente es SELECT autenticado; futuras pantallas administrativas deberán recibir permisos explícitos cuando se diseñen.

### Salud del sistema

La política anónima SELECT de `system_health` es deliberada y contiene sólo una señal técnica. El grant correcto para `anon` es SELECT; los otros privilegios observados son excesivos.

## Privilegios de secuencia

Sólo existe `public.system_health_id_seq`. El resto del esquema usa UUID, de modo que no hay secuencias asociadas a perfiles, roles, actividades, participantes o tokens.

`anon` y `authenticated` no insertan registros de salud y no necesitan `SELECT`, `UPDATE` o `USAGE` sobre la secuencia. `postgres` y `service_role` pueden conservarlos para administración del prototipo.

## Consistencia ACL

- Las 150 combinaciones de rutina coinciden entre `information_schema` y ACL.
- Las 476 combinaciones de tabla coinciden; ACL agrega 68 entradas `MAINTAIN` (17 objetos × 4 roles).
- Las 12 combinaciones de secuencia coinciden.
- Las 706 entradas ACL tienen valor explícito; no se observó una ACL predeterminada materializada como `<default>`.
- `PUBLIC` aparece sólo en funciones, con `EXECUTE`.
- `authenticator` no aparece como receptor directo. Sin un snapshot de `pg_auth_members` no se afirma ni se niega acceso heredado.

## Perfil mínimo recomendado

| Rol | Rutinas | Tablas | Secuencias |
| --- | --- | --- | --- |
| `anon` | Ninguna rutina SITAA | `system_health.SELECT` | Ninguna |
| `authenticated` | RPC y helpers actuales | Catálogos SELECT; `profiles` SELECT/UPDATE; `role_assignments` SELECT; `activities` CRUD bajo RLS; contrato actual de participantes bajo RLS | Ninguna |
| `service_role` | Todas para administración | Todas | `system_health_id_seq` |
| `postgres` | Propietario | Propietario | Propietario |
| `PUBLIC` | Ninguna | Ninguna | Ninguna |
| `authenticator` | Sin grant directo | Sin grant directo | Sin grant directo |

## Correcciones propuestas para 0002

La futura migración debe incluir únicamente correcciones confirmadas por estos snapshots:

1. Retirar `EXECUTE` de todas las funciones públicas a `PUBLIC` y `anon`, conservando los grants actuales de `authenticated`, `service_role` y `postgres`.
2. Retirar todos los privilegios de tabla de `anon` y conceder de nuevo sólo `system_health.SELECT`.
3. Retirar `TRUNCATE`, `REFERENCES`, `TRIGGER` y `MAINTAIN` de todas las tablas a `authenticated`.
4. Dejar los once catálogos en SELECT autenticado; retirar sus grants de escritura.
5. Dejar `role_assignments` en SELECT y `profiles` en SELECT/UPDATE para `authenticated`.
6. Retirar acceso directo autenticado a `activity_checkin_tokens`.
7. Retirar `SELECT`, `UPDATE` y `USAGE` de `system_health_id_seq` a `anon` y `authenticated`.
8. Mantener por ahora el acceso de `technical_admin`; no forma parte de la corrección de ACL de roles PostgreSQL.
9. No retirar overloads, columnas ni capacidades reservadas.

Antes de aplicar 0002 deben probarse login, panel, perfil, actividades, participantes, asistencia manual, QR/código, `/supabase-test` y las políticas RLS mediante los roles `anon` y `authenticated`. Los grants de `postgres` y `service_role` quedan fuera de este ajuste inicial.

## Perfil materializado en la migración 0002

`0002_database_security_and_integrity.sql` materializa el perfil mínimo anterior de forma explícita:

- revoca `EXECUTE` de todas las funciones públicas a `PUBLIC` y `anon`;
- conserva los grants existentes de `authenticated`, `service_role` y propietario, y concede la nueva `publish_activity(uuid)` a `authenticated`/`service_role`;
- revoca todos los privilegios de tabla de roles cliente y concede de nuevo sólo el contrato documentado;
- deja a `anon` únicamente `system_health.SELECT`;
- deja `activity_checkin_tokens` sin privilegio directo autenticado;
- revoca la secuencia `system_health_id_seq` a `anon` y `authenticated`;
- no toca grants de `postgres`, `service_role`, `authenticator` ni privilegios predeterminados.

**Estado:** definición creada y acompañada por verificación/rollback; no aplicada al proyecto Supabase vivo. La matriz observada al inicio de este documento sigue describiendo el prototipo vivo hasta que una nueva captura demuestre la aplicación.
