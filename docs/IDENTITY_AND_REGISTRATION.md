# Identidad y registro

**Estado funcional:** Fase A implementada localmente; migración 0004 pendiente de aplicación y Google pendiente de configuración.

## Principio

Google autentica la cuenta. SITAA conserva la identidad institucional y la autorización. La llave común es `auth.users.id`; no se usa el correo como llave primaria ni se duplica el `sub` de Google en `profiles`. Los proveedores vinculados permanecen en `auth.identities`.

## Acceso público y heredado

- El registro público usa exclusivamente Google OAuth mediante Supabase Auth.
- Se aceptan Gmail personal, Google Workspace, `pc.puma` y cuentas institucionales de oficina.
- No se restringen dominios ni se inspecciona `hd`.
- Sólo se usa la identidad básica `openid`, `email`, `profile`; no se solicitan Gmail, Drive, Calendar ni otros scopes.
- La interfaz recomienda una cuenta personal controlada individualmente. Una cuenta compartida reduce trazabilidad, pero no se bloquea automáticamente.
- El login con correo y contraseña permanece como acceso secundario heredado para usuarios existentes. No existe alta pública por contraseña ni dependencia SMTP en esta fase.
- Supabase puede vincular Google automáticamente a una identidad existente con el mismo correo verificado; SITAA no crea otro perfil ni sobrescribe identidad institucional.

## Categorías y estados

| Cuenta | Estados | Identidad institucional |
| --- | --- | --- |
| `institutional` | `pending_registration`, `active`, `inactive` | Obligatoria al activar |
| `technical` | `active`, `inactive` | No aplica |

`pending_registration` significa que Google creó un Auth user y un perfil mínimo, pero aún faltan tipo de persona, identificador y programa. Conserva `is_active=false` y timestamps de activación/desactivación nulos. No puede entrar a paneles normales.

`active` exige perfil completo, `is_active=true`, `activated_at` y ningún `deactivated_at`. `inactive` conserva la historia, usa `is_active=false` y requiere `deactivated_at`. Una cuenta inactiva no se reactiva al volver a Google.

## Identidad institucional

- `student` deriva `student_account`.
- `professor` deriva `worker_number`.
- El identificador se guarda como texto de 1–50 dígitos y conserva ceros iniciales.
- `full_name` normalizado admite 2–200 caracteres.
- El correo verificado de Google se normaliza en minúsculas y admite hasta 254 caracteres.
- El programa principal debe existir y estar activo.
- La unicidad es por `(institutional_id_type, institutional_id_value)`.
- Alumno/profesor, identificador, programa y roles no provienen de Google.
- Un nuevo alumno o profesor no recibe roles; `role_assignments` permanece separado.

## Registration intent

Antes de enviar al usuario a Google, SITAA valida nombre, tipo, identificador y programa mediante `create_registration_intent`. Guarda únicamente una huella SHA-256 del token opaco, con expiración de 15 minutos y consumo único. El token crudo:

- se entrega sólo al servidor Next.js;
- se guarda temporalmente en cookie `HttpOnly`, `SameSite=Lax`, segura en producción;
- no contiene PII;
- no aparece en query params ni `localStorage`;
- nunca se persiste en texto claro.

`registration_intents` tiene RLS habilitado y ningún acceso directo para `anon` o `authenticated`. El callback consume el intent mediante `complete_own_google_registration`, que vuelve a validar identidad, programa, unicidad, vigencia, Google verificado y perfil pendiente dentro de una transacción.

## Flujos

### Registro nuevo

1. `/register/student` o `/register/professor` captura sólo datos institucionales.
2. El servidor crea el intent y su cookie.
3. Supabase inicia Google OAuth con callback `/auth/callback`.
4. El trigger crea exactamente un perfil mínimo `pending_registration` para un Auth user Google nuevo.
5. El callback intercambia el código y consume el intent.
6. El perfil se completa y activa sin crear roles.

Si el OAuth se abandona o el intent expira, el perfil permanece pendiente. `/complete-registration` permite capturar nuevamente los datos y completar el mismo perfil sin repetir Google.

### Login Google

No requiere intent. Perfil activo va al panel; inactivo va al estado de cuenta; pendiente va a completar registro. Un intent obsoleto nunca modifica un perfil activo.

### Cuenta técnica

Sólo un proceso administrativo confiable puede fijar `app_metadata.sitaa_account_kind=technical`. Requiere correo confirmado y nombre válido, no crea identidad académica ni rol automático. Metadata pública no puede solicitarla.

## Invariantes de seguridad

- Cada Auth user tiene exactamente un perfil SITAA.
- Google nuevo, bootstrap técnico o rechazo atómico son los únicos caminos futuros.
- Signup público con correo/contraseña, OAuth no soportado, metadata ausente o ambigua abortan sin huérfanos.
- Cambios de correo Auth sincronizan sólo `profiles.email`; no cambian nombre canónico, persona, programa, identificador o roles.
- El callback no confía en identidad recibida por query params.
- No se envían identificadores institucionales a Google.
- No se almacenan secretos OAuth en Git, Vercel público ni el navegador.

## Aplicación de 0004

0004 permanece sin aplicar. El preflight debe seguir en cero para categorías bloqueantes. Usuarios heredados por correo/contraseña y OAuth existentes son informativos; no se exige Google a perfiles actuales. Tras configurar Google según `GOOGLE_AUTH_SETUP.md`: aplicar 0004 manualmente, desplegar la aplicación compatible, ejecutar el verificador y regenerar el snapshot.
