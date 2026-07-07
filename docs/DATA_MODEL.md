# Modelo de datos

## Tablas implementadas

La integración actual utiliza cinco tablas públicas. Supabase Auth conserva la identidad de acceso; `profiles` y `role_assignments` contienen el contexto institucional.

| Tabla | Propósito | Contrato utilizado por la aplicación |
| --- | --- | --- |
| `divisions` | Divisiones académicas | `id`, `code`, `name`, `is_active` |
| `academic_programs` | Carreras o programas | `id`, `division_id`, `code`, `name`, `is_active` |
| `roles` | Catálogo estable de roles | `id`, `code`, `label`, `description`, `is_active` |
| `profiles` | Perfil institucional vinculado a Auth | `id`, `full_name`, `student_number`, `employee_number`, `institutional_email`, `primary_program_id`, `status` |
| `role_assignments` | Asignaciones múltiples, vigentes o históricas | `id`, `user_id`, `role_code`, `scope_type`, `service_area`, `division_id`, `program_id`, `starts_at`, `ends_at`, `status`, `is_active` |

`profiles` no contiene un rol fijo. Debe soportar número de cuenta de alumno, número de trabajador, programa y semestre cuando sean aplicables. Una cuenta sin perfil existe en Auth, pero todavía no está activada en SITAA.

## Entidades previstas

### Actividades y participación

| Entidad | Propósito | Relaciones mínimas |
| --- | --- | --- |
| `activities` | Actividad o evento de tutoría/asesoría | periodo, programa, servicio, categoría, responsable y datos operativos |
| `activity_participants` | Personas convocadas o registradas | actividad y `profile_id` obligatorios |
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
- Separar Auth, perfil y asignaciones de rol.
- Validar alcance, área de servicio y vigencia mediante RLS y restricciones.
- Vincular participantes y asistencias a perfiles SITAA.
- Evitar participación o asistencia duplicada por actividad y perfil.
- Conservar versiones publicadas y sus respuestas.
- Normalizar los campos usados en permisos e indicadores; documentar límites de filtrado para campos dinámicos.

## Estado de implementación

Las entidades de actividades, participantes, asistencia, formularios y reportes permanecen en diseño. Este documento no crea ni autoriza migraciones SQL.