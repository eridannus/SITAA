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

## Identidad frente a autorización

- `student` y `worker` son tipos de persona; no sustituyen las asignaciones de rol.
- El alumno se identifica con número de cuenta y puede recibir o perder `peer_tutor` sin modificar su identidad base.
- El trabajador se identifica con número de trabajador y puede recibir `professor`, responsabilidades de coordinación, jefatura, secretaría técnica u otras asignaciones autorizadas.
- El programa principal describe afiliación y no concede permisos por sí mismo.

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
- Solo quienes pueden editar una actividad pueden agregar o retirar participantes; la búsqueda usa perfiles registrados y roles de participante controlados.
- Un alumno agregado como participante puede consultar la actividad conforme a RLS, sin recibir permisos de edición.
- Toda elevación, revocación o modificación de permisos debe quedar auditada.
- La interfaz no sustituye RLS.


## Creación y edición de actividades

- professor y peer_tutor operan únicamente en su programa académico principal y en el área de servicio de su asignación.
- program_tutoring_lead opera tutorías en el programa asignado.
- program_advising_lead opera asesorías en el programa asignado.
- program_head opera actividades únicamente en el programa asignado.
- division_tutoring_liaison puede elegir Diseño Gráfico, Arquitectura o «Ambos programas» dentro de su división y área de servicio.
- technical_admin puede crear actividades en cualquier programa o en el alcance divisional para soporte y pruebas.
- La interfaz filtra opciones, la acción del servidor repite la validación y RLS conserva la autorización definitiva.
- Cuando solo existe una combinación válida de alcance y programa, la interfaz la muestra como información de solo lectura; el servidor impone esa combinación e ignora valores manipulados.

## Criterios para RLS

Cada política comprobará identidad, asignación vigente, alcance, programa o división, área de servicio y operación permitida. Los reportes y exportaciones aplicarán las mismas restricciones que las vistas de origen.

## Pendientes de definición

- Quién puede otorgar o revocar cada asignación.
- Procedimiento de suplencias temporales.
- Flujo colegiado para aprobar campos obligatorios y publicar versiones.
- Nivel de detalle y umbrales de agregación para jefaturas.