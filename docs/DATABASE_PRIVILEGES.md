# Privilegios efectivos de la base de datos

> Este documento describe el estado vivo posterior a 0002 y 0003. No es SQL ejecutable y no concede ni revoca privilegios.

**Fecha de reconciliación:** 2026-07-16.

**Snapshot:** `2026-07-17T00:21:06Z`.

## Evidencia

- `live_routine_privileges.sql`: `information_schema.routine_privileges`.
- `live_table_privileges.sql`: `information_schema.table_privileges`.
- `live_sequence_privileges.sql`: ACL expandida de secuencias.
- `live_acl.sql`: ACL expandida de `pg_proc.proacl` y `pg_class.relacl`.

Los cuatro artefactos son concordantes: 99 grants de rutina, 262 de tabla, 6 de secuencia y 401 entradas ACL expandidas. No se observaron credenciales ni datos personales u operativos.

## Matriz compacta

| Categoría | `anon` | `authenticated` | `PUBLIC` | `postgres` / `service_role` | Resultado |
| --- | --- | --- | --- | --- | --- |
| 33 funciones públicas | Ninguna | `EXECUTE` en las 33 firmas | Ninguna | `EXECUTE` en las 33 firmas | Coincide con 0002 |
| 11 catálogos y semestres | Ninguna | `SELECT` | Ninguna | Administración | Coincide con 0002 |
| `profiles` | Ninguna | `SELECT`, `UPDATE`, limitados por RLS | Ninguna | Administración | Coincide con 0002 |
| `role_assignments` | Ninguna | `SELECT`, limitado por RLS | Ninguna | Administración | Coincide con 0002 |
| `activities` | Ninguna | `SELECT`, `INSERT`, `UPDATE`, `DELETE`, limitados por RLS | Ninguna | Administración | Coincide con 0002 |
| `activity_participants` | Ninguna | `SELECT`, `INSERT`, `UPDATE`, `DELETE`, limitados por RLS | Ninguna | Administración | Coincide con 0002 |
| `activity_checkin_tokens` | Ninguna | Ninguna; acceso sólo mediante RPC | Ninguna | Administración | Coincide con 0002 |
| `system_health` | `SELECT` | `SELECT` | Ninguna | Administración | Acceso público deliberado y limitado |
| `system_health_id_seq` | Ninguna | Ninguna | Ninguna | `SELECT`, `UPDATE`, `USAGE` | Coincide con 0002 |

`authenticator` no aparece como receptor directo. El snapshot no incluye membresías de roles, por lo que no se infiere acceso heredado más allá de la evidencia disponible.

## Rutinas y autorización interna

Las 33 firmas sólo conceden `EXECUTE` a `authenticated`, `postgres` y `service_role`. No existe `EXECUTE` efectivo para `anon` o `PUBLIC`, incluido en:

- `add_activity_participant`
- `remove_activity_participant`
- `update_activity_participant_attendance`
- `update_activity_participants_attendance_bulk`
- `open_activity_attendance_checkin`
- `close_activity_attendance_checkin`
- `check_in_activity`
- `finalize_expired_attendance`
- `publish_activity`

La capacidad de ejecutar una RPC no sustituye su autorización interna. Las funciones administrativas siguen comprobando sesión, creador, permisos de actividad, participante, estado y horario según corresponda. `authenticated` conserva también `EXECUTE` en helpers y funciones internas heredadas; este contrato fue preservado deliberadamente por 0002 para no romper consumidores no inventariados.

## Tablas y secuencia

- `anon` tiene un único grant de tabla: `system_health.SELECT`.
- `authenticated` tiene 23 grants directos, exactamente los necesarios para catálogos, perfil propio, roles propios, actividades y participantes bajo RLS, más la lectura de salud.
- `activity_checkin_tokens` carece de acceso directo cliente.
- `system_health_id_seq` sólo concede tres privilegios a `postgres` y tres a `service_role`; el esquema operativo restante usa UUID.
- `postgres` y `service_role` conservan el acceso administrativo previsto.

No se confirmó un grant faltante para los flujos actuales ni un exceso cliente respecto del perfil mínimo materializado por 0002.

## Estado de hallazgos

- **A-05, resuelto por 0002:** no hay `EXECUTE` de `PUBLIC` o `anon` sobre funciones SITAA.
- **A-06, resuelto por 0002:** grants de tablas y secuencia se redujeron al contrato mínimo confirmado.
- **A-02, diferido:** el alcance académico de `technical_admin` es una decisión de autorización de aplicación/RLS, no un grant PostgreSQL pendiente. **Deferred intentionally until user, role and permission administration is designed.**

## Cambios futuros

Cualquier ajuste posterior de privilegios debe partir de nueva evidencia viva, usar una migración a partir de `0004`, conservar validación interna en RPC y acompañarse de verificación negativa para `anon`, `PUBLIC` y usuarios autenticados fuera de alcance. No deben inferirse ni añadirse grants desde este documento.
