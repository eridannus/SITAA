# Roles y permisos

Los permisos se aplicarán con RLS en Supabase. No existe un rol fijo en `profiles`: el acceso efectivo se calcula a partir de asignaciones activas, vigencia, alcance y área de servicio.

## Catálogo de roles

| Clave | Nombre | Responsabilidad principal |
| --- | --- | --- |
| `student` | Alumno | Consulta su información, registra asistencia y responde formularios. |
| `peer_tutor` | Alumno tutor par | Atiende actividades asignadas durante una vigencia determinada. |
| `professor` | Profesor tutor / asesor | Planea y documenta actividades bajo sus asignaciones. |
| `program_tutoring_lead` | Encargado de tutorías de carrera | Coordina tutorías y formularios dentro de su programa. |
| `program_advising_lead` | Encargado de asesorías de carrera | Coordina asesorías y formularios dentro de su programa. |
| `division_tutoring_liaison` | Enlace divisional de tutorías y asesorías | Consulta y coordina ambos servicios en su división. |
| `program_head` | Jefatura de carrera / programa | Supervisa la operación del programa asignado. |
| `division_head` | Jefatura de división | Supervisa la operación de su división. |
| `technical_secretary` | Secretario técnico | Consulta exclusivamente información logística autorizada. |
| `technical_admin` | Administrador técnico | Gestiona configuración técnica sin acceso académico amplio implícito. |

## Dimensiones de una asignación

Cada asignación incluye usuario, rol, vigencia, alcance (`own`, `program`, `division`, `system`), área de servicio (`tutoring`, `advising`, `both`, `logistics`, `technical`) y la referencia institucional que corresponda.

Un usuario puede conservar `student` y recibir temporalmente `peer_tutor`. Al vencer la segunda asignación, mantiene solo sus permisos de alumno.

## Editores de formularios

- `program_tutoring_lead` edita formularios de tutorías en su programa.
- `program_advising_lead` edita formularios de asesorías en su programa.
- `division_tutoring_liaison` edita formularios de tutorías y asesorías dentro de su división.
- `program_head` interviene solo cuando el flujo institucional le asigna aprobación o supervisión; no decide por defecto el contenido académico.
- `technical_admin` brinda soporte al constructor y al versionado, pero no decide campos académicos ni su obligatoriedad.

La selección de campos obligatorios corresponde a acuerdos colegiados o institucionales. Publicar una nueva configuración crea una versión; no modifica formularios ya respondidos.

## Reglas de acceso

- Cada permiso permanece limitado por la asignación que lo concede; no se mezclan alcances entre asignaciones.
- Las asignaciones históricas no conceden acceso actual.
- El enlace divisional cubre tutorías y asesorías de **Diseño Gráfico** y **Arquitectura** dentro de su asignación.
- `technical_secretary` solo ve nombre del evento, fecha, hora, lugar, responsable, asistencia estimada y requerimientos logísticos.
- `technical_admin` no obtiene por su rol lectura de contenido académico sensible.
- Los participantes y asistencias siempre referencian perfiles SITAA.
- Toda elevación, revocación o modificación de permisos debe quedar auditada.
- La interfaz no sustituye RLS.

## Criterios para RLS

Cada política comprobará identidad, asignación vigente, alcance, programa o división, área de servicio y operación permitida. Los reportes y exportaciones aplicarán las mismas restricciones que las vistas de origen.

## Pendientes de definición

- Quién puede otorgar o revocar cada asignación.
- Procedimiento de suplencias temporales.
- Flujo colegiado para aprobar campos obligatorios y publicar versiones.
- Nivel de detalle y umbrales de agregación para jefaturas.