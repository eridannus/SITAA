# SITAA: snapshot remoto de Supabase para Windows PowerShell.
# Reconciliación solamente. Todas las consultas son de sólo lectura y los
# artefactos generados deben revisarse antes de convertirlos en migraciones.

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $Utf8NoBom
[Console]::OutputEncoding = $Utf8NoBom
$OutputEncoding = $Utf8NoBom

function Write-Utf8File {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string[]]$Lines
  )
  [System.IO.File]::WriteAllLines($Path, $Lines, $Utf8NoBom)
}

function Resolve-NativePostgresTool {
  param([Parameter(Mandatory = $true)][string]$Name)

  $Command = Get-Command ($Name + '.exe') -CommandType Application -ErrorAction SilentlyContinue
  if (-not $Command) {
    $Command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue
  }
  if ($Command) {
    return $Command.Source
  }

  $KnownPath = Join-Path 'C:\Program Files\PostgreSQL\18\bin' ($Name + '.exe')
  if (Test-Path -LiteralPath $KnownPath -PathType Leaf) {
    return $KnownPath
  }
  return $null
}

function Get-ToolVersion {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return 'no disponible'
  }
  return ((& $Path --version 2>$null) -join ' ').Trim()
}

if ([string]::IsNullOrWhiteSpace($env:SUPABASE_DB_URL)) {
  throw 'SUPABASE_DB_URL no está configurada. Define el secreto en el entorno de PowerShell; no lo guardes en archivos del repositorio.'
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = (Resolve-Path (Join-Path $ScriptDir '..')).Path
$OutDir = Join-Path $RootDir 'supabase\reconciliation\live'
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$OutputNames = @(
  'live_schema.sql',
  'live_tables.sql',
  'live_columns.sql',
  'live_constraints.sql',
  'live_indexes.sql',
  'live_triggers.sql',
  'live_functions.sql',
  'live_policies.sql',
  'live_seed_catalogs.sql',
  'live_snapshot_metadata.txt'
)

$PgDumpPath = Resolve-NativePostgresTool -Name 'pg_dump'
$PsqlPath = Resolve-NativePostgresTool -Name 'psql'
$SupabaseCommand = Get-Command 'supabase.exe' -CommandType Application -ErrorAction SilentlyContinue
if (-not $SupabaseCommand) {
  $SupabaseCommand = Get-Command 'supabase' -CommandType Application -ErrorAction SilentlyContinue
}
$SupabasePath = if ($SupabaseCommand) { $SupabaseCommand.Source } else { $null }

if ([string]::IsNullOrWhiteSpace($PsqlPath)) {
  throw 'No se encontró psql en PATH ni en C:\Program Files\PostgreSQL\18\bin. Instala o habilita las herramientas cliente de PostgreSQL antes de generar el snapshot completo.'
}

$SchemaTool = if (-not [string]::IsNullOrWhiteSpace($PgDumpPath)) {
  'pg_dump'
} elseif (-not [string]::IsNullOrWhiteSpace($SupabasePath)) {
  'supabase-cli-fallback'
} else {
  throw 'No se encontró pg_dump en PATH ni en C:\Program Files\PostgreSQL\18\bin, y Supabase CLI tampoco está disponible como respaldo final.'
}

$PgDumpVersion = Get-ToolVersion -Path $PgDumpPath
$PsqlVersion = Get-ToolVersion -Path $PsqlPath
$SupabaseVersion = Get-ToolVersion -Path $SupabasePath
$GeneratedAtUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ('sitaa-supabase-snapshot-' + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

$PreviousClientEncoding = $env:PGCLIENTENCODING
$PreviousPgOptions = $env:PGOPTIONS
$env:PGCLIENTENCODING = 'UTF8'
$env:PGOPTIONS = '-c default_transaction_read_only=on'

function Invoke-ReadOnlySnapshotQuery {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string[]]$SqlLines
  )

  $QueryPath = Join-Path $TempDir ($Name + '.query.sql')
  $OutputPath = Join-Path $TempDir ($Name + '.sql')
  Write-Utf8File -Path $QueryPath -Lines $SqlLines

  Write-Host ('Generando ' + $Name + ' con psql en una transacción de sólo lectura...')
  $PsqlArguments = @(
    '--no-psqlrc',
    '--set=ON_ERROR_STOP=1',
    '--quiet',
    '--tuples-only',
    '--no-align',
    '--pset=pager=off',
    ('--dbname=' + $env:SUPABASE_DB_URL),
    ('--file=' + $QueryPath),
    ('--output=' + $OutputPath)
  )
  & $PsqlPath @PsqlArguments
  if ($LASTEXITCODE -ne 0) {
    throw ('No fue posible generar ' + $Name + ' con psql.')
  }
  if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
    throw ('psql no produjo la salida esperada para ' + $Name + '.')
  }
}

function Write-FailureMetadata {
  $FailureLines = @(
    'SITAA Supabase live snapshot metadata',
    ('Generated at UTC: ' + $GeneratedAtUtc),
    'Status: FAILURE',
    'Purpose: reconciliation only; no remote writes.',
    ('Schema tool selected: ' + $SchemaTool),
    ('pg_dump version: ' + $PgDumpVersion),
    ('psql version: ' + $PsqlVersion),
    ('Supabase CLI version: ' + $SupabaseVersion),
    'Connection credentials: provided at runtime and intentionally not recorded.',
    'Result: no live snapshot file was replaced by this failed run.'
  )
  Write-Utf8File -Path (Join-Path $OutDir 'live_snapshot_metadata.txt') -Lines $FailureLines
}

try {
  $SchemaTemp = Join-Path $TempDir 'live_schema.sql'
  if ($SchemaTool -eq 'pg_dump') {
    Write-Host 'Generando live_schema.sql con pg_dump nativo; Docker no es necesario...'
    $PgDumpArguments = @(
      ('--dbname=' + $env:SUPABASE_DB_URL),
      '--schema-only',
      '--schema=public',
      '--no-owner',
      '--no-privileges',
      '--encoding=UTF8',
      ('--file=' + $SchemaTemp)
    )
    & $PgDumpPath @PgDumpArguments
  } else {
    Write-Warning 'pg_dump nativo no está disponible. Se usará Supabase CLI como respaldo final; este camino puede requerir Docker.'
    & $SupabasePath db dump --db-url $env:SUPABASE_DB_URL --schema public --file $SchemaTemp
  }
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $SchemaTemp -PathType Leaf)) {
    throw 'No fue posible generar live_schema.sql. La salida temporal incompleta será eliminada.'
  }

  Invoke-ReadOnlySnapshotQuery -Name 'live_tables' -SqlLines @(
    'begin transaction read only;',
    "select '-- schema' || E'\t' || 'table' || E'\t' || 'relation_type' || E'\t' || 'rls_enabled' || E'\t' || 'rls_forced';",
    'select n.nspname || E''\t'' || c.relname || E''\t'' ||',
    "  case c.relkind when 'r' then 'table' when 'p' then 'partitioned_table' else c.relkind::text end || E'\t' ||",
    "  c.relrowsecurity::text || E'\t' || c.relforcerowsecurity::text",
    'from pg_class c',
    'join pg_namespace n on n.oid = c.relnamespace',
    "where n.nspname = 'public' and c.relkind in ('r', 'p')",
    'order by c.relname;',
    'commit;'
  )

  Invoke-ReadOnlySnapshotQuery -Name 'live_columns' -SqlLines @(
    'begin transaction read only;',
    "select '-- table' || E'\t' || 'position' || E'\t' || 'column' || E'\t' || 'data_type' || E'\t' || 'udt_name' || E'\t' || 'nullable' || E'\t' || 'default' || E'\t' || 'char_max_length' || E'\t' || 'numeric_precision' || E'\t' || 'numeric_scale' || E'\t' || 'datetime_precision';",
    'select table_name || E''\t'' || ordinal_position::text || E''\t'' || column_name || E''\t'' || data_type || E''\t'' || udt_name || E''\t'' || is_nullable || E''\t'' ||',
    "  coalesce(column_default, '') || E'\t' || coalesce(character_maximum_length::text, '') || E'\t' ||",
    "  coalesce(numeric_precision::text, '') || E'\t' || coalesce(numeric_scale::text, '') || E'\t' || coalesce(datetime_precision::text, '')",
    'from information_schema.columns',
    "where table_schema = 'public'",
    'order by table_name, ordinal_position;',
    'commit;'
  )

  Invoke-ReadOnlySnapshotQuery -Name 'live_constraints' -SqlLines @(
    'begin transaction read only;',
    "select '-- table' || E'\t' || 'constraint' || E'\t' || 'type' || E'\t' || 'definition';",
    'select c.conrelid::regclass::text || E''\t'' || c.conname || E''\t'' ||',
    "  case c.contype when 'p' then 'primary_key' when 'f' then 'foreign_key' when 'u' then 'unique' when 'c' then 'check' else c.contype::text end || E'\t' ||",
    '  pg_get_constraintdef(c.oid, true)',
    'from pg_constraint c',
    "where c.connamespace = 'public'::regnamespace and c.conrelid <> 0 and c.contype in ('p', 'f', 'u', 'c')",
    'order by c.conrelid::regclass::text, c.conname;',
    'commit;'
  )

  Invoke-ReadOnlySnapshotQuery -Name 'live_indexes' -SqlLines @(
    'begin transaction read only;',
    "select '-- schema' || E'\t' || 'table' || E'\t' || 'index' || E'\t' || 'definition';",
    "select schemaname || E'\t' || tablename || E'\t' || indexname || E'\t' || indexdef",
    'from pg_indexes',
    "where schemaname = 'public'",
    'order by tablename, indexname;',
    'commit;'
  )

  Invoke-ReadOnlySnapshotQuery -Name 'live_triggers' -SqlLines @(
    'begin transaction read only;',
    "select '-- table' || E'\t' || 'trigger' || E'\t' || 'definition';",
    "select c.relname || E'\t' || t.tgname || E'\t' || pg_get_triggerdef(t.oid, true)",
    'from pg_trigger t',
    'join pg_class c on c.oid = t.tgrelid',
    'join pg_namespace n on n.oid = c.relnamespace',
    "where n.nspname = 'public' and not t.tgisinternal",
    'order by c.relname, t.tgname;',
    'commit;'
  )

  Invoke-ReadOnlySnapshotQuery -Name 'live_functions' -SqlLines @(
    'begin transaction read only;',
    "select '-- signature' || E'\t' || 'identity_arguments' || E'\t' || 'arguments' || E'\t' || 'definition';",
    "select p.oid::regprocedure::text || E'\t' || pg_get_function_identity_arguments(p.oid) || E'\t' || pg_get_function_arguments(p.oid) || E'\t' || pg_get_functiondef(p.oid)",
    'from pg_proc p',
    'join pg_namespace n on n.oid = p.pronamespace',
    "where n.nspname = 'public' and p.prokind in ('f', 'p')",
    'order by p.proname, p.oid::regprocedure::text;',
    'commit;'
  )

  Invoke-ReadOnlySnapshotQuery -Name 'live_policies' -SqlLines @(
    'begin transaction read only;',
    "select '-- schema' || E'\t' || 'table' || E'\t' || 'policy' || E'\t' || 'mode' || E'\t' || 'roles' || E'\t' || 'command' || E'\t' || 'using' || E'\t' || 'with_check';",
    "select schemaname || E'\t' || tablename || E'\t' || policyname || E'\t' || permissive || E'\t' ||",
    "  array_to_string(roles, ',') || E'\t' || cmd || E'\t' || coalesce(qual, '') || E'\t' || coalesce(with_check, '')",
    'from pg_policies',
    "where schemaname = 'public'",
    'order by tablename, policyname;',
    'commit;'
  )

  Invoke-ReadOnlySnapshotQuery -Name 'live_seed_catalogs' -SqlLines @(
    'begin transaction read only;',
    "select '-- catalog' || E'\t' || 'row_as_json';",
    'select format(',
    "  'select %L || E''\t'' || to_jsonb(c)::text from public.%I c order by to_jsonb(c)::text;',",
    '  c.relname, c.relname',
    ')',
    'from pg_class c',
    'join pg_namespace n on n.oid = c.relnamespace',
    "where n.nspname = 'public'",
    "  and c.relkind in ('r', 'p')",
    "  and c.relname = any (array['roles','divisions','academic_programs','academic_periods','activity_types','service_types','attention_categories','activity_modalities','activity_statuses','location_types','participant_roles'])",
    'order by c.relname',
    '\gexec',
    'commit;'
  )

  $SuccessMetadata = @(
    'SITAA Supabase live snapshot metadata',
    ('Generated at UTC: ' + $GeneratedAtUtc),
    'Status: SUCCESS',
    'Purpose: reconciliation only; no remote writes.',
    ('Schema tool selected: ' + $SchemaTool),
    ('pg_dump version: ' + $PgDumpVersion),
    ('psql version: ' + $PsqlVersion),
    ('Supabase CLI version: ' + $SupabaseVersion),
    'PostgreSQL client encoding: UTF8',
    'Connection credentials: provided at runtime and intentionally not recorded.',
    'Schema scope: public only; schema-only; ownership and privileges excluded.',
    'Catalog seed scope: controlled SITAA catalogs only; operational and personal data excluded.'
  )
  Write-Utf8File -Path (Join-Path $TempDir 'live_snapshot_metadata.txt') -Lines $SuccessMetadata

  foreach ($Name in $OutputNames) {
    $TempOutput = Join-Path $TempDir $Name
    if (-not (Test-Path -LiteralPath $TempOutput -PathType Leaf)) {
      throw ('Falta la salida temporal esperada: ' + $Name)
    }
  }
  foreach ($Name in $OutputNames) {
    Move-Item -LiteralPath (Join-Path $TempDir $Name) -Destination (Join-Path $OutDir $Name) -Force
  }

  Write-Host ('Snapshot completo escrito en ' + $OutDir)
  Write-Host 'Los artefactos son para reconciliación; revísalos antes de crear o actualizar migraciones.'
}
catch {
  Write-FailureMetadata
  Write-Error 'Falló la generación del snapshot. No se reemplazaron los archivos de salida con datos parciales. Revisa el error de la herramienta mostrado arriba.'
  exit 1
}
finally {
  if (Test-Path -LiteralPath $TempDir) {
    Remove-Item -LiteralPath $TempDir -Recurse -Force
  }

  if ($null -eq $PreviousClientEncoding) {
    Remove-Item Env:PGCLIENTENCODING -ErrorAction SilentlyContinue
  } else {
    $env:PGCLIENTENCODING = $PreviousClientEncoding
  }
  if ($null -eq $PreviousPgOptions) {
    Remove-Item Env:PGOPTIONS -ErrorAction SilentlyContinue
  } else {
    $env:PGOPTIONS = $PreviousPgOptions
  }
}
