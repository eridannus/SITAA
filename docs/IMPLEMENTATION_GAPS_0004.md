# Brechas de implementación para 0004 y fases posteriores

**Estado:** Fase A cerrada; 0004 y su corrección incremental 0005 están aplicadas, verificadas y reconciliadas. Este documento conserva las brechas de fases posteriores.

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

## Contrato de aplicación completado

Se configuró Google conforme a `GOOGLE_AUTH_SETUP.md`; los preflight, aplicaciones manuales, verificadores y smoke tests de 0004/0005 fueron aprobados. El snapshot posterior se regeneró y reconcilió en `supabase/reconciliation/0005_post_apply_reconciliation.md`.

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

No forman parte de la Fase A: Azure, SMTP, dominio obligatorio, scopes Google elevados, panel administrativo, roles V2 o filtros.
