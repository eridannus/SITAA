# Supabase en SITAA

Este directorio contiene la baseline reconciliada y el historial versionado de cambios de base de datos de SITAA.

## Baseline autoritativa

`supabase/migrations/0001_baseline_current_schema.sql` representa el esquema vivo capturado el 16 de julio de 2026 mediante `pg_dump` y consultas de sólo lectura con `psql`. Sustituye el intento anterior basado en snapshots JSON incompletos, que nunca fue aplicado como migración administrada.

La baseline incluye tablas, columnas, llaves y demás constraints, índices, triggers, funciones, configuración RLS, políticas y semillas de catálogos controlados. Está destinada a instalaciones nuevas. No debe ejecutarse a ciegas contra la base actual de producción/prototipo porque ese entorno ya contiene los objetos y datos por cambios manuales históricos.

El dump se obtuvo con `--no-privileges`, pero los grants y ACL vivos se capturan por separado en los cuatro artefactos especializados de reconciliación. La baseline conserva la estructura histórica y 0002 materializa el contrato mínimo de privilegios verificado.

## Estado de la cadena

- `0001_baseline_current_schema.sql`: baseline reconciliada.
- `0002_database_security_and_integrity.sql`: aplicada y verificada en Supabase el 2026-07-16.
- `0003_fix_draft_temporal_lifecycle.sql`: aplicada y verificada en Supabase el 2026-07-16.
- `0004_identity_registration_foundation.sql`: aplicada y verificada; introduce Google OAuth y finalización institucional autenticada, sin intents.
- `0005_fix_google_oauth_user_creation.sql`: aplicada y verificada; corrige la secuencia temprana de `email_confirmed_at` y endurece la verificación final.
- `0006_structured_person_names.sql`: aplicada y verificada; formaliza nombres estructurados y conserva `full_name` derivado.
- Snapshot posterior: `2026-07-18T04:05:40Z`, reconciliado contra 0001–0006 sin deriva inexplicada.
- Siguiente número disponible: `0007`; este cierre no lo crea.

## Cierre de 0005

El preflight, la aplicación manual, el verificador transaccional y los smoke tests de Google fueron aprobados. El verificador terminó con `ROLLBACK` y retiró sólo fixtures sintéticos. El informe `reconciliation/0005_post_apply_reconciliation.md` documenta el snapshot posterior, la ausencia de deriva y la separación administrativa inicial de cuentas sin PII.

El rollback de 0005 es exclusivamente de emergencia: no transforma datos, pero reintroduce el defecto prematuro de 0004. Nunca borra Auth users, profiles ni identidades Google.

## Historial futuro

Después de esta reconciliación:

- `0001_baseline_current_schema.sql` no se reescribe, excepto para corregir un defecto comprobado de la baseline.
- `0001`–`0006` no se reescriben, salvo para corregir un artefacto histórico comprobado y documentado.
- Cada cambio posterior usa el siguiente número libre y continúa incrementalmente; las migraciones aplicadas no se reescriben.
- Una migración se crea antes o junto con cualquier SQL aplicado a Supabase.
- Si el SQL se aplica manualmente desde Supabase SQL Editor, el mismo archivo debe quedar comprometido en Git.
- Los cambios de modelo, permisos o arquitectura también actualizan la documentación correspondiente.
- La verificación y el rollback se versionan cuando el riesgo o el alcance lo requieren.
- Después de cambios significativos se regenera el snapshot, se compara contra toda la cadena y se actualiza `docs/DATABASE_CHANGELOG.md`.

0006 se aplicó después de que `reconciliation/0006_structured_person_names_preflight.sql` reportó cero categorías bloqueantes. La aplicación compatible fue desplegada y el verificador terminó con código 0 y `ROLLBACK`. Su corrección de arnés concede acceso sólo a fixtures `pg_temp`, por lo que no cambia privilegios de producción ni la migración aplicada.

## Generación de snapshots

En Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pull-supabase-snapshot.ps1
```

El entorno proporciona `SUPABASE_DB_URL` como secreto. El script prefiere `pg_dump` y `psql` nativos, genera todos los archivos en un directorio temporal y sólo publica el conjunto completo cuando termina correctamente. No imprime ni guarda la URI y no ejecuta escrituras remotas.

Los resultados se almacenan en `supabase/reconciliation/live/`. Son artefactos para comparar el estado vivo y construir migraciones; no son migraciones para ejecutar directamente.

La reconciliación cerrada el 2026-07-18 comparó el snapshot `2026-07-18T04:05:40Z` contra `0001`–`0006`. No se detectó deriva inexplicada; los detalles están en `reconciliation/0006_post_apply_reconciliation.md`.

## Reglas de seguridad

- No incluir secretos, llaves `service_role`, tokens ni datos personales u operativos reales.
- No ejecutar la baseline contra la base viva actual.
- No crear cambios destructivos sin revisión explícita y respaldo adecuado.
- No reparar historial remoto ni aplicar migraciones automáticamente desde el flujo de snapshots.
