# Brechas de implementación para 0004 y fases posteriores

**Estado:** Fase A Google implementada localmente; 0004 no aplicada.

## Incluido en 0004

- `account_kind=institutional|technical` y `person_type=student|professor`;
- `account_status=pending_registration|active|inactive`;
- preservación de perfiles y login email/password heredados;
- perfil mínimo atómico para Google nuevo;
- `registration_intents` privado, huella SHA-256, 15 minutos y consumo único;
- RPC anónimo de creación de intent y RPC autenticado de finalización;
- rechazo de signup público por contraseña, OAuth no Google y metadata ambigua;
- sincronización segura de correo Auth sin cambiar identidad canónica;
- formularios alumno/profesor, callback PKCE y recuperación `/complete-registration`;
- login Google principal y contraseña heredada secundaria;
- cero asignaciones automáticas de rol;
- compatibilidad `worker → professor` en participante responsable.

## Prerrequisitos antes de aplicar

1. Configurar Google conforme a `GOOGLE_AUTH_SETUP.md`.
2. Volver a ejecutar el preflight aprobado y confirmar cero bloqueos.
3. Probar callback de producción, local y fallback técnico autorizado.
4. Aplicar 0004 manualmente y desplegar inmediatamente la aplicación compatible.
5. Ejecutar el verificador transaccional y el plan de pruebas.
6. Regenerar y reconciliar el snapshot.

## Compatibilidad deliberada

- Usuarios existentes no necesitan Google y continúan con contraseña.
- La vinculación por correo verificado ocurre en Supabase Auth y no reescribe `profiles`.
- Email provider sigue habilitado, pero la aplicación no ofrece signup público ni depende de SMTP.
- `technical_admin` conserva el acceso académico transitorio A-02.
- No se restringen dominios ni se detectan cuentas compartidas automáticamente.

## Pendiente de fases posteriores

- **Fase B:** administración de cuentas, desactivación Auth coordinada y auditoría.
- **Fase C:** roles V2, delegación y revocación histórica.
- **Fase D:** filtros y paginación autorizada.
- **Fase E:** retirar el acceso académico transitorio de `technical_admin`.
- **Fase F:** check-in abierto.

No forman parte de 0004: Azure, SMTP, recuperación nueva de contraseña, dominio obligatorio, scopes Google elevados, panel administrativo, roles V2, filtros o migración 0005.
