# Modelo de datos

## Tablas implementadas

La integración actual utiliza tablas institucionales y catálogos operativos públicos. Supabase Auth conserva la identidad de acceso; `profiles` y `role_assignments` contienen el contexto institucional.

| Tabla | Propósito | Contrato utilizado por la aplicación |
| --- | --- | --- |
| `divisions` | Divisiones académicas | `id`, `code`, `name`, `is_active` |
| `academic_programs` | Carreras o programas | `id`, `division_id`, `code`, `name`, `is_active` |
| `roles` | Catálogo estable de roles | `id`, `code`, `label`, `description`, `is_active` |
| `profiles` | Identidad institucional estable vinculada a Auth | `id`, `first_names`, `paternal_surname`, `maternal_surname`, `full_name`, `email`, `person_type`, `institutional_id_type`, `institutional_id_value`, `primary_program_id` |
| `role_assignments` | Asignaciones múltiples, vigentes o históricas | `id`, `user_id`, `role_code`, `scope_type`, `service_area`, `division_id`, `program_id`, `starts_at`, `ends_at`, `status`, `is_active` |
| `academic_periods` | Periodos académicos operativos | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `activity_types` | Tipos de actividad | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `service_types` | Tipos de servicio | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `attention_categories` | Categorías de atención | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `activity_modalities` | Modalidades de actividad | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `activity_statuses` | Estados del ciclo de actividad | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `location_types` | Tipos de ubicación | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `participant_roles` | Roles dentro de una actividad | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `activities` | Núcleo operativo de tutorías, asesorías y acompañamiento | `id`, `title`, `description`, `academic_period_id`, `program_id`, códigos de catálogos, ubicación, `start_date`, `start_time`, `end_date`, `end_time`, `duration_mode`, `starts_at`, `ends_at`, `responsible_profile_id`, `created_by`, `status_code` |

`profiles` contiene identidad estable y no almacena rol ni semestre actual. Una cuenta sin perfil existe en Auth, pero todavía no está activada en SITAA.

### Reglas del perfil

- `person_type`: `student` o `worker`.
- `institutional_id_type`: `student_account` o `worker_number`.
- Una persona `student` usa `student_account`; una persona `worker`, incluidos profesores, usa `worker_number`.
- `institutional_id_value` almacena el número correspondiente y debe ser único dentro de su tipo.
- `primary_program_id` es obligatorio para un perfil registrado completo. Los perfiles bootstrap pueden conservarlo temporalmente en `null` hasta completar su configuración.
- `full_name` es la representación normalizada de nombres y apellidos; no sustituye sus campos separados.
- Los roles y responsabilidades se obtienen exclusivamente de `role_assignments`.
- El semestre, cuando un comité lo requiera, se captura en el contexto de participación, la actividad o una respuesta de formulario versionada; nunca como atributo actual de `profiles`.
- La edición propia se limita a nombres, apellidos, tipo de persona, identificador institucional y programa principal; no incluye roles ni estado de activación.
- Guardar o completar un perfil requiere seleccionar un programa académico disponible.

Los catálogos operativos se consultan por `code` y muestran `label` o `name`. Solo los valores con `is_active = true` se presentan en la operación normal. Son datos controlados previos a la implementación de actividades; el visor actual es de solo lectura.

### Reglas temporales de actividades

- `academic_period_id` se asigna automáticamente desde el único periodo activo; no es editable en el alta.
- `start_date` y `start_time` son obligatorios y usan hora de 24 horas.
- `duration_mode` admite `one_hour`, `two_hours` y `custom`.
- Las duraciones de una y dos horas calculan automáticamente `end_date` y `end_time`; la personalizada exige ambos campos.
- `starts_at` y `ends_at` se mantienen como campos de compatibilidad derivados de fecha y hora separadas.


### Reglas del flujo base implementado

- Todos los campos operativos de la actividad son obligatorios salvo description.
- Las fechas se presentan como DD/MM/YYYY y las horas en formato de 24 horas.
- Alta y actualización usan el único periodo académico activo; no se puede seleccionar manualmente.
- La edición conserva responsible_profile_id y created_by; lectura, actualización y eliminación dependen de RLS.
- TODO: modelar el alcance para que el enlace divisional pueda elegir Diseño Gráfico, Arquitectura o ambos, sin crear «Ambos programas» como programa ficticio.

## Entidades previstas

### Participación y asistencia previstas

| Entidad | Propósito | Relaciones mínimas |
| --- | --- | --- |
| `activity_participants` | Personas convocadas o registradas | actividad y `profile_id` obligatorios; contexto académico opcional, incluido semestre si se acuerda |
| `attendance_records` | Registro de asistencia o check-in | actividad, `profile_id`, fecha, método y estado |

Todos los participantes deben referenciar `profiles`. No se modela un participante externo de texto libre como flujo normal. Si una persona no está registrada, no puede formar parte correctamente de la lista de asistencia producida por SITAA.

### Formularios dinámicos

| Entidad | Propósito | Relaciones mínimas |
| --- | --- | --- |
| `forms` | Identidad y alcance del formulario | programa/división, área de servicio, creador y estado |
| `form_versions` | Versión publicable e inmutable | formulario, número de versión, `created_by`, fecha y estado |
| `form_fields` | Definición ordenada de campos | versión, clave, etiqueta, tipo, orden, requerido y configuración |
| `form_responses` | Envío de un formulario | `activity_id`, `form_version_id`, perfil, `created_by` y fecha |
| `form_response_values` | Valor de cada campo respondido | respuesta, campo y valor tipado o serializado |

Los tipos de campo podrán incluir, de manera controlada, texto corto/largo, número, fecha, opción única, opciones múltiples, escala y otros tipos aprobados. Los editores eligen campos, orden y obligatoriedad.

SITAA no codifica campos académicos universalmente obligatorios. Solo se exigen campos técnicos indispensables para integridad, como IDs, marcas de tiempo, `created_by`, `activity_id` y `form_version_id`.

Una versión publicada no se modifica. Las nuevas decisiones académicas generan otra versión y las respuestas anteriores conservan su referencia original.

## Reportes

Tablas, resúmenes, gráficas, CSV y PDF se derivan de actividades, perfiles, asistencia y respuestas. Deben admitir filtros por actividad, fecha, responsable, programa, servicio, categoría y campos configurados cuando su tipo permita consulta consistente.

## Evidencia fuera del modelo

No se proponen tablas ni campos para administrar archivos o referencias documentales externas. Quedan excluidos explícitamente:

- `activity_evidence`;
- `evidence_type`;
- `external_url`;
- `used_for_indicator`;
- `evidence_indicator_links`.

Tampoco se modelan carteles, fotografías, oficios, materiales, carpetas de Drive o enlaces de indicadores. La evidencia interna de SITAA son sus propios registros estructurados, respuestas, resúmenes y exportaciones.

## Reglas de integridad

- Usar UUID y marcas de tiempo con zona horaria.
- Separar Auth, identidad estable del perfil y asignaciones de rol.
- Validar la correspondencia entre `person_type` e `institutional_id_type`.
- No almacenar el semestre actual ni campos equivalentes en `profiles`.
- Validar alcance, área de servicio y vigencia mediante RLS y restricciones.
- Vincular participantes y asistencias a perfiles SITAA.
- Evitar participación o asistencia duplicada por actividad y perfil.
- Conservar versiones publicadas y sus respuestas.
- Normalizar los campos usados en permisos e indicadores; documentar límites de filtrado para campos dinámicos.

## Estado de implementación

La tabla `activities` y su alta, listado, edición y eliminación básicos están implementados. Participantes, asistencia, formularios y reportes permanecen en diseño. Este documento no crea ni autoriza migraciones SQL.