# Plan de pruebas 0004: Google OAuth e identidad institucional

**Estado:** listo para ejecución manual después de configurar Google y aplicar 0004 en prueba.

## Preflight y preparación

- [ ] Todas las categorías bloqueantes del preflight son cero.
- [ ] `legacy_email_password_user`, `existing_oauth_identity` y `possible_technical_operator` son informativas.
- [ ] Huérfanos Auth/profile y triggers inesperados permanecen en cero.
- [ ] Google cumple `GOOGLE_AUTH_SETUP.md`; producción permite `https://www.sitaa.net/auth/callback`.
- [ ] Email provider sigue habilitado sólo para acceso heredado; no existe signup público por contraseña.

## Inicio del registro

- [ ] `/register` ofrece rutas separadas de alumno y profesor.
- [ ] `/register/student` y `/register/professor` no solicitan nombre, identificador, programa, correo o contraseña antes de Google.
- [ ] Elegir alumno guarda sólo `student`; elegir profesor guarda sólo `professor` en cookie breve HttpOnly.
- [ ] La cookie no contiene PII y no aparece en URL, `state` o `localStorage`.
- [ ] Funcionan Gmail personal, `pc.puma` y otro Google Workspace, sin dominio obligatorio ni `hd`.
- [ ] Se muestra recomendación de cuenta personal y advertencia sobre cuentas compartidas.
- [ ] Cancelar consentimiento produce error sanitizado y permite reintentar.
- [ ] No se envía correo de activación ni se requiere SMTP.

## Callback y selección

- [ ] `/auth/callback` intercambia PKCE y no confía en identidad de query params.
- [ ] Perfil activo va al panel sin sobrescribir persona, identificador, programa o nombre.
- [ ] Perfil inactivo no se reactiva y va a estado de cuenta.
- [ ] Perfil pendiente con cookie `student` va a `/complete-registration/student`.
- [ ] Perfil pendiente con cookie `professor` va a `/complete-registration/professor`.
- [ ] Perfil pendiente sin cookie o con valor inválido va a `/complete-registration`.
- [ ] Iniciar Google directamente desde login, sin elección previa, permite escoger ruta después.
- [ ] Callbacks de producción, local y preview autorizado respetan el origen canónico.

## Finalización autenticada

- [ ] Las rutas de alumno y profesor usan formularios de tipo fijo, sin selector interno.
- [ ] Se preservan valores, errores por campo y foco del primer error; el flujo funciona en móvil.
- [ ] `student` deriva `student_account`; `professor` deriva `worker_number`.
- [ ] Se aceptan identificadores de 1 y 50 dígitos; 51 y caracteres no numéricos se rechazan.
- [ ] Los ceros iniciales se conservan.
- [ ] Nombre de 200 caracteres se acepta; 1 y 201 se rechazan.
- [ ] Programa inexistente o inactivo se rechaza y el perfil queda pendiente.
- [ ] Duplicado se rechaza sólo al usuario autenticado que completa su perfil.
- [ ] Perfil activo no se reescribe; perfil inactivo no se reactiva.
- [ ] Usuario sin identidad Google vinculada no completa el registro.
- [ ] Ningún registro crea `role_assignments`.
- [ ] No existe tabla de intents, RPC anónimo de registro ni endpoint de disponibilidad de identificador.

## Autorización y compatibilidad

- [ ] Perfil pendiente e inactivo no entra a paneles normales aunque tenga una asignación.
- [ ] Alumno y profesor activos sin roles no pueden crear actividades.
- [ ] Asignaciones actuales de profesor y tutor par conservan permisos.
- [ ] Bootstrap técnico confiable funciona y no recibe rol automático.
- [ ] Signup futuro con provider email, OAuth no Google, provider ausente y metadata ambigua se rechazan sin huérfanos.
- [ ] Usuario existente entra con correo/contraseña desde acceso heredado.
- [ ] Google con el mismo correo verificado se vincula sin duplicar ni sobrescribir el perfil.
- [ ] `/auth/confirm` conserva exclusivamente el intercambio OTP heredado necesario.

## Seguridad y liberación

- [ ] `anon` no puede ejecutar la finalización; `authenticated` sí.
- [ ] No hay PII institucional antes de autenticación ni enumeración anónima.
- [ ] No hay Client ID/Secret, `service_role`, cookies o tokens en Git, logs o UI.
- [ ] No se solicitan scopes elevados.
- [ ] Se conservan privacidad/ciclo de borradores de 0002/0003 y funciones de actividades/asistencia.
- [ ] Ejecutar el verificador y confirmar `ROLLBACK`.
- [ ] Revisar rollback: no elimina Auth users, profiles ni identidades Google y no usa `CASCADE`.
- [ ] Ejecutar `npm run check:text`, `npm run lint` y `npm run build`.
- [ ] Aplicar manualmente 0004, desplegar inmediatamente la app compatible y regenerar snapshot.
