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

El verificador transaccional no sustituye conexiones reales. La preparación local ya creó:

- `scripts/sem01_0011_run_multisession.ps1`;
- `scripts/check-sem01-0011-multisession.mjs`.

El primer borrador del arnés pasó sus comprobaciones sintácticas y estáticas locales, pero falló la revisión manual: podía eliminar por error un SQL versionado y aprobaba varios IDs sin ejecutar la semántica individual descrita. No se ejecutó ningún modo remoto con ese borrador y no aportó escenarios aceptados. SEM-01-DB-08 corrigió el ciclo de vida de fuentes, la aprobación por resultado exacto, la cobertura concurrente y las huellas de postcondición, además de ampliar el checker con regresiones negativas específicas.

Una segunda revisión manual encontró después los defectos principales de reanudación, diagnóstico de `-PostcheckOnly` e inventario de funciones en la huella POST0011. SEM-01-DB-09 los corrigió localmente sin ejecutar ningún modo remoto: la reanudación quedó limitada a una frontera de fase completamente terminada y respaldada por sus resultados y huellas exactas; una fase activa o incompleta no se reproduce, y un RunId rechazado no puede volver a `ready` ni producir evidencia aprobada. Los resultados observados durante una fase activa no equivalen a una fase completada.

La revisión posterior de DB-09 detectó todavía una frontera PHASE_02 inválida con cero actividades aunque el fixture de instalación persistía, una cadena `if`/`elseif` que omitía invariantes de manifiestos `running` y `approved`, la imposibilidad de documentar un estado 0011 parcial o `UNKNOWN`, inventarios de constraints, índices y ACL de tabla hasheados sin demostrar antes su contenido exacto y publicación no atómica de evidencia aprobada o rechazada. SEM-01-DB-10 corrigió localmente los conteos de frontera, la validación exacta de inventarios, el sondeo de estados parciales y el orden de publicación de evidencia: cada fase conserva conteos diagnósticos explícitos; PHASE_02 congela exactamente el UUID y la huella de la fila física completa de su única actividad; el estado del manifiesto se valida en bloques independientes; los inventarios exactos se prueban antes de aceptar sus hashes; y la evidencia terminal se publica de forma inmutable antes del manifiesto correspondiente.

Una revisión separada de DB-10 encontró siete defectos locales adicionales: los objetos diagnósticos parciales no eran totales bajo `Set-StrictMode`; `ready/PHASE_06_FINAL_POSTCHECK` podía omitir la fase final e imprimir aprobación; la comparación de ACL de rutinas ignoraba grants noowner delegables; MS18/MS19 no demostraban que el inicio siguiera futuro al observar la espera; los manifiestos terminales se persistían antes de su validación final; `ActiveWorkerPids` no era durable para todos los helpers de workers; y un diagnóstico anidado podía sustituir el `ErrorRecord` original. SEM-01-DB-11 corrigió localmente esos límites: usa un renderer total con `NOT_APPLICABLE`, reserva PHASE_06 para `approved`, compara grantor/privilegio/grant option, prueba futuro y cruce en orden, valida candidatos terminales antes de escribirlos, sincroniza ambas fuentes de PID y congela el fallo original.

La revisión separada de DB-11 encontró todavía siete defectos locales: `PGOPTIONS` transportaba sin escape los valores multiword de aislamiento; el observer genérico de 30 segundos era menor que el margen wall-clock de 45 segundos; el cruce del reloj no probaba simultáneamente que waiter y holder conservaran el advisory esperado; postchecks aprobados y fallidos compartían una ruta ambigua; los artefactos terminales `*.publishing` no se inventariaban; un fallo durante la finalización rechazada podía reemplazar el `ErrorRecord` primario; y las operaciones de fase podían heredar un MSxx obsoleto. SEM-01-DB-12 corrigió estos límites sólo localmente: codifica `read\ committed` y `repeatable\ read` mediante allowlist, fija las desigualdades wall-clock `45 000 < 55 000 < 70 000 < 90 000` ms con separaciones de al menos 10 000 ms, exige el marcador combinado `CLOCK_CROSSED_WHILE_WAITING|1`, separa `final-postcheck.local.txt` de `failure-postcheck.local.txt`, clasifica publicaciones terminales parciales, protege el fallo primario frente a toda finalización secundaria y usa `NONE` fuera de un escenario activo.

La revisión separada de DB-12 encontró cuatro defectos locales restantes: PHASE_02 retenía durante doce segundos el `RowExclusiveLock` de `activities`, aunque la migración inmutable sólo permite cinco segundos de espera estructural; el checker exigía ese `pg_sleep(12)` contradictorio; MS05 afirmaba mediante un booleano fijo que el proceso partía de `repeatable read`; y MS06 tampoco observaba el aislamiento efectivo dentro de los mismos procesos `psql` que ejecutaban el rollback. SEM-01-DB-13 corrigió estos límites sólo localmente: extrae y congela el `lock_timeout = '5s'` de la migración protegida, aplica las desigualdades `2 000 + 2 000 <= 5 000 - 1 000` ms, reemplaza el sleep por un holder de una sola sesión que el controlador avanza explícitamente de etapa A a etapa B después de observar la espera y antepone un comando interno fijo de marcador al `-f` protegido en el mismo proceso de migración o rollback. El SQL versionado continúa ejecutándose byte por byte desde su ruta de repositorio.

La revisión separada de DB-13 detectó que PHASE_02 todavía trataba el `lock_timeout = '5s'` como plazo de terminación del proceso completo, que su sondeo de dos segundos abría una conexión `psql` por intento y podía aceptar un resultado tardío, que el cumplimiento temporal se reducía a un booleano y que la salida del proceso holder se usaba como sustituto de `COMMIT` y del orden transaccional. SEM-01-DB-14 corrigió esos defectos sólo localmente: separa el presupuesto estructural (`wait age <= 2 000 ms`, marcador de `COMMIT <= 2 000 ms` y `2 000 + 2 000 <= 5 000 - 1 000 ms`) del timeout de recolección del proceso de migración (`180 000 ms`, superior al `statement_timeout = '120s'` inmutable); usa una única sesión observadora preconectada, persistente y de sólo lectura; mide en servidor la edad de la espera desde `pg_stat_activity.query_start`; aplica comprobaciones monotónicas antes y después de cada comando; observa en vivo `INSTALL_PERIOD_READ|1` y `INSTALL_HOLDER_COMMITTED|1`; y recolecta por separado los procesos después de probar la liberación transaccional. El orden ya no depende de `CompletedAtUtc` ni exige que toda la migración termine dentro de cinco segundos.

La revisión separada de DB-14 encontró tres defectos residuales: las respuestas exitosas del observador no volvían a comprobar su plazo individual después de encontrar el marcador; las esperas de marcadores del holder seguían el mismo patrón marcador-antes-de-deadline; y el límite estructural sumaba una muestra de edad del servidor con un cronómetro del controlador iniciado sólo después de recibir la respuesta. Esa fórmula omitía el transporte de la respuesta y el procesamiento del controlador, que podían consumir de forma invisible el intervalo de seguridad. SEM-01-DB-15 corrigió estos defectos sólo localmente: cada solicitud y cada etapa congela un timestamp monotónico de envío y valida su plazo antes de leer, después de leer y justo antes de aceptar un marcador; el observador emite los milisegundos epoch del inicio de la consulta de lock y de la observación; el holder emite, después de `COMMIT`, el epoch del marcador final; y el límite estructural se calcula íntegramente con reloj PostgreSQL como `commit_marker_epoch_ms - lock_query_start_epoch_ms`. El máximo aceptable sigue siendo `4 000 ms`. El plazo monotónico del marcador de `COMMIT` permanece como control independiente de vivacidad del controlador y no se suma a la medición estructural del servidor.

La revisión separada de DB-15 confirmó esas correcciones del observador de instalación y de los deadlines de marcadores, pero encontró defectos distintos en el runtime genérico: todavía aceptaba un probe exitoso antes de comprobar el plazo posterior, medía duración con `DateTime.UtcNow`, observaba sólo el waiter advisory y no al holder concedido exacto, y MS20 conservaba un holder fijo de ocho segundos, no probaba que la autoridad se hubiera retirado mientras el mismo RPC seguía bloqueado y fijaba artificialmente la evidencia de retiro previo a la liberación. SEM-01-DB-16 corrige esos defectos sólo localmente: el observador genérico usa tiempo monotónico, rechaza resultados tardíos y conserva evidencia estructurada; todos los pares prueban conteos exactos, holder concedido, waiter no concedido, sesiones vivas y, cuando aplica, locks de `activities` del mismo par; MS20 usa un holder staged y una segunda observación independiente que fija la ausencia de la asignación mientras los mismos backends siguen en sus estados de lock, antes de permitir la etapa de liberación. Los fallos de limpieza permanecen secundarios al fallo original.

La revisión separada de DB-16 encontró un defecto adicional en el enlace del timeout de proceso: `Invoke-PsqlFile` usaba una variable `ProcessTimeoutMilliseconds` no declarada después de iniciar el worker; `Invoke-PsqlSql` enviaba ese valor como parámetro nombrado desconocido; `Start-PsqlWorker` declaraba el parámetro sin usarlo; y los wrappers directos de migración o rollback podían iniciar `psql` antes de fallar bajo `Set-StrictMode`. Ni el checker ni `-ValidateOnly` inspeccionaban la superficie real de parámetros. SEM-01-DB-17 corrige esos límites sólo localmente: `Invoke-PsqlFile` declara el parámetro acotado; un helper puro resuelve el valor explícito o deriva `statement_timeout + 30 000` sin overflow; toda validación ocurre antes del arranque; el timeout efectivo llega exactamente a `Wait-PsqlWorker`; los archivos protegidos usan un plazo de terminación determinista de `210 000 ms`; y el controlador detiene y recolecta mediante limpieza secundaria cualquier worker no recolectado sin reemplazar el `ErrorRecord` primario. Fixtures locales y estáticos cubren el enlace, el orden, la propiedad única del timeout y el ciclo de vida fail-safe sin iniciar procesos.

La revisión separada de DB-17 confirmó la corrección del enlace del timeout y del ownership directo de workers, pero encontró que varias orquestaciones superiores todavía ejecutaban limpieza throwable de procesos o base de datos dentro de `finally`. Un fallo de esa limpieza podía sustituir el código estable, la `FailureClass`, la atribución MSxx y el `ErrorRecord` primarios antes de que el manejador externo generara evidencia. SEM-01-DB-18 corrige esas fronteras sólo localmente: congela inmediatamente error y escenario, intenta cada cleanup independiente mediante un resultado no lanzable, conserva el error primario aunque fallen limpiezas posteriores y rechaza una ruta primaria exitosa si su postcondición de cleanup no queda probada. PHASE_02, PHASE_03, los pares advisory, MS18/MS19, MS20 y PHASE_05 ya no ejecutan cleanup remoto o de procesos directamente en `finally`; las aprobaciones afectadas se difieren hasta completar sus postcondiciones. `-ValidateOnly` y el checker cubren fallos anidados, continuidad después de un cleanup fallido, identidad del error congelado, clase y escenario, ownership nulo o ya recolectado y ausencia de remoción ficticia, sin conexión ni procesos PostgreSQL.

La revisión separada de DB-18 confirmó la preservación del fallo primario en esas orquestaciones, pero detectó una frontera distinta: `Invoke-SecondaryFailureOperation` usa `&` y, por tanto, una asignación escalar dentro de su scriptblock no modifica la variable del caller. Esto hacía que una limpieza satisfactoria de credenciales dejara aparentemente poblados `pointer`, `plain` y `secure`, y que toda escritura exclusiva dejara aparentemente no nulos `writer` y `stream`; ambas rutas rechazaban sus propias postcondiciones. La misma revisión encontró que `Start-StagedInstallationHolder`, `Start-StagedAuthorityLossHolder` y `Start-PersistentInstallationObserver` iniciaban el proceso antes del `try` propietario, y que los dos holders staged conservaban una remoción local de PID no protegida capaz de sustituir el `ErrorRecord` original.

SEM-01-DB-19 corrige estos defectos sólo localmente. Credenciales y escritura exclusiva comunican cleanup mediante propiedades de objetos de estado compartidos; el BSTR se libera una sola vez, las referencias sensibles quedan nulas y cada recurso de archivo adquirido queda dispuesto antes de aprobar. Los tres starters precalculan todo lo independiente, entran al `try` antes de `Process.Start()`, sólo retornan workers completamente representados en las fuentes PID aplicables y, ante cualquier fallo posterior al arranque, observan la terminación antes de intentar por separado ambas remociones sin reemplazar el error congelado. Fixtures locales prueban la diferencia entre scalar y propiedad compartida, el consumo explícito de valores retornados, la reapertura/movimiento/eliminación inmediata del archivo, los fallos parciales de construcción o disposición y cada frontera sintética de ownership sin crear procesos del sistema, ejecutar SQL ni usar red.

La revisión separada de DB-19 confirmó esas correcciones de cleanup y ownership, pero encontró dos defectos locales restantes. Los pares advisory genéricos todavía usaban una espera fija de 800 ms y los escenarios wall-clock otra de 700 ms; ninguna demostraba que el holder previsto hubiera adquirido el advisory exacto antes de arrancar el waiter. Además, `-ReadOnlyProbeOnly` no validaba el perfil sintético no administrador requerido por MS20, por lo que un LAB estructuralmente incompleto podía fallar por primera vez dentro de PHASE_05.

SEM-01-DB-20 corrige ambos límites sólo localmente. Una observación read-only comprueba cardinalidad exacta por `application_name`, backend cliente vivo, advisory concedido `(1397310541, 1101)`, PID interno y proceso local activo antes de habilitar un único waiter; la observación posterior del par queda ligada al mismo backend y los escenarios wall-clock conservan esa identidad hasta el cruce. Un único predicado canónico define también el conjunto sintético no administrador de MS20: baseline, manifiesto, reanudación, probe LAB, pregrant y post-cleanup congelan su conteo y hash del conjunto, mientras la selección interna usa el primer UUID ordenado sin exponer UUID ni correo en evidencia sanitizada.

La revisión separada de DB-20 confirmó el readiness holder-before-waiter y la congelación del conjunto candidato de MS20, pero encontró cuatro fronteras todavía incompletas: las observaciones advisory omitían `objsubid = 2`; baseline y diagnósticos sólo contaban locks concedidos; MS11–MS17 retenían holders con sleeps fijos de cinco o seis segundos, cuya duración restante después del readiness era indeterminada y podía impedir el `55P03` esperado a tres segundos de MS11/MS12; y los dos SQL transitorios de cada par se creaban antes de adquirir ownership completo, por lo que un fallo intermedio podía dejar el primero como residuo.

SEM-01-DB-21 corrige esos defectos sólo localmente. La identidad exacta del advisory de dos enteros exige simultáneamente `locktype = 'advisory'`, `classid = 1397310541`, `objid = 1101` y `objsubid = 2`; los límites diagnósticos separan locks concedidos, en espera y totales. MS11–MS17 usan holders staged de una sola sesión, sin `pg_sleep`: la etapa A ejecuta la operación real, emite un marcador específico y conserva abierta la transacción; MS11/MS12 sólo reciben rollback tras recolectar el `55P03` exacto, mientras MS13–MS17 se liberan después de observar el par completo ligado al mismo backend. El ownership comienza antes del primer `New-SqlFile`, la limpieza de holder y waiter es independiente y cada frontera completada exige `TRANSIENT_WORKER_SQL_FILES|0`.

La revisión separada de DB-21 confirmó la identidad advisory exacta con `objsubid = 2`, los conteos concedido/en espera/total, los holders staged deterministas de MS11–MS17, las políticas release-after-55P03 y release-after-pair, el estado de ownership previo al primer archivo, el diagnóstico de residuos SQL transitorios y la preservación del conjunto candidato MS20. Sin embargo, encontró que `New-SqlFile` todavía sólo comunicaba el path después de que el write exclusivo retornaba: un fallo posterior a `FileMode.CreateNew` podía dejar un `worker_*.sql` físico cuyo nombre permanecía desconocido para el cleanup del caller, y el fixture sintético existente no creaba ese archivo parcial real.

SEM-01-DB-22 corrige ese límite sólo localmente. `New-SqlFile` congela y valida el path autoritativo antes de abrirlo, mantiene ownership interno hasta completar el write, la disposición y una verificación estricta de archivo regular, UTF-8 sin BOM, contenido canónico y SHA-256, y elimina específicamente el path transitorio ante cualquier fallo sin modificar la semántica global de publicaciones `*.publishing`. Fixtures físicas bajo un directorio desechable `validate-db22-*` prueban fallos de apertura, construcción del writer, escritura, flush, disposición, contenido, hash y remoción, incluida la preservación del `ErrorRecord` primario y el cleanup independiente de holder/waiter. El checker inspecciona el cuerpo real de `New-SqlFile` y conserva todas las regresiones DB-08–DB-21.

La revisión separada de DB-22 confirmó la asignación autoritativa previa al write dentro de `New-SqlFile`, la remoción específica de archivos parciales, la verificación exacta UTF-8 sin BOM/contenido/bytes/hash, los fixtures físicos de holder y waiter, la preservación de las publicaciones terminales `*.publishing` y todos los contratos advisory, staged-holder y MS20 de DB-21. Encontró, sin embargo, una frontera posterior: después del retorno exitoso de `New-SqlFile`, `Invoke-PsqlFile` resolvía el timeout de proceso antes de adquirir ownership disposable. Con `StatementTimeoutMilliseconds = 570001` y `ProcessTimeoutMilliseconds = 0`, `psql_process_timeout_overflow_rejected` ocurría con `worker = null` y `sqlLifecycleValidated = false`; el `catch` omitía la remoción. `Invoke-PsqlSql` tampoco protegía el handoff exterior y el checker exigía ese orden inseguro. Por ello DB-22 no autorizó `-ReadOnlyProbeOnly`.

SEM-01-DB-23 corrige ese límite sólo localmente. El ownership explícito pasa de `New-SqlFile` al caller de `Invoke-PsqlSql`, luego al controller de `Invoke-PsqlFile` antes de toda validación o resolución fallible y finalmente al worker sólo después de que `Start-PsqlWorker` retorna completo. Un fallo pre-worker ejecuta cleanup estructurado, guardado e idempotente, observa ausencia y conserva el `ErrorRecord`, la `FailureClass` y el escenario primarios aunque falle la remoción. El handoff exterior repite esa limpieza de forma idempotente ante fallos de entrada o binding; los SQL protegidos con `DeleteSqlFileOnCompletion = false` nunca adquieren ownership disposable ni se eliminan. Fixtures físicas `validate-db23-*` prueban overflow, timeout negativo, archivo ausente, rechazo de guard, cleanup secundario, preservación de SQL de repositorio y el modelo caller/controller/worker sin iniciar procesos. El checker cubre las funciones reales y rechaza la restauración del orden residual.

La revisión separada de DB-23 confirmó que la validación de timeout pre-worker ya ocurre bajo ownership controller, que los caminos de overflow y timeout negativo eliminan su SQL transitorio canónico, que `Invoke-PsqlSql` dispone de una frontera exterior de handoff, que el SQL de repositorio continúa protegido y que las fixtures caller/controller/worker son físicas y locales. También confirmó la corrección del residuo identificado en DB-22. Sin embargo, encontró que `Assert-DisposableWorkerSqlPath` aceptaba hojas arbitrarias bajo `RunDirectory`, por lo que el cleanup controller podía alcanzar manifiestos, postchecks, evidencia o publicaciones; los setters mutaban estado antes de terminar la validación de identidad; y el handoff exterior repetía el cleanup después de `completed` porque sólo comprobaba `!WorkerOwns`. Además, `Start-PsqlWorker` podía arrancar un proceso, fallar antes de devolver el worker, descartar el resultado de `Stop-PsqlWorker` y dejar al caller con `worker = null`, habilitando cleanup controller sin prueba de terminación. Los pares transitorios directos compartían esa ambigüedad y el checker sólo exigía la presencia textual de `Stop-PsqlWorker`, no terminación observada ni escrow.

SEM-01-DB-24 corrige esos límites sólo localmente. La eliminación automática exige un hijo directo con basename case-sensitive `^worker_[a-z0-9_]+_[0-9a-f]{32}\.sql$`, fuera del repositorio, distinto de los cuatro SQL protegidos y, cuando existe, regular y no reparse. Un único `OwnerState` gobierna transiciones failure-atomic `none → caller/controller → starter → worker → completed`; path, directorio, basename y SHA-256 quedan congelados antes del handoff. Tras `Process.Start`, el proceso entra inmediatamente en escrow `starter`; cualquier fallo posterior conserva el error primario, ejecuta cleanup estructurado y sólo retira PID o SQL después de observar terminación. El cleanup exterior sólo actúa con ownership caller/controller activo, nunca vuelve a borrar después de `completed`, y un archivo recreado o con hash distinto se conserva para cleanup independiente. Fixtures físicas `validate-db24-*` cubren archivos no-worker, nombres malformados, path anidado, identidad y hash de reemplazo, cleanup interior único, modelos pre-start/post-start y pares holder/waiter sin iniciar procesos; el checker aplica mutaciones negativas sobre las funciones runtime reales.

La revisión separada de DB-24 confirmó el basename exacto y el límite de borrado al padre directo, la preservación de paths no-worker o malformados, el enum de owner único, la comprobación del hash de reemplazo antes de borrar, una sola invocación de cleanup interior tras ownership `completed`, la protección del SQL de repositorio, las fixtures físicas DB-24 y la preservación de evidencia terminal y publicaciones. También encontró límites posteriores: `New-SqlFile` retornaba sólo el path y el hash verificado se recalculaba después, por lo que el handoff podía adoptar un reemplazo; `Set-PsqlDisposableStarterOwnership` leía `Process.Id` y validaba antes de guardar el proceso, mientras `Start-StagedRuntimeAdvisoryHolder` transfería ownership antes de actualizar su estado local; `Invoke-PsqlSql` llamaba directamente el cleanup exterior y podía reemplazar el `ErrorRecord` primario; `Start-PsqlWorker` no limpiaba el material PostgreSQL de `ProcessStartInfo`; el invariant no demostraba coherencia entre proceso, worker y terminación; y el checker codificaba el orden inseguro de PID antes del escrow.

SEM-01-DB-25 corrige esos límites sólo localmente. `New-SqlFile` retorna un artefacto estructurado con path, identidad física verificada, longitud y `OwnershipState`; esos valores se transfieren directamente y quedan inmutables, sin rehash que sustituya la confianza inicial. Todos sus callers runtime consumen el artefacto y el owner inicial explícito. Después de `Process.Start`, la referencia y el estado `starter` quedan visibles antes de leer PID, iniciar lectores, sanitizar o escribir manifiestos; el catch conserva referencias fallback de proceso, resultado de Start y `StartInfo`. La sanitización elimina todas las variables PostgreSQL en éxito y fallo, y sus fallos permanecen secundarios. El cleanup exterior se ejecuta mediante un resultado no lanzable y preserva `ErrorRecord`, `FailureClass` y escenario originales. El invariant completo prueba identidad, proceso, PID, worker, terminación, ausencia y `StartInfo` limpio. Fixtures físicas y sintéticas `validate-db25-*` cubren reemplazo durante handoff, mutaciones failure-atomic, fallo de `Process.Id`, sanitización, fallo exterior integrado, holder staged, estados imposibles, SQL protegido y residuo cero; el checker añade mutaciones sobre las implementaciones runtime, sin iniciar procesos ni ejecutar SQL.

La revisión separada de DB-25 confirmó el artefacto estructurado de SQL transitorio ya verificado, la transferencia de identidad inmutable, el rechazo de reemplazos, el escrow local inmediato del proceso antes de `Process.Id`, las referencias fallback, la sanitización de `ProcessStartInfo`, el cleanup exterior no reemplazante de `Invoke-PsqlSql`, los invariants ampliados, la protección de SQL de repositorio y las fixtures físicas y sintéticas DB-25. Encontró, no obstante, dos grupos de defectos posteriores. `Set-PsqlDisposableWorkerOwnership` mutaba `Worker`, `OwnerState` y `WorkerTransferCount` antes de su invariant final; si éste fallaba podía dejar `OwnerState = worker`, mientras el caller conservaba `worker = null`. `Start-PsqlWorker` todavía ejecutaba una aserción falible de `StartInfo` después del handoff; su cleanup genérico sólo retiraba SQL con owner `starter`; `Invoke-PsqlFile` carecía de una frontera para `worker = null` con owner `worker`; y `Start-StagedRuntimeAdvisoryHolder` compartía la exposición a un fallo interno del setter.

La misma revisión comprobó que `Wait-StagedRuntimeAdvisoryHolderMarker` sólo cercaba el tiempo antes de drenar streams, por lo que podía aceptar un marcador que se volviera visible después del deadline. El checker exigía expresamente el orden genérico inseguro y no exigía comprobaciones post-read y pre-return para esos marcadores.

SEM-01-DB-26 corrige ambos grupos sólo localmente. El handoff `starter → worker` valida por completo proceso, PID, fuentes de registro, identidad, `StartInfo`, worker candidato e historial antes de mutar; congela las tres propiedades modificadas y las restaura property-for-property si falla el invariant final. En ambos starters la transferencia es la última operación antes de `return $worker`. Los cleanups distinguen owner starter, worker completo y worker parcial inválido; conservan el fallo primario, observan terminación antes de retirar PID o SQL y fallan cerrados cuando no pueden demostrar una colección completa. `Invoke-PsqlFile` rechaza explícitamente el estado imposible sin tratarlo como controller. Los marcadores staged usan el timestamp monotónico de envío como origen único y verifican el límite antes de leer, después de leer y justo antes de aceptar; el timestamp devuelto es exactamente el comprobado. MS11–MS17 derivan por separado readiness y release observados dentro del plazo. Fixtures sintéticas `validate-db26-*` cubren handoff exitoso, fallos pre y postmutación, cleanup starter/worker/parcial, terminación fallida, orden terminal, frontera inclusiva de 1 000 ms, marcadores tardíos post-read/pre-return, etapas A/B, duplicados y valores malformados; las mutaciones estáticas inspeccionan las funciones runtime reales sin iniciar procesos, usar credenciales, red o PostgreSQL.

La revisión separada de DB-26 confirmó el handoff de worker failure-atomic, todas las aserciones genéricas y staged sobre el candidato antes de transferir ownership, la transferencia inmediatamente anterior al retorno, el cleanup de estados starter y worker completo, el rechazo explícito de estados imposibles, los deadlines duros staged posteriores a la lectura y anteriores al retorno, la evidencia oportuna de readiness y release de MS11–MS17 y las fixtures físicas y sintéticas DB-26. Encontró un defecto posterior fuera de esas correcciones: MS06 todavía retenía el `RowExclusiveLock` de `activities` mediante `pg_sleep(8)`. Su probe demostraba el lock sólo en un instante; el arranque de conexiones, la latencia del Session Pooler, el observador y el scheduling local consumían una porción no controlada de esos ocho segundos. El holder podía liberar antes de que el rollback protegido alcanzara su lock `NOWAIT`, permitir que éste avanzara el LAB a POST0010 y sólo entonces provocar el rechazo por ausencia de `55P03`. El checker tampoco prohibía ese sleep ni exigía que el mismo holder siguiera bloqueando después del rechazo.

SEM-01-DB-27 corrige ese defecto sólo localmente. MS06 usa ahora un único holder de relación staged sobre una conexión `psql`, con artefacto SQL transitorio verificado y Stage A fija que abre la transacción, adquiere el `RowExclusiveLock` y emite `MS06_ROLLBACK_HOLDER_LOCKED|1`; no contiene sleeps ni liberación automática. El rollback contendido sólo arranca después del marcador oportuno y de observar exactamente una sesión `client backend`, `idle in transaction`, con el lock concedido sobre `public.activities` y worker local vivo. Tras el `55P03`, se conserva la huella POST0011 y una segunda observación exige el mismo backend y el mismo lock antes de autorizar Stage B. Ésta ejecuta `ROLLBACK` antes de `MS06_ROLLBACK_HOLDER_RELEASED|1`, queda sujeta a los deadlines monotónicos de DB-26 y precede a la colección, remoción de SQL y limpieza de ambos orígenes de PID. Sólo después de cleanup completo se ejecuta el rollback protegido exitoso. Fixtures `validate-db27-*` y mutaciones del checker cubren orden de etapas, gate de readiness, demora sintética superior a ocho segundos sin liberación, rechazo exacto antes de release, identidad del holder, marcadores duros, cleanup independiente con error primario preservado y éxito contendido inesperado sin segundo rollback.

`-PostcheckOnly` es ahora exclusivamente diagnóstico: lee incluso manifiestos rechazados o interrumpidos, registra por separado el estado esperado, el observado, cada comparación de huella, los PID del manifiesto y los workers remotos, y todos los conteos de residuos. Los campos de inventario no disponibles en un estado parcial se expresan como `NOT_APPLICABLE`; sólo informa `CLEAN` cuando el contrato completo coincide. No aprueba escenarios ni modifica el estado del RunId. La huella POST0011 cubre el inventario exacto de funciones, los triggers no internos, constraints, índices, RLS y ACL relevantes, incluida la presencia de `acquire_sem01_calendar_lock_0011()` y sin atribuir a 0011 objetos inexistentes.

El arnés corregido por DB-08 a DB-27, con versión local `2026-08-12-sem01-0011-multisession-v20`, pasó validación sintáctica y estática local, pero permanece sin ejecutar: no se ha conectado a PostgreSQL, no se ha realizado el probe LAB de sólo lectura y ninguno de los escenarios MS01–MS24 está aprobado. El cambio de versión no constituye evidencia remota. `-ReadOnlyProbeOnly` continúa expresamente prohibido hasta que una revisión separada apruebe DB-27. Sus cuatro modos superiores son exactamente:

- `-ValidateOnly`: validación local predeterminada, sin red, credenciales ni procesos `psql`;
- `-ReadOnlyProbeOnly`: probe confirmado y transaccional de sólo lectura sobre el LAB desechable allowlisted;
- `-Execute`: matriz completa, reanudable y protegida por frase de confirmación explícita;
- `-PostcheckOnly`: diagnóstico de sólo lectura posterior a una interrupción o rechazo.

La ejecución completa conserva siete límites reanudables y ordenados: `PHASE_00_VALIDATE`, `PHASE_01_READ_ONLY_BASELINE`, `PHASE_02_INSTALLATION_MATRIX`, `PHASE_03_ROLLBACK_MATRIX`, `PHASE_04_REAPPLY_0011`, `PHASE_05_RUNTIME_MATRIX` y `PHASE_06_FINAL_POSTCHECK`. Instalación y rollback consumen byte por byte los artefactos versionados; el runtime sólo comienza después de reaplicar 0011 y el estado final exigido es 0011 aplicada sin residuos.

La matriz canónica contiene exactamente:

- `MS01_PRE0011_ACTIVITY_RELATION_LOCK`;
- `MS02_MIGRATION_WAITS_FOR_ACTIVITIES_FIRST`;
- `MS03_ACTIVITY_COMMITS_BEFORE_MIGRATION_GUARD`;
- `MS04_INSTALLATION_NO_DEADLOCK`;
- `MS05_MIGRATION_PINS_READ_COMMITTED`;
- `MS06_ROLLBACK_PINS_READ_COMMITTED`;
- `MS07_ADMIN_RPC_REJECTS_HIGH_ISOLATION`;
- `MS08_PUBLISH_REJECTS_HIGH_ISOLATION`;
- `MS09_ACTIVITY_DML_REJECTS_HIGH_ISOLATION`;
- `MS10_READ_COMMITTED_NORMAL_PATH`;
- `MS11_OVERLAPPING_CREATIONS`;
- `MS12_CREATE_VERSUS_CORRECTION`;
- `MS13_PUBLISH_VERSUS_CALENDAR`;
- `MS14_ACTIVITY_DATE_VERSUS_CALENDAR`;
- `MS15_ACTIVITY_RELATION_HOLDER_WAITS_ADVISORY`;
- `MS16_CALENDAR_MUTATION_WAITS_ADVISORY`;
- `MS17_POST_WAIT_RERESOLUTION`;
- `MS18_PUBLISH_WALL_CLOCK_AFTER_WAIT`;
- `MS19_SCHEDULE_WALL_CLOCK_AFTER_WAIT`;
- `MS20_AUTHORITY_LOSS_AFTER_WAIT`;
- `MS21_ADVISORY_OBSERVATION`;
- `MS22_DETERMINISTIC_WINNER_LOSER`;
- `MS23_RUNTIME_NO_DEADLOCK`;
- `MS24_ZERO_RESIDUE`.

La cobertura DB-03/DB-04 conserva expresamente el caso en que una actividad confirma mientras la migración espera el lock estructural de `activities` y la guarda post-lock vuelve a leer el estado confirmado. También cubre la publicación que espera hasta que su hora de inicio pasa y la transición a `scheduled` equivalente, cuyo validator debe rechazarla con el reloj de pared posterior a la espera.

Los manifiestos, SQL temporales, logs y evidencia se limitan a `C:\Dev\SITAA-LOCAL-EVIDENCE\SEM-01\MULTISESSION-0011`, fuera del repositorio. Una ejecución aprobada deberá emitir el marcador final `SEM01_0011_MULTISESSION|APPROVED`; hasta entonces no existe evidencia multisesión aprobada.

La siguiente acción operativa, sólo después de una revisión separada que apruebe DB-27, será reanudar el proyecto LAB desechable, ejecutar `-ReadOnlyProbeOnly`, inspeccionar el resultado y sólo entonces considerar la autorización de `-Execute`. No se ejecutó ningún modo remoto durante DB-27 y no se debe ejecutar ahora. La regeneración/reconciliación del snapshot y `/admin/periods` permanecen bloqueados hasta aprobar toda la matriz. La cronología de la migración productiva y del verificador transaccional permanece sin cambios.

## Orden obligatorio de ejecución futura

Esta lista conserva la secuencia aprobada durante la preparación y registra los gates ya completados. La migración y el verificador corregido están aprobados; el siguiente gate obligatorio es el arnés multisesión y la secuencia continúa sin omitir las etapas posteriores.

1. [x] Revisar y aprobar el paquete local completo.
2. [x] Commit y push del paquete sólo de base de datos.
3. [x] Confirmar build de Vercel verde.
4. [x] Ejecutar manualmente el preflight independiente.
5. [x] Revisar todas las categorías bloqueantes e informativas.
6. [x] Aplicar manualmente `0011`.
7. [x] Ejecutar y aprobar el verificador transaccional corregido.
8. [ ] Aprobar la matriz multisesión separada.
   - [x] Corregir bajo SEM-01-DB-08 el arnés, ampliar su checker estático y validar ambos localmente sin conexión.
   - [x] Corregir bajo SEM-01-DB-09 la reanudación por frontera completa, la inmutabilidad de RunId rechazados, el postcheck diagnóstico y la huella POST0011, con fixtures locales y sin conexión.
   - [x] Corregir bajo SEM-01-DB-10 los residuos por frontera, las invariantes completas del manifiesto, el diagnóstico parcial, los inventarios exactos y la publicación durable de evidencia, con fixtures locales y sin conexión.
   - [x] Corregir bajo SEM-01-DB-11 la totalidad diagnóstica, estados terminales, ACL exactas, prueba de reloj, validación terminal previa, PID durables y clasificación de fallos, con fixtures locales y sin conexión.
   - [x] Corregir bajo SEM-01-DB-12 el transporte `PGOPTIONS`, los límites wall-clock, la prueba simultánea de cruce y advisory, los artefactos terminales separados, la finalización no reemplazante y la atribución honesta de escenario, con fixtures locales y sin conexión.
   - [x] Corregir bajo SEM-01-DB-13 el presupuesto inmutable de instalación, el holder controlado por etapas y la prueba del aislamiento efectivo en el mismo proceso `psql`, con fixtures locales y sin conexión.
   - [x] Corregir bajo SEM-01-DB-14 la separación entre espera estructural y terminación de proceso, el observador persistente preconectado y el orden transaccional basado en marcadores vivos, con fixtures locales y sin conexión.
   - [x] Corregir bajo SEM-01-DB-15 los deadlines duros posteriores a lectura y match, los timestamps de servidor y la medición estructural íntegra con reloj PostgreSQL, con fixtures locales y sin conexión.
   - [x] Corregir bajo SEM-01-DB-16 el observador genérico monotónico, la evidencia exacta de pares advisory y la pérdida de autoridad durante el bloqueo de MS20, con fixtures locales y sin conexión.
   - [x] Corregir bajo SEM-01-DB-17 el enlace explícito del timeout de proceso, su resolución previa al arranque y el ownership fail-safe de workers, con fixtures locales y sin conexión.
   - [x] Confirmar mediante la revisión separada de DB-17 el enlace del timeout y el ownership directo, e identificar la frontera superior de cleanup throwable.
   - [x] Corregir bajo SEM-01-DB-18 las fronteras de cleanup de orquestación y preservar error, clase y escenario primarios, con fixtures locales y sin conexión.
   - [x] Revisar DB-18 por separado, confirmar la preservación de fallos primarios e identificar la propagación escalar y el ownership post-start todavía incompletos.
   - [x] Corregir bajo SEM-01-DB-19 la propagación explícita del estado de cleanup, los recursos exclusivos y el ownership completo de los tres starters, con fixtures locales y sin conexión.
   - [x] Revisar DB-19 por separado, confirmar sus correcciones e identificar el orden advisory no determinista y el prerrequisito MS20 ausente del probe LAB.
   - [x] Corregir bajo SEM-01-DB-20 el readiness exacto holder-before-waiter y congelar el conjunto candidato de MS20 desde el baseline, con fixtures locales y sin conexión.
   - [x] Revisar DB-20 por separado, confirmar sus correcciones e identificar la identidad advisory incompleta, los conteos parciales, los holders temporizados y el ownership tardío de SQL transitorio.
   - [x] Corregir bajo SEM-01-DB-21 la identidad advisory exacta, los conteos concedido/en espera/total, los holders staged y el ownership desde el primer SQL, con fixtures locales y sin conexión.
   - [x] Revisar DB-21 por separado, confirmar sus correcciones e identificar el path parcial todavía desconocido cuando el write exclusivo fallaba antes de retornar.
   - [x] Corregir bajo SEM-01-DB-22 el ownership interno de creación, la remoción transitoria específica, la verificación exacta y los fixtures físicos, sin conexión.
   - [x] Revisar DB-22 por separado, confirmar sus correcciones e identificar el handoff todavía desprotegido después del retorno de `New-SqlFile` y antes del worker.
   - [x] Corregir bajo SEM-01-DB-23 el ownership caller/controller/worker, el cleanup pre-worker, el handoff idempotente y los fixtures físicos, sin conexión.
   - [x] Revisar DB-23 por separado, confirmar sus correcciones e identificar el guard disposable demasiado amplio, las transiciones no atómicas, el cleanup exterior redundante y la pérdida de escrow posterior a `Process.Start`.
   - [x] Corregir bajo SEM-01-DB-24 la identidad exacta, el ownership único failure-atomic, el escrow starter y las fixtures físicas de reemplazo y fallo post-start, sin conexión.
   - [x] Revisar DB-24 por separado, confirmar sus límites de path, owner y cleanup, e identificar la pérdida de identidad verificada, el escrow post-start tardío, la sanitización incompleta y el cleanup exterior reemplazante.
   - [x] Corregir bajo SEM-01-DB-25 el artefacto verificado, la identidad inmutable, el escrow inmediato y fallback, la sanitización de `StartInfo`, el cleanup exterior no reemplazante y los invariants completos, con fixtures locales y sin conexión.
   - [x] Revisar DB-25 por separado, confirmar el artefacto verificado, la identidad inmutable, el escrow inmediato, la sanitización y el cleanup no reemplazante, e identificar el handoff worker no atómico y los deadlines staged incompletos.
   - [x] Corregir bajo SEM-01-DB-26 el handoff `starter → worker` failure-atomic, el orden terminal de ambos starters, el cleanup defensivo y los deadlines monotónicos post-read y pre-return, con fixtures locales y sin conexión.
   - [x] Aprobar DB-26 mediante una revisión local separada.
   - [x] Corregir bajo SEM-01-DB-27 el holder temporizado de MS06 mediante etapas controladas, doble observación del mismo lock, release posterior a `55P03` y cleanup completo antes del rollback exitoso, con fixtures locales y sin conexión.
   - [ ] Aprobar DB-27 mediante una revisión local separada.
   - [ ] Reanudar el LAB, ejecutar `-ReadOnlyProbeOnly`, revisar el resultado y sólo entonces autorizar `-Execute`.
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
