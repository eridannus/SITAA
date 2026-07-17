# Auditoría arquitectónica de la base de datos

## Alcance y método

Esta auditoría es de sólo lectura. Contrasta la migración baseline `0001_baseline_current_schema.sql`, los catorce artefactos reconciliados de `supabase/reconciliation/live/`, las llamadas Supabase de `app/`, `lib/` y `components/`, los tipos de `types/` y la documentación funcional vigente. No se consultó Supabase remoto, no se inspeccionaron datos personales y no se modificó la aplicación ni la baseline.

La evidencia refleja el snapshot reconciliado disponible en el repositorio. Aunque el esquema principal conserva `--no-privileges`, los snapshots especializados de rutinas, tablas, secuencias y ACL resuelven la incertidumbre sobre grants efectivos que antes se registró como M-08.

## Resumen ejecutivo

La auditoría se actualizó el 2026-07-16 con el snapshot posterior a 0002 y 0003 (`2026-07-17T00:21:06Z`). La comparación local contra `0001 + 0002 + 0003` no encontró deriva inexplicada.

0002 resolvió A-01, A-03, A-04, A-05 y A-06: borradores privados al creador, `pending` vencido rechazado, publicación transaccional completa, `created_by` inmutable, transición inversa bloqueada y privilegios cliente mínimos. 0003 resolvió además el defecto temporal que atrapaba borradores con fechas provisionales pasadas o incompletas. Las verificaciones SQL y los smoke tests manuales terminaron correctamente.

A-02 permanece como único hallazgo alto activo y se conserva de forma deliberada durante desarrollo y pruebas. **Deferred intentionally until user, role and permission administration is designed.** `technical_admin` mantiene acceso amplio a contenido publicado, pero no a borradores ajenos.

Se identificaron **cuatro candidatos potencialmente obsoletos o sin uso conocido**: tres funciones (`can_create_activity(uuid,text)`, `can_manage_activity(uuid,text)` y `has_active_role(text)`) y la columna `activities.updated_by`. Ninguno debe retirarse sin ejecutar primero las consultas de dependencias y verificar consumidores externos.

### Conteo de hallazgos

| Severidad | Cantidad |
| --- | ---: |
| Crítica | 0 |
| Alta | 1 |
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
| Triggers | 6 |
| Funciones y firmas | 33 |
| Políticas RLS | 23 |
| Filas de semillas controladas | 51 |
| Grants de rutinas | 99 |
| Grants de tablas en `information_schema` | 262 |
| Grants de secuencia | 6 |
| Entradas ACL expandidas | 401 |

Módulos representados: salud del sistema, perfiles, roles y asignaciones, divisiones y programas, semestres, catálogos operativos, actividades, participantes, asistencia manual, tokens QR/código y expiración/reapertura de asistencia.

## Áreas confirmadas como saludables

- Las 17 tablas tienen RLS habilitado. `activity_checkin_tokens` no tiene políticas directas y queda accesible mediante RPC con validación interna, lo cual es coherente con el carácter secreto de sus tokens.
- Las 32 funciones `SECURITY DEFINER` declaran `SET search_path TO 'public'`; `set_updated_at()` es la única función `SECURITY INVOKER`.
- No hay índices exactamente duplicados. La unicidad de participante por actividad y de tokens activos está protegida.
- `get_academic_period_for_date(date)` elige el semestre activo con el `starts_on` más reciente que no sea posterior a la fecha. Esto conserva la asignación intersemestral y coincide con la aplicación.
- La ventana normal usa `America/Mexico_City`: abre 15 minutos antes del inicio y cierra 15 minutos después del término. Las reaperturas posteriores duran 15 minutos según `expires_at` y pueden repetirse.
- `check_in_activity(text)` distingue `qr`/enlace de `code`, protege `justified` y la ausencia manual, y permite corregir una ausencia creada por el sistema durante una reapertura válida.
- La política de `activity_participants` permite al alumno leer sólo su propia fila; el roster completo requiere `can_read_activity`.
- `postgres` y `service_role` conservan el acceso administrativo esperado; `authenticator` no aparece como receptor directo y no se observaron otros roles en las ACL.
- No falta ningún grant requerido por las llamadas actuales de la aplicación: `authenticated` puede ejecutar las 33 firmas y conserva los privilegios de tabla necesarios. `PUBLIC` y `anon` no ejecutan funciones SITAA.
- Los códigos internos verificados son estables y coherentes: `tutoring`/`advising`, `student`/`worker`, `graphic_design`/`architecture`, `online` para modalidad y `online_space` para tipo de ubicación. No hay motivo para renombrarlos por razones cosméticas.

## Hallazgos críticos

No se confirmó ningún hallazgo crítico con la evidencia disponible.

## Hallazgos altos

### A-01 — Los borradores no están aislados por RLS

- **Estado:** resuelto por 0002 y confirmado en el snapshot posterior a 0003. La evidencia siguiente describe el defecto original.

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

- **Estado:** resuelto por 0002. Las RPC individual y masiva y el trigger de tabla rechazan `pending` cuando el plazo natural es nulo o `<= now()`.

- **Objetos afectados:** `update_activity_participant_attendance(uuid,text,text)` y `update_activity_participants_attendance_bulk(uuid,uuid[],text,text)`.
- **Evidencia:** ambos RPC aceptan `pending` sin consultar `activity_attendance_deadline`. La interfaz oculta esa opción cuando vence la ventana, pero la función puede invocarse directamente. `finalize_expired_attendance()` sólo normaliza de manera perezosa al cargar flujos relevantes.
- **Llamadores/dependencias actuales:** acciones individuales y masivas de `/activities/[id]`; cualquier cliente autenticado con permiso de edición puede invocar el RPC.
- **Riesgo:** actividades cerradas pueden conservar temporal o indefinidamente asistencia pendiente, afectando indicadores y reportes. La regla queda dividida entre interfaz y base.
- **Acción recomendada:** rechazar `pending` en ambos RPC cuando el plazo natural haya vencido, o normalizarlo atómicamente a `absent/system`. Mantener correcciones finales `attended`, `absent` y `justified`.
- **Confianza:** alta.

### A-04 — La publicación completa sólo se valida en TypeScript

- **Estado:** resuelto por 0002 mediante `publish_activity(uuid)` y `validate_activity_scheduled_state()`.

- **Objetos afectados:** tabla `activities`, política INSERT, `can_create_activity(text,uuid,uuid,text)` y acciones de creación/publicación.
- **Evidencia:** varias columnas operativas son anulables para permitir borradores. La política INSERT verifica creador y permiso de alcance, pero no exige campos completos cuando `status_code = 'scheduled'`. La aplicación sí valida título, catálogos, ubicación, fecha, hora y duración.
- **Llamadores/dependencias actuales:** `app/activities/actions.ts` implementa la validación; un uso directo de la API puede omitirla. `activity_attendance_deadline` incluso tiene valores de respaldo para horarios incompletos.
- **Riesgo:** actividades publicadas incompletas, semestres o ventanas de asistencia incoherentes y fallos posteriores en reportes.
- **Acción recomendada:** centralizar la transición de publicación en un RPC transaccional o en una validación de base condicionada por estado, preservando la flexibilidad de `draft`. No imponer `NOT NULL` global a campos que un borrador puede omitir.
- **Confianza:** alta.

### A-05 — Todos los RPC permiten `EXECUTE` a `PUBLIC` y `anon`

- **Estado:** resuelto por 0002. El snapshot vivo no contiene grants de rutina para `PUBLIC` o `anon`.

- **Objetos afectados:** las 30 firmas públicas, en especial `add_activity_participant`, `remove_activity_participant`, `update_activity_participant_attendance`, `update_activity_participants_attendance_bulk`, `open_activity_attendance_checkin`, `close_activity_attendance_checkin`, `check_in_activity` y `finalize_expired_attendance`.
- **Evidencia:** `live_routine_privileges.sql` contiene 150 filas: cada firma concede `EXECUTE` a `PUBLIC`, `anon`, `authenticated`, `postgres` y `service_role`. `live_acl.sql` confirma las mismas 150 entradas; todas tienen ACL explícita, no `<default>`.
- **Llamadores/dependencias actuales:** los siete RPC administrativos o de check-in dependen de controles internos; `finalize_expired_attendance()` no valida al llamador y realiza actualizaciones globales deterministas. Los helpers de horario `SECURITY DEFINER` tampoco verifican permiso antes de devolver fechas para un UUID conocido.
- **Riesgo:** cualquier sesión anónima puede invocar la superficie RPC. Los controles internos rechazan a `anon` en altas, bajas, asistencia, apertura y cierre porque `auth.uid()` es nulo, pero el grant permite sondeo, carga innecesaria y diferencias de error. `finalize_expired_attendance()` sí puede producir cambios globales vencidos sin autenticación.
- **Acción recomendada:** revocar `EXECUTE` a `PUBLIC` y `anon` en las 30 firmas; conservar `authenticated`, `service_role` y `postgres`. Evaluar después, con consumidores externos verificados, si `authenticated` debe perder funciones internas como `generate_three_word_code()` o `set_updated_at()`.
- **Confianza:** alta.

### A-06 — Privilegios directos de tabla y secuencia exceden el modelo RLS

- **Estado:** resuelto por 0002. El snapshot vivo coincide con el perfil mínimo documentado.

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

Con A-03 resuelto, el flujo mantiene una fuente práctica de verdad: helpers para apertura/plazo, tokens con `expires_at`, finalización a `absent/system`, reaperturas de 15 minutos y protección de estados manuales/justificados. Todas las conversiones naturales observadas usan `America/Mexico_City`; M-07 permanece como oportunidad de consolidación.

### I-03 — RLS completo y grants mínimos verificados

Todos los objetos de datos públicos tienen RLS. Las políticas mantienen catálogos y `system_health` como lectura, limitan perfiles/asignaciones y ocultan tokens. El snapshot posterior a 0002 confirma que los grants directos reflejan esas limitaciones; A-06 está resuelto.

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
| `guard_activity_participant_pending_deadline()` | VOLATILE, trigger | trigger de `activity_participants` | Vigente; resuelve escritura directa de A-03 |
| `has_active_role(text)` | STABLE | sin llamador conocido | Candidata, verificar |
| `has_any_active_role(text[])` | STABLE | creación antigua y actual | Vigente mientras exista ese uso |
| `is_activity_participant(uuid)` | STABLE | política SELECT y tarjetas | Vigente |
| `open_activity_attendance_checkin(uuid)` | VOLATILE | acciones QR/código; helpers de ventana/generador | Vigente |
| `publish_activity(uuid)` | VOLATILE | publicación transaccional de borradores | Vigente; resuelve A-04 |
| `remove_activity_participant(uuid)` | VOLATILE | acción de participantes; `can_edit_activity` | Vigente |
| `search_profiles_for_participation(uuid,text)` | STABLE | búsqueda de participantes | Vigente |
| `set_updated_at()` | VOLATILE, INVOKER | cuatro triggers | Vigente |
| `update_activity_participant_attendance(uuid,text,text)` | VOLATILE | edición individual | Vigente; A-03 resuelto, revisar M-07 |
| `update_activity_participants_attendance_bulk(uuid,uuid[],text,text)` | VOLATILE | edición masiva | Vigente; A-03 resuelto |
| `validate_activity_scheduled_state()` | VOLATILE, trigger | trigger de `activities` y publicación | Vigente; resuelve A-04 |

No se detectó una función con `SECURITY DEFINER` sin `search_path` controlado. Los nombres de parámetros usan prefijos como `target_` y `new_`; no se confirmó una ambigüedad PL/pgSQL vigente entre parámetros y columnas de salida.

## Cobertura RLS por tabla

| Tabla o grupo | Políticas observadas | Evaluación |
| --- | --- | --- |
| `activities` | SELECT, INSERT, UPDATE, DELETE | Completa; borradores sólo por creador |
| `activity_participants` | SELECT, INSERT, UPDATE, DELETE | Completa; alumno sólo ve su fila |
| `activity_checkin_tokens` | Sin políticas directas | Intencional si grants y RPC quedan acotados |
| `profiles` | SELECT/UPDATE propios | Intencional; sin registro público |
| `role_assignments` | SELECT propio | Intencional; administración aún fuera del flujo |
| Catálogos y semestres | SELECT para `authenticated` | Intencionalmente de sólo lectura |
| `system_health` | SELECT para `anon` | Intencional y sin datos sensibles |

No hay dos políticas del mismo comando que se solapen sobre una tabla. La amplitud pendiente de A-02 se concentra en `can_manage_activity` para contenido publicado; no alcanza borradores ajenos.

## Privilegios efectivos y ACL

### Resolución de M-08

M-08 permanece **resuelto como incertidumbre**. El snapshot posterior a 0002/0003 confirma además que A-05 y A-06 fueron remediados:

- 99 grants de rutina: 33 firmas para `authenticated`, `postgres` y `service_role`.
- 262 grants de tabla: contrato mínimo cliente más administración de `postgres`/`service_role`.
- 6 grants de secuencia: `SELECT`, `UPDATE` y `USAGE` sólo para `postgres` y `service_role`.
- 401 entradas ACL expandidas, concordantes con las vistas especializadas.

No existe `EXECUTE` para `PUBLIC` o `anon`; tampoco acceso directo autenticado a `activity_checkin_tokens` o a `system_health_id_seq`. El snapshot no captura `pg_auth_members`, por lo que no se infiere acceso heredado de `authenticator`.

### Matriz resumida de rutinas

| Receptor | Objetos con `EXECUTE` | Evaluación |
| --- | ---: | --- |
| `PUBLIC` | 0/33 | Correcto |
| `anon` | 0/33 | Correcto |
| `authenticated` | 33/33 | Contrato vigente; RPC y helpers conservados deliberadamente |
| `service_role` | 33/33 | Administrativo esperado; la aplicación no usa su clave |
| `postgres` | 33/33 | Propietario esperado |
| `authenticator` | 0 grants directos | Correcto; membresía no capturada |
| Otros roles | Ninguno observado | Sin evidencia adicional |

Los RPC administrativos mantienen autorización interna aunque el grant de objeto ya sea mínimo. Esta defensa en profundidad sigue siendo necesaria para separar un usuario autenticado permitido de otro fuera de alcance.

### Matriz resumida de tablas

| Categoría | Grants observados | RLS/política | Evaluación |
| --- | --- | --- | --- |
| `profiles` y `role_assignments` | `authenticated`: SELECT/UPDATE de perfil y SELECT de asignaciones | RLS limita a identidad propia | Correcto |
| `activities` y `activity_participants` | CRUD autenticado | RLS y helpers limitan alcance | Correcto |
| `activity_checkin_tokens` | Sin grant cliente | Acceso mediante RPC | Correcto |
| 11 catálogos/semestres | SELECT autenticado | Políticas de lectura | Correcto |
| `system_health` | SELECT para `anon` y `authenticated` | SELECT anónimo deliberado | Correcto |
| Todas las tablas | Acceso completo para `postgres` y `service_role` | Roles administrativos | Confirmado como esperado para el prototipo |
| Todas las tablas | Sin ACL para `PUBLIC` | Sin acceso directo | Correcto |

No se confirmó un privilegio cliente excesivo ni faltante respecto del perfil materializado por 0002.

### Secuencia

El único objeto es `system_health_id_seq`. Sólo `service_role` y `postgres` tienen `SELECT`, `UPDATE` y `USAGE`; los roles cliente no tienen acceso. Como las demás claves primarias usan UUID, la secuencia no participa en actividades, perfiles, roles, participantes ni tokens.

### Grants confirmados como suficientes, excesivos o ausentes

- **Seguros/suficientes:** acceso de propietario `postgres`; administración `service_role`; contrato autenticado vigente; `anon` sólo para salud.
- **Excesivos:** ninguno confirmado contra el alcance intencional de 0002.
- **Ausentes:** ninguno requerido por la aplicación actual.

Cualquier nueva reducción debe basarse en consumidores verificados y publicarse en una migración posterior; no corresponde reescribir 0002.

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

## Trabajo posterior permitido

0002 y 0003 están cerradas, aplicadas y verificadas. El siguiente cambio de base de datos debe comenzar en `0004` y no reescribir la historia.

1. Mantener A-02 diferido hasta diseñar administración de usuarios, roles y permisos.
2. Validar datos antes de restricciones posteriores: duplicados de identidad, asignaciones solapadas y divergencia temporal.
3. Medir antes de añadir índices de autorización o joins.
4. Consolidar después contratos RPC, TypeScript y timestamps canónicos.
5. Conservar overloads, columnas de compatibilidad, alcance divisional y tokens de registro hasta contar con evidencia para retirarlos.
6. Diseñar el check-in abierto como operación transaccional separada: cuando una actividad lo permita, un usuario autenticado no preinscrito podrá ser agregado como participante y marcado `attended` en una sola operación.

Cada cambio debe ser pequeño, revisable, aplicado manualmente, verificado y reconciliado con un snapshot posterior.

## Conclusión

El snapshot regenerado coincide con `0001 + 0002 + 0003`. No hay deriva inexplicada en esquema, funciones, triggers, políticas, grants, ACL, catálogos o restricciones. Las únicas diferencias ambientales son el timestamp y el valor aleatorio `\restrict` de `pg_dump`.

## Estado de remediación verificado

| Hallazgo | Cobertura | Estado vivo |
| --- | --- | --- |
| A-01 | Helpers y RLS separan `draft` por creador; no amplían por responsable, participante, gestor ni `technical_admin` | Resuelto por 0002 |
| A-02 | Sin cambio para contenido publicado. **Deferred intentionally until user, role and permission administration is designed.** | Diferido intencionalmente |
| A-03 | Ambas RPC y un trigger rechazan `pending` cuando `activity_attendance_deadline <= now()`, incluso ante `UPDATE` directo | Resuelto por 0002 |
| A-04 | `publish_activity(uuid)` y el trigger validan el contrato programado, creador, permiso y transición | Resuelto por 0002 |
| A-05 | Sin `EXECUTE` de `PUBLIC` o `anon` sobre funciones SITAA | Resuelto por 0002 |
| A-06 | Contratos explícitos mínimos de tablas y secuencia para roles cliente | Resuelto por 0002 |
| Ciclo temporal de borradores | Borradores no terminan y su creador puede editarlos/eliminarlos con horario provisional | Resuelto por 0003 |

Conteo activo posterior a la reconciliación: crítica 0, alta 1, media 7, baja 4 e informativa 5. Los hallazgos medios y bajos no se consideran resueltos por 0002 o 0003.
