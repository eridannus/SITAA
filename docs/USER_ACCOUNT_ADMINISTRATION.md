# Administración de cuentas de usuario

**Estado funcional:** Fase B.1 implementada localmente y pendiente de aplicar mediante 0007. Las fases B.2, B.3 y C no están implementadas.

La separación inicial de cuentas realizada al cerrar la Fase A fue una limpieza revisada del entorno; no es una operación reutilizable de fusión, conversión o transferencia.

## Límites por fase

### B.1 — Directorio de sólo lectura y base de auditoría

Preparado localmente:

- rutas protegidas `/admin/accounts` y `/admin/accounts/[id]`;
- búsqueda, filtros, orden y paginación en servidor mediante RPC;
- detalle de identidad, resumen mínimo de confirmación Auth y asignaciones V1;
- identificador enmascarado en lista y completo sólo en detalle autorizado;
- tabla append-only `admin_audit_events` sin acceso directo de clientes;
- historial administrativo sanitizado, sin devolver `metadata`;
- ninguna mutación de cuentas, Auth o roles.

El acceso exige simultáneamente perfil activo y una asignación actual `technical_admin` con alcance `system`, área `technical` y programa/división nulos. La aplicación y cada RPC verifican el contrato completo.

### B.2 — Ciclo de vida e identidad administrativa

Pendiente: activación, desactivación, corrección de identidad o programa y los flujos confiables de recuperación. Estas operaciones requerirán motivo, autorización, auditoría y coordinación con Auth. Los administradores nunca verán ni establecerán contraseñas.

### B.3 — Cuentas técnicas y operaciones Auth

Pendiente: alta e invitación de cuentas técnicas, reenvío de confirmaciones, revocación coordinada de sesiones y otras operaciones `auth.admin`. Sólo podrán ejecutarse en backend confiable; nunca habrá `service_role` en el navegador.

### Fase C — Roles y delegación

Asignar, revocar, transferir o delegar roles queda fuera de B.1–B.3 y pertenece a Fase C. Antes requiere el catálogo y contrato V2, campos de revocación, matriz de autoridad y auditoría transaccional. B.1 sólo clasifica filas V1 como actuales, futuras, vencidas, inactivas o suspendidas por estado de cuenta.

## Directorio B.1

La consulta nunca descarga el padrón completo al navegador. Sin texto ni filtros devuelve cero filas. El texto tiene entre 2 y 200 caracteres; `%`, `_` y `\` se buscan literalmente y sólo `extensions.unaccent(text)` aporta coincidencia sin acentos. La página válida está entre 1 y 1 000 000, contiene 20 filas por defecto y hasta 50. Si una página queda fuera de rango, el servidor repite la misma consulta autorizada con página 1/tamaño 1 y redirige a la última página conservando filtros; no inventa total cero ni añade un RPC de conteo.

Filtros admitidos: programa, tipo y estado de cuenta, tipo de persona, rol, área de servicio y alcance actuales. Rol, servicio y alcance deben coincidir en la misma fila vigente de `role_assignments`. Los valores desconocidos se rechazan.

La lista devuelve únicamente nombre estructurado/derivado, correo, clasificación básica, programa, identificador enmascarado y conteo de asignaciones actuales. La ficha autorizada añade el identificador completo, fechas de ciclo de vida y un booleano de correo Auth confirmado. Nunca expone credenciales, tokens, cookies, metadata Auth, identidades OAuth ni enlaces de recuperación.

## Auditoría administrativa

`admin_audit_events` se prepara en 0007 como bitácora append-only. Tiene referencias restrictivas a actor, objetivo y asignación opcional; acción y resultado controlados; motivo acotado; y metadata JSON de objeto, tamaño limitado y llaves superiores normalizadas antes de detectar términos sensibles. RLS está activa, no hay políticas de cliente y los triggers impiden `UPDATE`, `DELETE` y `TRUNCATE`. El ACL explícito de `service_role` es sólo `SELECT`/`INSERT` sobre la tabla y `EXECUTE` sobre el validador de metadata; 0007 bloquea si ese rol no conserva `rolbypassrls=true`.

B.1 no escribe eventos porque no ofrece mutaciones. Fases posteriores deberán insertar mediante operaciones privilegiadas revisadas y sólo podrán leer una proyección sanitizada.

## Criterios de aceptación

- La autorización no depende de ocultar controles.
- Una asignación `technical_admin` mal formada no concede acceso.
- Una cuenta inactiva no administra el directorio aunque conserve asignaciones actuales.
- Un usuario no autorizado obtiene `42501` directamente desde todas las RPC de datos cruzados.
- No se amplían las políticas propias de `profiles` ni `role_assignments`.
- La aplicación funciona antes de aplicar 0007 mostrando un estado controlado de migración pendiente.
- No se introduce PII real en SQL, verificadores o documentación.
