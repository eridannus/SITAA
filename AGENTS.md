# Guía para agentes y colaboradores

## Propósito

Este repositorio corresponde a **SITAA (Sistema Integral de Tutorías y Asesorías Académicas)**. Contiene una aplicación Next.js en evolución, documentación funcional y migraciones Supabase reconciliadas.

## Fuente de verdad

Antes de proponer o implementar cambios, revisar:

1. `docs/PROJECT_BRIEF.md`
2. `docs/MVP.md`
3. `docs/DATA_MODEL.md`
4. `docs/ROLES_AND_PERMISSIONS.md`
5. `docs/SECURITY_NOTES.md`
6. `docs/DECISIONS.md`
7. `docs/IDENTITY_AND_REGISTRATION.md`
8. `docs/ROLES_AND_PERMISSIONS_V2.md`
9. `docs/USER_ACCOUNT_ADMINISTRATION.md`
10. `docs/FILTERING_AND_VISIBILITY.md`
11. `docs/GOOGLE_AUTH_SETUP.md` para cambios de autenticación o despliegue OAuth.
12. `docs/DESIGN_SYSTEM.md` para cualquier interfaz o cambio visual.

Para preparar 0004 o cambios de identidad/autorización, revisar también `docs/IMPLEMENTATION_GAPS_0004.md`. `docs/ROLES_AND_PERMISSIONS.md` conserva reglas operativas implementadas, pero su catálogo futuro y matriz de asignación están parcialmente sustituidos por la versión V2.

Si un cambio altera el alcance, el modelo de datos, los permisos o la arquitectura, actualizar primero la documentación relacionada y registrar la decisión en `docs/DECISIONS.md`.

## Reglas de trabajo

- Usar español en documentación, interfaz y mensajes dirigidos al usuario, salvo nombres técnicos inevitables.
- Todo texto visible en español debe guardarse como UTF-8; no reemplazar acentos, eñes ni signos de apertura con `?`.
- Después de editar textos de interfaz o documentación en español, ejecutar `npm run check:text`.
- Mantener TypeScript en modo estricto.
- Diseñar para Next.js con App Router, Tailwind CSS y Supabase.
- Aplicar autorización en la base de datos mediante Row Level Security (RLS); ocultar controles en la interfaz no cuenta como autorización.
- Tratar los datos académicos y personales como información sensible.
- Mantener los cambios pequeños, verificables y documentados.
- No incluir secretos, credenciales, datos reales de estudiantes ni archivos de entorno en Git.
- No añadir dependencias, servicios de pago o complejidad arquitectónica sin justificarlo en `docs/DECISIONS.md`.

## Interfaz obligatoria

- `docs/DESIGN_SYSTEM.md` es la fuente canónica de color, componentes, estados e interacción.
- Usar tokens y primitivas semánticas existentes antes de crear estilos nuevos; nunca introducir branding `emerald-*`.
- Usar verde sólo mediante el contrato semántico de éxito y especificar siempre foreground y background de controles rellenos.
- Auditar responsive, wrapping, foco visible, teclado y objetivos táctiles después de todo cambio visual.
- Ejecutar `npm run check:ui` y `npm run check:text` al modificar UI.

## Estado actual

La aplicación y las migraciones `0001`–`0007` existen, están aplicadas, verificadas y reconciliadas contra el snapshot `2026-07-21T00:16:03Z`, sin deriva inexplicada. `0006_structured_person_names.sql` mantiene `full_name` como compatibilidad derivada y `0007_admin_account_directory_audit.sql` es inmutable. `0008_operational_account_barrier_identity_correction.sql` fue aplicada y su verificador final aprobó con `ROLLBACK`; es inmutable. La corrección de identidad y auditoría sanitizada aprobó en producción, pero un smoke test detectó una composición de permisos exclusiva de aplicación para responsables históricos entre programas. Su corrección y reejecución están pendientes, al igual que el snapshot y la reconciliación post-0008. El snapshot vigente sigue representando post-0007. `0009` es el siguiente número disponible, pero no se requiere para este defecto de aplicación. B.2b, B.3 y Fase C permanecen pendientes. No modificar ninguna migración aplicada ni conectarse a Supabase sin autorización expresa.

Todo acceso a datos de otras cuentas y toda mutación administrativa u operativa debe tener autorización explícita en la base de datos. No se debe confiar en controles ocultos, en el estado del JWT ni en una comprobación exclusiva de la aplicación.

La Fase A está implementada y operativa: usa Google OAuth para registro público, sin restricción de dominio ni scopes elevados. El acceso por correo/contraseña es sólo heredado. La identidad institucional se captura únicamente después de autenticar; no introducir signup público por contraseña, PII preautenticación, endpoints anónimos de disponibilidad, secretos OAuth, datos institucionales en URLs o `localStorage`, ni lógica que confíe en email como llave primaria.

- Usar "sólo" con tilde cuando significa "solamente"; usar "solo" sin tilde únicamente cuando significa "sin compañía".
