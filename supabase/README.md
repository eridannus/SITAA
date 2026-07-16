# Supabase en SITAA

Este directorio concentra el historial de cambios de base de datos de SITAA.

## Regla principal

Todo cambio futuro en la base de datos debe registrarse como archivo SQL de migración dentro de `supabase/migrations/`. Durante el prototipo, una migración puede aplicarse manualmente desde el SQL Editor de Supabase, pero su archivo SQL debe conservarse en Git aunque ya haya sido ejecutado.

## Convención de nombres

Usar nombres consecutivos, breves y descriptivos:

- `0001_baseline_current_schema.sql`
- `0002_short_description.sql`
- `0003_short_description.sql`

El número indica el orden de aplicación. La descripción usa minúsculas, guiones bajos y una frase técnica corta y consistente.

## Baseline reconciliada

La migración `supabase/migrations/0001_baseline_current_schema.sql` fue generada desde los snapshots disponibles en `supabase/reconciliation/`. Representa el estado conocido del proyecto vivo al momento de la reconciliación y conserva TODOs explícitos para objetos que todavía requieren verificación.

La baseline debe revisarse antes de ejecutarse en cualquier entorno. Su objetivo es fijar un punto de partida verificable para que los cambios posteriores queden versionados en el repositorio.

## Snapshots remotos

En Windows, el flujo recomendado es:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pull-supabase-snapshot.ps1
```

El entorno debe proporcionar `SUPABASE_DB_URL` como secreto. El valor se usa sólo durante la ejecución: no se imprime, no se incluye en metadatos y no debe guardarse en archivos ni comprometerse en Git.

El script prefiere `pg_dump` y `psql` nativos desde `PATH`; después busca PostgreSQL 18 en `C:\Program Files\PostgreSQL\18\bin`. Con esas herramientas no usa Supabase CLI y no requiere Docker. Supabase CLI queda únicamente como respaldo final del dump de esquema cuando `pg_dump` no está disponible; `psql` sigue siendo necesario para generar las consultas de reconciliación.

Las salidas se escriben en `supabase/reconciliation/live/` e incluyen el esquema `public`, tablas, columnas, restricciones, índices, triggers, funciones, políticas y datos de catálogos controlados. No se exportan datos personales ni operativos. Consulta `supabase/reconciliation/README.md` para el detalle y las garantías ante fallos.

Los snapshots son artefactos de reconciliación, no migraciones ejecutables. Sirven para construir o revisar migraciones versionadas; aplicar cambios a Supabase permanece como un paso manual y revisado.

## Reglas de seguridad

- No incluir secretos, llaves `service_role`, tokens ni datos personales reales.
- No crear migraciones destructivas sin revisión explícita.
- No depender sólo de cambios manuales: el repositorio debe ser la fuente de verdad.
- Revisar cada migración y actualizar la documentación del modelo o las decisiones cuando corresponda.
