# Configuración de Google OAuth para SITAA

**Estado:** Google Cloud y Supabase están configurados. Las migraciones 0004 y 0005, sus verificadores y los smoke tests de alta/finalización están aprobados. La Fase A está operativa.

No guardar Client ID, Client Secret, cookies ni tokens en el repositorio. Esta guía describe configuración operativa; no contiene secretos.

## Google Cloud

1. Crear o elegir un proyecto de Google Cloud.
2. Configurar la audiencia OAuth como **External**.
3. Solicitar únicamente identidad básica: `openid`, `userinfo.email` y `userinfo.profile`.
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

## Publicación pública a producción

**Estado:** `AUTH-01` cerrado. Google OAuth público usa audiencia **External**, está **In production** y completó un recorrido de registro en producción con una identidad que nunca perteneció a la lista anterior de usuarios de prueba.

Estado manual observado y aprobado para este checkpoint:

- Audience: **External**.
- Publishing status: **In production**.
- La marca está verificada, se muestra a las personas usuarias e incluye la identidad y el logotipo de SITAA.
- La propiedad de `sitaa.net` está verificada en Search Console y el registro DNS de verificación permanece presente.
- La página pública `https://www.sitaa.net/acerca-de` y el aviso `https://www.sitaa.net/privacidad` están desplegados.
- No se configuró una página específica de términos de servicio para este alcance.
- Un cliente **Web application** de producción, con origen JavaScript y callback Supabase de producción configurados.
- El cliente de producción no contiene URI local, Preview ni LAB.
- Data Access solicita únicamente `openid`, `userinfo.email` y `userinfo.profile`.
- Cero scopes sensibles y cero scopes restringidos.
- Ningún scope o API de Gmail, Drive, Calendar u otro producto Google.
- Un registro completo de producción produjo un perfil institucional de alumno activo y cero asignaciones de rol automáticas.
- La evidencia sanitizada de cierre está en `docs/AUTH_01_PUBLIC_OAUTH_EVIDENCE.md`.

- [x] Auditar **Audience**, **Branding**, **Data Access** y **OAuth Clients** en Google Cloud.
- [x] Confirmar que sólo se solicitan `openid`, `userinfo.email` y `userinfo.profile`.
- [x] Confirmar cero scopes sensibles y cero scopes restringidos.
- [x] Revisar la separación entre producción y pruebas del cliente OAuth.
- [x] Desplegar y verificar manualmente `/acerca-de` y `/privacidad` en producción.
- [x] Verificar la propiedad de `sitaa.net` mediante Search Console y conservar el registro DNS correspondiente.
- [x] Completar los campos de **Branding**, cargar el logotipo y comprobar que la marca verificada se muestra.
- [x] Publicar la aplicación para audiencia de producción.
- [x] Completar un recorrido de registro en producción con una identidad que nunca fue usuario de prueba, conforme a DEC-065.
- [x] Decidir que no se requiere una página de términos para el lanzamiento inicial.
- [x] Confirmar nuevamente que no se añadió Gmail, Drive, Calendar ni otro scope o API de Google.

Los requisitos, nombres de pantallas y procesos de verificación de Google pueden cambiar. Antes de ejecutar cada paso deben contrastarse nuevamente con la documentación oficial vigente; esta lista no sustituye esa revisión.

## Criterios operativos

Las variaciones de cuenta y recuperación permanecen como regresiones de `PILOT-01`, no como bloqueos de `AUTH-01`:

- probar una cuenta Gmail de consumidor;
- probar una cuenta Google `pc.puma` / UNAM;
- probar otra organización institucional de Workspace cuando esté disponible;
- cancelar el consentimiento y comprobar el retorno con error sanitizado;
- comprobar el retorno después de un rechazo por política organizacional;
- repetir el inicio de sesión después de completar un registro existente.

- Confirmar que no se envía correo de activación ni se requiere SMTP.
- Confirmar que cuentas activas, inactivas y pendientes siguen rutas distintas.
- Confirmar que una cuenta compartida muestra advertencia, pero no se detecta ni bloquea automáticamente.
- 0005 permite que Supabase complete su secuencia OAuth aunque `email_confirmed_at` sea nulo durante el `INSERT`; la verificación final ocurre contra la identidad Google enlazada al completar el perfil.
- El snapshot `2026-07-17T23:20:07Z` reconcilia el resultado vivo de 0001–0005. No quedaron cuentas fallidas que requirieran limpieza.
