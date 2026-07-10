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

**Decisión:** las actividades nuevas no pueden crearse con fecha pasada. Una actividad ocurrida bloquea sus datos base para responsables regulares; participantes, asistencia y notas de asistencia permanecen editables para usuarios autorizados. Las correcciones administrativas de datos base y la eliminación se determinan con funciones autorizadas de Supabase.

**Consecuencias:** la interfaz muestra resumen de solo lectura cuando los datos base están bloqueados y conserva la gestión de asistencia. La base de datos mantiene la autorización definitiva mediante RLS y funciones como `activity_has_ended`, `can_update_activity_base` y `can_delete_activity`.

**Estado:** Aceptada.

## DEC-024 — Flujo de borrador y publicación de actividades

**Contexto:** la planeación de una actividad puede requerir guardarse antes de quedar lista para participantes y asistencia. Además, publicar debe marcar un cambio claro de ciclo de vida y evitar bloqueos accidentales.

**Decisión:** las actividades pueden guardarse como borrador con `status_code = draft` o publicarse con `status_code = scheduled`. Guardar borrador solo exige título y programa; los demás campos operativos pueden quedar incompletos. Publicar exige todos los campos operativos, valida fecha y hora, y solo después de pasar validación muestra la confirmación de publicación. En la interfaz **Borrador** y **Programada** usan estilos visuales distintos.

**Consecuencias:** una actividad en borrador no se muestra como actividad asignada a alumnos y solo aparece en el panel de quien la creó. Los responsables regulares solo editan datos base mientras la actividad sea un borrador no ocurrido. Al confirmar la publicación, responsables regulares dejan de editar libremente datos base; las correcciones administrativas dependen de `can_update_activity_base`. Participantes y asistencia siguen siendo gestionables por usuarios autorizados. Las actividades nuevas publicadas no pueden crearse con fecha u hora de inicio pasada en tiempo de Ciudad de México.

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

**Decisión:** la asistencia puede abrirse desde 15 minutos antes del inicio de la actividad. Si se abre antes o durante la actividad, el acceso permanece válido hasta 15 minutos después del término. Después de concluida la actividad, un responsable o editor autorizado puede reabrir la asistencia manualmente por ventanas de 15 minutos. El responsable o editor puede cerrar la asistencia manualmente en cualquier momento. No se puede abrir asistencia en actividades en borrador ni en actividades sin fecha y hora completas.

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
