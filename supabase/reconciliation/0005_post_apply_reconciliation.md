# Cierre de reconciliación posterior a 0005

**Snapshot:** `2026-07-17T23:20:07Z`

**Cadena incluida:** `0001`–`0005`

**Resultado:** reconciliado, sin deriva inexplicada.

## Evidencia revisada

Se inspeccionaron, sin modificarlos, `live_schema.sql`, `live_tables.sql`, `live_columns.sql`, `live_constraints.sql`, `live_indexes.sql`, `live_triggers.sql`, `live_functions.sql`, `live_policies.sql`, `live_routine_privileges.sql`, `live_table_privileges.sql`, `live_sequence_privileges.sql`, `live_acl.sql`, `live_seed_catalogs.sql` y `live_snapshot_metadata.txt`.

El metadata informa `SUCCESS`, PostgreSQL 18.4, codificación UTF8, alcance de esquema `public` y generación de sólo lectura. Los catorce artefactos requeridos existen, contienen datos cuando corresponde y no hay archivos temporales, marcadores de ejecución fallida, URI de conexión, credenciales, tokens ni correos personales u operativos.

## Resultado estructural

| Evidencia | Resultado |
| --- | --- |
| Tablas | 17; coincidencia exacta con la cadena versionada |
| Columnas | 156; coincidencia exacta con 0001 más las adiciones de 0004 |
| Restricciones | 68; coincide el estado final. La restricción heredada `profiles_person_identifier_consistency_check` fue retirada expresamente por 0004 y sustituida por el contrato de cuenta e identidad |
| Índices | 38; coincidencia exacta de índices explícitos, primarios y únicos |
| Funciones | 37 firmas, 35 nombres; mismo inventario que 0001–0005 |
| Triggers públicos | 7; coincidencia exacta |
| Políticas RLS | 23; coincidencia exacta de nombres y reglas efectivas esperadas |
| Catálogos controlados | 51 filas; coincidencia exacta con el baseline, incluida la activación de programas añadida por 0004 |

Las quince funciones sustituidas después del baseline coinciden con sus definiciones finales de 0002–0005 después de normalizar formato de `pg_get_functiondef`. La única diferencia textual observada es que PostgreSQL omite `SECURITY INVOKER` en `enforce_sitaa_profile_identity`, porque es el valor predeterminado; no cambia su semántica.

`handle_sitaa_auth_user_created()` y `complete_own_google_registration(text,text,text,uuid)` coinciden exactamente de forma normalizada con 0005. La primera ya no exige `email_confirmed_at` durante el `INSERT` inicial de Google; la segunda exige usuario autenticado, perfil institucional pendiente, identidad Google vinculada y verificada, correos normalizados coincidentes, programa activo e identificador único. La finalización activa el perfil existente y no crea roles.

El inventario especializado de triggers se limita deliberadamente a tablas de `public`, por lo que no contiene los dos triggers de `auth.users`. Su existencia y contrato posterior a 0005 se sustentan en los preflight y verificadores transaccionales de 0004 y 0005, confirmados como aprobados por el operador. Las funciones objetivo sí están capturadas y coinciden con 0005. Esta limitación conocida de cobertura no constituye deriva.

## RLS y privilegios

- Las 17 tablas públicas conservan RLS habilitado.
- La lectura de borradores permanece limitada a `created_by = auth.uid()`; el contenido publicado conserva las reglas de gestión y participación de 0002.
- Las protecciones de publicación, ciclo temporal de borradores, participantes, asistencia vencida y check-in permanecen presentes.
- `anon` sólo tiene `SELECT` sobre `system_health`; no tiene `EXECUTE` sobre rutinas públicas.
- `authenticated` conserva lectura de catálogos y perfiles propios, operaciones RLS sobre actividades/participantes y `EXECUTE` sobre las 34 rutinas de aplicación previstas.
- Las tres funciones de trigger de identidad no son ejecutables por `anon` ni `authenticated`.
- `service_role` y `postgres` conservan los privilegios administrativos observados. No se añadió ninguna llave ni uso de `service_role` a la aplicación.
- `information_schema` y ACL expandido son consistentes. Las 34 entradas adicionales del ACL de tablas corresponden a `MAINTAIN` para `postgres` y `service_role`, privilegio que `information_schema.table_privileges` no enumera.
- La única secuencia, `system_health_id_seq`, sólo concede privilegios a `postgres` y `service_role`.
- El acceso académico transitorio de `technical_admin` se conserva intencionalmente hasta la Fase E.

## Clasificación de diferencias

| Diferencia esperada | Diferencia observada | Clasificación | Acción |
| --- | --- | --- | --- |
| Comentarios, orden y formato generados por PostgreSQL 18.4 | Omisión de `SECURITY INVOKER` predeterminado y representación de ACL `MAINTAIN` | Diferencia inocua generada por el entorno | Ninguna |
| Triggers SITAA sobre `auth.users` | Fuera del alcance `public` de `live_triggers.sql`; preflight y verificadores aprobados | Limitación conocida de cobertura, no deriva | Conservar la evidencia de verificación; ampliar un snapshot futuro sólo mediante el script versionado si se requiere |
| Separación inicial de cuentas | Cambios en perfiles y asignaciones operativas, no exportados por el snapshot controlado | Diferencia controlada de datos operativos | Documentar; no convertir en migración reutilizable |
| Registro normal de profesor mediante Google | Perfil operativo activo sin roles; no exportado | Diferencia controlada de datos operativos | Ninguna |

No se detectaron diferencias de esquema, función, trigger público, política, grant o catálogo que requieran una migración correctiva.

## Separación administrativa inicial

Se realizó una conciliación administrativa única del entorno. Un perfil institucional usado durante desarrollo se convirtió en cuenta técnica interna: se limpiaron persona, programa e identificador; `technical_admin` permaneció activo y una asignación académica/divisional temporal fue desactivada, no eliminada. Por separado, una cuenta de profesor se registró normalmente mediante Google, quedó institucional y activa, y no recibió roles.

No se transfirieron actividades, participantes, asistencias ni referencias históricas entre cuentas. Esta operación no es fusión de cuentas ni una capacidad general de migración y no debe codificarse como SQL reutilizable. La administración futura corresponde al módulo controlado de Fase B.

## Higiene de artefactos locales

Se detectaron `account_identity_audit.local.sql` y `account_identity_audit_result.local.txt`. Son archivos locales de auditoría que pueden contener identificadores o datos operativos; se conservaron sin copiarlos ni incluir su contenido en este informe. `.gitignore` los excluye mediante reglas limitadas a `supabase/reconciliation/*.local.sql` y `supabase/reconciliation/*.local.txt`. Los resultados oficiales de 0004/0005 y el snapshot live permanecen preservados.

## Verificación funcional y estado de migraciones

- **0004:** aplicada; preflight y verificador transaccional aprobados. Instaló la base de registro Google y fue sustituida únicamente en el momento de verificación temprana por 0005, sin rollback.
- **0005:** aplicada; preflight, migración y verificador transaccional aprobados. El verificador terminó con `ROLLBACK` y retiró sólo fixtures sintéticos.
- Smoke tests confirmados: Google crea la cuenta, el perfil pendiente alcanza selección/completado de identidad, la finalización de profesor funciona, el profesor queda sin roles, una cuenta activa es desviada de `/register` y la cuenta técnica conserva `technical_admin`.
- No quedaron filas Auth fallidas que requirieran limpieza.
- El login heredado por correo/contraseña permanece disponible.

## Cierre

La Fase A de identidad y Google OAuth queda implementada y operativa: registro público sólo con Google, rutas separadas de alumno/profesor, ciclo `pending_registration`, finalización institucional autenticada, activación básica automática, identificadores de dígitos almacenados como texto, ausencia de asignación automática de roles, categoría técnica y guardas de registro. No existe dependencia SMTP ni restricción de dominio.

Permanecen abiertas las fases B (administración de cuentas), C (roles V2), D (paneles y filtros según permisos), E (retiro del acceso académico transitorio de `technical_admin`) y F (check-in abierto). `0006` es el siguiente número disponible; no se crea ni se reserva para una implementación concreta en este cierre.
