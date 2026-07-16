# Reconciliación de Supabase

Este directorio contiene snapshots usados para comparar la base de datos viva de Supabase con las migraciones versionadas del repositorio. Son artefactos de reconciliación: no son migraciones y no deben ejecutarse directamente.

## Flujo recomendado en Windows

Configura `SUPABASE_DB_URL` como secreto de la sesión de PowerShell y ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pull-supabase-snapshot.ps1
```

El script busca las herramientas en este orden:

1. `pg_dump` y `psql` nativos disponibles en `PATH`.
2. `C:\Program Files\PostgreSQL\18\bin`.
3. Supabase CLI únicamente como respaldo final para el dump de esquema si `pg_dump` no existe.

Cuando `pg_dump` y `psql` están disponibles, Supabase CLI no se invoca y Docker no es necesario. `psql` sí es obligatorio para producir el conjunto completo de snapshots.

## Flujo alternativo en Bash

Se conserva el script existente para entornos compatibles:

```bash
bash scripts/pull-supabase-snapshot.sh
```

## Salidas

El flujo de Windows genera en `supabase/reconciliation/live/`:

- `live_schema.sql`: esquema `public` obtenido con `pg_dump --schema-only`, sin propietarios ni privilegios.
- `live_tables.sql`: tablas, tipo de relación y estado de RLS.
- `live_columns.sql`: tipos, UDT, nulabilidad, valores predeterminados y metadatos de longitud o precisión.
- `live_constraints.sql`: llaves primarias y foráneas, restricciones únicas y checks.
- `live_indexes.sql`: definiciones completas de índices.
- `live_triggers.sql`: definiciones de triggers no internos.
- `live_functions.sql`: firmas, argumentos y definiciones completas de funciones y procedimientos.
- `live_policies.sql`: políticas RLS con roles, comando, `USING` y `WITH CHECK`.
- `live_seed_catalogs.sql`: filas JSON de los catálogos controlados conocidos que existan.
- `live_snapshot_metadata.txt`: fecha UTC, versiones de herramientas y estado del proceso.

El snapshot de semillas se limita a `roles`, `divisions`, `academic_programs`, `academic_periods`, `activity_types`, `service_types`, `attention_categories`, `activity_modalities`, `activity_statuses`, `location_types` y `participant_roles`. No exporta usuarios, perfiles, asignaciones de roles, actividades, participantes, tokens ni datos operativos o de prueba.

## Seguridad y fallos

- `SUPABASE_DB_URL` debe existir sólo como secreto de entorno; el script no la imprime ni la guarda.
- `pg_dump` opera únicamente sobre el esquema `public` y `psql` usa transacciones `read only`.
- También se configura PostgreSQL en modo de transacción predeterminado de sólo lectura durante la ejecución.
- Todos los artefactos se generan primero en un directorio temporal. Sólo reemplazan las salidas vivas cuando el conjunto completo termina correctamente.
- Si algo falla, el temporal se elimina, las salidas parciales no se publican y los metadatos registran `FAILURE` sin credenciales.
- El flujo no aplica migraciones, no repara historial remoto y no realiza escrituras en Supabase.

Después de generar los snapshots, revísalos y úsalos para construir o actualizar archivos versionados bajo `supabase/migrations/`. Aplicar migraciones permanece como un paso manual y revisado.
