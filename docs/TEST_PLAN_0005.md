# Plan de pruebas 0005: alta Google y exclusión del registro autenticado

**Estado:** 0005 aplicada y verificada. El preflight y el verificador transaccional fueron aprobados; los smoke tests confirmados se resumen en `supabase/reconciliation/0005_post_apply_reconciliation.md`. La lista se conserva como contrato de regresión.

## Base de datos

- [ ] El preflight read-only devuelve cero en todas las categorías bloqueantes.
- [ ] Confirma las funciones, triggers, columnas y constraints esperados de 0004.
- [ ] Confirma que la función instalada conserva el contrato prematuro que 0005 reemplaza.
- [ ] Un `auth.users` Google sintético con `email_confirmed_at=null` se inserta y crea exactamente un perfil `pending_registration` inactivo e incompleto.
- [ ] El alta pendiente no crea `role_assignments` ni acceso operativo.
- [ ] Una identidad Google enlazada con correo coincidente y `email_verified=true` permite completar alumno y profesor.
- [ ] Se aceptan las representaciones boolean y string confiable de `email_verified=true`.
- [ ] Identidad ausente, perteneciente a otro usuario, con correo distinto o no verificada se rechaza.
- [ ] Auth/profile ausente, perfil activo e inactivo se rechazan sin reescritura ni reactivación.
- [ ] Identificador inválido o duplicado y programa inactivo/inexistente dejan el perfil pendiente sin cambios parciales.
- [ ] Los ceros iniciales y el tipo derivado de identificador se conservan.
- [ ] OAuth no soportado, signup futuro por contraseña, metadata técnica pública y alta malformada se revierten sin huérfanos.
- [ ] Bootstrap técnico confiable conserva la exigencia de correo confirmado.
- [ ] Perfiles heredados email/password conservan estado y acceso.
- [ ] Alumno y profesor básicos no crean actividades; asignaciones de profesor y tutor par conservan permisos.
- [ ] Permanecen los contratos de borradores, publicación y asistencia de 0002/0003.
- [ ] `0005_fix_google_oauth_user_creation_verify.sql` termina con `ROLLBACK`.

## Aplicación

- [ ] Un usuario activo que abre `/register`, `/register/student` o `/register/professor` va a `/dashboard`.
- [ ] Un usuario activo no puede evadir la guarda mediante POST directo a `startGoogleRegistration`.
- [ ] Un usuario pendiente va a `/complete-registration` o a la ruta fija elegida.
- [ ] Un usuario inactivo va a `/account-status?state=inactive`.
- [ ] Un Auth user autenticado sin perfil va a `/account-status?state=missing`.
- [ ] Un usuario no autenticado inicia registro de alumno y de profesor con Google.
- [ ] Funcionan los test users Gmail y `pc.puma` configurados en Google External/Testing.
- [ ] Cancelar consentimiento muestra un mensaje sanitizado y permite reintentar.
- [ ] El callback diferencia error de proveedor, código ausente, intercambio fallido, sesión ausente, consulta fallida y perfil ausente.
- [ ] Los logs sólo incluyen etapa, código/mensaje sanitizados y timestamp; nunca código OAuth, state, verifier, tokens o cookies.
- [ ] El identificador duplicado se informa sólo durante la finalización autenticada.
- [ ] Ningún alta asigna roles ni permite crear actividades.
- [ ] Login heredado correo/contraseña continúa funcionando.
- [ ] Vinculación Google por mismo correo no duplica ni sobrescribe el perfil existente.
- [ ] El flujo funciona en móvil y no muestra instrucciones SMTP.

## Liberación

- [ ] Ejecutar `npm run check:text`, `npm run lint` y `npm run build`.
- [ ] Revisar SQL y confirmar ausencia de `CASCADE`, borrado de Auth/identities/profiles y cambios fuera del alcance.
- [ ] Aplicar 0005 manualmente sólo después de aprobar el preflight.
- [ ] Ejecutar el verificador transaccional y smoke tests Gmail/`pc.puma`.
- [ ] Regenerar el snapshot y actualizar el estado reconciliado.
