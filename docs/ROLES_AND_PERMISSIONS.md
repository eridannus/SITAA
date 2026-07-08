# Roles y permisos

Los permisos se aplicarÃ¡n con RLS en Supabase. No existe un rol fijo en `profiles`: el acceso efectivo se calcula a partir de asignaciones activas, vigencia, alcance y Ã¡rea de servicio.

## CatÃ¡logo de roles

| Clave | Nombre | Responsabilidad principal |
| --- | --- | --- |
| `student` | Alumno | Consulta su informaciÃ³n, registra asistencia y responde formularios. |
| `peer_tutor` | Alumno tutor par | Atiende actividades asignadas durante una vigencia determinada. |
| `professor` | Profesor tutor / asesor | Planea y documenta actividades bajo sus asignaciones. |
| `program_tutoring_lead` | Encargado de tutorÃ­as de carrera | Coordina tutorÃ­as y formularios dentro de su programa. |
| `program_advising_lead` | Encargado de asesorÃ­as de carrera | Coordina asesorÃ­as y formularios dentro de su programa. |
| `division_tutoring_liaison` | Enlace divisional de tutorÃ­as y asesorÃ­as | Consulta y coordina ambos servicios en su divisiÃ³n. |
| `program_head` | Jefatura de carrera / programa | Supervisa la operaciÃ³n del programa asignado. |
| `division_head` | Jefatura de divisiÃ³n | Supervisa la operaciÃ³n de su divisiÃ³n. |
| `technical_secretary` | Secretario tÃ©cnico | Consulta exclusivamente informaciÃ³n logÃ­stica autorizada. |
| `technical_admin` | Administrador tÃ©cnico | Gestiona configuraciÃ³n tÃ©cnica sin acceso acadÃ©mico amplio implÃ­cito. |

## Dimensiones de una asignaciÃ³n

Cada asignaciÃ³n incluye usuario, rol, vigencia, alcance (`own`, `program`, `division`, `system`), Ã¡rea de servicio (`tutoring`, `advising`, `both`, `logistics`, `technical`) y la referencia institucional que corresponda.

Un usuario puede conservar `student` y recibir temporalmente `peer_tutor`. Al vencer la segunda asignaciÃ³n, mantiene solo sus permisos de alumno.

## Identidad frente a autorizaciÃ³n

- `student` y `worker` son tipos de persona; no sustituyen las asignaciones de rol.
- El alumno se identifica con nÃºmero de cuenta y puede recibir o perder `peer_tutor` sin modificar su identidad base.
- El trabajador se identifica con nÃºmero de trabajador y puede recibir `professor`, responsabilidades de coordinaciÃ³n, jefatura, secretarÃ­a tÃ©cnica u otras asignaciones autorizadas.
- El programa principal describe afiliaciÃ³n y no concede permisos por sÃ­ mismo.

## Editores de formularios

- `program_tutoring_lead` edita formularios de tutorÃ­as en su programa.
- `program_advising_lead` edita formularios de asesorÃ­as en su programa.
- `division_tutoring_liaison` edita formularios de tutorÃ­as y asesorÃ­as dentro de su divisiÃ³n.
- `program_head` interviene solo cuando el flujo institucional le asigna aprobaciÃ³n o supervisiÃ³n; no decide por defecto el contenido acadÃ©mico.
- `technical_admin` brinda soporte al constructor y al versionado, pero no decide campos acadÃ©micos ni su obligatoriedad.

La selecciÃ³n de campos obligatorios corresponde a acuerdos colegiados o institucionales. Publicar una nueva configuraciÃ³n crea una versiÃ³n; no modifica formularios ya respondidos.

## Reglas de acceso

- Cada permiso permanece limitado por la asignaciÃ³n que lo concede; no se mezclan alcances entre asignaciones.
- Las asignaciones histÃ³ricas no conceden acceso actual.
- El enlace divisional cubre tutorÃ­as y asesorÃ­as de **DiseÃ±o GrÃ¡fico** y **Arquitectura** dentro de su asignaciÃ³n.
- `technical_secretary` solo ve nombre del evento, fecha, hora, lugar, responsable, asistencia estimada y requerimientos logÃ­sticos.
- `technical_admin` no obtiene por su rol lectura de contenido acadÃ©mico sensible.
- Los participantes y asistencias siempre referencian perfiles SITAA.
- Solo quienes pueden editar una actividad pueden agregar o retirar participantes; la bÃºsqueda usa perfiles registrados y roles de participante controlados.
- En el MVP, la bÃºsqueda y el alta de participantes se limitan a perfiles cuyo `primary_program_id` coincide con el `program_id` de la actividad; la interfaz filtra y el servidor valida nuevamente.
- Un alumno agregado como participante puede consultar la actividad conforme a RLS, sin recibir permisos de ediciÃ³n.
- Los usuarios con únicamente el rol `student` ven resúmenes de sus actividades asignadas y, cuando aplique, su propia condición de participación; no ven el padrón completo de participantes ni controles administrativos.
- Toda elevaciÃ³n, revocaciÃ³n o modificaciÃ³n de permisos debe quedar auditada.
- La interfaz no sustituye RLS.


## CreaciÃ³n y ediciÃ³n de actividades

- professor y peer_tutor operan Ãºnicamente en su programa acadÃ©mico principal y en el Ã¡rea de servicio de su asignaciÃ³n.
- program_tutoring_lead opera tutorÃ­as en el programa asignado.
- program_advising_lead opera asesorÃ­as en el programa asignado.
- program_head opera actividades Ãºnicamente en el programa asignado.
- division_tutoring_liaison puede elegir DiseÃ±o GrÃ¡fico o Arquitectura dentro de su divisiÃ³n y Ã¡rea de servicio. Â«Ambos programasÂ» queda reservado fuera del MVP.
- technical_admin puede crear actividades de prueba o soporte en DiseÃ±o GrÃ¡fico o Arquitectura durante el MVP; el alcance divisional queda reservado.
- Las actividades divisionales heredadas no se muestran como flujo normal del MVP; solo el administrador técnico o el creador original pueden convertirlas o eliminarlas para limpieza operativa, sujeto a RLS.
- La interfaz filtra opciones, la acciÃ³n del servidor repite la validaciÃ³n y RLS conserva la autorizaciÃ³n definitiva.
- Cuando solo existe una combinaciÃ³n vÃ¡lida de alcance y programa, la interfaz la muestra como informaciÃ³n de solo lectura; el servidor impone esa combinaciÃ³n e ignora valores manipulados.

## Criterios para RLS

Cada polÃ­tica comprobarÃ¡ identidad, asignaciÃ³n vigente, alcance, programa o divisiÃ³n, Ã¡rea de servicio y operaciÃ³n permitida. Los reportes y exportaciones aplicarÃ¡n las mismas restricciones que las vistas de origen.

## Pendientes de definiciÃ³n

- QuiÃ©n puede otorgar o revocar cada asignaciÃ³n.
- Procedimiento de suplencias temporales.
- Flujo colegiado para aprobar campos obligatorios y publicar versiones.
- Nivel de detalle y umbrales de agregaciÃ³n para jefaturas.
