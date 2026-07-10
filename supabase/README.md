# Supabase en SITAA

Este directorio concentra el historial de cambios de base de datos de SITAA.

## Regla principal

A partir de esta etapa, todo cambio futuro en la base de datos debe registrarse en el repositorio como archivo SQL de migración dentro de `supabase/migrations/`.

Durante el prototipo, algunas migraciones pueden seguir ejecutándose manualmente desde el SQL Editor de Supabase. Aun así, el archivo SQL correspondiente debe quedar comprometido en Git, aunque la aplicación manual ya se haya realizado en Supabase.

## Convención de nombres

Usar nombres consecutivos, breves y descriptivos:

- `0001_baseline_current_schema.sql`
- `0002_short_description.sql`
- `0003_short_description.sql`

El número indica el orden de aplicación. La descripción debe usar minúsculas, guiones bajos y una frase corta en inglés o español técnico consistente.

## Baseline pendiente

La primera migración real debe capturar el estado actual de Supabase como baseline verificable. No debe escribirse a mano con suposiciones: debe reconciliarse contra el esquema vivo, funciones, políticas RLS, índices, catálogos mínimos y objetos necesarios para que SITAA opere.

Hasta que exista esa baseline, los archivos de documentación en `docs/DATABASE_STATE.md` y `docs/DATABASE_CHANGELOG.md` funcionan como guía de reconciliación, no como definición ejecutable del esquema.

## Reglas de seguridad

- No incluir secretos, llaves `service_role`, tokens ni datos personales reales.
- No crear migraciones destructivas sin revisión explícita.
- No depender sólo de cambios manuales en Supabase: el repositorio debe convertirse en la fuente de verdad.
- Toda migración debe ser revisable y, cuando aplique, acompañarse de notas en la documentación del modelo o decisiones.

## Baseline generada desde snapshots vivos

La migración `supabase/migrations/0001_baseline_current_schema.sql` fue generada desde los snapshots en `supabase/reconciliation/`. Representa el estado conocido del proyecto vivo al momento de la reconciliación, pero conserva TODOs para objetos no cubiertos por los snapshots: constraints, índices, triggers, grants, datos semilla y tablas mencionadas por políticas sin columnas capturadas.

Esta baseline debe revisarse antes de ejecutarse automáticamente en cualquier entorno. Su objetivo principal es fijar un punto de partida verificable para que los cambios futuros sí queden versionados en el repositorio.
