# Evidencia AUTH-01 — lanzamiento público de Google OAuth

## Alcance y fecha

- Fecha: 2026-08-07.
- Este documento registra el checkpoint de preparación para el lanzamiento público de OAuth.
- El ticket que creó este checkpoint fue exclusivamente documental y no realizó acciones remotas.

## Configuración de producción sanitizada

- La audiencia está configurada como **External** y el estado de publicación es **In production**.
- La identidad pública configurada es **SITAA**; la marca fue verificada y se muestra a las personas usuarias junto con el logotipo de la aplicación.
- La propiedad de `sitaa.net` está verificada en Search Console y el registro DNS de verificación permanece presente, sin conservar aquí su valor.
- La configuración de dominios autorizados incluye `sitaa.net` y el dominio de callback administrado por el proveedor, sin registrar su hostname completo.
- La página pública de la aplicación es `https://www.sitaa.net/acerca-de`.
- El aviso de privacidad público es `https://www.sitaa.net/privacidad`.
- No se configuró una página específica de términos de servicio para la aplicación.
- Data Access contiene exactamente `openid`, `userinfo.email` y `userinfo.profile`.
- Scopes sensibles: **0**.
- Scopes restringidos: **0**.

## Smoke test de producción sanitizado

Una identidad de Google que nunca había pertenecido a la lista anterior de usuarios de prueba completó el recorrido de producción:

- llegó al selector de cuenta y consentimiento con nombre y logotipo de SITAA;
- no recibió advertencia de aplicación no verificada;
- Google solicitó únicamente nombre e imagen de perfil, cuando está disponible, y correo electrónico;
- completó de forma autenticada el perfil institucional de alumno;
- produjo exactamente un perfil institucional activo;
- recibió cero asignaciones de rol automáticas;
- pudo abrir Inicio, Actividades y Perfil;
- su navegación ordinaria no mostró accesos a Catálogos ni Cuentas;
- observó el estado vacío correcto de actividades porque no tenía asignación como participante;
- conservó el autoservicio limitado a sus nombres personales estructurados;
- encontró en el selector público de registro la acción `← Volver al inicio de sesión`, dirigida a `/login`;
- no encontró en el dashboard autenticado la nota temporal de desarrollo sobre paneles especializados futuros.

Este recorrido validó la navegación ordinaria, pero no repitió intentos directos por URL contra Catálogos o Cuentas. Esas guardas pertenecen al contrato de autorización previamente aprobado y no a la evidencia específica de este smoke test de `AUTH-01`.

La identidad, la persona, el dominio de correo y el identificador institucional usados en la prueba no se registran en este checkpoint.

## Observaciones de seguridad

- SITAA no solicitó scopes de Gmail, Drive, Calendar, Contacts ni archivos.
- No apareció una advertencia de aplicación no verificada.
- Los datos institucionales se recopilaron sólo después de autenticar con Google.
- El registro público no concedió autoridad académica ni administrativa.
- Este checkpoint no capturó secretos, tokens, códigos, cookies, screenshots ni respuestas crudas de Google o Supabase.

## Aceptación

`AUTH-01` está aprobado y cerrado dentro de su alcance definido de OAuth público.

## Regresiones residuales de PILOT-01

Las siguientes variaciones permanecen como regresiones explícitas de `PILOT-01`, no como bloqueos para el cierre de `AUTH-01`:

- cuenta Gmail de consumidor;
- cuenta Google `pc.puma` / UNAM;
- otra organización institucional de Google Workspace, cuando esté disponible;
- cancelación del consentimiento;
- retorno después de un rechazo por política organizacional;
- inicio de sesión repetido después de completar un registro existente.
