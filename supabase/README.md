# Supabase en SITAA

Este directorio contiene la baseline reconciliada, las migraciones incrementales, Edge Functions y artefactos de verificación de SITAA.

## Cadena canónica

`0001_baseline_current_schema.sql` representa la baseline histórica. `0002`–`0009` están aplicadas, verificadas, reconciliadas e inmutables. El snapshot canónico post‑0009 es `2026-07-22T23:32:46Z` y no presenta deriva inexplicada.

`0010_coordinated_auth_session_suspension.sql` está preparado sólo localmente para B.3a. No está aplicado; su preflight, verificador, rollback, Edge Function y prueba Auth desechable tampoco se han ejecutado. No crear 0011 mientras esta preparación siga abierta.

Toda migración nueva debe:

- iniciar una transacción explícita cuando el cambio sea transaccional;
- validar la línea base viva antes del DDL y el resultado antes del `COMMIT`;
- normalizar ACL de forma explícita;
- incluir preflight, verificador y rollback cuando el riesgo lo requiera;
- aplicarse manualmente después de revisión y de publicar una aplicación compatible;
- regenerar y reconciliar el snapshot después de cambios significativos.

No se reescriben migraciones aplicadas ni se ejecutan snapshots como migraciones.

## Preparación B.3a

0010 prepara `admin_auth_operations`, cinco RPC y un trigger owner-only. La Edge Function `admin-account-auth-lifecycle` es la única frontera permitida para `service_role` y Auth Admin. El navegador y Next.js nunca reciben el secreto. La función exige JWT y usa un cliente de usuario para RPC autenticadas y un cliente privilegiado, sin persistencia de sesión, sólo para claim/result y `auth.admin.updateUserById()`.

El adaptador aísla `ban_duration = '876000h'` para suspensión y `ban_duration = 'none'` para restauración, valores admitidos por los tipos instalados de `@supabase/auth-js` 2.110.1. Esta evidencia de tipos no demuestra su comportamiento en Supabase hospedado. No se afirma revocación inmediata de JWT, refresh tokens o restauración hasta aprobar `docs/TEST_PLAN_0010.md`.

No añadir `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_SECRET_KEY` ni equivalentes a `.env.example`, Vercel público, aplicación Next.js o navegador.

## Snapshots

En Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pull-supabase-snapshot.ps1
```

El script requiere `SUPABASE_DB_URL`, prefiere `pg_dump`/`psql` nativos, usa consultas de sólo lectura y publica el conjunto únicamente si todos los artefactos terminan correctamente. Nunca imprime ni persiste la URI. Este comando no debe ejecutarse durante la preparación 0010 sin autorización expresa.

Los resultados viven en `supabase/reconciliation/live/` y sirven como evidencia de reconciliación. Incluyen esquema, tablas, columnas, restricciones, índices, triggers, funciones, políticas, ACL, privilegios y semillas permitidas; no incluyen usuarios ni datos operativos.

## Seguridad

- No guardar secretos, tokens, PII ni datos operativos reales.
- No ejecutar `db push`, `db reset`, repair automático ni escrituras desde el flujo de snapshot.
- No desplegar/invocar una Edge Function ni usar Auth Admin como parte de una validación estática.
- `service_role` no implica acceso directo al ledger B.3a; únicamente puede ejecutar las dos RPC de servicio aprobadas.
- El rollback 0010 sólo es elegible antes de la primera operación o evento B.3a real.
