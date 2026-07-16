# Auditoría arquitectónica de la base de datos

## Alcance y método

Esta auditoría es de sólo lectura. Contrasta la migración baseline `0001_baseline_current_schema.sql`, los catorce artefactos reconciliados de `supabase/reconciliation/live/`, las llamadas Supabase de `app/`, `lib/` y `components/`, los tipos de `types/` y la documentación funcional vigente. No se consultó Supabase remoto, no se inspeccionaron datos personales y no se modificó la aplicación ni la baseline.

La evidencia refleja el snapshot reconciliado disponible en el repositorio. Aunque el esquema principal conserva `--no-privileges`, los snapshots especializados de rutinas, tablas, secuencias y ACL resuelven la incertidumbre sobre grants efectivos que antes se registró como M-08.

## Resumen ejecutivo

La estructura tiene una base coherente para el MVP: las 17 tablas públicas tienen RLS habilitado, no hay índices exactamente duplicados, las funciones `SECURITY DEFINER` declaran un `search_path` controlado y los flujos centrales de semestre, ventana normal de asistencia, reapertura extraordinaria y privacidad de la lista de participantes están representados.

Sin embargo, no conviene ampliar todavía el sistema con formularios, reportes u otros módulos sensibles. Se confirmaron seis hallazgos altos:

1. La política RLS de `activities` permite leer borradores a responsables, participantes y roles de gestión, aunque el producto establece visibilidad exclusiva para `created_by`.
2. `technical_admin` recibe acceso académico amplio por `can_manage_activity`, contrario a la documentación de permisos.
3. Los RPC manuales permiten devolver una asistencia vencida a `pending`, aunque ese estado debe ser temporal.
4. La integridad de una actividad publicada depende de la aplicación; la base permite una fila `scheduled` incompleta si se usa la API directamente.
5. Las 30 funciones públicas, incluidos ocho RPC de mutación, conceden `EXECUTE` explícito a `PUBLIC` y `anon`.
6. `anon` y `authenticated` tienen privilegios de tabla y mantenimiento mucho más amplios que los flujos expuestos por SITAA.

A-02 se conserva como riesgo conocido, pero queda diferido intencionalmente durante desarrollo y pruebas hasta diseñar la administración de usuarios, roles y permisos. La migración 0002 inicial debe concentrarse en A-01, A-03, A-04 y las correcciones de privilegios confirmadas por los snapshots.

Se identificaron **cuatro candidatos potencialmente obsoletos o sin uso conocido**: tres funciones (`can_create_activity(uuid,text)`, `can_manage_activity(uuid,text)` y `has_active_role(text)`) y la columna `activities.updated_by`. Ninguno debe retirarse sin ejecutar primero las consultas de dependencias y verificar consumidores externos.

### Conteo de hallazgos

| Severidad | Cantidad |
| --- | ---: |
| Crítica | 0 |
| Alta | 6 |
| Media | 7 |
| Baja | 4 |
| Informativa | 5 |

## Inventario reconciliado

| Objeto | Cantidad |
| --- | ---: |
| Tablas públicas | 17 |
| Columnas | 151 |
| Restricciones | 61 |
| Índices | 37 |
| Triggers | 4 |
| Funciones y firmas | 30 |
| Políticas RLS | 23 |
| Filas de semillas controladas | 51 |
| Grants de rutinas | 150 |
| Grants de tablas en `information_schema` | 476 |
| Grants de secuencia | 12 |
| Entradas ACL expandidas | 706 |

Módulos representados: salud del sistema, perfiles, roles y asignaciones, divisiones y programas, semestres, catálogos operativos, actividades, participantes, asistencia manual, tokens QR/código y expiración/reapertura de asistencia.

## Áreas confirmadas como saludables

- Las 17 tablas tienen RLS habilitado. `activity_checkin_tokens` no tiene políticas directas y queda accesible mediante RPC con validación interna, lo cual es coherente con el carácter secreto de sus tokens.
- Las 29 funciones `SECURITY DEFINER` declaran `SET search_path TO 'public'`; `set_updated_at()` es la única función `SECURITY INVOKER`.
- No hay índices exactamente duplicados. La unicidad de participante por actividad y de tokens activos está protegida.
- `get_academic_period_for_date(date)` elige el semestre activo con el `starts_on` más reciente que no sea posterior a la fecha. Esto conserva la asignación intersemestral y coincide con la aplicación.
- La ventana normal usa `America/Mexico_City`: abre 15 minutos antes del inicio y cierra 15 minutos después del término. Las reaperturas posteriores duran 15 minutos según `expires_at` y pueden repetirse.
- `check_in_activity(text)` distingue `qr`/enlace de `code`, protege `justified` y la ausencia manual, y permite corregir una ausencia creada por el sistema durante una reapertura válida.
- La política de `activity_participants` permite al alumno leer sólo su propia fila; el roster completo requiere `can_read_activity`.
- `postgres` y `service_role` conservan el acceso administrativo esperado; `authenticator` no aparece como receptor directo y no se observaron otros roles en las ACL.
- No falta ningún grant requerido por las llamadas actuales de la aplicación: `authenticated` puede ejecutar los 30 RPC y conserva los privilegios de tabla necesarios. El problema confirmado es exceso, no ausencia.
- Los códigos internos verificados son estables y coherentes: `tutoring`/`advising`, `student`/`worker`, `graphic_design`/`architecture`, `online` para modalidad y `online_space` para tipo de ubicación. No hay motivo para renombrarlos por razones cosméticas.

## Hallazgos críticos

No se confirmó ningún hallazgo crítico con la evidencia disponible.

## Hallazgos altos

### A-01 — Los borradores no están aislados por RLS

- **Objetos afectados:** política `Users can read permitted activities`, `can_read_activity(uuid)`, `can_edit_activity(uuid)`, política SELECT de `activity_participants` y consulta directa de `/activities/[id]`.
- **Evidencia:** la política SELECT de `activities` autoriza `created_by`, `responsible_profile_id`, `is_activity_participant(id)` o `can_manage_activity(...)` sin condicionar `status_code`. `get_visible_activity_cards()` sí filtra correctamente `draft` por `created_by`, pero la página de detalle lee `activities` directamente.
- **Llamadores/dependencias actuales:** `/activities` usa el RPC seguro; `/activities/[id]` usa `.from("activities").select("*")`; `can_read_activity` controla la lectura administrativa del roster.
- **Riesgo:** exposición de borradores incompletos a un responsable distinto del creador, participantes agregados o roles amplios. La protección de interfaz no sustituye RLS.
- **Acción recomendada:** en una migración revisada, expresar en RLS y en los helpers de lectura la regla: `draft` sólo para `created_by`; otros estados según responsabilidad, participación y gestión. Probar acceso directo REST/RPC además de la interfaz.
- **Confianza:** alta.

### A-02 — `technical_admin` obtiene acceso académico amplio implícito

- **Estado:** diferido intencionalmente durante desarrollo y pruebas. **Deferred intentionally until user, role and permission administration is designed.**

- **Objetos afectados:** `can_manage_activity(text,uuid,uuid,text)`, `can_edit_activity(uuid)`, `can_read_activity(uuid)`, `can_update_activity_base(uuid)`, `can_delete_activity(uuid)` y políticas/RPC que los invocan.
- **Evidencia:** la rama `ra.role_code = 'technical_admin'` de `can_manage_activity` no exige alcance, programa, división ni una asignación académica adicional. La documentación establece que el rol técnico no obtiene lectura amplia de contenido sensible.
- **Llamadores/dependencias actuales:** políticas CRUD de `activities`, políticas de `activity_participants`, gestión de participantes, asistencia, QR/código y corrección base.
- **Riesgo:** lectura y modificación de actividades, rosters y asistencia por una responsabilidad exclusivamente técnica. También amplía la visibilidad de borradores por A-01.
- **Acción recomendada:** no cambiarlo en 0002. Cuando exista administración de usuarios, roles y permisos, separar soporte técnico de gestión académica y exigir una asignación administrativa/académica explícita para contenido sensible.
- **Confianza:** alta.

### A-03 — Una asistencia vencida puede volver a `pending` mediante RPC

- **Objetos afectados:** `update_activity_participant_attendance(uuid,text,text)` y `update_activity_participants_attendance_bulk(uuid,uuid[],text,text)`.
- **Evidencia:** ambos RPC aceptan `pending` sin consultar `activity_attendance_deadline`. La interfaz oculta esa opción cuando vence la ventana, pero la función puede invocarse directamente. `finalize_expired_attendance()` sólo normaliza de manera perezosa al cargar flujos relevantes.
- **Llamadores/dependencias actuales:** acciones individuales y masivas de `/activities/[id]`; cualquier cliente autenticado con permiso de edición puede invocar el RPC.
- **Riesgo:** actividades cerradas pueden conservar temporal o indefinidamente asistencia pendiente, afectando indicadores y reportes. La regla queda dividida entre interfaz y base.
- **Acción recomendada:** rechazar `pending` en ambos RPC cuando el plazo natural haya vencido, o normalizarlo atómicamente a `absent/system`. Mantener correcciones finales `attended`, `absent` y `justified`.
- **Confianza:** alta.

### A-04 — La publicación completa sólo se valida en TypeScript

- **Objetos afectados:** tabla `activities`, política INSERT, `can_create_activity(text,uuid,uuid,text)` y acciones de creación/publicación.
- **Evidencia:** varias columnas operativas son anulables para permitir borradores. La política INSERT verifica creador y permiso de alcance, pero no exige campos completos cuando `status_code = 'scheduled'`. La aplicación sí valida título, catálogos, ubicación, fecha, hora y duración.
- **Llamadores/dependencias actuales:** `app/activities/actions.ts` implementa la validación; un uso directo de la API puede omitirla. `activity_attendance_deadline` incluso tiene valores de respaldo para horarios incompletos.
- **Riesgo:** actividades publicadas incompletas, semestres o ventanas de asistencia incoherentes y fallos posteriores en reportes.
- **Acción recomendada:** centralizar la transición de publicación en un RPC transaccional o en una validación de base condicionada por estado, preservando la flexibilidad de `draft`. No imponer `NOT NULL` global a campos que un borrador puede omitir.
- **Confianza:** alta.

### A-05 — Todos los RPC permiten `EXECUTE` a `PUBLIC` y `anon`

- **Objetos afectados:** las 30 firmas públicas, en especial `add_activity_participant`, `remove_activity_participant`, `update_activity_participant_attendance`, `update_activity_participants_attendance_bulk`, `open_activity_attendance_checkin`, `close_activity_attendance_checkin`, `check_in_activity` y `finalize_expired_attendance`.
- **Evidencia:** `live_routine_privileges.sql` contiene 150 filas: cada firma concede `EXECUTE` a `PUBLIC`, `anon`, `authenticated`, `postgres` y `service_role`. `live_acl.sql` confirma las mismas 150 entradas; todas tienen ACL explícita, no `<default>`.
- **Llamadores/dependencias actuales:** los siete RPC administrativos o de check-in dependen de controles internos; `finalize_expired_attendance()` no valida al llamador y realiza actualizaciones globales deterministas. Los helpers de horario `SECURITY DEFINER` tampoco verifican permiso antes de devolver fechas para un UUID conocido.
- **Riesgo:** cualquier sesión anónima puede invocar la superficie RPC. Los controles internos rechazan a `anon` en altas, bajas, asistencia, apertura y cierre porque `auth.uid()` es nulo, pero el grant permite sondeo, carga innecesaria y diferencias de error. `finalize_expired_attendance()` sí puede producir cambios globales vencidos sin autenticación.
- **Acción recomendada:** revocar `EXECUTE` a `PUBLIC` y `anon` en las 30 firmas; conservar `authenticated`, `service_role` y `postgres`. Evaluar después, con consumidores externos verificados, si `authenticated` debe perder funciones internas como `generate_three_word_code()` o `set_updated_at()`.
- **Confianza:** alta.

### A-06 — Privilegios directos de tabla y secuencia exceden el modelo RLS

- **Objetos afectados:** las 17 tablas públicas y `system_health_id_seq`.
- **Evidencia:** `live_table_privileges.sql` muestra para `anon`, `authenticated`, `postgres` y `service_role` los siete privilegios `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES` y `TRIGGER` sobre cada tabla. La ACL añade `MAINTAIN` para esos cuatro roles. La secuencia concede `SELECT`, `UPDATE` y `USAGE` a los mismos roles. No hay grants de tabla o secuencia para `PUBLIC`.
- **Llamadores/dependencias actuales:** la aplicación anónima sólo consulta `system_health`; usuarios autenticados leen catálogos y usan acceso directo acotado para perfiles, roles y actividades. Participantes y tokens usan principalmente RPC.
- **Riesgo:** RLS bloquea la lectura y DML anónimos sin política, por lo que no se confirmó exposición directa de filas sensibles. Sin embargo, `TRUNCATE` y capacidades de mantenimiento no son controles por fila y sobran en roles de cliente; los catálogos supuestamente de sólo lectura también tienen grants de escritura.
- **Acción recomendada:** dejar a `anon` únicamente `SELECT` en `system_health`; retirar privilegios utilitarios a `authenticated`; reducir catálogos a `SELECT`; retirar acceso directo autenticado a `activity_checkin_tokens`; retirar acceso de secuencia a `anon` y `authenticated`; conservar administración para `postgres`/`service_role`.
- **Confianza:** alta sobre ACL directas; la herencia de roles no puede evaluarse porque el snapshot no incluye `pg_auth_members`.

## Hallazgos medios

### M-01 — No existe unicidad para identificadores institucionales

- **Objetos afectados:** `profiles.institutional_id_type`, `profiles.institutional_id_value`.
- **Evidencia:** hay checks de tipo y consistencia persona/identificador, pero no restricción o índice único sobre el par.
- **Llamadores/dependencias actuales:** búsqueda de perfiles, alta de participantes y listas de asistencia.
- **Riesgo:** cuentas distintas podrían compartir número de cuenta o de trabajador, dificultando seleccionar a la persona correcta.
- **Acción recomendada:** auditar duplicados de forma agregada, resolverlos y después crear unicidad parcial para valores no nulos/no vacíos.
- **Confianza:** alta.

### M-02 — Claves foráneas de rutas frecuentes carecen de índices útiles

- **Objetos afectados:** 16 claves foráneas sin índice líder, en particular `role_assignments.user_id`, `role_assignments.role_code`, `role_assignments.program_id`, `role_assignments.division_id`, `profiles.primary_program_id`, `academic_programs.division_id` y varios catálogos de `activities`.
- **Evidencia:** el snapshot contiene 37 índices, pero ninguno comienza por esas columnas. Los helpers de autorización consultan `role_assignments.user_id` en casi cada acceso.
- **Llamadores/dependencias actuales:** RLS y funciones `has_*`, `can_manage_activity`, carga de perfil, joins de tarjetas y futuros filtros/reportes.
- **Riesgo:** degradación creciente de autorización, joins y borrados referenciales conforme aumenten usuarios y actividades.
- **Acción recomendada:** medir planes y añadir primero índices compuestos/selectivos para roles activos por usuario; después los de joins y filtros comprobados. No crear indiscriminadamente los 16.
- **Confianza:** alta sobre la ausencia; media sobre la prioridad final sin métricas de carga.

### M-03 — Permanecen tres funciones candidatas de prototipo

- **Objetos afectados:** `can_create_activity(uuid,text)`, `can_manage_activity(uuid,text)` y `has_active_role(text)`.
- **Evidencia:** las políticas usan las firmas actuales de cuatro parámetros; la aplicación no llama estas tres funciones. Las firmas antiguas no consideran todo el alcance y la de creación concede una respuesta positiva a roles amplios sin validar programa propio.
- **Llamadores/dependencias actuales:** la firma antigua de `can_create_activity` llama a la firma antigua de `can_manage_activity` y a `has_any_active_role`; no se encontró consumidor de `has_active_role` en snapshots o aplicación.
- **Riesgo:** ambigüedad para nuevos desarrollos y reutilización accidental de reglas menos precisas.
- **Acción recomendada:** ejecutar el análisis `pg_depend`, revisar privilegios y buscar consumidores externos antes de retirar las tres firmas en 0002.
- **Confianza:** media-alta; no se conocen clientes externos.

### M-04 — Tipos y documentación no reflejan exactamente el esquema vivo

- **Objetos afectados:** tipos `Division`, `AcademicProgram`, `Role`, `Profile`, `RoleAssignment`, `ActivityParticipant`; `docs/DATA_MODEL.md`.
- **Evidencia:** TypeScript/documentación esperan, entre otros, `divisions.is_active`, `academic_programs.is_active`, `roles.id`, `roles.is_active` y `role_assignments.status`, que no existen. La base permite nulos de bootstrap que varios tipos declaran obligatorios. Participantes usan `added_by` en base y un alias opcional `created_by` en aplicación.
- **Llamadores/dependencias actuales:** contexto autenticado, formularios, panel, catálogos y adaptadores RPC.
- **Riesgo:** casts que ocultan datos ausentes, ramas de interfaz basadas en propiedades inexistentes y futuras migraciones diseñadas desde un contrato incorrecto.
- **Acción recomendada:** escoger explícitamente el contrato canónico y alinear tipos/documentación en un cambio separado; no añadir columnas sólo para satisfacer tipos heredados.
- **Confianza:** alta.

### M-05 — Dos representaciones temporales pueden divergir

- **Objetos afectados:** `activities.start_date`, `start_time`, `end_date`, `end_time`, `starts_at`, `ends_at` y `activities_time_order_check`.
- **Evidencia:** la aplicación escribe ambas representaciones, pero no hay trigger/check que pruebe su equivalencia. La restricción de orden sólo compara `starts_at` y `ends_at`; asistencia usa los campos separados y la lista conserva `starts_at` como respaldo.
- **Llamadores/dependencias actuales:** acciones de actividad, tarjetas, detección de actividad ocurrida y asistencia.
- **Riesgo:** fecha visible, ordenamiento, bloqueo y vencimiento pueden discrepar si otro cliente actualiza sólo una representación.
- **Acción recomendada:** declarar los campos separados como fuente de verdad y derivar los timestamps en base, o retirar la compatibilidad después de comprobar consumidores y datos.
- **Confianza:** alta.

### M-06 — Las asignaciones de rol permiten duplicidad y dimensiones residuales

- **Objetos afectados:** `role_assignments` y `valid_role_assignment_scope`.
- **Evidencia:** no hay unicidad para asignaciones activas equivalentes. El check exige `program_id` para alcance `program`, pero no obliga `division_id` a nulo; para alcance `division` no obliga `program_id` a nulo.
- **Llamadores/dependencias actuales:** todos los helpers de autorización y el contexto autenticado.
- **Riesgo:** asignaciones solapadas, resultados duplicados y datos dimensionales ambiguos que hoy son ignorados de forma distinta por cada helper.
- **Acción recomendada:** consultar duplicados/solapamientos, definir si programa debe conservar además la división y reforzar la regla sólo después de esa decisión. Preferir una restricción que permita historial legítimo.
- **Confianza:** alta sobre la estructura; media sobre la regla dimensional final.

### M-07 — La lógica de asistencia tiene duplicación y una diferencia de timestamp

- **Objetos afectados:** `activity_attendance_open_at`, `activity_attendance_deadline`, `get_activity_attendance_checkin_state`, actualización manual individual y masiva.
- **Evidencia:** el RPC de estado reconstruye horarios en vez de delegar completamente en los dos helpers. La actualización masiva fija `checked_in_at = coalesce(..., now())` al marcar `attended`; la individual conserva el valor existente y puede dejarlo nulo.
- **Llamadores/dependencias actuales:** panel QR/código y controles manuales individual/masivo.
- **Riesgo:** una futura corrección puede aplicarse a una fórmula y no a la otra; el significado de `checked_in_at` depende del modo de edición.
- **Acción recomendada:** centralizar el cálculo de ventana y decidir si `checked_in_at` significa check-in efectivo o cualquier confirmación manual. Aplicar una semántica consistente.
- **Confianza:** alta.

## Hallazgos bajos

### B-01 — `activities.updated_by` no tiene escritor conocido

- **Objetos afectados:** `activities.updated_by` y su clave foránea.
- **Evidencia:** no aparece en acciones ni funciones; sólo existe en el esquema.
- **Llamadores/dependencias actuales:** no se encontraron referencias conocidas, fuera de la restricción.
- **Riesgo:** columna siempre nula y expectativa falsa de auditoría.
- **Acción recomendada:** decidir si debe poblarse automáticamente; si no, verificar datos y consumidores externos antes de retirarla.
- **Confianza:** media-alta.

### B-02 — Cobertura desigual y duplicada de `updated_at`

- **Objetos afectados:** catálogos con `updated_at`, triggers de `activities`, `activity_participants`, `profiles` y `role_assignments`.
- **Evidencia:** sólo cuatro tablas tienen trigger. Varios RPC además escriben `updated_at = now()` en tablas que ya tienen trigger.
- **Llamadores/dependencias actuales:** mutaciones de asistencia y actualizaciones de perfil/actividad.
- **Riesgo:** timestamps de catálogos pueden quedar obsoletos si un editor futuro no los actualiza; las escrituras duplicadas agregan ruido.
- **Acción recomendada:** adoptar una convención única y añadir triggers sólo a tablas realmente mutables.
- **Confianza:** alta.

### B-03 — El adaptador de tarjetas compensa un contrato RPC incompleto

- **Objetos afectados:** `get_visible_activity_cards()` y `lib/activities/get-visible-activities.ts`.
- **Evidencia:** el RPC no devuelve `program_id`, `division_id`, `created_by` ni varios códigos; el adaptador acepta múltiples alias y realiza una segunda consulta directa a `activities`.
- **Llamadores/dependencias actuales:** `/activities` y resumen de `/activities/[id]`.
- **Riesgo:** más viajes, casts amplios y posibilidad de ocultar una deriva futura del retorno.
- **Acción recomendada:** versionar un retorno canónico y tipado; mantener compatibilidad hasta desplegar conjuntamente base y aplicación.
- **Confianza:** alta.

### B-04 — La finalización perezosa oculta sus fallos en la aplicación

- **Objetos afectados:** `lib/attendance/finalize-expired-attendance.ts`.
- **Evidencia:** el helper captura cualquier error y no lo registra ni lo devuelve. Sí se llama antes de `/activities`, `/activities/[id]`, `/check-in` y `/check-in/[token]`.
- **Llamadores/dependencias actuales:** las cuatro rutas requeridas y la acción de código manual.
- **Riesgo:** un fallo de permisos o base deja estados pendientes sin señal operativa, aunque la interfaz siga cargando.
- **Acción recomendada:** incorporar observabilidad sanitizada del lado servidor y conservar mensajes no técnicos para usuarios.
- **Confianza:** alta.

## Hallazgos informativos

### I-01 — Semestres por frontera de inicio

`get_academic_period_for_date(date)` implementa correctamente la frontera `starts_on <= target_date`, orden descendente y primer resultado activo. `ends_on` documenta el calendario, pero no corta la asignación intersemestral. No se encontró una función antigua basada en rangos.

### I-02 — Núcleo de asistencia coherente

Fuera de A-03 y M-07, el flujo mantiene una fuente práctica de verdad: helpers para apertura/plazo, tokens con `expires_at`, finalización a `absent/system`, reaperturas de 15 minutos y protección de estados manuales/justificados. Todas las conversiones naturales observadas usan `America/Mexico_City`.

### I-03 — RLS completo por tabla, pero grants de objeto no mínimos

Todos los objetos de datos públicos tienen RLS. Las políticas mantienen catálogos y `system_health` como lectura, limitan perfiles/asignaciones y ocultan tokens. Los grants de objeto no reflejan esas limitaciones, por lo que A-06 debe corregirse aunque RLS continúe como autorización por fila.

### I-04 — Índices y unicidades principales

No existen índices idénticos. `activity_checkin_tokens_activity_id_idx` no queda sustituido por el índice único parcial `(activity_id, token_type)`, porque el primero cubre todos los tokens. La unicidad `(activity_id, profile_id)`, `secret_token`, código activo y token activo por actividad/tipo está bien definida.

### I-05 — Catálogos y estados futuros

Los códigos sembrados coinciden con la aplicación. Estados como `open`, `completed`, `validated` y `cancelled` exceden el flujo actual `draft`/`scheduled`, pero constituyen capacidad futura documentada; no deben eliminarse por falta de uso inmediato.

## Inventario de funciones, firmas y dependencias conocidas

`STABLE` describe consultas contextuales; `VOLATILE` incluye mutaciones o generación aleatoria. Todas las filas son `SECURITY DEFINER` salvo `set_updated_at()`.

| Firma | Volatilidad | Llamadores/dependencias conocidas | Evaluación |
| --- | --- | --- | --- |
| `activity_attendance_deadline(uuid)` | STABLE | aplicación; finalización, apertura y estado | Vigente |
| `activity_attendance_open_at(uuid)` | STABLE | aplicación; apertura, token activo y estado | Vigente |
| `activity_has_ended(uuid)` | STABLE | aplicación; permisos base y borrado | Vigente |
| `add_activity_participant(uuid,uuid,text)` | VOLATILE | acción de participantes; `can_edit_activity` | Vigente |
| `can_create_activity(text,uuid,uuid,text)` | STABLE | política INSERT; `can_manage_activity`, `has_any_active_role` | Vigente |
| `can_create_activity(uuid,text)` | STABLE | sólo firma antigua `can_manage_activity(uuid,text)` y `has_any_active_role` | Candidata, verificar |
| `can_delete_activity(uuid)` | STABLE | política DELETE y aplicación | Vigente |
| `can_edit_activity(uuid)` | STABLE | políticas de participantes; RPC de participantes/asistencia/tokens | Vigente |
| `can_manage_activity(text,uuid,uuid,text)` | STABLE | políticas y helpers actuales | Vigente, requiere A-02 |
| `can_manage_activity(uuid,text)` | STABLE | firma antigua de creación | Candidata, verificar |
| `can_read_activity(uuid)` | STABLE | política SELECT de participantes | Vigente |
| `can_update_activity_base(uuid)` | STABLE | política UPDATE y aplicación | Vigente |
| `check_in_activity(text)` | VOLATILE | `/check-in` y `/check-in/[token]`; finalización | Vigente |
| `close_activity_attendance_checkin(uuid)` | VOLATILE | acciones QR/código; `can_edit_activity` | Vigente |
| `finalize_expired_attendance()` | VOLATILE | cuatro rutas; apertura, token activo y check-in | Vigente; revisar A-03/B-04 |
| `generate_three_word_code()` | VOLATILE | apertura de asistencia | Vigente |
| `get_academic_period_for_date(date)` | STABLE | creación/edición de actividad | Vigente |
| `get_active_activity_attendance_checkin(uuid)` | VOLATILE | detalle de actividad; finalización y permisos | Vigente |
| `get_activity_attendance_checkin_state(uuid)` | STABLE | detalle de actividad | Vigente; revisar M-07 |
| `get_activity_participants(uuid)` | STABLE | detalle de actividad; `can_read_activity` | Vigente |
| `get_visible_activity_cards()` | STABLE | listado/detalle; permisos y participación | Vigente; revisar B-03 |
| `has_active_role(text)` | STABLE | sin llamador conocido | Candidata, verificar |
| `has_any_active_role(text[])` | STABLE | creación antigua y actual | Vigente mientras exista ese uso |
| `is_activity_participant(uuid)` | STABLE | política SELECT y tarjetas | Vigente |
| `open_activity_attendance_checkin(uuid)` | VOLATILE | acciones QR/código; helpers de ventana/generador | Vigente |
| `remove_activity_participant(uuid)` | VOLATILE | acción de participantes; `can_edit_activity` | Vigente |
| `search_profiles_for_participation(uuid,text)` | STABLE | búsqueda de participantes | Vigente |
| `set_updated_at()` | VOLATILE, INVOKER | cuatro triggers | Vigente |
| `update_activity_participant_attendance(uuid,text,text)` | VOLATILE | edición individual | Vigente; corregir A-03/M-07 |
| `update_activity_participants_attendance_bulk(uuid,uuid[],text,text)` | VOLATILE | edición masiva | Vigente; corregir A-03 |

No se detectó una función con `SECURITY DEFINER` sin `search_path` controlado. Los nombres de parámetros usan prefijos como `target_` y `new_`; no se confirmó una ambigüedad PL/pgSQL vigente entre parámetros y columnas de salida.

## Cobertura RLS por tabla

| Tabla o grupo | Políticas observadas | Evaluación |
| --- | --- | --- |
| `activities` | SELECT, INSERT, UPDATE, DELETE | Completa, pero SELECT es demasiado amplio para borradores |
| `activity_participants` | SELECT, INSERT, UPDATE, DELETE | Completa; alumno sólo ve su fila |
| `activity_checkin_tokens` | Sin políticas directas | Intencional si grants y RPC quedan acotados |
| `profiles` | SELECT/UPDATE propios | Intencional; sin registro público |
| `role_assignments` | SELECT propio | Intencional; administración aún fuera del flujo |
| Catálogos y semestres | SELECT para `authenticated` | Intencionalmente de sólo lectura |
| `system_health` | SELECT para `anon` | Intencional y sin datos sensibles |

No hay dos políticas del mismo comando que se solapen sobre una tabla. La principal amplitud no proviene de políticas duplicadas, sino de expresiones helper demasiado amplias.

## Privilegios efectivos y ACL

### Resolución de M-08

M-08 queda **resuelto como incertidumbre**: existen snapshots completos y concordantes. La evidencia no demuestra un perímetro mínimo; demuestra dos excesos confirmados, reclasificados como A-05 y A-06.

- Rutinas: 150 grants, correspondientes a 30 firmas × 5 receptores.
- Tablas: 476 grants de `information_schema`, correspondientes a 17 tablas × 7 privilegios × 4 receptores.
- ACL de tablas: las 476 combinaciones anteriores coinciden y agregan 68 entradas `MAINTAIN` no mostradas por `information_schema.table_privileges`.
- Secuencias: 12 grants, correspondientes a una secuencia × 3 privilegios × 4 receptores.
- ACL total: 706 entradas sobre 48 objetos; ninguna usa `<default>`. El `EXECUTE` de `PUBLIC` es explícito, no sólo el privilegio implícito predeterminado de PostgreSQL.

No se detectó una discrepancia contradictoria entre las vistas y ACL. La diferencia documentada es de cobertura: `live_acl.sql` incluye `MAINTAIN`, mientras `information_schema.table_privileges` no lo reporta. No hay evidencia de membresía de roles porque el snapshot no captura `pg_auth_members`; por tanto, no se infiere acceso heredado de `authenticator`.

### Matriz resumida de rutinas

| Receptor | Objetos con `EXECUTE` | Evaluación |
| --- | ---: | --- |
| `PUBLIC` | 30/30 | Excesivo; retirar |
| `anon` | 30/30 | Excesivo; SITAA exige autenticación para todos los RPC actuales |
| `authenticated` | 30/30 | Suficiente para la aplicación; más amplio que el mínimo interno |
| `service_role` | 30/30 | Administrativo esperado; la aplicación no usa su clave |
| `postgres` | 30/30, con capacidad de delegación | Propietario esperado |
| `authenticator` | 0 grants directos | Correcto; membresía no capturada |
| Otros roles | Ninguno observado | Sin evidencia adicional |

Los RPC administrativos `add_activity_participant`, `remove_activity_participant`, las dos actualizaciones manuales y `open`/`close` dependen de `can_edit_activity` y rechazan a un anónimo. `check_in_activity` exige implícitamente un `auth.uid()` que coincida con un participante. Esas defensas son necesarias, pero no justifican conceder `EXECUTE` a `PUBLIC` o `anon`. `finalize_expired_attendance()` es la excepción: no valida al llamador y puede mutar globalmente filas vencidas.

### Matriz resumida de tablas

| Categoría | Grants observados | RLS/política | Desviación |
| --- | --- | --- | --- |
| Tablas sensibles: `profiles`, `role_assignments`, `activities`, `activity_participants`, `activity_checkin_tokens` | Los 8 privilegios ACL para `anon` y `authenticated` | RLS bloquea filas no autorizadas | `TRUNCATE`/`MAINTAIN` y grants no usados son excesivos |
| 11 catálogos/semestres | Los 8 privilegios ACL para `anon` y `authenticated` | Sólo SELECT para `authenticated` | Deben quedar en SELECT autenticado |
| `system_health` | Los 8 privilegios ACL para `anon` y `authenticated` | SELECT anónimo deliberado | `anon` sólo necesita SELECT |
| Todas las tablas | Acceso completo para `postgres` y `service_role` | Roles administrativos | Confirmado como esperado para el prototipo |
| Todas las tablas | Sin ACL para `PUBLIC` | Sin acceso directo | Correcto |

No se confirmó lectura de filas sensibles por `anon`: las políticas RLS no la permiten. El riesgo confirmado está en la capacidad de objeto innecesaria, especialmente operaciones que no son autorización por fila.

### Secuencia

El único objeto es `system_health_id_seq`. `anon`, `authenticated`, `service_role` y `postgres` tienen `SELECT`, `UPDATE` y `USAGE`; `PUBLIC` y `authenticator` no tienen grant directo. Como las demás claves primarias de SITAA usan UUID, la secuencia no participa en actividades, perfiles, roles, participantes ni tokens. Los clientes no necesitan acceso; puede conservarse para administración/propietario.

### Grants confirmados como suficientes, excesivos o ausentes

- **Seguros/suficientes:** acceso de propietario `postgres`; acceso administrativo `service_role`; `authenticated` para RPC vigentes, lectura de catálogos y operaciones directas que usa la aplicación; `anon` SELECT de `system_health`.
- **Excesivos:** `EXECUTE` de `PUBLIC`/`anon`; todos los grants de tabla de `anon` salvo `system_health.SELECT`; privilegios `TRUNCATE`, `REFERENCES`, `TRIGGER` y `MAINTAIN` de `authenticated`; escritura autenticada en catálogos; acceso directo autenticado a tokens; acceso de secuencia para clientes.
- **Ausentes:** no falta un privilegio requerido por la aplicación actual. `authenticator` no necesita ACL directa según la evidencia disponible.

### Operaciones explícitas recomendadas para una migración futura

Este bloque es una recomendación auditable, no una migración creada ni ejecutada:

```sql
revoke execute on all functions in schema public from public, anon;

revoke all privileges on all tables in schema public from anon;
grant select on table public.system_health to anon;

revoke truncate, references, trigger, maintain
on all tables in schema public from authenticated;

revoke insert, update, delete on table
  public.academic_periods,
  public.academic_programs,
  public.activity_modalities,
  public.activity_statuses,
  public.activity_types,
  public.attention_categories,
  public.divisions,
  public.location_types,
  public.participant_roles,
  public.roles,
  public.service_types,
  public.system_health,
  public.role_assignments
from authenticated;

revoke insert, delete on table public.profiles from authenticated;
revoke all privileges on table public.activity_checkin_tokens from authenticated;
revoke all privileges on sequence public.system_health_id_seq from anon, authenticated;
```

La migración debe conservar `SELECT/INSERT/UPDATE/DELETE` autenticado sobre `activities`, mantener por ahora el contrato RLS de `activity_participants`, conservar `SELECT/UPDATE` propio de `profiles` y `SELECT` de `role_assignments`. No se recomienda cambiar grants de `service_role` o `postgres` en 0002. Tampoco se recomienda modificar privilegios de las firmas heredadas para `authenticated` hasta verificar consumidores externos.

## Objetos que parecen redundantes pero todavía no deben eliminarse

- `can_create_activity(uuid,text)` y `can_manage_activity(uuid,text)`: parecen firmas anteriores al modelo con alcance; requieren `pg_depend`, revisión de grants y búsqueda de clientes externos.
- `has_active_role(text)`: no tiene llamadores conocidos, pero puede ser un RPC consumido fuera del repositorio.
- `can_edit_activity(uuid)` y `can_read_activity(uuid)`: hoy tienen lógica sustancialmente igual, pero representan capacidades distintas y ambas tienen dependencias. Conviene compartir un núcleo, no borrar una firma sin transición.
- `activities.starts_at` y `activities.ends_at`: duplican fecha/hora separadas, pero están documentadas como compatibilidad y aún participan en la aplicación.
- `activities.updated_by`: no tiene escritor conocido; debe comprobarse si contiene datos o es usado por integraciones.
- `activity_checkin_tokens_activity_id_idx`: comparte prefijo con un índice parcial, pero no es un duplicado funcional.

## Capacidades heredadas o reservadas intencionales

- `activities.scope_type = 'division'` y `program_id IS NULL` representan «Ambos programas». El MVP no los expone, pero se reservan para una necesidad futura y para limpiar registros heredados.
- `activity_checkin_tokens.token_type = 'registration'` reserva el flujo de inscripción/invitación. El flujo actual usa sólo `attendance`.
- `starts_at`/`ends_at` son compatibilidad temporal; no deben desaparecer hasta migrar consumidores.
- Los estados `open`, `completed`, `validated` y `cancelled` anticipan un ciclo posterior. Mantener códigos internos estables evita migraciones cosméticas.
- Los campos anulables de `profiles` permiten bootstrap técnico; el perfil completo sí exige datos estables desde la aplicación.

## Plan de consolidación propuesto

1. **0002 inicial:** aislamiento RLS de borradores, asistencia vencida no pendiente, publicación transaccional completa y correcciones de privilegios verificadas.
2. **Diferir A-02:** conservar temporalmente el acceso de `technical_admin` durante desarrollo/pruebas hasta diseñar administración de identidades y permisos.
3. **Validar datos antes de restricciones posteriores:** duplicados de identidad, asignaciones solapadas y divergencia temporal.
4. **Optimizar después:** índices de autorización y joins medidos.
5. **Consolidar contratos después:** retornos RPC, TypeScript y timestamps canónicos.
6. **Conservar legado/reservas:** no retirar overloads, columnas de compatibilidad, alcance divisional ni tokens de registro en 0002.

Cada paso debe ser pequeño, reversible y probado en un entorno no productivo antes de aplicarse manualmente.

## Candidatos para `0002_database_consolidation.sql`

La siguiente lista define el alcance inicial recomendado; esta auditoría no crea la migración:

1. Aplicar visibilidad RLS de borradores exclusivamente para `created_by` y alinear los helpers relacionados.
2. Rechazar `pending` en actualizaciones manuales o masivas después del plazo natural de asistencia.
3. Implementar una transición transaccional y completa de `draft` a `scheduled` en la base.
4. Aplicar sólo las correcciones de privilegios confirmadas: retirar `EXECUTE` de `PUBLIC`/`anon`, reducir tablas de `anon`, retirar capacidades utilitarias de `authenticated`, limitar catálogos/tokens y retirar la secuencia a roles cliente.
5. No restringir `technical_admin` todavía; A-02 permanece diferido intencionalmente.
6. No eliminar overloads heredados, columnas de compatibilidad ni capacidades reservadas.

Unicidad institucional, índices, dimensiones de roles, timestamps, contratos RPC y cualquier retiro de objetos deben quedar fuera de 0002 y tratarse en migraciones posteriores con evidencia adicional.

## Conclusión

La base reconciliada es comprensible y tiene controles importantes, pero **no es prudente extenderla antes de una consolidación de seguridad e integridad**. A-01 puede exponer borradores; A-03 y A-04 pueden producir asistencia o actividades publicadas inconsistentes; A-05 y A-06 confirman un perímetro de grants excesivo. A-02 sigue siendo alto, pero se difiere deliberadamente durante desarrollo y pruebas. La futura 0002 debe atender exactamente los puntos enumerados arriba, conservar las capacidades reservadas y posponer cualquier eliminación.
