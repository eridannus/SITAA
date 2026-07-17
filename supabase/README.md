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
- `0004_identity_registration_foundation.sql`: reescrita para Google OAuth y finalización institucional autenticada, sin intents; pendiente de preflight, configuración, revisión y aplicación manual.
- Snapshot posterior: `2026-07-17T00:21:06Z`, reconciliado sin deriva inexplicada.
- Siguiente número permitido después de aplicar/verificar 0004: `0005`.

## Aplicación pendiente de 0004

1. Configurar Google OAuth siguiendo `docs/GOOGLE_AUTH_SETUP.md`, sin guardar secretos en Git o Vercel público.
2. Ejecutar el preflight de sólo lectura y aprobar cero categorías bloqueantes; usuarios email/password y OAuth existentes son informativos.
3. Comprometer migración y aplicación compatible, sin desplegar todavía.
4. Aplicar manualmente `migrations/0004_identity_registration_foundation.sql`.
5. Desplegar inmediatamente la aplicación `pending_registration` + Google callback.
6. Ejecutar el verificador y `docs/TEST_PLAN_0004.md`; regenerar el snapshot.

El rollback es exclusivamente de emergencia, bloquea perfiles pendientes/técnicos incompatibles y nunca borra Auth users, profiles ni identidades Google.

## Historial futuro

Después de esta reconciliación:

- `0001_baseline_current_schema.sql` no se reescribe, excepto para corregir un defecto comprobado de la baseline.
- `0001`, `0002` y `0003` no se reescriben, salvo para corregir un artefacto histórico comprobado y documentado.
- El siguiente cambio usa `0004_short_description.sql` y continúa incrementalmente.
- Una migración se crea antes o junto con cualquier SQL aplicado a Supabase.
- Si el SQL se aplica manualmente desde Supabase SQL Editor, el mismo archivo debe quedar comprometido en Git.
- Los cambios de modelo, permisos o arquitectura también actualizan la documentación correspondiente.
- La verificación y el rollback se versionan cuando el riesgo o el alcance lo requieren.
- Después de cambios significativos se regenera el snapshot, se compara contra toda la cadena y se actualiza `docs/DATABASE_CHANGELOG.md`.

## Generación de snapshots

En Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pull-supabase-snapshot.ps1
```

El entorno proporciona `SUPABASE_DB_URL` como secreto. El script prefiere `pg_dump` y `psql` nativos, genera todos los archivos en un directorio temporal y sólo publica el conjunto completo cuando termina correctamente. No imprime ni guarda la URI y no ejecuta escrituras remotas.

Los resultados se almacenan en `supabase/reconciliation/live/`. Son artefactos para comparar el estado vivo y construir migraciones; no son migraciones para ejecutar directamente.

La reconciliación cerrada el 2026-07-16 comparó el snapshot regenerado contra `0001 + 0002 + 0003`. Las diferencias fueron efectos esperados de 0002/0003 o metadata inocua de `pg_dump`; no se detectó deriva inexplicada.

## Reglas de seguridad

- No incluir secretos, llaves `service_role`, tokens ni datos personales u operativos reales.
- No ejecutar la baseline contra la base viva actual.
- No crear cambios destructivos sin revisión explícita y respaldo adecuado.
- No reparar historial remoto ni aplicar migraciones automáticamente desde el flujo de snapshots.
