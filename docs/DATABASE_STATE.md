# Estado reconciliado de la base de datos

**Actualización documental:** 2026-07-22.
**Snapshot vivo canónico:** `2026-07-22T23:32:46Z`, estado `SUCCESS`.

La fuente histórica aplicada, verificada y reconciliada es `0001`–`0009`. Estas migraciones son inmutables. La comparación se realizó previamente contra `supabase/reconciliation/live/`; esta preparación B.3a no volvió a conectarse a Supabase, no ejecutó SQL y no regeneró el snapshot.

## Cadena aplicada

1. `0001_baseline_current_schema.sql`: baseline reconciliada.
2. `0002_database_security_and_integrity.sql`: seguridad, publicación y privilegios mínimos.
3. `0003_fix_draft_temporal_lifecycle.sql`: ciclo temporal de borradores.
4. `0004_identity_registration_foundation.sql`: identidad y registro institucional.
5. `0005_fix_google_oauth_user_creation.sql`: alta por Google OAuth.
6. `0006_structured_person_names.sql`: nombres estructurados y `full_name` derivado.
7. `0007_admin_account_directory_audit.sql`: directorio B.1 de sólo lectura y auditoría append-only.
8. `0008_operational_account_barrier_identity_correction.sql`: barrera de cuenta activa y corrección de identidad B.2a.
9. `0009_admin_account_lifecycle_transitions.sql`: desactivación/reactivación auditada B.2b.

## Inventario vivo posterior a 0009

| Categoría | Cantidad |
| --- | ---: |
| Tablas públicas | 18 |
| Columnas | 165 |
| Restricciones PK, FK, UNIQUE o CHECK | 80 |
| Índices, incluidos los respaldados por restricciones | 43 |
| Triggers sobre tablas públicas | 11 |
| Funciones y firmas públicas | 54 |
| Políticas RLS | 25 |
| Tablas con RLS habilitado | 18 |
| Filas en catálogos controlados | 51 |
| Grants de rutinas | 137 |
| Grants de tablas publicados por `information_schema` | 267 |
| Grants de secuencias | 6 |
| Entradas ACL expandidas | 445 |

El delta frente a post‑0008 es exactamente el esperado por 0009: tres firmas, cinco grants de rutina y cinco entradas ACL adicionales, sin cambio de tablas, columnas, restricciones, índices, triggers, políticas, semillas ni privilegios de tabla o secuencia. No existe deriva inexplicada.

## Contratos acumulados vigentes

- Cada `auth.users` aceptado corresponde a un único perfil SITAA; Google crea un perfil `pending_registration` y la finalización institucional autenticada lo activa.
- Los componentes estructurados del nombre son autoritativos y `full_name` es compatibilidad derivada.
- `admin_audit_events` conserva nueve columnas, RLS sin políticas de cliente y protección append-only.
- B.1 exige `technical_admin/system/technical` exacto; B.2a conserva esa autoridad, la barrera operativa independiente del JWT y la corrección de identidad auditada.
- B.2b permite desactivar o reactivar cuentas elegibles, protege el último administrador exacto, conserva `activated_at`, asignaciones e historia y genera auditoría minimizada.
- Una cuenta inactiva no puede operar SITAA aunque conserve un JWT técnicamente válido.
- 0009 no usa Auth Admin, no revoca sesiones físicas y no garantiza invalidación inmediata de tokens.
- RLS continúa habilitado en las 18 tablas y `PUBLIC`/`anon` no ejecutan funciones SITAA; `anon` conserva únicamente la lectura deliberada de `system_health`.
- Catálogos, actividades, participantes y asistencia preservan sus contratos acumulados.

Las matrices manuales de concurrencia B.2a/B.2b siguen sin ejecutarse y no constituyen evidencia de producción.

## Preparación local 0010 / B.3a

`0010_coordinated_auth_session_suspension.sql` existe localmente y está **sin aplicar**. Prepara:

- `admin_auth_operations`, ledger sin políticas cliente para coordinar perfil y Auth;
- cinco RPC B.3a públicas o de servicio y un trigger de estado owner-only;
- retiro de `EXECUTE` directo de `authenticated` sobre la mutación B.2b;
- una Edge Function autenticada como único límite para Auth Admin y `service_role`;
- reintentos idempotentes que reanudan desde la última etapa persistida;
- cercado por intento para impedir que un resultado Auth tardío se aplique a un claim posterior;
- timestamps autoritativos de reloj de pared posteriores a los locks e inmutabilidad estricta de evidencia;
- evidencia administrativa minimizada y separación explícita entre la transición del perfil y la sincronización Auth.

La barrera 0008 sigue siendo el límite operativo inmediato. La coordinación no simula atomicidad entre PostgreSQL y Auth: desactivar primero bloquea el perfil y después intenta suspender Auth; reactivar primero restaura Auth y sólo entonces activa el perfil. El modelo SQL conserva estados recuperables y terminales sanitizados, pero el adaptador hospedado provisional emite únicamente fallos reintentables hasta verificar una taxonomía terminal y un camino de recuperación. Nunca se persisten errores crudos.

No se ha ejecutado el preflight, la migración, el verificador, el rollback, la Edge Function ni Auth Admin. Tampoco se ha probado en un proyecto hospedado el efecto sobre JWT existentes, refresh tokens o la restauración con `ban_duration = 'none'`. La matriz desechable de `docs/TEST_PLAN_0010.md` es bloqueante antes de producción.

## Pendientes

- **A-02:** `technical_admin` mantiene acceso académico amplio a contenido publicado. **Deferred intentionally until user, role and permission administration is designed.**
- B.3a permanece abierta hasta aplicar/verificar 0010, desplegar la Edge Function y aprobar la prueba Auth desechable y smoke tests.
- B.3b, administración de roles/Fase C, retiro de A-02, paneles especializados, formularios dinámicos, reportes y exportaciones continúan pendientes.
- No se debe crear 0011 mientras 0010 siga en preparación no aplicada.

## Evidencia y rollback

Los resultados de aplicación y verificación de 0009 están en `supabase/reconciliation/0009_post_apply_reconciliation.md` y archivos asociados. Los snapshots vivos no se editan manualmente.

El rollback 0010 sólo es elegible antes de que exista la primera operación B.3a o evento Auth B.3a. Después de ese punto, la historia coordinada no puede eliminarse y cualquier corrección deberá usar una migración posterior revisada.
