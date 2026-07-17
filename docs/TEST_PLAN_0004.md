# Plan de pruebas 0004: Google OAuth e identidad institucional

**Estado:** listo para ejecución manual después de configurar Google y aplicar 0004 en prueba.

## Preflight y preparación

- [ ] Todas las categorías bloqueantes del preflight son cero.
- [ ] `legacy_email_password_user`, `existing_oauth_identity` y `possible_technical_operator` se revisan como informativas.
- [ ] `auth_user_without_profile` y `profile_without_auth_user` permanecen en cero.
- [ ] No existen triggers no documentados sobre `auth.users`.
- [ ] Google OAuth está configurado conforme a `GOOGLE_AUTH_SETUP.md`.
- [ ] Site URL es `https://www.sitaa.net` y producción permite `/auth/callback`.
- [ ] Email provider permanece habilitado para acceso heredado; no existe signup público por contraseña.

## Registro Google

- [ ] Alumno nuevo: nombre, número de cuenta y programa; “Continuar con Google”.
- [ ] Profesor nuevo: nombre, número de trabajador y programa; “Continuar con Google”.
- [ ] Funcionan Gmail personal, una cuenta `pc.puma` y otro Google Workspace.
- [ ] La interfaz no exige dominio institucional ni inspecciona `hd`.
- [ ] Se muestra recomendación de cuenta personal y advertencia de trazabilidad para cuentas compartidas.
- [ ] No se solicitan correo, contraseña o confirmación en formularios públicos.
- [ ] No se envía correo de autenticación ni se requiere SMTP.
- [ ] Cancelar consentimiento muestra un error sanitizado y permite reintentar.
- [ ] El flujo funciona en móvil y conserva campos tras validación local.

## Registration intents

- [ ] El token es aleatorio, expira en 15 minutos y sólo se usa una vez.
- [ ] La tabla guarda SHA-256, nunca el token crudo.
- [ ] La cookie es `HttpOnly`, `SameSite=Lax`, segura en producción, breve y no contiene PII.
- [ ] No aparece token ni identidad institucional en URL, query params o `localStorage`.
- [ ] `anon` y `authenticated` no leen/escriben directamente `registration_intents`.
- [ ] Identificador no numérico, >50, nombre fuera de 2–200, programa inexistente/inactivo y duplicado se rechazan.
- [ ] Un intent expirado o consumido no activa el perfil.
- [ ] Una carrera de duplicados deja el segundo perfil en `pending_registration`.

## Callback y recuperación

- [ ] `/auth/callback` intercambia PKCE y no confía en identidad de query params.
- [ ] Perfil activo va al panel sin sobrescribir persona, identificador, programa o nombre.
- [ ] Perfil inactivo no se reactiva y va a estado de cuenta.
- [ ] Perfil pendiente con intent válido se completa atómicamente.
- [ ] Perfil pendiente sin intent va a `/complete-registration`.
- [ ] `/complete-registration` revalida datos y activa el mismo perfil sin otro login Google.
- [ ] Usuario no autenticado es enviado a login; activo vuelve al panel; inactivo vuelve a estado de cuenta.
- [ ] Callback local y fallback de Vercel autorizados funcionan sin alterar el origen canónico.

## Identidad y roles

- [ ] `student` deriva `student_account`; `professor` deriva `worker_number`.
- [ ] Identificadores de 1 y 50 dígitos son válidos; 51 se rechaza; ceros iniciales sobreviven.
- [ ] Nombre de 200 caracteres se acepta; 1 y 201 se rechazan; correo >254 se rechaza.
- [ ] Alumno, profesor y cuenta técnica válidos crean exactamente un perfil.
- [ ] Ningún registro crea `role_assignments`.
- [ ] Alumno/profesor nuevos no pueden crear actividades.
- [ ] Asignaciones actuales de profesor y tutor par conservan sus permisos.
- [ ] Cuenta técnica sólo se crea con `app_metadata` confiable y no recibe rol automático.

## Compatibilidad heredada

- [ ] Un usuario existente inicia con correo/contraseña desde la sección heredada.
- [ ] Login Google sin intent funciona para un perfil activo existente.
- [ ] Google con el mismo correo verificado se vincula al Auth user existente sin duplicar profile.
- [ ] Vincular Google no sobrescribe identidad ni nombre canónico.
- [ ] Un email/password existente no queda bloqueado por carecer de identidad Google.
- [ ] `/auth/confirm` conserva intercambio OTP necesario para flujos heredados, sin activar perfiles pendientes automáticamente.

## Rechazos Auth y seguridad

- [ ] Signup futuro con provider email se rechaza sin Auth/profile huérfano.
- [ ] OAuth distinto de Google, provider ausente y metadata ambigua se rechazan con contrato estable.
- [ ] Metadata pública no puede solicitar cuenta técnica.
- [ ] `pending_registration` e `inactive` no entran a dashboard, actividades, perfil, catálogos o check-in.
- [ ] Cambiar correo Auth sólo sincroniza `profiles.email`.
- [ ] No hay Client ID/Secret, service role, cookies o tokens en Git, logs o UI.
- [ ] No se solicitan scopes elevados.

## Regresión y liberación

- [ ] Privacidad y ciclo de borradores de 0002/0003.
- [ ] Publicación, participantes, asistencia manual, QR/código y semestre.
- [ ] Acceso transitorio de `technical_admin` sin cambios.
- [ ] Ejecutar `0004_identity_registration_verify.sql` y confirmar `ROLLBACK`.
- [ ] Revisar rollback: no elimina Auth users, profiles ni identidades Google.
- [ ] Ejecutar `npm run check:text`, `npm run lint` y `npm run build`.
- [ ] Aplicar manualmente 0004, desplegar inmediatamente la app compatible y regenerar snapshot.
