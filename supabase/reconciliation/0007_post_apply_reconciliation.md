# Cierre de reconciliación posterior a 0007

**Fecha de reconciliación:** 2026-07-20 (`America/Mexico_City`)

**Snapshot:** `2026-07-21T00:16:03Z`

**Estado declarado:** `SUCCESS`

**Cadena incluida:** `0001 + 0002 + 0003 + 0004 + 0005 + 0006 + 0007`

**Resultado:** reconciliado sin deriva inexplicada; Fase B.1 cerrada.

Este informe compara localmente el snapshot post-0006 versionado con el conjunto vivo post-0007 ya generado. No se estableció conexión con Supabase, no se ejecutó SQL, no se regeneró ni editó el snapshot y no se modificó ninguna migración.

## Integridad del snapshot

Se inspeccionaron los 14 artefactos obligatorios: esquema, tablas, columnas, restricciones, índices, triggers, funciones, políticas, tres inventarios de privilegios, ACL expandida, semillas controladas y metadata. Todos existen y tienen contenido.

El metadata declara:

- generación UTC `2026-07-21T00:16:03Z`;
- estado `SUCCESS`;
- propósito exclusivo de reconciliación sin escrituras remotas;
- `pg_dump 18.4` y `psql 18.4` nativos;
- codificación UTF-8;
- alcance `public`, sólo esquema, sin ownership ni privilegios en el dump principal;
- las cuatro capturas de privilegios completas.

No se encontraron URI de conexión, contraseñas, tokens, cookies, correos ni filas operativas. `live_seed_catalogs.sql` contiene únicamente los 11 catálogos permitidos. No hay temporales, resultados parciales ni marcador `FAILURE`. Los timestamps de publicación forman un solo conjunto y el metadata fue emitido al terminarlo.

## Inventario vivo

| Categoría | Post-0006 | Post-0007 | Variación |
| --- | ---: | ---: | ---: |
| Tablas públicas | 17 | 18 | +1 |
| Columnas | 156 | 165 | +9 |
| Restricciones PK, FK, UNIQUE o CHECK | 72 | 80 | +8 |
| Índices, incluidos los respaldados por restricciones | 38 | 43 | +5 |
| Triggers no internos sobre tablas públicas | 8 | 10 | +2 |
| Firmas de función públicas | 39 | 47 | +8 |
| Políticas RLS | 23 | 23 | 0 |
| Tablas con RLS habilitado | 17 | 18 | +1 |
| Semillas controladas | 51 | 51 | 0 |
| Grants de rutina | 112 | 125 | +13 |
| Grants de tabla publicados por `information_schema` | 261 | 270 | +9 |
| Grants de secuencia | 6 | 6 | 0 |
| Entradas ACL expandidas | 413 | 436 | +23 |

El delta teórico de tabla era +10 al contar ocho privilegios del propietario —incluido `MAINTAIN`— y dos de `service_role`. PostgreSQL 18 no publica `MAINTAIN` en `information_schema.table_privileges`, por lo que ese artefacto aumenta en +9. `live_acl.sql` sí expande `MAINTAIN` y confirma las diez entradas nuevas de tabla; junto con 13 entradas de función produce el delta ACL esperado de +23. Es una diferencia de representación, no un privilegio ausente ni deriva.

## Tabla y columnas

La única tabla nueva es `public.admin_audit_events`, con RLS habilitado y sin RLS forzado. Su forma viva coincide con 0007:

1. `id uuid NOT NULL DEFAULT gen_random_uuid()`;
2. `actor_profile_id uuid NOT NULL`;
3. `target_profile_id uuid NOT NULL`;
4. `action_code text NOT NULL`;
5. `outcome text NOT NULL`;
6. `reason text NULL`;
7. `role_assignment_id uuid NULL`;
8. `metadata jsonb NOT NULL DEFAULT '{}'::jsonb`;
9. `occurred_at timestamptz NOT NULL DEFAULT now()`.

El diff especializado añade sólo esas nueve filas: no elimina ni modifica columnas post-0006. `profiles` y `role_assignments` conservan su forma V1; no aparecen campos de revocación de Fase C ni cambios en tablas operativas.

## Restricciones e índices

Las ocho restricciones nuevas son exactamente una PK sobre `id`, tres FK `ON DELETE RESTRICT` hacia `profiles`/`role_assignments` y cuatro `CHECK` para código de acción, resultado `success|failure`, motivo normalizado y acotado, y metadata validada. No cambió ni desapareció ninguna restricción previa.

Los cinco índices nuevos son:

- `admin_audit_events_pkey`, único sobre `id`;
- `admin_audit_events_target_occurred_idx`, sobre objetivo, fecha descendente e ID descendente;
- `admin_audit_events_actor_occurred_idx`, sobre actor, fecha descendente e ID descendente;
- `profiles_admin_directory_sort_idx`, sobre apellidos, nombres e ID;
- `profiles_admin_directory_filters_idx`, sobre estado, clase de cuenta, persona y programa.

No tienen predicados ni columnas incluidas; sólo la PK es única. Los 38 índices post-0006 permanecen sin diferencias.

## Triggers y funciones

Los dos triggers nuevos pertenecen a `admin_audit_events` y llaman `prevent_admin_audit_event_mutation()`:

- fila, `BEFORE UPDATE OR DELETE`;
- sentencia, `BEFORE TRUNCATE`.

Los ocho triggers públicos anteriores permanecen sin cambios. La captura especializada abarca `public`; los triggers de `auth.users` siguen sustentados por preflights y verificadores aprobados.

Las ocho firmas nuevas coinciden semánticamente con 0007:

1. `sitaa_current_mexico_date()`;
2. `is_b1_account_admin()`;
3. `admin_audit_metadata_is_safe(jsonb)`;
4. `prevent_admin_audit_event_mutation()`;
5. `search_admin_accounts_b1(...)`;
6. `get_admin_account_detail_b1(uuid)`;
7. `get_admin_account_assignments_b1(uuid)`;
8. `get_admin_account_audit_history_b1(uuid,integer,integer)`.

La evidencia confirma volatilidad, autoridad invoker/definer, `search_path`, fecha de `America/Mexico_City`, autoridad exacta B.1, máximo de metadata de 16 384 bytes, normalización de llaves sensibles, excepción append-only, paginación acotada, escape literal de comodines, lista minimizada, confirmación Auth booleana, proyección de auditoría sin metadata y clasificaciones V1. Las 39 firmas post-0006 siguen presentes sin cambios. La corrección del verificador no es una migración ni un cambio vivo.

## RLS y políticas

Las 18 tablas públicas tienen RLS habilitado. `admin_audit_events` no tiene políticas de cliente y el total permanece en 23. `live_policies.sql` es idéntico al post-0006: no se añadió lectura transversal de perfiles o asignaciones ni una política administrativa directa.

## Privilegios y ACL

El contrato vivo de funciones es mínimo y explícito:

- `sitaa_current_mexico_date()`, `is_b1_account_admin()` y `prevent_admin_audit_event_mutation()` son owner-only;
- `admin_audit_metadata_is_safe(jsonb)` concede `EXECUTE` sólo al propietario y a `service_role`, sin grant option;
- las cuatro RPC B.1 conceden `EXECUTE` sólo al propietario y a `authenticated`, sin grant option;
- `PUBLIC` y `anon` no ejecutan funciones 0007; `service_role` no ejecuta las RPC públicas.

`admin_audit_events` concede al propietario sus privilegios normales y a `service_role` exactamente `SELECT` e `INSERT`. `PUBLIC`, `anon` y `authenticated` no tienen acceso directo; `service_role` no tiene `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER` ni `MAINTAIN`. No existen grants de columna que amplíen el contrato.

Los 112 grants de rutina, 261 grants de tabla, seis grants de secuencia y 413 entradas ACL post-0006 permanecen sin eliminaciones o alteraciones. 0007 no crea secuencias.

## Catálogos y frontera de datos

Las 51 semillas siguen sin cambios: cinco semestres, dos programas, tres modalidades, seis estados, cinco tipos de actividad, cinco categorías, una división, siete ubicaciones, cinco roles de participante, diez roles institucionales y dos servicios. No se añadió ni renombró un rol; `technical_admin` conserva el código V1 consumido por B.1.

El snapshot no exporta usuarios Auth, perfiles, asignaciones, actividades, participantes, asistencia, tokens ni eventos de auditoría. No se inspeccionó ni publicó PII operativa.

## Aplicación, verificación y smoke tests

- El preflight terminó con todos los conteos bloqueantes en cero.
- La migración 0007 terminó en `COMMIT` y quedó inmutable.
- La aplicación compatible de Fase B.1 fue desplegada.
- La primera ejecución del verificador falló en su bloque estático, antes de crear fixtures, porque recortaba `pg_proc.prosrc` antes de colapsar saltos de línea.
- El arnés se corrigió sin modificar objetos vivos; el verificador reejecutado terminó correctamente con su `ROLLBACK` final y no dejó fixtures ni grants temporales persistentes.
- Los smoke tests confirmaron acceso del administrador técnico exacto, rechazo de profesor y alumno ordinarios, búsqueda, filtros, lista, detalle, asignaciones V1 e historial sanitizado, sin controles de mutación.

## Clasificación completa de diferencias

| Diferencia | Clasificación |
| --- | --- |
| Tabla, columnas, restricciones, índices, triggers, funciones y RLS de 0007 | Cambio estructural esperado de 0007 |
| Grants de ocho funciones y ACL de `admin_audit_events` | Cambio de privilegio esperado de 0007 |
| Timestamp del snapshot y token aleatorio `\restrict`/`\unrestrict` | Diferencia ambiental inocua |
| Omisión textual opcional de `SECURITY INVOKER` | Diferencia ambiental inocua |
| `MAINTAIN` visible en ACL expandida pero no en `information_schema.table_privileges` | Diferencia de representación PostgreSQL inocua |
| Espacios finales y formato emitidos por `psql`/`pg_dump` | Diferencia ambiental inocua del artefacto generado |
| Datos operativos posteriores al snapshot anterior | Diferencia controlada no exportada ni inspeccionada |

**Deriva inexplicada:** ninguna.

## Conclusión

El estado vivo queda reconciliado contra `0001`–`0007`. 0007 está aplicada, verificada, probada en producción y reconciliada; Fase B.1 queda operativa y cerrada dentro de sus límites de sólo lectura. Las migraciones aplicadas permanecen inmutables. `0008` es el siguiente número disponible para un cambio futuro real; no se crea en este cierre.
