# Cierre de reconciliación posterior a 0006

**Snapshot:** `2026-07-18T04:05:40Z`

**Estado declarado:** `SUCCESS`

**Cadena incluida:** `0001`–`0006`
**Resultado:** reconciliado sin deriva inexplicada

Este informe compara localmente la evidencia viva ya generada con el resultado acumulado de las migraciones. No se estableció conexión remota, no se ejecutó SQL y no se alteró el snapshot.

## Integridad del snapshot

Se inspeccionaron los 14 artefactos obligatorios:

- `live_schema.sql`;
- `live_tables.sql`;
- `live_columns.sql`;
- `live_constraints.sql`;
- `live_indexes.sql`;
- `live_triggers.sql`;
- `live_functions.sql`;
- `live_policies.sql`;
- `live_routine_privileges.sql`;
- `live_table_privileges.sql`;
- `live_sequence_privileges.sql`;
- `live_acl.sql`;
- `live_seed_catalogs.sql`;
- `live_snapshot_metadata.txt`.

Todos existen y tienen contenido. El metadata declara PostgreSQL 18.4, UTF-8, esquema `public`, generación de sólo esquema y estado `SUCCESS`. No hay marcadores `FAILURE`, archivos temporales/parciales ni patrones de credenciales o URI de conexión. Los archivos especializados concuerdan entre sí en nombres de objetos, RLS, constraints, triggers, firmas, políticas y ACL.

## Inventario vivo

| Categoría | Posterior a 0005 | Posterior a 0006 | Variación |
| --- | ---: | ---: | ---: |
| Tablas públicas | 17 | 17 | 0 |
| Columnas | 156 | 156 | 0 |
| Restricciones | 68 | 72 | +4 |
| Índices | 38 | 38 | 0 |
| Triggers públicos | 7 | 8 | +1 |
| Firmas de función | 37 | 39 | +2 |
| Políticas RLS | 23 | 23 | 0 |
| Tablas con RLS | 17 | 17 | 0 |
| Semillas controladas | 51 | 51 | 0 |
| Grants de rutina | 108 | 112 | +4 |
| Grants de tabla | 261 | 261 | 0 |
| Grants de secuencia | 6 | 6 | 0 |
| Entradas ACL expandidas | 409 | 413 | +4 |

La variación corresponde al alcance de 0006: cuatro constraints de nombre/identidad, el trigger normalizador, `normalize_sitaa_profile_names()`, la firma estructurada de finalización y sus ACL, compensadas por retirar `authenticated` de la firma anterior. No hay cambios de tablas, columnas, índices, políticas, catálogos ni privilegios operativos ajenos a identidad.

Los catálogos conservan 51 filas: 5 semestres, 2 programas, 3 modalidades, 6 estados, 5 tipos de actividad, 5 categorías de atención, 1 división, 7 ubicaciones, 5 roles de participante, 10 roles institucionales y 2 servicios.

## Contrato de nombres estructurados

La evidencia confirma:

- `profiles.first_names`, `paternal_surname` y `maternal_surname` son columnas `text`;
- `full_name` continúa disponible;
- `maternal_surname` admite `NULL`;
- el constraint de identidad exige nombre(s) y apellido paterno para cuentas institucionales `active|inactive`;
- las cuentas técnicas `active|inactive` exigen nombre(s) y permiten omitir apellidos;
- los perfiles institucionales `pending_registration` permanecen estructuralmente incompletos;
- `profiles_structured_full_name_check` relaciona la representación derivada con los componentes;
- `normalize_sitaa_profile_names()` normaliza espacios y reconstruye `full_name` en orden determinista;
- el trigger `normalize_sitaa_profile_names` se ejecuta antes de insertar o actualizar `profiles`;
- `enforce_sitaa_profile_identity()` conserva el ciclo de cuenta y limita el autoservicio a los componentes del nombre.

No se dividieron nombres históricos por heurística. El backfill de componentes revisado por el operador es una diferencia controlada de datos y no aparece en el snapshot reproducible.

## Funciones y triggers

Las 39 firmas incluyen las funciones acumuladas de actividades, borradores, publicación, participantes, asistencia, expiración, reapertura, QR/código, semestres, identidad y registro. En particular:

- está instalada la firma de seis argumentos de `complete_own_google_registration` definida por 0006;
- la firma anterior de cuatro argumentos permanece para compatibilidad/rollback, sin ejecución del cliente;
- `handle_sitaa_auth_user_created()` conserva Google pendiente, bootstrap técnico confiable y rechazos atómicos;
- `sync_sitaa_profile_email_from_auth()` permanece presente;
- continúan `publish_activity`, las guardas de borrador, la validación programada, la expiración de asistencia y los RPC de check-in.

Los ocho triggers públicos incluyen los dos de integridad temporal de actividades/participantes y los tres de `profiles`, incluido el nuevo normalizador. `live_triggers.sql` se limita a tablas de `public`; por ello los triggers sobre `auth.users` se sustentan en los preflight y verificadores transaccionales aprobados de 0004–0006. No se infiere su ausencia a partir de una captura cuyo alcance no incluye `auth`.

## RLS, privilegios y ACL

- Las 17 tablas públicas mantienen RLS habilitado y las 23 políticas no cambiaron.
- `PUBLIC` y `anon` no tienen `EXECUTE` en funciones SITAA.
- Sólo la firma de seis argumentos de finalización concede ejecución cliente a `authenticated`; la firma anterior no la concede.
- El normalizador y el handler Auth no conceden ejecución a `authenticated`, `anon` ni `PUBLIC`.
- `anon` conserva únicamente el acceso deliberado de lectura a `system_health`.
- Los grants de tablas, secuencias, actividades, participantes y asistencia permanecen iguales al cierre 0005.
- La actividad administrativa de roles continúa separada; 0006 no amplía `role_assignments` ni el acceso académico.

Los artefactos de tabla y ACL expandida no incluyen ACL por columna de `pg_attribute`. El contrato exacto —`authenticated` puede actualizar `first_names`, `paternal_surname` y `maternal_surname`, pero no `full_name` ni campos administrativos— fue comprobado por el verificador 0006 ejecutado bajo el rol cliente real. Es una limitación explícita de cobertura del snapshot, no una diferencia de privilegio efectiva.

La omisión textual de `SECURITY INVOKER` en `pg_get_functiondef()` es semánticamente inocua: el preflight usa `pg_proc.prosecdef = false`. Las diferencias de representación de `MAINTAIN` en ACL tampoco cambian el privilegio efectivo.

## Regresiones de migraciones anteriores

No se observaron regresiones:

- 0002: privacidad de borradores, publicación transaccional, integridad programada, límite de asistencia pendiente y privilegios mínimos;
- 0003: edición/eliminación de borradores provisionales sin bloqueo temporal;
- 0004: ciclo `pending_registration|active|inactive`, cuentas `institutional|technical`, unicidad del identificador y creación atómica de perfil;
- 0005: alta Google pendiente antes de la confirmación final y validación estricta en la finalización;
- 0006: componentes autoritativos, nombre derivado y autoservicio acotado.

La asistencia manual, compacta y por QR/enlace/código, sus ventanas, expiración y reapertura conservan las firmas y triggers esperados.

## Aplicación, verificación y smoke tests

- El preflight independiente terminó con las 15 categorías bloqueantes en cero y el conteo informativo en cero.
- La migración terminó con `COMMIT`.
- La aplicación compatible con la RPC estructurada fue desplegada.
- El verificador transaccional terminó con código de salida 0 y `ROLLBACK`; no persistió fixtures sintéticas.
- Los smoke tests de producción confirmaron alta/finalización, edición de nombres y representación derivada sin reproducir datos de cuentas en este informe.

La primera ejecución del verificador expuso un defecto exclusivo del arnés: sus helpers `pg_temp` eran `SECURITY INVOKER` y el rol `authenticated` no podía leer la tabla temporal de lookup. La corrección concede únicamente `SELECT` sobre `pg_temp.sitaa_0006_cases` y `EXECUTE` sobre `pg_temp.case_id(text)` y `pg_temp.case_email(text)`. Esos permisos desaparecen con la sesión/transacción, no alcanzan objetos persistentes, no alteran privilegios productivos y no modificaron la migración 0006.

## Sistema visual obligatorio

`docs/DESIGN_SYSTEM.md` es el contrato canónico para toda la aplicación, no sólo para páginas públicas. La interfaz usa azul y oro como identidad; azul para acciones primarias, oro/ámbar para advertencia, rojo para destrucción y verde exclusivamente para éxito semántico. Estados y controles rellenos definen foreground/background legibles mediante primitivas centralizadas. `npm run check:ui` es obligatorio y no se detectó branding `emerald-*` en el código de interfaz auditado.

La puerta pública compacta, navegación autenticada, visibilidad técnica de Catálogos, marca SVG y favicon de alto contraste permanecen operativos. Este cierre no rediseña pantallas ni modifica código.

## Clasificación de diferencias

| Diferencia | Clasificación |
| --- | --- |
| Timestamp, formato y cláusulas predeterminadas omitidas por PostgreSQL | Ambiental inocua |
| Backfill revisado de nombres en perfiles existentes | Dato operativo controlado; no exportado |
| Separación previa de cuenta técnica y académica | Dato operativo controlado; ya documentado |
| Objetos, restricciones, funciones y ACL introducidos por 0006 | Coincidencia con la migración |
| Esquema, RLS, políticas, grants operativos y catálogos anteriores | Coincidencia acumulada 0001–0006 |

**Hallazgos inexplicados:** ninguno.

## Higiene del repositorio

Los archivos `*.local.sql` y `*.local.txt` siguen excluidos por `.gitignore`; no se inspeccionaron ni incorporaron porque pueden contener correspondencias privadas. Los resultados oficiales de preflight, migración y verificación exitosa, el snapshot y este informe son los artefactos de cierre. La salida exitosa del verificador supersede el fallo previo del arnés.

## Conclusión

El estado vivo queda reconciliado contra `0001`–`0006` sin deriva inexplicada. 0006 está aplicada, verificada y operativa; `full_name` permanece como compatibilidad derivada y reportes/CSV/PDF siguen fuera de su alcance. Las migraciones `0001`–`0006` permanecen inmutables. `0007` es el siguiente número disponible y no se crea en esta tarea.
