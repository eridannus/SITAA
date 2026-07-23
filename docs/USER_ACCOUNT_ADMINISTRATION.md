# Administración de cuentas de usuario

**Estado funcional:** Fase B.1 está cerrada mediante 0007, Fase B.2a mediante 0008 y Fase B.2b mediante 0009. Las tres están aplicadas, verificadas, probadas y reconciliadas dentro de sus alcances aprobados. B.3a está preparada sólo localmente mediante 0010, todavía abierta y sin aplicación ni evidencia Auth hospedada; B.3b y Fase C siguen pendientes.

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

Aplicada, verificada y reconciliada mediante 0008. Una cuenta distinta de `active` queda fuera de actividades, participantes, asistencia y check-in mediante políticas RLS restrictivas y guardas explícitas en las RPC `SECURITY DEFINER`, sin depender de que expire su JWT.

Un administrador B.1 exacto puede corregir nombres estructurados, tipo/identificador/programa institucional según el tipo de cuenta, con motivo obligatorio, bloqueos de dependencias y un único evento append-only `account_identity_corrected`. No puede corregirse a sí mismo ni corregir objetivos pendientes. UUID, email, clase/estado de cuenta, ciclo de vida, Auth, roles y toda la historia operativa permanecen inmutables.

La corrección usa un protocolo fijo de concurrencia: captura al actor una vez; autoriza de forma optimista; rechaza autocorrección; bloquea `role_assignments`, `activities` y `activity_participants` en `SHARE`; bloquea actor y objetivo en orden UUID; vuelve a exigir autoridad B.1; y sólo entonces carga, valida, actualiza y audita el objetivo. Las revocaciones de rol y desactivaciones del actor se serializan con este segundo control. Sólo bloquean las dependencias abiertas: borradores o actividades que todavía no terminan según la fecha y hora de Ciudad de México. Las cuatro pruebas manuales de dos sesiones siguen pendientes y requieren un entorno desechable completo; no se ejecutarán en producción ni se limpiarán borrando historia append-only.

`activity_participants` deja de aceptar DML directo de `authenticated`; sus altas pasan exclusivamente por RPC con lock/relectura. El ACL explícito por columna (`pg_attribute.attacl`) debe estar vacío, pero `information_schema.column_privileges` conserva las filas legítimas que derivan del ACL de tabla. El preflight bloquea filas no explicadas y acceso efectivo superior al privilegio de tabla en vez de reparar deriva; el verificador demuestra el detector con un grant de columna transaccional que revoca de inmediato. `activities` conserva las escrituras de aplicación, con un trigger que inmoviliza creador/responsable, revalida alcance y participantes después de cualquier espera y rechaza que un cliente reabra una actividad histórica mediante estado u horario. `role_assignments` no incorpora writer B.2a; Fase C deberá adoptar este mismo contrato.

El primer preflight remoto de 0008 revirtió con un falso positivo por nombres y el segundo abortó por la decompilación conjunta de `OLD`/`NEW`. El tercero produjo las 40 categorías y expuso que el arnés rechazaba únicamente los casts `::text` añadidos por el deparser. La reejecución corregida aprobó las 35 categorías bloqueantes y terminó con `ROLLBACK`; después se publicó la aplicación compatible y 0008 se aplicó con `COMMIT`.

La primera ejecución del verificador pasó los controles estáticos y comenzó las fixtures, pero abortó al invocar directamente como `authenticated` el helper owner-only `is_b1_account_admin()`. El ACL actuó correctamente y la transacción completa fue descartada sin persistencia. Una segunda ejecución descartada dejó postcondiciones crudas bajo el rol cliente. La versión final separó semántica owner, denegación cliente `42501` y acceso autorizado por las RPC B.1/B.2a `SECURITY DEFINER`; aprobó y terminó con `ROLLBACK`. Los smoke tests finales, incluido el responsable histórico entre programas, aprobaron.

### B.2b — Ciclo de vida operativo cerrado

Implementada mediante 0009: desactivación y reactivación del estado operativo en `profiles`, con auditoría y sin mutar Auth, roles ni historia. `pending_registration` no puede activarse administrativamente y continúa en el flujo propio de registro.

### B.3a — Suspensión/restauración coordinada preparada

0010 prepara un ledger idempotente y una única Edge Function autenticada. Desactivar deja primero el perfil inactivo e inserta la operación directamente en `profile_suspended`; reactivar sólo vuelve a activar el perfil después de sincronizar Auth y revalidar la autoridad B.1. Un fallo conserva la última etapa confirmada y permite reintento por una autoridad exacta, sin repetir el evento de ciclo ya persistido. La operación más reciente se conserva como contexto aunque sea final; sólo una operación no final bloquea un nuevo cambio. Si Auth ya está sincronizado, otro administrador exacto puede finalizar inmediatamente sin repetir la llamada privilegiada. La barrera 0008 niega operaciones aunque un JWT emitido siga vigente.

Esta preparación no está aplicada, desplegada ni probada contra Auth hospedado. No garantiza revocación inmediata de JWT o refresh tokens. `service_role` queda confinado al paquete Edge; la aplicación Next.js no obtiene un cliente privilegiado.

### B.3b — Otras operaciones Auth pendientes

Alta e invitación de cuentas técnicas, reenvío de confirmaciones, recuperación y otras operaciones `auth.admin` quedan fuera de 0010. Los administradores nunca ven ni establecen contraseñas.

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

La aplicación compatible con B.2a expone `/admin/accounts/[id]/identity`. Con 0008 aplicada e inmutable, la Server Action autentica de forma independiente, verifica la autoridad B.1 exacta, reconsulta el contexto y llama exclusivamente a la RPC transaccional; nunca expone el error crudo de PostgREST. Las dos ejecuciones descartadas del verificador no persistieron fixtures, correcciones ni auditoría. La versión final con límites owner/cliente correctos aprobó con `ROLLBACK`; la corrección de identidad, la auditoría sanitizada y los permisos del responsable histórico aprobaron los smoke tests. El snapshot post-0008 quedó reconciliado sin deriva inexplicada.

## Criterios de aceptación

- La autorización no depende de ocultar controles.
- Una asignación `technical_admin` mal formada no concede acceso.
- Una cuenta inactiva no administra el directorio aunque conserve asignaciones actuales.
- Un usuario no autorizado obtiene `42501` directamente desde todas las RPC de datos cruzados.
- No se amplían las políticas propias de `profiles` ni `role_assignments`.
- La aplicación compatible publicada consulta exclusivamente las RPC B.1 autorizadas por 0007.
- No se introduce PII real en SQL, verificadores o documentación.

## Fase B.2b operativa: ciclo de vida administrativo

La ruta protegida `/admin/accounts/[id]/lifecycle` permite a una autoridad B.1 exacta desactivar una cuenta activa elegible o reactivar una inactiva válida. El detalle muestra estado, marcas temporales y conteos de dependencias; las dependencias se conservan y no bloquean. La acción requiere motivo de 10–1000 caracteres y confirmación explícita, y llama exclusivamente a la RPC 0009.

La cuenta propia, los registros pendientes y la última autoridad B.1 exacta no son objetivos válidos. La guarda de última autoridad es defensa en profundidad: con un único administrador exacto activo, el objetivo posible es la propia cuenta y se rechaza antes; con un actor autorizado distinto hay al menos dos autoridades. El verificador captura primero la línea base viva, añade dos administradores sintéticos y comprueba los totales relativos línea base + 2, + 1 y + 2, sin modificar autoridades preexistentes. Las fases cliente llaman RPC bajo `authenticated` y las postcondiciones crudas se evalúan como owner.

La reactivación exige identidad coherente, Auth confirmado y, para cuentas institucionales, un programa existente y activo bloqueado con `FOR SHARE`. El orden es: advisory de ciclo, `role_assignments` en `SHARE`, Auth objetivo, perfiles ordenados por UUID, segunda autorización, programa institucional, validación, actualización y auditoría. La matriz manual de concurrencia debe ejecutarse sólo en un entorno desechable y aún está pendiente. La desactivación aplica la barrera operativa existente sin borrar historia ni afirmar revocación física de sesiones. Al reactivar, sólo recuperan efecto asignaciones todavía activas, vigentes, válidas y compatibles.

La precedencia de denegación del contexto es determinista: cuenta propia, registro pendiente, ciclo de vida inválido, último administrador, identidad inválida y finalmente Auth no confirmado. La mutación vuelve a validar todo bajo locks y es la autoridad final.

La aplicación compatible consulta primero el contexto B.3a. Sólo si PostgreSQL reporta explícitamente que esa firma no existe usa el camino directo 0009 aislado. Cuando B.3a está disponible, toda falla de Edge Function se cierra sin fallback privilegiado de Next.js. La interfaz distingue perfil suspendido, sincronización pendiente, Auth sincronizado y operación completa, conserva el mismo `request_id` durante una corrección de formulario y usa `current_operation_id` para no presentar una operación final como pendiente.

El primer preflight remoto de 0009 no fue aprobado por cuatro falsos positivos del arnés; un diagnóstico de sólo lectura confirmó el estado post-0008. La reejecución corregida dejó los 19 bloqueos en cero y terminó con `ROLLBACK`. Después de desplegar la aplicación compatible, los intentos 1 y 2 fallaron antes del DDL por el `EXISTS` exterior sin cerrar y por el cast faltante de `pg_default_acl.defaclobjtype`; ambas transacciones se descartaron. El intento 3 aprobó la guarda atómica y terminó con `COMMIT`. El verificador final aprobó con `ROLLBACK` sin persistir fixtures, los smoke tests aprobaron y el snapshot `2026-07-22T23:32:46Z` quedó reconciliado sin deriva inexplicada. 0009 es inmutable, B.2b está cerrada y B.3/Fase C permanecen pendientes.
