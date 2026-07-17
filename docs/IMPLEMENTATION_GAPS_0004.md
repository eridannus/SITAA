# Brechas de implementación para 0004 y fases posteriores

**Estado:** Fase A y 0004 aplicadas; corrección incremental 0005 creada y no aplicada.

## Incluido en 0004

- `account_kind=institutional|technical`, `person_type=student|professor` y estados `pending_registration|active|inactive`;
- preservación de perfiles y login email/password heredados;
- perfil mínimo atómico para Google nuevo;
- selección pública alumno/profesor sin PII antes de OAuth;
- formularios institucionales autenticados y RPC transaccional disponible sólo para `authenticated`;
- rechazo de signup público por contraseña, OAuth no Google y metadata ambigua;
- sincronización segura de correo Auth sin cambiar identidad canónica;
- login Google principal y contraseña heredada secundaria;
- cero asignaciones automáticas de rol;
- compatibilidad `worker → professor` en participante responsable.

No existe tabla de intents, escritura anónima de registro ni endpoint público de disponibilidad de identificadores.

## Prerrequisitos antes de aplicar

1. Configurar Google conforme a `GOOGLE_AUTH_SETUP.md`.
2. Repetir el preflight y confirmar cero bloqueos.
3. Probar callback de producción, local y preview autorizado.
4. Aplicar 0004 manualmente y desplegar inmediatamente la aplicación compatible.
5. Ejecutar verificador y plan de pruebas.
6. Regenerar y reconciliar el snapshot.

## Compatibilidad deliberada

- Usuarios existentes no necesitan Google y continúan con contraseña.
- La vinculación por correo verificado ocurre en Supabase Auth y no reescribe `profiles`.
- Email provider sigue habilitado, pero no hay signup público ni dependencia SMTP.
- `technical_admin` conserva el acceso académico transitorio A-02.
- No se restringen dominios ni se detectan cuentas compartidas automáticamente.

## Fases posteriores

- **Fase B:** administración de cuentas, desactivación Auth coordinada y auditoría.
- **Fase C:** roles V2, delegación y revocación histórica.
- **Fase D:** filtros y paginación autorizada.
- **Fase E:** retirar acceso académico transitorio de `technical_admin`.
- **Fase F:** check-in abierto.

No forman parte de 0004 ni de su corrección 0005: Azure, SMTP, dominio obligatorio, scopes Google elevados, panel administrativo, roles V2 o filtros.
