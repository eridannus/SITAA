# Estado reconciliado de la base de datos

**Fecha de cierre documental:** 2026-07-17.

**Snapshot vivo comparado:** `2026-07-17T23:20:07Z`, estado `SUCCESS`.

La fuente de verdad histórica y evolutiva es la cadena:

1. `supabase/migrations/0001_baseline_current_schema.sql`: baseline reconciliada.
2. `supabase/migrations/0002_database_security_and_integrity.sql`: aplicada y verificada en Supabase el 2026-07-16.
3. `supabase/migrations/0003_fix_draft_temporal_lifecycle.sql`: aplicada y verificada en Supabase el 2026-07-16.
4. `supabase/migrations/0004_identity_registration_foundation.sql`: aplicada y verificada.
5. `supabase/migrations/0005_fix_google_oauth_user_creation.sql`: aplicada y verificada.

`0006_structured_person_names.sql` está creada localmente como siguiente cambio, pero no forma parte del estado vivo ni se ha aplicado.

El snapshot regenerado bajo `supabase/reconciliation/live/` fue comparado localmente contra esa cadena. No se conectó a Supabase durante esta reconciliación documental.

## Inventario posterior a 0005

| Categoría | Cantidad |
| --- | ---: |
| Tablas públicas | 17 |
| Columnas | 156 |
| Restricciones PK, FK, UNIQUE o CHECK | 68 |
| Índices, incluidos los respaldados por restricciones | 38 |
| Triggers sobre tablas públicas | 7 |
| Funciones y firmas públicas | 37 |
| Políticas RLS | 23 |
| Tablas con RLS habilitado | 17 |
| Filas de semillas en catálogos controlados | 51 |
| Grants de rutinas | 108 |
| Grants de tablas | 261 |
| Grants de secuencia | 6 |
| Entradas ACL expandidas | 409 |

El estado vivo coincide con el resultado acumulado de 0001–0005. Las 156 columnas corresponden al baseline más `academic_programs.is_active` y los cuatro campos de ciclo de cuenta añadidos por 0004. Las funciones críticas de 0005 coinciden de forma normalizada con la migración aplicada.

## Efectos verificados de 0002

- Los borradores sólo son visibles para `created_by`; responsable, participante, gestor y `technical_admin` no amplían la lectura de borradores ajenos.
- `can_read_activity(uuid)` y `can_edit_activity(uuid)` distinguen `draft` de estados publicados.
- `publish_activity(uuid)` publica dentro de una transacción y exige sesión, creador, autorización vigente, semestre y contrato programado completo.
- `validate_activity_scheduled_state()` y `validate_activities_scheduled_state` protegen filas `scheduled`, hacen inmutable `created_by` para sesiones cliente y prohíben `scheduled → draft`.
- `guard_activity_participant_pending_deadline()` y su trigger, junto con las RPC individual y masiva, rechazan restaurar `pending` en la frontera natural o después.
- `PUBLIC` y `anon` no tienen `EXECUTE` sobre funciones SITAA.
- `anon` conserva únicamente `SELECT` sobre `system_health`.
- `authenticated` conserva el contrato directo mínimo documentado y no tiene acceso directo a `activity_checkin_tokens` ni a `system_health_id_seq`.
- `technical_admin` conserva intencionalmente acceso amplio sobre contenido publicado durante desarrollo y pruebas, pero no sobre borradores ajenos.

La verificación SQL de 0002 terminó sin desviaciones. Los smoke tests manuales de borradores, publicación, bloqueo, participantes, asistencia y QR/código también pasaron.

## Efectos verificados de 0003

- `activity_has_ended(uuid)` devuelve `false` para cualquier borrador.
- `can_update_activity_base(uuid)` permite al creador editar su borrador aunque la fecha u hora provisional sea pasada, nula o incompleta.
- `can_delete_activity(uuid)` aplica la misma regla al borrado del borrador propio.
- El comportamiento temporal y administrativo de actividades publicadas permanece sin cambios.
- La privacidad de borradores establecida por 0002 permanece intacta.

Los nueve resultados del verificador de 0003 fueron verdaderos y la prueba terminó con el `ROLLBACK` transaccional esperado. Los smoke tests manuales confirmaron edición y eliminación de borradores atrapados y rechazo de publicación con horarios inválidos.

## Efectos verificados de 0004 y 0005

- `profiles` distingue cuentas `institutional|technical` y estados `pending_registration|active|inactive` con restricciones de identidad y ciclo de vida.
- Google crea un único perfil institucional pendiente, inactivo, incompleto y sin roles, aunque `email_confirmed_at` sea nulo durante el `INSERT` inicial.
- La finalización exige sesión, identidad Google vinculada y verificada, correos coincidentes, programa activo e identificador institucional único.
- La sincronización de Auth actualiza sólo `profiles.email`.
- Signup público por contraseña, OAuth no soportado y metadata ambigua continúan rechazados atómicamente.
- Las rutas públicas de registro excluyen cuentas ya autenticadas y la guarda de render es de sólo lectura.
- Los preflight y verificadores transaccionales de 0004 y 0005 pasaron; sus fixtures terminaron en `ROLLBACK`.
- Los smoke tests reales de alta Google y finalización de profesor pasaron. No quedaron filas Auth fallidas que limpiar.

## Resultado de reconciliación

| Diferencia observada | Clasificación |
| --- | --- |
| Objetos y privilegios de seguridad operativa | Efectos esperados de 0002 |
| Definiciones finales del ciclo temporal de borradores | Efectos esperados de 0003 |
| Campos, restricciones, funciones y trigger público de identidad | Efectos esperados de 0004 |
| Definiciones finales de alta y finalización Google | Efectos esperados de 0005 |
| Omisión de `SECURITY INVOKER` predeterminado y representación ACL de `MAINTAIN` | Diferencias ambientales inocuas |
| Separación administrativa inicial y nuevo perfil de profesor | Diferencias controladas de datos operativos; no se exportan en el snapshot |

**Deriva inexplicada:** ninguna en esquema, funciones, triggers, políticas, grants, ACL, catálogos o restricciones.

El detalle probatorio está en `supabase/reconciliation/0005_post_apply_reconciliation.md`. El inventario `live_triggers.sql` se limita a tablas de `public`; los dos triggers SITAA sobre `auth.users` quedaron comprobados por los preflight y verificadores aprobados de 0004 y 0005.

## Pendientes conocidos

- **A-02:** `technical_admin` mantiene acceso académico amplio a contenido publicado. **Deferred intentionally until user, role and permission administration is designed.**
- La Fase A de identidad y Google OAuth está cerrada y operativa mediante 0004 + 0005.
- La separación inicial entre cuenta técnica y cuenta académica fue una operación administrativa controlada; no es una migración reutilizable ni una función de fusión de cuentas.
- Administración de cuentas (Fase B), roles V2 (Fase C), filtros (Fase D), retiro de A-02 (Fase E) y check-in abierto (Fase F) siguen pendientes.
- Permanecen siete hallazgos medios y cuatro bajos de la auditoría; 0002 y 0003 no pretendían resolverlos.
- El check-in abierto sigue pendiente. En una capacidad futura, un usuario autenticado de SITAA no preinscrito podrá ser agregado como participante y marcado `attended` en una sola operación transaccional, únicamente cuando la actividad habilite check-in abierto.
- Overloads heredados, `activities.updated_by`, `starts_at`/`ends_at`, alcance divisional y `token_type = 'registration'` permanecen reservados o pendientes de análisis.

## Inmutabilidad y siguiente migración

`0001`–`0005` forman historia aplicada y verificada y no se reescriben. `0006` formaliza nombres personales estructurados, está pendiente de preflight, revisión y aplicación manual coordinada. No se ha conectado a Supabase para crearla.

Todo trabajo futuro de base de datos debe revisar la cadena completa, crear una nueva migración numerada, incluir verificación y rollback cuando corresponda, aplicarse manualmente a Supabase, regenerar el snapshot después de cambios significativos, comparar el estado vivo contra la cadena y actualizar `docs/DATABASE_CHANGELOG.md`.
