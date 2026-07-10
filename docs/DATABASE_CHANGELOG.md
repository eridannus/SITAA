# Historial de cambios de base de datos

Los cambios SQL anteriores a la migración baseline fueron aplicados manualmente durante el prototipo.

## Baseline pendiente

El siguiente paso es capturar el estado actual de Supabase en una migración baseline:

- `supabase/migrations/0001_baseline_current_schema.sql`

Esa migración debe generarse o redactarse a partir del esquema vivo verificado, no desde memoria ni desde inferencias parciales. Debe reconciliar tablas, vistas o RPC, funciones, políticas RLS, índices, triggers, catálogos mínimos y cualquier objeto necesario para reproducir el estado actual de SITAA.

Hasta completar la baseline, este changelog sólo documenta que el historial previo existe fuera del repositorio y debe reconciliarse.

## Cambios posteriores

Después de la baseline, cada cambio de base de datos debe registrarse con una migración numerada y una nota breve en este archivo.

Formato sugerido:

### 0002_short_description.sql

- Fecha:
- Propósito:
- Objetos afectados:
- Aplicado en Supabase:
- Observaciones:
