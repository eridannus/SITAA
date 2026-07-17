# Configuración de Google OAuth para SITAA

**Estado:** Google Cloud y Supabase están configurados. Las migraciones 0004 y 0005, sus verificadores y los smoke tests de alta/finalización están aprobados. La Fase A está operativa.

No guardar Client ID, Client Secret, cookies ni tokens en el repositorio. Esta guía describe configuración operativa; no contiene secretos.

## Google Cloud

1. Crear o elegir un proyecto de Google Cloud.
2. Configurar la audiencia OAuth como **External**.
3. Solicitar únicamente identidad básica: `openid`, `email` y `profile`.
4. Crear un cliente OAuth de tipo **Web application**.
5. Copiar desde la pantalla del proveedor Google en Supabase la URI exacta de callback de Supabase y registrarla en **Authorized redirect URIs** de Google.
6. Guardar Client ID y Client Secret únicamente en la configuración del proveedor Google de Supabase.

No habilitar Gmail, Drive, Calendar ni scopes elevados. No configurar restricción de dominio ni validar el claim `hd`.

## Supabase Auth

- Habilitar Google e introducir sus credenciales sólo en Supabase.
- Mantener **Allow new users to sign up** habilitado.
- Mantener sign-ins anónimos deshabilitados.
- Mantener Email provider habilitado sólo para acceso heredado.
- SMTP no es requisito para el registro Google de Fase A.
- Site URL: `https://www.sitaa.net`.
- Redirect autorizado de producción: `https://www.sitaa.net/auth/callback`.
- Autorizar sólo callbacks locales o previews técnicos explícitamente aprobados, por ejemplo `http://localhost:3000/auth/callback` y el fallback documentado de Vercel.

La vinculación automática de identidades por correo verificado se administra en Supabase Auth. Debe probarse con una cuenta heredada antes de liberar producción.

## Aplicación y Vercel

- Production usa `NEXT_PUBLIC_SITE_URL=https://www.sitaa.net`.
- No crear variables `NEXT_PUBLIC_*` para secretos de Google.
- No enviar identificadores, programa o nombre institucional en `redirectTo`, `state` o URLs.
- El callback canónico es `/auth/callback`; la cookie temporal de tipo de registro es `HttpOnly`, contiene sólo `student` o `professor` y se limita a esa ruta.
- Los datos institucionales se capturan después de Google; no existe escritura anónima de registro ni endpoint de disponibilidad de identificadores.

## Criterios operativos

- Probar Gmail personal, `pcpuma.acatlan.unam.mx` y otro Workspace.
- Confirmar que no se envía correo de activación ni se requiere SMTP.
- Confirmar que cancelar consentimiento vuelve con error sanitizado.
- Confirmar que cuentas activas, inactivas y pendientes siguen rutas distintas.
- Confirmar que una cuenta compartida muestra advertencia, pero no se detecta ni bloquea automáticamente.
- La configuración External/Testing debe incluir expresamente las cuentas Gmail y `pc.puma` usadas como test users.
- 0005 permite que Supabase complete su secuencia OAuth aunque `email_confirmed_at` sea nulo durante el `INSERT`; la verificación final ocurre contra la identidad Google enlazada al completar el perfil.
- El snapshot `2026-07-17T23:20:07Z` reconcilia el resultado vivo de 0001–0005. No quedaron cuentas fallidas que requirieran limpieza.
