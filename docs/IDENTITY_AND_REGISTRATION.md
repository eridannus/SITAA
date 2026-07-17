# Identidad y registro

**Estado funcional:** 0004 aplicada. Google configurado. 0005 creada y pendiente de aplicación para corregir el orden real del alta OAuth.

## Principio

Google autentica la cuenta. SITAA conserva identidad institucional y autorización. La llave común es `auth.users.id`; el correo no es llave primaria y el `sub` de Google no se duplica en `profiles`. Las identidades vinculadas permanecen en `auth.identities`.

## Acceso público y heredado

- El registro público usa exclusivamente Google OAuth mediante Supabase Auth.
- Se aceptan Gmail personal, Google Workspace, `pc.puma` y cuentas institucionales de oficina, sin restricción de dominio ni inspección de `hd`.
- Sólo se solicita identidad básica `openid`, `email`, `profile`.
- La interfaz recomienda una cuenta individual; una cuenta compartida reduce trazabilidad, pero no se bloquea automáticamente.
- El login correo/contraseña permanece como acceso heredado para usuarios existentes. No hay alta pública por contraseña ni dependencia SMTP.
- Supabase puede vincular Google a una identidad existente con el mismo correo verificado sin crear otro perfil ni sobrescribir identidad SITAA.

## Categorías y estados

| Cuenta | Estados | Identidad institucional |
| --- | --- | --- |
| `institutional` | `pending_registration`, `active`, `inactive` | Obligatoria al activar |
| `technical` | `active`, `inactive` | No aplica |

`pending_registration` indica que Google creó un Auth user y un perfil mínimo, pero faltan persona, identificador y programa. Usa `is_active=false`, sin timestamps de activación/desactivación, y no entra a paneles normales.

`active` exige perfil completo, `is_active=true`, `activated_at` y ningún `deactivated_at`. `inactive` conserva historia, usa `is_active=false` y requiere `deactivated_at`; volver a Google no reactiva la cuenta.

## Identidad institucional

- `student` deriva `student_account`; `professor` deriva `worker_number`.
- El identificador se guarda como texto de 1–50 dígitos y conserva ceros iniciales.
- `full_name` normalizado admite 2–200 caracteres.
- El correo verificado de Google se normaliza en minúsculas y admite hasta 254 caracteres.
- El programa principal debe existir y estar activo.
- La unicidad es por `(institutional_id_type, institutional_id_value)`.
- Persona, identificador, programa y roles no provienen de Google.
- Un nuevo alumno o profesor no recibe roles; `role_assignments` permanece separado.

## Flujo aprobado

1. `/register/student` o `/register/professor` inicia Google OAuth sin solicitar PII institucional.
2. El servidor guarda sólo `student` o `professor` en una cookie breve `HttpOnly`, `SameSite=Lax` y segura en producción. Es una pista de UX, no autorización.
3. El trigger crea exactamente un perfil mínimo `pending_registration` para un Google nuevo, aunque `email_confirmed_at` todavía sea nulo durante el `INSERT` inicial de Auth.
4. `/auth/callback` intercambia PKCE y dirige a `/complete-registration/student`, `/complete-registration/professor` o al selector `/complete-registration`.
5. El usuario autenticado captura nombre, identificador y programa en un formulario de tipo fijo.
6. `complete_own_google_registration` exige una identidad `auth.identities` Google enlazada, correo coincidente y verificación final; después valida perfil pendiente, formato, programa y unicidad, actualiza el mismo perfil transaccionalmente y no crea roles.

No existe tabla de intents, escritura anónima de registro, consulta pública de disponibilidad ni PII institucional antes de Google. La duplicidad del identificador sólo se comunica al usuario autenticado que completa su propio perfil.

### Login Google sin elección previa

Un perfil activo va al panel; uno inactivo va al estado de cuenta; uno pendiente sin cookie válida va a `/complete-registration` para elegir alumno o profesor. Un perfil activo nunca se reescribe desde el callback.

### Cuenta técnica

Sólo un proceso administrativo confiable puede fijar `app_metadata.sitaa_account_kind=technical`. Requiere correo confirmado y nombre válido; no crea identidad académica ni rol. Metadata pública no puede solicitarla.

## Invariantes de seguridad

- Cada Auth user tiene exactamente un perfil SITAA.
- Google nuevo, bootstrap técnico o rechazo atómico son los únicos caminos futuros.
- Signup público por contraseña, OAuth no soportado y metadata ausente o ambigua abortan sin huérfanos.
- No hay operación anónima que escriba PII o revele si existe un número institucional.
- El RPC de finalización exige `auth.uid()` y Google verificado, y sólo tiene `EXECUTE` para `authenticated`.
- Cambios de correo Auth sincronizan sólo `profiles.email`.
- El callback no confía en query params para persona o identidad.
- No se envían identificadores, programa o nombre a Google, URLs, `state` o `localStorage`.
- No se almacenan secretos OAuth en Git, variables públicas ni navegador.

## Corrección 0005

0004 ya está aplicada. Las primeras pruebas reales confirmaron `sitaa_google_email_not_verified` durante el `INSERT` de `auth.users`: Supabase aún no había fijado `email_confirmed_at`. La transacción se revirtió completamente y no dejó usuarios, identidades ni perfiles que limpiar. 0005 elimina esa comprobación sólo del trigger Google y la hace más fuerte durante la finalización autenticada. Antes de aplicarla: aprobar preflight, revisar migración/rollback, aplicar manualmente, ejecutar verificador y regenerar snapshot.
