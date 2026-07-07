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

## Alcance actual

Esta etapa incluye únicamente la base visual y técnica de Next.js. Todavía no configura Supabase, autenticación ni tablas de base de datos. La definición del producto se encuentra en `docs/`.