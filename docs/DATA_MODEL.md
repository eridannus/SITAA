# Modelo de datos preliminar

Este modelo es conceptual. Los nombres, tipos y restricciones definitivos se fijarán antes de crear migraciones.

## Entidades principales

| Entidad | Propósito | Campos clave sugeridos |
| --- | --- | --- |
| `profiles` | Complemento del usuario de Auth | `id`, nombre, matrícula o número de empleado, correo institucional, estado |
| `roles` | Catálogo de roles | `id`, clave, nombre |
| `user_roles` | Roles asignados y su vigencia | usuario, rol, alcance, fecha inicial/final |
| `academic_periods` | Semestres o periodos | clave, nombre, inicio, fin, estado |
| `academic_programs` | Programas o carreras | clave, nombre, estado |
| `groups` | Grupos dentro de un periodo y programa | periodo, programa, clave, estado |
| `group_memberships` | Estudiantes asociados a grupos | grupo, estudiante, vigencia |
| `staff_assignments` | Tutores, asesores o coordinadores por alcance | usuario, grupo/programa, función, periodo |
| `session_types` | Tipos configurables de actividad | nombre, descripción, campos habilitados, estado |
| `semester_plans` | Plan de trabajo del responsable | periodo, responsable, grupo, objetivos, estado |
| `plan_items` | Actividades previstas | plan, tipo, tema, fecha estimada, objetivo, estado |
| `sessions` | Instancia realizada o programada | plan/actividad, tipo, responsable, grupo, inicio/fin, modalidad, ubicación, tema, objetivo, notas, estado |
| `attendance_windows` | Ventana y token del QR | sesión, huella del token, inicio, expiración, estado |
| `attendance_records` | Asistencia individual | sesión, estudiante, fecha, método, estado, validado por |
| `survey_templates` | Versión de encuesta aplicable | nombre, versión, esquema, estado |
| `survey_responses` | Respuesta de un estudiante | plantilla, sesión, estudiante, fecha, respuestas |
| `audit_events` | Trazabilidad de acciones críticas | actor, acción, entidad, identificador, fecha, metadatos mínimos |

## Relaciones esenciales

- Un periodo contiene grupos, planes y sesiones.
- Un grupo pertenece a un programa y a un periodo.
- Un plan pertenece a un responsable, un grupo y un periodo; contiene actividades.
- Una sesión pertenece a un tipo, tiene un responsable y puede vincularse a una actividad del plan.
- Una sesión tiene muchas asistencias y, como máximo, una asistencia por estudiante.
- Una encuesta usa una versión inmutable de plantilla; una respuesta pertenece a una sesión y un estudiante.
- Roles y asignaciones determinan el alcance efectivo de las políticas RLS.

## Reglas de integridad

- Usar identificadores UUID y marcas de tiempo con zona horaria.
- Separar el usuario de Supabase Auth de su perfil institucional.
- Impedir por restricción única la asistencia duplicada por `sesión + estudiante`.
- No borrar registros operativos cerrados; usar estados, cancelación o archivado.
- Mantener versiones de plantillas para no reinterpretar respuestas históricas.
- Evitar información personal en campos libres y metadatos de auditoría.
- Los campos configurables pueden usar `jsonb`, pero los datos necesarios para permisos, filtros e indicadores deben permanecer normalizados.

## Estados sugeridos

- Periodo: `borrador`, `activo`, `cerrado`.
- Plan: `borrador`, `enviado`, `aprobado`, `cerrado`.
- Sesión: `programada`, `en_curso`, `realizada`, `cancelada`.
- Asistencia: `presente`, `justificada`, `invalidada`.

## Pendientes de definición

- Si una sesión puede reunir más de un grupo o responsable.
- Alcance institucional de coordinadores y administradores.
- Conservación y anonimización de encuestas.
- Campos obligatorios por tipo de sesión.
- Método de carga inicial de usuarios y asignaciones.
