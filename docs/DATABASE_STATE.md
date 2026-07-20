# Estado reconciliado de la base de datos

**Fecha de cierre documental:** 2026-07-18.

**Snapshot vivo comparado:** `2026-07-18T04:05:40Z`, estado `SUCCESS`.

La fuente de verdad histórica y evolutiva es la cadena aplicada y verificada:

1. `0001_baseline_current_schema.sql`: baseline reconciliada.
2. `0002_database_security_and_integrity.sql`: seguridad, publicación y privilegios mínimos.
3. `0003_fix_draft_temporal_lifecycle.sql`: ciclo temporal de borradores.
4. `0004_identity_registration_foundation.sql`: identidad y registro institucional.
5. `0005_fix_google_oauth_user_creation.sql`: secuencia de alta Google.
6. `0006_structured_person_names.sql`: nombres personales estructurados y `full_name` derivado.

La comparación fue local contra los artefactos ya generados en `supabase/reconciliation/live/`. No se conectó a Supabase ni se ejecutó SQL durante este cierre.

## Inventario posterior a 0006

| Categoría | Cantidad |
| --- | ---: |
| Tablas públicas | 17 |
| Columnas | 156 |
| Restricciones PK, FK, UNIQUE o CHECK | 72 |
| Índices, incluidos los respaldados por restricciones | 38 |
| Triggers sobre tablas públicas | 8 |
| Funciones y firmas públicas | 39 |
| Políticas RLS | 23 |
| Tablas con RLS habilitado | 17 |
| Filas de semillas en catálogos controlados | 51 |
| Grants de rutinas | 112 |
| Grants de tablas | 261 |
| Grants de secuencia | 6 |
| Entradas ACL expandidas | 413 |

Frente al snapshot posterior a 0005, 0006 conserva tablas, columnas, índices, políticas, RLS, grants de tablas y secuencias y catálogos. Los incrementos esperados son cuatro restricciones, un trigger, dos firmas de función, cuatro grants de rutina y cuatro entradas ACL.

## Contrato vivo de identidad posterior a 0006

- `first_names`, `paternal_surname` y `maternal_surname` existen como `text`; el apellido materno admite `NULL`.
- Los componentes estructurados son autoritativos y `normalize_sitaa_profile_names()` deriva `full_name` de forma determinista.
- Una cuenta institucional `active|inactive` exige nombre(s), apellido paterno, programa e identificador coherente; una técnica exige nombre(s) y puede omitir apellidos.
- Un perfil institucional `pending_registration` permanece incompleto hasta la finalización autenticada.
- `enforce_sitaa_profile_identity()` permite autoservicio sólo de los tres componentes del nombre y protege los campos administrativos.
- La firma de seis argumentos de `complete_own_google_registration` es la única firma de finalización ejecutable por `authenticated`; la firma anterior permanece sin acceso del cliente.
- `handle_sitaa_auth_user_created()` conserva las rutas Google pendiente y técnica confiable; `sync_sitaa_profile_email_from_auth()` permanece instalada.
- El snapshot especializado enumera triggers de tablas `public`; los triggers sobre `auth.users` se comprobaron mediante el preflight y el verificador transaccional aprobados.

El snapshot de tablas y ACL no captura ACL de columna (`pg_attribute.attacl`). La autorización exacta de `UPDATE (first_names, paternal_surname, maternal_surname)` y el rechazo de `full_name` o campos administrativos quedaron comprobados por el verificador 0006 ejecutado bajo `SET LOCAL ROLE authenticated`. Esta limitación de cobertura no altera el privilegio efectivo ni constituye deriva.

## Protecciones acumuladas conservadas

- Los borradores sólo son visibles para `created_by`; `technical_admin` no amplía la lectura de borradores ajenos.
- La publicación exige estado programado completo y protege `created_by` y la transición de estado.
- El creador puede corregir o eliminar su borrador provisional conforme a 0003.
- Participación, asistencia manual y masiva, expiración, reapertura y check-in QR/enlace/código conservan sus funciones y triggers.
- Google crea exactamente un perfil pendiente; signup público por contraseña, proveedores no soportados y metadata inválida se rechazan atómicamente.
- `PUBLIC` y `anon` no tienen `EXECUTE` sobre funciones SITAA; `anon` conserva sólo lectura de `system_health`.
- RLS permanece habilitado en las 17 tablas y las 23 políticas no cambiaron.
- Los 11 catálogos controlados conservan 51 filas; no se exportaron datos operativos o personales.

## Evidencia de aplicación y verificación de 0006

- El preflight reportó cero filas en todas las categorías bloqueantes.
- La migración terminó con `COMMIT` y la aplicación compatible fue desplegada.
- El verificador transaccional terminó con código de salida 0 y `ROLLBACK`; las fixtures sintéticas no persistieron.
- El arnés fue corregido para conceder a `authenticated` sólo `SELECT` sobre `pg_temp.sitaa_0006_cases` y `EXECUTE` sobre sus dos helpers temporales. Esos grants desaparecen con la sesión/transacción y no cambian producción ni la migración aplicada.
- Los smoke tests de producción confirmaron registro, edición y representación de nombres estructurados.

## Resultado de reconciliación

| Diferencia observada | Clasificación |
| --- | --- |
| Objetos de 0002–0005 | Coincidencia exacta o semántica con la cadena acumulada |
| Restricciones, normalizador, trigger, RPC estructurada y ACL de rutina de 0006 | Coincidencia exacta o semántica |
| Omisión textual de `SECURITY INVOKER`, predeterminado en PostgreSQL, y representación ACL de `MAINTAIN` | Diferencia ambiental inocua |
| Timestamp y formato producido por `pg_dump`/`psql` | Diferencia ambiental inocua |
| Backfill revisado de nombres y separación ya documentada entre cuentas técnica y académica | Diferencia controlada de datos operativos; no se exporta |

**Deriva inexplicada:** ninguna en esquema, funciones, triggers, políticas, privilegios efectivos, ACL, catálogos o restricciones.

El detalle probatorio está en `supabase/reconciliation/0006_post_apply_reconciliation.md`.

## Pendientes conocidos

- **A-02:** `technical_admin` mantiene acceso académico amplio a contenido publicado. **Deferred intentionally until user, role and permission administration is designed.**
- Administración de cuentas, roles V2, filtros/reportes, retiro de A-02 y check-in abierto siguen sus fases documentadas.
- Reportes y exportaciones CSV/PDF permanecen como trabajo futuro; 0006 sólo establece el modelo de nombres que deberán consumir.
- Overloads heredados, `activities.updated_by`, `starts_at`/`ends_at`, alcance divisional y `token_type = 'registration'` permanecen reservados o pendientes de análisis.

## Inmutabilidad y siguiente migración

`0001`–`0006` forman historia aplicada, verificada y reconciliada y no se reescriben. La migración `0007_admin_account_directory_audit.sql` y sus artefactos están preparados localmente para B.1, pero **no están aplicados**. Por ello, los conteos de este documento y el snapshot vigente siguen representando exclusivamente el estado posterior a 0006.

Todo cambio futuro de base de datos debe crear una migración nueva, incluir verificación y rollback cuando corresponda, aplicarse manualmente, regenerar el snapshot después de cambios significativos y reconciliarlo contra la cadena completa.
