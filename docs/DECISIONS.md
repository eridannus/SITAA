# Registro de decisiones

Este archivo conserva decisiones de producto y arquitectura. Cada entrada debe indicar contexto, decisión, consecuencias y estado. No se eliminan decisiones reemplazadas; se marcan como sustituidas.

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
| DEC-005 | Estrategia de formularios configurables | Propuesta |

## DEC-001 — Plataforma web y stack base

**Contexto:** se requiere acceso desde equipos institucionales y teléfonos sin mantener aplicaciones nativas.

**Decisión:** usar Next.js con App Router, TypeScript y Tailwind CSS; desplegar en Vercel Free y mantener el código en GitHub con GitKraken como cliente visual opcional.

**Consecuencias:** habrá una sola aplicación web y se deberán vigilar los límites del plan gratuito. GitKraken no sustituye las reglas de ramas, revisiones o commits del repositorio.

**Estado:** Aceptada.

## DEC-002 — Supabase como backend administrado

**Contexto:** el proyecto necesita PostgreSQL, identidad, archivos y autorización con bajo costo operativo inicial.

**Decisión:** usar Supabase Free para PostgreSQL, Auth, Storage y RLS.

**Consecuencias:** el diseño dependerá de capacidades y límites de Supabase. Antes del piloto se evaluarán respaldo, recuperación, cuotas y necesidad de un plan superior.

**Estado:** Aceptada.

## DEC-003 — Autorización mediante RLS

**Contexto:** los datos deben aislarse por identidad, rol y asignación académica, incluso ante llamadas directas a la API.

**Decisión:** RLS será el límite principal de autorización. La interfaz y las acciones de servidor aplicarán controles adicionales, pero no sustituirán las políticas de base de datos.

**Consecuencias:** cada tabla expuesta requiere políticas y pruebas positivas y negativas por rol.

**Estado:** Aceptada.

## DEC-004 — Primera entrega limitada al MVP

**Contexto:** formularios generales, integraciones y reportes avanzados ampliarían considerablemente el riesgo y el tiempo de entrega.

**Decisión:** implementar primero el flujo descrito en `docs/MVP.md`; el constructor general de formularios queda fuera.

**Consecuencias:** los tipos de sesión podrán tener configuración acotada, sin convertirse todavía en un motor genérico.

**Estado:** Aceptada.

## DEC-005 — Estrategia de formularios configurables

**Contexto:** se prevén formularios configurables, pero aún no existen requisitos sobre reglas, versiones, permisos o reportes.

**Decisión propuesta:** versionar esquemas de formulario, conservar respuestas históricas contra su versión original y normalizar por separado los campos utilizados en permisos o indicadores.

**Consecuencias:** requiere definir un esquema permitido, validación en servidor, migraciones de plantillas y experiencia de administración antes de implementarse.

**Estado:** Propuesta.

## Plantilla para nuevas decisiones

### DEC-XXX — Título

**Contexto:** por qué se necesita decidir.

**Decisión:** qué se hará.

**Consecuencias:** beneficios, costos y riesgos.

**Estado:** Propuesta, Aceptada o Sustituida por DEC-XXX.
