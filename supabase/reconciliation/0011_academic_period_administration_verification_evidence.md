# Evidencia de verificación productiva de 0011

## Alcance y fecha

Este checkpoint documenta de forma sanitizada la segunda ejecución productiva del verificador transaccional corregido de `0011_academic_period_administration.sql`, realizada el **2026-08-12** con identificador UTC `2026-08-12T19:25:25Z`. No sustituye un snapshot vivo ni acredita todavía el arnés multisesión, la reconciliación post-0011, la interfaz `/admin/periods` o sus smoke tests.

## Procedencia de la migración aplicada

- Commit fuente: `08d07132e67c299b46f5cf9db307adebd759b013`.
- Ruta: `supabase/migrations/0011_academic_period_administration.sql`.
- Git blob: `1a560df41deb83696cc080946056949c92e1f849`.
- SHA-256: `107e81a3af028d9c8382ef5e07ae7b2137a6aaec7ea143fa8c55d7772ad7e3c4`.

## Procedencia del verificador corregido

- HEAD de ejecución: `e5f733b04699629b0dac523e9762eeae4e125787`.
- Ruta: `supabase/reconciliation/0011_academic_period_administration_verify.sql`.
- Git blob: `640960f62f14b8293038beba7084a508cffce666`.
- SHA-256: `c3a42dcc850b87a042ea5a644a8201b19bb5e52651571781912fb1c39cdf5371`.

## Primer intento rechazado

La primera ejecución productiva permanece como antecedente histórico rechazado. `psql` terminó con código 3 y PostgreSQL emitió `42501` con el error estable `sitaa_activity_writer_identity_mismatch` durante la construcción del fixture sintético. No se alcanzaron un `COMMIT` explícito ni el `ROLLBACK` final; la transacción abierta fue descartada cuando terminó la sesión fallida. **Cero casos de ese intento se aceptan como evidencia.**

## Segunda ejecución aprobada

- Código de salida de `psql`: `0`.
- Filas de caso: `51`.
- Casos únicos: `51`, conjunto exacto `1–51`.
- Casos faltantes: ninguno.
- Casos duplicados: ninguno.
- `ROLLBACK` final explícito: exactamente uno, observado.
- `COMMIT`: cero, no observado.
- Solicitud interactiva de contraseña: no observada.
- SHA-256 del log local sanitizado: `d2acac543afc0551b4eb0391a31f55d11d37c9cd3bd50b5bed2db3e44bab265e`.
- SHA-256 del resumen local sanitizado: `4208dfdb1770e2fb4dd4489dcd20702b3b0c81d0cd5caf149abf2696e27f94f0`.

## Consecuencias

- La migración `0011` permanece aplicada en producción.
- El verificador productivo corregido y sus casos `1–51` quedan aprobados.
- Los fixtures y los eventos de auditoría generados por el verificador no persistieron, porque la ejecución terminó con su propio `ROLLBACK`.
- El script de rollback de la migración no fue ejecutado.
- La migración no fue reaplicada durante la ejecución aprobada del verificador.
- El repositorio permaneció limpio después de la ejecución.

## Gates pendientes

SEM-01 continúa activo y no está cerrado. El siguiente gate obligatorio es crear, revisar y ejecutar el arnés multisesión real. Después deberán regenerarse el snapshot vivo y la reconciliación post-0011. Sólo al aprobar esos gates podrá implementarse `/admin/periods`; su despliegue y los smoke tests de interfaz tampoco se han ejecutado. El horizonte «razonable» de fecha de actividad permanece diferido y sin implementar.

El snapshot vivo actualmente rastreado sigue representando post-0010. Este checkpoint no permite inferir ni declarar el inventario físico post-0011.

## Sanitización

Este documento no contiene URI de base de datos, hostname, referencia de proyecto, usuario o contraseña de base de datos, correo, UUID de una persona real, token, cookie, código de autorización, JWT, respuesta cruda del proveedor, fila cruda de base de datos ni ruta local absoluta. No reproduce la salida cruda de `stdout` o `stderr`; conserva únicamente hechos durables y el hash del log sanitizado.
