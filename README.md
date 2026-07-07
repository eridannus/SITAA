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
- `/login`: inicio de sesión con correo y contraseña.
- `/dashboard`: panel básico protegido para usuarios autenticados.

## Configuración de Supabase

Copia `.env.example` como `.env.local` y completa las variables públicas del proyecto:

```env
NEXT_PUBLIC_SUPABASE_URL=https://tu-proyecto.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_clave_anon_publica
```

La clave `anon` es pública y está sujeta a las políticas RLS. No agregues claves `service_role` ni secretos al repositorio.

## Autenticación

El acceso usa Supabase Auth con correo y contraseña mediante cookies SSR. El registro público no está implementado: crea las cuentas autorizadas desde el panel administrativo de Supabase y mantén deshabilitada la opción de permitir nuevos registros en la configuración de Auth.

Después de configurar `.env.local`, inicia la aplicación y abre `/login`. Los usuarios no autenticados que intenten visitar `/dashboard` serán enviados al inicio de sesión.

## Alcance actual

Esta etapa incluye la base visual y técnica de Next.js, una prueba de conexión pública y autenticación básica con Supabase. Todavía no implementa roles, paneles especializados ni tablas de dominio. La definición del producto se encuentra en `docs/`.