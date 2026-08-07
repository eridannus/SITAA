# Hoja de ruta

## Plan canónico vigente

La ejecución inmediata se rige por `MVP_OPERATIONAL_ROADMAP.md`. Sus paquetes canónicos son:

1. `DOC-00`: completado.
2. `AUTH-01`: completado; gate de lanzamiento de OAuth público satisfecho.
3. `SEM-01`: siguiente paquete estructural; kickoff pendiente.
4. `ATT-01`: registro y asistencia atómicos, pendiente.
5. `EXP-01`: exportaciones CSV y PDF, pendiente.
6. `ROLE-01`: roles y autoridad mínima del piloto, pendiente.
7. `GRP-01`: grupos, membresías y tutores, pendiente.
8. `DASH-01`: dashboard por capacidades y filtros autorizados, pendiente.
9. `ALERT-01`: alertas de riesgo e inboxes, pendiente.
10. `PILOT-01`: preparación y decisión go/no-go, pendiente.

`DOC-00` y `AUTH-01` están completados. `SEM-01` es el siguiente paquete estructural y su kickoff permanece pendiente. `0011` continúa sin asignarse y no existe; sólo podrá asignarse después de revisar y aprobar el diseño estructural correspondiente. La ejecución canónica se mantiene en `MVP_OPERATIONAL_ROADMAP.md`.

## Secuencia histórica supersedida

Las fases siguientes se conservan como contexto de planeación inicial. Ya no definen el orden de ejecución próximo, los gates del piloto ni la prioridad del MVP operativo.

Las fechas se definirán después de validar responsables y capacidad. Cada paquete vigente termina con evidencia verificable antes de avanzar.

## Fase 0 — Definición

- Validar alcance del MVP, roles y flujos institucionales.
- Resolver pendientes del modelo de datos y privacidad.
- Elaborar bocetos de los flujos principales.
- Definir indicadores y datos mínimos para reportes.

**Salida:** documentación aprobada y decisiones críticas registradas.

## Fase 1 — Fundamentos técnicos

- Inicializar Next.js, TypeScript y Tailwind CSS.
- Configurar entornos de Supabase y Vercel.
- Crear esquema, migraciones, datos ficticios y políticas RLS.
- Implementar autenticación, perfiles, roles y estructura de navegación.

**Salida:** acceso seguro y panel base por rol.

## Fase 2 — Planeación y sesiones

- Implementar periodos, programas, grupos y asignaciones.
- Crear planes semestrales y actividades previstas.
- Implementar ciclo de vida de sesiones y panel del tutor.

**Salida:** una sesión puede planearse, programarse y cerrarse.

## Fase 3 — Asistencia y encuestas

- Generar y validar QR temporal.
- Registrar, consultar y corregir asistencia con auditoría.
- Implementar encuesta versionada y resultados agregados.

**Salida:** flujo móvil completo de participación y evaluación.

## Fase 4 — Coordinación y reportes

- Crear panel de seguimiento institucional.
- Añadir filtros, indicadores básicos y exportación CSV segura.
- Validar consistencia entre agregados y registros fuente.

**Salida:** coordinación puede dar seguimiento a un periodo y exportar evidencia.

## Fase 5 — Piloto

- Ejecutar pruebas funcionales, accesibilidad, RLS, rendimiento y recuperación.
- Capacitar a un grupo controlado y recopilar incidencias.
- Ajustar experiencia, políticas y documentación operativa.

**Salida:** decisión informada de lanzamiento o nueva iteración.

## Después del MVP

- Formularios configurables y flujos de aprobación.
- Integraciones institucionales y notificaciones.
- Reportes avanzados, constancias y automatizaciones.
- Evaluación de escalabilidad y migración de planes gratuitos cuando el uso lo requiera.
