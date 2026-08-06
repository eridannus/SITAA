# Evidencia 0010 — Auditoría productiva de ausencia de secretos

## 1. Alcance

Este checkpoint documenta la auditoría de seguridad productiva del caso 19 de B.3a sobre el commit exacto `5df156ec0616da8823f6f13be41c2df11ea85537`, rama `main`, mediante la versión `2026-08-06-case19-v1`.

La auditoría no mutó producción, no autenticó usuarios, no operó Supabase, PostgreSQL, Auth Admin ni la Edge Function y no ejecutó un arnés Hosted Auth. El caso 19 quedó aprobado. Este documento no cierra B.3a ni sustituye los smoke tests o la reconciliación post‑0010 pendientes.

## 2. Fuentes de evidencia

La evidencia aprobada combina:

- observación por el operador de los nombres y alcances de variables de entorno en Vercel, sin revelar valores;
- observación por el operador de agregados de logs exclusivamente de Production;
- auditoría automatizada de artefactos de producción locales y de recursos productivos obtenidos mediante HTTP anónimo.

Las capturas de pantalla, los valores de variables, los recursos descargados, los extractos de bundles o source maps y las salidas temporales de auditoría no se versionan.

## 3. Variables de entorno en Vercel

| Variable pública | Alcance observado |
| --- | --- |
| `NEXT_PUBLIC_SITE_URL` | Production |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Production y Preview |
| `NEXT_PUBLIC_SUPABASE_URL` | Production y Preview |

- Variables compartidas: 0.
- Nombres visibles de variables privilegiadas o de base de datos: 0.
- Los valores nunca fueron revelados ni copiados.

No se observó ningún nombre que indicara credenciales `service_role`, secretos de Supabase, credenciales PostgreSQL, URI de Session pooler o base de datos, contraseña de base de datos, clave Auth Admin o variable temporal del arnés B.3a.

## 4. Logs de Production

El operador seleccionó Production, excluyó Preview y observó la última hora. El agregado fue:

| Categoría | Resultado |
| --- | ---: |
| Solicitudes Production | 7 |
| HTTP 200 | 7 |
| `GET /` | 3 |
| `GET /register` | 4 |
| Warning / Error / Fatal | 0 / 0 / 0 |
| Messages | Vacío |

No se observó correo, UUID, JWT, access token, refresh token, cookie, cabecera `Authorization`, motivo administrativo, payload del proveedor, clave, URI de base de datos, contraseña ni metadata sensible. El checkpoint omite deliberadamente hostnames y timestamps de solicitudes.

## 5. Artefactos locales de producción

- Commit fuente: `5df156ec0616da8823f6f13be41c2df11ea85537`.
- Build local de producción: aprobado.
- Artefactos locales de navegador: 22 archivos, 958637 bytes.
- Artefactos locales de servidor revisados: 532 archivos, 31959047 bytes.
- Archivos de primera parte revisados bajo `app/`, `components/`, `lib/` y el límite proxy/middleware: 96.
- Referencias de primera parte a claves privilegiadas, URI de base de datos, `auth.admin` o uso de `service_role`: 0.

El primer intento de `npm run build` fue bloqueado por el sandbox de Codex cuando Next.js intentó escribir `.next/trace-build`. Fue una restricción del entorno de ejecución, no un fallo de SITAA. Una repetición autorizada terminó con código 0, aprobó Next.js, TypeScript y todos los checkers integrados, preservó `.next/static` y dejó cero cambios tracked o staged; `package.json` y `package-lock.json` permanecieron intactos.

Los source maps de servidor contenían 280 apariciones literales de `service_role` y 8 de `SUPABASE_SECRET_KEY`. Todas pertenecían a texto de dependencias, sin valor asociado, ocurrencia en fuentes de primera parte, JavaScript de navegador o recurso remoto. Estos conteos son literales de dependencias revisados, no hallazgos ni filtraciones.

## 6. Recursos productivos remotos

- Rutas productivas revisadas: 14.
- Respuestas de contenido de rutas: 14, 199327 bytes.
- Recursos estáticos remotos: 12, 702568 bytes.
- Recursos JavaScript remotos: 11.

La captura automatizada utilizó únicamente solicitudes HTTPS anónimas `GET`/`HEAD`. No envió cookies, cabeceras `Authorization`, formularios ni sesiones. El checkpoint no conserva hostnames, recursos descargados ni contenido de respuestas.

## 7. Hallazgos de seguridad

| Clasificador | Resultado |
| --- | ---: |
| JWT privilegiados | 0 |
| Secretos prohibidos | 0 |
| Clientes privilegiados de primera parte | 0 |
| JWT públicos `anon` literales | 0 |
| Claves públicas clasificadas | 0 |
| URL de proyecto clasificadas | 0 |

Los tres ceros del clasificador de credenciales públicas significan que no hubo coincidencias literales en los artefactos auditados. No significan que estén ausentes las variables públicas de Vercel verificadas separadamente. La configuración pública de Supabase está permitida; el criterio de aprobación fue la ausencia de material privilegiado o de sesión de usuario.

Ninguna aparición de dependencia tuvo un valor de secreto asociado. Por ello, los literales de source maps no se clasificaron como filtraciones.

## 8. Integridad y limpieza

- `npm run check:auth-lifecycle`: código 0, `Límite confiable Auth B.3a: OK`.
- `npm run check:text`: código 0, `Integridad de texto: OK`.
- `git diff --check`: código 0 y salida vacía.
- Estado Git final de la auditoría: idéntico byte por byte al inicial.
- Cambios tracked o staged producidos por la auditoría: 0 / 0.
- Runtime temporal de auditoría: ausente.
- Helper temporal y recursos descargados: ausentes.
- Operaciones remotas de mutación, autenticación u operación Supabase: 0.
- Commit o push: 0.

## 9. Estado del caso

- Caso 19: aprobado.
- Caso 20: parcial.
- Smoke tests de producción de la interfaz desplegada: pendientes.
- Snapshot canónico y reconciliación post‑0010: pendientes.
- B.3a: abierta.
- Migración 0011: no debe crearse.
- El proyecto desechable de la matriz debe permanecer disponible hasta el cierre de B.3a.
