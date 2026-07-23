# Estado reconciliado de la base de datos

**Actualización documental:** 2026-07-23.
**Snapshot vivo canónico:** `2026-07-22T23:32:46Z`, estado `SUCCESS`.

La fuente histórica aplicada, verificada y reconciliada es `0001`–`0009`. Esas migraciones son inmutables. `0010` también está aplicada y su verificador PostgreSQL corregido está aprobado, pero la reconciliación post‑0010 permanece pendiente. El snapshot canónico bajo `supabase/reconciliation/live/` continúa representando post‑0009; este cierre documental no volvió a conectarse a Supabase, no ejecutó SQL y no regeneró el snapshot.

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
10. `0010_coordinated_auth_session_suspension.sql`: coordinación B.3a entre ciclo de vida SITAA y Auth; aplicada y con verificador PostgreSQL aprobado.

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

## 0010 aplicada / verificador PostgreSQL aprobado

`0010_coordinated_auth_session_suspension.sql` fue aplicada y el registro local termina en `COMMIT`. Añade:

- `admin_auth_operations`, ledger sin políticas cliente para coordinar perfil y Auth;
- cinco RPC B.3a públicas o de servicio y un trigger de estado owner-only;
- retiro de `EXECUTE` directo de `authenticated` sobre la mutación B.2b;
- una Edge Function autenticada como único límite para Auth Admin y `service_role`;
- reintentos idempotentes que reanudan desde la última etapa persistida;
- cercado por intento para impedir que un resultado Auth tardío se aplique a un claim posterior;
- timestamps autoritativos de reloj de pared posteriores a los locks e inmutabilidad estricta de evidencia;
- evidencia administrativa minimizada y separación explícita entre la transición del perfil y la sincronización Auth.

La barrera 0008 sigue siendo el límite operativo inmediato. La coordinación no simula atomicidad entre PostgreSQL y Auth: desactivar primero bloquea el perfil y después intenta suspender Auth; reactivar primero restaura Auth y sólo entonces activa el perfil. El modelo SQL conserva estados recuperables y terminales sanitizados, pero el adaptador hospedado provisional emite únicamente fallos reintentables hasta verificar una taxonomía terminal y un camino de recuperación. Nunca se persisten errores crudos.

El primer preflight remoto se ejecutó en una transacción de sólo lectura, devolvió sus 34 filas y terminó con `ROLLBACK` y código 0. No fue aprobado: 29 de 30 categorías bloqueantes fueron cero, pero `dangerous_default_acl` devolvió 50. El diagnóstico posterior, también de sólo lectura y cerrado con `ROLLBACK`/código 0, identificó cinco grupos estándar de diez filas: `postgres/public`, `postgres/storage`, `supabase_admin/graphql`, `supabase_admin/graphql_public` y `supabase_admin/public`. Ninguna de estas ejecuciones cambió objetos, filas o privilegios predeterminados.

La categoría corregida exige ejecutor y sesión `postgres`; inspecciona sólo defaults creados por `postgres`, globales o de `public`, para tablas y funciones, y bloquea grantees fuera de la allowlist que 0010 normaliza expresamente. Los defaults de secuencia, otros esquemas y otros propietarios quedan fuera porque no pueden inicializar los objetos creados por 0010. La captura y comparación del hash completo de `pg_default_acl` permanece intacta.

La segunda ejecución corregida quedó aprobada: devolvió exactamente 34 filas, dejó las 30 categorías bloqueantes en cero y produjo `dangerous_default_acl = 0`. Sus cuatro conteos informativos fueron `active_exact_b1_administrators = 1`, `existing_b2b_lifecycle_events = 4`, `inactive_accounts = 0` e `inactive_accounts_with_active_or_future_assignments = 0`. Terminó con `ROLLBACK`, código 0 y sin `ERROR`; no expuso UUID, datos operativos, PII, credenciales, tokens o secretos y no cambió ningún objeto, fila o privilegio.

La aplicación compatible se desplegó correctamente y la Edge Function está `ACTIVE`, sin invocaciones registradas para esta fase. El primer verificador hospedado terminó con código de salida 3 en `restore_failure_finalize`: la función devolvió correctamente `42501/sitaa_account_lifecycle_auth_unconfirmed`, pero el arnés intentaba capturarlo con `raise_exception`, condición reservada para `P0001`. No imprimió el `ROLLBACK` final; la desconexión de `psql` descartó la transacción abierta. No se ejecutó Auth Admin ni una operación real B.3a.

El diagnóstico posterior al aborto confirmó que el ledger existe, hay seis funciones B.3a, el ledger tiene cero filas y existen cero eventos de auditoría Auth B.3a. Terminó con `ROLLBACK` y código de salida 0; no sobrevivió ningún fixture del primer intento.

La reejecución usó `insufficient_privilege` y validó de forma conjunta SQLSTATE `42501` y el mensaje estable. Completó todos los escenarios, imprimió exactamente un `ROLLBACK` final, terminó con código de salida 0 y no produjo líneas `ERROR`. El verificador PostgreSQL quedó aprobado sin persistir fixtures, privilegios temporales, operaciones o auditoría.

Aún deben aprobarse la matriz Auth hospedada, los smoke tests y el snapshot/reconciliación post‑0010. No se ha probado el efecto sobre JWT existentes, refresh tokens o la restauración con `ban_duration = 'none'`.

## Pendientes

- **A-02:** `technical_admin` mantiene acceso académico amplio a contenido publicado. **Deferred intentionally until user, role and permission administration is designed.**
- B.3a permanece abierta hasta aprobar la prueba Auth desechable, los smoke tests y la reconciliación post‑0010.
- El paquete 0010 exige casts `::text` al serializar campos internos `char` de catálogo y revalida B.1 después de los locks en todas sus RPC mutables. Su verificador PostgreSQL está aprobado, pero no demuestra por sí solo la semántica hospedada de Auth.
- B.3b, administración de roles/Fase C, retiro de A-02, paneles especializados, formularios dinámicos, reportes y exportaciones continúan pendientes.
- No se debe crear 0011 mientras permanezcan abiertos los gates hospedados y la reconciliación post‑0010.

## Evidencia y rollback

Los resultados de aplicación y verificación de 0009 están en `supabase/reconciliation/0009_post_apply_reconciliation.md` y archivos asociados. Los snapshots vivos no se editan manualmente.

El diagnóstico confirmó que todavía no existe ninguna operación real B.3a ni evento Auth B.3a, por lo que el rollback conserva su elegibilidad documental; no se ejecutó en este cierre. Después de la primera operación o evento real, la historia coordinada no puede eliminarse y el rollback queda prohibido por diseño.
