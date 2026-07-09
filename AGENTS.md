# Guía para agentes y colaboradores

## Propósito

Este repositorio corresponde a **SITAA (Sistema Integral de Tutorías y Asesorías Académicas)**. En la etapa actual solo se define el producto, su alcance y sus reglas técnicas; todavía no existe una aplicación.

## Fuente de verdad

Antes de proponer o implementar cambios, revisar:

1. `docs/PROJECT_BRIEF.md`
2. `docs/MVP.md`
3. `docs/DATA_MODEL.md`
4. `docs/ROLES_AND_PERMISSIONS.md`
5. `docs/SECURITY_NOTES.md`
6. `docs/DECISIONS.md`

Si un cambio altera el alcance, el modelo de datos, los permisos o la arquitectura, actualizar primero la documentación relacionada y registrar la decisión en `docs/DECISIONS.md`.

## Reglas de trabajo

- Usar español en documentación, interfaz y mensajes dirigidos al usuario, salvo nombres técnicos inevitables.
- Mantener TypeScript en modo estricto cuando se inicialice el proyecto.
- Diseñar para Next.js con App Router, Tailwind CSS y Supabase.
- Aplicar autorización en la base de datos mediante Row Level Security (RLS); ocultar controles en la interfaz no cuenta como autorización.
- Tratar los datos académicos y personales como información sensible.
- Mantener los cambios pequeños, verificables y documentados.
- No incluir secretos, credenciales, datos reales de estudiantes ni archivos de entorno en Git.
- No añadir dependencias, servicios de pago o complejidad arquitectónica sin justificarlo en `docs/DECISIONS.md`.

## Estado inicial

No crear código de aplicación, inicializar Next.js ni instalar dependencias hasta que se aprueben el alcance del MVP y las decisiones abiertas registradas en la documentación.

- Usar "sólo" con tilde cuando significa "solamente"; usar "solo" sin tilde únicamente cuando significa "sin compañía".