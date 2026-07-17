# Modelo de datos

> **Vigencia:** este documento describe el esquema implementado después de 0003. El modelo funcional aprobado para identidad, cuentas técnicas y roles futuros está en `IDENTITY_AND_REGISTRATION.md` y `ROLES_AND_PERMISSIONS_V2.md`; las diferencias que requieren 0004 o fases posteriores están en `IMPLEMENTATION_GAPS_0004.md`.

## Tablas implementadas

La integración actual utiliza tablas institucionales y catálogos operativos públicos. Supabase Auth conserva la identidad de acceso; `profiles` y `role_assignments` contienen el contexto institucional.

| Tabla | Propósito | Contrato utilizado por la aplicación |
| --- | --- | --- |
| `divisions` | Divisiones académicas | `id`, `code`, `name`, `is_active` |
| `academic_programs` | Carreras o programas | `id`, `division_id`, `code`, `name`, `is_active` |
| `roles` | Catálogo estable de roles | `id`, `code`, `label`, `description`, `is_active` |
| `profiles` | Identidad institucional estable vinculada a Auth | `id`, `first_names`, `paternal_surname`, `maternal_surname`, `full_name`, `email`, `person_type`, `institutional_id_type`, `institutional_id_value`, `primary_program_id` |
| `role_assignments` | Asignaciones múltiples, vigentes o históricas | `id`, `user_id`, `role_code`, `scope_type`, `service_area`, `division_id`, `program_id`, `starts_at`, `ends_at`, `status`, `is_active` |
| `academic_periods` | Semestres académicos operativos y rangos oficiales | `id`, `code`, `label` o `name`, `description`, rangos oficiales de fecha, `is_active` |
| `activity_types` | Tipos de actividad | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `service_types` | Tipos de servicio | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `attention_categories` | Categorías de atención | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `activity_modalities` | Modalidades de actividad | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `activity_statuses` | Estados del ciclo de actividad | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `location_types` | Tipos de ubicación | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `participant_roles` | Roles dentro de una actividad | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `activities` | Núcleo operativo de tutorías, asesorías y acompañamiento | `id`, `title`, `description`, `academic_period_id`, `scope_type`, `division_id`, `program_id`, códigos de catálogos, ubicación, `start_date`, `start_time`, `end_date`, `end_time`, `duration_mode`, `starts_at`, `ends_at`, `responsible_profile_id`, `created_by`, `status_code` |

`profiles` contiene identidad estable y no almacena rol ni semestre actual. Una cuenta sin perfil existe en Auth, pero todavía no está activada en SITAA.

### Reglas del perfil

- Estado actual: `person_type` admite `student` o `worker`. Modelo aprobado: las cuentas institucionales usarán `student` o `professor`, de forma exclusiva; las técnicas internas usarán un `account_kind` explícito y no fingirán un tipo institucional.
- `institutional_id_type`: `student_account` o `worker_number`.
- El modelo aprobado exige `student_account` para alumnos y `worker_number` para profesores; ambos valores son texto de dígitos y conservan ceros iniciales.
- La unicidad futura aprobada para `institutional_id_value` es global entre cuentas institucionales, no sólo dentro del tipo. El esquema actual todavía no la impone.
- `primary_program_id` es obligatorio para una cuenta institucional completa y no concede permisos. Una cuenta `internal_technical` futura queda exenta de programa e identificador.
- `full_name` es la representación normalizada de nombres y apellidos; no sustituye sus campos separados.
- Los roles y responsabilidades se obtienen exclusivamente de `role_assignments`.
- El semestre, cuando un comité lo requiera, se captura en el contexto de participación, la actividad o una respuesta de formulario versionada; nunca como atributo actual de `profiles`.
- La edición propia actual permite más campos de los previstos. En el modelo aprobado, clasificación, identificador, programa, correo y estado principal se corrigen mediante flujos controlados; el autoservicio se limita a datos no críticos que se definan en implementación.
- El estado de cuenta debe distinguir verificación pendiente, activa e inactiva y formar parte de la autorización efectiva.

### Evolución prevista de asignaciones

`role_assignments` ya conserva cuenta, rol, alcance, servicio, programa/división, vigencia, activo, `assigned_by` y timestamps. Para cumplir el modelo V2 debe añadir o formalizar fecha de asignación, `revoked_by`, `revoked_at` y nota administrativa. Las asignaciones se revocan o desactivan, no se borran. La tabla `roles` requerirá códigos separados para profesor tutor, profesor asesor, coordinación, secretaría técnica de programa y secretaría auxiliar divisional.

Los catálogos operativos se consultan por `code` y muestran `label` o `name`. Sólo los valores con `is_active = true` se presentan en la operación normal. Son datos controlados previos a la implementación de actividades; el visor actual es de solo lectura.

### Alcance de actividades

- scope_type admite program o division.
- division_id es obligatorio en ambos alcances.
- En alcance program, program_id es obligatorio y su división debe coincidir con division_id.
- En alcance division, program_id es nulo; para la División de Diseño y Edificación representa «Ambos programas».
- En el MVP, altas y ediciones operativas usan exclusivamente scope_type = program; program_id es obligatorio y division_id se deriva del programa. El alcance divisional queda reservado y no se expone en la interfaz.

### Reglas temporales de actividades

- El semestre de la actividad se asigna automáticamente desde `start_date`, usando rangos oficiales mantenidos por usuarios técnicos o administrativos; no es editable por usuarios operativos.
- `start_date` y `start_time` son obligatorios y usan hora de 24 horas.
- `duration_mode` admite `one_hour`, `two_hours` y `custom`.
- Las duraciones de una y dos horas calculan automáticamente `end_date` y `end_time`; la personalizada exige ambos campos.
- `starts_at` y `ends_at` se mantienen como campos de compatibilidad derivados de fecha y hora separadas.
- `status_code` usa `draft` para actividades en borrador y `scheduled` para actividades publicadas/programadas.
- En borradores (`draft`), fechas, horas y campos operativos son provisionales: pueden faltar o contener valores pasados sin activar expiración ni bloqueo. Publicar exige completar y validar todo el contrato operativo.


### Reglas de semestre académico

- La interfaz debe mostrar la etiqueta **Semestre**; no debe mostrar “periodo calculado”.
- SITAA asigna el semestre automáticamente a partir de la fecha de inicio de la actividad.
- Los usuarios operativos no seleccionan ni editan el semestre manualmente.
- Usuarios técnicos o administrativos mantienen los rangos oficiales de semestre con base en calendarios UNAM.
- Convención institucional:
  - el primer semestre calendario del año corresponde al semestre 2 de ese mismo año académico;
  - el segundo semestre calendario del año corresponde al semestre 1 del año académico siguiente.
- Ejemplos: febrero–mayo 2026 = 2026-2; agosto–noviembre 2026 = 2027-1; febrero–mayo 2027 = 2027-2; agosto–noviembre 2027 = 2028-1.
- Reportes, estadísticas y exportaciones deberán poder filtrarse por semestre.

### Reglas del flujo base implementado

- Todos los campos operativos de la actividad son obligatorios salvo description.
- Las fechas se presentan como DD/MM/YYYY y las horas en formato de 24 horas.
- `draft` identifica una actividad en borrador; `scheduled` identifica una actividad publicada/programada.
- Alta y actualización asignan el semestre desde la fecha de inicio; no se puede seleccionar manualmente.
- La edición conserva responsible_profile_id y created_by; lectura, actualización y eliminación dependen de RLS.

## Entidades previstas

### Participación, registro y asistencia previstas

| Entidad | Propósito | Relaciones mínimas |
| --- | --- | --- |
| `activity_participants` | Perfiles registrados vinculados a una actividad por registro o invitación | `id`, `activity_id`, `profile_id`, `participant_role_code`, campos de asistencia, `created_by`, `created_at`; combinación actividad/perfil única |
| `attendance_records` | Confirmación de asistencia/check-in de participantes registrados | actividad, `profile_id`, fecha, fuente, estado, usuario o proceso que registró/corrigió |
| `activity_access_codes` | Códigos o enlaces temporales para registro o asistencia | actividad, flujo, código corto, estado, vigencia, regeneración y responsable |

Registro y asistencia son flujos distintos: registrar o invitar agrega participantes; el check-in confirma que asistieron. La asistencia debe poder marcarse y corregirse manualmente por la persona responsable o editor autorizado.

Estados de asistencia previstos: `pending`, `attended`, `absent`, `justified`. Fuentes previstas: `manual`, `qr`, `code`, `system`.

Los flujos futuros de registro y asistencia podrán usar QR, enlace directo o código corto de tres palabras. El QR no será el único método. Los códigos de tres palabras serán breves, en minúsculas, con palabras en español, sin acentos, ñ ni caracteres especiales, fáciles de dictar y únicos entre códigos activos.

Por defecto, el registro estará cerrado y la asistencia estará limitada a participantes registrados. Más adelante podrán habilitarse registro abierto o check-in abierto para tipos de actividad seleccionados.

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

SITAA no codifica campos académicos universalmente obligatorios. Sólo se exigen campos técnicos indispensables para integridad, como IDs, marcas de tiempo, `created_by`, `activity_id` y `form_version_id`.

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

Las tablas `activities` y `activity_participants` están implementadas con alta, consulta y retiro sujeto a RLS. Asistencia, formularios y reportes permanecen en diseño. Este documento no crea ni autoriza migraciones SQL.
### Accesos de asistencia por QR, enlace y código

`activity_checkin_tokens` representa el acceso temporal para confirmar asistencia de participantes ya registrados. El enlace directo usa `secret_token`; el código manual usa `three_word_code`. Ambos actualizan los mismos campos de asistencia de `activity_participants` mediante `check_in_activity`.

- El QR codifica el enlace directo con `secret_token`.
- El código de tres palabras es corto, en minúsculas, sin acentos, ñ ni caracteres especiales, y único entre códigos activos.
- Abrir, cerrar o regenerar asistencia no registra participantes nuevos; sólo permite confirmar asistencia de participantes existentes.
- Cerrar o regenerar invalida accesos anteriores conforme a las funciones autorizadas de Supabase.

### Campos de asistencia implementados en participantes

`activity_participants` conserva la asistencia manual y futura del participante mediante: `attendance_status`, `attendance_source`, `checked_in_at`, `attendance_updated_by`, `attendance_updated_at` y `attendance_notes`.

- `attendance_status`: `pending`, `attended`, `absent`, `justified`.
- `attendance_source`: `system`, `manual`, `qr`, `code`.
- La actualización manual usa la misma estructura que después podrán actualizar QR, enlaces o códigos.
- Las correcciones manuales deben conservar quién actualizó, cuándo y las notas disponibles.
