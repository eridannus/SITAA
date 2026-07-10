#!/usr/bin/env bash
set -euo pipefail

# SITAA: remote Supabase snapshot workflow for reconciliation only.
# This script is intentionally read-only. It must never run remote write operations, migration repair, destructive SQL,
# or any command that writes to the remote database.
#
# Required environment variable:
#   SUPABASE_DB_URL  Remote Postgres connection string provided as a setup secret.
#
# Security rules:
# - Do not echo SUPABASE_DB_URL.
# - Do not write credentials to disk.
# - Do not enable shell tracing.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/supabase/reconciliation/live"
SCHEMA_OUT="$OUT_DIR/live_schema.sql"
FUNCTIONS_OUT="$OUT_DIR/live_functions.sql"
POLICIES_OUT="$OUT_DIR/live_policies.sql"
METADATA_OUT="$OUT_DIR/live_snapshot_metadata.txt"

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

if [ -z "${SUPABASE_DB_URL:-}" ]; then
  fail 'SUPABASE_DB_URL no está configurada. Define el secreto en el setup de Codex; no lo guardes en archivos del repositorio.'
fi

mkdir -p "$OUT_DIR"

TMP_SCHEMA="$(mktemp)"
TMP_FUNCTIONS="$(mktemp)"
TMP_POLICIES="$(mktemp)"
TMP_METADATA="$(mktemp)"
cleanup() {
  rm -f "$TMP_SCHEMA" "$TMP_FUNCTIONS" "$TMP_POLICIES" "$TMP_METADATA"
}
trap cleanup EXIT

{
  printf 'SITAA Supabase live snapshot metadata\n'
  printf 'Generated at UTC: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'Purpose: reconciliation only; no remote writes.\n'
  printf 'SUPABASE_DB_URL: present; value intentionally not recorded.\n'
} > "$TMP_METADATA"

if ! command -v supabase >/dev/null 2>&1; then
  cat >&2 <<'MSG'
Error: Supabase CLI no está disponible.
Instala o habilita Supabase CLI en el entorno de setup de Codex y vuelve a ejecutar:
  bash scripts/pull-supabase-snapshot.sh
El script no generó snapshots parciales porque live_schema.sql requiere supabase db dump.
MSG
  exit 1
fi

if ! supabase db dump --help >/dev/null 2>&1; then
  cat >&2 <<'MSG'
Error: Supabase CLI está disponible, pero 'supabase db dump' no lo está.
Actualiza Supabase CLI o ajusta el entorno de setup. No uses operaciones de escritura remota ni reparación automática de historial remoto para este flujo.
MSG
  exit 1
fi

{
  printf 'Supabase CLI: '
  supabase --version 2>/dev/null || printf 'version unavailable\n'
} >> "$TMP_METADATA"

printf 'Generating read-only schema dump with Supabase CLI...\n'
if ! supabase db dump --db-url "$SUPABASE_DB_URL" --file "$TMP_SCHEMA" >/dev/null; then
  cat >&2 <<'MSG'
Error: no fue posible generar live_schema.sql con 'supabase db dump'.
Revisa que SUPABASE_DB_URL sea válido y que el entorno permita conectarse a Supabase.
No se ejecutaron operaciones de escritura remota ni reparación de historial remoto.
MSG
  exit 1
fi
mv "$TMP_SCHEMA" "$SCHEMA_OUT"
printf 'live_schema.sql: generated via supabase db dump\n' >> "$TMP_METADATA"

if command -v psql >/dev/null 2>&1; then
  {
    printf 'psql: '
    psql --version 2>/dev/null || printf 'version unavailable\n'
  } >> "$TMP_METADATA"

  printf 'Generating read-only function snapshot with psql...\n'
  if psql "$SUPABASE_DB_URL" -X -v ON_ERROR_STOP=1 -qAt -o "$TMP_FUNCTIONS" <<'SQL'
begin transaction read only;
select pg_get_functiondef(p.oid) || E'\n'
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
order by p.proname, p.oid::regprocedure::text;
commit;
SQL
  then
    mv "$TMP_FUNCTIONS" "$FUNCTIONS_OUT"
    printf 'live_functions.sql: generated via psql read-only query\n' >> "$TMP_METADATA"
  else
    rm -f "$TMP_FUNCTIONS"
    printf 'Warning: no fue posible generar live_functions.sql con psql.\n' >&2
    printf 'live_functions.sql: not generated; psql query failed\n' >> "$TMP_METADATA"
  fi

  printf 'Generating read-only policy snapshot with psql...\n'
  if psql "$SUPABASE_DB_URL" -X -v ON_ERROR_STOP=1 -qAt -o "$TMP_POLICIES" <<'SQL'
begin transaction read only;
select
  '-- Policy: public.' || tablename || '.' || policyname || E'\n' ||
  format('drop policy if exists %I on public.%I;', policyname, tablename) || E'\n' ||
  format('create policy %I', policyname) || E'\n' ||
  format('on public.%I', tablename) || E'\n' ||
  'as ' || lower(permissive) || E'\n' ||
  'for ' || cmd || E'\n' ||
  'to ' || array_to_string(roles, ', ') ||
  case when qual is not null then E'\nusing (' || qual || ')' else '' end ||
  case when with_check is not null then E'\nwith check (' || with_check || ')' else '' end ||
  E';\n'
from pg_policies
where schemaname = 'public'
order by tablename, policyname;
commit;
SQL
  then
    mv "$TMP_POLICIES" "$POLICIES_OUT"
    printf 'live_policies.sql: generated via psql read-only query\n' >> "$TMP_METADATA"
  else
    rm -f "$TMP_POLICIES"
    printf 'Warning: no fue posible generar live_policies.sql con psql.\n' >&2
    printf 'live_policies.sql: not generated; psql query failed\n' >> "$TMP_METADATA"
  fi
else
  printf 'Warning: psql no está disponible; se omitieron live_functions.sql y live_policies.sql.\n' >&2
  printf 'psql: not available\n' >> "$TMP_METADATA"
  printf 'live_functions.sql: not generated; psql not available\n' >> "$TMP_METADATA"
  printf 'live_policies.sql: not generated; psql not available\n' >> "$TMP_METADATA"
fi

mv "$TMP_METADATA" "$METADATA_OUT"
printf 'Snapshot files written to %s\n' "$OUT_DIR"
printf 'Review snapshots before creating or updating migrations. Applying migrations remains manual for now.\n'