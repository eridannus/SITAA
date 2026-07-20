# Plan de prueba — migración 0007

**Estado:** artefactos creados localmente; migración no aplicada.

**Objetivo:** verificar el directorio administrativo B.1 de sólo lectura, la autoridad técnica exacta y la base append-only de auditoría sin exponer PII real ni modificar permanentemente datos.

## Artefactos

- `supabase/reconciliation/0007_admin_account_directory_audit_preflight.sql`
- `supabase/migrations/0007_admin_account_directory_audit.sql`
- `supabase/reconciliation/0007_admin_account_directory_audit_verify.sql`
- `supabase/reconciliation/0007_admin_account_directory_audit_rollback.sql`

No se ejecuta ningún artefacto en esta preparación local.

## Preflight

Debe ejecutarse y revisarse antes de la migración. Abre una transacción de sólo lectura, devuelve exclusivamente categorías, clasificación y conteos, y termina en `ROLLBACK`.

Todos los conteos bloqueantes deben ser cero:

- tablas y columnas post-0006 requeridas;
- código `technical_admin` y extensión `unaccent` verificada;
- correspondencia uno-a-uno entre Auth y `profiles`;
- integridad referencial de `role_assignments`;
- ausencia de tabla, funciones, trigger o políticas 0007;
- políticas propias de perfiles/asignaciones y grants cliente esperados.

La migración repite esas condiciones dentro de su misma transacción antes de ejecutar DDL.

## Verificador transaccional

Usa UUID sintéticos, correos `example.invalid`, objetos `pg_temp` y finaliza en `ROLLBACK`. Los grants del arnés se limitan a tablas y helpers temporales necesarios para probar con `SET LOCAL ROLE authenticated`.

Casos mínimos:

1. Una cuenta activa con asignación exacta `technical_admin/system/technical` puede buscar.
2. Un alumno ordinario recibe `42501`.
3. Un profesor ordinario recibe `42501`.
4. Un `technical_admin` con alcance o servicio mal formado recibe `42501`.
5. Un administrador técnico inactivo recibe `42501`.
6. Sin texto ni filtros se devuelven cero filas.
7. El texto encuentra nombre de forma acento-insensible, correo e identificador sintéticos.
8. Funcionan programa, tipo/estado de cuenta, persona, rol, servicio y alcance.
9. Rol, servicio y alcance no combinan asignaciones distintas.
10. Se rechazan página menor a uno y tamaño mayor a 50.
11. El identificador de lista se enmascara y conserva como máximo los últimos cuatro caracteres.
12. Sólo la ficha autorizada devuelve el identificador completo.
13. Auth se representa únicamente mediante el booleano `auth_email_confirmed`.
14. Las asignaciones se clasifican con semántica V1, sin campos de revocación de Fase C.
15. El historial devuelve la proyección sanitizada y omite `metadata`.
16. `authenticated` no lee ni escribe directamente `admin_audit_events`.
17. El trigger impide actualizar o eliminar eventos.
18. Llaves sensibles y metadata mayor al límite se rechazan.
19. RLS continúa mostrando únicamente perfil y asignaciones propias.
20. Persisten contratos esenciales de registro, nombres estructurados, borradores, participantes, asistencia y check-in de 0002–0006.

El verificador también comprueba firmas exactas, `SECURITY DEFINER`, `search_path`, RLS, ausencia de políticas cliente y grants de ejecución sólo para `authenticated` en las cuatro RPC públicas.

## Smoke tests posteriores al despliegue compatible

- La navegación `Cuentas` aparece sólo con el contrato B.1 exacto, también en móvil.
- Usuarios sin sesión vuelven a login; usuarios autenticados no autorizados vuelven al dashboard.
- Sin criterios se explica por qué no se navega el directorio completo.
- Filtros y paginación conservan estado y responden a teclado/zoom 200 %.
- Lista, correo e identificadores largos envuelven sin colisión a 320, 375, 768, 1024 y 1440 px.
- El identificador está enmascarado en lista y completo sólo en detalle.
- No existen controles de activación, corrección, Auth o roles.
- Antes de aplicar 0007, la aplicación compatible muestra “Módulo todavía no disponible” sin detalles PostgreSQL/Supabase.

## Rollback manual

El rollback sólo se considera tras revisión. Su guard exige el contrato 0007 completo y aborta si `admin_audit_events` contiene una fila. Revoca ejecución de las RPC antes de retirarlas, no usa `CASCADE`, elimina únicamente objetos 0007, verifica el contrato post-0006 y confirma con `COMMIT` sólo si la autoverificación termina correctamente.

## Secuencia de aplicación futura

1. Aprobar el preflight.
2. Aplicar 0007 manualmente.
3. Desplegar la aplicación compatible.
4. Ejecutar el verificador y confirmar su `ROLLBACK`.
5. Ejecutar smoke tests.
6. Regenerar el snapshot vivo.
7. Reconciliar 0001–0007.
8. Actualizar changelog y estado canónico como aplicados.
