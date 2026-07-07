# Producto mínimo viable

## Objetivo del MVP

Validar un flujo completo para un periodo académico: configuración, planeación, ejecución de sesiones, asistencia, encuesta y reporte.

## Incluido

### Configuración

- Inicio de sesión con Supabase Auth.
- Perfiles institucionales y asignación de roles.
- Catálogos mínimos: periodos, programas académicos, grupos y tipos de sesión.
- Activación y cierre de un periodo académico.

### Operación

- Plan semestral de tutoría o asesoría por responsable y grupo.
- Alta, edición, cancelación y cierre de sesiones.
- Campos base de sesión: tipo, tema, objetivo, fecha, horario, modalidad, ubicación o enlace, responsable, grupo y notas.
- Generación de un QR temporal por sesión.
- Registro de asistencia con validación de identidad y prevención básica de duplicados.
- Captura de una encuesta breve de satisfacción posterior a la sesión.

### Consulta y reportes

- Panel de estudiante con próximas sesiones e historial propio.
- Panel de tutor o asesor con plan, sesiones y asistencia de sus grupos asignados.
- Panel de coordinación con avance del periodo e indicadores agregados.
- Panel administrativo para catálogos, usuarios y roles.
- Exportación CSV filtrada por periodo, programa, responsable, tipo y estado.
- Reportes básicos: sesiones planeadas/realizadas/canceladas, asistencia y satisfacción promedio.

## Fuera del MVP

- Constructor general de formularios y flujos de aprobación.
- Aplicaciones móviles nativas.
- Integración con sistemas escolares, SSO, correo o mensajería institucional.
- Analítica predictiva, recomendaciones automáticas o IA.
- Firma electrónica, constancias y reportes regulatorios avanzados.
- Operación multiinstitución y personalización visual por institución.

## Flujo principal

1. Administración configura periodo, catálogos, usuarios y asignaciones.
2. El tutor o asesor registra su plan semestral.
3. Crea o programa una sesión vinculada al plan.
4. Al iniciar, habilita un QR de vigencia corta.
5. El estudiante autenticado registra su asistencia.
6. El responsable cierra la sesión y confirma incidencias.
7. El estudiante responde la encuesta.
8. Coordinación consulta indicadores o exporta CSV.

## Criterios de aceptación globales

- No existen pantallas o consultas que evadan las políticas RLS.
- Un estudiante no puede registrar asistencia por otra persona ni duplicarla.
- Un tutor solo administra sesiones dentro de sus asignaciones vigentes.
- Los cambios de estado relevantes conservan autor, fecha y contexto.
- Los CSV respetan los mismos filtros y permisos que la vista de origen.
- Los flujos principales son utilizables desde una pantalla móvil.
