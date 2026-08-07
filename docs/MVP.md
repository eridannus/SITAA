# Producto mínimo viable

## Objetivo

Poner SITAA en operación durante un semestre académico sustituyendo las listas en papel, Formularios de Google y hojas de cálculo manuales usados para registro y asistencia. El MVP operativo cubre identidad pública, semestre, actividades, participantes, asistencia, autoridad mínima, grupos, consulta autorizada, exportaciones y alertas académicas mínimas.

La secuencia canónica de entrega está en `MVP_OPERATIONAL_ROADMAP.md`.

## Incluido en el MVP operativo

### Identidad y acceso público

- Google OAuth público como gate de lanzamiento, con `openid`, `userinfo.email` y `userinfo.profile` exclusivamente.
- Flujos públicos diferenciados para alumnos y profesores, con identidad institucional completada después de Google.
- Cuentas técnicas internas separadas del registro público.
- Acceso por correo/contraseña sólo para cuentas heredadas.
- Perfiles activos y completos como requisito de operación; identidad no concede automáticamente tutoría, asesoría o gestión.
- Página pública de inicio/acerca de, política de privacidad, dominio verificado y configuración Google publicada para audiencia de producción.

### Configuración de semestre

- `academic_periods` representa semestres oficiales con código único y rango de fechas no traslapado.
- Sólo `technical_admin` exacto puede acceder al listado administrativo y crear, actualizar, activar o desactivar semestres en el MVP inmediato.
- Las lecturas autorizadas de periodos activos o históricos como referencia para actividades, filtros y reportes permanecen disponibles dentro del universo visible de quien consulta; leer un periodo no concede autoridad para administrarlo.
- Los semestres históricos referenciados no se eliminan destructivamente.
- Las actividades reciben el semestre automáticamente desde su fecha de inicio; usuarios operativos no lo eligen ni lo reescriben.
- La administración general de catálogos no forma parte de este alcance.

### Actividades, participantes y asistencia

- Alta, edición permitida, publicación, cancelación y consulta de actividades dentro del alcance autorizado.
- Datos estructurados: título, categoría, servicio, fecha, horario, semestre, modalidad, ubicación, responsable, programa y descripción opcional.
- Participantes vinculados a perfiles registrados; no hay participantes libres, anónimos o provisionales.
- Prerregistro por responsables autorizados y opción explícita de autorregistro durante check-in, deshabilitada por defecto.
- El autorregistro exige un perfil estudiantil SITAA completo y activo.
- QR, enlace directo y código de tres palabras usan el mismo contrato de check-in.
- Si la persona aún no participa y la actividad permite autorregistro, inserción de participante y confirmación de asistencia ocurren en una sola transacción.
- Check-in repetido idempotente, vencimiento controlado y corrección manual siempre disponible para autoridades autorizadas.

### Exportaciones operativas

- CSV UTF-8 con encabezados en español.
- PDF institucional imprimible con metadata de actividad, padrón y totales de asistencia.
- Vista, CSV y PDF derivan del mismo dataset autorizado.
- No se exportan UUID internos, tokens ni identificadores técnicos.
- CSV y PDF son salidas operativas centrales, no reportes avanzados.

### Roles y autoridad mínima

- Subconjunto inicial: `technical_admin`, `professor_tutor`, `professor_advisor`, `peer_tutor`, `program_tutoring_lead`, `program_advising_lead`, `program_coordinator`, `division_tutoring_liaison` y sólo otros roles que el piloto demuestre necesarios.
- `technical_admin` asigna inicialmente roles institucionales de alto nivel.
- `program_tutoring_lead` asigna o revoca `professor_tutor` y `peer_tutor` sólo en su programa.
- `program_advising_lead` asigna o revoca `professor_advisor` sólo en su programa.
- Las asignaciones conservan vigencia, alcance, revocación e historia; no hay autoasignación.

### Grupos de tutoría

- Los grupos se modelan fuera de `profiles`, por programa y semestre.
- Incluyen código, turno, semestre nominal, cohorte/generación, etiqueta y estado.
- `program_tutoring_lead` administra el ciclo de vida de los grupos únicamente dentro de su programa: puede crearlos, editar sus atributos administrativos y cerrarlos sin borrar historia.
- Puede agregar manualmente estudiantes SITAA existentes, moverlos entre grupos del mismo programa y periodo o finalizar sus membresías.
- Un alumno tiene como máximo un grupo actual por programa y periodo; un grupo tiene un tutor primario actual y un tutor puede atender varios grupos.
- El rol vigente `professor_tutor` del mismo programa se asigna antes del grupo; sólo entonces el lead puede asignar o transferir al tutor.
- La asignación de tutor referencia la asignación de rol habilitante; el rol no puede revocarse mientras grupos activos dependan de él.
- Membresías y tutores se cierran o revocan, no se borran.
- La búsqueda y los filtros cubren grupo, estudiante, tutor, periodo, turno, semestre nominal y cohorte/generación.
- La asignación masiva desde una selección filtrada materializa filas explícitas de grupo; no crea una regla dinámica permanente.
- El estudiante consulta su grupo actual y el contacto de tutor expresamente permitido; el tutor consulta sus grupos y padrones autorizados.
- La importación CSV sólo enlaza perfiles estudiantiles SITAA existentes y conserva una vista previa de identificadores no encontrados.

### Paneles y filtros

- Un dashboard adaptable se compone desde capacidades efectivas para alumno, profesor, tutor/asesor, leads, coordinación, enlace divisional y administración técnica.
- Filtros iniciales: semestre, programa, servicio, responsable, grupo, tutor, estado, tipo, categoría y rango de fechas.
- RLS/RPC construyen primero el universo visible; filtros, conteos, orden y paginación sólo lo reducen.
- Parámetros de consulta nunca conceden acceso.

### Alertas de riesgo

- Todo profesor activo puede registrar una alerta mínima sin requerir rol de tutor o asesor.
- Campos: nombre del alumno, programa, materia, categoría, grupo opcional, identificador opcional y vínculo opcional a perfil SITAA.
- Categorías cerradas: `absences`, `missing_work` y `socioemotional_attention`.
- Ausencias y trabajos pendientes se enrutan a leads de tutoría/asesoría y coordinación del programa; atención socioemocional, a enlace divisional y coordinación.
- Los destinatarios se fijan al crear la alerta.
- Estados: `new`, `acknowledged` y `archived`.
- El inbox interno con contadores es la entrega primaria.
- El rol técnico por sí solo no permite leer contenido de alerta; sólo diagnósticos sanitizados.
- SITAA registra y enruta señales: no diagnostica, gestiona casos ni almacena narrativa clínica.

## Formularios dinámicos: arquitectura conservada y ejecución diferida

La arquitectura de formularios dinámicos sigue aceptada para una etapa posterior al MVP operativo:

- creación por usuarios autorizados dentro de alcance;
- campos configurables, orden y obligatoriedad;
- versiones publicadas inmutables respecto de respuestas históricas;
- respuestas vinculadas a usuario, actividad y versión;
- requisitos académicos configurables, sin imponer campos desde código.

Esta capacidad no se abandona, pero no bloquea el piloto inicial porque registro y asistencia deben sustituir primero los procesos manuales actuales.

## Fuera del MVP operativo inmediato

- Constructor de formularios dinámicos y respuestas versionadas.
- B.3b completa y administración de cuentas técnicas adicionales.
- Transferencia y delegación general de roles; retiro de A-02.
- Paneles avanzados, gráficas y constructor configurable de reportes.
- Constancias, notificaciones generales e integraciones institucionales.
- Administración general de catálogos.
- Participantes anónimos, registro abierto sin asistencia y perfiles provisionales desde padrones.
- Reglas dinámicas permanentes de grupos.
- Evidencia documental externa, almacenamiento de archivos o carpetas institucionales.
- Analítica predictiva, recomendaciones automáticas o IA.

## Flujo principal

1. `technical_admin` configura el semestre oficial.
2. Una persona autorizada crea y publica una actividad.
3. El responsable prerregistra participantes o habilita autorregistro durante check-in.
4. La persona registrada confirma asistencia mediante QR, enlace o código.
5. Una autoridad autorizada corrige asistencia cuando procede.
6. Cada rol consulta su universo por semestre, programa, grupo y otros filtros permitidos.
7. El responsable o autoridad exporta el padrón autorizado como CSV o PDF.

En paralelo, cualquier profesor activo puede emitir una alerta mínima; SITAA fija destinatarios autorizados y la entrega en sus inboxes internos.

## Criterios de aceptación globales

- Google OAuth público funciona con cuentas no tester y scopes básicos exclusivamente.
- RLS y RPC limitan toda operación por cuenta activa, rol, alcance, servicio, programa y vigencia.
- Ninguna participación o asistencia válida carece de perfil SITAA elegible.
- Autorregistro y asistencia se confirman atómicamente e idempotentemente.
- La corrección manual de asistencia permanece disponible y auditada.
- Semestres no se traslapan y su historia referenciada no se destruye.
- Un tutor de grupo conserva un rol habilitante vigente y explícitamente referenciado.
- Vista, CSV y PDF comparten universo autorizado y totales consistentes.
- Alertas minimizan datos, fijan destinatarios y no exponen contenido por autoridad técnica.
- Flujos principales funcionan en móvil y cumplen el sistema visual, accesibilidad, privacidad, rendimiento y recuperación definidos para el piloto.
