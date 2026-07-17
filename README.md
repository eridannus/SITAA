# SITAA

Sistema Integral de Tutorías y Asesorías Académicas.

## Requisitos

- Node.js compatible con la versión de Next.js indicada en `package.json`.
- npm.

## Comandos

```bash
npm install
npm run dev
```

La aplicación estará disponible en [http://localhost:3000](http://localhost:3000).

Otros comandos útiles:

```bash
npm run lint   # Revisa la calidad del código
npm run build  # Genera la compilación de producción
npm run start  # Inicia la compilación de producción
```

## Rutas iniciales

- `/`: página principal.
- `/health`: comprobación básica del servicio; muestra `SITAA OK`.
- `/supabase-test`: verifica la configuración y consulta `public.system_health`.
- `/login`: Google como acceso principal y correo/contraseña heredado como opción secundaria.
- `/register`: elección de registro de alumno o profesor.
- `/register/student` y `/register/professor`: inicio Google sin capturar PII institucional.
- `/auth/callback`: intercambio PKCE y selección de la ruta de finalización.
- `/complete-registration`: selector para perfiles Google con registro pendiente.
- `/complete-registration/student` y `/complete-registration/professor`: identidad institucional autenticada de tipo fijo.
- `/dashboard`: panel protegido con perfil institucional y asignaciones de rol activas.
- `/catalogs`: visor protegido de catálogos operativos activos.
- `/profile`: edición protegida de identidad institucional básica.
- `/activities`: listado protegido de actividades visibles.
- `/activities/new`: alta protegida de una actividad básica.

## Configuración de Supabase

Copia `.env.example` como `.env.local` y completa las variables públicas del proyecto:

```env
NEXT_PUBLIC_SUPABASE_URL=https://tu-proyecto.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_clave_anon_publica
```

La clave `anon` es pública y está sujeta a las políticas RLS. No agregues claves `service_role` ni secretos al repositorio.

## Autenticación

El acceso público usa Google OAuth con cookies SSR; correo/contraseña permanece sólo para cuentas heredadas. El registro no restringe dominios ni requiere SMTP. Antes de producción se debe configurar Google según `docs/GOOGLE_AUTH_SETUP.md`, aplicar/verificar 0004 y autorizar `https://www.sitaa.net/auth/callback` junto con callbacks locales o técnicos deliberados.

El registro autentica primero con Google y sólo después solicita identidad institucional. No existe escritura anónima ni consulta de disponibilidad de identificadores; tampoco asigna tutoría, asesoría, tutoría par o administración. Las cuentas técnicas no usan formularios públicos.

Después de configurar `.env.local`, inicia la aplicación y abre `/login`. Los usuarios no autenticados que intenten visitar `/dashboard`, `/catalogs`, `/profile` o `/activities` serán enviados al inicio de sesión.

La aplicación y 0004 se liberan coordinadamente: aprobar el preflight, aplicar la migración manualmente, desplegar inmediatamente esta versión compatible, ejecutar el verificador y regenerar el snapshot. No se deben mantener por tiempo prolongado una base con `student|professor` y una versión de aplicación que aún interprete `worker`.

## Alcance actual

Esta etapa incluye autenticación, perfiles, asignaciones de rol, catálogos y el alta/listado básico de actividades. El dashboard muestra el contexto vigente del usuario, pero todavía no aplica paneles especializados por rol ni implementa participantes, asistencia, QR, formularios o reportes. La definición del producto se encuentra en `docs/`.
