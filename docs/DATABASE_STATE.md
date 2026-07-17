# Estado reconciliado de la base de datos

**Fecha de cierre documental:** 2026-07-16.

**Snapshot vivo comparado:** `2026-07-17T00:21:06Z`, estado `SUCCESS`.

La fuente de verdad histórica y evolutiva es la cadena:

1. `supabase/migrations/0001_baseline_current_schema.sql`: baseline reconciliada.
2. `supabase/migrations/0002_database_security_and_integrity.sql`: aplicada y verificada en Supabase el 2026-07-16.
3. `supabase/migrations/0003_fix_draft_temporal_lifecycle.sql`: aplicada y verificada en Supabase el 2026-07-16.

El snapshot regenerado bajo `supabase/reconciliation/live/` fue comparado localmente contra esa cadena. No se conectó a Supabase durante esta reconciliación documental.

## Inventario posterior a 0003

| Categoría | Cantidad |
| --- | ---: |
| Tablas públicas | 17 |
| Columnas | 151 |
| Restricciones PK, FK, UNIQUE o CHECK | 61 |
| Índices, incluidos los respaldados por restricciones | 37 |
| Triggers | 6 |
| Funciones y firmas públicas | 33 |
| Políticas RLS | 23 |
| Tablas con RLS habilitado | 17 |
| Filas de semillas en catálogos controlados | 51 |
| Grants de rutinas | 99 |
| Grants de tablas | 262 |
| Grants de secuencia | 6 |
| Entradas ACL expandidas | 401 |

Las tablas, columnas, restricciones, índices y semillas coinciden con 0001. Las diferencias del snapshot regenerado se limitan a funciones, políticas, triggers y privilegios previstos por 0002 y a las tres definiciones de temporalidad de borradores reemplazadas por 0003.

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

## Resultado de reconciliación

| Diferencia observada | Clasificación |
| --- | --- |
| Tres funciones nuevas, dos triggers nuevos y cambios de helpers/RPC | Efecto esperado de 0002 |
| Política SELECT de `activities` separada por estado `draft` | Efecto esperado de 0002 |
| Grants reducidos para `PUBLIC`, `anon` y `authenticated` | Efecto esperado de 0002 |
| Definiciones finales de `activity_has_ended`, `can_update_activity_base` y `can_delete_activity` | Efecto esperado de 0003 |
| Nuevo valor aleatorio `\restrict` de `pg_dump` y nueva fecha UTC de metadata | Diferencia ambiental inocua |

**Deriva inexplicada:** ninguna en esquema, funciones, triggers, políticas, grants, ACL, catálogos o restricciones.

## Pendientes conocidos

- **A-02:** `technical_admin` mantiene acceso académico amplio a contenido publicado. **Deferred intentionally until user, role and permission administration is designed.**
- **0004 está aplicada** y Google OAuth está configurado. El snapshot versionado aún no debe presentarse como evidencia post-0004 hasta regenerarlo.
- La prueba productiva confirmó `sitaa_google_email_not_verified` durante el `INSERT` de `auth.users`; no quedaron Auth users, identities, profiles ni enlaces accidentales. `0005_fix_google_oauth_user_creation.sql` está creada y no aplicada.
- 0005 conserva el perfil Google `pending_registration` inactivo durante el alta temprana y traslada la verificación fuerte a la finalización autenticada. También excluye cuentas autenticadas de las rutas públicas de registro.
- Administración de cuentas (Fase B), roles V2 (Fase C), filtros (Fase D), retiro de A-02 (Fase E) y check-in abierto (Fase F) siguen pendientes.
- Permanecen siete hallazgos medios y cuatro bajos de la auditoría; 0002 y 0003 no pretendían resolverlos.
- El check-in abierto sigue pendiente. En una capacidad futura, un usuario autenticado de SITAA no preinscrito podrá ser agregado como participante y marcado `attended` en una sola operación transaccional, únicamente cuando la actividad habilite check-in abierto.
- Overloads heredados, `activities.updated_by`, `starts_at`/`ends_at`, alcance divisional y `token_type = 'registration'` permanecen reservados o pendientes de análisis.

## Inmutabilidad y siguiente migración

`0001`, `0002`, `0003` y `0004` forman historia aplicada y no se reescriben. `0005` es la siguiente migración creada y permanece pendiente de aplicación; el snapshot vivo debe regenerarse después de verificarla.

Todo trabajo futuro de base de datos debe revisar la cadena completa, crear una nueva migración numerada, incluir verificación y rollback cuando corresponda, aplicarse manualmente a Supabase, regenerar el snapshot después de cambios significativos, comparar el estado vivo contra la cadena y actualizar `docs/DATABASE_CHANGELOG.md`.
