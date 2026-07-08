# Producto mínimo viable

## Objetivo

Validar un flujo completo para un periodo académico: configuración, planeación, actividad, participantes, asistencia, formulario dinámico y reporte.

## Incluido

### Configuración institucional

- Inicio de sesión con Supabase Auth.
- Perfiles de identidad estable con nombres, apellidos, correo, tipo de persona, identificador institucional y programa principal cuando aplique.
- Flujos diferenciados de registro o activación: alumnos con número de cuenta; trabajadores/profesores con número de trabajador.
- Asignación inicial de alumno automatizable; roles de trabajadores y profesores sujetos a autorización.
- El semestre no forma parte del perfil y solo se captura en contexto de actividad o formularios si existe acuerdo institucional.
- Asignaciones múltiples de rol con vigencia, alcance y área de servicio.
- Catálogos mínimos: periodos, divisiones, programas, grupos, categorías y tipos de servicio.

### Actividades y participantes

- Alta, edición, cancelación y cierre de actividades.
- Datos estructurados de actividad: nombre, categoría, servicio, fecha, horario, modalidad, lugar o enlace, responsable, programa y notas autorizadas.
- Participantes vinculados a perfiles registrados en SITAA; no se admiten participantes externos de texto libre como flujo normal.
- Registro/invitación de participantes separado del check-in de asistencia.
- Registro de asistencia con validación de identidad, prevención de duplicados y corrección manual obligatoria.
- Mecanismos futuros de acceso para registro y asistencia: QR, enlace directo y código corto de tres palabras; el QR no será el único método.

### Formularios dinámicos

- Creación de formularios por usuarios autorizados dentro de su alcance.
- Campos configurables, tipos de campo, orden y condición requerida u opcional.
- Versionado: una versión publicada no cambia las respuestas históricas asociadas.
- Respuestas vinculadas a usuario, actividad y versión del formulario.
- Ningún campo académico se impone desde el código. Solo son obligatorios los datos técnicos necesarios para integridad, como identificadores, marcas de tiempo, `created_by`, `activity_id` y `form_version_id`.

### Consulta y reportes

- Paneles básicos según asignaciones de rol.
- Tablas, resúmenes y gráficas.
- Filtros por actividad o evento, fecha, profesor o responsable, programa, tipo de servicio, categoría y campos configurados cuando sea técnicamente posible.
- Exportación CSV y generación de reportes PDF dentro del alcance autorizado.

## Fuera del MVP

- Almacenamiento o catálogo de carteles, fotografías, oficios, materiales y demás evidencia documental externa.
- Carpetas de Drive, enlaces de indicadores o metadatos para relacionar evidencias externas.
- Participantes externos capturados únicamente como texto libre.
- Aplicaciones móviles nativas e integraciones institucionales avanzadas.
- Analítica predictiva, recomendaciones automáticas o IA.
- Firma electrónica y reportes regulatorios avanzados.

## Flujo principal

1. Administración configura periodo, catálogos, perfiles y asignaciones.
2. Un responsable autorizado crea o selecciona una versión de formulario.
3. Se planea y programa una actividad.
4. Se agregan participantes registrados en SITAA.
5. Los participantes registran asistencia y responden los formularios aplicables.
6. El responsable cierra la actividad.
7. Un usuario autorizado consulta tablas, resúmenes o gráficas y exporta CSV o PDF.

## Criterios de aceptación globales

- RLS limita toda consulta y operación por asignación, alcance y área de servicio.
- Ninguna asistencia o participación válida carece de perfil SITAA.
- Una persona no puede registrar asistencia duplicada en la misma actividad.
- Las respuestas conservan la versión de formulario utilizada.
- La obligatoriedad académica se configura en el formulario y no se codifica globalmente.
- Los filtros y exportaciones respetan los mismos permisos que la vista de origen.
- Los flujos principales funcionan en una pantalla móvil.