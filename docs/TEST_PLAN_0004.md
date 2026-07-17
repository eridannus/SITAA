# Plan de pruebas 0004: identidad y registro

**Estado:** listo para ejecución manual después de aplicar 0004 en un entorno de prueba.

**Restricción:** 0004 está creada pero no aplicada. No usar datos personales reales. Ejecutar primero `supabase/reconciliation/0004_identity_registration_preflight.sql` y resolver todas las categorías incompatibles.

## Preparación

- Configurar `NEXT_PUBLIC_SITE_URL=https://www.sitaa.net` en producción y los redirect URL de Supabase para producción y previews autorizados.
- Confirmar que la confirmación de correo está habilitada en Supabase Auth.
- Usar correos de prueba controlados e identificadores sintéticos sólo numéricos.
- Registrar el resultado sin copiar contraseñas, tokens ni identificadores completos.

## Registro de alumno

- [ ] `/register` distingue claramente registro de alumno y de profesor.
- [ ] `/register/student` acepta nombre, correo válido, contraseña coincidente, programa activo y número de cuenta sólo numérico.
- [ ] Un valor como `00123456` conserva los ceros iniciales.
- [ ] Letras, espacios, guiones y puntuación muestran error de campo.
- [ ] Un duplicado de `(student_account, valor)` se rechaza con mensaje sanitizado.
- [ ] El mismo valor existente como `worker_number` no causa conflicto.
- [ ] El formulario conserva nombre, correo, identificador y programa tras un error; no devuelve contraseñas desde el servidor.
- [ ] Se recibe el correo de verificación y se muestra “Revisa tu correo”.
- [ ] Confirmar el correo cambia `pending_verification` a `active` una sola vez.
- [ ] El alumno activo inicia sesión y ve su panel básico.
- [ ] No aparece “Nueva actividad” y `can_create_activity` devuelve falso sin asignación.
- [ ] No se crea automáticamente `student` ni `peer_tutor` en `role_assignments`.

## Registro de profesor

- [ ] `/register/professor` acepta número de trabajador sólo numérico y programa activo.
- [ ] `00004444` conserva ceros iniciales.
- [ ] Letras, espacios, guiones y puntuación se rechazan.
- [ ] Un duplicado de `(worker_number, valor)` se rechaza.
- [ ] Se completa verificación, activación e inicio de sesión.
- [ ] El perfil queda como `person_type=professor` e `identifier_type=worker_number`.
- [ ] No se crean roles de tutor, asesor, coordinación o comité.
- [ ] El profesor sin asignación no ve ni puede abrir el alta de actividades.
- [ ] Un usuario existente con asignación `professor` conserva su permiso actual.

## Exclusividad de identidad

- [ ] Un alumno no puede registrarse con `worker_number`.
- [ ] Un profesor no puede registrarse con `student_account`.
- [ ] Una cuenta institucional no puede ser simultáneamente alumno y profesor.
- [ ] `identifier_value` permanece `text` y nunca se convierte a número.
- [ ] El correo sigue siendo único y administrado por Supabase Auth.

## Cuenta técnica

- [ ] No existe una ruta pública para cuentas técnicas.
- [ ] `sitaa_registration_type=technical` en metadata pública se rechaza y no crea profile.
- [ ] El esquema admite una cuenta `technical` creada mediante `app_metadata` confiable, sin persona, programa o identificador.
- [ ] No se crea automáticamente ninguna cuenta técnica ni asignación `technical_admin`.
- [ ] El bootstrap futuro exige proceso administrativo: crear Auth con `app_metadata` controlada, verificar el profile técnico, asignar `technical_admin` por procedimiento auditado y probar transferencia. No usar el navegador ni una variable `NEXT_PUBLIC_*` para credenciales privilegiadas.

## Perfiles existentes y preflight

- [ ] Perfiles válidos sobreviven y `worker` se transforma determinísticamente a `professor`.
- [ ] `is_active=true` con correo confirmado se proyecta a `active`.
- [ ] `is_active=true` sin correo confirmado se proyecta a `pending_verification`.
- [ ] `is_active=false` se proyecta a `inactive`.
- [ ] Identificadores de prototipo como `TEST-ALUM-0001`, duplicados, no numéricos, perfiles incompletos o sin programa se reportan y detienen la migración.
- [ ] La remediación sustituye placeholders por valores sintéticos únicos sólo numéricos o recrea cuentas desechables; nunca debilita constraints ni limpia caracteres silenciosamente.
- [ ] Una asignación `technical_admin` existente no convierte automáticamente el perfil a cuenta técnica.

## Autenticación y ciclo de vida

- [ ] Un perfil pendiente no entra al panel normal y ve una pantalla de verificación pendiente.
- [ ] Un perfil inactivo no entra al panel normal y ve una pantalla de cuenta inactiva.
- [ ] Una confirmación posterior no reactiva un perfil `inactive`.
- [ ] Un enlace inválido o expirado muestra un error sanitizado.
- [ ] La callback funciona con `https://www.sitaa.net/auth/confirm`.
- [ ] Los dominios `vercel.app` configurados como preview regresan a su origen seguro cuando no existe `NEXT_PUBLIC_SITE_URL` de producción.
- [ ] El parámetro de retorno de login sigue aceptando sólo rutas internas.
- [ ] La revocación de sesiones Auth para cuentas inactivas permanece documentada para Fase B/0005.

## Autoservicio y seguridad

- [ ] `/profile` permite cambiar únicamente `full_name`.
- [ ] UPDATE directo de tipo de cuenta/persona, identificador, programa, estado, timestamps, email o roles se rechaza en base de datos.
- [ ] El correo sólo puede cambiar mediante Supabase Auth y su verificación.
- [ ] No existe autoasignación de roles.
- [ ] No aparece `service_role` en código cliente, bundles ni variables `NEXT_PUBLIC_*`.
- [ ] Los mensajes no exponen SQL, nombres de constraints, stack traces, tokens ni existencia de otra persona.
- [ ] Los formularios usan errores por campo, `aria-invalid`, `aria-describedby`, foco inicial, estado pendiente y diseño móvil.
- [ ] Nombres y correos largos ajustan su contenido sin invadir columnas.

## Regresión

- [ ] Privacidad y ciclo de borradores de 0002/0003.
- [ ] Publicación transaccional y validación temporal.
- [ ] Participantes registrados y roles de participante.
- [ ] Asistencia manual individual y masiva.
- [ ] QR, enlace, código, expiración y reapertura.
- [ ] Asignación automática de semestre.
- [ ] Roles y permisos actuales, incluido el acceso transitorio de `technical_admin`.
- [ ] UTF-8 mediante `npm run check:text`.
- [ ] Layout móvil de registro, login, panel y perfil.

## Verificación SQL y rollback

- [ ] Ejecutar `0004_identity_registration_verify.sql`; comprobar resultado y `ROLLBACK` final.
- [ ] Revisar manualmente el rollback; confirmar que se detiene sin `sitaa.rollback_0004_reviewed=yes`.
- [ ] No ejecutar rollback si existen cuentas técnicas sin plan de remediación.
- [ ] Confirmar que rollback no borra Auth users ni profiles.
