# Registro de decisiones

Este archivo conserva decisiones de producto y arquitectura. No se eliminan decisiones reemplazadas; se marcan como sustituidas.

## Estados

- **Propuesta:** requiere validaciÃ³n.
- **Aceptada:** guÃ­a la implementaciÃ³n.
- **Sustituida:** otra decisiÃ³n la reemplazÃ³.

## Ãndice

| ID | DecisiÃ³n | Estado |
| --- | --- | --- |
| DEC-001 | Plataforma web y stack base | Aceptada |
| DEC-002 | Supabase como backend administrado | Aceptada |
| DEC-003 | AutorizaciÃ³n mediante RLS | Aceptada |
| DEC-004 | Primera entrega limitada al MVP | Aceptada |
| DEC-005 | Formularios dinÃ¡micos versionados | Aceptada |
| DEC-006 | Roles mediante asignaciones mÃºltiples y acotadas | Aceptada |
| DEC-007 | Evidencia interna y participantes registrados | Aceptada |
| DEC-008 | CatÃ¡logos operativos controlados | Aceptada |
| DEC-009 | Perfil de identidad estable | Aceptada |
| DEC-010 | Listas de asistencia con identidad institucional | Aceptada |
| DEC-011 | Programa acadÃ©mico obligatorio | Aceptada |
| DEC-012 | Actividades como nÃºcleo operativo | Aceptada |
| DEC-013 | Fecha, hora y duraciÃ³n de actividades | Aceptada |
| DEC-014 | ValidaciÃ³n, ediciÃ³n y eliminaciÃ³n de actividades base | Aceptada |
| DEC-015 | Alcance de actividades por programa o divisiÃ³n | Aceptada |
| DEC-016 | SelecciÃ³n de alcance consciente de permisos | Aceptada |
| DEC-017 | Participantes registrados por actividad | Aceptada |
| DEC-018 | Alcance programÃ¡tico exclusivo durante el MVP | Aceptada |
| DEC-019 | Privacidad del padrón de participantes | Aceptada |

## DEC-001 â€” Plataforma web y stack base

**DecisiÃ³n:** usar Next.js con App Router, TypeScript y Tailwind CSS; desplegar en Vercel Free y mantener el cÃ³digo en GitHub.

**Consecuencias:** habrÃ¡ una aplicaciÃ³n web Ãºnica y se vigilarÃ¡n los lÃ­mites de los planes gratuitos.

**Estado:** Aceptada.

## DEC-002 â€” Supabase como backend administrado

**DecisiÃ³n:** usar Supabase Free para PostgreSQL, Auth y RLS.

**Consecuencias:** antes del piloto se evaluarÃ¡n respaldo, recuperaciÃ³n y cuotas. Storage no se utilizarÃ¡ para evidencia documental externa.

**Estado:** Aceptada.

## DEC-003 â€” AutorizaciÃ³n mediante RLS

**DecisiÃ³n:** RLS serÃ¡ el lÃ­mite principal de autorizaciÃ³n por identidad, asignaciÃ³n, vigencia, alcance y Ã¡rea de servicio.

**Consecuencias:** cada tabla expuesta requiere pruebas positivas y negativas para las combinaciones autorizadas.

**Estado:** Aceptada.

## DEC-004 â€” Primera entrega limitada al MVP

**DecisiÃ³n:** el MVP incluye actividades, participantes registrados, asistencia, formularios dinÃ¡micos bÃ¡sicos y reportes CSV/PDF. Se excluyen integraciones avanzadas y evidencia documental externa.

**Consecuencias:** el constructor configura campos y versiones, pero no es todavÃ­a un motor general de procesos.

**Estado:** Aceptada.

## DEC-005 â€” Formularios dinÃ¡micos versionados

**Contexto:** los campos acadÃ©micos y su obligatoriedad cambian por programa, servicio y acuerdos colegiados.

**DecisiÃ³n:** permitir a usuarios autorizados crear campos, elegir tipos, ordenarlos y marcarlos como requeridos u opcionales. Cada respuesta conserva `form_version_id`. Solo los identificadores, marcas de tiempo, creador y referencias tÃ©cnicas indispensables son obligatorios por diseÃ±o.

**Consecuencias:** ninguna lista global de campos acadÃ©micos obligatorios se codifica en la aplicaciÃ³n. Los responsables editan dentro de su Ã¡mbito; la jefatura participa solo en aprobaciÃ³n o supervisiÃ³n configurada; el administrador tÃ©cnico brinda soporte sin decidir contenido.

**Estado:** Aceptada.

## DEC-006 â€” Roles mediante asignaciones mÃºltiples y acotadas

**DecisiÃ³n:** usar un catÃ¡logo de roles y asignaciones independientes con usuario, rol, vigencia, alcance y Ã¡rea de servicio. `profiles` no almacena un rol fijo.

**Consecuencias:** la autorizaciÃ³n evalÃºa todas las asignaciones vigentes sin mezclar alcances y conserva el historial.

**Estado:** Aceptada.

## DEC-007 â€” Evidencia interna y participantes registrados

**Contexto:** gestionar archivos y enlaces de evidencia externa duplicarÃ­a procesos institucionales. Las listas de participaciÃ³n requieren identidades verificables.

**DecisiÃ³n:** SITAA produce evidencia interna estructurada mediante actividades, participantes, asistencia, respuestas, resÃºmenes y exportaciones. No administra carteles, fotos, oficios, materiales, carpetas de Drive ni enlaces de indicadores. Todo participante referencia un perfil SITAA con identificadores institucionales cuando apliquen.

**Consecuencias:** no existirÃ¡n entidades como `activity_evidence` o `evidence_indicator_links`, ni participantes externos de texto libre como flujo normal. Una persona no registrada no puede integrarse correctamente en la lista de asistencia.

**Estado:** Aceptada.

## DEC-008 â€” CatÃ¡logos operativos controlados

**Contexto:** actividades, formularios y reportes necesitan vocabularios estables para evitar variantes libres y resultados inconsistentes.

**DecisiÃ³n:** utilizar catÃ¡logos activos para periodos acadÃ©micos, tipos de actividad y servicio, categorÃ­as de atenciÃ³n, modalidades, estados, ubicaciones y roles de participante antes de implementar actividades.

**Consecuencias:** la operaciÃ³n referencia cÃ³digos controlados y solo expone valores activos. La primera interfaz es de consulta; la ediciÃ³n y sus permisos se definirÃ¡n posteriormente.

**Estado:** Aceptada.
## DEC-009 â€” Perfil de identidad estable

**Contexto:** el semestre y las responsabilidades institucionales cambian con el tiempo; almacenarlos como atributos actuales del perfil producirÃ­a datos ambiguos o sobrescritos.

**DecisiÃ³n:** `profiles` conserva nombres, apellidos, nombre completo, correo, tipo de persona, tipo y valor de identificador institucional y programa principal. Alumnos usan nÃºmero de cuenta; trabajadores y profesores, nÃºmero de trabajador. El semestre se captura Ãºnicamente en el contexto de una actividad, participaciÃ³n o formulario cuando se requiera. Los roles permanecen en `role_assignments`.

**Consecuencias:** los flujos de registro de alumnos y trabajadores serÃ¡n distintos. La asignaciÃ³n inicial de alumno puede automatizarse; los roles de trabajadores y profesores requieren autorizaciÃ³n. Cambiar responsabilidades no modifica la identidad base.

**Estado:** Aceptada.
## DEC-010 â€” Listas de asistencia con identidad institucional

**DecisiÃ³n:** las listas de asistencia se generarÃ¡n exclusivamente a partir de perfiles registrados en SITAA y mostrarÃ¡n el identificador institucional que corresponda: nÃºmero de cuenta para alumnos o nÃºmero de trabajador para personal.

**Consecuencias:** no se usarÃ¡n nombres libres como participantes vÃ¡lidos. Los cambios de identidad se reflejan desde el perfil, mientras los roles permanecen separados en `role_assignments`.

**Estado:** Aceptada.
## DEC-011 â€” Programa acadÃ©mico obligatorio

**DecisiÃ³n:** todo perfil registrado o actualizado debe tener `primary_program_id`. El programa se selecciona de `academic_programs` entre los valores disponibles. Solo perfiles bootstrap o de prueba pueden conservar temporalmente `null` mientras completan su configuraciÃ³n.

**Consecuencias:** el formulario impide guardar sin programa y el dashboard advierte cuando falta. El programa es informaciÃ³n de afiliaciÃ³n y no concede roles ni permisos por sÃ­ mismo.

**Estado:** Aceptada.
## DEC-012 â€” Actividades como nÃºcleo operativo

**DecisiÃ³n:** SITAA modela tutorÃ­as, asesorÃ­as, tutorÃ­as pares, actividades remediales y acompaÃ±amientos como `activities`, no Ãºnicamente como sesiones. Cada actividad referencia catÃ¡logos controlados, un programa, una persona responsable y quien la creÃ³.

**Consecuencias:** participantes, asistencia, QR, formularios y reportes se incorporarÃ¡n posteriormente alrededor de la actividad. Las nuevas actividades requieren inicio y se crean con estado `scheduled`.

**Estado:** Aceptada.
## DEC-013 â€” Fecha, hora y duraciÃ³n de actividades

**DecisiÃ³n:** toda actividad requiere fecha y hora de inicio en formato de 24 horas. La duraciÃ³n usa `one_hour`, `two_hours` o `custom`; las dos primeras calculan el tÃ©rmino y la personalizada exige fecha y hora finales. El periodo acadÃ©mico se asigna automÃ¡ticamente desde el Ãºnico periodo activo.

**Consecuencias:** `activities` conserva fecha y hora en campos separados y tambiÃ©n completa `starts_at`/`ends_at` por compatibilidad. La validaciÃ³n usa la fecha actual de Ciudad de MÃ©xico y no permite inicios pasados ni tÃ©rminos anteriores al inicio.

**Estado:** Aceptada.

## DEC-014 â€” ValidaciÃ³n, ediciÃ³n y eliminaciÃ³n de actividades base

**DecisiÃ³n:** todos los campos operativos de una actividad son obligatorios salvo description. Las fechas se muestran como DD/MM/YYYY y las horas en formato de 24 horas. El mÃ³dulo base permite editar y eliminar actividades, siempre sujeto a autenticaciÃ³n, confirmaciÃ³n explÃ­cita para eliminar y polÃ­ticas RLS.

**Consecuencias:** creaciÃ³n y ediciÃ³n comparten validaciÃ³n y conservan los valores rechazados. El periodo se obtiene del Ãºnico periodo activo; responsible_profile_id y created_by no cambian al editar. La opciÃ³n Â«Ambos programasÂ» queda pendiente: requerirÃ¡ un modelo posterior de alcance de actividad para que division_tutoring_liaison pueda seleccionar DiseÃ±o GrÃ¡fico, Arquitectura o ambos sin debilitar permisos.

**Estado:** Aceptada.


## DEC-015 â€” Alcance de actividades por programa o divisiÃ³n

**DecisiÃ³n:** una actividad tiene alcance program o division. El alcance program referencia un programa y su divisiÃ³n; el alcance division no referencia programa y representa Â«Ambos programasÂ» para la DivisiÃ³n de DiseÃ±o y EdificaciÃ³n.

**Consecuencias:** las opciones dependen de asignaciones activas, programa, divisiÃ³n y Ã¡rea de servicio. La interfaz limita selecciones, la acciÃ³n del servidor valida nuevamente y RLS sigue siendo el lÃ­mite definitivo.

**Estado:** Aceptada.


## DEC-016 â€” SelecciÃ³n de alcance consciente de permisos

**DecisiÃ³n:** los selectores de alcance y programa solo se muestran cuando el usuario tiene mÃ¡s de una opciÃ³n vÃ¡lida. Una combinaciÃ³n Ãºnica se presenta como informaciÃ³n de solo lectura y se impone nuevamente en el servidor.

**Consecuencias:** profesores, tutores pares y responsables con un Ãºnico programa no realizan selecciones redundantes. Alumnos sin rol operativo no ven la acciÃ³n de alta; los roles divisionales y tÃ©cnicos conservan las opciones amplias autorizadas.

**Estado:** Aceptada.


## DEC-017 â€” Participantes registrados por actividad

**DecisiÃ³n:** cada participante de una actividad referencia un perfil SITAA y un rol del catÃ¡logo participant_roles. La bÃºsqueda se realiza por nombre, correo o identificador institucional mediante la funciÃ³n autorizada de Supabase; no se admiten personas de texto libre ni duplicados por actividad.

**Consecuencias:** los editores autorizados agregan o retiran participantes bajo RLS. Ser participante concede visibilidad de la actividad conforme a las polÃ­ticas de lectura, pero no permisos de ediciÃ³n ni asistencia automÃ¡tica.

**Estado:** Aceptada.


## DEC-018 â€” Alcance programÃ¡tico exclusivo durante el MVP

**DecisiÃ³n:** durante el MVP, toda actividad creada o editada pertenece a un Ãºnico programa: DiseÃ±o GrÃ¡fico o Arquitectura. El alcance division permanece en el esquema como capacidad reservada, pero Â«Ambos programasÂ» no se expone en la interfaz ni se acepta en las acciones operativas del MVP.

**Consecuencias:** division_tutoring_liaison y technical_admin eligen uno de los programas permitidos. La bÃºsqueda y el alta de participantes exigen coincidencia entre el programa principal del perfil y el programa de la actividad.

**Estado:** Aceptada.


## DEC-019 — Privacidad del padrón de participantes

**Decisión:** los alumnos con rol exclusivamente `student` consultan únicamente el resumen de las actividades donde participan y su propia condición de participación. El padrón completo de participantes se reserva para usuarios autorizados a gestionar la actividad.

**Consecuencias:** la interfaz no invoca funciones de listado de participantes para alumnos y no muestra errores de permisos derivados de esa restricción. RLS y RPC mantienen la autorización definitiva; ser participante no concede visibilidad sobre otros participantes.

**Estado:** Aceptada.
## Plantilla para nuevas decisiones

### DEC-XXX â€” TÃ­tulo

**Contexto:** por quÃ© se necesita decidir.

**DecisiÃ³n:** quÃ© se harÃ¡.

**Consecuencias:** beneficios, costos y riesgos.

**Estado:** Propuesta, Aceptada o Sustituida por DEC-XXX.
