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
| DEC-022 | Asignación automática de semestre académico | Aceptada |
| DEC-023 | Bloqueo de datos base en actividades ocurridas | Aceptada |
| DEC-024 | Flujo de borrador y publicación de actividades | Aceptada |
| DEC-025 | Indicadores monocromáticos en tarjetas de actividad | Aceptada |
| DEC-026 | Check-in de asistencia por QR, enlace y código | Aceptada |
| DEC-027 | Etiqueta compartida para QR y enlace directo | Aceptada |
| DEC-028 | Ventanas de tiempo para check-in de asistencia | Aceptada |
| DEC-029 | Expiración automática de asistencia pendiente | Aceptada |
| DEC-030 | Migraciones SQL versionadas en repositorio | Aceptada |
| DEC-031 | Consolidación inicial de seguridad e integridad | Aceptada |
| DEC-032 | Temporalidad provisional de borradores | Aceptada |
| DEC-033 | Cierre de reconciliación posterior a 0003 | Aceptada |
| DEC-034 | Dominio canónico de producción | Aceptada |
| DEC-035 | Identidad y registro institucional separados | Aceptada |
| DEC-036 | Roles académicos V2 y autoridad de asignación | Aceptada |
| DEC-044 | Puerta pública y navegación autenticada | Aceptada |
| DEC-045 | Sistema visual canónico y estados semánticos | Aceptada |
| DEC-046 | Cierre reconciliado de 0006 | Aceptada |
| DEC-047 | Directorio de cuentas de sólo lectura y base de auditoría administrativa | Aceptada |
| DEC-048 | Cierre y reconciliación de Fase B.1 / migración 0007 | Aceptada |
| DEC-037 | Administración confiable y filtrado posterior a autorización | Aceptada |
| DEC-038 | Implementación por fases y check-in abierto posterior | Aceptada |
| DEC-039 | Sincronización Auth/profile en Fase A | Aceptada |
| DEC-040 | Contrato de aplicación coordinada de identidad 0004 | Aceptada |
| DEC-041 | Verificación Google diferida hasta la finalización institucional | Aceptada |
| DEC-042 | Cierre reconciliado de identidad y Google OAuth | Aceptada |

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

**Decisión:** permitir a usuarios autorizados crear campos, elegir tipos, ordenarlos y marcarlos como requeridos u opcionales. Cada respuesta conserva `form_version_id`. Sólo los identificadores, marcas de tiempo, creador y referencias técnicas indispensables son obligatorios por diseño.

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

**Decisión:** todo perfil registrado o actualizado debe tener `primary_program_id`. El programa se selecciona de `academic_programs` entre los valores disponibles. Sólo perfiles bootstrap o de prueba pueden conservar temporalmente `null` mientras completan su configuración.

**Consecuencias:** el formulario impide guardar sin programa y el dashboard advierte cuando falta. El programa es información de afiliación y no concede roles ni permisos por sí mismo.

**Estado:** Aceptada.
## DEC-012 — Actividades como núcleo operativo

**Decisión:** SITAA modela tutorías, asesorías, tutorías pares, actividades remediales y acompañamientos como `activities`, no únicamente como sesiones. Cada actividad referencia catálogos controlados, un programa, una persona responsable y quien la creó.

**Consecuencias:** participantes, asistencia, QR, formularios y reportes se incorporarán posteriormente alrededor de la actividad. Las nuevas actividades requieren inicio y se crean con estado `scheduled`.

**Estado:** Aceptada.
## DEC-013 — Fecha, hora y duración de actividades

**Decisión:** toda actividad requiere fecha y hora de inicio en formato de 24 horas. La duración usa `one_hour`, `two_hours` o `custom`; las dos primeras calculan el término y la personalizada exige fecha y hora finales. El semestre se asigna automáticamente desde la fecha de inicio de la actividad mediante rangos oficiales.

**Consecuencias:** `activities` conserva fecha y hora en campos separados y también completa `starts_at`/`ends_at` por compatibilidad. Los reportes y estadísticas podrán filtrar por semestre. La validación usa la fecha actual de Ciudad de México y no permite inicios pasados ni términos anteriores al inicio.

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

## DEC-022 — Asignación automática de semestre académico

**Contexto:** SITAA requiere reportes semestrales consistentes, pero el semestre no debe ser elegido manualmente por usuarios operativos ni presentarse con lenguaje técnico confuso.

**Decisión:** la interfaz mostrará la etiqueta **Semestre** y nunca “periodo calculado”. SITAA asignará el semestre automáticamente desde la fecha de inicio de la actividad, usando rangos oficiales mantenidos por usuarios técnicos o administrativos conforme a calendarios UNAM. El primer semestre calendario corresponde al semestre 2 del mismo año académico; el segundo semestre calendario corresponde al semestre 1 del año académico siguiente.

**Ejemplos:** febrero–mayo 2026 = 2026-2; agosto–noviembre 2026 = 2027-1; febrero–mayo 2027 = 2027-2; agosto–noviembre 2027 = 2028-1.

**Consecuencias:** los usuarios operativos no seleccionan ni editan el semestre. Actividades, reportes, estadísticas y exportaciones podrán filtrarse por semestre sin almacenar semestre actual en `profiles`.

**Estado:** Aceptada.
## DEC-023 — Bloqueo de datos base en actividades ocurridas

**Contexto:** las actividades ya realizadas requieren correcciones de asistencia y participantes, pero no deben modificar libremente su planeación base.

**Decisión:** una actividad publicada que ya ocurrió bloquea sus datos base para responsables regulares; participantes, asistencia y notas permanecen editables para usuarios autorizados. Los borradores no participan en este cálculo temporal. Las correcciones administrativas de datos base y la eliminación se determinan con funciones autorizadas de Supabase.

**Consecuencias:** la interfaz muestra resumen de sólo lectura cuando los datos base publicados están bloqueados y conserva la gestión de asistencia. La base de datos mantiene la autorización definitiva mediante RLS y funciones como `activity_has_ended`, `can_update_activity_base` y `can_delete_activity`.

**Estado:** Aceptada.

## DEC-024 — Flujo de borrador y publicación de actividades

**Contexto:** la planeación de una actividad puede requerir guardarse antes de quedar lista para participantes y asistencia. Además, publicar debe marcar un cambio claro de ciclo de vida y evitar bloqueos accidentales.

**Decisión:** las actividades pueden guardarse como borrador con `status_code = draft` o publicarse con `status_code = scheduled`. Guardar borrador solo exige título y programa; los demás campos operativos pueden quedar incompletos. Publicar exige todos los campos operativos, valida fecha y hora, y solo después de pasar validación muestra la confirmación de publicación. En la interfaz **Borrador** y **Programada** usan estilos visuales distintos.

**Consecuencias:** una actividad en borrador no se muestra como actividad asignada a alumnos y sólo aparece en el panel de quien la creó. Su creador puede editarla o eliminarla aunque la fecha sea pasada o la hora esté incompleta. Al confirmar la publicación, responsables regulares dejan de editar libremente datos base; las correcciones administrativas dependen de `can_update_activity_base`. Participantes y asistencia siguen siendo gestionables por usuarios autorizados después de publicar. Una actividad no puede publicarse con fecha u hora de inicio pasada en tiempo de Ciudad de México.

**Estado:** Aceptada.

## DEC-025 — Indicadores monocromáticos en tarjetas de actividad

**Decisión:** las tarjetas de actividad muestran indicadores visuales discretos y fijos: `TUT` para tutoría, `ASE` para asesoría, `✎` para Diseño Gráfico y `△` para Arquitectura. Los indicadores usan estilo monocromático y etiquetas accesibles; no se reinterpretan dinámicamente ni usan emoji decorativo.

**Consecuencias:** las tarjetas pueden escanearse rápidamente sin añadir color semántico adicional. Si falta el dato de servicio o programa, no se muestra un indicador que pueda resultar engañoso.

**Estado:** Aceptada.

## DEC-026 — Check-in de asistencia por QR, enlace y código

**Decisión:** SITAA permite confirmar asistencia de participantes ya registrados mediante QR, enlace directo con token secreto o código corto de tres palabras. Estos mecanismos no registran ni invitan participantes; sólo actualizan la asistencia de perfiles ya vinculados a la actividad.

**Consecuencias:** el responsable o editor autorizado abre, cierra o regenera el acceso de asistencia. Regenerar invalida el código anterior. La asistencia manual sigue siendo obligatoria como mecanismo de corrección y todos los métodos actualizan los mismos campos de `activity_participants`.

**Estado:** Aceptada.

## DEC-027 — Etiqueta compartida para QR y enlace directo

**Contexto:** la fuente de asistencia `qr` se usa cuando un participante confirma asistencia mediante el token seguro, ya sea escaneando el QR o abriendo el enlace directo.

**Decisión:** mantener el valor de base de datos `qr` sin agregar nuevas fuentes, pero mostrarlo en la interfaz como **QR o enlace**.

**Consecuencias:** la interfaz describe mejor el comportamiento real sin cambiar enums, RPCs ni analítica de origen. Si más adelante se requiere distinguir QR de enlace directo, se definirá una decisión y modelo específico.

**Estado:** Aceptada.

## DEC-028 — Ventanas de tiempo para check-in de asistencia

**Contexto:** la confirmación por QR, enlace directo o código debe evitar registros fuera del momento operativo de la actividad, sin impedir correcciones manuales autorizadas.

**Decisión:** la ventana normal de asistencia inicia 15 minutos antes del inicio de la actividad y termina 15 minutos después de su término. Si se abre antes o durante la actividad, el acceso permanece válido hasta ese cierre normal. Después de concluida la ventana normal, un responsable o editor autorizado puede reabrir la asistencia manualmente por ventanas de 15 minutos, tantas veces como sea necesario. El responsable o editor puede cerrar la asistencia manualmente en cualquier momento. No se puede abrir asistencia en actividades en borrador ni en actividades sin fecha y hora completas.

**Consecuencias:** los códigos activos tienen expiración visible para los editores y los códigos cerrados o expirados se rechazan como inválidos. La reapertura posterior al evento queda limitada temporalmente y la asistencia manual sigue disponible para correcciones justificadas.

**Estado:** Aceptada.


## Plantilla para nuevas decisiones

### DEC-XXX — Título

**Contexto:** por qué se necesita decidir.

**Decisión:** qué se hará.

**Consecuencias:** beneficios, costos y riesgos.

**Estado:** Propuesta, Aceptada o Sustituida por DEC-XXX.


## DEC-029 — Expiración automática de asistencia pendiente

**Decisión:** `pending` es un estado temporal. Quince minutos después de la hora de término de una actividad, SITAA finaliza de forma perezosa toda asistencia pendiente y la marca como `absent` con fuente `system` cuando se cargan actividades o se intenta registrar asistencia.

**Consecuencias:** para indicadores y reportes, una actividad vencida no debe conservar asistencia pendiente indefinida. Después del vencimiento normal, los estados finales esperados son `attended`, `absent` o `justified`. La interfaz de asistencia manual oculta `pending` cuando la ventana ya expiró y el servidor rechaza intentos de volver a dejar registros en pendiente. El botón estudiantil "Registrar asistencia" sólo aparece mientras la asistencia propia está en `pending`. Una vez vencido el periodo normal, un editor autorizado puede reabrir asistencia de forma extraordinaria por 15 minutos usando el mismo flujo QR/enlace/código. Durante esa reapertura, `check_in_activity` puede cambiar a `attended` a participantes marcados `absent` por el sistema, pero no sobreescribe ausencias manuales ni asistencias justificadas. La corrección posterior sigue disponible en el flujo manual autorizado.

**Estado:** Aceptada.

## DEC-030 — Migraciones SQL versionadas en repositorio

**Contexto:** durante el prototipo, varios cambios SQL de Supabase se aplicaron manualmente. El primer intento de baseline se construyó desde snapshots JSON incompletos y no representaba constraints, índices, triggers, todas las tablas ni semillas. Posteriormente se obtuvo un snapshot completo y de sólo lectura del esquema vivo mediante `pg_dump` y `psql`.

**Decisión:** `0001_baseline_current_schema.sql` queda sustituida por la baseline reconciliada desde los snapshots vivos completos y se convierte en el punto de partida para instalaciones nuevas. La versión incompleta anterior queda superada y nunca fue aplicada como migración administrada. Después de esta reconciliación, `0001` no se reescribe salvo para corregir un defecto comprobado de la baseline. Todo cambio posterior usa `0002_short_description.sql`, `0003_short_description.sql` y así sucesivamente. La migración debe crearse antes o junto con cualquier SQL aplicado a Supabase, aunque la aplicación siga realizándose manualmente.

**Consecuencias:** el repositorio pasa a ser la fuente de verdad para cambios futuros. La baseline no debe ejecutarse a ciegas contra la base viva actual, que ya contiene los objetos por cambios manuales históricos. Los snapshots de reconciliación no sustituyen migraciones y cada migración posterior debe revisarse junto con la documentación relacionada.

**Estado:** Aceptada.

## DEC-031 — Consolidación inicial de seguridad e integridad en base de datos

**Contexto:** la auditoría reconciliada confirmó borradores expuestos por helpers/RLS, posibilidad de devolver asistencia vencida a Pendiente, publicación incompleta al usar la API directamente y grants de objeto excesivos. La restricción académica de `technical_admin` requiere un diseño posterior de administración de identidades y permisos.

**Decisión:** 0002 define cuatro límites: los borradores son privados al creador en la base; Pendiente es temporal y se rechaza en la frontera natural o después, tanto por RPC como por `UPDATE` directo, incluso si existe reapertura extraordinaria; la publicación normal se realiza mediante `publish_activity(uuid)` y toda transición cliente `draft → scheduled` revalida sesión, creador, permiso vigente, semestre y contrato completo; `created_by` es inmutable y una actividad publicada no vuelve a borrador desde una sesión cliente; `anon` y `authenticated` reciben sólo los privilegios directos confirmados como necesarios. `technical_admin` conserva temporalmente acceso amplio de aplicación para creación y contenido publicado durante desarrollo y pruebas, pero no a borradores ajenos.

**Consecuencias:** la aplicación crea primero un borrador y sólo después invoca la RPC de publicación. Los borradores incompletos siguen permitidos; las filas programadas incompletas no. Se conservan overloads heredados, `activities.updated_by`, alcance divisional reservado, capacidad de tokens de registro y timestamps de compatibilidad. Los privilegios predeterminados no cambian por falta de evidencia reconciliada.

**Estado:** Aceptada; 0002 aplicada y verificada en Supabase.

## DEC-032 — Temporalidad provisional de borradores

**Contexto:** una fecha pasada o una hora faltante en un borrador hacía que `activity_has_ended` lo tratara como ocurrido y que los helpers de datos base bloquearan al propio creador.

**Decisión:** Las fechas y horas de un borrador son provisionales y no activan bloqueo temporal. `activity_has_ended(uuid)` devuelve false para `draft`; el creador conserva lectura, edición y eliminación exclusivas. El bloqueo temporal comienza sólo después de publicar.

**Consecuencias:** 0003 corrige las funciones sin reescribir filas, por lo que los borradores atrapados se recuperan al aplicarla. `publish_activity(uuid)` sigue rechazando campos incompletos, inicio pasado, semestre inválido y cualquier inconsistencia del contrato programado. Los controles de asistencia y QR no se muestran mientras la actividad siga en borrador.

**Estado:** Aceptada; 0003 aplicada y verificada en Supabase el 2026-07-16.

## DEC-033 — Cierre de reconciliación posterior a 0003

**Contexto:** 0002 y 0003 fueron aplicadas y verificadas en Supabase. El snapshot vivo se regeneró después de ambas migraciones y conserva evidencia especializada de estructura, funciones, políticas, privilegios y ACL.

**Decisión histórica al cierre de 0003:** la cadena `0001 + 0002 + 0003` quedó reconciliada con el snapshot generado en `2026-07-17T00:21:06Z`, sin deriva inexplicada. En ese momento, el siguiente número permitido era `0004`. DEC-042 registra el cierre vigente posterior a 0005.

**Consecuencias:** todo cambio futuro debe crear una migración nueva, incluir verificación y rollback cuando corresponda, aplicarse manualmente, regenerar el snapshot después de cambios significativos, comparar el estado vivo contra la cadena completa y actualizar el changelog. La restricción de `technical_admin` permanece diferida y el check-in abierto sigue fuera del alcance implementado.

**Estado:** Aceptada.

## DEC-045 — Sistema visual canónico y estados semánticos

**Contexto:** superficies anteriores al rediseño conservaban emerald como marca, combinaciones locales de alertas y controles duplicados, lo que producía inconsistencia y regresiones de contraste.

**Decisión:** `docs/DESIGN_SYSTEM.md` es la especificación visual autoritativa. Azul y oro forman la identidad; éxito, advertencia, error, información y neutral usan tokens independientes. Verde queda reservado a éxito real. Acciones, badges, alertas, tabs, campos, superficies y encabezados reutilizan primitivas semánticas, y `npm run check:ui` bloquea patrones prohibidos.

**Consecuencias:** nuevas pantallas no eligen paletas propias ni duplican controles rellenos. Los cambios visuales requieren contraste comprobado, foco, teclado, wrapping, movimiento reducido y revisión responsive. Las excepciones de color calculado se limitan al canvas y se documentan en el checker.

**Estado:** Aceptada.

## DEC-034 — Dominio canónico de producción

**Contexto:** los enlaces de check-in deben ser estables y coincidir con la configuración de Vercel y Supabase Auth.

**Decisión:** el origen público canónico es `https://www.sitaa.net`. `https://sitaa.net` redirige al origen canónico y `https://sitaa.vercel.app` permanece como respaldo técnico, no como URL pública principal. Vercel Production define `NEXT_PUBLIC_SITE_URL=https://www.sitaa.net`; Supabase Authentication usa ese mismo origen como Site URL y permite redirecciones bajo `https://www.sitaa.net/**` y `https://sitaa.vercel.app/**`.

**Consecuencias:** QR y enlaces directos derivan de `NEXT_PUBLIC_SITE_URL` y fueron verificados manualmente con `https://www.sitaa.net/check-in/...`. Cloudflare administra DNS y los CNAME dirigidos a Vercel permanecen en modo DNS only. Los entornos Preview no deben heredar automáticamente el origen de producción salvo configuración deliberada. `NEXT_PUBLIC_SITE_URL` es configuración pública, pero su valor productivo no se fija en archivos locales con secretos.

**Estado:** Aceptada.

## DEC-035 — Identidad y registro institucional separados

**Contexto:** el esquema actual usa `student|worker`, no distingue cuentas técnicas internas y sólo dispone de login. El acceso básico no debe confundirse con responsabilidades académicas.

**Decisión:** SITAA tendrá rutas públicas distintas para alumnos y profesores. Ambas autentican primero con Google y capturan identidad institucional después, en formularios autenticados de tipo fijo. Google aporta correo verificado y SITAA activa sólo al completar el perfil. No hay restricción de dominio. Las cuentas institucionales usan `student|professor`, identificador de dígitos como texto y programa obligatorio. Las cuentas `technical` se crean administrativamente. Perfil y asignaciones permanecen separados.

**Consecuencias:** un profesor nuevo no es tutor ni asesor; un alumno nuevo no es tutor par. La persona desarrolladora puede tener una cuenta institucional ordinaria y otra técnica independiente. Corregir identidad principal corresponde a administración técnica auditada. La implementación requiere una migración a partir de 0004 y backfill verificado.

**Estado:** Aceptada; detalles técnicos menores se registran en `IMPLEMENTATION_GAPS_0004.md`.

## DEC-039 — Sincronización Auth/profile en Fase A

**Contexto:** el registro público debe crear el perfil sin exponer credenciales administrativas ni confiar en metadata editable para privilegios.

**Decisión:** 0004 usa triggers y un RPC `SECURITY DEFINER` exclusivo de `authenticated`. Un Google nuevo crea un profile mínimo `pending_registration`; después, el usuario captura identidad institucional y completa el mismo perfil transaccionalmente. No existe tabla de intents, PII preautenticación, escritura anónima ni endpoint de disponibilidad. Signup público por contraseña y OAuth distinto de Google se rechazan. El login por contraseña permanece sólo para usuarios existentes. La creación no genera `role_assignments`; cuentas técnicas requieren `app_metadata` confiable. Toda inserción futura crea exactamente un profile o revierte atómicamente.

**Consecuencias:** no se necesita SMTP ni se envía identidad institucional a Google. Una cookie breve `HttpOnly` guarda sólo la ruta `student|professor`; no contiene PII ni funciona como autorización. La duplicidad se informa únicamente después de autenticar. La aplicación nunca recibe `service_role`. Administración y auditoría completa continúan en Fase B.

**Estado:** Implementada por 0004 y corregida en su secuencia OAuth por 0005; ambas están aplicadas y verificadas.

## DEC-040 — Contrato de aplicación coordinada de identidad 0004

**Contexto:** 0004 introduce semántica de `profiles` distinta de la aplicación post-0003: `worker` pasa a `professor`, el acceso depende de `account_status` y Auth crea/sincroniza perfiles mediante triggers. Separar la migración de la versión compatible de la aplicación durante demasiado tiempo puede mostrar etiquetas incompatibles o bloquear de forma inesperada a una cuenta.

**Decisión:** antes de cualquier DDL se ejecuta un preflight bloqueante. Detiene perfiles incompatibles, huérfanos Auth/profile, dependencias anteriores de `pending_verification` y triggers no documentados. Identidades email/password y OAuth existentes son informativas, no bloqueantes. El despliegue se coordina así: configurar Google; aprobar preflight; comprometer app y migración; aplicar 0004 manualmente; desplegar la app compatible; ejecutar verificador y pruebas; regenerar snapshot.

**Consecuencias:** perfiles activos existentes permanecen activos aunque usen sólo contraseña. El rollback no elimina Auth users, profiles ni identidades Google y se bloquea ante perfiles `pending_registration` o técnicos incompatibles. La ventana entre DDL y despliegue debe minimizarse.

**Estado:** Aceptada y aplicada con 0004. La migración 0005 mantiene el mismo contrato coordinado para su corrección incremental.

## DEC-036 — Roles académicos V2 y autoridad de asignación

**Contexto:** `professor` combina tutoría y asesoría, faltan responsabilidades organizacionales separadas y la tabla no conserva revocación completa.

**Decisión:** tutor par, profesor tutor y profesor asesor son roles distintos, aditivos y revocables. Se formalizan coordinación y secretaría técnica por programa, jefatura, enlace y secretaría auxiliar divisional, y `technical_admin`. Sólo `technical_admin` administra roles críticos; el lead de tutorías delega profesor tutor/tutor par y el lead de asesorías delega profesor asesor dentro de su programa. Nadie se autoasigna. Toda asignación/revocación conserva historia y auditoría.

**Consecuencias:** Mariana y Alejandra requieren códigos distintos aunque inicialmente compartan permisos. Los códigos vivos se migran con backfill y compatibilidad, no se renombran a ciegas. A-02 permanece como excepción transitoria hasta completar la administración y las pruebas de la fase E.

**Estado:** Aceptada.

## DEC-037 — Administración confiable y filtrado posterior a autorización

**Contexto:** no existe panel de usuarios y las operaciones de Supabase Auth admin no pueden exponerse con una clave pública. Los filtros futuros tampoco deben convertirse en permisos implícitos.

**Decisión:** las operaciones de activación, desactivación, identidad, Auth admin y roles críticos se ejecutan sólo en backend confiable o Edge Function, con autorización y auditoría; nunca con `service_role` en el cliente. Administradores no ven ni establecen contraseñas. RLS/RPC construyen primero el conjunto visible y los filtros sólo lo reducen, ordenan o paginan.

**Consecuencias:** desactivar conserva historia y suspende autorización efectiva. El panel busca por identidad, cuenta, estado y asignaciones sin descargar directorios completos. Los estados de filtro serán reutilizables en actividades y reportes, pero sus opciones visibles son UX, no autorización.

**Estado:** Aceptada.

## DEC-038 — Implementación por fases y check-in abierto posterior

**Contexto:** identidad, administración, roles, filtros y la eliminación de A-02 tienen dependencias de seguridad; el check-in abierto requiere una identidad estable.

**Decisión:** implementar en orden: A) identidad/registro; B) administración básica/auditoría; C) roles; D) paneles/filtros/reportes; E) retirar acceso académico implícito de `technical_admin`; F) check-in abierto. La fase F sólo opera cuando la actividad lo habilita y, dentro de una transacción, agrega al usuario autenticado elegible como participante si falta y marca asistencia.

**Consecuencias:** el check-in abierto no forma parte de la Fase A. Conserva el mensaje normal de éxito, valida cuenta/programa/elegibilidad y no cambia la ausencia normal de participantes registrados que no asisten. Cada fase puede usar una o más migraciones posteriores sin reescribir 0001–0005.

**Estado:** Aceptada.

## DEC-041 — Verificación Google diferida hasta la finalización institucional

**Contexto:** con 0004 aplicada, Supabase confirmó Google pero insertó inicialmente `auth.users.email_confirmed_at=null`. El trigger lanzó `sitaa_google_email_not_verified` y revirtió toda la operación; no quedaron filas que limpiar.

**Decisión:** 0005 permite que el trigger cree únicamente un perfil institucional `pending_registration`, inactivo e incompleto, cuando metadata confiable identifica Google. La activación se traslada al RPC autenticado, que exige una identidad Google enlazada al mismo Auth user, correo coincidente con Auth/profile y verificación final. Las rutas y el action de alta impiden reiniciar registro desde una cuenta autenticada.

**Consecuencias:** quitar la verificación temprana no concede acceso. Se conserva el rechazo atómico de proveedores no soportados y signup por contraseña, mientras los diagnósticos del callback distinguen etapas sin registrar secretos. El preflight, aplicación, verificador y smoke tests de 0005 fueron aprobados.

**Estado:** Implementada, aplicada y verificada en 0005.

## DEC-042 — Cierre reconciliado de identidad y Google OAuth

**Contexto:** 0004 y 0005 están aplicadas y verificadas; el snapshot `2026-07-17T23:20:07Z` fue generado después de los verificadores, los smoke tests y una separación administrativa controlada de cuentas.

**Decisión:** cerrar la Fase A como operativa y fijar `0001`–`0005` como cadena aplicada, verificada y reconciliada. La separación inicial entre cuenta técnica y cuenta académica se documenta como limpieza específica del entorno, no como migración reutilizable ni función de fusión. `0006` es el siguiente número disponible, sin quedar reservado para una implementación concreta.

**Consecuencias:** registro público Google, ciclo `pending_registration`, finalización institucional, activación básica, cuenta técnica, guardas de registro y login heredado quedan vigentes. Las fases B–F continúan abiertas y `technical_admin` conserva temporalmente su acceso académico amplio hasta la Fase E.

**Estado:** Aceptada; reconciliación cerrada sin deriva inexplicada.

## DEC-043 — Identidad visual y nombres personales estructurados

**Contexto:** la experiencia pública todavía usa una portada extensa y estilos verdes dispersos. Además, la finalización del registro captura únicamente `full_name`, aunque `profiles` ya dispone de `first_names`, `paternal_surname` y `maternal_surname`.

**Decisión:** 0006 formaliza esos tres campos existentes como fuente autoritativa del nombre para cuentas activas; un trigger normaliza espacios y mantiene `full_name` como valor derivado de compatibilidad. No se dividirán nombres históricos automáticamente: el preflight bloqueará cuentas activas incompletas para que su correspondencia sea revisada fuera de archivos versionados. La aplicación capturará y editará los componentes por separado. El orden futuro será apellido paterno, apellido materno y nombre(s), con comparación local en español cuando corresponda.

La interfaz adopta tokens semánticos azul y oro inspirados en la identidad UNAM, una puerta de acceso compacta y una navegación autenticada con avatar y menú de cuenta. El fondo animado será decorativo, no interceptará interacción y respetará `prefers-reduced-motion`. Los reportes y las exportaciones seguirán fuera de alcance, pero en el futuro expondrán columnas separadas para nombre(s) y apellidos.

**Consecuencias:** `full_name` no se elimina y continúa atendiendo consumidores antiguos. La aplicación coordinada exigió aprobar el preflight antes de ejecutar 0006. La cuenta Google refuerza visualmente la identidad autenticada sin convertir metadata del proveedor en identidad institucional editable.

**Estado:** Implementada, aplicada, verificada y reconciliada en 0006.

## DEC-044 — Puerta pública y navegación autenticada

**Contexto:** la primera revisión visual en producción mostró que la puerta pública heredaba el encabezado autenticado, podía desplazar toda la página en vistas móviles y presentaba acciones demasiado próximas. La navegación seleccionada no garantizaba contraste y exponía la interfaz administrativa de catálogos a usuarios institucionales ordinarios.

**Decisión:** el layout raíz queda neutral y los árboles autenticados incorporan el encabezado mediante layouts anidados, sin ocultamiento posterior por pathname. `/` y `/login` ocupan el viewport dinámico completo, respetan áreas seguras y limitan cualquier desbordamiento excepcional al interior de la tarjeta. La navegación usa clases semánticas con texto blanco explícito en el estado seleccionado, denomina `Inicio` al destino `/dashboard` y conserva rutas móviles en el menú de cuenta. La interfaz `/catalogs` requiere una asignación vigente `technical_admin` tanto para mostrarse como para abrirse directamente; los catálogos controlados siguen disponibles como datos de referencia para los flujos que los consumen.

**Consecuencias:** la puerta cerrada no muestra navegación global ni genera desplazamiento documental normal. El dashboard deja de duplicar enlaces disponibles en el encabezado o menú de cuenta. Ocultar Catálogos no sustituye RLS ni cambia privilegios de las tablas; es una autorización adicional de la interfaz administrativa calculada desde asignaciones activas.

**Estado:** Aceptada.

## DEC-046 — Cierre reconciliado de 0006

**Contexto:** 0006 fue aplicada después de aprobar su preflight, desplegar la aplicación compatible y revisar los nombres estructurados. El verificador transaccional terminó con código 0 y `ROLLBACK`; su única corrección fue conceder al rol de prueba acceso a helpers `pg_temp`, sin cambiar privilegios productivos. El snapshot `2026-07-18T04:05:40Z` se generó después de los smoke tests.

**Decisión:** fijar `0001`–`0006` como cadena aplicada, verificada y reconciliada, sin deriva inexplicada. `first_names`, `paternal_surname` y `maternal_surname` son autoritativos; `full_name` es compatibilidad derivada. `0007` es el siguiente número disponible. `docs/DESIGN_SYSTEM.md` es el contrato obligatorio para toda interfaz: marca azul y oro, acciones primarias azules, oro/ámbar para advertencia, rojo para destrucción y verde sólo para éxito semántico; `npm run check:ui` es una validación obligatoria.

## DEC-047 — Directorio de cuentas de sólo lectura y base de auditoría administrativa

**Contexto:** Fase B requiere consultar cuentas antes de introducir correcciones, operaciones Auth o mutaciones de roles. El esquema vivo V1 no tiene campos de revocación y las políticas propias no deben ampliarse para habilitar consultas transversales.

**Decisión:** preparar 0007 con cuatro RPC `SECURITY DEFINER` de sólo lectura y una bitácora `admin_audit_events` append-only. La autoridad exacta exige cuenta activa y asignación actual `technical_admin/system/technical`, sin programa/división; `starts_at` y `ends_at` son fechas calendario inclusivas de `America/Mexico_City`. Un helper privado deriva esa fecha explícitamente, por lo que Next.js y las RPC comparten el contrato y la autorización no depende de la zona horaria de la sesión PostgreSQL. El directorio no navega el padrón sin criterios, escapa comodines literales, limita página a 1–1 000 000 y tamaño a 1–50, exige coincidencia de rol/servicio/alcance en una misma asignación y recupera el total mediante la misma RPC si una página queda fuera de rango. La lista enmascara identificadores; el detalle expone sólo identidad necesaria y un booleano de confirmación por Auth o Google verificado. La auditoría bloquea `UPDATE`/`DELETE`/`TRUNCATE`, admite únicamente metadata de objeto JSON de hasta 16 384 bytes, concede a `service_role` sólo `SELECT`/`INSERT` y omite metadata en su proyección B.1.

**Consecuencias:** B.1 no activa, desactiva, corrige, invita, recupera ni administra roles. Las operaciones de ciclo de vida/Auth quedan en B.2/B.3 y las mutaciones de rol en Fase C. Durante la preparación, el código compatible mostró “migración pendiente” hasta la aplicación coordinada de 0007; ese estado histórico quedó cerrado por DEC-048.

**Consecuencias:** las migraciones aplicadas permanecen inmutables. Los grants temporales del verificador desaparecen con su sesión/transacción y no amplían producción. Reportes y exportaciones CSV/PDF siguen pendientes. Cualquier cambio posterior requiere una nueva migración, snapshot y reconciliación cuando corresponda.

**Estado:** Aceptada; implementada y cerrada por DEC-048.

## DEC-048 — Cierre y reconciliación de Fase B.1 / migración 0007

**Contexto:** 0007 fue aplicada con `COMMIT` después de aprobar el preflight y desplegar la aplicación compatible. La primera ejecución del verificador falló antes de crear fixtures por una normalización defectuosa del arnés, no por el esquema vivo. El verificador corregido terminó con `ROLLBACK`, los smoke tests de producción aprobaron y el snapshot completo `2026-07-21T00:16:03Z` fue generado con herramientas PostgreSQL 18.4 en modo de sólo lectura.

**Decisión:** cerrar Fase B.1 y fijar `0001`–`0007` como cadena aplicada, verificada y reconciliada. El directorio administrativo permanece exclusivamente de lectura, con autoridad exacta B.1 y auditoría append-only. La corrección del verificador no representa una migración ni un cambio de objetos vivos. La reconciliación estructural, funcional, RLS, privilegios, ACL y catálogos no encontró deriva inexplicada.

**Consecuencias:** 0007 es inmutable. B.1 no incorpora mutaciones de cuentas, Auth o roles. El snapshot post-0007 fue la evidencia autoritativa hasta el cierre posterior documentado por DEC-050; 0008 ocupó después el siguiente número disponible.

**Estado:** Aceptada; Fase B.1 operativa y reconciliada sin deriva inexplicada.

## DEC-049 — Barrera operativa de cuenta activa y corrección administrativa de identidad

**Contexto:** una asignación vigente y un JWT emitido antes de una baja temporal no bastan para determinar que una cuenta deba seguir operando. B.1 tampoco permite corregir de manera transaccional errores en la identidad estable de otra cuenta.

**Decisión:** preparar 0008 para exigir perfil único con `account_status = active` e `is_active = true` antes de cualquier acceso operativo. La base aplica esta frontera mediante políticas RLS restrictivas sobre `activities` y `activity_participants` y guardas explícitas en las 29 rutinas operativas `SECURITY DEFINER` ejecutables por `authenticated`. La corrección de identidad usa la autoridad B.1 exacta, prohíbe autocorrección y objetivos pendientes, revalida dependencias bajo locks y escribe un único evento `account_identity_corrected` con razón obligatoria y metadata mínima. Para cerrar escritores concurrentes, `authenticated` deja de tener DML directo sobre `activity_participants`; `activities` conserva su DML de aplicación bajo un trigger owner-only que inmoviliza creador/responsable, revalida cambios de alcance y evita participantes incompatibles. Fase C deberá aplicar el mismo protocolo a cualquier writer futuro de `role_assignments`.

**Endurecimiento de revisión:** la revalidación adquiere `SHARE` en orden fijo sobre `role_assignments`, `activities` y `activity_participants`; bloquea actor y objetivo juntos en orden UUID; y repite la autoridad B.1 antes de conocer o mutar el objetivo. Revocaciones y desactivaciones iniciadas primero hacen fallar ese segundo control; una corrección iniciada primero puede confirmar bajo autoridad todavía válida. La única frontera de dependencia abierta es borrador o actividad todavía no terminada según el cálculo post-0007 en `America/Mexico_City`; la historia no borrador terminada no bloquea, pero DML autenticado tampoco puede reabrirla. El rol participante `responsible` conserva el requisito de profesor sin imponerlo a la responsabilidad primaria. Las entradas colapsan whitespace, recortan y convierten vacío en `NULL`. Preflight, guarda post-DDL, verificador y rollback exigen RLS/FK/ACL/firmas exactos: `attacl` debe estar vacío; las filas de `information_schema.column_privileges` deben derivar íntegramente del ACL de tabla; y `has_column_privilege` no puede superar `has_table_privilege`. Las cuatro funciones nuevas se fijan con `md5(regexp_replace(prosrc,'\s+','','g'))`; las pruebas de concurrencia de dos sesiones siguen pendientes de ejecución manual en un entorno desechable, nunca en producción.

**Consecuencias:** la protección no depende de la expiración del JWT ni de ocultar controles. No se mutan Auth, estado/categoría de cuenta, asignaciones, actividades, participantes o historia. Un conflicto se rechaza sin reparación automática ni evento persistente. Las filas de columna derivadas de grants autorizados de tabla no se confunden con grants explícitos. El delta previsto es cuatro funciones, un trigger, dos políticas, +7 grants de rutina, −3 grants directos de tabla y +4 ACL expandidas netas; no se introduce cliente `service_role`. La auditoría confirmada no se elimina para limpiar pruebas: las pruebas concurrentes que puedan confirmar correcciones descartan/restauran el entorno desechable completo. B.2b conserva activación/reactivación y Fase C conserva roles. A-02 continúa intencionalmente para administradores técnicos activos durante desarrollo.

**Ajuste de aplicación posterior:** el verificador transaccional final terminó con `ROLLBACK` y la corrección de identidad aprobó en producción. Un smoke test detectó que la página y las acciones de participantes recalculaban el alcance mediante el programa actual, en vez de consumir `can_edit_activity(uuid)`. La interfaz y sus Server Actions usan ahora esa decisión autoritativa para participantes/asistencia, manteniendo separadas `can_update_activity_base(uuid)` y `can_delete_activity(uuid)`. Así, una responsabilidad histórica registrada por UUID sobrevive a una corrección posterior de programa o identificador sin ampliar RLS ni ACL.

**Estado:** Aceptada e implementada; cierre canónico en DEC-050.

## DEC-050 — Cierre y reconciliación de Fase B.2a / migración 0008

**Contexto:** 0008 fue aplicada con `COMMIT` después de aprobar el preflight y publicar la aplicación compatible. El verificador final terminó con `ROLLBACK`; la corrección de identidad, la auditoría sanitizada y la regresión de responsable histórico entre programas aprobaron sus smoke tests. El snapshot completo `2026-07-22T01:46:13Z` fue generado con `pg_dump 18.4` y `psql 18.4` en modo de sólo lectura.

**Decisión:** cerrar Fase B.2a dentro de su alcance aprobado y fijar `0001`–`0008` como cadena aplicada, verificada, probada, reconciliada e inmutable. El snapshot confirma exactamente 18 tablas, 165 columnas, 80 restricciones, 43 índices, 11 triggers, 51 firmas de función, 25 políticas, RLS en las 18 tablas y 51 semillas controladas. Los privilegios son 132 grants de rutina, 267 de tabla, 6 de secuencia y 440 entradas ACL expandidas. La comparación contra post-0007 reproduce únicamente el delta de 0008 y no encuentra deriva inexplicada.

**Consecuencias:** la barrera de cuenta activa y la corrección auditada de identidad son contratos operativos vigentes. Las pruebas manuales de concurrencia en dos sesiones siguen reservadas a un entorno desechable y no se afirma que se hayan observado en producción; no bloquean este cierre porque el contrato transaccional y el verificador estático/funcional sí aprobaron. B.2b, B.3 y Fase C continúan pendientes. `0009` es el siguiente número disponible y cualquier cambio vivo posterior requiere una migración nueva.

**Estado:** Aceptada; Fase B.2a cerrada y reconciliada sin deriva inexplicada.

## DEC-051 — Transiciones administrativas de ciclo de vida B.2b

**Contexto:** una cuenta activa debe poder suspenderse operativamente y una cuenta inactiva válida debe poder reactivarse sin borrar identidad, asignaciones o historia. La operación exige autoridad B.1 exacta y debe resistir concurrencia con cambios de autoridad.

**Decisión:** preparar 0009 con contexto sin PII y una única RPC de transición auditada. Se prohíbe actuar sobre la cuenta propia, sobre registros pendientes o sobre la última autoridad B.1 exacta. La guarda de conteo de última autoridad se conserva como defensa en profundidad: bajo el contrato válido, un actor distinto con autoridad implica al menos dos administradores exactos activos, mientras el caso unitario es necesariamente propio y se rechaza antes. La mutación serializa la decisión, reautoriza al actor después de los locks y, al reactivar una cuenta institucional, bloquea con `FOR SHARE` el programa referenciado antes de validar y actualizar. El programa debe existir y continuar activo; una escritura concurrente se resuelve por espera y reevaluación, no por una lectura optimista. Las dependencias operativas se muestran como advertencias y se conservan. Las asignaciones no se reescriben: al reactivar, sólo recuperan efecto las que además continúen activas, vigentes por la fecha inclusiva de Ciudad de México y estructuralmente válidas; las vencidas, futuras, inactivas o malformadas no se reparan ni activan automáticamente.

**Consecuencias:** desactivar suspende el acceso por la barrera operativa existente aun si un JWT sigue técnicamente vigente, pero conserva identidad e historia y no revoca físicamente sesiones Supabase ni administra Auth. El preflight siempre presenta 19 bloqueos y 7 informativos, exige el conjunto canónico de 51 semillas y preserva exactamente los triggers Auth y los tres grants de actualización de nombres estructurados; ninguna columna de ciclo de vida queda editable por cliente. El verificador separa explícitamente fases cliente y owner, calcula la seguridad de dos administradores con respecto a la línea base viva y conserva sin mutar a toda autoridad preexistente. Las operaciones `auth.admin`, recuperación y bloqueo pertenecen a B.3; los roles V2 pertenecen a Fase C. Cada éxito genera evidencia administrativa append-only. 0009 permanece preparada, no aplicada ni reconciliada.

**Estado:** Aceptada para preparación local; pendiente de aplicación controlada.
