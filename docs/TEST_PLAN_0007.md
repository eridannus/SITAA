# Plan de prueba — migración 0007

**Estado:** preflight aprobado; migración aplicada con `COMMIT`; verificador corregido aprobado con `ROLLBACK`; smoke tests de producción aprobados; snapshot y reconciliación post-0007 cerrados sin deriva inexplicada.

**Objetivo:** verificar el directorio administrativo B.1 de sólo lectura, la autoridad técnica exacta y la base append-only de auditoría sin exponer PII real ni modificar permanentemente datos.

## Artefactos

- `supabase/reconciliation/0007_admin_account_directory_audit_preflight.sql`
- `supabase/migrations/0007_admin_account_directory_audit.sql`
- `supabase/reconciliation/0007_admin_account_directory_audit_verify.sql`
- `supabase/reconciliation/0007_admin_account_directory_audit_rollback.sql`

El preflight y la migración se ejecutaron correctamente y la aplicación compatible fue publicada. La primera ejecución del verificador se detuvo en su bloque estático inicial, antes de crear fixtures. El diagnóstico confirmó que los objetos y ACL persistentes eran correctos y que el fallo pertenecía exclusivamente al comparador de `pg_proc.prosrc`. Tras corregir el arnés, la reejecución terminó correctamente con el `ROLLBACK` esperado.

## Preflight

Debe ejecutarse y revisarse antes de la migración. Abre una transacción de sólo lectura, devuelve exclusivamente categorías, clasificación y conteos, y termina en `ROLLBACK`.

Todos los conteos bloqueantes deben ser cero:

- tablas y columnas post-0006 requeridas;
- código `technical_admin` y función exacta `extensions.unaccent(text)`;
- correspondencia uno-a-uno entre Auth y `profiles`;
- integridad referencial de `role_assignments`;
- ausencia de tabla, funciones, trigger o políticas 0007;
- RLS, políticas propias con roles/comandos exactos y grants cliente post-0006, incluidos sólo los tres nombres estructurados actualizables;
- roles `anon`, `authenticated` y `service_role`, incluido `service_role.rolbypassrls=true`, forma V1 real y ausencia de conflictos 0007.

El único dato informativo es el conteo agregado de asignaciones `technical_admin` actuales mal formadas; no bloquea ni expone filas.

La migración repite esas condiciones dentro de su misma transacción antes de ejecutar DDL.

## Verificador transaccional

Genera un `run_id` UUID por ejecución y deriva de él correos `example.invalid`, marcadores de nombre/comodines e identificadores institucionales numéricos. Así, las aserciones exactas no pueden colisionar con datos previos. Usa objetos `pg_temp` y finaliza en `ROLLBACK`; los grants del arnés se limitan a tablas y helpers temporales necesarios para probar con `SET LOCAL ROLE authenticated` o `service_role`.

Antes de crear fixtures, el bloque estático valida el contrato físico completo de 0007 mediante catálogos PostgreSQL:

- las nueve columnas de `admin_audit_events`, en orden, con tipos, nulabilidad y defaults exactos;
- una PK, tres FK `ON DELETE RESTRICT` y cuatro `CHECK` con su semántica real;
- los cuatro índices B.1 con tabla, método btree, claves y dirección, sin unicidad, predicado, expresión ni columnas incluidas;
- exactamente dos triggers append-only, con timing, eventos, nivel fila/sentencia, función y estado habilitado;
- RLS sin políticas y ACL de tabla/columna: ningún acceso de `PUBLIC`, `anon` o `authenticated`; `service_role` sólo `SELECT`/`INSERT`, sin grants de columna;
- nombres, tipos y orden exactos de las entradas y salidas de las cuatro RPC;
- volatilidad, `SECURITY DEFINER`/invoker, `search_path`, cuerpo semántico y ACL exacto de los helpers de fecha, autoridad, metadata y bloqueo de mutaciones.

La migración normaliza explícitamente el ACL de sus ocho funciones para `PUBLIC`, `anon`, `authenticated` y `service_role`, y ejecuta antes del `COMMIT` una guarda atómica sobre privilegios efectivos, grantees directos y ausencia de grant option. Las RPC quedan ejecutables sólo por `authenticated`; los helpers privados quedan sólo para el propietario, salvo el validador de metadata, que concede `EXECUTE` explícito y no delegable a `service_role`.

Estas aserciones complementan, pero no sustituyen, las pruebas funcionales siguientes.

Matriz mínima de 72 comprobaciones:

1–4. Existen las cuatro RPC con firmas estables; historial usa entrada `requested_profile_id`, salida `target_profile_id`, nombres PostgREST coordinados y helpers privados sin `EXECUTE` cliente. Cada una devuelve `42501` para las diez clases no autorizadas; detalle, asignaciones e historial niegan igual un UUID existente y uno inexistente.
5–10. Se rechazan paginaciones `NULL`, cero, negativas o superiores al máximo; página 1 000 000/tamaño 50 y offset 1 000 000 son válidos sin desbordamiento.
11–14. `%`, `_` y `\` son literales; patrones compuestos sólo encuentran marcadores UUID sintéticos y no amplían el conjunto.
15–26. Accede únicamente `technical_admin/system/technical/null/null` con perfil activo y asignación actual; se niegan alumno, profesor, alcance/servicio incorrectos, programa/división no nulos, perfil o asignación inactivos, futuro y vencido; ambos límites del día son inclusivos.
27–30. Filtros de rol/servicio/alcance coinciden en una misma fila; filas distintas no se combinan; estado vacío devuelve cero y el texto usa marcadores sintéticos únicos.
31–35. Lista enmascarada, detalle completo sólo autorizado, existencia indistinguible para no autorizados, historial sin metadata y Auth sólo booleano.
36–39. Confirmación verdadera por `email_confirmed_at` o Google verificado con correo coincidente; correo Google distinto o ausencia de evidencia devuelven falso.
40–46. `authenticated`, `anon` y `PUBLIC` carecen de acceso directo; `service_role` tiene exactamente `SELECT`/`INSERT` sobre la tabla y `EXECUTE` exclusivo —además del propietario— sobre el validador. Bajo `SET LOCAL ROLE service_role` se prueban inserción/lectura válidas, tres rechazos de metadata y ausencia de `UPDATE`/`DELETE`/`TRUNCATE`; por separado el propietario alcanza los triggers y éstos rechazan las tres mutaciones.
47–53. Metadata ordinaria se acepta; `access_token`, `accessToken`, `refresh-token`, `authorizationHeader`, `recoveryLink`, `clientSecretValue`, objetos sobredimensionados y valores no objeto se rechazan.
54–58. Asignaciones se presentan como `current`, `future`, `expired`, `inactive` y `suspended_by_account_status` con semántica V1.
59–64. Persisten RLS propio, grants de nombres estructurados, contrato de registro post-0006, privacidad de borradores y contratos estáticos de participantes, asistencia y check-in.
65–72. Existe el helper privado y estable de fecha institucional, sin `SECURITY DEFINER`, con `search_path=pg_catalog`, sin `EXECUTE` para `PUBLIC`, `anon`, `authenticated` ni `service_role`; devuelve la fecha de `America/Mexico_City` incluso con la sesión en `Pacific/Kiritimati`. Inicio y término del día institucional son inclusivos, el día siguiente es futuro, el anterior es vencido y las tres funciones B.1 no contienen `current_date`. El límite de metadata es 16 384 bytes y la fixture sobredimensionada supera ese máximo.

El verificador también comprueba `SECURITY DEFINER`, `search_path`, RLS, ausencia de políticas cliente, ACL exacto de auditoría y ejecución sólo para `authenticated` en las cuatro RPC públicas. Todas las fechas de fixtures parten de `institutional_today`, calculada con `(current_timestamp AT TIME ZONE 'America/Mexico_City')::date`; no se convierten desde la zona horaria de sesión. La fixture de `admin_inactive` conserva una sola asignación deliberada.

La primera ejecución no alcanzó estas fixtures. `pg_proc.prosrc` conservó saltos de línea externos; `btrim()` se aplicaba antes de sustituir espacios y dejaba un espacio ordinario al inicio y al final. El contrato corregido usa `btrim(regexp_replace(lower(p.prosrc), '\s+', ' ', 'g'))`, añade una regresión sintética con saltos externos y mantiene todas las aserciones funcionales. La reejecución aprobó la matriz completa y terminó en el `ROLLBACK` final; no dejó datos ni grants temporales persistentes.

## Smoke tests de producción aprobados

- La navegación `Cuentas` aparece sólo con el contrato B.1 exacto, también en móvil.
- Usuarios sin sesión vuelven a login; usuarios autenticados no autorizados vuelven al dashboard.
- Sin criterios se explica por qué no se navega el directorio completo.
- Filtros y paginación conservan estado y responden a teclado/zoom 200 %.
- Lista, correo e identificadores largos envuelven sin colisión a 320, 375, 768, 1024 y 1440 px.
- El identificador está enmascarado en lista y completo sólo en detalle.
- No existen controles de activación, corrección, Auth o roles.
- La aplicación compatible publicada abre B.1 contra la migración aplicada sin exponer detalles PostgreSQL/Supabase.

La prueba con administrador técnico exacto aprobó acceso y navegación. Profesor y alumno ordinarios no vieron ni abrieron el directorio. Búsqueda, filtros, lista, detalle, asignaciones V1 e historial sanitizado funcionaron y no se expusieron controles de cuenta, Auth o roles.

## Rollback manual

El rollback sólo se considera tras revisión. Inicia explícitamente en `READ COMMITTED`, confirma de forma mínima que la tabla existe y obtiene `ACCESS EXCLUSIVE NOWAIT` sobre `admin_audit_events` antes del guard completo y de comprobar que esté vacía. Un lector, escritor, mantenimiento o DDL concurrente hace que el intento aborte sin esperar; la operación debe aquietarse y reintentarse, nunca retirando `NOWAIT`, debilitando el lock, saltando el control de vacío o forzando el rollback. El lock impide que un `INSERT` de `service_role` confirme entre la comprobación y el `DROP TABLE`.

Con el lock retenido hasta el final de la transacción, el guard exige el contrato 0007 completo, incluido el ACL exacto de las ocho funciones, el helper privado de fecha institucional y el límite de metadata de 16 384 bytes, y aborta si `admin_audit_events` contiene una fila. Revoca a los cuatro roles la ejecución de todas las RPC y helpers antes de retirarlos, no usa `CASCADE`, elimina únicamente objetos 0007, verifica el contrato post-0006 y confirma con `COMMIT` sólo si la autoverificación termina correctamente. El rollback permanece disponible únicamente mientras no exista historia administrativa.

## Secuencia ejecutada

1. Se aprobó el preflight con todos los bloqueos en cero.
2. Se aplicó 0007 y terminó con `COMMIT`.
3. Se publicó la aplicación compatible.
4. Se corrigió el falso negativo exclusivo del arnés y el verificador reejecutado terminó con `ROLLBACK`.
5. Se aprobaron los smoke tests de producción.
6. Se generó el snapshot completo `2026-07-21T00:16:03Z`, estado `SUCCESS`.
7. Se reconcilió `0001`–`0007` sin deriva inexplicada.

`0007_admin_account_directory_audit.sql` forma parte de la historia aplicada y es inmutable. Fase B.1 está cerrada; `0008` es el siguiente número disponible.
