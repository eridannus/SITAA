# Reconciliación de Supabase

Este directorio contiene snapshots de sólo lectura usados para comparar la base de datos viva con las migraciones versionadas. Los snapshots son insumos de reconciliación y no deben ejecutarse directamente.

## Snapshot vivo completo

El conjunto generado el 16 de julio de 2026 contiene:

- `live_schema.sql`: esquema `public` obtenido con `pg_dump --schema-only --no-owner --no-privileges`.
- `live_tables.sql`: tablas, tipo de relación y estado RLS.
- `live_columns.sql`: tipos, UDT, nulabilidad, defaults y metadatos de longitud o precisión.
- `live_constraints.sql`: PK, FK, UNIQUE y CHECK con definición completa.
- `live_indexes.sql`: definiciones de `pg_indexes`, incluidos índices implícitos de constraints.
- `live_triggers.sql`: definiciones completas de triggers no internos.
- `live_functions.sql`: firmas, argumentos y definiciones completas.
- `live_policies.sql`: políticas RLS con modo, roles, comando, `USING` y `WITH CHECK`.
- `live_seed_catalogs.sql`: filas JSON de catálogos controlados.
- `live_snapshot_metadata.txt`: fecha UTC, versiones y estado de generación.

La validación de reconciliación confirmó 17 tablas, 151 columnas, 61 constraints, 37 índices, 4 triggers, 30 funciones, 23 políticas y 51 filas de semillas. No se encontraron inconsistencias entre el esquema principal y los snapshots especializados. Los índices de PK y UNIQUE se consideran representados por sus constraints aunque no aparezcan como sentencias `CREATE INDEX` independientes en el dump.

Los antiguos snapshots JSON de columnas, funciones y políticas quedan conservados como antecedente, pero fueron sustituidos como fuente autoritativa por este conjunto completo bajo `supabase/reconciliation/live/`.

## Flujo recomendado en Windows

Configura `SUPABASE_DB_URL` como secreto de la sesión y ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pull-supabase-snapshot.ps1
```

La resolución de herramientas sigue este orden:

1. `pg_dump` y `psql` nativos desde `PATH`.
2. `C:\Program Files\PostgreSQL\18\bin`.
3. Supabase CLI sólo como respaldo final cuando falta `pg_dump`; `psql` sigue siendo obligatorio para el conjunto completo.

Con las herramientas nativas disponibles no se evalúa ni invoca Supabase CLI. El script se guarda como UTF-8 con BOM para que Windows PowerShell 5.1 interprete correctamente los mensajes en español; los archivos SQL se generan directamente en UTF-8 sin transformaciones manuales.

## Semillas permitidas

`live_seed_catalogs.sql` se limita a:

- `roles`
- `divisions`
- `academic_programs`
- `academic_periods`
- `activity_types`
- `service_types`
- `attention_categories`
- `activity_modalities`
- `activity_statuses`
- `location_types`
- `participant_roles`

No se exportan usuarios, perfiles, asignaciones de rol, actividades, participantes, asistencia, tokens ni otros datos operativos o de prueba.

## Seguridad y manejo de fallos

- La URI sólo existe como secreto de entorno; no se imprime ni persiste.
- `psql` usa transacciones `read only` y el proceso establece PostgreSQL en modo de sólo lectura.
- Todos los archivos se generan primero en un directorio temporal.
- Si un comando falla, el temporal se elimina y no se publican archivos parciales.
- El flujo no aplica migraciones, no modifica la base viva y no repara historial remoto.

Después de generar un snapshot, se valida su integridad y se usa para preparar una migración numerada revisable. Aplicar SQL a Supabase permanece como un paso separado y manual.
