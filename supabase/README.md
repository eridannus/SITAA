# Supabase en SITAA

Este directorio contiene la baseline reconciliada y el historial versionado de cambios de base de datos de SITAA.

## Baseline autoritativa

`supabase/migrations/0001_baseline_current_schema.sql` representa el esquema vivo capturado el 16 de julio de 2026 mediante `pg_dump` y consultas de sólo lectura con `psql`. Sustituye el intento anterior basado en snapshots JSON incompletos, que nunca fue aplicado como migración administrada.

La baseline incluye tablas, columnas, llaves y demás constraints, índices, triggers, funciones, configuración RLS, políticas y semillas de catálogos controlados. Está destinada a instalaciones nuevas. No debe ejecutarse a ciegas contra la base actual de producción/prototipo porque ese entorno ya contiene los objetos y datos por cambios manuales históricos.

El dump se obtuvo con `--no-privileges`; por ello, los grants administrados por Supabase no pudieron reconstruirse desde los artefactos disponibles y están señalados como TODO verificable en la baseline.

## Historial futuro

Después de esta reconciliación:

- `0001_baseline_current_schema.sql` no se reescribe, excepto para corregir un defecto comprobado de la baseline.
- El siguiente cambio usa `0002_short_description.sql`, después `0003_short_description.sql` y así sucesivamente.
- Una migración se crea antes o junto con cualquier SQL aplicado a Supabase.
- Si el SQL se aplica manualmente desde Supabase SQL Editor, el mismo archivo debe quedar comprometido en Git.
- Los cambios de modelo, permisos o arquitectura también actualizan la documentación correspondiente.

## Generación de snapshots

En Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pull-supabase-snapshot.ps1
```

El entorno proporciona `SUPABASE_DB_URL` como secreto. El script prefiere `pg_dump` y `psql` nativos, genera todos los archivos en un directorio temporal y sólo publica el conjunto completo cuando termina correctamente. No imprime ni guarda la URI y no ejecuta escrituras remotas.

Los resultados se almacenan en `supabase/reconciliation/live/`. Son artefactos para comparar el estado vivo y construir migraciones; no son migraciones para ejecutar directamente.

## Reglas de seguridad

- No incluir secretos, llaves `service_role`, tokens ni datos personales u operativos reales.
- No ejecutar la baseline contra la base viva actual.
- No crear cambios destructivos sin revisión explícita y respaldo adecuado.
- No reparar historial remoto ni aplicar migraciones automáticamente desde el flujo de snapshots.
