# Roles y permisos

Los permisos se aplicarán con RLS en Supabase y se reflejarán en la interfaz. No existe un rol fijo en `profiles`: el acceso efectivo se calcula a partir de asignaciones de rol activas, su vigencia, alcance y área de servicio.

## Catálogo de roles

| Clave | Nombre | Responsabilidad principal |
| --- | --- | --- |
| `student` | Alumno | Consulta su información, registra su asistencia y responde encuestas. |
| `peer_tutor` | Alumno tutor par | Atiende actividades asignadas durante una vigencia determinada, sin perder su condición de alumno. |
| `professor` | Profesor tutor / asesor | Planea y documenta tutorías o asesorías bajo sus asignaciones. |
| `program_tutoring_lead` | Encargado de tutorías de carrera | Coordina tutorías y modifica sus formularios dentro del programa asignado. |
| `program_advising_lead` | Encargado de asesorías de carrera | Coordina asesorías y modifica sus formularios dentro del programa asignado. |
| `division_tutoring_liaison` | Enlace divisional de tutorías y asesorías | Consulta tutorías y asesorías de los programas de la división asignada. |
| `program_head` | Jefatura de carrera / programa | Supervisa la operación académica del programa asignado. |
| `division_head` | Jefatura de división | Supervisa la operación académica de su división. |
| `technical_secretary` | Secretario técnico | Consulta exclusivamente información logística autorizada. |
| `technical_admin` | Administrador técnico | Gestiona configuración técnica sin acceso académico amplio implícito. |

## Dimensiones de una asignación

Cada asignación de rol debe incluir:

- **Usuario y rol.** Un usuario puede tener varias asignaciones simultáneas o históricas.
- **Vigencia.** Fecha inicial, fecha final opcional y, cuando corresponda, periodo académico.
- **Alcance:** `own`, `program`, `division` o `system`.
- **Área de servicio:** `tutoring`, `advising`, `both`, `logistics` o `technical`.
- **Referencia de alcance.** Programa o división obligatoria cuando el alcance así lo requiera.

Ejemplo: un alumno conserva `student` con alcance `own` y puede recibir `peer_tutor` para tutorías de un programa durante un semestre. Al vencer esa asignación, continúa únicamente con los permisos de alumno.

## Reglas de acceso

- El permiso efectivo es la unión de asignaciones vigentes, pero cada permiso permanece limitado por su propio alcance y área de servicio.
- Las asignaciones históricas no conceden acceso actual y deben conservarse para auditoría.
- `program_tutoring_lead` y `program_advising_lead` pueden modificar formularios solo para su programa y área de servicio; `both` requiere autorización explícita.
- El enlace divisional puede consultar tutorías y asesorías de **Diseño Gráfico** y **Arquitectura** dentro de su asignación divisional. No obtiene permisos de edición salvo otra asignación explícita.
- `technical_secretary` solo puede ver: nombre del evento, fecha, hora, lugar, responsable, asistencia estimada y requerimientos logísticos. No accede a notas, asistencia individual, encuestas ni contenido académico.
- `technical_admin` administra parámetros, integraciones y operación técnica. Este rol no concede por sí mismo lectura de contenido académico sensible.
- Jefaturas y responsables solo acceden a programas o divisiones incluidos en sus asignaciones vigentes.
- Toda elevación, revocación o modificación de asignaciones debe quedar auditada.
- La interfaz no sustituye la autorización: las mismas reglas se aplicarán mediante RLS, vistas o funciones seguras.

## Criterios para RLS

Una política deberá comprobar, como mínimo:

1. La identidad mediante `auth.uid()`.
2. Que exista una asignación vigente para la acción requerida.
3. Que coincidan el alcance y la referencia de programa o división.
4. Que el área de servicio cubra el recurso (`both` cubre tutorías y asesorías).
5. Que el rol permita la operación solicitada: consultar, crear, modificar, aprobar o administrar.

## Pendientes de definición

- Nivel de detalle disponible para jefaturas y umbrales de agregación.
- Quién puede otorgar o revocar cada tipo de asignación.
- Procedimiento de suplencias y delegaciones temporales.
- Catálogo definitivo de formularios modificables por responsables de programa.