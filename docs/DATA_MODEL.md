# Modelo de datos preliminar

Este modelo es conceptual. Los nombres, tipos y restricciones definitivos se fijarán antes de crear migraciones.

## Identidad y autorización

| Entidad | Propósito | Campos clave sugeridos |
| --- | --- | --- |
| `profiles` | Complemento institucional del usuario de Auth | `id`, nombre, matrícula o número de empleado, correo institucional, estado |
| `roles` | Catálogo estable de capacidades | `id`, clave, nombre, estado |
| `role_assignments` | Roles múltiples, temporales y acotados | usuario, rol, alcance, programa/división, área de servicio, periodo, inicio, fin, estado, otorgado por |
| `divisions` | Divisiones académicas | clave, nombre, estado |
| `academic_programs` | Carreras o programas pertenecientes a una división | división, clave, nombre, estado |
| `academic_periods` | Semestres o periodos | clave, nombre, inicio, fin, estado |

`profiles` **no debe contener `role_code` ni otro rol fijo**. La autorización se deriva de `role_assignments`; una persona puede conservar asignaciones históricas y tener varias asignaciones activas.

### Valores controlados de asignación

- Alcance: `own`, `program`, `division`, `system`.
- Área de servicio: `tutoring`, `advising`, `both`, `logistics`, `technical`.
- Roles: `student`, `peer_tutor`, `professor`, `program_tutoring_lead`, `program_advising_lead`, `division_tutoring_liaison`, `program_head`, `division_head`, `technical_secretary`, `technical_admin`.

Para alcance `program` se exige programa y para `division` se exige división. `own` no admite referencias institucionales; `system` solo se utilizará para capacidades expresamente institucionales. La vigencia puede vincularse a un periodo y siempre debe poder evaluarse por fecha.

## Entidades operativas

| Entidad | Propósito | Campos clave sugeridos |
| --- | --- | --- |
| `groups` | Grupos dentro de un periodo y programa | periodo, programa, clave, estado |
| `group_memberships` | Estudiantes asociados a grupos | grupo, estudiante, inicio, fin |
| `service_assignments` | Responsabilidad operativa sobre grupos o actividades | usuario, grupo/programa, área de servicio, función, periodo |
| `session_types` | Tipos configurables de actividad | nombre, área de servicio, descripción, campos habilitados, estado |
| `semester_plans` | Plan de trabajo del responsable | periodo, responsable, grupo, área de servicio, objetivos, estado |
| `plan_items` | Actividades previstas | plan, tipo, tema, fecha estimada, objetivo, estado |
| `sessions` | Instancia programada o realizada | plan/actividad, tipo, responsable, grupo, inicio/fin, modalidad, ubicación, tema, objetivo, notas, estado |
| `attendance_windows` | Ventana y token del QR | sesión, huella del token, inicio, expiración, estado |
| `attendance_records` | Asistencia individual | sesión, estudiante, fecha, método, estado, validado por |
| `survey_templates` | Versión de encuesta aplicable | nombre, versión, programa, área de servicio, esquema, estado |
| `survey_responses` | Respuesta de un estudiante | plantilla, sesión, estudiante, fecha, respuestas |
| `audit_events` | Trazabilidad de acciones críticas | actor, acción, entidad, identificador, fecha, metadatos mínimos |

`role_assignments` autoriza capacidades por alcance; `service_assignments` identifica responsabilidades operativas concretas. Una asignación operativa nunca amplía por sí sola los permisos del rol.

## Relaciones esenciales

- Una división contiene programas; un programa contiene grupos por periodo.
- Un usuario tiene cero o más asignaciones de rol activas o históricas.
- Una asignación vincula un rol con alcance, área de servicio y vigencia.
- Un plan pertenece a un responsable, grupo, periodo y área de servicio; contiene actividades.
- Una sesión tiene muchas asistencias y, como máximo, una por estudiante.
- Una encuesta usa una versión inmutable de plantilla, acotada por programa y área de servicio cuando corresponda.

## Reglas de integridad

- Usar UUID y marcas de tiempo con zona horaria.
- Separar Supabase Auth del perfil institucional y de las asignaciones de rol.
- Validar que alcance y referencia institucional sean coherentes mediante restricciones.
- Evitar asignaciones duplicadas o vigencias superpuestas equivalentes.
- Finalizar o revocar asignaciones; no borrarlas si produjeron acciones auditables.
- Impedir por restricción única la asistencia duplicada por `sesión + estudiante`.
- No borrar registros operativos cerrados; usar estados, cancelación o archivado.
- Mantener versiones de formularios para no reinterpretar respuestas históricas.
- Mantener normalizados los campos usados en permisos, filtros e indicadores.
- Exponer al secretario técnico únicamente una proyección logística explícita, no filas académicas completas.

## Estados sugeridos

- Asignación de rol: `programada`, `activa`, `revocada`, `vencida`.
- Periodo: `borrador`, `activo`, `cerrado`.
- Plan: `borrador`, `enviado`, `aprobado`, `cerrado`.
- Sesión: `programada`, `en_curso`, `realizada`, `cancelada`.
- Asistencia: `presente`, `justificada`, `invalidada`.

## Pendientes de definición

- Reglas exactas para solapamiento y delegación de asignaciones.
- Matriz de otorgamiento y revocación por rol.
- Nivel de detalle académico permitido a cada jefatura.
- Campos obligatorios por tipo y área de servicio.
- Conservación y anonimización de encuestas.