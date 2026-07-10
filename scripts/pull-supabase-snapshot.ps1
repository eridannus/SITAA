# SITAA: remote Supabase snapshot workflow for Windows PowerShell.
# Reconciliación solamente. Este script es de sólo lectura y no debe ejecutar
# operaciones remotas de escritura, reparación de historial, SQL destructivo
# ni comandos que modifiquen la base de datos.
#
# Requiere:
#   SUPABASE_DB_URL como variable de entorno secreta.
#
# Seguridad:
# - No imprimir SUPABASE_DB_URL.
# - No escribir credenciales en disco.
# - No usar trazas que expongan variables de entorno.

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  Write-Error $Message
  exit 1
}

function Write-Utf8File([string]$Path, [string[]]$Lines) {
  [System.IO.File]::WriteAllLines($Path, $Lines, [System.Text.UTF8Encoding]::new($false))
}

if ([string]::IsNullOrWhiteSpace($env:SUPABASE_DB_URL)) {
  Fail 'SUPABASE_DB_URL no está configurada. Define el secreto en el entorno de Codex o PowerShell; no lo guardes en archivos del repositorio.'
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Resolve-Path (Join-Path $ScriptDir '..')
$OutDir = Join-Path $RootDir 'supabase\reconciliation\live'
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$SchemaOut = Join-Path $OutDir 'live_schema.sql'
$FunctionsOut = Join-Path $OutDir 'live_functions.sql'
$PoliciesOut = Join-Path $OutDir 'live_policies.sql'
$TablesOut = Join-Path $OutDir 'live_tables.sql'
$ColumnsOut = Join-Path $OutDir 'live_columns.sql'
$ConstraintsOut = Join-Path $OutDir 'live_constraints.sql'
$IndexesOut = Join-Path $OutDir 'live_indexes.sql'
$TriggersOut = Join-Path $OutDir 'live_triggers.sql'
$MetadataOut = Join-Path $OutDir 'live_snapshot_metadata.txt'

$SupabaseCommand = Get-Command supabase -ErrorAction SilentlyContinue
if (-not $SupabaseCommand) {
  Fail 'Supabase CLI no está disponible. Instala o habilita Supabase CLI y vuelve a ejecutar: powershell -ExecutionPolicy Bypass -File scripts/pull-supabase-snapshot.ps1'
}

$SupabaseHelp = & supabase db dump --help 2>$null
if ($LASTEXITCODE -ne 0) {
  Fail "Supabase CLI está disponible, pero 'supabase db dump' no lo está. Actualiza Supabase CLI o ajusta el entorno. No uses operaciones remotas de escritura ni reparación automática de historial para este flujo."
}

$PsqlCommand = Get-Command psql -ErrorAction SilentlyContinue
if (-not $PsqlCommand) {
  Fail 'psql no está disponible. Instala PostgreSQL client tools o habilita psql para generar snapshots completos: funciones, políticas, tablas, columnas, constraints, índices y triggers. No se generó ningún snapshot parcial.'
}

$metadata = @(
  'SITAA Supabase live snapshot metadata',
  ('Generated at UTC: ' + (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')),
  'Purpose: reconciliation only; no remote writes.',
  'SUPABASE_DB_URL: present; value intentionally not recorded.',
  ('Supabase CLI: ' + ((& supabase --version 2>$null) -join ' ')),
  ('psql: ' + ((& psql --version 2>$null) -join ' '))
)
Write-Utf8File -Path $MetadataOut -Lines $metadata

Write-Host 'Generating read-only schema dump with Supabase CLI...'
& supabase db dump --db-url $env:SUPABASE_DB_URL --file $SchemaOut | Out-Null
if ($LASTEXITCODE -ne 0) {
  Fail "No fue posible generar live_schema.sql con 'supabase db dump'. Revisa SUPABASE_DB_URL y la conectividad. No se ejecutaron operaciones remotas de escritura."
}
Add-Content -LiteralPath $MetadataOut -Value 'live_schema.sql: generated via supabase db dump' -Encoding UTF8

$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ('sitaa-supabase-snapshot-' + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

function Invoke-ReadOnlySnapshotQuery {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string[]]$SqlLines,
    [Parameter(Mandatory = $true)][string]$OutputPath
  )

  $QueryPath = Join-Path $TempDir ($Name + '.sql')
  Write-Utf8File -Path $QueryPath -Lines $SqlLines
  Write-Host ("Generating " + $Name + " with psql read-only query...")
  & psql $env:SUPABASE_DB_URL -X -v ON_ERROR_STOP=1 -qAt -f $QueryPath -o $OutputPath
  if ($LASTEXITCODE -ne 0) {
    Fail ("No fue posible generar " + $Name + " con psql. No se aplicó ningún cambio remoto.")
  }
  Add-Content -LiteralPath $MetadataOut -Value ($Name + ': generated via psql read-only query') -Encoding UTF8
}

try {
  Invoke-ReadOnlySnapshotQuery -Name 'live_functions.sql' -OutputPath $FunctionsOut -SqlLines @(
    'begin transaction read only;',
    "select pg_get_functiondef(p.oid) || E'\n'",
    'from pg_proc p',
    'join pg_namespace n on n.oid = p.pronamespace',
    "where n.nspname = 'public'",
    'order by p.proname, p.oid::regprocedure::text;',
    'commit;'
  )

  Invoke-ReadOnlySnapshotQuery -Name 'live_policies.sql' -OutputPath $PoliciesOut -SqlLines @(
    'begin transaction read only;',
    'select',
    "  '-- Policy: public.' || tablename || '.' || policyname || E'\n' ||",
    "  format('drop policy if exists %I on public.%I;', policyname, tablename) || E'\n' ||",
    "  format('create policy %I', policyname) || E'\n' ||",
    "  format('on public.%I', tablename) || E'\n' ||",
    "  'as ' || lower(permissive) || E'\n' ||",
    "  'for ' || cmd || E'\n' ||",
    "  'to ' || array_to_string(roles, ', ') ||",
    "  case when qual is not null then E'\nusing (' || qual || ')' else '' end ||",
    "  case when with_check is not null then E'\nwith check (' || with_check || ')' else '' end ||",
    "  E';\n'",
    'from pg_policies',
    "where schemaname = 'public'",
    'order by tablename, policyname;',
    'commit;'
  )

  Invoke-ReadOnlySnapshotQuery -Name 'live_tables.sql' -OutputPath $TablesOut -SqlLines @(
    'begin transaction read only;',
    "select schemaname || '.' || tablename",
    'from pg_tables',
    "where schemaname = 'public'",
    'order by tablename;',
    'commit;'
  )

  Invoke-ReadOnlySnapshotQuery -Name 'live_columns.sql' -OutputPath $ColumnsOut -SqlLines @(
    'begin transaction read only;',
    'select',
    "  table_name || E'\t' || ordinal_position || E'\t' || column_name || E'\t' || data_type || E'\t' || is_nullable || E'\t' || coalesce(column_default, '')",
    'from information_schema.columns',
    "where table_schema = 'public'",
    'order by table_name, ordinal_position;',
    'commit;'
  )

  Invoke-ReadOnlySnapshotQuery -Name 'live_constraints.sql' -OutputPath $ConstraintsOut -SqlLines @(
    'begin transaction read only;',
    'select',
    "  conrelid::regclass::text || E'\t' || conname || E'\t' || contype || E'\t' || pg_get_constraintdef(oid)",
    'from pg_constraint',
    "where connamespace = 'public'::regnamespace",
    'order by conrelid::regclass::text, conname;',
    'commit;'
  )

  Invoke-ReadOnlySnapshotQuery -Name 'live_indexes.sql' -OutputPath $IndexesOut -SqlLines @(
    'begin transaction read only;',
    "select schemaname || E'\t' || tablename || E'\t' || indexname || E'\t' || indexdef",
    'from pg_indexes',
    "where schemaname = 'public'",
    'order by tablename, indexname;',
    'commit;'
  )

  Invoke-ReadOnlySnapshotQuery -Name 'live_triggers.sql' -OutputPath $TriggersOut -SqlLines @(
    'begin transaction read only;',
    'select',
    "  event_object_table || E'\t' || trigger_name || E'\t' || action_timing || E'\t' || event_manipulation || E'\t' || action_statement",
    'from information_schema.triggers',
    "where trigger_schema = 'public'",
    'order by event_object_table, trigger_name, event_manipulation;',
    'commit;'
  )
}
finally {
  if (Test-Path -LiteralPath $TempDir) {
    Remove-Item -LiteralPath $TempDir -Recurse -Force
  }
}

Write-Host ("Snapshot files written to " + $OutDir)
Write-Host 'Review snapshots before creating or updating migrations. Applying migrations remains manual for now.'
