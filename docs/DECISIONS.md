# Registro de decisiones

Este archivo conserva decisiones de producto y arquitectura. No se eliminan decisiones reemplazadas; se marcan como sustituidas.

## Estados

- **Propuesta:** requiere validación.
- **Aceptada:** guía la implementación.
- **Sustituida:** otra decisión la reemplazó.

## Índice

| ID | Decisión | Estado |
| --- | --- | --- |
| DEC-001 | Plataforma web y stack base | Aceptada |
| DEC-002 | Supabase como backend administrado | Aceptada |
| DEC-003 | Autorización mediante RLS | Aceptada |
| DEC-004 | Primera entrega limitada al MVP | Aceptada |
| DEC-005 | Formularios dinámicos versionados | Aceptada |
| DEC-006 | Roles mediante asignaciones múltiples y acotadas | Aceptada |
| DEC-007 | Evidencia interna y participantes registrados | Aceptada |
| DEC-008 | Catálogos operativos controlados | Aceptada |
| DEC-009 | Perfil de identidad estable | Aceptada |
| DEC-010 | Listas de asistencia con identidad institucional | Aceptada |
| DEC-011 | Programa académico obligatorio | Aceptada |
| DEC-012 | Actividades como núcleo operativo | Aceptada |
| DEC-013 | Fecha, hora y duración de actividades | Aceptada |
| DEC-014 | Validación, edición y eliminación de actividades base | Aceptada |
| DEC-015 | Alcance de actividades por programa o división | Aceptada |
| DEC-016 | Selección de alcance consciente de permisos | Aceptada |
| DEC-017 | Participantes registrados por actividad | Aceptada |
| DEC-018 | Alcance programático exclusivo durante el MVP | Aceptada |
| DEC-019 | Privacidad del padrón de participantes | Aceptada |
| DEC-020 | Registro, asistencia y códigos de acceso | Aceptada |
| DEC-021 | Pase de lista compacto | Aceptada |

## DEC-001 — Plataforma web y stack base

**Decisión:** usar Next.js con App Router, TypeScript y Tailwind CSS; desplegar en Vercel Free y mantener el código en GitHub.

**Consecuencias:** habrá una aplicación web única y se vigilarán los límites de los planes gratuitos.

**Estado:** Aceptada.

## DEC-002 — Supabase como backend administrado

**Decisión:** usar Supabase Free para PostgreSQL, Auth y RLS.

**Consecuencias:** antes del piloto se evaluarán respaldo, recuperación y cuotas. Storage no se utilizará para evidencia documental externa.

**Estado:** Aceptada.

## DEC-003 — Autorización mediante RLS

**Decisión:** RLS será el límite principal de autorización por identidad, asignación, vigencia, alcance y área de servicio.

**Consecuencias:** cada tabla expuesta requiere pruebas positivas y negativas para las combinaciones autorizadas.

**Estado:** Aceptada.

## DEC-004 — Primera entrega limitada al MVP

**Decisión:** el MVP incluye actividades, participantes registrados, asistencia, formularios dinámicos básicos y reportes CSV/PDF. Se excluyen integraciones avanzadas y evidencia documental externa.

**Consecuencias:** el constructor configura campos y versiones, pero no es todavía un motor general de procesos.

**Estado:** Aceptada.

## DEC-005 — Formularios dinámicos versionados

**Contexto:** los campos académicos y su obligatoriedad cambian por programa, servicio y acuerdos colegiados.

**Decisión:** permitir a usuarios autorizados crear campos, elegir tipos, ordenarlos y marcarlos como requeridos u opcionales. Cada respuesta conserva `form_version_id`. Solo los identificadores, marcas de tiempo, creador y referencias técnicas indispensables son obligatorios por diseño.

**Consecuencias:** ninguna lista global de campos académicos obligatorios se codifica en la aplicación. Los responsables editan dentro de su ámbito; la jefatura participa solo en aprobación o supervisión configurada; el administrador técnico brinda soporte sin decidir contenido.

**Estado:** Aceptada.

## DEC-006 — Roles mediante asignaciones múltiples y acotadas

**Decisión:** usar un catálogo de roles y asignaciones independientes con usuario, rol, vigencia, alcance y área de servicio. `profiles` no almacena un rol fijo.

**Consecuencias:** la autorización evalúa todas las asignaciones vigentes sin mezclar alcances y conserva el historial.

**Estado:** Aceptada.

## DEC-007 — Evidencia interna y participantes registrados

**Contexto:** gestionar archivos y enlaces de evidencia externa duplicaría procesos institucionales. Las listas de participación requieren identidades verificables.

**Decisión:** SITAA produce evidencia interna estructurada mediante actividades, participantes, asistencia, respuestas, resúmenes y exportaciones. No administra carteles, fotos, oficios, materiales, carpetas de Drive ni enlaces de indicadores. Todo participante referencia un perfil SITAA con identificadores institucionales cuando apliquen.

**Consecuencias:** no existirán entidades como `activity_evidence` o `evidence_indicator_links`, ni participantes externos de texto libre como flujo normal. Una persona no registrada no puede integrarse correctamente en la lista de asistencia.

**Estado:** Aceptada.

## DEC-008 — Catálogos operativos controlados

**Contexto:** actividades, formularios y reportes necesitan vocabularios estables para evitar variantes libres y resultados inconsistentes.

**Decisión:** utilizar catálogos activos para periodos académicos, tipos de actividad y servicio, categorías de atención, modalidades, estados, ubicaciones y roles de participante antes de implementar actividades.

**Consecuencias:** la operación referencia códigos controlados y solo expone valores activos. La primera interfaz es de consulta; la edición y sus permisos se definirán posteriormente.

**Estado:** Aceptada.
## DEC-009 — Perfil de identidad estable

**Contexto:** el semestre y las responsabilidades institucionales cambian con el tiempo; almacenarlos como atributos actuales del perfil produciría datos ambiguos o sobrescritos.

**Decisión:** `profiles` conserva nombres, apellidos, nombre completo, correo, tipo de persona, tipo y valor de identificador institucional y programa principal. Alumnos usan número de cuenta; trabajadores y profesores, número de trabajador. El semestre se captura únicamente en el contexto de una actividad, participación o formulario cuando se requiera. Los roles permanecen en `role_assignments`.

**Consecuencias:** los flujos de registro de alumnos y trabajadores serán distintos. La asignación inicial de alumno puede automatizarse; los roles de trabajadores y profesores requieren autorización. Cambiar responsabilidades no modifica la identidad base.

**Estado:** Aceptada.
## DEC-010 — Listas de asistencia con identidad institucional

**Decisión:** las listas de asistencia se generarán exclusivamente a partir de perfiles registrados en SITAA y mostrarán el identificador institucional que corresponda: número de cuenta para alumnos o número de trabajador para personal.

**Consecuencias:** no se usarán nombres libres como participantes válidos. Los cambios de identidad se reflejan desde el perfil, mientras los roles permanecen separados en `role_assignments`.

**Estado:** Aceptada.
## DEC-011 — Programa académico obligatorio

**Decisión:** todo perfil registrado o actualizado debe tener `primary_program_id`. El programa se selecciona de `academic_programs` entre los valores disponibles. Solo perfiles bootstrap o de prueba pueden conservar temporalmente `null` mientras completan su configuración.

**Consecuencias:** el formulario impide guardar sin programa y el dashboard advierte cuando falta. El programa es información de afiliación y no concede roles ni permisos por sí mismo.

**Estado:** Aceptada.
## DEC-012 — Actividades como núcleo operativo

**Decisión:** SITAA modela tutorías, asesorías, tutorías pares, actividades remediales y acompañamientos como `activities`, no únicamente como sesiones. Cada actividad referencia catálogos controlados, un programa, una persona responsable y quien la creó.

**Consecuencias:** participantes, asistencia, QR, formularios y reportes se incorporarán posteriormente alrededor de la actividad. Las nuevas actividades requieren inicio y se crean con estado `scheduled`.

**Estado:** Aceptada.
## DEC-013 — Fecha, hora y duración de actividades

**Decisión:** toda actividad requiere fecha y hora de inicio en formato de 24 horas. La duración usa `one_hour`, `two_hours` o `custom`; las dos primeras calculan el término y la personalizada exige fecha y hora finales. El periodo académico se asigna automáticamente desde el único periodo activo.

**Consecuencias:** `activities` conserva fecha y hora en campos separados y también completa `starts_at`/`ends_at` por compatibilidad. La validación usa la fecha actual de Ciudad de México y no permite inicios pasados ni términos anteriores al inicio.

**Estado:** Aceptada.

## DEC-014 — Validación, edición y eliminación de actividades base

**Decisión:** todos los campos operativos de una actividad son obligatorios salvo description. Las fechas se muestran como DD/MM/YYYY y las horas en formato de 24 horas. El módulo base permite editar y eliminar actividades, siempre sujeto a autenticación, confirmación explícita para eliminar y políticas RLS.

**Consecuencias:** creación y edición comparten validación y conservan los valores rechazados. El periodo se obtiene del único periodo activo; responsible_profile_id y created_by no cambian al editar. La opción «Ambos programas» queda pendiente: requerirá un modelo posterior de alcance de actividad para que division_tutoring_liaison pueda seleccionar Diseño Gráfico, Arquitectura o ambos sin debilitar permisos.

**Estado:** Aceptada.


## DEC-015 — Alcance de actividades por programa o división

**Decisión:** una actividad tiene alcance program o division. El alcance program referencia un programa y su división; el alcance division no referencia programa y representa «Ambos programas» para la División de Diseño y Edificación.

**Consecuencias:** las opciones dependen de asignaciones activas, programa, división y área de servicio. La interfaz limita selecciones, la acción del servidor valida nuevamente y RLS sigue siendo el límite definitivo.

**Estado:** Aceptada.


## DEC-016 — Selección de alcance consciente de permisos

**Decisión:** los selectores de alcance y programa solo se muestran cuando el usuario tiene más de una opción válida. Una combinación única se presenta como información de solo lectura y se impone nuevamente en el servidor.

**Consecuencias:** profesores, tutores pares y responsables con un único programa no realizan selecciones redundantes. Alumnos sin rol operativo no ven la acción de alta; los roles divisionales y técnicos conservan las opciones amplias autorizadas.

**Estado:** Aceptada.


## DEC-017 — Participantes registrados por actividad

**Decisión:** cada participante de una actividad referencia un perfil SITAA y un rol del catálogo participant_roles. La búsqueda se realiza por nombre, correo o identificador institucional mediante la función autorizada de Supabase; no se admiten personas de texto libre ni duplicados por actividad.

**Consecuencias:** los editores autorizados agregan o retiran participantes bajo RLS. Ser participante concede visibilidad de la actividad conforme a las políticas de lectura, pero no permisos de edición ni asistencia automática.

**Estado:** Aceptada.


## DEC-018 — Alcance programático exclusivo durante el MVP

**Decisión:** durante el MVP, toda actividad creada o editada pertenece a un único programa: Diseño Gráfico o Arquitectura. El alcance division permanece en el esquema como capacidad reservada, pero «Ambos programas» no se expone en la interfaz ni se acepta en las acciones operativas del MVP.

**Consecuencias:** division_tutoring_liaison y technical_admin eligen uno de los programas permitidos. La búsqueda y el alta de participantes exigen coincidencia entre el programa principal del perfil y el programa de la actividad.

**Estado:** Aceptada.


## DEC-019 — Privacidad del padrón de participantes

**Decisión:** los alumnos con rol exclusivamente `student` consultan únicamente el resumen de las actividades donde participan, con descripción y ubicación cuando existan. El padrón completo de participantes se reserva para usuarios autorizados a gestionar la actividad.

**Consecuencias:** la interfaz no invoca funciones de listado de participantes para alumnos y no muestra errores de permisos derivados de esa restricción. RLS y RPC mantienen la autorización definitiva; ser participante no concede visibilidad sobre otros participantes.

**Estado:** Aceptada.
## DEC-020 — Registro, asistencia y códigos de acceso

**Decisión:** SITAA separa registro/invitación de participantes y confirmación de asistencia. La asistencia manual es el mecanismo base y obligatorio; QR, enlace directo y código corto de tres palabras podrán actualizar después los mismos campos de asistencia, pero la corrección manual por responsable o editor autorizado siempre debe existir.

**Consecuencias:** el QR no será el único método de acceso. Los códigos de tres palabras serán breves, en minúsculas, con palabras en español, sin acentos, ñ ni caracteres especiales, fáciles de dictar y únicos entre códigos activos. El responsable podrá abrir o cerrar registro y abrir, cerrar o regenerar check-in; el check-in podrá usarse al inicio, durante o al final de la actividad.

**Seguridad por defecto:** el registro inicia cerrado y la asistencia se limita a participantes registrados. Registro abierto o check-in abierto podrán habilitarse después para tipos de actividad seleccionados. Los estados de asistencia serán `pending`, `attended`, `absent` y `justified`; las fuentes serán `manual`, `qr`, `code` y `system`.

**Estado:** Aceptada.

## DEC-021 — Pase de lista compacto

**Decisión:** SITAA mantiene tarjetas detalladas de participantes, agrega una vista compacta de pase de lista para actividades con muchos participantes e incluye conteos rápidos de registrados, asistieron y faltaron.

**Consecuencias:** los editores autorizados pueden revisar el estado general de asistencia, seleccionar participantes y aplicar cambios masivos. La vista compacta no reemplaza la edición individual; ambas actualizan los mismos campos de asistencia y respetan RLS.

**Estado:** Aceptada.

## Plantilla para nuevas decisiones

### DEC-XXX — Título

**Contexto:** por qué se necesita decidir.

**Decisión:** qué se hará.

**Consecuencias:** beneficios, costos y riesgos.

**Estado:** Propuesta, Aceptada o Sustituida por DEC-XXX.

