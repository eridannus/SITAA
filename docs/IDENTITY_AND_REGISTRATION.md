# Identidad y registro

**Estado funcional:** Fase A implementada y operativa. 0004, 0005 y 0006 están aplicadas, verificadas y reconciliadas. Los nombres estructurados son el contrato vivo y `full_name` permanece como compatibilidad derivada.

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
- `first_names` y `paternal_surname` admiten 1–150 caracteres normalizados; `maternal_surname` es opcional y usa el mismo límite.
- `full_name` permanece como valor derivado de compatibilidad y no se captura como un campo único desde 0006.
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
5. El usuario autenticado captura nombre(s), apellido paterno, apellido materno opcional, identificador y programa en un formulario de tipo fijo.
6. `complete_own_google_registration` exige una identidad `auth.identities` Google enlazada, correo coincidente y verificación final; después valida perfil pendiente, formato, programa y unicidad, actualiza el mismo perfil transaccionalmente y no crea roles.

Los nombres canónicos instalados son `on_sitaa_auth_user_created` para el alta `AFTER INSERT` y `on_sitaa_auth_user_email_changed` para sincronizar `AFTER UPDATE OF email` únicamente cuando `OLD.email IS DISTINCT FROM NEW.email`. Las migraciones posteriores deben preservarlos y verificar su contrato semántico, no sustituirlos por nombres genéricos ni inferir equivalencia sólo por la existencia de algún trigger.

No existe tabla de intents, escritura anónima de registro, consulta pública de disponibilidad ni PII institucional antes de Google. La duplicidad del identificador sólo se comunica al usuario autenticado que completa su propio perfil.

### Login Google sin elección previa

Un perfil activo va al panel; uno inactivo va al estado de cuenta; uno pendiente sin cookie válida va a `/complete-registration` para elegir alumno o profesor. Un perfil activo nunca se reescribe desde el callback.

### Cuenta técnica

Sólo un proceso administrativo confiable puede fijar `app_metadata.sitaa_account_kind=technical`. Requiere correo confirmado y nombre(s) estructurado; los apellidos son opcionales. Durante la transición, metadata confiable `sitaa_full_name` puede poblar `first_names` completo sin intentar dividirlo. No crea identidad académica ni rol y metadata pública no puede solicitarla.

## Contrato de nombres 0006

Los campos estructurados son autoritativos y `full_name` se reconstruye en la base. Se recortan extremos y se colapsan espacios repetidos, conservando Unicode, acentos y apóstrofes. No se adivinaron límites de apellido a partir de nombres completos históricos: el preflight aprobado exigió que las cuentas activas tuvieran una correspondencia revisada fuera de archivos versionados antes de aplicar 0006.

Para orden alfabético futuro se usa apellido paterno, apellido materno y nombre(s), en ese orden. Los reportes y exportaciones futuros mostrarán tres columnas separadas; continúan fuera del alcance de 0006.

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

Las primeras pruebas reales posteriores a 0004 confirmaron `sitaa_google_email_not_verified` durante el `INSERT` de `auth.users`: Supabase aún no había fijado `email_confirmed_at`. La transacción se revirtió completamente y no dejó usuarios, identidades ni perfiles que limpiar. 0005 eliminó esa comprobación sólo del trigger Google y reforzó la verificación durante la finalización autenticada. Su preflight, aplicación, verificador transaccional y smoke tests reales fueron aprobados; el snapshot posterior quedó reconciliado sin deriva inexplicada.

## Cierre de Fase A

La Fase A comprende registro público sólo con Google, rutas separadas para alumno y profesor, perfil mínimo `pending_registration`, finalización institucional autenticada, activación básica automática, identificadores de dígitos almacenados como texto, ausencia de roles automáticos, soporte de cuenta técnica, guardas para excluir cuentas autenticadas del registro público y acceso heredado por correo/contraseña. No depende de SMTP ni restringe dominios.

Durante el cierre se separaron administrativamente una cuenta técnica interna y una cuenta académica de profesor. La cuenta técnica conserva únicamente su identidad técnica y la asignación `technical_admin`; una asignación académica temporal quedó inactiva. La cuenta académica se registró normalmente con Google y no recibió roles. No se transfirieron actividades ni historia. Esta limpieza inicial no constituye fusión de cuentas ni una migración reutilizable.

Fase B.1, B.2a y B.2b están cerradas. Permanecen abiertas B.3, roles V2/Fase C, paneles y filtros posteriores, retiro del acceso académico transitorio de `technical_admin` y check-in abierto.

## Corrección administrativa implementada en B.2a

El autoservicio autenticado continúa limitado a `first_names`, `paternal_surname` y `maternal_surname` propios. B.2a implementa mediante 0008 una RPC distinta para que un administrador B.1 exacto corrija la identidad estable de otra cuenta activa o inactiva con motivo y auditoría. La capacidad fue verificada, probada y reconciliada contra el snapshot `2026-07-22T01:46:13Z`.

En cuentas institucionales puede corregir nombres, `person_type`, identificador y programa activo; en cuentas técnicas, sólo nombres. UUID, email, `account_kind`, `account_status`, `is_active`, fechas de ciclo de vida, vínculo Auth, roles e historia son inmutables. Las cuentas `pending_registration` deben completar su propio flujo y no son objetivos de corrección administrativa.

La entrada administrativa colapsa tabs, saltos de línea y espacios repetidos, recorta el resultado y convierte vacío en `NULL`. El nombre completo derivado debe medir 2–200 caracteres para cuentas institucionales y técnicas; el tipo institucional debe ser explícitamente `student` o `professor`. Las dependencias de tipo y programa se deciden bajo un orden fijo de locks para impedir cambios concurrentes que crucen la validación.

## Ciclo de vida administrativo B.2b implementado

Desactivar o reactivar no cambia la identidad canónica, el correo, el UUID, `account_kind`, los identificadores, el programa ni las asignaciones. Una cuenta `pending_registration` continúa exclusivamente en su flujo propio. Para reactivar, el estado inactivo debe conservar el `activated_at` original y tener `deactivated_at`; la identidad debe seguir completa y coherente con su clase, el programa institucional debe estar activo, debe existir exactamente la correspondencia Auth/profile esperada y el correo de acceso debe estar confirmado.
