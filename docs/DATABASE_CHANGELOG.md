# Historial de cambios de base de datos

Los cambios SQL anteriores a la baseline fueron aplicados manualmente durante el prototipo.

## 0001_baseline_current_schema.sql — baseline reconciliada

- Fecha: 2026-07-16.
- Propósito: capturar el estado vivo completo de Supabase y establecer el punto de partida para instalaciones nuevas y migraciones futuras.
- Fuentes: los 10 archivos bajo `supabase/reconciliation/live/`, generados mediante `pg_dump 18.4` y `psql 18.4` en modo de sólo lectura.
- Objetos: 17 tablas, 151 columnas, 61 constraints, 37 índices, 4 triggers, 30 funciones, RLS para 17 tablas, 23 políticas y 51 filas de semillas controladas.
- Aplicado en Supabase desde el repositorio: no. El estado ya existe por cambios manuales del prototipo.
- Seguridad: la baseline no debe ejecutarse a ciegas contra la base viva actual.
- Pendiente verificable: grants, porque el dump fue generado con `--no-privileges` y no existe un snapshot especializado de privilegios.

Esta versión sustituye completamente el intento anterior de `0001`, construido desde snapshots JSON incompletos. La versión anterior nunca fue aplicada como migración administrada y ya no es autoritativa.

## Regla para cambios posteriores

`0001` queda fija después de esta reconciliación y sólo puede corregirse ante un defecto comprobado de la baseline. Todo cambio nuevo se registra de forma incremental:

- `0002_short_description.sql`
- `0003_short_description.sql`
- y así sucesivamente.

La migración debe crearse antes o junto con el SQL aplicado a Supabase. Si se ejecuta manualmente en Supabase SQL Editor, el archivo versionado y esta bitácora se actualizan en el mismo cambio.

Formato para nuevas entradas:

### 0002_short_description.sql

- Fecha:
- Propósito:
- Objetos afectados:
- Aplicado en Supabase:
- Observaciones:

## Flujo de snapshots

En Windows se usa:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pull-supabase-snapshot.ps1
```

El flujo no aplica cambios remotos. Genera artefactos de reconciliación en `supabase/reconciliation/live/`, que deben validarse antes de preparar una migración.
