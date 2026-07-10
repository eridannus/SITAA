# Historial de cambios de base de datos

Los cambios SQL anteriores a la migración baseline fueron aplicados manualmente durante el prototipo.

## Baseline pendiente

La baseline inicial ya fue generada desde snapshots vivos y queda pendiente de revisión antes de ejecutarse automáticamente contra cualquier entorno.

## 0001_baseline_current_schema.sql

- Fecha: 2026-07-10
- Propósito: documentar el estado vivo de Supabase después del prototipo manual y establecer el punto de partida para migraciones versionadas.
- Objetos afectados: tablas públicas capturadas por columnas, funciones públicas disponibles en snapshot y políticas RLS públicas.
- Aplicado en Supabase: no desde el repositorio; el estado ya existía por cambios manuales del prototipo.
- Observaciones: migración no destructiva generada desde `supabase/reconciliation/live_columns_snapshot.json`, `live_functions_snapshot.json` y `live_policies_snapshot.json`. Incluye TODOs para constraints, índices, triggers, grants, datos semilla y tablas mencionadas por políticas pero ausentes en el snapshot de columnas.

## Flujo de snapshots remotos

Para futuras reconciliaciones, Codex puede ejecutar `bash scripts/pull-supabase-snapshot.sh` durante setup si el entorno proporciona `SUPABASE_DB_URL` como secreto. En Windows puede ejecutarse con `powershell -ExecutionPolicy Bypass -File scripts/pull-supabase-snapshot.ps1`. El flujo cuenta con scripts para Bash y Windows PowerShell. El script genera snapshots en `supabase/reconciliation/live/` sin escribir credenciales ni aplicar cambios remotos. Estos archivos sirven como insumo para crear migraciones revisables; no sustituyen una migración SQL versionada.

Aplicar migraciones a Supabase sigue siendo manual por ahora. No se debe usar este flujo para ejecutar `db push`, `db reset` ni reparar historial remoto de migraciones automáticamente.

## Cambios posteriores
Después de la baseline, cada cambio de base de datos debe registrarse con una migración numerada y una nota breve en este archivo.

Formato sugerido:

### 0002_short_description.sql

- Fecha:
- Propósito:
- Objetos afectados:
- Aplicado en Supabase:
- Observaciones:
