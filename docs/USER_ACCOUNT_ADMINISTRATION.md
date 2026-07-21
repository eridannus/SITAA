# Administración de cuentas de usuario

**Estado funcional:** Fase B.1 está operativa mediante 0007. Fase B.2a está preparada localmente mediante 0008, todavía no aplicada, no verificada en PostgreSQL, sin smoke tests y no reconciliada; B.2b, B.3 y C permanecen pendientes.

La separación inicial de cuentas realizada al cerrar la Fase A fue una limpieza revisada del entorno; no es una operación reutilizable de fusión, conversión o transferencia.

## Límites por fase

### B.1 — Directorio de sólo lectura y base de auditoría

Implementado y operativo:

- rutas protegidas `/admin/accounts` y `/admin/accounts/[id]`;
- búsqueda, filtros, orden y paginación en servidor mediante RPC;
- detalle de identidad, resumen mínimo de confirmación Auth y asignaciones V1;
- identificador enmascarado en lista y completo sólo en detalle autorizado;
- tabla append-only `admin_audit_events` sin acceso directo de clientes;
- historial administrativo sanitizado, sin devolver `metadata`;
- ninguna mutación de cuentas, Auth o roles.

El acceso exige simultáneamente perfil activo y una asignación actual `technical_admin` con alcance `system`, área `technical` y programa/división nulos. La aplicación y cada RPC verifican el contrato completo. La vigencia compara fechas calendario `YYYY-MM-DD` de `America/Mexico_City`: inicio y término son inclusivos, y la base no depende de la zona horaria de la sesión PostgreSQL.

### B.2a — Barrera operativa y corrección de identidad

Preparada localmente mediante 0008, todavía no aplicada ni verificada en PostgreSQL. Una cuenta distinta de `active` queda fuera de actividades, participantes, asistencia y check-in mediante políticas RLS restrictivas y guardas explícitas en las RPC `SECURITY DEFINER`, sin depender de que expire su JWT.

Un administrador B.1 exacto podrá corregir nombres estructurados, tipo/identificador/programa institucional según el tipo de cuenta, con motivo obligatorio, bloqueos de dependencias y un único evento append-only `account_identity_corrected`. No puede corregirse a sí mismo ni corregir objetivos pendientes. UUID, email, clase/estado de cuenta, ciclo de vida, Auth, roles y toda la historia operativa permanecen inmutables.

La corrección usa un protocolo fijo de concurrencia: captura al actor una vez; autoriza de forma optimista; rechaza autocorrección; bloquea `role_assignments`, `activities` y `activity_participants` en `SHARE`; bloquea actor y objetivo en orden UUID; vuelve a exigir autoridad B.1; y sólo entonces carga, valida, actualiza y audita el objetivo. Las revocaciones de rol y desactivaciones del actor se serializan con este segundo control. Sólo bloquean las dependencias abiertas: borradores o actividades que todavía no terminan según la fecha y hora de Ciudad de México. Las cuatro pruebas manuales de dos sesiones siguen pendientes y requieren un entorno desechable completo; no se ejecutarán en producción ni se limpiarán borrando historia append-only.

`activity_participants` deja de aceptar DML directo de `authenticated`; sus altas pasan exclusivamente por RPC con lock/relectura. El ACL explícito por columna (`pg_attribute.attacl`) debe estar vacío, pero `information_schema.column_privileges` conserva las filas legítimas que derivan del ACL de tabla. El preflight bloquea filas no explicadas y acceso efectivo superior al privilegio de tabla en vez de reparar deriva; el verificador demuestra el detector con un grant de columna transaccional que revoca de inmediato. `activities` conserva las escrituras de aplicación, con un trigger que inmoviliza creador/responsable, revalida alcance y participantes después de cualquier espera y rechaza que un cliente reabra una actividad histórica mediante estado u horario. `role_assignments` no incorpora writer B.2a; Fase C deberá adoptar este mismo contrato.

El primer preflight remoto de 0008 revirtió sin cambios y sólo señaló `registration_trigger_drift = 1`, un falso positivo por nombres locales incorrectos. El segundo intento abortó durante la evaluación, antes de producir categorías, porque `pg_get_expr` no puede reconstruir el `WHEN` que usa `OLD` y `NEW`; tampoco dejó cambios. La corrección usa `pg_get_triggerdef` y mantiene la semántica exacta sin modificar los triggers. Otra reejecución permanece pendiente, por lo que B.2a sigue sin aplicar.

### B.2b — Activación y reactivación coordinadas con Auth

Pendiente: activación, desactivación, reactivación, revocación de sesión y los flujos confiables de recuperación. Requieren una decisión separada y coordinación con Auth. Los administradores nunca verán ni establecerán contraseñas.

### B.3 — Cuentas técnicas y operaciones Auth

Pendiente: alta e invitación de cuentas técnicas, reenvío de confirmaciones, revocación coordinada de sesiones y otras operaciones `auth.admin`. Sólo podrán ejecutarse en backend confiable; nunca habrá `service_role` en el navegador.

### Fase C — Roles y delegación

Asignar, revocar, transferir o delegar roles queda fuera de B.1–B.3 y pertenece a Fase C. Antes requiere el catálogo y contrato V2, campos de revocación, matriz de autoridad y auditoría transaccional. B.1 sólo clasifica filas V1 como actuales, futuras, vencidas, inactivas o suspendidas por estado de cuenta.

## Directorio B.1

La consulta nunca descarga el padrón completo al navegador. Sin texto ni filtros devuelve cero filas. El texto tiene entre 2 y 200 caracteres; `%`, `_` y `\` se buscan literalmente y sólo `extensions.unaccent(text)` aporta coincidencia sin acentos. La página válida está entre 1 y 1 000 000, contiene 20 filas por defecto y hasta 50. Si una página queda fuera de rango, el servidor repite la misma consulta autorizada con página 1/tamaño 1 y redirige a la última página conservando filtros; no inventa total cero ni añade un RPC de conteo.

Filtros admitidos: programa, tipo y estado de cuenta, tipo de persona, rol, área de servicio y alcance actuales. Rol, servicio y alcance deben coincidir en la misma fila vigente de `role_assignments`. Los valores desconocidos se rechazan.

La lista devuelve únicamente nombre estructurado/derivado, correo, clasificación básica, programa, identificador enmascarado y conteo de asignaciones actuales. La ficha autorizada añade el identificador completo, fechas de ciclo de vida y un booleano de correo Auth confirmado. Nunca expone credenciales, tokens, cookies, metadata Auth, identidades OAuth ni enlaces de recuperación.

## Auditoría administrativa

`admin_audit_events` fue aplicada en 0007 como bitácora append-only. Tiene referencias restrictivas a actor, objetivo y asignación opcional; acción y resultado controlados; motivo acotado; y metadata que debe ser un objeto JSON de hasta 16 384 bytes, con llaves superiores normalizadas antes de detectar términos sensibles. RLS está activa, no hay políticas de cliente y los triggers impiden `UPDATE`, `DELETE` y `TRUNCATE`. El ACL explícito de `service_role` es sólo `SELECT`/`INSERT` sobre la tabla y `EXECUTE` sobre el validador de metadata; 0007 bloqueó la aplicación si ese rol no conservaba `rolbypassrls=true`.

El preflight y la aplicación de 0007 concluyeron correctamente. La primera ejecución del verificador falló en el bloque estático, antes de crear fixtures, por el orden de normalización de saltos de línea externos en `pg_proc.prosrc`. Un diagnóstico de sólo lectura confirmó que las definiciones y ACL persistentes cumplen el contrato. El verificador corregido aprobó la cobertura completa con `ROLLBACK`; los smoke tests de producción y el snapshot `2026-07-21T00:16:03Z` permitieron reconciliar B.1 sin deriva inexplicada.

El cierre de verificación B.1 fija también la forma física: nueve columnas en orden, PK y tres FK restrictivas, cuatro validaciones semánticas, cuatro índices concretos y dos triggers exactos. Las cuatro RPC se verifican por nombre, tipo y orden de entradas/salidas; los helpers privados se verifican por autoridad, fecha institucional, límite de 16 384 bytes, protección append-only y privilegio mínimo.

El ACL de las ocho funciones 0007 se define sin depender de privilegios por defecto: las cuatro RPC sólo conceden `EXECUTE` a `authenticated`; los helpers de fecha, autoridad y trigger son owner-only; el validador de metadata conserva como única excepción el `EXECUTE` explícito de `service_role`. Ningún grant concedido a esos roles incluye grant option.

El rollback sólo puede retirar `admin_audit_events` mientras no exista historia. Antes de comprobar el vacío adquiere `ACCESS EXCLUSIVE NOWAIT` en una transacción `READ COMMITTED`; por ello un lector o escritor concurrente hace que el intento aborte de forma segura y evita que un `INSERT` de `service_role` confirme entre el control y el `DROP TABLE`. El operador debe aquietar la actividad y reintentar, nunca relajar el lock ni omitir la comprobación.

B.1 no escribe eventos porque no ofrece mutaciones. Fases posteriores deberán insertar mediante operaciones privilegiadas revisadas y sólo podrán leer una proyección sanitizada.

La aplicación compatible con B.2a añade `/admin/accounts/[id]/identity`. Antes de aplicar 0008, el detalle B.1 omite la acción y el acceso directo muestra un estado controlado; nunca se expone el error crudo de PostgREST. Tras 0008, la Server Action autentica de forma independiente, verifica la autoridad B.1 exacta, reconsulta el contexto y llama exclusivamente a la RPC transaccional.

## Criterios de aceptación

- La autorización no depende de ocultar controles.
- Una asignación `technical_admin` mal formada no concede acceso.
- Una cuenta inactiva no administra el directorio aunque conserve asignaciones actuales.
- Un usuario no autorizado obtiene `42501` directamente desde todas las RPC de datos cruzados.
- No se amplían las políticas propias de `profiles` ni `role_assignments`.
- La aplicación compatible publicada consulta exclusivamente las RPC B.1 autorizadas por 0007.
- No se introduce PII real en SQL, verificadores o documentación.
