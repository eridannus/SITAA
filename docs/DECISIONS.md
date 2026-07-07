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
## Plantilla para nuevas decisiones

### DEC-XXX — Título

**Contexto:** por qué se necesita decidir.

**Decisión:** qué se hará.

**Consecuencias:** beneficios, costos y riesgos.

**Estado:** Propuesta, Aceptada o Sustituida por DEC-XXX.