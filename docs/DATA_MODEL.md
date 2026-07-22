# Modelo de datos

> **Vigencia:** este documento describe el esquema vivo reconciliado después de 0008. El modelo funcional de identidad y cuentas técnicas está en `IDENTITY_AND_REGISTRATION.md`; el modelo futuro de roles permanece en `ROLES_AND_PERMISSIONS_V2.md`.

## Tablas implementadas

La integración actual utiliza tablas institucionales y catálogos operativos públicos. Supabase Auth conserva la identidad de acceso; `profiles` y `role_assignments` contienen el contexto institucional.

| Tabla | Propósito | Contrato utilizado por la aplicación |
| --- | --- | --- |
| `divisions` | Divisiones académicas | `id`, `code`, `name`, `is_active` |
| `academic_programs` | Carreras o programas | `id`, `division_id`, `code`, `name`, `is_active` |
| `roles` | Catálogo estable de roles, con `code` como llave primaria | `code`, `label`, `description`, `sort_order` |
| `profiles` | Identidad de cuenta estable vinculada a Auth | `id`, `email`, `first_names`, `paternal_surname`, `maternal_surname`, `full_name`, `account_kind`, `account_status`, `person_type`, `institutional_id_type`, `institutional_id_value`, `primary_program_id`, `activated_at`, `deactivated_at` |
| `role_assignments` | Asignaciones múltiples, vigentes o históricas V1 | `id`, `user_id`, `role_code`, `scope_type`, `service_area`, `division_id`, `program_id`, `starts_at`, `ends_at`, `is_active`, `assigned_by`, timestamps |
| `academic_periods` | Semestres académicos operativos y rangos oficiales | `id`, `code`, `label` o `name`, `description`, rangos oficiales de fecha, `is_active` |
| `activity_types` | Tipos de actividad | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `service_types` | Tipos de servicio | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `attention_categories` | Categorías de atención | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `activity_modalities` | Modalidades de actividad | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `activity_statuses` | Estados del ciclo de actividad | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `location_types` | Tipos de ubicación | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `participant_roles` | Roles dentro de una actividad | `id`, `code`, `label` o `name`, `description`, `is_active` |
| `activities` | Núcleo operativo de tutorías, asesorías y acompañamiento | `id`, `title`, `description`, `academic_period_id`, `scope_type`, `division_id`, `program_id`, códigos de catálogos, ubicación, `start_date`, `start_time`, `end_date`, `end_time`, `duration_mode`, `starts_at`, `ends_at`, `responsible_profile_id`, `created_by`, `status_code` |
| `admin_audit_events` | Bitácora administrativa append-only de Fase B | `id`, actor, objetivo, acción, resultado, motivo, asignación opcional, metadata segura y `occurred_at` |

`profiles` contiene identidad estable y no almacena rol ni semestre actual. Todo Auth user admitido por SITAA tiene exactamente un perfil; un perfil `pending_registration` existe pero todavía no está activado para la operación normal.

### Auditoría administrativa implementada en 0007

`admin_audit_events` está implementada como bitácora administrativa append-only: UUID, actor y objetivo en `profiles`, acción, resultado, motivo opcional, asignación V1 opcional, metadata de objeto JSON limitada a 16 384 bytes y fecha. Sus referencias usan borrado restrictivo, RLS no concede acceso directo a clientes y dos triggers bloquean actualización, eliminación y truncado. `service_role` conserva únicamente `SELECT` e `INSERT`; B.1 sólo consulta una proyección sanitizada mediante RPC, no escribe eventos ni devuelve metadata sin procesar.

El snapshot `2026-07-22T01:46:13Z` confirma sus nueve columnas, ocho restricciones, tres índices propios —incluida la PK—, dos triggers, RLS sin políticas y ACL mínimo. La tabla forma parte del inventario vivo reconciliado posterior a 0008.

### Reglas del perfil

- En 0004, `account_kind` admite `institutional|technical`; `person_type` admite `student|professor` sólo para cuentas institucionales.
- `institutional_id_type`: `student_account` o `worker_number`.
- El modelo aprobado exige `student_account` para alumnos y `worker_number` para profesores; ambos valores son texto de dígitos y conservan ceros iniciales.
- La unicidad se aplica al par (`institutional_id_type`, `institutional_id_value`) mediante índice parcial para cuentas institucionales. El mismo valor puede existir una vez por cada tipo.
- `primary_program_id` es obligatorio para una cuenta institucional completa y no concede permisos. Una cuenta `technical` queda exenta de persona, programa e identificador.
- 0006 formaliza `first_names`, `paternal_surname` y `maternal_surname` como fuente autoritativa. Nombre(s) y apellido paterno son obligatorios para cuentas institucionales activas; el apellido materno es opcional. Las cuentas técnicas requieren nombre(s) y permiten apellidos opcionales.
- `full_name` se conserva como representación derivada de compatibilidad. Un trigger normaliza espacios y lo reconstruye sin eliminar acentos ni forzar mayúsculas.
- Los roles y responsabilidades se obtienen exclusivamente de `role_assignments`.
- El semestre, cuando un comité lo requiera, se captura en el contexto de participación, la actividad o una respuesta de formulario versionada; nunca como atributo actual de `profiles`.
- Con 0006, el autoservicio directo de `profiles` se limita a los tres componentes del nombre; `full_name` deja de escribirse directamente. Clasificación, identificador, programa, correo, estado y timestamps permanecen protegidos por privilegios de columna y trigger.
- `account_status` distingue `pending_registration|active|inactive`; `is_active` se conserva como compatibilidad y refleja únicamente `active`.
- `pending_registration` admite temporalmente identidad institucional incompleta para el Auth user Google; no concede acceso operativo.

### Registro institucional autenticado

- 0004 no agrega una tabla de registro temporal: nombre, identificador y programa se reciben sólo después de Google OAuth.
- 0006 añade el overload `complete_own_google_registration(person_type, first_names, paternal_surname, maternal_surname, institutional_id_value, primary_program_id)`. El overload post-0005 permanece para rollback, pero pierde `EXECUTE` de `authenticated` mientras 0006 esté activo.
- La disponibilidad del identificador no se expone a `anon`; unicidad y carreras se resuelven al completar el perfil mediante el índice parcial.
- No se divide `full_name` de perfiles históricos. El preflight sólo reporta conteos y bloquea cuentas activas sin correspondencia estructurada revisada.
- El orden canónico futuro es `paternal_surname`, `maternal_surname`, `first_names`. Aplicaciones que ordenen en memoria usarán comparación local en español. CSV y PDF futuros expondrán columnas separadas; no se implementan en 0006.

### Evolución prevista de asignaciones

`role_assignments` ya conserva cuenta, rol, alcance, servicio, programa/división, vigencia, activo, `assigned_by` y timestamps. Para cumplir el modelo V2 debe añadir o formalizar fecha de asignación, `revoked_by`, `revoked_at` y nota administrativa. Las asignaciones se revocan o desactivan, no se borran. La tabla `roles` requerirá códigos separados para profesor tutor, profesor asesor, coordinación, secretaría técnica de programa y secretaría auxiliar divisional.

En el directorio B.1, `starts_at` y `ends_at` se evalúan como fechas calendario inclusivas de `America/Mexico_City`. La aplicación y las RPC 0007 comparten la misma regla y no dependen de la zona horaria de la sesión PostgreSQL.

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

## Participación y asistencia implementadas

| Entidad | Propósito | Relaciones mínimas |
| --- | --- | --- |
| `activity_participants` | Perfiles registrados vinculados a una actividad por registro o invitación | `id`, `activity_id`, `profile_id`, `participant_role_code`, campos de asistencia, `created_by`, `created_at`; combinación actividad/perfil única |
| `activity_checkin_tokens` | Accesos temporales de asistencia para participantes registrados | `activity_id`, `code_words`, `secret_token`, apertura, expiración y estado activo |

Registro y asistencia son flujos distintos: registrar o invitar agrega participantes; el check-in confirma que asistieron. La asistencia debe poder marcarse y corregirse manualmente por la persona responsable o editor autorizado.

Estados de asistencia previstos: `pending`, `attended`, `absent`, `justified`. Fuentes previstas: `manual`, `qr`, `code`, `system`.

La asistencia implementada usa QR, enlace directo o código corto de tres palabras. El QR no es el único método. Los códigos son breves, en minúsculas, sin acentos, ñ ni caracteres especiales, fáciles de dictar y únicos entre códigos activos.

La asistencia está limitada a participantes registrados. El registro abierto y el check-in abierto permanecen como capacidades futuras.

## Entidades previstas

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

La Fase A de identidad Google y los nombres estructurados de 0006 están aplicados, verificados y reconciliados. Participantes, asistencia y check-in son módulos implementados. La Fase B.1 está implementada, verificada, probada y reconciliada mediante 0007. B.2a está cerrada mediante 0008; B.2b, B.3 y Fase C permanecen pendientes.
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

## Delta implementado y reconciliado por 0008

0008 está aplicada, verificada, probada, reconciliada e inmutable. No crea tablas, columnas, índices, restricciones ni semillas. Añade una frontera de autorización, dos RPC administrativas y un trigger de integridad para las escrituras directas soportadas de `activities`; además retira el DML directo de `authenticated` sobre `activity_participants` para obligar a usar sus RPC validadas. El snapshot `2026-07-22T01:46:13Z` confirma 18 tablas, 165 columnas, 80 restricciones, 43 índices, 11 triggers, 51 firmas de función, 25 políticas, 51 semillas controladas y RLS habilitado en las 18 tablas.

Una corrección exitosa conserva UUID de perfil, email, vínculo Auth, clase/estado de cuenta, ciclo de vida, asignaciones y toda la historia operativa. Inserta exactamente un evento append-only en `admin_audit_events` con `action_code = account_identity_corrected`, `outcome = success`, razón normalizada y metadata que contiene sólo el arreglo ordenado `changed_fields`.

La normalización administrativa colapsa whitespace antes de recortar; el nombre derivado mide 2–200 caracteres en ambos tipos de cuenta y `person_type` institucional nunca puede ser nulo. Las decisiones sobre cambios de tipo/programa se serializan contra asignaciones, actividades y participantes mediante locks de tabla en orden documentado.

Para estas dependencias, “abierta” significa `status_code = draft` o no terminada mediante el cálculo post-0007 de fecha/hora en `America/Mexico_City`; “histórica” significa no borrador y terminada por ese mismo cálculo. La historia puede quedar incompatible después de una corrección válida sin ser reescrita. El trigger de `activities` impide que DML autenticado convierta esa historia en actividad abierta; una ruta confiable que lo hiciera tendría que revalidar participantes y responsabilidad primaria antes del commit.
