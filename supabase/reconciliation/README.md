# Reconciliación de Supabase

Este directorio contiene snapshots usados para reconciliar la base de datos viva de Supabase con las migraciones versionadas del repositorio.

## Flujo remoto desde setup de Codex

Scripts disponibles:

```bash
bash scripts/pull-supabase-snapshot.sh
```

En Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pull-supabase-snapshot.ps1
```

El entorno de setup debe proporcionar la variable secreta:

```bash
SUPABASE_DB_URL=postgresql://...
```

Esa variable debe configurarse como secreto del entorno. No debe guardarse en `.env`, documentación, scripts, logs ni archivos del repositorio.

## Salidas esperadas

El script escribe en `supabase/reconciliation/live/`:

- `live_schema.sql`
- `live_functions.sql`, si `psql` está disponible
- `live_policies.sql`, si `psql` está disponible
- `live_snapshot_metadata.txt`

El script de PowerShell también genera, cuando `psql` está disponible:

- `live_tables.sql`
- `live_columns.sql`
- `live_constraints.sql`
- `live_indexes.sql`
- `live_triggers.sql`

Si Supabase CLI no está disponible, si `supabase db dump` no existe o si `psql` no está disponible para el flujo completo de Windows, el script falla claramente con instrucciones.

## Seguridad

El flujo es sólo de lectura y sirve para reconciliación. El script no ejecuta:

- `supabase db push`
- `supabase db reset`
- reparaciones automáticas del historial remoto de migraciones
- SQL destructivo contra Supabase

Las consultas auxiliares con `psql`, cuando están disponibles, se ejecutan dentro de transacciones `read only`.

## Uso de los snapshots

Los snapshots no son una migración por sí mismos. Se revisan para crear o actualizar archivos SQL en `supabase/migrations/`, que después deben revisarse antes de aplicarse manualmente en Supabase.