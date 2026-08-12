# Plan canónico de prueba 0011 — SEM-01

## Estado

**Aplicada en producción y verificador transaccional aprobado.** La migración `0011_academic_period_administration.sql` se aplicó correctamente el 2026-08-12 y confirmó su transacción. La ejecución productiva del verificador corregido aprobó después el conjunto exacto de casos 1–51 y terminó con su propio `ROLLBACK` explícito. El rollback de la migración no fue ejecutado. SEM-01 permanece activo y no está cerrado; `/admin/periods` todavía no existe y no forma parte de este paquete.

La primera ejecución productiva del verificador, el 2026-08-12, terminó antes de completar los casos: `psql` devolvió código 3 y PostgreSQL rechazó con `42501` / `sitaa_activity_writer_identity_mismatch` la construcción del fixture sintético de actividad. El verificador no alcanzó su `ROLLBACK` explícito final; al terminar la sesión `psql` fallida sin `COMMIT`, PostgreSQL descartó la transacción abierta. Ningún caso 1–51 se acepta de esa ejecución y el fallo no justificó ejecutar el rollback de la migración. Este intento se conserva únicamente como cronología histórica rechazada.

La segunda ejecución productiva del verificador corregido, identificada en UTC como `2026-08-12T19:25:25Z`, terminó con código 0: emitió exactamente 51 filas, conjunto único 1–51, cero faltantes, cero duplicados, un `ROLLBACK` final explícito, cero `COMMIT` y ninguna solicitud interactiva de contraseña. Los fixtures y eventos de auditoría del verificador no persistieron. Esta ejecución aprueba el gate transaccional, no el arnés multisesión ni la reconciliación.

No se declaran aprobados el arnés multisesión, el snapshot/reconciliación post-0011, la implementación o despliegue de `/admin/periods`, ni los smoke tests de interfaz. El snapshot rastreado permanece post-0010. El horizonte de fecha de actividad «razonable» permanece diferido y no se implementa como regla de base de datos.

## Alcance del paquete

El paquete de base de datos consta de:

1. `supabase/reconciliation/0011_academic_period_administration_preflight.sql`;
2. `supabase/migrations/0011_academic_period_administration.sql`;
3. `supabase/reconciliation/0011_academic_period_administration_verify.sql`;
4. `supabase/reconciliation/0011_academic_period_administration_rollback.sql`;
5. `scripts/check-sql-0011.mjs`.

La migración es database-first, ya fue aplicada y verificada transaccionalmente. Todavía deben aprobarse el arnés multisesión y la reconciliación post-0011 antes de implementar la aplicación SEM-01. No requirió un despliegue de compatibilidad previo porque conserva todas las firmas y contratos actualmente consumidos.

El preflight independiente es obligatorio, pero no se trata como una instantánea inmutable: su lectura puede quedar obsoleta mientras la migración espera adquirir locks. Antes de 0011, el DML de `activities` todavía no participa en el advisory de SEM-01. Por ello, después de adquirir el advisory y los locks estructurales sobre `academic_periods` y `activities`, la migración repite de forma autoritativa todas las comprobaciones mutables de periodos y de transición de actividades antes de ejecutar DDL. La guarda post-lock vuelve a congelar la semilla completa y su huella histórica, integridad y traslapes, y compara atribución almacenada, resolución post-0010 y resolución SEM-01 para todas las actividades. Una deriva observada en ese punto falla cerrada; no repara ni modifica filas.

## Inventario exacto de objetos

### Tabla nueva

`public.academic_period_audit_events`

- `id uuid` PK con `gen_random_uuid()`;
- `actor_profile_id uuid` FK restrictiva a `profiles`;
- `academic_period_id uuid` FK restrictiva a `academic_periods`;
- `period_code text` copiado de forma estable;
- `action_code text`;
- `outcome text`, siempre `success`;
- `reason text`, nulo sólo en creación;
- `changed_fields text[]`;
- `old_values jsonb`;
- `new_values jsonb`;
- `occurred_at timestamptz` autoritativo, capturado con reloj de pared después de adquirir locks y completar la mutación.

RLS queda habilitado sin políticas cliente. No existe privilegio directo para `PUBLIC`, `anon`, `authenticated` ni `service_role`. Los índices nuevos son:

- `academic_period_audit_events_period_occurred_idx`;
- `academic_period_audit_events_actor_occurred_idx`.

### Restricciones nuevas de `academic_periods`

- `academic_periods_sem01_shape_check`;
- `academic_periods_active_date_range_excl`, exclusión GiST de `daterange(starts_on, ends_on, '[]')` para filas activas distintas de `pilot`.

### Triggers nuevos

En `academic_periods`:

- `academic_periods_guard_sem01`;
- `academic_periods_guard_truncate_sem01`;
- `academic_periods_set_updated_at_sem01`.

En `academic_period_audit_events`:

- `academic_period_audit_events_guard_update_delete`;
- `academic_period_audit_events_guard_truncate`.

En `activities`, ambos `FOR EACH STATEMENT`:

- `activities_sem01_lock_insert`;
- `activities_sem01_lock_update`, limitado a `start_date`, `status_code` y `academic_period_id`.

### Funciones privadas owner-only

- `is_exact_sem01_period_admin_0011(uuid)`;
- `lock_and_reauthorize_sem01_admin_0011(uuid)`;
- `normalize_sem01_reason_0011(text)`;
- `is_sem01_audit_payload_valid_0011(text,text[],jsonb,jsonb)`;
- `resolve_academic_period_proposal_0011(date,text,uuid,text,text,date,date,boolean)`;
- `diagnose_academic_period_impact_0011(text,uuid,text,text,date,date,boolean)`;
- `acquire_sem01_calendar_lock_0011()`;
- `guard_academic_periods_sem01_0011()`;
- `set_academic_period_updated_at_0011()`;
- `guard_academic_period_audit_append_only_0011()`.

No se concede `EXECUTE` cliente sobre estas funciones.

### Funciones reemplazadas de forma compatible

- `get_academic_period_for_date(date)` conserva firma, columnas, tipos, estabilidad y `SECURITY DEFINER`;
- `publish_activity(uuid)` conserva firma, retorno y uso por la aplicación;
- `validate_activity_scheduled_state()` conserva el contrato del trigger y usa el resolver nuevo.

`get_visible_activity_cards()` y `semester_label` no se reemplazan: siguen leyendo la FK almacenada y el nombre de `academic_periods`.

## Superficie RPC pública congelada

Sólo `authenticated` recibe `EXECUTE`; cada función administrativa valida internamente la autoridad técnica exacta.

### `list_admin_academic_periods(integer,integer)`

Parámetros:

- `result_limit integer DEFAULT 100`, rango 1–100;
- `result_offset integer DEFAULT 0`, rango 0–10000.

Retorna:

`TABLE(id uuid, code text, name text, starts_on date, ends_on date, is_active boolean, created_at timestamptz, updated_at timestamptz, activity_reference_count bigint)`.

### `create_admin_academic_period(text,date,date,boolean)`

Parámetros:

- `requested_code text`;
- `requested_starts_on date`;
- `requested_ends_on date`;
- `requested_is_active boolean DEFAULT true`.

Retorna:

`TABLE(period_id uuid, code text, name text, starts_on date, ends_on date, is_active boolean, created_at timestamptz, updated_at timestamptz, audit_event_id uuid)`.

La creación inicializa `name = code` y no acepta ni exige motivo.

### `correct_admin_academic_period(uuid,text,date,date,text)`

Parámetros:

- `requested_period_id uuid`;
- `requested_name text`;
- `requested_starts_on date`;
- `requested_ends_on date`;
- `change_reason text`.

Retorna el mismo contrato tabular de mutación. No recibe ni modifica `code`, `sort_order` o `academic_period_id`.

### `activate_admin_academic_period(uuid,text)`

Parámetros: `requested_period_id uuid`, `change_reason text`. Retorna el contrato tabular de mutación.

### `deactivate_admin_academic_period(uuid,text)`

Parámetros: `requested_period_id uuid`, `change_reason text`. Retorna el contrato tabular de mutación.

No existe RPC de eliminación, escritura genérica, asignación manual ni remapeo masivo.

## Códigos estables de error

| Código/mensaje sanitizado | SQLSTATE | Uso |
| --- | --- | --- |
| `sitaa_sem01_read_committed_required` | `25000` | mutación invocada fuera de `READ COMMITTED` |
| `sitaa_0011_read_committed_required` | `25000` | contexto de migración o rollback fuera de `READ COMMITTED` |
| `sitaa_0011_read_write_required` | `25006` | contexto de migración o rollback que no es `READ WRITE` |
| `sitaa_sem01_admin_access_denied` | `42501` | autoridad exacta ausente o perdida después de esperar locks |
| `sitaa_sem01_invalid_pagination` | `22023` | paginación fuera de límites |
| `sitaa_sem01_invalid_period_code` | `22023` | código distinto de `YYYY-1` o `YYYY-2` |
| `sitaa_sem01_period_code_conflict` | `23505` | código ya existente |
| `sitaa_sem01_invalid_period_name` | `22023` | nombre vacío, fuera de límite o no normalizable |
| `sitaa_sem01_complete_dates_required` | `23514` | fecha inicial o final ausente |
| `sitaa_sem01_invalid_period_range` | `23514` | `starts_on > ends_on` |
| `sitaa_sem01_active_state_required` | `22023` | estado propuesto nulo |
| `sitaa_sem01_invalid_reason` | `22023` | motivo normalizado fuera de 10–1000 caracteres |
| `sitaa_sem01_unsafe_reason` | `22023` | motivo con material sensible prohibido |
| `sitaa_sem01_period_not_found` | `P0002` | periodo inexistente |
| `sitaa_sem01_pilot_immutable` | `23514` | intento de mutar `pilot` |
| `sitaa_sem01_period_code_immutable` | `23514` | intento de cambiar código |
| `sitaa_sem01_no_changes` | `22023` | corrección sin delta real |
| `sitaa_sem01_period_already_active` | `22023` | activación redundante |
| `sitaa_sem01_period_already_inactive` | `22023` | desactivación redundante |
| `sitaa_sem01_period_overlap` | `23P01` | traslape activo |
| `sitaa_sem01_calendar_impact_blocked` | `23514` | impacto no permitido sobre actividades |
| `sitaa_sem01_audit_append_only` | `42501` | UPDATE, DELETE o TRUNCATE de auditoría |
| `sitaa_sem01_period_delete_forbidden` | `42501` | eliminación o truncado del catálogo |
| `sitaa_activity_academic_period_unavailable` | `23514` | publicación/estado programado sin periodo resoluble |

No se exponen SQL, errores crudos, filas operativas, UUID masivos, secretos ni payloads de proveedor.

## Delta de esquema y ACL esperado

Antes de 0011 existen 19 tablas públicas, 183 columnas, 96 restricciones, 48 índices, 13 triggers, 60 funciones y 25 políticas. La aplicación de 0011 añade:

- 1 tabla y 11 columnas;
- 9 restricciones: 7 de la tabla nueva, 1 `CHECK` y 1 exclusión sobre `academic_periods`;
- 4 índices físicos: PK y 2 índices explícitos de auditoría, más el índice de la exclusión;
- 7 triggers;
- 10 funciones privadas;
- 5 RPC administrativas;
- reemplazo compatible de 3 funciones existentes;
- 0 políticas cliente nuevas;
- 0 secuencias;
- 0 cambios a default ACL.

El inventario post-0011 esperado es: 20 tablas, 194 columnas, 105 restricciones, 52 índices, 20 triggers públicos no internos, 75 funciones, 25 políticas y 20 tablas con RLS.

`authenticated` conserva `SELECT` de referencia sobre `academic_periods`; pierde cualquier DML directo si existiera. `service_role` conserva sólo `SELECT` directo sobre esa tabla y pierde su DML innecesario. `PUBLIC` y `anon` no obtienen acceso. La auditoría no tiene acceso directo de cliente o `service_role`. Las firmas del resolver y publicación conservan `EXECUTE` para `authenticated` y `service_role`.

La línea base de ACL de columna distingue tres capas. La ACL explícita (`pg_attribute.attacl` expandida con `aclexplode`) contiene exactamente `UPDATE`, sin grant option y con otorgante `postgres`, para `authenticated` sobre `profiles.first_names`, `profiles.paternal_surname` y `profiles.maternal_surname`. `information_schema.column_privileges` se valida aparte como proyección explicable por ACL de tabla o columna; no se interpreta como inventario de grants explícitos. El acceso efectivo de `PUBLIC`, `anon`, `authenticated` y `service_role` debe coincidir con la ACL de tabla más esas tres excepciones, y `authenticated` no puede tener `UPDATE` de tabla sobre `profiles` ni `UPDATE` efectivo en otra columna del perfil.

## Resolver y compatibilidad

El resolver ordena periodos activos ordinarios por `starts_on`, `code` e `id`; ignora `pilot` e inactivos. El candidato comienza en `starts_on`. Si hay sucesor configurado, termina el día anterior al `starts_on` del sucesor; si no lo hay, termina en su propio `ends_on`. Por tanto devuelve `NULL` antes del primero y después del `ends_on` del último.

La entrada y comparaciones son `date`; el resultado no depende de la zona de sesión. La aplicación desplegada continúa invocando `get_academic_period_for_date({ target_date })` y `publish_activity({ target_activity_id })` sin cambio. La publicación toma el lock compartido, bloquea la actividad, vuelve a resolver y persiste estado/periodo de forma atómica. Inmediatamente antes de decidir si el inicio sigue siendo futuro captura `clock_timestamp()` después de la espera del advisory y del `FOR UPDATE`; el validator de filas programadas hace la misma captura en el punto real de validación después del trigger statement-level. No usan el tiempo de inicio de la transacción. Esta regla de reloj de pared es independiente del horizonte de fecha razonable, que permanece diferido. Un preview de aplicación nunca es autoritativo.

## Orden de locks y concurrencia

El dominio fijo es `pg_advisory_xact_lock(1397310541, 1101)`.

La migración, el rollback y el verificador fijan explícitamente `READ COMMITTED` y `READ WRITE` inmediatamente después de `BEGIN`; no heredan `default_transaction_isolation` ni `default_transaction_read_only` de la sesión. La relectura autoritativa posterior a una espera requiere snapshots frescos por comando. Por la misma razón, las rutas runtime de mutación `lock_and_reauthorize_sem01_admin_0011`, `publish_activity` y el trigger statement-level `acquire_sem01_calendar_lock_0011` rechazan `REPEATABLE READ` y `SERIALIZABLE` antes de consultar autorización, esperar el advisory o leer datos. Esta exigencia es una condición de consistencia, no una reducción de seguridad SQL. El resolver puro y el listado administrativo de sólo lectura conservan las semánticas normales de la base de datos.

La instalación inicial usa un orden estructural especial y exacto: advisory, `activities` en `SHARE ROW EXCLUSIVE`, `academic_periods` en `ACCESS EXCLUSIVE` y guarda autoritativa post-lock. El orden `activities` antes de `academic_periods` coincide con el DML pre-0011 de actividades, que adquiere primero su relación objetivo y después consulta `academic_periods`; así, una sentencia ya iniciada puede terminar sin quedar bloqueada por un lock inverso retenido por la migración. La guarda post-lock sólo es autoritativa después de ambos locks y bajo la transacción `READ COMMITTED` fijada por el script. Un `lock_timeout` o un rechazo explícito son resultados fail-closed aceptables; un deadlock PostgreSQL nunca lo es.

Orden de mutación de periodos:

1. actor y comprobación optimista exacta;
2. advisory lock SEM-01;
3. lock estructural de `academic_periods`;
4. row lock del perfil actor;
5. row locks de sus asignaciones, ordenados por ID;
6. reautorización exacta completa;
7. row lock del periodo objetivo;
8. diagnóstico, auditoría y escritura.

`publish_activity` verifica primero `READ COMMITTED` y toma el mismo advisory lock antes de su `FOR UPDATE`. INSERT de actividades y UPDATE que afecte fecha, estado o periodo verifican el aislamiento y adquieren el lock mediante trigger `FOR EACH STATEMENT`, antes de cualquier row lock. Ningún row trigger adquiere por primera vez el dominio.

Después de 0011, una sentencia de actividad puede haber adquirido ya su lock relacional normal antes de que el trigger statement-level espere el advisory. Por ello, una RPC ordinaria de periodos nunca intenta `LOCK TABLE public.activities` mientras conserva el advisory: lee actividades para diagnosticar bajo el dominio compartido sin crear el ciclo advisory/relation lock. El lock estructural de `activities` es exclusivo del procedimiento de instalación/rollback. Tras cualquier espera, la validación de fila o la publicación vuelve a resolver el semestre y rechaza una atribución cliente obsoleta.

## Clasificación de impacto

El diagnóstico compara para todas las actividades la FK almacenada, la resolución actual y la resolución propuesta. Bloquea:

- atribución no nula que dejaría de coincidir;
- cambio de resolución de una fila ya asignada;
- actividad no borrador ya inconsistente;
- ganancia, pérdida o cambio en cualquier no borrador;
- pérdida o cambio de un borrador no asignado que ya resolvía.

Sólo permite como cambio lógico la habilitación de borradores `draft`, sin FK, actualmente no resolubles y resolubles bajo la propuesta. La mutación de periodo ejecuta cero DML contra `activities`.

La sustitución inicial del resolver durante la migración usa exactamente esa misma clasificación. Un borrador sin atribución que ya era resoluble no puede perder su resolución ni cambiar a otro periodo. El único cambio lógico permitido durante la transición inicial es `draft`, `academic_period_id IS NULL`, resolución post-0010 `NULL` y resolución SEM-01 no nula. Las guardas independiente, pre-lock y post-lock aplican el mismo predicado.

## Auditoría

Creación produce `academic_period_created` sin motivo. Corrección, activación y desactivación producen, respectivamente, `academic_period_corrected`, `academic_period_activated` y `academic_period_deactivated`, con motivo normalizado. `changed_fields`, `old_values` y `new_values` contienen sólo el delta permitido. `occurred_at` usa `clock_timestamp()` explícito al insertar el evento después de la mutación exitosa; representa el tiempo real posterior a espera de locks y reautorización, no el inicio de la transacción. Cada éxito escribe exactamente un evento en la misma transacción; rechazo o rollback escribe cero.

## Casos transaccionales 1–51

### Caso 1 — Línea base exacta post-0011
Comprueba objetos, forma y exclusión.

### Caso 2 — Código ordinario válido
Acepta `YYYY-1`/`YYYY-2` exacto.

### Caso 3 — Formatos ordinarios inválidos
Rechaza semestre o año inválido.

### Caso 4 — Espacios y formatos alternativos
Rechaza espacios, guion bajo y diagonal sin normalizar el código.

### Caso 5 — Unicidad de código
Rechaza duplicado con código estable.

### Caso 6 — Inmutabilidad de código
Rechaza UPDATE incluso fuera de la RPC.

### Caso 7 — Fechas completas
Exige ambos límites.

### Caso 8 — Rango válido
Acepta `starts_on <= ends_on`.

### Caso 9 — Rango inválido
Rechaza inicio posterior al fin.

### Caso 10 — Traslape por INSERT
La exclusión GiST rechaza la carrera lógica.

### Caso 11 — Traslape por UPDATE
La exclusión rechaza activar/actualizar hacia un rango ocupado.

### Caso 12 — Preservación de `pilot`
Conserva su excepción histórica exacta.

### Caso 13 — Validación de nombre
Exige texto normalizado de 1–120 caracteres.

### Caso 14 — `updated_at`
Cambia automáticamente sólo ante una actualización real.

### Caso 15 — Denegación anónima
ACL impide ejecutar el listado.

### Caso 16 — Denegación autenticada ordinaria
La función falla cerrada.

### Caso 17 — Asignación técnica malformada
Alcance/servicio incorrecto no concede autoridad.

### Caso 18 — Perfil administrativo inactivo
Perfil inactivo no administra.

### Caso 19 — Asignación futura
Vigencia futura no concede autoridad.

### Caso 20 — Asignación expirada
Vigencia terminada no concede autoridad.

### Caso 21 — Autoridad exacta exitosa
Perfil técnico exacto puede crear/listar.

### Caso 22 — Listado administrativo
Proyección acotada y conteo agregado.

### Caso 23 — Fecha anterior al primer periodo
Resolver devuelve `NULL`.

### Caso 24 — Fecha dentro del periodo
Resolver devuelve el periodo esperado.

### Caso 25 — Intersemestre configurado
Conserva el anterior cuando el sucesor ya existe.

### Caso 26 — Frontera del sucesor
El sucesor inicia exactamente en `starts_on`.

### Caso 27 — Después del último periodo
Resolver devuelve `NULL` después de `ends_on` sin sucesor.

### Caso 28 — Periodo inactivo ignorado
No participa en resolución.

### Caso 29 — Re-resolución de publicación
No confía en valor cliente. La definición desplegada conserva `clock_timestamp()` para la decisión futura posterior a la espera.

### Caso 30 — Correspondencia programada
Trigger impide FK distinta del resolver. La comprobación owner-side inspecciona `publish_activity` y `validate_activity_scheduled_state`: ambas deben usar `clock_timestamp()` y ninguna puede usar `current_timestamp`, `transaction_timestamp()` o `now()` para validar el inicio futuro.

### Caso 31 — Corrección sólo de nombre
No cambia atribución, audita sólo `name` y acota `occurred_at` entre los instantes wall-clock anterior y posterior a la RPC.

### Caso 32 — Corrección de fecha sin impacto
Una fila inactiva aislada puede corregirse con motivo.

### Caso 33 — Corrección con impacto
Se rechaza antes de escribir.

### Caso 34 — Activación con impacto
Se rechaza sin evento.

### Caso 35 — Desactivación con impacto
Se rechaza sin perder atribución.

### Caso 36 — Ausencia de DELETE
No existe función ni privilegio cliente.

### Caso 37 — Ausencia de DML directo
Se prueban por separado las denegaciones de `authenticated` y `service_role`; el caso se registra una sola vez después de que ambas fases concluyen.

### Caso 38 — Un evento por éxito
Cardinalidad exacta.

### Caso 39 — Motivo administrativo
Corrección/activación/desactivación exigen 10–1000 caracteres seguros.

### Caso 40 — Evidencia segura
Allowlist, claves delta y tamaño acotado.

### Caso 41 — Auditoría append-only
UPDATE, DELETE y TRUNCATE fallan bajo la misma guarda.

### Caso 42 — Independencia de zona
UTC, Ciudad de México y Tokio resuelven el mismo `date`.

### Caso 43 — ACL estable
Firmas consumidas siguen disponibles y helpers quedan privados. La inspección owner-side de las definiciones desplegadas comprueba además que `lock_and_reauthorize_sem01_admin_0011`, `publish_activity` y `acquire_sem01_calendar_lock_0011` ejecutan primero el guard `sitaa_sem01_read_committed_required`/`25000`, antes de advisory, autorización o lecturas de datos según corresponda. Es una prueba estructural de definiciones; no simula una carrera multisesión.

### Caso 44 — Restauración de fixtures
El archivo termina en `ROLLBACK`; no persiste usuario, periodo, actividad ni evento.

### Caso 45 — Postcondiciones exactas
Valida mapa completo de casos y ausencia de residuos antes del rollback.

### Caso 46 — Habilitación benigna
Crear un periodo puede volver resoluble un borrador no asignado antes irresoluble.

### Caso 47 — Cero DML de actividad
Compara JSON completo, `xmin`, `updated_at`, estado, creador, responsable y FK.

### Caso 48 — Publicación posterior
La publicación vuelve a resolver y persiste el periodo correcto.

### Caso 49 — No borrador protegido
Ganancia, pérdida o cambio se rechaza.

### Caso 50 — Atribución no nula protegida
No puede cambiar ni desaparecer.

### Caso 51 — Borrador ya resoluble protegido
No puede perder ni cambiar resolución por mutación de calendario.

## Plan multisesión posterior

El verificador transaccional no sustituye conexiones reales. Un ticket separado deberá crear y revisar un arnés PowerShell para un entorno desechable o controlado previamente aprobado. Debe cubrir:

Escenarios específicos DB-04, aún no ejecutados:

1. un `UPDATE` de actividad pre-0011 que ya mantiene `ROW EXCLUSIVE` sobre `activities` y se pausa antes de leer `academic_periods`, mientras comienza la migración;
2. prueba de que la migración espera `activities` sin bloquear antes la lectura de `academic_periods` de esa transacción;
3. prueba de que la transacción de actividad puede terminar y la migración relee después su estado confirmado;
4. prueba de ausencia de deadlock PostgreSQL;
5. migración iniciada desde una sesión cuyo aislamiento predeterminado es `REPEATABLE READ`, demostrando que el script establece `READ COMMITTED` antes de leer la línea base;
6. rollback iniciado desde una sesión con predeterminado alterado, demostrando el mismo pin explícito;
7. RPC administrativa de periodos dentro de `REPEATABLE READ` y `SERIALIZABLE`, rechazada antes de mutar en ambos casos;
8. `publish_activity` dentro de esos niveles, rechazada antes de mutar;
9. DML directo relevante de actividad dentro de esos niveles, rechazado por el trigger statement-level;
10. operaciones normales en `READ COMMITTED` o autocommit que siguen concluyendo correctamente.

La lista anterior es un plan futuro y no afirma ejecución. Además se conservan los escenarios previos:

- dos creaciones activas traslapadas concurrentes;
- creación contra corrección;
- publicación contra cambio de calendario;
- actualización de fecha de actividad contra cambio de calendario;
- sentencia de actividad que ya inició, conserva su lock relacional normal y espera el advisory mientras la mutación de periodo lo conserva;
- mutación de periodo que espera el advisory mientras una transacción de actividad lo conserva;
- DML de actividad que confirma mientras la migración espera el lock estructural de `activities`; la guarda post-lock debe observar el estado confirmado y aprobarlo sólo si sigue siendo seguro o fallar cerrada;
- publicación que espera el advisory hasta que su hora de inicio pasa; debe rechazar con el reloj de pared posterior a la espera;
- transición a `scheduled` que espera el advisory hasta que su hora de inicio pasa; el validator debe rechazarla;
- pérdida de autoridad mientras una sesión espera;
- observación del advisory lock y PID sin datos sensibles;
- ganador/perdedor deterministas;
- ausencia de deadlock;
- cleanup y cero fixtures persistentes.

En todas las direcciones de espera el resultado aceptable es finalización determinista o rechazo de negocio estable después de volver a resolver, sin atribución obsoleta; nunca un deadlock PostgreSQL.

Este paquete no crea ni ejecuta ese arnés.

## Orden obligatorio de ejecución futura

Esta lista conserva la secuencia aprobada durante la preparación y registra los gates ya completados. La migración y el verificador corregido están aprobados; el siguiente gate obligatorio es el arnés multisesión y la secuencia continúa sin omitir las etapas posteriores.

1. [x] Revisar y aprobar el paquete local completo.
2. [x] Commit y push del paquete sólo de base de datos.
3. [x] Confirmar build de Vercel verde.
4. [x] Ejecutar manualmente el preflight independiente.
5. [x] Revisar todas las categorías bloqueantes e informativas.
6. [x] Aplicar manualmente `0011`.
7. [x] Ejecutar y aprobar el verificador transaccional corregido.
8. [ ] Crear, revisar y ejecutar el arnés multisesión separado.
9. [ ] Regenerar el snapshot vivo y reconciliarlo.
10. [ ] Sólo entonces implementar y desplegar `/admin/periods`.
11. [ ] Ejecutar smoke tests de UI.
12. [ ] Cerrar SEM-01 únicamente al aprobar toda la evidencia.

## Smoke tests futuros

Después de la reconciliación SQL y del despliegue de aplicación:

- autoridad técnica exacta ve `/admin/periods`;
- usuario ordinario no ve navegación y recibe denegación en ruta/acción/RPC;
- lista activa/inactiva, paginación y conteos;
- creación activa e inactiva;
- corrección con motivo;
- activación/desactivación con conflicto legible;
- ausencia total de eliminar;
- `/catalogs` permanece sólo lectura;
- creación/edición/publicación de actividades conserva asignación automática;
- tarjetas conservan `semester_label`.

No se ha ejecutado ninguno de estos smoke tests.

## Elegibilidad del rollback

El rollback sólo es elegible si:

- la auditoría contiene cero filas;
- las cinco filas de periodo coinciden con la línea base post-0010;
- ninguna actividad depende de la semántica nueva;
- no existe dependencia externa sobre objetos 0011;
- se adquieren el advisory lock y locks estructurales con `NOWAIT`.

Se vuelve permanentemente inelegible después de la primera mutación administrativa real o publicación dependiente. Nunca borra, trunca ni remapea periodos, actividades o auditoría.

## Reconciliación y evidencia

Tras la futura aplicación deben regenerarse todos los artefactos de `supabase/reconciliation/live/`, comparar schema, funciones, triggers, políticas y ACL, y documentar el delta real. La evidencia sólo puede contener conteos, contratos, hashes y resultados sanitizados. Se prohíben secretos, correos, UUID de personas, filas de actividad, tokens, cookies, URI y errores crudos.
