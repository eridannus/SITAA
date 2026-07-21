# Roles y permisos

> **Documento parcialmente sustituido:** `ROLES_AND_PERMISSIONS_V2.md` es canónico para catálogo futuro, elegibilidad, autoridad de asignación y administración. Este archivo conserva las reglas operativas ya implementadas de actividades, borradores, participantes y asistencia hasta que una migración o cambio de aplicación las sustituya expresamente.

Los permisos se aplicarán con RLS en Supabase. No existe un rol fijo en `profiles`: el acceso efectivo se calcula a partir de asignaciones activas, vigencia, alcance y área de servicio.

## Catálogo de roles V1 implementado

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

Un usuario puede conservar `student` y recibir temporalmente `peer_tutor`. Al vencer la segunda asignación, mantiene sólo sus permisos de alumno.

## Identidad frente a autorización

- `student` y `worker` son tipos de persona; no sustituyen las asignaciones de rol.
- El alumno se identifica con número de cuenta y puede recibir o perder `peer_tutor` sin modificar su identidad base.
- El trabajador se identifica con número de trabajador y puede recibir `professor`, responsabilidades de coordinación, jefatura, secretaría técnica u otras asignaciones autorizadas.
- El programa principal describe afiliación y no concede permisos por sí mismo.

Una asignación sólo produce autorización operativa cuando la cuenta asociada está activa y compatible (`account_status = active`, `is_active = true`). La 0008 local propuesta para B.2a —todavía no aplicada ni verificada en PostgreSQL— hace que RLS y las RPC operativas apliquen esta frontera aun si el JWT o la asignación todavía parecen vigentes. Las cuentas no activas conservarían únicamente el acceso propio mínimo necesario para explicar su estado.

La corrección administrativa B.2a conserva la autoridad exacta de B.1 y no modifica roles. Cuando cambia tipo de persona o programa, serializa la comprobación contra `role_assignments`, `activities` y `activity_participants` en ese orden; sólo una dependencia abierta —borrador o actividad aún no terminada en tiempo de Ciudad de México— bloquea. La responsabilidad o participación histórica no borrador ya terminada no bloquea. Las altas de participantes pasan por RPC, sin DML directo de `authenticated`; las escrituras de actividades conservan el alcance autorizado, no pueden sustituir creador/responsable ni reabrir historia mediante DML cliente. Las mutaciones futuras de roles pertenecen a Fase C y deberán adoptar la misma revalidación posterior a la espera.

La persona asignada como `responsible_profile_id` puede ser profesor o tutor par según el flujo autorizado. Sólo el rol de participante `responsible` conserva el requisito de `person_type = professor`; no se extrapola esa regla a toda responsabilidad primaria.

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
- La interfaz administrativa `/catalogs` se muestra y autoriza en servidor sólo cuando existe una asignación vigente `technical_admin`. Esta restricción no elimina la lectura de catálogos controlados que necesitan registro, actividades u otros flujos institucionales.
- Los participantes y asistencias siempre referencian perfiles SITAA.
- Sólo quienes pueden editar una actividad pueden agregar o retirar participantes; la búsqueda usa perfiles registrados y roles de participante controlados.
- La persona responsable, tutor, profesor o editor autorizado puede marcar y corregir asistencia manualmente para participantes registrados, incluyendo estado y notas, ya sea de forma individual o mediante pase de lista compacto.
- La persona responsable puede abrir, cerrar o regenerar el check-in de asistencia por QR, enlace directo o código de tres palabras para participantes ya registrados. Esta función confirma asistencia; no abre registro ni invitación de participantes.
- En el MVP, la búsqueda y el alta de participantes se limitan a perfiles cuyo `primary_program_id` coincide con el `program_id` de la actividad; la interfaz filtra y el servidor valida nuevamente.
- Un alumno agregado como participante puede consultar la actividad conforme a RLS, sin recibir permisos de edición. Puede confirmar su propia asistencia mediante QR, enlace directo o código cuando la asistencia esté abierta.
- Los usuarios con únicamente el rol `student` ven resúmenes de sus actividades asignadas, incluyendo descripción y ubicación cuando existan; no ven el padrón completo de participantes ni controles administrativos.
- Toda elevación, revocación o modificación de permisos debe quedar auditada.
- La interfaz no sustituye RLS.


## Creación y edición de actividades

- professor y peer_tutor operan únicamente en su programa académico principal y en el área de servicio de su asignación.
- program_tutoring_lead opera tutorías en el programa asignado.
- program_advising_lead opera asesorías en el programa asignado.
- program_head opera actividades únicamente en el programa asignado.
- division_tutoring_liaison puede elegir Diseño Gráfico o Arquitectura dentro de su división y área de servicio. «Ambos programas» queda reservado fuera del MVP.
- technical_admin puede crear actividades de prueba o soporte en Diseño Gráfico o Arquitectura durante el MVP; el alcance divisional queda reservado.
- Las actividades divisionales heredadas no se muestran como flujo normal del MVP; solo el administrador técnico o el creador original pueden convertirlas o eliminarlas para limpieza operativa, sujeto a RLS.
- La interfaz filtra opciones, la acción del servidor repite la validación y RLS conserva la autorización definitiva.
- Cuando solo existe una combinación válida de alcance y programa, la interfaz la muestra como información de solo lectura; el servidor impone esa combinación e ignora valores manipulados.

## Borrador, publicación y bloqueo de datos base

- Las actividades pueden guardarse como borrador (`draft`) o publicarse como programadas (`scheduled`).
- Publicar una actividad bloquea la edición normal de datos base para responsables regulares.
- El creador puede leer, editar y eliminar su borrador con independencia de fechas u horas provisionales; ningún responsable, participante, gestor ni `technical_admin` accede a un borrador ajeno.
- Antes de confirmar la publicación, el servidor valida campos obligatorios, permisos, semestre, programa, fecha y hora.
- Un borrador puede contener fechas pasadas o datos temporales incompletos; `publish_activity(uuid)` rechaza publicarlo hasta que el inicio sea futuro y el contrato esté completo.
- Las actividades en borrador no se muestran como actividades asignadas a alumnos durante el MVP.
- Si una actividad publicada o ya ocurrida queda bloqueada para un responsable regular, la interfaz muestra un mensaje dinámico de contacto: tutorías contacta al encargado de tutorías del programa, asesorías contacta al encargado de asesorías del programa y otros servicios contactan al responsable correspondiente.

## Bloqueo de datos base en actividades ocurridas

- Las actividades nuevas no pueden crearse con fecha pasada.
- Una actividad ya ocurrida también bloquea sus datos base para responsables regulares.
- Participantes, asistencia y notas de asistencia permanecen editables después de ocurrida la actividad para usuarios autorizados.
- Las correcciones administrativas de datos base dependen de `can_update_activity_base`; la eliminación depende de `can_delete_activity`.
- Ocultar controles en la interfaz no sustituye RLS ni las funciones autorizadas de Supabase.

## Criterios para RLS

Cada política comprobará identidad, asignación vigente, alcance, programa o división, área de servicio y operación permitida. Los reportes y exportaciones aplicarán las mismas restricciones que las vistas de origen.

## Pendientes y decisiones trasladadas

- La autoridad para otorgar o revocar roles ya está aprobada en `ROLES_AND_PERMISSIONS_V2.md`.
- Procedimiento de suplencias temporales.
- Flujo colegiado para aprobar campos obligatorios y publicar versiones.
- Nivel de detalle y umbrales de agregación para jefaturas.


## Expiración de asistencia

Quince minutos después del término de la actividad, SITAA marca como `absent` con fuente `system` toda asistencia pendiente al cargar pantallas operativas o al intentar registrar asistencia. Desde ese momento, `pending` deja de estar disponible en controles manuales individuales y en acciones masivas; responsables y editores autorizados pueden corregir a `attended`, `absent` o `justified`, pero no dejar la asistencia vencida nuevamente en pendiente. Después del vencimiento, un editor autorizado puede reabrir asistencia de forma extraordinaria por 15 minutos. Esa reapertura permite que participantes marcados `absent` por el sistema confirmen asistencia por QR, enlace o código; no sobreescribe ausencias manuales ni asistencias justificadas. La corrección posterior también puede realizarse mediante controles manuales autorizados.
